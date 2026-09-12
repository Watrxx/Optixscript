$host.UI.RawUI.BackgroundColor="Black"
$host.UI.RawUI.ForegroundColor="White"
Clear-Host
$end=(Get-Date).AddSeconds(15)
$lines=@("Never gonna give you up","Never gonna let you down","Never gonna run around","and desert you")
$i=0
while((Get-Date) -lt $end){
  Clear-Host
  Write-Host "==================" -ForegroundColor Magenta
  Write-Host "  RICK ASTLEY HD  " -ForegroundColor Magenta
  Write-Host "==================" -ForegroundColor Magenta
  Write-Host ""
  $line=$lines[$i % 4]
  Write-Host $line -ForegroundColor Yellow
  $i++
  Start-Sleep -Milliseconds 500
}
exit
