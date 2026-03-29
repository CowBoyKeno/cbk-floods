local FloodController = {
    state = CBKFloods.deepCopy(Config.DefaultState),
    phaseIndex = 0,
    mode = 'idle',
    phaseStartAt = 0,
    phaseTransitionAt = 0,
    phaseTargetLevel = 0.0,
    phaseStartLevel = 0.0,
    actor = nil
}

local function unix()
    return os.time()
end

local function scaledLevel(level)
    return CBKFloods.clamp(
        (level or 0.0) * (Config.FloodProfile.levelMultiplier or 1.0),
        Config.FloodProfile.baseLevel,
        Config.FloodProfile.maxLevel
    )
end

local function scaledDuration(phase)
    local seconds = phase and phase.duration or 0
    local multiplier = phase and phase.kind == 'ramp'
        and (Config.FloodProfile.rampMultiplier or 1.0)
        or (Config.FloodProfile.waitMultiplier or 1.0)

    return math.max(0, math.floor((seconds * multiplier) + 0.5))
end

local function syncGlobalState()
    FloodController.state.updatedAt = unix()
    GlobalState[Config.StateBagName] = FloodController.state
end

local function isAllowed(src)
    if src == 0 then return true end
    return IsPlayerAceAllowed(src, Config.PermissionAce)
end

local function canViewAdminUi(src)
    if src == 0 then return true end
    if Config.ShowUiToAdminsOnly == false then
        return true
    end

    return IsPlayerAceAllowed(src, Config.AdminUiAce or Config.PermissionAce)
end

local function formatIdentifiers(src)
    local identifiers = GetPlayerIdentifiers(src)
    if not identifiers or #identifiers == 0 then
        return 'none'
    end

    return table.concat(identifiers, ', ')
end

local function logPermissionState(src, allowed, context)
    if src == 0 then
        print(('[cbk-floods] ACE %s for console on %s (ace=%s)'):format(
            allowed and 'allowed' or 'denied',
            context,
            Config.PermissionAce
        ))
        return
    end

    print(('[cbk-floods] ACE %s for %s on %s | ace=%s | identifiers=%s'):format(
        allowed and 'allowed' or 'denied',
        ('%s (%s)'):format(GetPlayerName(src) or 'unknown', src),
        context,
        Config.PermissionAce,
        formatIdentifiers(src)
    ))
end

local function notify(src, description, notifType)
    if src == 0 then
        print(('[cbk-floods] %s'):format(description))
        return
    end

    if Config.UseOxLibNotify then
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'CBK Floods',
            description = description,
            type = notifType or 'inform'
        })
    end

    if Config.UseChatMessages ~= false then
        TriggerClientEvent('chat:addMessage', src, {
            color = { 0, 153, 255 },
            args = { 'CBK Floods', description }
        })
    end
end

local function broadcast(message, notifType)
    if Config.UseOxLibNotify then
        TriggerClientEvent('ox_lib:notify', -1, {
            title = 'Emergency Management',
            description = message,
            type = notifType or 'inform',
            duration = 8000
        })
    end

    if Config.UseChatMessages ~= false then
        TriggerClientEvent('chat:addMessage', -1, {
            color = { 255, 80, 80 },
            args = { 'Emergency Management', message }
        })
    end
end

local function setMode(mode)
    FloodController.mode = mode
    FloodController.state.mode = mode
    FloodController.state.enabled = mode ~= 'idle'
end

local function grantAdminUiSession(src)
    if src == 0 then return end
    TriggerClientEvent('cbk-floods:client:setAdminUiAccess', src, true)
end

local function pulseAlarm()
    FloodController.state.alarmToken = (FloodController.state.alarmToken or 0) + 1
end

local function resetController(reason)
    FloodController.state = CBKFloods.deepCopy(Config.DefaultState)
    FloodController.phaseIndex = 0
    FloodController.phaseStartAt = 0
    FloodController.phaseTransitionAt = 0
    FloodController.phaseTargetLevel = 0.0
    FloodController.phaseStartLevel = 0.0
    FloodController.actor = nil
    setMode('idle')
    FloodController.state.reason = reason
    syncGlobalState()
end

local function getPhaseTrend(startLevel, targetLevel)
    if targetLevel > startLevel then
        return 'rising'
    end

    if targetLevel < startLevel then
        return 'falling'
    end

    return 'steady'
end

local function beginPhase(index)
    local phase = Config.FloodProfile.phases[index]
    if not phase then
        resetController('Scenario complete.')
        broadcast(Config.FloodProfile.completeMessage or 'Flood event complete.', 'success')
        return
    end

    local now = unix()
    local duration = scaledDuration(phase)
    local targetLevel = scaledLevel(phase.targetLevel)

    FloodController.phaseIndex = index
    FloodController.phaseStartAt = now
    FloodController.phaseTransitionAt = now + duration
    FloodController.phaseStartLevel = FloodController.state.level or Config.FloodProfile.baseLevel
    FloodController.phaseTargetLevel = targetLevel

    FloodController.state.stage = index
    FloodController.state.stageName = phase.name or ('Stage %s'):format(index)
    FloodController.state.maxLevel = Config.FloodProfile.maxLevel
    FloodController.state.alarm = phase.alarm == true
    FloodController.state.holdUntil = FloodController.phaseTransitionAt
    FloodController.state.weatherType = phase.weatherType
    FloodController.state.weatherTransitionSeconds = phase.weatherTransitionSeconds or 0
    FloodController.state.rainLevel = phase.rainLevel ~= nil and phase.rainLevel or -1.0
    FloodController.state.windSpeed = phase.windSpeed or 0.0
    FloodController.state.windDirectionDegrees = phase.windDirectionDegrees or 0.0
    FloodController.state.summary = phase.summary or phase.message or 'Flood conditions are evolving.'
    FloodController.state.trend = getPhaseTrend(FloodController.phaseStartLevel, targetLevel)

    if phase.kind == 'ramp' then
        setMode('ramping')
    else
        setMode('holding')
        FloodController.state.level = targetLevel
    end

    if phase.alarm == true then
        pulseAlarm()
    end

    if phase.message then
        broadcast(phase.message, phase.messageType or 'inform')
    end

    syncGlobalState()

    if duration <= 0 then
        if FloodController.mode == 'ramping' then
            FloodController.state.level = targetLevel
            syncGlobalState()
        end
        beginPhase(index + 1)
    end
end

local function startFlood(src)
    if FloodController.mode ~= 'idle' then
        return false, 'Flood event is already active.'
    end

    FloodController.state = CBKFloods.deepCopy(Config.DefaultState)
    FloodController.state.enabled = true
    FloodController.state.startedAt = unix()
    FloodController.state.level = Config.FloodProfile.baseLevel
    FloodController.actor = src
    beginPhase(1)
    return true, 'Flood event started.'
end

local function stopFlood(src, reason)
    if FloodController.mode == 'idle' then
        return false, 'Flood event is not active.'
    end

    resetController(reason or ('Stopped by %s'):format(src == 0 and 'console' or ('player %s'):format(src)))
    broadcast('Flood event has been reset to normal conditions.', 'success')
    return true, 'Flood event stopped.'
end

local function setFloodLevel(src, level)
    level = tonumber(level)
    if not level then
        return false, 'Invalid level.'
    end

    level = CBKFloods.clamp(level, Config.FloodProfile.baseLevel, Config.FloodProfile.maxLevel)
    FloodController.state.enabled = true
    FloodController.state.level = level
    FloodController.state.stageName = 'Manual Override'
    FloodController.state.stage = FloodController.phaseIndex
    FloodController.state.maxLevel = Config.FloodProfile.maxLevel
    FloodController.state.alarm = true
    FloodController.state.holdUntil = 0
    FloodController.state.weatherType = 'THUNDER'
    FloodController.state.weatherTransitionSeconds = 15
    FloodController.state.rainLevel = 1.0
    FloodController.state.windSpeed = 10.0
    FloodController.state.windDirectionDegrees = 210.0
    FloodController.state.summary = ('Flood level manually set to %.2f meters.'):format(level)
    FloodController.state.trend = 'steady'
    setMode('manual')
    pulseAlarm()
    syncGlobalState()
    broadcast(('Flood level manually set to %.2f by admin.'):format(level), 'warning')
    return true, ('Flood level set to %.2f.'):format(level)
end

exports('GetFloodState', function()
    return FloodController.state
end)

lib.callback.register('cbk-floods:server:getState', function()
    return FloodController.state
end)

lib.callback.register('cbk-floods:server:canViewUi', function(source)
    return canViewAdminUi(source)
end)

CreateThread(function()
    resetController('Resource initialized.')

    while true do
        Wait(Config.UpdateIntervalMs)

        if FloodController.mode == 'idle' then
            goto continue
        end

        local now = unix()

        if FloodController.mode == 'holding' then
            if now >= FloodController.phaseTransitionAt then
                beginPhase(FloodController.phaseIndex + 1)
            end
        elseif FloodController.mode == 'ramping' then
            local total = math.max(1, FloodController.phaseTransitionAt - FloodController.phaseStartAt)
            local elapsed = math.max(0, now - FloodController.phaseStartAt)
            local progress = CBKFloods.clamp(elapsed / total, 0.0, 1.0)
            local nextLevel = CBKFloods.round(
                FloodController.phaseStartLevel + ((FloodController.phaseTargetLevel - FloodController.phaseStartLevel) * progress),
                2
            )

            if nextLevel ~= FloodController.state.level then
                FloodController.state.level = nextLevel
                syncGlobalState()
            end

            if progress >= 1.0 then
                if FloodController.state.level ~= FloodController.phaseTargetLevel then
                    FloodController.state.level = FloodController.phaseTargetLevel
                    syncGlobalState()
                end

                beginPhase(FloodController.phaseIndex + 1)
            end
        end

        ::continue::
    end
end)

local function requirePermission(src)
    local allowed = isAllowed(src)
    if not allowed then
        logPermissionState(src, false, 'command check')
        notify(src, 'You do not have permission to manage flood events.', 'error')
        return false
    end
    return true
end

RegisterCommand(('%sstart'):format(Config.CommandPrefix), function(src)
    if not requirePermission(src) then return end
    local ok, msg = startFlood(src)
    if ok then
        grantAdminUiSession(src)
    end
    notify(src, msg, ok and 'success' or 'error')
end, false)

RegisterCommand(('%sstop'):format(Config.CommandPrefix), function(src)
    if not requirePermission(src) then return end
    local ok, msg = stopFlood(src)
    if ok then
        grantAdminUiSession(src)
    end
    notify(src, msg, ok and 'success' or 'error')
end, false)

RegisterCommand(('%sset'):format(Config.CommandPrefix), function(src, args)
    if not requirePermission(src) then return end
    local ok, msg = setFloodLevel(src, args[1])
    if ok then
        grantAdminUiSession(src)
    end
    notify(src, msg, ok and 'success' or 'error')
end, false)

RegisterCommand(('%sstatus'):format(Config.CommandPrefix), function(src)
    if not requirePermission(src) then return end
    grantAdminUiSession(src)

    local state = FloodController.state
    local nextTransitionIn = math.max(0, (state.holdUntil or 0) - unix())

    notify(src, ('Mode: %s | Stage: %s | Level: %.2f | Next change: %ss | Weather: %s'):format(
        FloodController.mode,
        state.stageName,
        state.level or 0.0,
        nextTransitionIn,
        state.weatherType or 'dynamic'
    ), 'inform')
end, false)

RegisterCommand(('%sperm'):format(Config.CommandPrefix), function(src)
    local allowed = isAllowed(src)
    logPermissionState(src, allowed, 'permission self-test')

    notify(src, ('Permission check for "%s": %s. Identifier details were logged to server console.'):format(
        Config.PermissionAce,
        allowed and 'allowed' or 'denied'
    ), allowed and 'success' or 'warning')
end, false)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    GlobalState[Config.StateBagName] = nil
end)
