# Deployment Notes

## Start Order

1. `ox_lib`
2. `cbk-floods`

## Server.cfg Example

```cfg
add_ace group.admin cbk.floods.manage allow
add_principal identifier.license:YOUR_LICENSE_HERE group.admin

ensure ox_lib
ensure cbk-floods
```

If you use a different ACE group, update the `add_principal` line to target that group. If commands still deny access, run `/floodperm` in game and copy the `license:` identifier from the server console log.

## Current Runtime Behavior

- `water.xml` is the active flood water asset
- The admin panel is restricted by `Config.ShowUiToAdminsOnly`
- Public warnings use chat by default because they are easier to read during long events
- The alarm is synthesized in NUI from `Config.AlertSound`
- Drowning is only suppressed while active flood water is above the base level

## Integration Points

- Read state from `GlobalState.cbkFloodState`
- Use `exports['cbk-floods']:GetFloodState()` on client or server for direct reads

Useful state fields:

- `enabled`
- `mode`
- `stage`
- `stageName`
- `level`
- `maxLevel`
- `holdUntil`
- `weatherType`
- `summary`

## Main Tuning Areas

### Timeline

Edit `Config.FloodProfile.phases` to control:

- event length
- weather sequence
- warning timing
- rise speed
- recession timing
- public alert copy

### Water

Edit these for runtime water behavior:

- `Config.WaterXmlFile`
- `Config.WaterLevelScale`
- `Config.WaterLevelBias`
- `Config.WaterSpreadExpansion`
- `Config.WaterSpreadExpansionLimit`
- `Config.WaterFloodBaseLevelMin`
- `Config.WaterFloodBaseLevelMax`
- `Config.WaterSpreadRiseStart`
- `Config.WaterSpreadRiseCurve`

Edit `water.xml` when you need to change actual authored flood coverage or fill map gaps.

### Alerts

Edit these for warning behavior:

- `Config.UseChatMessages`
- `Config.UseOxLibNotify`
- `Config.AlertSound`
- per-phase `message`, `messageType`, and `alarm`

## Validation Checklist

Before public release, test:

1. `/floodperm` returns `allowed` for your admin account
2. `/floodstart` opens the admin panel for an admin
3. non-admin players do not receive the panel when `Config.ShowUiToAdminsOnly = true`
4. chat warnings are readable and appear at each key phase
5. weather transitions follow the configured sequence
6. water reaches all intended inland areas after a reconnect
7. `/floodstop` fully restores water and weather
8. normal drowning works again when no flood is active

## Operational Notes

- If you change `water.xml`, restart the resource and reconnect once for a clean client reload
- If water looks wrong at one spot, use `/floodprobe` and inspect F8 output
- Because flood water is client-native driven, every client must be running the same resource version for visuals and collision to stay aligned
