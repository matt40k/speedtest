cls
Write-Host "Running from: $PSScriptRoot"
Set-Location $PSScriptRoot

$SpeedtestBinary = ""

if ($IsWindows -or (!$IsWindows -and !$IsMac -and !$IsLinux)) {
    Write-Host "Running on Windows"
    # Download the speedtest cli (if we haven't already)
    if (!(Test-Path "speedtest.exe"))
    {
        Invoke-WebRequest -Uri "https://bintray.com/ookla/download/download_file?file_path=ookla-speedtest-1.0.0-win64.zip" -OutFile "speedtest.zip"
        Expand-Archive "speedtest.zip" -DestinationPath "./" -Force  
        Remove-Item -Path "speedtest.zip" -Force
        Remove-Item -Path "speedtest.md" -Force
    }
    $SpeedtestBinary = "./speedtest.exe"

} elseif ($IsMacOS) {
    Write-Host "Running on Mac"
    $SpeedtestBinary = "/usr/local/bin/speedtest"
} elseif ($IsLinux) {
    Write-Host "Running on Linux"
} else {
    Write-Host "Running on unknown - aborting"
    throw
}

if (!(Test-Path "isps.csv"))
{
    Set-Content -Path "./isps.csv" -Value "isp"
}
$isps = Import-Csv -Path "./isps.csv"

# Random sleep time
$noOfSecs = (Get-Random -Minimum 3 -Maximum 851)
Write-Host "Sleeping for $($noOfSecs) seconds"
Start-Sleep -Seconds $noOfSecs

# Randomly pick one of the servers from the list
# To add to list: 
# OVH
# Iomart
$servers = @"
[
    { "Id": 32806, "Name": "Mythic Beasts Ltd", "Weight": 12 },
    { "Id": 3731, "Name": "Virgin Media", "Weight": 1 },
    { "Id": 1675, "Name": "Custodian DataCentre", "Weight": 3 }
]
"@ | ConvertFrom-Json

$serverList = @()
$serverList += "Id,Name"
foreach ($server in $servers)
{
    $c = $server.Weight
    if ($c -gt 0)
    {
        while ($c -gt 0)
        {
            $c -= 1
            $serverList += "$($server.Id),$($server.Name)"
        }
    }
}
$serverList = $serverList | ConvertFrom-Csv
$randomNo = (Get-Random -Minimum 0 -Maximum ($serverList.Count -1))
$serverId = $serverList[$randomNo].Id
Write-Host "Server selected: $($serverlist[$randomNo].Name) - Id: $($serverId)"

Write-Host "Running speed test"
$SpeedtestParams = "--format=json --server-id=$serverId --progress=no --accept-license --accept-gdpr"
$resultRaw = (Invoke-Expression "$($SpeedtestBinary) $($SpeedtestParams)")
Write-Host $resultRaw
if ($resultRaw.Length -gt 1) {
$result = $resultRaw | ConvertFrom-Json 
# ExternalIPSum - Answers "Has my public IP changed" question whilst dealing with IP addresses is personal information (GDPR). 
# Split IPv4 address up into 4 numbers and add them together. Don't care what the address is, just if its changed.
$json = @"
[{
    DownloadSpeed : "$([math]::Round($result.download.bandwidth / 1000000 * 8, 4))",
    UploadSpeed   : "$([math]::Round($result.upload.bandwidth / 1000000 * 8, 4))",
    PacketLoss    : "$([math]::Round($result.packetLoss))",
    ISP           : "$($result.isp)",
    ExternalIPSum : "$((($result.interface.externalIp).Split('.') | Measure-Object -Sum).Sum)",
    UsedServer    : "$($result.server.host)",
    Jitter        : "$([math]::Round($result.ping.jitter))",
    Latency       : "$([math]::Round($result.ping.latency))",
    Timestamp     : "$($result.timestamp)"
}]
"@ | ConvertFrom-json
$myIsp = ($result.isp).ToLower().Replace(' ', '_')
$csvFile = "$(Get-Date -Format "yyyyMMdd")_$($myIsp).csv"
# Upload the git repo (jic we are running on multiple devices)
git pull
$json | Select-Object DownloadSpeed,UploadSpeed,PacketLoss,ISP,ExternalIPSum,UsedServer,Jitter,Latency,Timestamp | Export-CSV $csvFile -Append -NoTypeInformation
# Simple way of creating a distinct list of ISPs we are speed testing
$newIsp = 1
foreach ($isp in $isps) { if ($isp.isp -eq $myIsp) { $newIsp = 0 } }
if ($newIsp -eq 1)
{
    Write-Host "Adding new ISP to 'isp.csv'"
    Add-Content -Path "isps.csv" -Value $myIsp
}
Write-Host "Commiting to Git"
git add $csvFile
git add "isps.csv"
git commit -m "Adding results"
Write-Host "Pushing git changes to remote"
git push

} else {
    Write-Host "Invalid response from Speedtest Cli"
}