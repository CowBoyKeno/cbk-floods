local state = CBKFloods.deepCopy(Config.DefaultState)
local activeAlarm = false
local uiVisible = false
local waterLoaded = false
local waterQuadCount = 0
local baseWaterLevels = {}
local waterQuadMeta = {}
local renderedFloodLevel = nil
local lastAlarmToken = 0
local canViewUi = Config.ShowUiToAdminsOnly ~= true
local forcedUiViewer = false
local lastUiPermissionCheckAt = -10000
local lastStateReceivedAt = 0
local lastWaterDeathPed = 0
local lastWaterDeathEnabled = nil
local appliedWeather = {
    weatherType = nil,
    transitionSeconds = -1,
    rainLevel = nil,
    windSpeed = nil,
    windDirectionDegrees = nil
}
local weatherResetToken = 0
local frontendAlarmToken = 0

local function unix()
    local cloudTime = GetCloudTimeAsInt()
    if cloudTime and cloudTime > 0 then
        return cloudTime
    end

    local stateUpdatedAt = (state and state.updatedAt) or 0
    if stateUpdatedAt <= 0 then
        return 0
    end

    local elapsedMs = math.max(0, GetGameTimer() - (lastStateReceivedAt or 0))
    return stateUpdatedAt + math.floor(elapsedMs / 1000)
end

local function notify(description, notifType)
    if Config.UseOxLibNotify then
        lib.notify({
            title = 'CBK Floods',
            description = description,
            type = notifType or 'inform'
        })
    end

    if Config.UseChatMessages ~= false then
        TriggerEvent('chat:addMessage', {
            color = { 0, 153, 255 },
            args = { 'CBK Floods', description }
        })
    else
        BeginTextCommandThefeedPost('STRING')
        AddTextComponentSubstringPlayerName(description)
        EndTextCommandThefeedPostTicker(false, false)
    end
end

local function nui(payload)
    SendNUIMessage(payload)
end

local function setUIVisible(toggle)
    if uiVisible == toggle then return end
    uiVisible = toggle
    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)
    nui({ action = 'setVisible', visible = toggle })
end

local function shouldShowUi()
    if not state.enabled then
        return false
    end

    if Config.ShowUiToAdminsOnly == false then
        return true
    end

    return canViewUi == true or forcedUiViewer == true
end

local function refreshUiPermission()
    lastUiPermissionCheckAt = GetGameTimer()

    if Config.ShowUiToAdminsOnly == false then
        canViewUi = true
        return true
    end

    local allowed = lib.callback.await('cbk-floods:server:canViewUi', false)
    canViewUi = allowed == true
    return canViewUi
end

local function playAlarm(toggle, force)
    if activeAlarm == toggle and not force then return end
    activeAlarm = toggle
    local alertSound = Config.AlertSound or {}

    nui({
        action = 'alarm',
        enabled = toggle,
        config = alertSound
    })

    frontendAlarmToken = frontendAlarmToken + 1

    if toggle and alertSound.enabled ~= false and alertSound.useFrontendFallback == true then
        local token = frontendAlarmToken

        CreateThread(function()
            local pulses = math.max(1, math.floor(tonumber(alertSound.pulses) or 1))
            local intervalMs = math.max(0, math.floor(tonumber(alertSound.intervalMs) or 0))

            for pulse = 1, pulses do
                if token ~= frontendAlarmToken then
                    return
                end

                PlaySoundFrontend(-1, alertSound.name or '5_SEC_WARNING', alertSound.set or 'DLC_HEISTS_GENERAL_FRONTEND_SOUNDS', true)

                if pulse < pulses and intervalMs > 0 then
                    Wait(intervalMs)
                end
            end

            if token ~= frontendAlarmToken then
                return
            end

            local finalName = alertSound.finalName
            local finalSet = alertSound.finalSet
            if finalName and finalSet then
                if intervalMs > 0 then
                    Wait(intervalMs)
                end

                if token ~= frontendAlarmToken then
                    return
                end

                PlaySoundFrontend(-1, finalName, finalSet, true)
            end
        end)
    end
end

local function applyFloodWeather(weatherType, transitionSeconds, windSpeed, windDirectionDegrees)
    if not weatherType or weatherType == '' then
        return
    end

    weatherResetToken = weatherResetToken + 1
    SetWeatherOwnedByNetwork(false)

    local normalizedType = tostring(weatherType)
    local normalizedTransition = math.max(0.0, tonumber(transitionSeconds) or 0.0)

    if appliedWeather.weatherType ~= normalizedType or math.abs((appliedWeather.transitionSeconds or -1) - normalizedTransition) > 0.01 then
        if normalizedTransition > 0.0 then
            SetWeatherTypeOvertimePersist(normalizedType, normalizedTransition + 0.0)

            CreateThread(function()
                local expectedType = normalizedType
                local waitMs = math.floor(normalizedTransition * 1000) + 1000
                Wait(waitMs)

                if state.enabled and state.weatherType == expectedType then
                    SetWeatherTypeNowPersist(expectedType)
                    SetOverrideWeather(expectedType)
                end
            end)
        else
            SetWeatherTypeNowPersist(normalizedType)
            SetOverrideWeather(normalizedType)
        end

        appliedWeather.weatherType = normalizedType
        appliedWeather.transitionSeconds = normalizedTransition
    end

    local normalizedRainLevel = tonumber(state.rainLevel)
    if normalizedRainLevel == nil then
        normalizedRainLevel = -1.0
    end

    if appliedWeather.rainLevel ~= normalizedRainLevel then
        SetRainLevel(normalizedRainLevel + 0.0)
        appliedWeather.rainLevel = normalizedRainLevel
    end

    local normalizedWindSpeed = tonumber(windSpeed) or 0.0
    if appliedWeather.windSpeed ~= normalizedWindSpeed then
        SetWindSpeed(normalizedWindSpeed + 0.0)
        appliedWeather.windSpeed = normalizedWindSpeed
    end

    local normalizedWindDirection = tonumber(windDirectionDegrees) or 0.0
    if appliedWeather.windDirectionDegrees ~= normalizedWindDirection then
        SetWindDirection(math.rad(normalizedWindDirection))
        appliedWeather.windDirectionDegrees = normalizedWindDirection
    end
end

local function resetFloodWeather()
    weatherResetToken = weatherResetToken + 1
    local resetToken = weatherResetToken
    local resetWeatherType = Config.FloodProfile.resetWeatherType or 'CLEARING'
    local resetTransitionSeconds = math.max(0.0, tonumber(Config.FloodProfile.resetWeatherTransitionSeconds) or 0.0)

    if resetTransitionSeconds > 0.0 then
        SetWeatherTypeOvertimePersist(resetWeatherType, resetTransitionSeconds + 0.0)
    else
        SetWeatherTypeNowPersist(resetWeatherType)
    end

    SetWindSpeed(-1.0)
    SetWindDirection(-1.0)
    SetRainLevel(-1.0)

    appliedWeather = {
        weatherType = nil,
        transitionSeconds = -1,
        rainLevel = nil,
        windSpeed = nil,
        windDirectionDegrees = nil
    }

    CreateThread(function()
        local waitMs = math.floor(resetTransitionSeconds * 1000) + 1000
        if waitMs > 0 then
            Wait(waitMs)
        end

        if weatherResetToken ~= resetToken then
            return
        end

        ClearWeatherTypePersist()
        ClearOverrideWeather()
        SetWeatherOwnedByNetwork(true)
        SetRainLevel(-1.0)
        SetWindSpeed(-1.0)
        SetWindDirection(-1.0)
    end)
end

local function resetFloodWater()
    ResetWater()
    waterLoaded = false
    waterQuadCount = 0
    baseWaterLevels = {}
    waterQuadMeta = {}
end

local function captureWaterQuadMeta(index, baseLevel)
    local meta = {
        baseLevel = baseLevel,
        canFlood = false
    }

    local okBounds, minX, minY, maxX, maxY = GetWaterQuadBounds(index)
    if okBounds then
        meta.minX = minX + 0.0
        meta.minY = minY + 0.0
        meta.maxX = maxX + 0.0
        meta.maxY = maxY + 0.0
    end

    local minBaseLevel = Config.WaterFloodBaseLevelMin
    local maxBaseLevel = Config.WaterFloodBaseLevelMax
    local quadBaseLevel = baseLevel or 0.0
    local inBaseLevelBand = true

    if minBaseLevel ~= nil and quadBaseLevel < minBaseLevel then
        inBaseLevelBand = false
    end

    if maxBaseLevel ~= nil and quadBaseLevel > maxBaseLevel then
        inBaseLevelBand = false
    end

    meta.canFlood = Config.WaterSpreadUseAllLoadedQuads == true
        or inBaseLevelBand
        or quadBaseLevel <= (Config.WaterSpreadCoastalMaxBaseLevel or 8.0)

    return meta
end

local function applyWaterQuadBounds(index, meta, expansion)
    if not meta or meta.minX == nil then
        return
    end

    local minX = math.floor(meta.minX - expansion)
    local minY = math.floor(meta.minY - expansion)
    local maxX = math.ceil(meta.maxX + expansion)
    local maxY = math.ceil(meta.maxY + expansion)
    SetWaterQuadBounds(index, minX, minY, maxX, maxY)
end

local function getWaterActivationProgress(level)
    local maxFloodLevel = (state and state.maxLevel) or Config.FloodProfile.maxLevel or 1.0
    local normalizedLevel = CBKFloods.clamp((level or 0.0) / math.max(maxFloodLevel, 0.01), 0.0, 1.0)
    local riseStart = CBKFloods.clamp(Config.WaterSpreadRiseStart or 0.72, 0.0, 0.98)
    if normalizedLevel <= riseStart then
        return 0.0
    end

    local normalized = (normalizedLevel - riseStart) / math.max(1.0 - riseStart, 0.01)
    local curve = math.max(Config.WaterSpreadRiseCurve or 2.4, 1.0)
    return CBKFloods.clamp(normalized ^ curve, 0.0, 1.0)
end

local function loadFloodWater()
    if (Config.FloodWaterMode or 'water_xml') ~= 'water_xml' then
        return false
    end

    resetFloodWater()

    local clipRect = Config.WaterClipRect
    if clipRect then
        SetWaterAreaClipRect(
            clipRect.minX,
            clipRect.minY,
            clipRect.maxX,
            clipRect.maxY
        )
    end

    local waterFile = Config.WaterXmlFile or 'water.xml'
    local success = LoadWaterFromPath(GetCurrentResourceName(), waterFile)
    waterLoaded = success == true or success == 1

    if not waterLoaded then
        print(('[cbk-floods] failed to load %s via LoadWaterFromPath'):format(waterFile))
        return false
    end

    waterQuadCount = GetWaterQuadCount()
    local floodCapableQuadCount = 0

    for i = 0, waterQuadCount - 1 do
        local okLevel, waterLevel = GetWaterQuadLevel(i)
        if okLevel then
            baseWaterLevels[i] = waterLevel + 0.0
            waterQuadMeta[i] = captureWaterQuadMeta(i, baseWaterLevels[i])
            if waterQuadMeta[i].canFlood then
                floodCapableQuadCount = floodCapableQuadCount + 1
            end
        end
    end

    if waterQuadCount <= 1 then
        print(('[cbk-floods] warning: %s exposed only %s water quad at runtime. Continuing so the asset can be tested.'):format(waterFile, waterQuadCount))
    end

    print(('[cbk-floods] loaded %s with %s water quads (%s flood quads)'):format(
        waterFile,
        waterQuadCount,
        floodCapableQuadCount
    ))

    if Config.WaterSpreadExpandBounds then
        local configuredExpansionLimit = math.max(Config.WaterSpreadExpansionLimit or 0.0, 0.0)
        if configuredExpansionLimit > 0.0 then
            print(('[cbk-floods] runtime water quad bounds expansion enabled (requested %.2f, capped to %.2f)'):format(
                Config.WaterSpreadExpansion or 0.0,
                configuredExpansionLimit
            ))
        else
            print(('[cbk-floods] runtime water quad bounds expansion enabled (requested %.2f, uncapped test mode)'):format(
                Config.WaterSpreadExpansion or 0.0
            ))
        end
    else
        print('[cbk-floods] runtime water quad bounds expansion is disabled.')
    end

    return waterQuadCount > 0
end

local function ensureWaterLoaded()
    if waterLoaded and waterQuadCount > 0 then
        return true
    end

    return loadFloodWater()
end

local function renderFloodWater(level)
    if not Config.EnableFloodWater then
        return
    end

    if (level or 0.0) <= (Config.FloodProfile.baseLevel or 0.0) then
        return
    end

    if (Config.FloodWaterMode or 'water_xml') ~= 'water_xml' then
        return
    end

    if not ensureWaterLoaded() then
        return
    end

    local waterOffset = ((level or 0.0) * (Config.WaterLevelScale or 1.0)) + (Config.WaterLevelBias or 0.0)
    local heightProgress = getWaterActivationProgress(level)

    for i = 0, waterQuadCount - 1 do
        local baseLevel = baseWaterLevels[i]
        if baseLevel ~= nil then
            local meta = waterQuadMeta[i]
            if meta and meta.canFlood then
                SetWaterQuadLevel(i, baseLevel + waterOffset)

                if Config.WaterSpreadExpandBounds and meta.minX ~= nil then
                    local expansionProgress = heightProgress
                    if Config.WaterSpreadExpansionUsesHeight ~= false then
                        local expansionLead = CBKFloods.clamp(Config.WaterSpreadExpansionLead or 0.0, 0.0, 0.35)
                        expansionProgress = CBKFloods.clamp(heightProgress + expansionLead, 0.0, 1.0)
                    end

                    local requestedExpansion = (Config.WaterSpreadExpansion or 0.0) * expansionProgress
                    local expansionLimit = math.max(Config.WaterSpreadExpansionLimit or 0.0, 0.0)
                    local expansion = expansionLimit > 0.0 and math.min(requestedExpansion, expansionLimit) or requestedExpansion
                    applyWaterQuadBounds(i, meta, expansion)
                end
            else
                SetWaterQuadLevel(i, baseLevel)
            end
        end
    end
end

local function syncWaterDeathSetting(force)
    local ped = PlayerPedId()
    if not DoesEntityExist(ped) then
        return
    end

    local floodActive = state.enabled == true and (state.level or 0.0) > (Config.FloodProfile.baseLevel or 0.0)
    local shouldDieInWater = not floodActive

    if force or ped ~= lastWaterDeathPed or shouldDieInWater ~= lastWaterDeathEnabled then
        SetPedDiesInWater(ped, shouldDieInWater)
        lastWaterDeathPed = ped
        lastWaterDeathEnabled = shouldDieInWater
    end
end

local function runWaterProbe(coords)
    coords = coords or GetEntityCoords(PlayerPedId())
    local ped = PlayerPedId()
    local quad2d = GetWaterQuadAtCoords(coords.x, coords.y)
    local quad3d = GetWaterQuadAtCoords_3d(coords.x, coords.y, coords.z)
    local hasWaterHeight, waterHeight = GetWaterHeightNoWaves(coords.x, coords.y, coords.z + 250.0)
    local inWater = DoesEntityExist(ped) and IsEntityInWater(ped) or false

    local summary = ('Probe x=%.2f y=%.2f z=%.2f | 2d=%s | 3d=%s | inWater=%s | waterHeight=%s'):format(
        coords.x,
        coords.y,
        coords.z,
        quad2d,
        quad3d,
        inWater and 'true' or 'false',
        hasWaterHeight and ('%.2f'):format(waterHeight) or 'none'
    )

    print(('[cbk-floods] %s'):format(summary))

    if quad2d >= 0 then
        local okLevel, quadLevel = GetWaterQuadLevel(quad2d)
        local okBounds, minX, minY, maxX, maxY = GetWaterQuadBounds(quad2d)
        local okType, quadType = GetWaterQuadType(quad2d)

        print(('[cbk-floods] probe quad=%s level=%s type=%s bounds=%s,%s -> %s,%s'):format(
            quad2d,
            okLevel and ('%.2f'):format(quadLevel) or 'unknown',
            okType and quadType or 'unknown',
            okBounds and minX or 'unknown',
            okBounds and minY or 'unknown',
            okBounds and maxX or 'unknown',
            okBounds and maxY or 'unknown'
        ))
    end

    if quad2d >= 0 and quad3d == -1 then
        notify('Flood probe: 2D surface exists here, but 3D water volume does not. This is a render/volume mismatch.', 'warning')
    else
        notify(('Flood probe logged to F8. 2D quad: %s | 3D quad: %s'):format(quad2d, quad3d), 'inform')
    end
end

local function refreshUI()
    local holdRemaining = 0
    if (state.holdUntil or 0) > 0 then
        holdRemaining = math.max(0, state.holdUntil - unix())
    end

    local statusText = 'Monitoring'
    local stateClass = 'safe'
    local summary = state.summary or 'Normal conditions.'

    if not state.enabled then
        statusText = 'Idle'
        summary = state.summary or 'Flood event inactive.'
    elseif state.mode == 'holding' then
        if state.alarm == true then
            statusText = 'Emergency Warning'
            stateClass = 'unsafe'
        elseif (state.level or 0.0) >= ((state.maxLevel or Config.FloodProfile.maxLevel) - 0.01) then
            statusText = 'Peak Flooding'
            stateClass = 'unsafe'
        else
            statusText = 'Storm Escalating'
            stateClass = 'unsafe'
        end
    elseif state.mode == 'ramping' and state.trend == 'falling' then
        statusText = 'Waters Receding'
        stateClass = 'unsafe'
    elseif state.mode == 'ramping' then
        statusText = 'Waters Rising'
        stateClass = 'unsafe'
    elseif state.alarm == true then
        statusText = 'Emergency Active'
        stateClass = 'unsafe'
    elseif state.mode == 'manual' then
        statusText = 'Manual Override'
        stateClass = 'unsafe'
    end

    nui({
        action = 'update',
        payload = {
            enabled = state.enabled,
            stage = state.stage or 0,
            stageName = state.stageName or 'Idle',
            level = CBKFloods.round(state.level or 0.0, 2),
            maxLevel = state.maxLevel or Config.FloodProfile.maxLevel,
            alarm = state.alarm == true,
            holdRemaining = holdRemaining,
            statusText = statusText,
            stateClass = stateClass,
            summary = summary
        }
    })
end

local function onStateChanged(newState)
    state = newState or CBKFloods.deepCopy(Config.DefaultState)
    lastStateReceivedAt = GetGameTimer()
    local now = GetGameTimer()

    if state.enabled and Config.ShowUiToAdminsOnly == true and canViewUi ~= true and (now - lastUiPermissionCheckAt) >= 5000 then
        refreshUiPermission()
    end

    local showUi = shouldShowUi()

    if showUi then
        setUIVisible(true)
    else
        setUIVisible(false)
        if not state.enabled then
            playAlarm(false)
            resetFloodWeather()
            if Config.EnableFloodWater then
                resetFloodWater()
            end
            renderedFloodLevel = nil
        end
    end

    if state.enabled then
        applyFloodWeather(
            state.weatherType,
            state.weatherTransitionSeconds,
            state.windSpeed,
            state.windDirectionDegrees
        )
    end

    local alarmEnabled = state.alarm == true and state.enabled == true
    local alarmToken = state.alarmToken or 0

    if alarmEnabled and alarmToken > lastAlarmToken then
        playAlarm(true, true)
    else
        playAlarm(alarmEnabled)
    end

    lastAlarmToken = alarmToken
    syncWaterDeathSetting(true)
    refreshUI()
end

RegisterNetEvent('cbk-floods:client:setAdminUiAccess', function(enabled)
    forcedUiViewer = enabled == true

    if state.enabled then
        setUIVisible(shouldShowUi())
        refreshUI()
    end
end)

AddStateBagChangeHandler(Config.StateBagName, 'global', function(_, _, value)
    if not value then return end
    onStateChanged(value)
end)

CreateThread(function()
    Wait(1000)

    for attempt = 1, 15 do
        if NetworkIsPlayerActive(PlayerId()) then
            refreshUiPermission()

            local ok, serverState = pcall(function()
                return lib.callback.await('cbk-floods:server:getState', false)
            end)

            if ok and serverState then
                onStateChanged(serverState)
                return
            end
        end

        Wait(1000)
    end

    refreshUiPermission()
    refreshUI()
end)

CreateThread(function()
    while true do
        if not Config.EnableFloodWater then
            if renderedFloodLevel ~= nil then
                resetFloodWater()
                renderedFloodLevel = nil
            end

            Wait(1000)
            goto continue
        end

        if state.enabled and (state.level or 0.0) > (Config.FloodProfile.baseLevel or 0.0) then
            local currentLevel = state.level or 0.0

            if renderedFloodLevel == nil then
                renderFloodWater(currentLevel)
                renderedFloodLevel = currentLevel
            elseif math.abs(currentLevel - renderedFloodLevel) >= 0.01 then
                renderFloodWater(currentLevel)
                renderedFloodLevel = currentLevel
            end

            Wait(250)
            goto continue
        end

        if renderedFloodLevel ~= nil then
            resetFloodWater()
            renderedFloodLevel = nil
        end

        Wait(250)
        ::continue::
    end
end)

CreateThread(function()
    while true do
        Wait(1000)
        syncWaterDeathSetting(false)
    end
end)

RegisterNetEvent('onClientResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    refreshUiPermission()
    refreshUI()
end)

RegisterCommand(('%sprobe'):format(Config.CommandPrefix), function()
    runWaterProbe()
end, false)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    if Config.EnableFloodWater then
        resetFloodWater()
    end
    local ped = PlayerPedId()
    if DoesEntityExist(ped) then
        SetPedDiesInWater(ped, true)
    end
    resetFloodWeather()
    playAlarm(false)
    setUIVisible(false)
end)

exports('GetFloodState', function()
    return state
end)
