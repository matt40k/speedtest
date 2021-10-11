cls
Write-Host "Running from: $PSScriptRoot"
Set-Location $PSScriptRoot

function CleanDate($dt) {
    if ($dt.substring(2,1) -eq "/")
    {
        return "$($dt.substring(6,4))-$($dt.substring(0,2))-$($dt.substring(3,2))T$($dt.substring(11,2)):$($dt.substring(14,2)):$($dt.substring(17,2))Z"
    }
    return $dt
}

if (Test-Path "speedtest.csv") {
    Write-Host "Delete speedtest.csv"
    Remove-Item "speedtest.csv" -Force
}

Write-Host "Combing csv files, fixing dates and order"
Get-ChildItem -File -Filter "202*.csv" | Select-Object -ExpandProperty FullName | Import-Csv | Select-Object DownloadSpeed, UploadSpeed, PacketLoss, ISP, ExternalIPSum, UsedServer, Jitter, Latency, @{Name='Timestamp';Expression={ CleanDate -dt $_.Timestamp }} | Sort-Object -Property Timestamp | Export-Csv .\speedtest.csv -NoTypeInformation -Append
