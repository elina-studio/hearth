# Hearth visualizer: sets up the NucBox (Windows) to render MilkDrop for Hearth.
# Run in PowerShell opened as administrator. The Mac setup (tools/viz/setup-viz.sh) prints the exact command,
# with the helper's house key filled in:
#   $c='<commit>'; & ([scriptblock]::Create((irm https://raw.githubusercontent.com/elina-studio/hearth/$c/tools/viz/install.ps1))) -Commit $c -Token <key>
# What it does: installs Node.js and ffmpeg (winget), puts the renderer in %LOCALAPPDATA%\HearthViz, lets the TV
# reach it on port 8790 (home network only), measures how fast this machine renders, starts the renderer at every
# sign-in, and makes the ready-made loops the NAS plays when this machine is off. Safe to run again.
param(
    [Parameter(Mandatory = $true)][string]$Commit,
    [string]$Token = "",
    [string]$Helper = "http://192.168.254.41:8765",
    [switch]$SkipLoops
)
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"
$Dir = Join-Path $env:LOCALAPPDATA "HearthViz"
$Port = 8790
# an update can leave the key out: it is already in config.json from the first setup
if (-not $Token) {
    $cf = Join-Path $Dir "config.json"
    if (Test-Path $cf) { $Token = (Get-Content $cf -Raw | ConvertFrom-Json).token }
}

function Step($n, $text) { Write-Host ""; Write-Host "[$n/7] $text" -ForegroundColor Yellow }
function Fail($text) { Write-Host ""; Write-Host "STOPPED: $text" -ForegroundColor Red; Write-Host "Send me the lines above."; throw "setup stopped" }
# native tools print progress on stderr, which Windows PowerShell 5.1 treats as an error under "Stop":
# run them through cmd so both streams come back as plain text
function Native($line) { cmd /c "$line 2>&1" }
function Refresh-Path {
    $env:Path = [Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [Environment]::GetEnvironmentVariable("Path", "User") + ";" + (Join-Path $env:LOCALAPPDATA "Microsoft\WinGet\Links")
}

$admin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $admin) { Fail "PowerShell isn't running as administrator. Right-click PowerShell, pick 'Run as administrator', and paste the command again." }
if (-not $Token) { Fail "no house key: this is the first setup on this machine, so use the command the Mac setup prints (it has -Token)." }

Step 1 "Node.js and ffmpeg"
Refresh-Path
if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
    Write-Host "   Installing Node.js (a minute or two)..."
    Native "winget install -e --id OpenJS.NodeJS.LTS --accept-source-agreements --accept-package-agreements --silent" | Out-Host
    Refresh-Path
}
if (-not (Get-Command ffmpeg -ErrorAction SilentlyContinue)) {
    Write-Host "   Installing ffmpeg (a minute or two)..."
    Native "winget install -e --id Gyan.FFmpeg --accept-source-agreements --accept-package-agreements --silent" | Out-Host
    Refresh-Path
}
$node = (Get-Command node -ErrorAction SilentlyContinue)
$ff = (Get-Command ffmpeg -ErrorAction SilentlyContinue)
if (-not $node) { Fail "Node.js didn't install. Close PowerShell, open it again as administrator, and paste the command again." }
if (-not $ff) { Fail "ffmpeg didn't install. Close PowerShell, open it again as administrator, and paste the command again." }
Write-Host ("   Node " + (Native "node --version") + ", ffmpeg at " + $ff.Source)
$edge = @("${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe", "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe") | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $edge) { Fail "Microsoft Edge isn't installed. The renderer draws MilkDrop inside Edge, out of sight." }

Step 2 "Getting the renderer (Hearth $($Commit.Substring(0,7)))"
$tmp = Join-Path $env:TEMP "hearth-viz-dl"
Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory $tmp | Out-Null
Invoke-WebRequest "https://codeload.github.com/elina-studio/hearth/zip/$Commit" -OutFile "$tmp\hearth.zip" -UseBasicParsing
Expand-Archive "$tmp\hearth.zip" -DestinationPath $tmp
$src = Get-ChildItem $tmp -Directory | Where-Object { $_.Name -like "hearth-*" } | Select-Object -First 1
if (-not $src) { Fail "the download didn't unpack." }
# stop a running renderer before replacing its files
Get-ScheduledTask -TaskName "Hearth visualizer" -ErrorAction SilentlyContinue | Stop-ScheduledTask -ErrorAction SilentlyContinue
Get-CimInstance Win32_Process -Filter "Name = 'node.exe'" | Where-Object { $_.CommandLine -like "*HearthViz*" } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
New-Item -ItemType Directory $Dir -Force | Out-Null
Copy-Item (Join-Path $src.FullName "tools\viz\*") $Dir -Recurse -Force
Push-Location $Dir
Native "npm install --omit=dev --no-audit --no-fund" | Out-Host
if ($LASTEXITCODE -ne 0) { Pop-Location; Fail "npm install failed." }
Pop-Location
$cfg = [ordered]@{ helper = $Helper; token = $Token; port = $Port; browser = "msedge"; fps = 30; keep = 6; ffmpeg = $ff.Source }
$old = Join-Path $Dir "config.json"
if (Test-Path $old) {
    $prev = Get-Content $old -Raw | ConvertFrom-Json
    if ($prev.width) { $cfg.width = $prev.width; $cfg.height = $prev.height; $cfg.measuredFps = $prev.measuredFps }
}
$cfg | ConvertTo-Json | Set-Content $old -Encoding ASCII
Write-Host "   Installed in $Dir"

Step 3 "Letting the TV reach the renderer (port $Port, home network only)"
Get-NetFirewallRule -DisplayName "Hearth visualizer" -ErrorAction SilentlyContinue | Remove-NetFirewallRule
New-NetFirewallRule -DisplayName "Hearth visualizer" -Direction Inbound -Protocol TCP -LocalPort $Port -RemoteAddress LocalSubnet -Action Allow -Profile Any | Out-Null
Write-Host "   Done."

Step 4 "Checking the house key with the NAS helper"
try {
    $st = Invoke-RestMethod "$Helper/api/viz/status" -Headers @{ "X-Hearth-Token" = $Token } -TimeoutSec 10
} catch { Fail "the NAS helper didn't accept the key or isn't reachable ($($_.Exception.Message)). Run the Mac setup command first." }
if (-not $st.ffmpeg) { Fail "the NAS helper is the old version (no ffmpeg). Run the Mac setup command first." }
Write-Host "   The helper answered."

Step 5 "Measuring how fast this machine draws MilkDrop (about a minute)"
Push-Location $Dir
$bench = Native "node viz.js bench"
Pop-Location
$bench | Out-Host
$res = ($bench | Select-String "^RESULT").Line
if (-not $res) { Fail "the speed check didn't finish." }
if ($res -like "*SLOW*") {
    Write-Host "   This machine draws too slowly to keep up with a song as it plays, so the TV will use the ready-made loops." -ForegroundColor Yellow
} else {
    Write-Host "   Fast enough: songs get their own MilkDrop, following the beat." -ForegroundColor Green
}

Step 6 "Starting the renderer now and at every sign-in"
$cmd = "Set-Location '$Dir'; & '" + $node.Source + "' viz.js serve *>> '$Dir\serve.log'"
$action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -Command `"$cmd`""
$trigger = New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit ([TimeSpan]::Zero) -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1)
Register-ScheduledTask -TaskName "Hearth visualizer" -Action $action -Trigger $trigger -Settings $settings -Description "Renders MilkDrop for Hearth on the TV" -Force | Out-Null
Start-ScheduledTask -TaskName "Hearth visualizer"
$ok = $false
for ($i = 0; $i -lt 30; $i++) {
    Start-Sleep -Seconds 2
    try { $s = Invoke-RestMethod "http://127.0.0.1:$Port/status" -TimeoutSec 2; if ($s.ok) { $ok = $true; break } } catch {}
}
if (-not $ok) { Fail "the renderer didn't start. Its log is $Dir\serve.log." }
Start-Sleep -Seconds 3
$st = Invoke-RestMethod "$Helper/api/viz/status" -Headers @{ "X-Hearth-Token" = $Token } -TimeoutSec 10
if ($st.nucbox) { Write-Host ("   Running, and the NAS helper sees it at " + $st.nucbox.host + ".") -ForegroundColor Green }
else { Write-Host "   Running, but the NAS helper hasn't heard from it yet. It says hello every minute; check again with the last line below." -ForegroundColor Yellow }

Step 7 "Making the ready-made loops for when this machine is off (about 10 to 20 minutes)"
if ($SkipLoops) {
    Write-Host "   Skipped."
} else {
    Push-Location $Dir
    Native "node viz.js loops" | Out-Host
    Pop-Location
}
$st = Invoke-RestMethod "$Helper/api/viz/status" -Headers @{ "X-Hearth-Token" = $Token } -TimeoutSec 10
Write-Host ""
$nLooks = @(Get-Content (Join-Path $Dir "looks.json") -Raw | ConvertFrom-Json).Count
Write-Host ("ALL DONE. Loops on the NAS: " + $st.loops + " of " + $nLooks + " (the renderer makes any missing ones itself, between songs). Renderer seen by the NAS: " + [bool]$st.nucbox) -ForegroundColor Green
Write-Host "Open Music on the TV, play a song, and pick Visualizer."
