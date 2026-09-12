$host.UI.RawUI.BackgroundColor="Black"
$host.UI.RawUI.ForegroundColor="White"
Clear-Host
$end=(Get-Date).AddSeconds(15)
while((Get-Date) -lt $end){
  Clear-Host
  Write-Host "*** STOP: 0x0000007A ***" -ForegroundColor Cyan
  Write-Host "KERNEL_DATA_INPAGE_ERROR" -ForegroundColor Cyan
  Write-Host ""
  Write-Host "The system encountered an unrecoverable error." -ForegroundColor Gray
  Write-Host "Technical information:" -ForegroundColor Gray
  Write-Host "***  F:\dump_0x0000007A  ***" -ForegroundColor Yellow
  Start-Sleep -Milliseconds 200
}
exit
