<#

//*********************************************************
// THIS CODE IS PROVIDED AS IS WITHOUT WARRANTY OF
// ANY KIND, EITHER EXPRESS OR IMPLIED, INCLUDING ANY
// IMPLIED WARRANTIES OF FITNESS FOR A PARTICULAR
// PURPOSE, MERCHANTABILITY, OR NON-INFRINGEMENT.
//*********************************************************

    Date: 23rd February 2016
    Author: Steve Jeffery
    Description:   This script is intended to be used to measure latency 
                   between SharePoint servers and SQL servers.                   
#>

# Global variables & code
$userObj = [System.Security.Principal.WindowsIdentity]::GetCurrent()
$user = $userObj.name 
$LogFilePath = "C:\temp"
$LogDate = Get-Date -Format dd-MM-yy-ss
$LogFile = "$LogFilePath\$(gc env:computername)-$LogDate.log"

function Write-LogEvent # This function is used to write to the event log.
{
	Param 
	(
		[string]$Message,
		[string]$Level,
		[int]$Id
	)
	
	$eventLog = Get-EventLog –List | Where-Object {$_.Log –eq ‘Application’}
	$eventLog.MachineName = “.”
	$eventLog.Source = “Contoso IT Department” # You should change the source to something more relevant.
	$eventLog.WriteEntry(“$Message”,”$Level”,$Id)
}

function Log-Write
{
    Param
    (
        [string]$Log,
        [string]$Value
    )

    $D = Get-Date -Format dd-MM-yy-hh:mm:ss:ms
    $LogEntry = $D.ToString() + ' :: ' + $Value

    Add-Content $Log -Value $LogEntry -ErrorAction SilentlyContinue
    
}

Write-LogEvent -Id 1234 -Level "Information" -Message "Initiating network latency tracking script."

<#
.Synopsis
   This script tracks latency between a host and target server.
.DESCRIPTION
   This script tracks latency between a host and target server. Output from this script is direct into a SQL database to allow further analysis.
.EXAMPLE
   This example will track network latency between two servers for a period of 24 hours.
   
   Measure-NetworkLatency -Target "SERVERNAME" -DatabaseServer "SQLSERVER" -DatabaseName "LatencyDB" -LogFilePath "C:\Temp" -DurationHours 48
#>
function Measure-NetworkLatency
{
    Param
    (
        [string]$Target,
        [string]$DatabaseServer,
        [string]$DatabaseName,
        [string]$LogFilePath,
        [int]$DurationHours
    )

    Log-Write -Log $LogFile -Value "Begin: preflight checks"
        Log-Write -Log $LogFile -Value "Begin: checking log file"
        Write-Host -ForegroundColor White "Begin: preflight checks"

            if (!(Test-Path $LogFilePath))
            {
                Write-Error "Log file path is invalid, please check."
            }
        
            else
            {
                $LogFile = "$LogFilePath\$(gc env:computername)-$LogDate.log"
                Log-Write -Log $LogFile -Value "Network latency report."
                Log-Write -Log $LogFile -Value "Initiated by: $user"
                Log-Write -Log $LogFile -Value "Local server: $env:COMPUTERNAME"
                Log-Write -Log $LogFile -Value ""
                Write-LogEvent -Id 1337 -Level "Information" -Message "Latency script has been started."
                Log-Write -Log $LogFile -Value "Success: Information event in application log created."
                Log-Write -Log $LogFile -Value "End: checking log file"
                Write-Host -ForegroundColor Green "Successfully created log file"
            }

        Log-Write -Log $LogFile -Value "Begin: checking SQL connectivity"

        $SQLConnection = New-Object System.Data.SqlClient.SqlConnection("Data Source=$DatabaseServer;Integrated Security=SSPI")
        $SQLConnection.Open()

            if ($SQLConnection.State -ne 'Open')
            {
                Log-Write -Log $LogFile -Value "End: preflight check failed, cannot open connection to SQL server."
                Write-Error "Preflight check failed, cannot open connection to SQL server."
                End
            }
            
            else
            {
                Log-Write -Log $LogFile -Value "End: Success! Successfully opened connection to SQL server $DatabaseServer"
                $SQLConnection.Close() 
                Write-Host -ForegroundColor Green "Successfully opened SQL connection to $DatbaseServer" 
            }

        Log-Write -Log $LogFile -Value "Begin: checking ICMP traffic to targets"

        $Ping = New-Object System.Net.NetworkInformation.Ping

            
            $icmpTest = $Ping.Send($target)

            if ($icmpTest.Status -ne 'Success')
            {
                Write-Error "Preflight check failed, cannot ping $server; please check firewalls, etc."
                Log-Write -Log $LogFile -Value "End: preflight check failed, cannot ping $server"
            }

            else
            {
                Log-Write "End: Success! Successfully pinged $server"
                Write-Host -ForegroundColor Green "Successfully pinged $server"
            }
            

    Log-Write -Log $LogFile -Value "End: preflight checks completed."
    Write-Host -ForegroundColor White "End: preflight checks"

    $startTime = [datetime]::Now
    

    while ([datetime]::Now -le $startTime.AddHours($DurationHours))
    {
        $dbConnection = New-Object System.Data.SqlClient.SqlConnection("Data Source=$DatabaseServer;Initial Catalog=$DatabaseName;Integrated Security=SSPI")
        $dbConnection.Open()
        $dbCmd = New-Object System.Data.SqlClient.SqlCommand
        $dbCmd.Connection = $dbConnection
        $Ping = New-Object System.Net.NetworkInformation.Ping
        $pingSender = $Ping.Send($target)
        $pingTime = Get-Date -Format dd-MM-yy-hh:mm:ss:ms
        $pingRoundTrip = $pingSender.RoundtripTime
        $pingStatus = $pingSender.Status
        $hostName = $env:COMPUTERNAME
        $dbCmd.CommandText = "INSERT INTO Latency (Host,Destination,Time,Roundtrip,Status) VALUES('{0}','{1}','{2}','{3}','{4}')" -f $hostName,$target,$pingTime,$pingRoundTrip,$pingStatus
        $dbCmd.executenonquery()
        $dbConnection.Close()
        Write-Host "." -NoNewline
        Start-Sleep -Seconds 2
    }

    
}   

Measure-NetworkLatency -Target "<server-name>" -DatabaseServer "<server-name>" -DatabaseName "Latency" -LogFilePath "c:\temp" -DurationHours 120

