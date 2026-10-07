# SPP Dashboard

A local control panel and a few fixes for **[SPP Classics V2](https://github.com/celguar/spp-classics-cmangos)**, WotLK 3.3.5a (cmangos with ike3 playerbots).
It replaces the launcher windows with a desktop app. From the app you start, stop and watch the server, change
common settings, read logs and crashes, and apply SQL fixes.

It runs on the Windows PowerShell 5.1 and Microsoft Edge that come with Windows 10/11. You don't install anything else.

> This is an add-on, not a fork. It sits next to your SPP install and doesn't change SPP's own files, except the
> settings you edit in the dashboard and the bot-level settings it manages (see [Bot level sync](#bot-level-sync)).

## Contents

| Folder | What it is |
|---|---|
| `Dashboard\` | The dashboard: `dashboard.ps1` (web server and control logic), `web\index.html` (UI), `app.ps1` + `SPP Dashboard.vbs` (desktop app with a tray icon) |
| `Tweaks\` | Shared SQL fixes for the world database, plus `apply_sql.bat` |
| `MyTweaks\` | Your own SQL (git-ignored). The dashboard lists it next to `Tweaks\` |
| `Addons\StartAttackMacros\` | Optional WoW client addon (see [below](#startattackmacros-client-addon)) |

## Install

1. Install SPP Classics V2 as usual (`Server_Update.bat`). Run the SPP launcher once, choose **WotLK**, and let it finish
   setting up the databases. Create your game account.
2. Put this repo's folders into the SPP root folder, next to `SPP_Server\`:
   ```
   SPP_Classics_V2\
     SPP_Server\        <- SPP itself
     Dashboard\
     Tweaks\
     Addons\
   ```
   With git, run this inside the SPP root: `git init`, `git remote add origin <repo url>`, then `git pull origin main`.
   SPP's own folders are in `.gitignore`, so git leaves them alone.
3. Create the shortcuts by running this once from the `Dashboard` folder:
   ```
   powershell -ExecutionPolicy Bypass -File app.ps1 -Install
   ```
   This adds **SPP Dashboard** to the Desktop and the Start menu.

### First-time setup

Stop/restart and the console go through the server's remote console (RA). To make them work:

1. In `SPP_Server\Settings\wotlk\mangosd.conf`, set `Ra.Enable = 1` and `Ra.IP = 127.0.0.1`, then restart the server
   once.
2. Make an account GM level 3. Either type `account set gmlevel <NAME> 3` in the world server console, or with the
   server stopped run:
   ```sql
   UPDATE wotlkrealmd.account SET gmlevel = 3 WHERE username = 'NAME';
   ```
3. In the dashboard, go to **Settings › Dashboard** and save that account's name and password. They're stored only in
   `Dashboard\dashboard.json`, which is git-ignored.

**After SPP updates:** if `Server_Update.bat` brings in new database versions, the SPP launcher applies them. Run the
launcher once and choose WotLK before you start the server from the dashboard again.

## Using it

- **SPP Dashboard** (shortcut or `SPP Dashboard.vbs`) opens the dashboard in its own window and puts an icon in the
  tray. Closing the window keeps the dashboard running in the tray. **Quit** in the tray menu stops it. The game
  server keeps running either way.
- The tray icon shows the server state: green means online, amber means starting or stopping, red means crashed. The
  tray menu has Start, Restart, Stop and *Start with Windows*.
- `SPP_Dashboard.bat` runs the same dashboard in a console window, then open http://localhost:8099/.

### Features

- **Start / stop / restart** the database, login server and world server in the right order. They run hidden by
  default; switch this off with *Run server windows hidden*. Stop and restart save characters first and can count
  down.
- **Auto-restart on crash** (watchdog). It can tell a crash from a normal shutdown: a crash leaves a crash dump or an
  error exit code. A shutdown done from the console or in game doesn't trigger it.
- **Daily restart** at a set time, so the bots re-sync to your level. You can make it skip when someone is logged
  in.
- **Clear stuck sessions:** when the game client closes or crashes while you're in the world, the dashboard kicks
  the character that's left on the server. See [Known issues](#known-issues) for why.
- **Settings:** the common `mangosd.conf` and `aiplayerbot.conf` options in a form, plus a search over every setting.
  Changes are written in place, and a backup goes to `Settings\wotlk\backups`.
- **Console** (GM commands over RA), **Logs** (live tail with spam filters), **Crashes** (parsed crash dumps with hints
  for known crashes), **Characters** (your characters, bots by level, *unstuck*), **Tweaks** (apply SQL from
  `Tweaks\` / `MyTweaks\`).

### Bot level sync

*Settings › Dashboard › Keep bots near my level* (±N levels, default 5). On every server start, before the world
loads, the dashboard:

- sets `RandomBotMinLevel`/`RandomBotMaxLevel` to your last played character's level ±N;
- sets `randombotStartingLevel = 80`, so bots re-roll into that range (new level, gear and spells) when their
  randomize timer runs out;
- clears the timers of bots outside the range, so they re-roll as soon as they log in;
- keeps Death Knights offline while the range is below 55. They can't go lower than that.

The original values are saved. Turning the option off puts them back at the next start. The first start after
turning it on is heavier than usual, because many bots re-roll at once.

## Tweaks

The `Tweaks\` folder has these SQL files. The first comment lines of each file are shown in the dashboard.

| File | What it does |
|---|---|
| `fix_portal_teleports.sql` / `revert_portal_teleports.sql` | Fixes a world-server crash (`Spell::EffectTeleportUnits`) caused by portal objects whose teleport has no facing set |
| `fix_surface_portal_crash.sql` / `revert_surface_portal.sql` | Older, narrower workaround for the same crash: it disables one portal. Superseded by the fix above |
| `hearthstone_5min.sql` / `hearthstone_revert.sql` | Hearthstone cooldown of 5 minutes instead of 30 |

You can apply them from the **Tweaks** tab. Or, from a command prompt:
`Tweaks\apply_sql.bat <file.sql>` (drag-and-drop onto the .bat may close at once). Most of them take effect after the
world server restarts. Put your own SQL in `MyTweaks\`.

## StartAttackMacros (client addon)

`/sam` replaces the attack abilities on your action bars with
`#showtooltip` / `/startattack` / `/cast <ability>` macros. The buttons keep their icons and the highest rank is used.
`/sam all` converts every ability, `/sam undo` reverts the bars, and `/sam list` shows what's converted.

To install, copy `Addons\StartAttackMacros` into your 3.3.5a client's `Interface\AddOns\` and restart the client.
After `/sam`, **type `/reload`**. The client only saves new macros on `/reload` or a clean logout, and a crash before
that leaves the converted buttons empty.

## Known issues

- **The client crashes on every chat line (ERROR #132 at `0x00530475`) and you can't move.** This comes from a bug
  in the server's reconnect handling. After the game client exits uncleanly (a crash, or closing it in the world), the
  server keeps the character's session. On this build it never expires. The next login reconnects into that session,
  and the reconnect skips the tutorial flags packet (`SMSG_TUTORIAL_FLAGS`). The client then reads its missing
  tutorial data when you send a chat message, and crashes. The dashboard clears these sessions for you. To do it by
  hand, close the game and type `.kick <name>` in the Console tab.
- **The Dungeon Finder gives the same dungeon again, or no reward.** If you queue again while the old Dungeon Finder
  group still counts as being in its dungeon, the server "continues" that dungeon instead of picking a random one,
  and such runs give no Random reward. Leave the group and form a new one before you queue again.
- **Known playerbots crashes** of the world server, for example `ai::Engine::Reset` and `BindToInstance`. They're bugs
  in the bot module. The watchdog restarts the server, and the Crashes tab names them.
- With `lfg` in a chat channel, every bot within ±4 levels of you, anywhere in the world, tries to join.

## Notes

- The dashboard only listens on `localhost:8099`. POST requests need a special header and must come from localhost,
  so other websites can't control it.
- `Dashboard\CLAUDE.md` holds the developer notes: how it works, what has been tested, and server details learned
  along the way.
