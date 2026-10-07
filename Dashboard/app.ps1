# SPP Dashboard desktop app - tray icon + Edge app window around dashboard.ps1
# Started by "SPP Dashboard.vbs" (no console window). Windows PowerShell 5.1, no installs needed.
#   (no args)  start the dashboard in the background, put an icon in the tray and open the app window
#   -Tray      same, without opening the window (used by Start with Windows)
#   -Install   create the Desktop and Start menu shortcuts, then exit
param([switch]$Tray, [switch]$Install)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms, System.Drawing

$DashDir     = Split-Path -Parent $MyInvocation.MyCommand.Path
$IconFile    = Join-Path $DashDir 'app.ico'
$Launcher    = Join-Path $DashDir 'SPP Dashboard.vbs'
$LogDir      = Join-Path $DashDir 'logs'
$AppLog      = Join-Path $LogDir 'app.log'
$EdgeProfile = Join-Path $env:LOCALAPPDATA 'SPP_Dashboard\edge'
$StartupLnk  = Join-Path ([Environment]::GetFolderPath('Startup')) 'SPP Dashboard.lnk'
if (-not (Test-Path $LogDir)) { New-Item -ItemType Directory $LogDir | Out-Null }

$Port = 8099
try { $j = Get-Content (Join-Path $DashDir 'dashboard.json') -Raw | ConvertFrom-Json; if ($j.port) { $Port = [int]$j.port } } catch {}
$Base = "http://localhost:$Port"

function Log([string]$msg) { try { Add-Content -Path $AppLog -Value ((Get-Date -Format 'yyyy-MM-dd HH:mm:ss') + ' ' + $msg) } catch {} }

Add-Type -Namespace SppApp -Name Win -MemberDefinition @'
[DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
[DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int cmd);
[DllImport("user32.dll")] public static extern bool IsIconic(IntPtr h);
'@

# ---------------------------------------------------------------- icon
# Gold shield with a sword on a dark rounded square (dashboard colours). $dot adds a status light.
function New-AppBitmap([int]$s, [string]$dot = '') {
    $b = New-Object System.Drawing.Bitmap $s, $s
    $g = [System.Drawing.Graphics]::FromImage($b)
    $g.SmoothingMode = 'AntiAlias'; $g.Clear([System.Drawing.Color]::Transparent)
    $hex = { param($h) [System.Drawing.ColorTranslator]::FromHtml($h) }
    # background
    $r = [single]($s * 0.22); $w = [single]($s - 1)
    $bg = New-Object System.Drawing.Drawing2D.GraphicsPath
    $bg.AddArc(0, 0, 2 * $r, 2 * $r, 180, 90); $bg.AddArc($w - 2 * $r, 0, 2 * $r, 2 * $r, 270, 90)
    $bg.AddArc($w - 2 * $r, $w - 2 * $r, 2 * $r, 2 * $r, 0, 90); $bg.AddArc(0, $w - 2 * $r, 2 * $r, 2 * $r, 90, 90); $bg.CloseFigure()
    $g.FillPath((New-Object System.Drawing.SolidBrush (& $hex '#171b24')), $bg)
    if ($s -ge 32) { $g.DrawPath((New-Object System.Drawing.Pen ((& $hex '#3a3220'), [single]($s / 32))), $bg) }
    # shield
    $p = { param($x, $y) New-Object System.Drawing.PointF ([single]($x * $s)), ([single]($y * $s)) }
    $sh = New-Object System.Drawing.Drawing2D.GraphicsPath
    $sh.AddLine((& $p 0.22 0.17), (& $p 0.78 0.17))
    $sh.AddLine((& $p 0.78 0.17), (& $p 0.78 0.48))
    $sh.AddBezier((& $p 0.78 0.48), (& $p 0.78 0.70), (& $p 0.62 0.80), (& $p 0.50 0.87))
    $sh.AddBezier((& $p 0.50 0.87), (& $p 0.38 0.80), (& $p 0.22 0.70), (& $p 0.22 0.48))
    $sh.CloseFigure()
    $gold = New-Object System.Drawing.Drawing2D.LinearGradientBrush ((& $p 0 0.17), (& $p 0 0.87), (& $hex '#f6d58a'), (& $hex '#c9942e'))
    $g.FillPath($gold, $sh)
    # sword
    $dark = New-Object System.Drawing.SolidBrush (& $hex '#171b24')
    # sword, point down: pommel, grip, crossguard, tapered blade
    $u = [Math]::Max(1.0, $s * 0.045)
    $g.FillEllipse($dark, [single](0.5 * $s - 1.3 * $u), [single](0.22 * $s), [single](2.6 * $u), [single](2.6 * $u))
    $g.FillRectangle($dark, [single](0.5 * $s - 0.8 * $u), [single](0.25 * $s), [single](1.6 * $u), [single](0.10 * $s))
    $g.FillRectangle($dark, [single](0.36 * $s), [single](0.34 * $s), [single](0.28 * $s), [single](1.6 * $u))
    $g.FillPolygon($dark, [System.Drawing.PointF[]]@((& $p 0.455 0.36), (& $p 0.545 0.36), (& $p 0.545 0.68), (& $p 0.50 0.77), (& $p 0.455 0.68)))
    # status light
    if ($dot) {
        $d = $s * 0.42; $x = $s - $d
        $g.FillEllipse($dark, [single]($x - $s * 0.04), [single]($x - $s * 0.04), [single]($d + $s * 0.04), [single]($d + $s * 0.04))
        $g.FillEllipse((New-Object System.Drawing.SolidBrush (& $hex $dot)), [single]$x, [single]$x, [single]($d - $s * 0.04), [single]($d - $s * 0.04))
    }
    $g.Dispose()
    return $b
}

# .ico with PNG entries (Vista+), so it stays sharp at every size
function Save-AppIcon([string]$path) {
    $sizes = 16, 24, 32, 48, 64, 256
    $pngs = foreach ($s in $sizes) { $ms = New-Object System.IO.MemoryStream; $bmp = New-AppBitmap $s; $bmp.Save($ms, [System.Drawing.Imaging.ImageFormat]::Png); $bmp.Dispose(); , $ms.ToArray() }
    $out = New-Object System.IO.MemoryStream; $bw = New-Object System.IO.BinaryWriter $out
    $bw.Write([uint16]0); $bw.Write([uint16]1); $bw.Write([uint16]$sizes.Count)
    $offset = 6 + 16 * $sizes.Count
    for ($i = 0; $i -lt $sizes.Count; $i++) {
        $dim = if ($sizes[$i] -ge 256) { 0 } else { $sizes[$i] }
        $bw.Write([byte]$dim); $bw.Write([byte]$dim); $bw.Write([byte]0); $bw.Write([byte]0)
        $bw.Write([uint16]1); $bw.Write([uint16]32); $bw.Write([uint32]$pngs[$i].Length); $bw.Write([uint32]$offset)
        $offset += $pngs[$i].Length
    }
    foreach ($png in $pngs) { $bw.Write([byte[]]$png) }
    $bw.Flush(); [System.IO.File]::WriteAllBytes($path, $out.ToArray())
}

# ---------------------------------------------------------------- shortcuts
function New-Shortcut([string]$lnk, [string]$arguments = '') {
    $sc = (New-Object -ComObject WScript.Shell).CreateShortcut($lnk)
    $sc.TargetPath = Join-Path $env:WINDIR 'System32\wscript.exe'
    $sc.Arguments = ('"' + $Launcher + '" ' + $arguments).Trim()
    $sc.WorkingDirectory = $DashDir
    $sc.IconLocation = "$IconFile,0"
    $sc.Description = 'SPP Classics V2 server dashboard'
    $sc.Save()
}

if (-not (Test-Path $IconFile)) { Save-AppIcon $IconFile }
if ($Install) {
    New-Shortcut (Join-Path ([Environment]::GetFolderPath('Desktop')) 'SPP Dashboard.lnk')
    New-Shortcut (Join-Path ([Environment]::GetFolderPath('Programs')) 'SPP Dashboard.lnk')
    return
}

# ---------------------------------------------------------------- app window (Edge in app mode, own profile)
function Get-EdgePath {
    foreach ($k in 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\msedge.exe', 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\msedge.exe') {
        try { $v = (Get-ItemProperty $k -ErrorAction Stop).'(default)'; if ($v -and (Test-Path $v)) { return $v } } catch {}
    }
    $p = Join-Path ${env:ProgramFiles(x86)} 'Microsoft\Edge\Application\msedge.exe'
    if (Test-Path $p) { return $p }
    return $null
}
function Find-AppWindow {
    $procs = @(Get-CimInstance Win32_Process -Filter "Name = 'msedge.exe'" -ErrorAction SilentlyContinue |
        Where-Object { $_.CommandLine -and $_.CommandLine.Contains($EdgeProfile) -and $_.CommandLine -notmatch '--type=' })
    foreach ($cp in $procs) {
        $p = Get-Process -Id $cp.ProcessId -ErrorAction SilentlyContinue
        if ($p -and $p.MainWindowHandle -ne [IntPtr]::Zero) { return $p.MainWindowHandle }
    }
    return [IntPtr]::Zero
}
function Test-Dash {
    $c = New-Object System.Net.Sockets.TcpClient
    try { $c.Connect('127.0.0.1', $Port); return $true } catch { return $false } finally { $c.Close() }
}
function Open-Window {
    $h = Find-AppWindow
    if ($h -ne [IntPtr]::Zero) {
        if ([SppApp.Win]::IsIconic($h)) { [void][SppApp.Win]::ShowWindow($h, 9) }
        [void][SppApp.Win]::SetForegroundWindow($h); return
    }
    for ($i = 0; $i -lt 40 -and -not (Test-Dash); $i++) { Start-Sleep -Milliseconds 250 }
    $edge = Get-EdgePath
    if ($edge) {
        Start-Process $edge -ArgumentList @("--app=$Base/", "--user-data-dir=`"$EdgeProfile`"", '--no-first-run', '--no-default-browser-check', '--window-size=1280,860')
    } else { Start-Process "$Base/" }
}

# A second launch (shortcut clicked again) just brings the window forward
$mutex = New-Object System.Threading.Mutex($false, 'Local\SPP_Dashboard_App')
$owned = $false
try { $owned = $mutex.WaitOne(0) } catch [System.Threading.AbandonedMutexException] { $owned = $true }
if (-not $owned) { if (-not $Tray) { Open-Window }; return }

# ---------------------------------------------------------------- dashboard process
$script:DashProc = $null
$script:DashRestarts = @()
function Start-Dash {
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = 'powershell.exe'
    $psi.Arguments = '-NoProfile -ExecutionPolicy Bypass -File "' + (Join-Path $DashDir 'dashboard.ps1') + '" -Background'
    $psi.WorkingDirectory = $DashDir
    $psi.UseShellExecute = $false; $psi.CreateNoWindow = $true
    $script:DashProc = [System.Diagnostics.Process]::Start($psi)
    Log "dashboard started, pid $($script:DashProc.Id)"
}
function Stop-Dash {
    if ($script:DashProc -and -not $script:DashProc.HasExited) { try { $script:DashProc.Kill(); $script:DashProc.WaitForExit(3000) | Out-Null } catch {} }
}
function Invoke-Api([string]$path, $body = $null) {
    $req = [System.Net.HttpWebRequest]::Create("$Base$path")
    $req.Timeout = 4000; $req.ReadWriteTimeout = 4000
    if ($body -ne $null) {
        $req.Method = 'POST'; $req.ContentType = 'application/json'; $req.Headers.Add('X-SPP', '1')
        $bytes = [System.Text.Encoding]::UTF8.GetBytes((ConvertTo-Json $body -Compress))
        $st = $req.GetRequestStream(); $st.Write($bytes, 0, $bytes.Length); $st.Close()
    }
    try { $resp = $req.GetResponse() }
    catch [System.Net.WebException] {
        if (-not $_.Exception.Response) { throw }
        $t = (New-Object System.IO.StreamReader $_.Exception.Response.GetResponseStream()).ReadToEnd()
        $msg = $t
        try { $e = ($t | ConvertFrom-Json).error; if ($e) { $msg = $e } } catch {}
        if (-not $msg) { $msg = $_.Exception.Message }
        throw $msg
    }
    $t = (New-Object System.IO.StreamReader $resp.GetResponseStream()).ReadToEnd(); $resp.Close()
    return ($t | ConvertFrom-Json)
}

if (Test-Dash) { Log 'dashboard already running - using it' } else { Start-Dash }

# ---------------------------------------------------------------- tray
[System.Windows.Forms.Application]::EnableVisualStyles()
$small = [System.Windows.Forms.SystemInformation]::SmallIconSize.Width
$Icons = @{}
foreach ($k in @{ off = ''; up = '#4cc38a'; busy = '#f0a443'; crash = '#ef5b5b' }.GetEnumerator()) {
    $bmp = New-AppBitmap $small $k.Value; $Icons[$k.Key] = [System.Drawing.Icon]::FromHandle($bmp.GetHicon())
}
$ni = New-Object System.Windows.Forms.NotifyIcon
$ni.Icon = $Icons.off; $ni.Text = 'SPP Dashboard - starting...'; $ni.Visible = $true

$menu = New-Object System.Windows.Forms.ContextMenuStrip
function Add-Item([string]$text, [scriptblock]$onClick) {
    $it = New-Object System.Windows.Forms.ToolStripMenuItem $text
    $it.Tag = $onClick
    $it.add_Click({ try { & $this.Tag } catch { Log ("menu: " + $_.Exception.Message); Show-Error $_.Exception.Message } })
    [void]$menu.Items.Add($it); return $it
}
function Show-Error([string]$msg) { [void][System.Windows.Forms.MessageBox]::Show($msg, 'SPP Dashboard', [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning) }
function Ask([string]$msg) {
    $r = [System.Windows.Forms.MessageBox]::Show($msg, 'SPP Dashboard', [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Question)
    return $r -eq [System.Windows.Forms.DialogResult]::Yes
}
function Need-Ra {
    if ($script:Last -and $script:Last.raConfigured) { return $true }
    if (Ask "Stopping the server cleanly needs the GM account for the remote console.`n`nOpen the dashboard to set it up (Settings > Dashboard)?") { Open-Window }
    return $false
}

$miOpen = Add-Item 'Open dashboard' { Open-Window }
$miOpen.Font = New-Object System.Drawing.Font $miOpen.Font, ([System.Drawing.FontStyle]::Bold)
[void]$menu.Items.Add((New-Object System.Windows.Forms.ToolStripSeparator))
$miStatus = Add-Item 'Status: connecting...' {}; $miStatus.Enabled = $false
$miStart = Add-Item 'Start server' { [void](Invoke-Api '/api/server/start' @{}) ; $ni.ShowBalloonTip(3000, 'SPP Dashboard', 'Starting the server - the world takes a few minutes to load.', 'Info') }
$miRestart = Add-Item 'Restart server' { if ((Need-Ra) -and (Ask 'Restart the server in 10 seconds? Characters are saved first.')) { [void](Invoke-Api '/api/server/restart' @{ delay = 10 }) } }
$miStop = Add-Item 'Stop server' { if ((Need-Ra) -and (Ask 'Stop the server in 10 seconds? Characters are saved first.')) { [void](Invoke-Api '/api/server/stop' @{ delay = 10 }) } }
[void]$menu.Items.Add((New-Object System.Windows.Forms.ToolStripSeparator))
$miAuto = Add-Item 'Start with Windows' {
    if (Test-Path $StartupLnk) { Remove-Item $StartupLnk } else { New-Shortcut $StartupLnk '-Tray' }
    $miAuto.Checked = Test-Path $StartupLnk
}
$miAuto.Checked = Test-Path $StartupLnk
[void]$menu.Items.Add((New-Object System.Windows.Forms.ToolStripSeparator))
$miQuit = Add-Item 'Quit dashboard' {
    if ($script:Last -and $script:Last.world.running) {
        if (-not (Ask "Quit the dashboard?`n`nThe game server keeps running in the background. Auto-restart on crash is off until you open the dashboard again.")) { return }
    }
    $script:Quitting = $true
    $timer.Stop(); Stop-Dash; $ni.Visible = $false; $ni.Dispose()
    [System.Windows.Forms.Application]::Exit()
}
$ni.ContextMenuStrip = $menu
$ni.add_MouseDoubleClick({ if ($_.Button -eq 'Left') { Open-Window } })
$ni.add_BalloonTipClicked({ Open-Window })

# ---------------------------------------------------------------- status polling
$script:Last = $null; $script:SeenCrash = $null; $script:Quitting = $false
function Update-Tray {
    $s = $null
    try { $s = Invoke-Api '/api/status' } catch {}
    if (-not $s) {
        $script:Last = $null
        $ni.Icon = $Icons.off; $ni.Text = 'SPP Dashboard - not responding'; $miStatus.Text = 'Dashboard not responding'
        $miStart.Enabled = $false; $miStop.Enabled = $false; $miRestart.Enabled = $false
        # restart our own dashboard if it died (max 3 times in 10 minutes)
        if ($script:DashProc -and $script:DashProc.HasExited -and -not $script:Quitting) {
            $script:DashRestarts = @($script:DashRestarts | Where-Object { ((Get-Date) - $_).TotalMinutes -lt 10 })
            if ($script:DashRestarts.Count -lt 3) {
                Log "dashboard exited (code $($script:DashProc.ExitCode)) - restarting"
                $script:DashRestarts += Get-Date; Start-Dash
            } elseif ($script:DashProc) {
                Log 'dashboard keeps exiting - giving up, see logs\dashboard.log'
                $ni.ShowBalloonTip(8000, 'SPP Dashboard', 'The dashboard keeps stopping. See Dashboard\logs\dashboard.log.', 'Error')
                $script:DashProc = $null
            }
        }
        return
    }
    $world = $s.world
    $busy = $s.action -ne 'idle'
    if ($busy) { $state = 'busy'; $txt = if ($s.message) { $s.message } else { $s.action } }
    elseif ($world.running -and $world.ready) {
        $state = 'up'; $n = $s.online
        $txt = if ($n) { "Online - $($n.players) player$(if ($n.players -ne 1) {'s'}), $($n.bots) bots" } else { 'Online' }
    }
    elseif ($world.running) { $state = 'busy'; $txt = 'Loading the world...' }
    elseif ($s.message -match 'unexpectedly|crash') { $state = 'crash'; $txt = 'World server crashed' }
    else { $state = 'off'; $txt = 'Server stopped' }
    $ni.Icon = $Icons[$state]
    $tip = "SPP - $txt"; if ($tip.Length -gt 63) { $tip = $tip.Substring(0, 60) + '...' }
    $ni.Text = $tip; $miStatus.Text = $txt
    $miStart.Enabled = (-not $busy) -and (-not $world.running)
    $miStop.Enabled = (-not $busy) -and $world.running
    $miRestart.Enabled = $miStop.Enabled

    # notifications
    $crash = if ($s.lastCrash) { $s.lastCrash.name } else { '' }
    if ($script:SeenCrash -ne $null -and $crash -and $crash -ne $script:SeenCrash) {
        $more = if ($s.watchdog) { 'Auto-restart is on - restarting.' } else { 'Click to open the dashboard.' }
        $ni.ShowBalloonTip(10000, 'World server crashed', "$($s.lastCrash.where)`n$more", 'Error')
    }
    $script:SeenCrash = $crash
    if ($script:Last -and $script:Last.action -eq 'starting' -and -not $busy -and $world.ready) {
        $ni.ShowBalloonTip(4000, 'SPP Dashboard', 'Server is up - you can log in.', 'Info')
    }
    $script:Last = $s
}
$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 3000
$timer.add_Tick({ try { Update-Tray } catch { Log ("tick: " + $_.Exception.Message) } })
$timer.Start()

if (-not $Tray) { Open-Window }
try { Update-Tray } catch { Log ("tick: " + $_.Exception.Message) }
Log 'app started'
[System.Windows.Forms.Application]::Run()
$mutex.ReleaseMutex()
