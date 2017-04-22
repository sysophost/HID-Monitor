Function Start-HIDMonitor() {
    #Requires -RunAsAdministrator
    param(
        [Parameter(Mandatory=$false)][string]$logPath = "C:\temp\log.log",
        [Parameter(Mandatory=$false)][string]$createMessage = "USB device inserted: ",
        [Parameter(Mandatory=$false)][string]$deleteMessage = "USB device removed: "
    )
    
    New-EventQuery -queryString "select * from __instanceCreationEvent within 1 where targetInstance isa 'Win32_USBControllerDevice'" -logMessage $createMessage -namePrefix "create" -logPath $logPath
    New-EventQuery -queryString "select * from __instanceDeletionEvent within 1 where targetInstance isa 'Win32_USBControllerDevice'" -logMessage $deleteMessage -namePrefix "delete" -logPath $logPath
}

Function New-EventQuery() {
    #Requires -RunAsAdministrator
    param(
        [Parameter(Mandatory=$true)][string]$queryString,
        [Parameter(Mandatory=$false)][string]$logPath,
        [Parameter(Mandatory=$true)][string]$logMessage,
        [Parameter(Mandatory=$true)][string]$namePrefix
    )

    #config
    $wmiParams = @{
        Computername = $env:COMPUTERNAME
        ErrorAction = 'Stop'
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
    $wmiParams.Class = 'LogFileEventConsumer'
    $wmiParams.Arguments = @{
        Name = $namePrefix + 'HIDConsumer'
        Text = "$logMessage %TargetInstance.Dependent%"
        FileName = $logPath
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
    Get-WMIObject -Namespace root\Subscription -Class LogFileEventConsumer -Filter "Name='createHIDConsumer'" | Remove-WmiObject
    Get-WMIObject -Namespace root\Subscription -Class LogFileEventConsumer -Filter "Name='deleteHIDConsumer'" | Remove-WmiObject

    #delete binding
    Get-WMIObject -Namespace root\Subscription -Class __FilterToConsumerBinding -Filter "__Path LIKE '%HIDFilter%'"  | Remove-WmiObject
}