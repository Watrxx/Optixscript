$host.UI.RawUI.BackgroundColor="Black"
$host.UI.RawUI.ForegroundColor="White"
Clear-Host
$end=(Get-Date).AddSeconds(15)
$rand=[Random]::new()
while((Get-Date) -lt $end){
  Clear-Host
  Write-Host "[ NMAP SCAN ]" -ForegroundColor Green
  Write-Host "Target: 192.168.1.0/24" -ForegroundColor Gray
  Write-Host ""
  for($i=0;$i -lt 8;$i++){
    $ip="192.168.1." + $rand.Next(1,255)
    $port=$rand.Next(20,9999)
    Write-Host ("[OPEN]  " + $ip + ":" + $port) -ForegroundColor Green
  }
  Start-Sleep -Milliseconds 250
}
exit
