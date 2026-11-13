$py = "$env:LOCALAPPDATA\Programs\Python\Python312\python.exe"
$d = "D:\Projects\CareFlow\.agents\skills\logo-design"
Push-Location $d
& $py scripts/presentation_board.py careflow-spec.json -o careflow-board.html --png-dir careflow-slides 2>&1 | Select-Object -First 10
Get-ChildItem careflow-board.html, careflow-slides | Select-Object Name, Length | Format-Table -AutoSize -Wrap
Pop-Location
