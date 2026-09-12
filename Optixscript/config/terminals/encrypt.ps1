$host.UI.RawUI.BackgroundColor="Black"
$host.UI.RawUI.ForegroundColor="White"
Clear-Host
$end=(Get-Date).AddSeconds(15)
$rand=[Random]::new()
while((Get-Date) -lt $end){
  Clear-Host
  Write-Host "[ ENCRYPTION ENGINE ]" -ForegroundColor Cyan
  Write-Host "Algorithm: AES-256-GCM" -ForegroundColor Gray
  Write-Host "Mode: CBC" -ForegroundColor Gray
  Write-Host ""
  $k="{0:X8}-{1:X8}-{2:X8}" -f $rand.Next(0,0xFFFFFFFF),$rand.Next(0,0xFFFFFFFF),$rand.Next(0,0xFFFFFFFF)
  Write-Host ("Key: " + $k) -ForegroundColor Yellow
  Write-Host "Status: OK" -ForegroundColor Green
  Start-Sleep -Milliseconds 200
}
exit
