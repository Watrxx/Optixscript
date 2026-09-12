$host.UI.RawUI.BackgroundColor="Black"
$host.UI.RawUI.ForegroundColor="White"
Clear-Host
$end=(Get-Date).AddSeconds(15)
$rand=[Random]::new()
while((Get-Date) -lt $end){
  Clear-Host
  Write-Host "[ MEMORY DUMP ]" -ForegroundColor Red
  Write-Host "Address: 0xFFFF0000" -ForegroundColor Red
  Write-Host ""
  for($i=0;$i -lt 10;$i++){
    $addr="{0:X8}" -f (0xFFFF0000 + ($i*16))
    $hex="{0:X2} {1:X2} {2:X2} {3:X2} {4:X2} {5:X2} {6:X2} {7:X2}" -f $rand.Next(0,256),$rand.Next(0,256),$rand.Next(0,256),$rand.Next(0,256),$rand.Next(0,256),$rand.Next(0,256),$rand.Next(0,256),$rand.Next(0,256)
    Write-Host ($addr + "  " + $hex) -ForegroundColor Yellow
  }
  Start-Sleep -Milliseconds 300
}
exit
