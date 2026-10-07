# SPP Dashboard – handoff notes

Local web control panel for **SPP Classics V2 (WotLK 3.3.5a, cmangos + ike3 playerbots)** installed at
`D:\Games\SPP_Classics_V2`. This folder (`Dashboard\`) lives inside it.

## How it works
- `SPP_Dashboard.bat` → runs `dashboard.ps1` (Windows PowerShell 5.1, no installs) → `HttpListener` on
  `http://localhost:8099/`, serves `web\index.html` (single file, vanilla JS, no CDNs) and a JSON API.
- Main loop: `GetContextAsync().Wait(1000)` then `Tick` (server start/stop/restart state machine + crash watchdog).
- Dashboard settings in `dashboard.json` (GM account for remote console, watchdog, autosave, log spam filters).
- POSTs require header `X-SPP: 1` and a localhost Origin (blocks other websites).
- `-RootOverride <path>` + env `SPP_DASH_NOSERVE=1` let you dot-source the script and test functions.

## Desktop app (2026-10-06)
- `SPP Dashboard.vbs` (no console) → `app.ps1`: WinForms tray icon + Edge `--app` window with its own profile in
  `%LOCALAPPDATA%\SPP_Dashboard\edge`. Starts `dashboard.ps1 -Background` as a windowless child
  (transcript in `logs\dashboard.log`, app log in `logs\app.log`) and restarts it if it dies (max 3 in 10 min).
- Single instance via mutex `Local\SPP_Dashboard_App`. A second launch finds the Edge window (msedge command line
  contains the profile path) and focuses it. Closing the window keeps the tray. Quit kills only a dashboard it started.
- Tray: polls `/api/status` every 3 s; icon dot green/amber/red; balloons on a new crash dump and on "server up";
  menu Start/Restart/Stop (asks for the GM account if RA isn't set), Start with Windows (Startup shortcut with `-Tray`).
- `app.ico` is drawn by `New-AppBitmap`/`Save-AppIcon` (PNG-in-ICO), recreated if missing; served as `/favicon.ico`.
- `app.ps1 -Install` creates Desktop + Start menu shortcuts. `SPP_Dashboard.bat` still runs the old console mode.
- `/api/status` caches the online counts for 4 s (each one is a mysql.exe query).

## Bot level sync (2026-10-06, option `botLevelSync`/`botLevelRange` in dashboard.json, Settings › Dashboard)
- `Sync-BotLevels` runs in the start flow right before `Start-World` (DB up, mangosd down - the bot manager caches
  `ai_playerbot_random_bots` events in memory, so edits while it runs are ignored/overwritten).
- Based on cmangos/playerbots `RandomPlayerbotMgr::Randomize`: `randombotStartingLevel = 80` sends every bot whose
  `randomize` event is missing/expired to `RandomizeFirst` (level = urand(RandomBotMinLevel, RandomBotMaxLevel)).
  `SyncLevelWithPlayers` is left 0 - with no player online `playersLevel` = 0 and it would pin re-rolls to the min.
- Out-of-range bots: `randomize` + `teleport` events deleted (re-roll on login, grind teleport once a player is on).
  DKs: `RandomizeFirst` can't lower them below 55 and urand(min > max) for DKs above range, so while max < 55 their
  `ClassRaceProb.6.*` = 0 and their `add` events are deleted; other out-of-range DKs get `randomize` held 14 days.
- Original conf values saved in `botOrig`; turning the option off restores them at the next start.
- Verified live 2026-10-06: first start re-rolled gradually (11-20 online went 93 → 300 within minutes), 0 DKs online.

## Daily restart (`restartDaily`, `restartTime` HH:mm, `restartSkipPlayers`, `restartWarn` min, `restartLast`)
- `Check-Schedule` runs from `Tick` (idle, world running). Fires once per day within 30 min of the time, else
  skips to tomorrow; `restartLast` = date of the last run/skip. Uses `Begin-Stop -Restart` (5 s with nobody on,
  `restartWarn` minutes of in-game countdown otherwise), so the bot level sync runs on every scheduled restart.

## Status
- Written and tested on Linux pwsh 7 with copies of the real config, crash and log files, plus a fake mysql and RA
  server: settings read/write (CRLF kept, backups to `Settings\wotlk\backups`), crash parsing, log tail and filter,
  tweaks, characters, RA commands, and all API endpoints.
- **Not yet tested on Windows / PowerShell 5.1** or against the live server. Untested: process detection
  (`Get-SppProc` matches `*\wotlk\*` in the exe path), start flow (DB via `Server\Database\start.bat` with workdir
  `SPP_Server`, then `realmd.exe` and `mangosd.exe` with workdir `Settings\wotlk`), stop/restart via RA,
  stopall (mysqladmin shutdown), watchdog, CPU%/RAM, Open-folder buttons, and the UI in a real browser.
- 2026-10-06, Windows PS 5.1 against the live server: script parses, listener starts, process detection and
  CPU/RAM work, and all read-only endpoints return correct data. Fixed: a shutdown done outside the dashboard
  (console / in-game `.server shutdown`) was flagged as a crash and would have set off the watchdog. Now
  `Watch-World`/`Test-WorldCrashed` treat exit code 0/2 with no new crash dump as a clean shutdown.
- `hideWindows` (default on, toggle under Settings › Dashboard): DB, realmd, mangosd and the autosave daemon start
  with `-WindowStyle Hidden`. The autosave daemon is now found by its cmd.exe command line, not its window title.
  With the windows hidden, the remote console is the only clean way to stop the server.
- First run: the user must save a GM level 3 account name and password under Settings › Dashboard.
  `Ra.Enable = 1` and `Ra.IP = 127.0.0.1` are already set in mangosd.conf and take effect after one server restart.

## Server facts learned (useful for future fixes)
- Exact source: github.com/celguar/mangos-wotlk branch `ike3-bots`, commit 188c9b60. Bots: github.com/cmangos/playerbots.
- DB: MySQL 5.7 on 127.0.0.1:3310, root/123456; DBs wotlkmangos / wotlkcharacters / wotlkrealmd / wotlkplayerbots.
  Bundled client: `SPP_Server\Server\Database\bin\mysql.exe`. Random bot accounts start with `RNDBOT`.
- Configs are CRLF; edit values in place, never rewrite the whole file.
- RA protocol: server sends a username prompt → send name; password prompt → send pass; `+Logged in.` then `mangos>`
  prompts after each command.
- The Dungeon Finder has no matchmaking in this build (`LFGQueue::Update`: only full 5-man groups pop).
  Bots join the player's group when the player types `lfg` in a chat channel (±4 levels).
- Crash fixed with SQL: GameObject-cast teleports (`Spell::EffectTeleportUnits`, null `m_caster` when
  `spell_target_position.target_orientation = 0`). See `Tweaks\fix_portal_teleports.sql`.
- Known bot crashes: `Player/Group::BindToInstance` (bot teleporting into a dungeon), `guardAI::JustDied` (DoT from a vanished caster),
  `ai::Engine::Reset` < `PlayerbotAI::Reset` < `RandomTeleport` < `ChangeStrategy` (2026-10-06 22:54, ~10 min after a start
  with ~2900 bot re-rolls; broken trigger/action lists, looks like a use-after-free in playerbots).
- SOLVED 2026-10-07: client (Wow.exe 3.3.5a) crash at 0x00530475 on every chat line (+ "can't move").
  Cause: server reconnect bug. After an unclean client exit the session stays 60 s (`ShouldDisconnect`); logging in
  within that window takes the reconnect branch in `WorldSocket::HandleAuthSession`, which never sends
  `SMSG_TUTORIAL_FLAGS` (only `World::AddSession_` does). The new client's tutorial bit array (`[0xBD1AFC]`) stays
  null, and SendChatMessage's tutorial check (func 0x530450, tutorial 22) dereferences it. Loops: crash -> quick
  relog -> crash. Waiting does NOT help: on this server the orphaned session never expires (still present 215 s
  after a crash, no logout in Char.log). Fix verified: RA `.kick <name>` -> clean logout -> next login is a new session.
  Automated: `Check-StuckSessions` (in `Tick`, option `autoKickStuck`, default on) watches the local Wow.exe; 5 s after
  it exits, any real character still `online = 1` gets an RA `.kick`. Clean logouts leave nobody online, so no kick.
- `Tweaks\` (in git) holds shared SQL fixes plus `apply_sql.bat`; `MyTweaks\` (git-ignored) holds personal SQL and
  `apply_sql_log.txt`. The Tweaks tab lists both (`folder` field). Drag-and-drop onto the .bat closes instantly on
  this PC, but it works when run from cmd.
- Repo: the install root is a standalone git repo (README.md, .gitignore); SPP_Server/ and Git/ are ignored.
  `Addons\StartAttackMacros` is a copy of the client addon (install into the WoW client's Interface\AddOns).

## Ideas not done yet
- Fresh install / SPP update: the dashboard does not run the launcher's install/update steps (`Launcher.bat`
  `:start_database` compares `Server\Versions\wotlk_*_version.spp` with `set /a *_version=` under `:setup_wotlk`).
  Idea: block Start when they differ, and auto-enable `Ra.Enable`/`Ra.IP` + GM-level a chosen account.
- Live player and bot positions on a map; bot management (`.rndbot` commands);
  editable list of crash-hint signatures; tray icon or auto-start.
