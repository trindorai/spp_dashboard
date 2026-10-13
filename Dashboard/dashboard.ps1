# SPP Dashboard - local web control panel for SPP Classics V2 (WotLK)
# Runs on Windows PowerShell 5.1+, no installs needed. Serves http://localhost:<port>/
# -Background: started by the desktop app (app.ps1) with no console - no browser, no prompts, output to logs\dashboard.log
param([int]$Port = 0, [switch]$NoBrowser, [switch]$Background, [string]$RootOverride = '')

$ErrorActionPreference = 'Stop'
Set-StrictMode -Off

# ---------------------------------------------------------------- paths
$DashDir   = Split-Path -Parent $MyInvocation.MyCommand.Path
$Root      = if ($RootOverride) { $RootOverride } else { Split-Path -Parent $DashDir }
$Spp       = Join-Path $Root 'SPP_Server'
$Exp       = 'wotlk'
$SettingsDir = Join-Path $Spp "Settings\$Exp"
$BinDir    = Join-Path $Spp "Server\Binaries\$Exp\Bin64"
$CrashDir  = Join-Path $BinDir 'Crashes'
$LogFile   = Join-Path $SettingsDir 'logs\Server.log'
$MysqlExe  = Join-Path $Spp 'Server\Database\bin\mysql.exe'
$TweaksDir = Join-Path $Root 'Tweaks'      # shared SQL fixes (in the repo)
$MyTweaksDir = Join-Path $Root 'MyTweaks'  # personal SQL (git-ignored); also gets apply_sql_log.txt
$WebDir    = Join-Path $DashDir 'web'
$CfgFile   = Join-Path $DashDir 'dashboard.json'
$ConfFiles = @{ mangosd = (Join-Path $SettingsDir 'mangosd.conf'); aiplayerbot = (Join-Path $SettingsDir 'aiplayerbot.conf') }
if ([System.IO.Path]::DirectorySeparatorChar -eq '/') {
    # test mode on Linux: normalise path separators
    foreach ($v in 'SettingsDir','BinDir','CrashDir','LogFile','MysqlExe') { Set-Variable $v ((Get-Variable $v).Value -replace '\\','/') }
    $ConfFiles.mangosd = $ConfFiles.mangosd -replace '\\','/'; $ConfFiles.aiplayerbot = $ConfFiles.aiplayerbot -replace '\\','/'
}

# ---------------------------------------------------------------- dashboard config
function Load-Cfg {
    $d = @{ port = 8099; raUser = ''; raPass = ''; watchdog = $false; startAutosave = $true; hideWindows = $true; botLevelSync = $false; botLevelRange = 5; botLevelBelow = $null; botLevelAbove = $null;
            restartDaily = $false; restartTime = '04:00'; restartSkipPlayers = $true; restartWarn = 10; restartLast = '';
            autoKickStuck = $true; startTweaks = @();
            logFilters = @('spell #75460','Path empty','game_graveyard_zone','already existing cooldown','lost references','too far away from player','MoveSplineInitArgs') }
    if (Test-Path $CfgFile) {
        try {
            $j = Get-Content $CfgFile -Raw | ConvertFrom-Json
            foreach ($p in $j.PSObject.Properties) { $d[$p.Name] = $p.Value }
        } catch { Write-Host "dashboard.json unreadable, using defaults" }
    }
    return $d
}
function Save-Cfg { ($Cfg | ConvertTo-Json -Depth 5) | Set-Content -Path $CfgFile -Encoding UTF8 }
$Cfg = Load-Cfg
if ($Port -gt 0) { $Cfg.port = $Port }

# ---------------------------------------------------------------- conf file helpers
function Read-ConfValue([string]$file, [string]$key) {
    $pat = '^\s*' + [regex]::Escape($key) + '\s*=\s*(.*?)\s*$'
    foreach ($line in [System.IO.File]::ReadAllLines($ConfFiles[$file])) {
        $m = [regex]::Match($line, $pat)
        if ($m.Success) { return $m.Groups[1].Value }
    }
    return $null
}
function Get-DbInfo([string]$key) {
    $v = (Read-ConfValue 'mangosd' $key).Trim('"')
    $p = $v.Split(';')
    return @{ host = $p[0]; port = $p[1]; user = $p[2]; pass = $p[3]; db = $p[4] }
}
function Write-ConfValues([string]$file, $changes, [switch]$AddMissing) {
    # $changes: hashtable key -> raw value text. Keeps CRLF and all other lines untouched. Backs up first.
    $path = $ConfFiles[$file]
    $bdir = Join-Path $SettingsDir 'backups'
    if (-not (Test-Path $bdir)) { New-Item -ItemType Directory -Path $bdir | Out-Null }
    $stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    Copy-Item $path (Join-Path $bdir ("{0}.{1}.bak" -f (Split-Path $path -Leaf), $stamp))
    $text = [System.IO.File]::ReadAllText($path)
    $done = @()
    foreach ($k in $changes.Keys) {
        $pat = '(?m)^([ \t]*' + [regex]::Escape($k) + '[ \t]*=[ \t]*)([^\r\n]*?)([ \t]*\r?)$'
        $re = New-Object System.Text.RegularExpressions.Regex($pat)
        if ($re.IsMatch($text)) {
            $script:__val = [string]$changes[$k]
            $text = $re.Replace($text, { param($m) $m.Groups[1].Value + $script:__val + $m.Groups[3].Value }, 1)
            $done += $k
        } elseif ($AddMissing) {
            $nl = if ($text.Contains("`r`n")) { "`r`n" } else { "`n" }
            if (-not $text.EndsWith($nl)) { $text += $nl }
            $text += ('{0} = {1}{2}' -f $k, $changes[$k], $nl); $done += $k
        }
    }
    [System.IO.File]::WriteAllText($path, $text, (New-Object System.Text.UTF8Encoding($false)))
    return ,$done
}

# curated settings shown in the UI
$SettingDefs = @(
  @{g='Gameplay'; f='mangosd'; k='GameType'; label='Realm type'; type='select'; options=@(@{v='0';t='PvE'},@{v='1';t='PvP'},@{v='6';t='RP'},@{v='8';t='RP-PvP'}); help='PvE: no forced PvP flag in contested zones.'},
  @{g='Gameplay'; f='mangosd'; k='Rate.XP.Kill'; label='XP from kills'; type='num'; min=0.5; max=10; step=0.5; help='Multiplier. 1 = original.'},
  @{g='Gameplay'; f='mangosd'; k='Rate.XP.Quest'; label='XP from quests'; type='num'; min=0.5; max=10; step=0.5; help='Multiplier. 1 = original.'},
  @{g='Gameplay'; f='mangosd'; k='Rate.XP.Explore'; label='XP from exploring'; type='num'; min=0.5; max=10; step=0.5; help='Multiplier. 1 = original.'},
  @{g='Gameplay'; f='mangosd'; k='Rate.Rest.InGame'; label='Rested XP gain'; type='num'; min=0.5; max=10; step=0.5; help='How fast rested XP builds while logged in.'},
  @{g='Gameplay'; f='mangosd'; k='Rate.Health'; label='Health regen'; type='num'; min=0.5; max=10; step=0.5; help='Out-of-combat health regeneration multiplier.'},
  @{g='Gameplay'; f='mangosd'; k='Rate.Mana'; label='Mana regen'; type='num'; min=0.5; max=10; step=0.5; help='Mana regeneration multiplier (also in combat).'},
  @{g='Gameplay'; f='mangosd'; k='Rate.Drop.Item.Quest'; label='Quest item drop rate'; type='num'; min=1; max=5; step=0.5; help='Multiplies quest item drop chance (capped at 100%).'},
  @{g='Gameplay'; f='mangosd'; k='Rate.Drop.Money'; label='Gold drops'; type='num'; min=0.5; max=5; step=0.5; help='Money dropped by mobs.'},
  @{g='Gameplay'; f='mangosd'; k='Rate.Reputation.Gain'; label='Reputation gain'; type='num'; min=0.5; max=5; step=0.5; help='Multiplier.'},
  @{g='Creatures'; f='mangosd'; k='Rate.Creature.Aggro'; label='Aggro range'; type='num'; min=0; max=2; step=0.05; help='0.5 = half distance, 0 = mobs never aggro on sight.'},
  @{g='Creatures'; f='mangosd'; k='CreatureFamilyAssistanceRadius'; label='Call-for-help radius'; type='num'; min=0; max=30; step=1; unit='yd'; help='How far a mob in combat pulls nearby allies.'},
  @{g='Creatures'; f='mangosd'; k='CreatureFamilyFleeAssistanceRadius'; label='Flee-for-help radius'; type='num'; min=0; max=60; step=1; unit='yd'; help='How far a fleeing mob runs to fetch help.'},
  @{g='Creatures'; f='mangosd'; k='Rate.Creature.Normal.HP'; label='Normal mob health'; type='num'; min=0.5; max=3; step=0.1; help='Health multiplier for normal mobs.'},
  @{g='Creatures'; f='mangosd'; k='Rate.Creature.Normal.Damage'; label='Normal mob damage'; type='num'; min=0.5; max=3; step=0.1; help='Damage multiplier for normal mobs.'},
  @{g='Dungeons'; f='mangosd'; k='Solocraft.Enable'; label='SoloCraft'; type='bool'; help='Buffs players inside instances based on how many are missing from the group.'},
  @{g='Dungeons'; f='mangosd'; k='Rate.InstanceResetTime'; label='Raid/heroic reset interval'; type='num'; min=0.1; max=2; step=0.1; help='Multiplier for days between lockout resets.'},
  @{g='Dungeons'; f='mangosd'; k='Channel.RestrictedLfg'; label='Restrict LookingForGroup channel'; type='bool'; help='Off = you can always type "lfg" there to recruit bots.'},
  @{g='Characters'; f='mangosd'; k='PlayerSave.Interval'; label='Character autosave'; type='num'; min=1; max=15; step=1; scale=60000; unit='min'; help='How often characters are saved to the database.'},
  @{g='Characters'; f='mangosd'; k='MinLevelForHeroicCharacterCreating'; label='Level needed for a Death Knight'; type='num'; min=0; max=80; step=1; help='Another character on the account needs this level (GM accounts skip it).'},
  @{g='Bots'; f='aiplayerbot'; k='AiPlayerbot.MinRandomBots'; label='Random bots (min)'; type='num'; min=0; max=3000; step=50; help='More bots = busier world, more CPU/RAM and crash risk.'},
  @{g='Bots'; f='aiplayerbot'; k='AiPlayerbot.MaxRandomBots'; label='Random bots (max)'; type='num'; min=0; max=3000; step=50; help='Keep equal to min for a stable count.'},
  @{g='Bots'; f='aiplayerbot'; k='AiPlayerbot.botActiveAlone'; label='Bots active away from you'; type='num'; min=0; max=100; step=5; unit='%'; help='Share of far-away bots that are fully simulated.'},
  @{g='Bots'; f='aiplayerbot'; k='AiPlayerbot.RandomBotMinLevel'; label='Bot min level'; type='num'; min=1; max=80; step=1; help=''},
  @{g='Bots'; f='aiplayerbot'; k='AiPlayerbot.RandomBotMaxLevel'; label='Bot max level'; type='num'; min=1; max=80; step=1; help=''},
  @{g='Bots'; f='aiplayerbot'; k='AiPlayerbot.RandomBotJoinLfg'; label='Bots use Dungeon Finder'; type='bool'; help='This build only pops full 5-player groups.'},
  @{g='Bots'; f='aiplayerbot'; k='AiPlayerbot.RandomBotJoinBG'; label='Bots join battlegrounds'; type='bool'; help=''},
  @{g='Bots'; f='aiplayerbot'; k='AiPlayerbot.RandomBotInvitePlayer'; label='Bots invite you to groups/guilds'; type='bool'; help='Also suppressed while you are /dnd.'},
  @{g='Bots'; f='aiplayerbot'; k='AiPlayerbot.RandomBotGroupNearby'; label='Bots group with each other'; type='bool'; help=''},
  @{g='Bots'; f='aiplayerbot'; k='AiPlayerbot.RandomBotFormGuild'; label='Bots form guilds'; type='bool'; help=''},
  @{g='Admin'; f='mangosd'; k='GmLogFile'; label='Log GM commands to gm.log'; type='strbool'; on='"gm.log"'; off='""'; help='Records every GM command with time and account.'},
  @{g='Admin'; f='mangosd'; k='Ra.Enable'; label='Remote console'; type='bool'; help='Required by this dashboard to stop the server cleanly and run GM commands.'}
)

# ---------------------------------------------------------------- process helpers
function Run-Proc([string]$file, [string]$arguments, [string]$stdin = $null, [int]$timeoutMs = 60000) {
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $file; $psi.Arguments = $arguments
    $psi.UseShellExecute = $false; $psi.CreateNoWindow = $true
    $psi.RedirectStandardOutput = $true; $psi.RedirectStandardError = $true
    $psi.RedirectStandardInput = ($stdin -ne $null -and $stdin -ne '')
    $psi.StandardOutputEncoding = [System.Text.Encoding]::UTF8
    $p = [System.Diagnostics.Process]::Start($psi)
    $outTask = $p.StandardOutput.ReadToEndAsync(); $errTask = $p.StandardError.ReadToEndAsync()
    if ($psi.RedirectStandardInput) { $p.StandardInput.Write($stdin); $p.StandardInput.Close() }
    if (-not $p.WaitForExit($timeoutMs)) { try { $p.Kill() } catch {} ; return @{ code = -1; out = ''; err = 'timeout' } }
    $p.WaitForExit()
    $err = (($errTask.Result -split "`r?`n") | Where-Object { $_ -and $_ -notmatch 'Using a password on the command line' }) -join "`n"
    return @{ code = $p.ExitCode; out = $outTask.Result; err = $err }
}
function Invoke-Sql([string]$query, [string]$db = '', [switch]$Table) {
    $i = Get-DbInfo 'WorldDatabaseInfo'
    $fmt = if ($Table) { '-t' } else { '-B -N' }
    $a = "-h{0} -P{1} -u{2} -p{3} --default-character-set=utf8 {4} {5}" -f $i.host, $i.port, $i.user, $i.pass, $fmt, $db
    return Run-Proc $MysqlExe $a $query 30000
}
function Sql-Rows([string]$query) {
    $r = Invoke-Sql $query
    if ($r.code -ne 0) { throw ("SQL error: " + $r.err) }
    $rows = New-Object System.Collections.ArrayList
    foreach ($l in ($r.out -split "`r?`n")) { if ($l -ne '') { [void]$rows.Add([string[]]($l -split "`t")) } }
    return ,$rows
}
function To-Int($v) { $n = 0; if ([int]::TryParse([string]$v, [ref]$n)) { return $n } else { return 0 } }
function Test-Port([int]$port) {
    $c = New-Object System.Net.Sockets.TcpClient
    try { $ar = $c.BeginConnect('127.0.0.1', $port, $null, $null); $ok = $ar.AsyncWaitHandle.WaitOne(300); if ($ok) { $c.EndConnect($ar) }; return ($ok -and $c.Connected) } catch { return $false } finally { $c.Close() }
}
function Get-SppProc([string]$name) {
    $ps = @(Get-Process -Name $name -ErrorAction SilentlyContinue)
    foreach ($p in $ps) { try { if ($p.Path -and $p.Path -like "*\$Exp\*") { return $p } } catch {} }
    if ($name -eq 'mysqld' -and $ps.Count -gt 0) { return $ps[0] }
    return $null
}
$CpuPrev = @{}
function Proc-Info([string]$name) {
    $p = Get-SppProc $name
    if (-not $p) { return @{ running = $false } }
    $now = Get-Date; $cpu = 0
    try {
        $tot = $p.TotalProcessorTime.TotalMilliseconds
        if ($CpuPrev.ContainsKey($name) -and $CpuPrev[$name].pid -eq $p.Id) {
            $dt = ($now - $CpuPrev[$name].t).TotalMilliseconds
            if ($dt -gt 0) { $cpu = [math]::Round((($tot - $CpuPrev[$name].cpu) / $dt) * 100 / [Environment]::ProcessorCount, 1) }
        }
        $CpuPrev[$name] = @{ pid = $p.Id; t = $now; cpu = $tot }
    } catch {}
    $up = 0; try { $up = [int]($now - $p.StartTime).TotalSeconds } catch {}
    return @{ running = $true; pid = $p.Id; cpu = $cpu; memMB = [math]::Round($p.WorkingSet64 / 1MB); uptime = $up }
}

# ---------------------------------------------------------------- remote console (RA)
function Read-Until($stream, [string[]]$patterns, [int]$timeoutMs) {
    $buf = New-Object byte[] 8192; $sb = New-Object System.Text.StringBuilder
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    while ($sw.ElapsedMilliseconds -lt $timeoutMs) {
        if ($stream.DataAvailable) {
            $n = $stream.Read($buf, 0, $buf.Length)
            if ($n -le 0) { break }
            [void]$sb.Append([System.Text.Encoding]::UTF8.GetString($buf, 0, $n))
            $s = $sb.ToString()
            foreach ($pt in $patterns) { if ($s -match $pt) { return $s } }
        } else { Start-Sleep -Milliseconds 30 }
    }
    return $sb.ToString()
}
function Invoke-Ra([string]$command, [int]$waitMs = 2500, [int]$raPort = 0) {
    if (-not $Cfg.raUser) { throw 'Set your GM account name and password in Settings > Dashboard first.' }
    if ($raPort -eq 0) { $raPort = To-Int (Read-ConfValue 'mangosd' 'Ra.Port') }
    $c = New-Object System.Net.Sockets.TcpClient
    try {
        $ar = $c.BeginConnect('127.0.0.1', $raPort, $null, $null)
        if (-not $ar.AsyncWaitHandle.WaitOne(1500) -or -not $c.Connected) { throw 'Remote console not reachable. Is the world server running, with Ra.Enable = 1 (needs one restart after enabling)?' }
        $c.EndConnect($ar)
        $s = $c.GetStream(); $enc = [System.Text.Encoding]::UTF8
        [void](Read-Until $s @('(?i)user') 3000)
        $b = $enc.GetBytes([string]$Cfg.raUser + "`r`n"); $s.Write($b, 0, $b.Length)
        $r = Read-Until $s @('(?i)pass', '-No such user', '-Not enough') 3000
        if ($r -match '-No such user') { throw ("Login failed: account '" + $Cfg.raUser + "' not found.") }
        if ($r -match '-Not enough') { throw ("Login failed: account '" + $Cfg.raUser + "' needs GM level 3.") }
        $b = $enc.GetBytes([string]$Cfg.raPass + "`r`n"); $s.Write($b, 0, $b.Length)
        $r = Read-Until $s @('mangos>', '-Wrong pass') 3000
        if ($r -notmatch 'mangos>') { throw 'Login failed: wrong password.' }
        $b = $enc.GetBytes($command + "`r`n"); $s.Write($b, 0, $b.Length)
        $out = Read-Until $s @('mangos>\s*$') $waitMs
        return ($out -replace 'mangos>\s*$', '').Trim()
    } finally { $c.Close() }
}

# ---------------------------------------------------------------- server control state machine
$State = @{ action = 'idle'; step = ''; since = (Get-Date); message = ''; userStopped = $true; wasRunning = $false; watchdogRestarts = 0 }
function Set-Action([string]$a, [string]$step, [string]$msg) { $State.action = $a; $State.step = $step; $State.since = Get-Date; if ($msg) { $State.message = $msg } }
function Win-Style { if ($Cfg.hideWindows) { 'Hidden' } else { 'Minimized' } }
function Start-Db { Start-Process -FilePath (Join-Path $Spp 'Server\Database\start.bat') -WorkingDirectory $Spp -WindowStyle (Win-Style) }
function Start-Realm { Start-Process -FilePath (Join-Path $BinDir 'realmd.exe') -WorkingDirectory $SettingsDir -WindowStyle (Win-Style) }
function Start-World { Start-Process -FilePath (Join-Path $BinDir 'mangosd.exe') -WorkingDirectory $SettingsDir -WindowStyle (Win-Style) }
function Start-Autosave {
    if (-not $Cfg.startAutosave) { return }
    # match on the command line - a hidden window has no title to match
    $running = @(Get-CimInstance Win32_Process -Filter "Name = 'cmd.exe'" -ErrorAction SilentlyContinue | Where-Object { $_.CommandLine -like '*autosave_daemon*' }).Count -gt 0
    if (-not $running) { Start-Process -FilePath (Join-Path $Spp 'Server\Tools\autosave_daemon.bat') -ArgumentList $Exp -WorkingDirectory (Join-Path $Spp 'Server\Tools') -WindowStyle (Win-Style) }
}
# Keep random bots within +-N levels of the most recently played real character. Runs at server start, before
# mangosd loads (the bot manager caches its timers in memory, so DB edits only count while it is down).
#  - aiplayerbot.conf: RandomBotMin/MaxLevel = the range; randombotStartingLevel = 80 makes every bot re-roll
#    (RandomizeFirst: new level in range, fresh gear/spells) when its randomize timer runs out, instead of only
#    bots at level <= 5. SyncLevelWithPlayers stays off: with nobody online it pins re-rolls to the min level.
#  - out-of-range bots get their randomize/teleport timers cleared, so they re-roll as soon as they log in.
#  - death knights can't go below 55 and the re-roll misbehaves for DKs above the range: while the range is
#    under 55 their login chance is set to 0 and they leave the online set; out-of-range DKs that stay
#    get their randomize timer pushed out 14 days.
#  - the original conf values are kept in dashboard.json (botOrig) and written back when the option is off.
$BotSyncKeys = @('AiPlayerbot.RandomBotMinLevel', 'AiPlayerbot.RandomBotMaxLevel', 'AiPlayerbot.randombotStartingLevel') +
    @(1, 2, 3, 4, 5, 6, 7, 8, 10, 11 | ForEach-Object { "AiPlayerbot.ClassRaceProb.6.$_" })
function Get-BotOrig {
    $h = @{}
    if ($Cfg.botOrig -is [hashtable]) { foreach ($k in $Cfg.botOrig.Keys) { $h[$k] = $Cfg.botOrig[$k] } }
    elseif ($Cfg.botOrig) { foreach ($p in $Cfg.botOrig.PSObject.Properties) { $h[$p.Name] = $p.Value } }
    return $h
}
function Restore-BotConf {
    $orig = Get-BotOrig
    if ($orig.Count -eq 0) { return $null }
    $ch = @{}; foreach ($k in $orig.Keys) { $ch[$k] = if ($orig[$k] -ne $null -and $orig[$k] -ne '') { [string]$orig[$k] } elseif ($k -like '*StartingLevel') { '5' } else { $null } }
    foreach ($k in @($ch.Keys)) { if ($ch[$k] -eq $null) { $ch.Remove($k) } }
    [void](Write-ConfValues 'aiplayerbot' $ch -AddMissing)
    $Cfg.botOrig = $null; Save-Cfg
    return 'Bot level sync is off - original bot level settings restored.'
}
function Sync-BotLevels {
    if (-not $Cfg.botLevelSync) { return (Restore-BotConf) }
    $ci = (Get-DbInfo 'CharacterDatabaseInfo').db; $li = (Get-DbInfo 'LoginDatabaseInfo').db
    $r = Sql-Rows ("SELECT c.name, c.level FROM {0}.characters c JOIN {1}.account a ON a.id = c.account WHERE a.username NOT LIKE 'RNDBOT%' ORDER BY c.logout_time DESC LIMIT 1" -f $ci, $li)
    if ($r.Count -eq 0) { return $null }
    $name = $r[0][0]; $lvl = To-Int $r[0][1]
    # levels below / above the player (botLevelRange is the older symmetric setting, used when these are not set)
    $below = if ($Cfg.botLevelBelow -ne $null) { [Math]::Max(0, (To-Int $Cfg.botLevelBelow)) } else { [Math]::Max(1, (To-Int $Cfg.botLevelRange)) }
    $above = if ($Cfg.botLevelAbove -ne $null) { [Math]::Max(0, (To-Int $Cfg.botLevelAbove)) } else { [Math]::Max(1, (To-Int $Cfg.botLevelRange)) }
    $min = [Math]::Max(1, $lvl - $below); $max = [Math]::Min(80, [Math]::Max($min + 1, $lvl + $above))
    $noDk = $max -lt 55

    $orig = Get-BotOrig
    if ($orig.Count -eq 0) { foreach ($k in $BotSyncKeys) { $orig[$k] = Read-ConfValue 'aiplayerbot' $k }; $Cfg.botOrig = $orig; Save-Cfg }
    $ch = @{ 'AiPlayerbot.RandomBotMinLevel' = "$min"; 'AiPlayerbot.RandomBotMaxLevel' = "$max"; 'AiPlayerbot.randombotStartingLevel' = '80' }
    foreach ($k in $BotSyncKeys) { if ($k -like '*ClassRaceProb.6.*') { $ch[$k] = if ($noDk) { '0' } else { [string]$orig[$k] } } }
    foreach ($k in @($ch.Keys)) { if ((Read-ConfValue 'aiplayerbot' $k) -eq $ch[$k]) { $ch.Remove($k) } }
    if ($ch.Count -gt 0) { [void](Write-ConfValues 'aiplayerbot' $ch -AddMissing) }

    $rb = "JOIN $li.account a ON a.id = c.account WHERE a.username LIKE 'RNDBOT%'"
    $out = "(c.level < $min OR c.level > $max)"
    $dkReroll = if ($noDk) { '0' } else { "(c.class = 6 AND c.level < $min)" }
    $reroll = "$out AND (c.class <> 6 OR $dkReroll)"
    $dkHold = "$out AND c.class = 6 AND NOT $dkReroll"
    $dkOut = if ($noDk) { "DELETE r FROM $ci.ai_playerbot_random_bots r JOIN $ci.characters c ON c.guid = r.bot $rb AND r.owner = 0 AND r.event = 'add' AND c.class = 6;" } else { '' }
    $q = @"
USE $ci;
SELECT COUNT(*) FROM $ci.characters c $rb AND $reroll;
DELETE r FROM $ci.ai_playerbot_random_bots r JOIN $ci.characters c ON c.guid = r.bot $rb AND r.owner = 0 AND r.event IN ('randomize', 'teleport') AND $reroll;
DELETE r FROM $ci.ai_playerbot_random_bots r JOIN $ci.characters c ON c.guid = r.bot $rb AND r.owner = 0 AND r.event = 'randomize' AND $dkHold;
INSERT INTO $ci.ai_playerbot_random_bots (owner, bot, time, validIn, event, value)
  SELECT 0, c.guid, UNIX_TIMESTAMP(), 1209600, 'randomize', 1 FROM $ci.characters c $rb AND $dkHold;
$dkOut
"@
    $res = Sql-Rows $q
    $count = if ($res.Count -gt 0) { To-Int $res[0][0] } else { 0 }
    $dkNote = if ($noDk) { ' Death knights are kept offline until the range reaches 55.' } else { '' }
    return "Bots set to levels $min-$max (around $name, level $lvl): $count will re-roll as they log in.$dkNote"
}
# One-shot SQL tweaks that need the world server stopped (e.g. bot timer resets): queued in dashboard.json
# (startTweaks = ["MyTweaks/file.sql", ...]) and applied during the next start, right before mangosd loads.
function Run-StartTweaks {
    $queue = @($Cfg.startTweaks | Where-Object { $_ })
    if ($queue.Count -eq 0) { return $null }
    $done = New-Object System.Collections.ArrayList; $left = New-Object System.Collections.ArrayList
    foreach ($item in $queue) {
        $parts = ([string]$item) -split '[\\/]', 2
        try { $r = Apply-Tweak $parts[1] $parts[0]; if ($r.ok) { [void]$done.Add($item) } else { [void]$left.Add($item) } }
        catch { [void]$left.Add($item) }
    }
    $Cfg.startTweaks = @($left); Save-Cfg
    $msg = 'Start tweaks applied: ' + ($done -join ', ')
    if ($left.Count) { $msg += '; failed (kept for next start): ' + ($left -join ', ') }
    return $msg
}
function Begin-Start {
    if (Get-SppProc 'mangosd') { throw 'World server is already running.' }
    if ($State.action -ne 'idle') { throw ('Busy: ' + $State.message) }
    $State.userStopped = $false
    Set-Action 'starting' 'db' 'Starting database...'
    if (-not (Test-Port 3310)) { Start-Db }
}
function Begin-Stop([int]$delay, [switch]$Restart) {
    if (-not (Get-SppProc 'mangosd')) { throw 'World server is not running.' }
    $out = Invoke-Ra (".server shutdown $delay")
    $State.userStopped = -not $Restart
    if ($Restart) { Set-Action 'restarting' 'waitexit' "Restarting in $delay s (characters are saved first)..." }
    else { Set-Action 'stopping' 'waitexit' "Shutting down in $delay s (characters are saved first)..." }
    return $out
}
# Keep a handle on the running mangosd so its exit code can be read after it exits.
# Shutdowns from the console or in-game (.server shutdown) exit with 0 (2 = restart) and write no crash dump.
function Watch-World($p) {
    if ($State.worldProc -and $State.worldProc.Id -eq $p.Id) { return }
    $State.worldProc = $p
    try { [void]$p.Handle; $State.worldStart = $p.StartTime } catch { $State.worldStart = Get-Date }
}
function Test-WorldCrashed {
    $p = $State.worldProc; $State.worldProc = $null
    if (-not $p) { return $true }
    $since = $State.worldStart
    $dump = @(Get-ChildItem $CrashDir -Filter *.txt -ErrorAction SilentlyContinue | Where-Object { $_.LastWriteTime -ge $since }).Count -gt 0
    if ($dump) { return $true }
    try { $p.WaitForExit(2000) | Out-Null; return -not ($p.ExitCode -eq 0 -or $p.ExitCode -eq 2) } catch { return $false }
}
# Daily restart: fires once per day within 30 min of restartTime (a PC that slept through it skips that day).
# restartLast holds the date of the last run/skip so a dashboard restart doesn't fire it twice.
function Get-NextRestart {
    if (-not $Cfg.restartDaily) { return $null }
    $t = [datetime]::MinValue
    if (-not [datetime]::TryParseExact([string]$Cfg.restartTime, 'HH:mm', [Globalization.CultureInfo]::InvariantCulture, 'None', [ref]$t)) { return $null }
    $due = (Get-Date).Date.Add($t.TimeOfDay)
    if ($Cfg.restartLast -eq $due.ToString('yyyy-MM-dd') -or (Get-Date) -gt $due.AddMinutes(30)) { $due = $due.AddDays(1) }
    return $due
}
function Check-Schedule {
    $due = Get-NextRestart
    if (-not $due -or (Get-Date) -lt $due) { return }
    $Cfg.restartLast = $due.ToString('yyyy-MM-dd'); Save-Cfg
    $players = 0; try { $o = (Get-Status).online; if ($o) { $players = [int]$o.players } } catch {}
    if ($players -gt 0 -and $Cfg.restartSkipPlayers) { $State.message = "Scheduled restart skipped - $players player(s) logged in."; Write-Host $State.message; return }
    $delay = if ($players -gt 0) { [Math]::Max(1, [int]$Cfg.restartWarn) * 60 } else { 5 }
    try { [void](Begin-Stop $delay -Restart); $State.message = "Scheduled restart in $delay s..."; Write-Host $State.message }
    catch { $State.message = 'Scheduled restart failed: ' + $_.Exception.Message; Write-Host $State.message }
}
# Stuck session fix: after an unclean client exit (crash, closing from in the world) this server keeps the
# session forever, and every later login "reconnects" into it without SMSG_TUTORIAL_FLAGS - the 3.3.5a client
# then crashes on the first chat line (null tutorial array). When the local Wow.exe goes away and real
# characters are still online a few seconds later, .kick them so the next login is a fresh session.
$WowWatch = @{ running = $false; exitAt = $null; lastCheck = [datetime]::MinValue }
function Check-StuckSessions {
    if (-not $Cfg.autoKickStuck -or -not $Cfg.raUser) { return }
    $now = Get-Date
    if (($now - $WowWatch.lastCheck).TotalSeconds -lt 2) { return }
    $WowWatch.lastCheck = $now
    $running = @(Get-Process -Name Wow, WowClassic -ErrorAction SilentlyContinue).Count -gt 0
    if ($running) { $WowWatch.running = $true; $WowWatch.exitAt = $null; return }
    if ($WowWatch.running) { $WowWatch.running = $false; $WowWatch.exitAt = $now }
    if (-not $WowWatch.exitAt -or ($now - $WowWatch.exitAt).TotalSeconds -lt 5) { return }
    $WowWatch.exitAt = $null
    $ci = (Get-DbInfo 'CharacterDatabaseInfo').db; $li = (Get-DbInfo 'LoginDatabaseInfo').db
    $rows = Sql-Rows ("SELECT c.name FROM {0}.characters c JOIN {1}.account a ON a.id = c.account WHERE c.online = 1 AND a.username NOT LIKE 'RNDBOT%'" -f $ci, $li)
    $names = @(foreach ($r in $rows) { $r[0] })
    if ($names.Count -eq 0) { return }
    foreach ($n in $names) { try { [void](Invoke-Ra ".kick $n") } catch {} }
    $State.message = 'Game client closed while in the world - cleared the stuck session for ' + ($names -join ', ') + ' so the next login is clean.'
    Write-Host $State.message
}
function Tick {
    $world = Get-SppProc 'mangosd'
    $elapsed = ((Get-Date) - $State.since).TotalSeconds
    switch ($State.action) {
        'starting' {
            if ($State.step -eq 'db') {
                if (Test-Port 3310) { Set-Action 'starting' 'realm' 'Starting login server...'; if (-not (Get-SppProc 'realmd')) { Start-Realm } }
                elseif ($elapsed -gt 60) { Set-Action 'idle' '' 'Database did not start within 60 s.' }
            } elseif ($State.step -eq 'realm') {
                if (-not $world) {
                    try { $t = Run-StartTweaks; if ($t) { Write-Host $t } } catch { Write-Host ('start tweaks failed: ' + $_.Exception.Message) }
                    try { $m = Sync-BotLevels; if ($m) { $State.botSync = $m; Write-Host $m } } catch { $State.botSync = 'Bot level sync failed: ' + $_.Exception.Message; Write-Host $State.botSync }
                    Start-World
                }
                Start-Autosave
                Set-Action 'starting' 'world' 'Loading the world (takes a few minutes)...'
            } elseif ($State.step -eq 'world') {
                if ($world) { $State.wasRunning = $true }
                if (Test-Port (To-Int (Read-ConfValue 'mangosd' 'WorldServerPort'))) { Set-Action 'idle' '' 'Server is up.' }
                elseif (-not $world -and $elapsed -gt 8) { $State.wasRunning = $false; Set-Action 'idle' '' 'World server exited during startup - check the Crashes tab.' }
            }
        }
        { $_ -eq 'stopping' -or $_ -eq 'restarting' } {
            if (-not $world) {
                $State.wasRunning = $false
                if ($State.action -eq 'restarting') { Set-Action 'starting' 'db' 'Starting again...' }
                else { Set-Action 'idle' '' 'Server stopped.' }
            } elseif ($elapsed -gt 300) { Set-Action 'idle' '' 'Shutdown is taking long - use Force stop if needed.' }
        }
        'idle' {
            if ($world) { $State.wasRunning = $true; Watch-World $world; Check-Schedule; try { Check-StuckSessions } catch { Write-Host ('stuck-session check: ' + $_.Exception.Message) } }
            elseif ($State.wasRunning) {
                $State.wasRunning = $false
                if (-not (Test-WorldCrashed)) { $State.userStopped = $true; $State.message = 'World server was shut down.' }
                elseif (-not $State.userStopped) {
                    if ($Cfg.watchdog) {
                        $State.watchdogRestarts++
                        Set-Action 'starting' 'db' 'Watchdog: world server stopped unexpectedly - restarting...'
                    } else { $State.message = 'World server stopped unexpectedly (crash?). See the Crashes tab.' }
                }
            }
        }
    }
}

# ---------------------------------------------------------------- data providers
$ZoneNames = @{1='Dun Morogh';3='Badlands';4='Blasted Lands';8='Swamp of Sorrows';10='Duskwood';11='Wetlands';12='Elwynn Forest';14='Durotar';15='Dustwallow Marsh';16='Azshara';17='The Barrens';28='Western Plaguelands';33='Stranglethorn Vale';36='Alterac Mountains';38='Loch Modan';40='Westfall';41='Deadwind Pass';44='Redridge Mountains';45='Arathi Highlands';46='Burning Steppes';47='The Hinterlands';51='Searing Gorge';65='Dragonblight';66="Zul'Drak";67='The Storm Peaks';85='Tirisfal Glades';130='Silverpine Forest';139='Eastern Plaguelands';141='Teldrassil';148='Darkshore';209='Shadowfang Keep';210='Icecrown';215='Mulgore';267='Hillsbrad Foothills';331='Ashenvale';357='Feralas';361='Felwood';394='Grizzly Hills';400='Thousand Needles';405='Desolace';406='Stonetalon Mountains';440='Tanaris';490="Un'Goro Crater";491='Razorfen Kraul';493='Moonglade';495='Howling Fjord';618='Winterspring';717='The Stockade';718='Wailing Caverns';719='Blackfathom Deeps';721='Gnomeregan';722='Razorfen Downs';796='Scarlet Monastery';1176="Zul'Farrak";1337='Uldaman';1377='Silithus';1477='Sunken Temple';1497='Undercity';1519='Stormwind City';1537='Ironforge';1581='The Deadmines';1584='Blackrock Depths';1637='Orgrimmar';1638='Thunder Bluff';1657='Darnassus';2100='Maraudon';2437='Ragefire Chasm';2817='Crystalsong Forest';3430='Eversong Woods';3433='Ghostlands';3483='Hellfire Peninsula';3487='Silvermoon City';3518='Nagrand';3519='Terokkar Forest';3520='Shadowmoon Valley';3521='Zangarmarsh';3522="Blade's Edge Mountains";3523='Netherstorm';3524='Azuremyst Isle';3525='Bloodmyst Isle';3537='Borean Tundra';3557='The Exodar';3703='Shattrath City';3711='Sholazar Basin';4080="Isle of Quel'Danas";4197='Wintergrasp';4298='The Scarlet Enclave';4395='Dalaran'}
$MapNames = @{0='Eastern Kingdoms';1='Kalimdor';530='Outland';571='Northrend';609='Ebon Hold'}
$ClassNames = @{1='Warrior';2='Paladin';3='Hunter';4='Rogue';5='Priest';6='Death Knight';7='Shaman';8='Mage';9='Warlock';11='Druid'}
$RaceNames = @{1='Human';2='Orc';3='Dwarf';4='Night Elf';5='Undead';6='Tauren';7='Gnome';8='Troll';10='Blood Elf';11='Draenei'}

$CrashCache = @{}
$OnlineCache = @{ at = $null; value = $null }
function Fmt-Next { $d = Get-NextRestart; if ($d) { $d.ToString('yyyy-MM-dd HH:mm') } else { $null } }
function Get-Status {
    $db = Test-Port 3310
    $o = @{ db = (Proc-Info 'mysqld'); realm = (Proc-Info 'realmd'); world = (Proc-Info 'mangosd'); dbPort = $db
            action = $State.action; step = $State.step; message = $State.message; watchdog = [bool]$Cfg.watchdog; watchdogRestarts = $State.watchdogRestarts
            raConfigured = [bool]$Cfg.raUser; online = $null; lastCrash = $null; nextRestart = (Fmt-Next) }
    $o.db.running = $db
    $o.world.ready = ($o.world.running -and (Test-Port (To-Int (Read-ConfValue 'mangosd' 'WorldServerPort'))))
    # online counts are cached for 4 s - the page and the tray icon both poll status
    if ($db -and $OnlineCache.at -and ((Get-Date) - $OnlineCache.at).TotalSeconds -lt 4) { $o.online = $OnlineCache.value }
    elseif ($db) {
        try {
            $ci = Get-DbInfo 'CharacterDatabaseInfo'; $li = Get-DbInfo 'LoginDatabaseInfo'
            $r = Sql-Rows ("SELECT IFNULL(SUM(a.username LIKE 'RNDBOT%'),0), IFNULL(SUM(a.username NOT LIKE 'RNDBOT%'),0) FROM {0}.characters c JOIN {1}.account a ON a.id=c.account WHERE c.online=1" -f $ci.db, $li.db)
            if ($r.Count -gt 0) { $o.online = @{ bots = (To-Int $r[0][0]); players = (To-Int $r[0][1]) } }
            $OnlineCache.at = Get-Date; $OnlineCache.value = $o.online
        } catch {}
    }
    $lc = Get-ChildItem $CrashDir -Filter *.txt -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if ($lc) {
        if (-not $CrashCache.ContainsKey($lc.Name)) { $CrashCache[$lc.Name] = (Parse-Crash $lc) }
        $pc = $CrashCache[$lc.Name]
        $o.lastCrash = @{ name = $lc.Name; time = $pc.time.Substring(0, 16); where = ($pc.signature -split '  <  ')[0] }
    }
    return $o
}

$CrashHints = @(
  @{ p = 'EffectTeleportUnits'; t = 'A portal-type object cast a teleport with no facing set. fix_portal_teleports.sql in Tweaks covers the known portals - if this happened after applying it, a portal not on that list triggered it.' },
  @{ p = 'BindToInstance'; t = 'A bot crashed while being saved to a dungeon instance lock (known bot bug, often right after a teleport into a dungeon).' },
  @{ p = 'ai::Engine::Reset'; t = 'A bot''s AI was reset during a random teleport (scheduled strategy change) and its action lists were already broken. Known playerbots instability, random - not caused by a setting. More likely right after a start while many bots re-roll their level.' },
  @{ p = 'SetAvoidAreaAction'; t = 'A bot''s "avoid mobs" strategy wrote mob areas into the shared navigation mesh while other threads used it. Disabled via -avoid mobs in the bot default strategies (aiplayerbot.conf, from the next start).' },
  @{ p = 'guardAI::JustDied'; t ='A town guard was killed by a damage-over-time effect whose caster had vanished (bot logged out, teleported or was re-rolled). Server bug in guard_ai.cpp; more likely right after a start that re-rolls many bots.' },
  @{ p = 'GetCharmerGuid'; t = 'A unit referenced a caster/owner that no longer exists (usually bot-related).' }
)
function Parse-Crash([System.IO.FileInfo]$f, [switch]$Full) {
    $lines = [System.IO.File]::ReadAllLines($f.FullName)
    $exc = ''; $frames = New-Object System.Collections.ArrayList; $inStack = $false; $stackNo = 0; $locals = New-Object System.Collections.ArrayList; $inLocals = $false
    foreach ($l in $lines) {
        if (-not $exc -and $l -match '^Exception code:\s*(.+)$') { $exc = $Matches[1].Trim() }
        if ($l -match '^Local Variables And Parameters') { $inLocals = $true; $inStack = $false; continue }
        if ($l -match '^Call stack:') { $stackNo++; $inStack = (-not $inLocals -and $stackNo -eq 1); continue }
        if ($inStack -and $l -match '^[0-9A-F]{16}\s+[0-9A-F]{16}\s+(\S+?)(\+[0-9A-F]+)?(\s+(.*))?$') {
            $fn = $Matches[1]; $src = [string]$Matches[4]; $file = ''; $line = ''
            if ($src -match '([^\\/]+)\s+line\s+(\d+)') { $file = $Matches[1]; $line = $Matches[2] }
            [void]$frames.Add(@{ fn = $fn; file = $file; line = $line })
        }
        if ($Full -and $inLocals -and $locals.Count -lt 80) {
            if ($l -match '^Call stack:' ) { continue }
            [void]$locals.Add($l)
        }
    }
    $sig = (@($frames | Select-Object -First 3 | ForEach-Object { $_.fn })) -join '  <  '
    $bot = @($frames | Where-Object { $_.fn -match 'Playerbot|HandleBotPackets' }).Count -gt 0
    $hint = 'Not a known crash yet - ask Claude to look at it.'
    # match against the first frames, not just the 3-frame signature (e.g. guardAI::JustDied sits 6 frames deep)
    $stackText = (@($frames | Select-Object -First 12 | ForEach-Object { $_.fn })) -join ' '
    foreach ($h in $CrashHints) { if ($stackText.Contains($h.p)) { $hint = $h.t; break } }
    $time = $f.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss')
    $hd = [regex]::Match(($lines | Select-Object -First 4) -join ' ', 'Crash date (\d+):(\d+):(\d{4})\. Time (\d+):(\d+)')
    if ($hd.Success) {
        $sec = 0; $fm = [regex]::Match($f.Name, '_(\d+)-(\d+)-(\d+)\]'); if ($fm.Success) { $sec = [int]$fm.Groups[3].Value }
        $time = '{0}-{1:00}-{2:00} {3:00}:{4:00}:{5:00}' -f $hd.Groups[3].Value, [int]$hd.Groups[2].Value, [int]$hd.Groups[1].Value, [int]$hd.Groups[4].Value, [int]$hd.Groups[5].Value, $sec
    }
    $o = @{ name = $f.Name; time = $time; exception = $exc; signature = $sig; bot = $bot; hint = $hint }
    if ($Full) { $o.frames = @($frames | Select-Object -First 25); $o.locals = (@($locals) -join "`n") }
    return $o
}
function Get-Crashes {
    $fs = @(Get-ChildItem $CrashDir -Filter *.txt -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 40)
    $out = New-Object System.Collections.ArrayList
    foreach ($f in $fs) { [void]$out.Add((Parse-Crash $f)) }
    $sorted = New-Object System.Collections.ArrayList
    foreach ($c in ($out | Sort-Object { $_.time } -Descending)) { [void]$sorted.Add($c) }
    return ,$sorted
}

function Get-LogTail([int]$lines, [bool]$filter, [string]$search) {
    if (-not (Test-Path $LogFile)) { return ,@() }
    $fs = New-Object System.IO.FileStream($LogFile, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
    try {
        $len = $fs.Length; $take = [int][Math]::Min($len, 1500000)
        [void]$fs.Seek($len - $take, [System.IO.SeekOrigin]::Begin)
        $buf = New-Object byte[] $take; [void]$fs.Read($buf, 0, $take)
    } finally { $fs.Close() }
    $all = [System.Text.Encoding]::UTF8.GetString($buf) -split "`r?`n"
    $res = New-Object System.Collections.ArrayList
    $filters = @($Cfg.logFilters)
    for ($i = $all.Count - 1; $i -ge 1 -and $res.Count -lt $lines; $i--) {
        $l = $all[$i]; if (-not $l) { continue }
        if ($filter) { $skip = $false; foreach ($f in $filters) { if ($f -and $l.Contains([string]$f)) { $skip = $true; break } }; if ($skip) { continue } }
        if ($search -and $l.IndexOf($search, [StringComparison]::OrdinalIgnoreCase) -lt 0) { continue }
        [void]$res.Add($l)
    }
    $res.Reverse()
    return ,$res
}

function Get-Characters {
    $ci = Get-DbInfo 'CharacterDatabaseInfo'; $li = Get-DbInfo 'LoginDatabaseInfo'
    $rows = Sql-Rows ("SELECT c.guid,c.name,c.level,c.race,c.class,c.map,c.zone,c.online,c.totaltime,a.username FROM {0}.characters c JOIN {1}.account a ON a.id=c.account WHERE a.username NOT LIKE 'RNDBOT%' ORDER BY c.online DESC, c.level DESC" -f $ci.db, $li.db)
    $chars = New-Object System.Collections.ArrayList
    foreach ($r in $rows) {
        $mapId = To-Int $r[5]; $zoneId = To-Int $r[6]
        [void]$chars.Add(@{ guid = (To-Int $r[0]); name = $r[1]; level = (To-Int $r[2]); race = $RaceNames[(To-Int $r[3])]; cls = $ClassNames[(To-Int $r[4])];
                     map = $(if ($MapNames.ContainsKey($mapId)) { $MapNames[$mapId] } else { "Instance (map $mapId)" });
                     zone = $(if ($ZoneNames.ContainsKey($zoneId)) { $ZoneNames[$zoneId] } else { "Zone #$zoneId" });
                     online = ($r[7] -eq '1'); played = (To-Int $r[8]); account = $r[9] })
    }
    $b = Sql-Rows ("SELECT LEAST(FLOOR((c.level-1)/10),7) AS br, COUNT(*), IFNULL(SUM(c.online),0) FROM {0}.characters c JOIN {1}.account a ON a.id=c.account WHERE a.username LIKE 'RNDBOT%' GROUP BY br ORDER BY br" -f $ci.db, $li.db)
    $brackets = New-Object System.Collections.ArrayList
    foreach ($r in $b) { $lo = (To-Int $r[0]) * 10 + 1; $hi = if ($lo -ge 71) { 80 } else { $lo + 9 }; [void]$brackets.Add(@{ label = "$lo-$hi"; total = (To-Int $r[1]); online = (To-Int $r[2]) }) }
    return @{ chars = $chars; bots = $brackets }
}
function Unstuck([int]$guid) {
    $ci = Get-DbInfo 'CharacterDatabaseInfo'
    $r = Sql-Rows ("SELECT online, name FROM {0}.characters WHERE guid={1}" -f $ci.db, $guid)
    if ($r.Count -eq 0) { throw 'Character not found.' }
    $name = $r[0][1]
    if ($r[0][0] -eq '1' -and (Get-SppProc 'mangosd')) { throw "$name is online. Log out to the character screen first." }
    $x = Sql-Rows ("UPDATE {0}.characters c JOIN {0}.character_homebind h ON h.guid=c.guid SET c.map=h.map, c.zone=h.zone, c.position_x=h.position_x, c.position_y=h.position_y, c.position_z=h.position_z WHERE c.guid={1}; SELECT ROW_COUNT();" -f $ci.db, $guid)
    if ($x.Count -gt 0 -and $x[$x.Count - 1][0] -eq '0') { return "$name is already at their Hearthstone location (or has none)." }
    return "$name was moved to their Hearthstone location."
}

$TweakFolders = [ordered]@{ Tweaks = $TweaksDir; MyTweaks = $MyTweaksDir }
function Get-Tweaks {
    $list = New-Object System.Collections.ArrayList
    foreach ($folder in $TweakFolders.Keys) {
        $dir = $TweakFolders[$folder]
        if (-not (Test-Path $dir)) { continue }
        foreach ($f in (Get-ChildItem $dir -Filter *.sql | Sort-Object Name)) {
            $desc = (@(Get-Content $f.FullName -TotalCount 4 | Where-Object { $_ -match '^\s*--' } | ForEach-Object { ($_ -replace '^\s*--\s*', '') })) -join ' '
            [void]$list.Add(@{ name = $f.Name; folder = $folder; desc = $desc; revert = ($f.Name -match 'revert') })
        }
    }
    return ,$list
}
function Apply-Tweak([string]$name, [string]$folder) {
    if (-not $folder) { $folder = 'Tweaks' }
    if (-not $TweakFolders.Contains($folder)) { throw 'Unknown tweak folder.' }
    $path = Join-Path $TweakFolders[$folder] ([System.IO.Path]::GetFileName($name))
    if (-not (Test-Path $path)) { throw 'File not found.' }
    $sql = [System.IO.File]::ReadAllText($path)
    $i = Get-DbInfo 'WorldDatabaseInfo'
    $r = Invoke-Sql $sql $i.db -Table
    if (-not (Test-Path $MyTweaksDir)) { New-Item -ItemType Directory $MyTweaksDir | Out-Null }
    $log = Join-Path $MyTweaksDir 'apply_sql_log.txt'
    Add-Content $log ("===== {0} : {1} (dashboard)`r`n{2}{3}`r`nexit code {4}" -f (Get-Date), $name, $r.out, $r.err, $r.code)
    $txt = [string]$r.out; if ($r.err) { $txt += "`n" + $r.err }
    return @{ ok = ($r.code -eq 0); output = $txt.Trim() }
}

function Search-Conf([string]$term) {
    $res = New-Object System.Collections.ArrayList
    if ($term.Length -lt 2) { return ,$res }
    foreach ($f in @('mangosd','aiplayerbot')) {
        $ls = [System.IO.File]::ReadAllLines($ConfFiles[$f])
        foreach ($l in $ls) {
            if ($l -match '^\s*([A-Za-z0-9_.\-'']+)\s*=\s*(.*?)\s*$') {
                if ($Matches[1].IndexOf($term, [StringComparison]::OrdinalIgnoreCase) -ge 0) {
                    [void]$res.Add(@{ f = $f; k = $Matches[1]; v = $Matches[2] })
                    if ($res.Count -ge 80) { return ,$res }
                }
            }
        }
    }
    return ,$res
}

# ---------------------------------------------------------------- HTTP plumbing
function Send-Json($ctx, $obj, [int]$code = 200) {
    $json = ConvertTo-Json -InputObject $obj -Depth 8 -Compress
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($json)
    $ctx.Response.StatusCode = $code
    $ctx.Response.ContentType = 'application/json; charset=utf-8'
    $ctx.Response.Headers.Add('Cache-Control', 'no-store')
    $ctx.Response.OutputStream.Write($bytes, 0, $bytes.Length)
    $ctx.Response.Close()
}
function Send-File($ctx, [string]$path, [string]$type = 'text/html; charset=utf-8') {
    $bytes = [System.IO.File]::ReadAllBytes($path)
    $ctx.Response.ContentType = $type
    $ctx.Response.Headers.Add('Cache-Control', 'no-store')
    $ctx.Response.OutputStream.Write($bytes, 0, $bytes.Length)
    $ctx.Response.Close()
}
function Read-Body($ctx) {
    $sr = New-Object System.IO.StreamReader($ctx.Request.InputStream, [System.Text.Encoding]::UTF8)
    $t = $sr.ReadToEnd(); $sr.Close()
    if ($t) { return ($t | ConvertFrom-Json) } else { return $null }
}
function Get-Delay($b) { if ($b -and $b.delay -ne $null) { return [int]$b.delay } else { return 10 } }

function Handle($ctx) {
    $req = $ctx.Request; $path = $req.Url.AbsolutePath; $q = $req.QueryString; $m = $req.HttpMethod
    # Only accept POSTs from our own page (blocks other websites from poking the local API)
    if ($m -eq 'POST') {
        $origin = [string]$req.Headers['Origin']
        if ($req.Headers['X-SPP'] -ne '1' -or ($origin -and $origin -notmatch '^http://(localhost|127\.0\.0\.1)(:\d+)?$')) { Send-Json $ctx @{ error = 'forbidden' } 403; return }
    }
    try {
        switch -Regex ($path) {
            '^/$' { Send-File $ctx (Join-Path $WebDir 'index.html'); return }
            '^/favicon\.ico$' { Send-File $ctx (Join-Path $DashDir 'app.ico') 'image/x-icon'; return }
            '^/api/status$' { Send-Json $ctx (Get-Status); return }
            '^/api/server/start$' { Begin-Start; Send-Json $ctx @{ ok = $true }; return }
            '^/api/server/stop$' { $o = Begin-Stop (Get-Delay (Read-Body $ctx)); Send-Json $ctx @{ ok = $true; output = $o }; return }
            '^/api/server/restart$' { $o = Begin-Stop (Get-Delay (Read-Body $ctx)) -Restart; Send-Json $ctx @{ ok = $true; output = $o }; return }
            '^/api/server/kill$' {
                $State.userStopped = $true
                $p = Get-SppProc 'mangosd'; if ($p) { $p.Kill() }
                Set-Action 'idle' '' 'World server force-stopped. Progress since the last autosave was not saved.'
                Send-Json $ctx @{ ok = $true }; return }
            '^/api/server/stopall$' {
                if (Get-SppProc 'mangosd') { throw 'Stop the world server first.' }
                $State.userStopped = $true
                $p = Get-SppProc 'realmd'; if ($p) { $p.Kill() }
                $i = Get-DbInfo 'WorldDatabaseInfo'
                $ma = Join-Path $Spp 'Server\Database\bin\mysqladmin.exe'
                if (Test-Port 3310) { [void](Run-Proc $ma ("-h{0} -P{1} -u{2} -p{3} shutdown" -f $i.host, $i.port, $i.user, $i.pass) $null 30000) }
                Set-Action 'idle' '' 'Login server and database stopped.'
                Send-Json $ctx @{ ok = $true }; return }
            '^/api/watchdog$' { $b = Read-Body $ctx; $Cfg.watchdog = [bool]$b.enabled; Save-Cfg; Send-Json $ctx @{ ok = $true }; return }
            '^/api/command$' { $b = Read-Body $ctx; $o = Invoke-Ra ([string]$b.command); Send-Json $ctx @{ ok = $true; output = $o }; return }
            '^/api/settings$' {
                if ($m -eq 'GET') {
                    $out = New-Object System.Collections.ArrayList
                    foreach ($d in $SettingDefs) { $c = $d.Clone(); $c.value = Read-ConfValue $d.f $d.k; [void]$out.Add($c) }
                    Send-Json $ctx @{ settings = $out; dash = @{ raUser = [string]$Cfg.raUser; raPassSet = [bool]$Cfg.raPass; port = $Cfg.port; startAutosave = [bool]$Cfg.startAutosave; hideWindows = [bool]$Cfg.hideWindows; botLevelSync = [bool]$Cfg.botLevelSync; botLevelRange = [int]$Cfg.botLevelRange; botLevelBelow = $(if ($Cfg.botLevelBelow -ne $null) { [int]$Cfg.botLevelBelow } else { [int]$Cfg.botLevelRange }); botLevelAbove = $(if ($Cfg.botLevelAbove -ne $null) { [int]$Cfg.botLevelAbove } else { [int]$Cfg.botLevelRange }); botSync = $State.botSync; restartDaily = [bool]$Cfg.restartDaily; restartTime = [string]$Cfg.restartTime; restartSkipPlayers = [bool]$Cfg.restartSkipPlayers; autoKickStuck = [bool]$Cfg.autoKickStuck; nextRestart = (Fmt-Next); logFilters = @($Cfg.logFilters) } }
                } else {
                    $b = Read-Body $ctx; $byFile = @{}
                    foreach ($ch in @($b.changes)) {
                        $f = [string]$ch.f; $k = [string]$ch.k
                        if (-not $ConfFiles.ContainsKey($f)) { continue }
                        if ($k -notmatch '^[A-Za-z0-9_.\-'']+$') { continue }
                        $v = [string]$ch.v
                        if ($v -match '[\r\n]') { continue }
                        if (-not $byFile.ContainsKey($f)) { $byFile[$f] = @{} }
                        $byFile[$f][$k] = $v
                    }
                    $done = New-Object System.Collections.ArrayList
                    foreach ($f in $byFile.Keys) { foreach ($k in (Write-ConfValues $f $byFile[$f])) { [void]$done.Add($k) } }
                    Send-Json $ctx @{ ok = $true; saved = $done }
                }
                return }
            '^/api/dashcfg$' {
                $b = Read-Body $ctx
                if ($b.raUser -ne $null) { $Cfg.raUser = [string]$b.raUser }
                if ($b.raPass) { $Cfg.raPass = [string]$b.raPass }
                if ($b.startAutosave -ne $null) { $Cfg.startAutosave = [bool]$b.startAutosave }
                if ($b.hideWindows -ne $null) { $Cfg.hideWindows = [bool]$b.hideWindows }
                if ($b.botLevelSync -ne $null) { $Cfg.botLevelSync = [bool]$b.botLevelSync }
                if ($b.restartDaily -ne $null) { $Cfg.restartDaily = [bool]$b.restartDaily }
                if ($b.restartTime -and [string]$b.restartTime -match '^([01]\d|2[0-3]):[0-5]\d$') { $Cfg.restartTime = [string]$b.restartTime }
                if ($b.restartSkipPlayers -ne $null) { $Cfg.restartSkipPlayers = [bool]$b.restartSkipPlayers }
                if ($b.autoKickStuck -ne $null) { $Cfg.autoKickStuck = [bool]$b.autoKickStuck }
                if ($b.botLevelRange -ne $null) { $Cfg.botLevelRange = [Math]::Min(20, [Math]::Max(1, [int]$b.botLevelRange)) }
                if ($b.botLevelBelow -ne $null) { $Cfg.botLevelBelow = [Math]::Min(20, [Math]::Max(0, [int]$b.botLevelBelow)) }
                if ($b.botLevelAbove -ne $null) { $Cfg.botLevelAbove = [Math]::Min(20, [Math]::Max(0, [int]$b.botLevelAbove)) }
                if ($b.logFilters -ne $null) { $Cfg.logFilters = @($b.logFilters) }
                Save-Cfg; Send-Json $ctx @{ ok = $true }; return }
            '^/api/conf/search$' { Send-Json $ctx @{ results = (Search-Conf ([string]$q['q'])) }; return }
            '^/api/crashes$' { Send-Json $ctx @{ crashes = (Get-Crashes) }; return }
            '^/api/crash$' { $n = [System.IO.Path]::GetFileName([string]$q['name']); $f = Get-Item -LiteralPath (Join-Path $CrashDir $n); Send-Json $ctx (Parse-Crash $f -Full); return }
            '^/api/log$' {
                $n = 300; if ($q['lines']) { $n = [int]$q['lines'] }
                Send-Json $ctx @{ lines = (Get-LogTail $n ($q['filter'] -ne '0') ([string]$q['search'])) }; return }
            '^/api/characters$' { Send-Json $ctx (Get-Characters); return }
            '^/api/characters/unstuck$' { $b = Read-Body $ctx; Send-Json $ctx @{ ok = $true; message = (Unstuck ([int]$b.guid)) }; return }
            '^/api/tweaks$' { Send-Json $ctx @{ tweaks = (Get-Tweaks) }; return }
            '^/api/tweaks/apply$' { $b = Read-Body $ctx; Send-Json $ctx (Apply-Tweak ([string]$b.name) ([string]$b.folder)); return }
            '^/api/open$' {
                $b = Read-Body $ctx
                $targets = @{ crashes = $CrashDir; settings = $SettingsDir; tweaks = $TweaksDir; mytweaks = $MyTweaksDir; logs = (Split-Path $LogFile) }
                if ($targets.ContainsKey([string]$b.what)) { Start-Process explorer.exe $targets[[string]$b.what] }
                Send-Json $ctx @{ ok = $true }; return }
            default { Send-Json $ctx @{ error = 'not found' } 404; return }
        }
    } catch {
        try { Send-Json $ctx @{ error = $_.Exception.Message } 500 } catch {}
    }
}

# ---------------------------------------------------------------- main loop
if ($env:SPP_DASH_NOSERVE -eq '1') { return }   # used by tests to load functions only
$listener = New-Object System.Net.HttpListener
$prefix = "http://localhost:$($Cfg.port)/"
$listener.Prefixes.Add($prefix)
if ($Background) { $NoBrowser = $true; try { Start-Transcript -Path (Join-Path $DashDir 'logs\dashboard.log') -Force | Out-Null } catch {} }
try { $listener.Start() } catch {
    Write-Host "Could not start on $prefix - is the dashboard already running? $($_.Exception.Message)" -ForegroundColor Red
    if (-not $Background) { Read-Host 'Press Enter to exit' }
    exit 1 }
$Host.UI.RawUI.WindowTitle = 'SPP Dashboard'
Write-Host ''
Write-Host "  SPP Dashboard is running at $prefix" -ForegroundColor Yellow
if (-not $Background) { Write-Host '  Keep this window open (you can minimize it). Closing it stops the dashboard only - the game server keeps running.' -ForegroundColor Gray }
Write-Host ''
if (-not $NoBrowser) { Start-Process $prefix }

if (Get-SppProc 'mangosd') { $State.wasRunning = $true; $State.userStopped = $false }
$pending = $listener.GetContextAsync()
while ($listener.IsListening) {
    if ($pending.Wait(1000)) {
        $ctx = $pending.Result
        $pending = $listener.GetContextAsync()
        Handle $ctx
    }
    try { Tick } catch { Write-Host ('tick error: ' + $_.Exception.Message) -ForegroundColor DarkYellow }
}
