$host.UI.RawUI.BackgroundColor="Black"
$host.UI.RawUI.ForegroundColor="White"
Clear-Host
$end=(Get-Date).AddSeconds(15)
$rand=[Random]::new()
$chars="01AE"
while((Get-Date) -lt $end){
  Clear-Host
  for($i=0;$i -lt 60;$i++){
    [Console]::SetCursorPosition($i,$rand.Next(0,15))
    $ch=$chars[$rand.Next(0,4)]
    Write-Host $ch -ForegroundColor Green -NoNewline
  }
  Start-Sleep -Milliseconds 25
}
exit
