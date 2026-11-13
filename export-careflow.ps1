$py = "$env:LOCALAPPDATA\Programs\Python\Python312\python.exe"
$d = "D:\Projects\CareFlow\.agents\skills\logo-design"
Push-Location $d
mkdir dist -Force | Out-Null
& $py scripts/export_variants.py careflow-symbol.svg `
  --name careflow --title "CareFlow logo" `
  --mono "#2563EB" --icon-bg "#2563EB" --icon-fg "#FFFFFF" `
  --png 32 512 1024 --web-icons --out-dir dist
Get-ChildItem dist | Select-Object Name, Length | Format-Table -AutoSize -Wrap
Pop-Location
