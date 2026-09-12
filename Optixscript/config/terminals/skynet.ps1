$host.UI.RawUI.BackgroundColor="Black"
$host.UI.RawUI.ForegroundColor="White"
Clear-Host
$end=(Get-Date).AddSeconds(15)
$msgs=@("[ SKYNET ONLINE ]","[ INITIATING T-800 ]","[ GLOBAL THERMONUCLEAR ]","[ LAUNCH SEQUENCE ]","[ JUDGMENT DAY ]")
$idx=0
while((Get-Date) -lt $end){
  Clear-Host
  Write-Host "================================" -ForegroundColor Red
  Write-Host $msgs[$idx % 5] -ForegroundColor Red
  Write-Host "================================" -ForegroundColor Red
  Write-Host ""
  Write-Host "Connection established." -ForegroundColor Gray
  Write-Host "Targets acquired: 8472" -ForegroundColor Gray
  $idx++
  Start-Sleep -Milliseconds 400
}
exit
