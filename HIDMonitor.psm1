Function Start-HIDMonitor() {
    #Requires -RunAsAdministrator
    [cmdletbinding()]
    param(
        [Parameter(Mandatory=$false)][string]$createEventId = 4444,
        [Parameter(Mandatory=$false)][string]$deleteEventId = 4445
    )
     
    try {
        New-EventQuery -queryString "select * from __instanceCreationEvent within 1 where targetInstance isa 'Win32_USBControllerDevice'" -namePrefix "create" -eventId $createEventId -eventLog 'Application' -eventSource 'HID Monitor - Device Inserted'
        New-EventQuery -queryString "select * from __instanceDeletionEvent within 1 where targetInstance isa 'Win32_USBControllerDevice'" -namePrefix "delete" -eventId $deleteEventId -eventLog 'Application' -eventSource 'HID Monitor - Device Removed'
    
    }
    catch {
        Write-Output '[!] An error was encountered registered WMI events, try running Stop-HIDMonitor first'
    }
}

Function New-EventQuery() {
    #Requires -RunAsAdministrator
    [cmdletbinding()]
    param(
        [Parameter(Mandatory=$true)][string]$queryString,
        [Parameter(Mandatory=$true)][string]$namePrefix,
        [Parameter(Mandatory=$false)][string]$eventId,
        [Parameter(Mandatory=$false)][string]$eventLog,
        [Parameter(Mandatory=$false)][string]$eventSource
    )

    #create event source
    New-EventSource -eventLog $eventLog -eventSource $eventSource

    #config
    $wmiParams = @{
        Computername = $env:COMPUTERNAME
        #ErrorAction = 'Stop'
        NameSpace = 'root\subscription'
    }

    #create filter
    $wmiParams.Class = '__EventFilter'
    $wmiParams.Arguments = @{
        Name = $namePrefix + 'HIDFilter'
        EventNamespace = 'root\CIMV2'
        QueryLanguage = 'WQL'
        Query = $queryString
    }
    $filterResult = Set-WmiInstance @wmiParams

    #create consumer
    $wmiParams.Class = 'NTEventLogEventConsumer'
    $wmiParams.Arguments = @{
        Name = $namePrefix + 'HIDConsumer'
        SourceName = $eventSource
        EventId = $eventId
        EventType = 2
        Category = 0
        NumberOfInsertionStrings = 1
        InsertionStringTemplates = @("USB Device State Change: %TargetInstance.Dependent%")
    }
    $consumerResult = Set-WmiInstance @wmiParams

    #create binding
    $wmiParams.Class = '__FilterToConsumerBinding'
    $wmiParams.Arguments = @{
        Filter = $filterResult
        Consumer = $consumerResult
    }
    $bindingResult = Set-WmiInstance @wmiParams
}

Function Stop-HIDMonitor() {
    #Requires -RunAsAdministrator

    #delete filter
    Get-WMIObject -Namespace root\Subscription -Class __EventFilter -Filter "Name='createHIDFilter'" | Remove-WmiObject
    Get-WMIObject -Namespace root\Subscription -Class __EventFilter -Filter "Name='deleteHIDFilter'" | Remove-WmiObject
 
    #delete consumer
    Get-WMIObject -Namespace root\Subscription -Class NTEventLogEventConsumer -Filter "Name='createHIDConsumer'" | Remove-WmiObject
    Get-WMIObject -Namespace root\Subscription -Class NTEventLogEventConsumer -Filter "Name='deleteHIDConsumer'" | Remove-WmiObject

    #delete binding
    Get-WMIObject -Namespace root\Subscription -Class __FilterToConsumerBinding -Filter "__Path LIKE '%HIDFilter%'"  | Remove-WmiObject
}

Function New-EventSource {
    #Requires -RunAsAdministrator
    [cmdletbinding()]
    param(
        [Parameter(Mandatory=$true)][string]$eventLog,
        [Parameter(Mandatory=$true)][string]$eventSource
    )

    If (!([System.Diagnostics.EventLog]::SourceExists($eventSource))) {
        New-EventLog -LogName $eventLog -Source $eventSource
    }
}