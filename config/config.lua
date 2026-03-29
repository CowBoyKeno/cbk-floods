Config = {}

Config.UseOxLibNotify = false
Config.PermissionAce = 'cbk.floods.manage'
Config.ShowUiToAdminsOnly = true
Config.AdminUiAce = Config.PermissionAce
Config.CommandPrefix = 'flood'
Config.StateBagName = 'cbkFloodState'

Config.UpdateIntervalMs = 500
Config.EnableFloodWater = true
Config.FloodWaterMode = 'water_xml'
Config.WaterXmlFile = 'water.xml'
Config.WaterClipRect = nil
Config.WaterLevelScale = 1.0
Config.WaterLevelBias = 0.0
Config.WaterSpreadExpansion = 1000.0
Config.WaterSpreadExpandBounds = true
Config.WaterSpreadExpansionLimit = 900.0
Config.WaterSpreadUseAllLoadedQuads = false
Config.WaterFloodBaseLevelMin = -5.0
Config.WaterFloodBaseLevelMax = 2.0
Config.WaterSpreadCoastalMaxBaseLevel = 2.0
Config.WaterSpreadExpansionUsesHeight = true
Config.WaterSpreadExpansionLead = 0.16
Config.WaterSpreadRiseStart = 0.82
Config.WaterSpreadRiseCurve = 2.4

Config.AlertSound = {
    enabled = true,
    useNuiSiren = true,
    sirenDurationMs = 6200,
    sirenVolume = 0.30,
    mode = 'bulletin',
    bulletinLowHz = 853,
    bulletinHighHz = 960,
    bulletinOnMs = 950,
    bulletinOffMs = 260,
    bulletinCycles = 4,
    bulletinStaticMs = 120,
    useFrontendFallback = false,
    name = '5_SEC_WARNING',
    set = 'DLC_HEISTS_GENERAL_FRONTEND_SOUNDS',
    pulses = 2,
    intervalMs = 220,
    finalName = 'Event_Start_Text',
    finalSet = 'GTAO_FM_Events_Soundset'
}

Config.DefaultState = {
    enabled = false,
    alarm = false,
    alarmToken = 0,
    stage = 0,
    stageName = 'Idle',
    mode = 'idle',
    trend = 'steady',
    level = 0.0,
    maxLevel = 200.0,
    startedAt = 0,
    holdUntil = 0,
    updatedAt = 0,
    weatherType = nil,
    weatherTransitionSeconds = 0,
    rainLevel = -1.0,
    windSpeed = 0.0,
    windDirectionDegrees = 0.0,
    summary = 'Flood event inactive.',
    reason = nil
}

Config.FloodProfile = {
    baseLevel = 0.0,
    maxLevel = 200.0,
    levelMultiplier = 1.0,
    waitMultiplier = 1.0,
    rampMultiplier = 1.0,
    resetWeatherType = 'CLEARING',
    resetWeatherTransitionSeconds = 45,
    completeMessage = 'Flood event complete. Waters have receded and conditions are stabilizing.',
    phases = {
        {
            name = 'Storm Front',
            kind = 'hold',
            targetLevel = 0.0,
            duration = 60,
            weatherType = 'OVERCAST',
            weatherTransitionSeconds = 45,
            rainLevel = 0.0,
            windSpeed = 3.5,
            windDirectionDegrees = 210.0,
            message = 'Dark clouds are rolling in. The city is moving into overcast conditions.',
            messageType = 'inform',
            summary = 'Skies are turning overcast as the storm front moves in.'
        },
        {
            name = 'Heavy Rain',
            kind = 'hold',
            targetLevel = 0.0,
            duration = 60,
            weatherType = 'RAIN',
            weatherTransitionSeconds = 45,
            rainLevel = 0.45,
            windSpeed = 5.5,
            windDirectionDegrees = 210.0,
            message = 'Rain bands are intensifying. Stay alert for emergency updates.',
            messageType = 'inform',
            summary = 'Rainfall is strengthening and visibility is dropping.'
        },
        {
            name = 'Tsunami Warning',
            kind = 'hold',
            targetLevel = 0.0,
            duration = 120,
            alarm = true,
            weatherType = 'THUNDER',
            weatherTransitionSeconds = 60,
            rainLevel = 0.75,
            windSpeed = 8.5,
            windDirectionDegrees = 210.0,
            message = 'Tsunami warning issued. Move to high ground immediately and prepare for flash flooding.',
            messageType = 'warning',
            summary = 'Emergency warning active. Get to high ground before the surge arrives.'
        },
        {
            name = 'Tsunami Impact',
            kind = 'ramp',
            targetLevel = 50.0,
            duration = 120,
            alarm = true,
            weatherType = 'THUNDER',
            weatherTransitionSeconds = 0,
            rainLevel = 1.0,
            windSpeed = 11.0,
            windDirectionDegrees = 210.0,
            message = 'Tsunami surge approaching now. Water is rising fast. Get to high ground immediately.',
            messageType = 'error',
            summary = 'The tsunami surge has arrived and flood water is climbing rapidly.'
        },
        {
            name = 'Major Flood Surge',
            kind = 'ramp',
            targetLevel = 100.0,
            duration = 120,
            weatherType = 'THUNDER',
            weatherTransitionSeconds = 0,
            rainLevel = 1.0,
            windSpeed = 12.0,
            windDirectionDegrees = 210.0,
            message = 'Water level has increased significantly. Move to even higher ground now.',
            messageType = 'warning',
            summary = 'Flood water is pushing inland and climbing toward rooftop level.'
        },
        {
            name = 'Extreme Flood Surge',
            kind = 'ramp',
            targetLevel = 150.0,
            duration = 120,
            weatherType = 'THUNDER',
            weatherTransitionSeconds = 0,
            rainLevel = 1.0,
            windSpeed = 12.0,
            windDirectionDegrees = 210.0,
            message = 'Flood level has increased again. Remaining on low structures is no longer safe.',
            messageType = 'warning',
            summary = 'Extreme flooding is underway. Only the highest terrain remains viable.'
        },
        {
            name = 'Catastrophic Peak Approach',
            kind = 'ramp',
            targetLevel = 200.0,
            duration = 120,
            weatherType = 'THUNDER',
            weatherTransitionSeconds = 0,
            rainLevel = 1.0,
            windSpeed = 12.0,
            windDirectionDegrees = 210.0,
            message = 'Water level has increased again. Catastrophic flooding is imminent. Reach the highest ground available.',
            messageType = 'error',
            summary = 'Flood waters are nearing their maximum map-wide height.'
        },
        {
            name = 'Peak Flooding',
            kind = 'hold',
            targetLevel = 200.0,
            duration = 900,
            weatherType = 'THUNDER',
            weatherTransitionSeconds = 0,
            rainLevel = 0.85,
            windSpeed = 10.0,
            windDirectionDegrees = 210.0,
            message = 'Peak flooding has been reached. Shelter in place on the highest ground and wait for waters to recede.',
            messageType = 'warning',
            summary = 'Flood waters are holding near the 200 meter peak.'
        },
        {
            name = 'Recession Begins',
            kind = 'ramp',
            targetLevel = 140.0,
            duration = 60,
            weatherType = 'RAIN',
            weatherTransitionSeconds = 45,
            rainLevel = 0.55,
            windSpeed = 7.0,
            windDirectionDegrees = 210.0,
            message = 'Flood waters are beginning to recede, but conditions remain extremely dangerous.',
            messageType = 'inform',
            summary = 'The water line is finally dropping, but only slowly.'
        },
        {
            name = 'Water Receding',
            kind = 'ramp',
            targetLevel = 70.0,
            duration = 60,
            weatherType = 'OVERCAST',
            weatherTransitionSeconds = 45,
            rainLevel = 0.0,
            windSpeed = 4.0,
            windDirectionDegrees = 210.0,
            message = 'Water level is falling. Continue using caution and avoid returning to low ground too early.',
            messageType = 'inform',
            summary = 'Rain is easing off as flood waters continue to drain away.'
        },
        {
            name = 'Clearing Out',
            kind = 'ramp',
            targetLevel = 0.0,
            duration = 60,
            weatherType = 'CLEARING',
            weatherTransitionSeconds = 45,
            rainLevel = 0.0,
            windSpeed = 2.0,
            windDirectionDegrees = 210.0,
            message = 'Flood waters are nearly gone. Continue carefully until emergency crews confirm all-clear conditions.',
            messageType = 'success',
            summary = 'Conditions are clearing as the last of the flood waters drain away.'
        },
        {
            name = 'Clear Skies',
            kind = 'hold',
            targetLevel = 0.0,
            duration = 60,
            weatherType = 'CLEAR',
            weatherTransitionSeconds = 30,
            rainLevel = 0.0,
            windSpeed = 1.0,
            windDirectionDegrees = 210.0,
            message = 'The storm has passed. Clear skies are returning across the region.',
            messageType = 'success',
            summary = 'Skies are clearing and the flood event is winding down.'
        }
    }
}
