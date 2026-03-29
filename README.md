# CBK FLOODS #

Server-authoritative tsunami and flood event resource for FiveM RP servers.

## Features

- Full event timeline from overcast skies to heavy rain, thunderstorm, tsunami warning, peak flooding, and recession
- Map-wide flood water driven by the included authored `water.xml`
- ACE-restricted admin controls
- Admin-only status panel by default with live stage, level, timer, and status
- Bulletin-style NUI alarm with optional frontend sound fallback
- Chat-based public warning broadcasts by default
- Client and server flood state exports for other resources

## Requirements

- OneSync
- `ox_lib`

## Included Files

- `water.xml` is the active flood water asset
- `ui/index.html`, `ui/app.js`, and `ui/style.css` power the admin panel and generated alarm
- There is no bundled alarm audio asset; the siren is generated from `Config.AlertSound`

## Install

1. Drop `cbk-floods` into your server `resources` folder.
2. Start `ox_lib` before `cbk-floods`.
3. Add ACE permissions and resource ensures to `server.cfg`.

Example:

```cfg
add_ace group.admin cbk.floods.manage allow
add_principal identifier.license:YOUR_LICENSE_HERE group.admin

ensure ox_lib
ensure cbk-floods
```

If you use a custom ACE group, keep the `add_ace` line and change the `add_principal` target group to match your setup. The permission line alone does not grant access to a player.

## Default Event Flow

The default profile in `config/config.lua` runs for about 31 minutes:

1. `Storm Front` for 60s with `OVERCAST`
2. `Heavy Rain` for 60s with `RAIN`
3. `Tsunami Warning` for 120s with alarm and `THUNDER`
4. Four rising flood ramps over 8 minutes up to `200.0`
5. `Peak Flooding` hold for 15 minutes
6. Recession and weather clear-out back through `RAIN`, `OVERCAST`, `CLEARING`, and `CLEAR`

You can fully change this through `Config.FloodProfile.phases`.

## Commands

- `/floodstart` starts the configured scenario
- `/floodstop` immediately resets the event
- `/floodset <level>` applies a manual flood level override
- `/floodstatus` shows the current mode, stage, level, next transition, and weather
- `/floodperm` checks ACE access and logs your identifiers to the server console
- `/floodprobe` logs local water probe details in F8 for troubleshooting water surface and volume mismatch

## Admin Panel

- The panel is admin-only by default through `Config.ShowUiToAdminsOnly = true`
- The server explicitly grants panel access when an authorized admin uses flood commands
- The panel auto-closes when the event returns to idle
- Set `Config.ShowUiToAdminsOnly = false` if you want all players to see it

## Alerts And Messaging

- `Config.UseChatMessages = true` keeps chat warnings enabled
- `Config.UseOxLibNotify = true` enables `ox_lib` notifications
- You can enable both at the same time if you want chat and `ox_lib` alerts together
- Alarm behavior is controlled through `Config.AlertSound`

## Water Tuning

The most important water settings live in `config/config.lua`:

- `Config.WaterXmlFile`
- `Config.WaterLevelScale`
- `Config.WaterLevelBias`
- `Config.WaterSpreadExpansion`
- `Config.WaterSpreadExpansionLimit`
- `Config.WaterFloodBaseLevelMin`
- `Config.WaterFloodBaseLevelMax`
- `Config.WaterSpreadRiseStart`
- `Config.WaterSpreadRiseCurve`

`water.xml` is the real coverage asset. The config values control how the event raises and spreads that authored water body at runtime.

## Exports

### Client

```lua
exports['cbk-floods']:GetFloodState()
```

### Server

```lua
exports['cbk-floods']:GetFloodState()
```

Returned state includes fields such as:

- `enabled`
- `mode`
- `stage`
- `stageName`
- `level`
- `maxLevel`
- `holdUntil`
- `weatherType`
- `summary`

## Troubleshooting

- If commands deny access, run `/floodperm` and use the logged `license:` identifier in your `add_principal` line
- If the admin panel does not open, verify the player can run `/floodstatus`
- If water looks wrong after changing `water.xml`, `restart cbk-floods` and reconnect once so the client reloads the water asset cleanly
- If you are debugging a specific spot, use `/floodprobe` and check F8

## Notes

- Flood drowning protection only applies while flood water is actively above the base level
- The resource intentionally avoids persistence so it remains hot-reload-safe and predictable
- Public release cleanup for editor metadata is left out of runtime scope
