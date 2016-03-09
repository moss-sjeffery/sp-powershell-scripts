Workflow Track-Latency
{
    param 
    (
        $Servers,
        $DurationHours,
        $DatabaseServer
    )

    foreach -parallel ($server in $Servers)
    {
        InlineScript {
            $startTime = [datetime]::Now
            $Ping = New-Object System.Net.NetworkInformation.Ping
            
            while ([datetime]::Now -le $startTime.AddHours($Using:DurationHours)) 
            {
                $dbConnection = New-Object System.Data.SqlClient.SqlConnection("Data Source=$Using:DatabaseServer;Initial Catalog=NET_Latency;Integrated Security=SSPI")
                $dbConnection.Open()
                $dbCmd = New-Object System.Data.SqlClient.SqlCommand
                $dbCmd.Connection = $dbConnection
                $Ping = New-Object System.Net.NetworkInformation.Ping
                $pingSender = $Ping.Send($Using:server)
                $pingTime = Get-Date -Format dd-MM-yy-hh:mm:ss:ms
                $pingRoundTrip = $pingSender.RoundtripTime
                $pingLatency = $pingRoundTrip -as [decimal]
                $pingLatencyRes = $pingLatency  /2
                $pingStatus = $pingSender.Status
                $hostName = $env:COMPUTERNAME
                $dbCmd.CommandText = "INSERT INTO Latency (Host,Destination,Time,LatencyValue,Status) VALUES('{0}','{1}','{2}','{3}','{4}')" -f $hostName,$Using:server,$pingTime,$pingLatencyRes,$pingStatus
                $dbCmd.executenonquery()
                $dbConnection.Close()
                Start-Sleep -Seconds 2
            }
            
        }
    }

}

Track-Latency -Servers "server-1", "server-2", "server-3" -DurationHours 24 -DatabaseServer "sql"


