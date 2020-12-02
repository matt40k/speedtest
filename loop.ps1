$run = 1
$counter = 0
while ($run -eq 1)
{
    $counter += 1
    Write-Host "Loop $counter"
    ./speedtest.ps1
    Start-Sleep -Seconds (15 * 60)
}