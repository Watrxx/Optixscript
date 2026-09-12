$host.UI.RawUI.BackgroundColor="Black"
$host.UI.RawUI.ForegroundColor="White"
Clear-Host
$end=(Get-Date).AddSeconds(15)
$rand=[Random]::new()
$tasks=@("BYPASSING FIREWALL","INJECTING PAYLOAD","CRACKING HASH","ESCALATING PRIVILEGES","PWNING KERNEL")
$idx=0
while((Get-Date) -lt $end){
  Clear-Host
  $task=$tasks[$idx % 5]
  $idx++
  Write-Host ("[ " + $task + " ]") -ForegroundColor Red
  $pct=$rand.Next(30,99)
  $filled=[int]($pct/5)
  $bar=""
  for($i=0;$i -lt 20;$i++){
    if($i -lt $filled){ $bar+="#" } else { $bar+="-" }
  }
  Write-Host ("[" + $bar + "] " + $pct + "%") -ForegroundColor Green
  Start-Sleep -Milliseconds 200
}
exit
