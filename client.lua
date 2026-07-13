local RESOURCE = GetCurrentResourceName()
local M1_CLIENT_SIGNATURE = 'M1WT-CLIENT-GUARD-v1'
local M1_READY = false
local M1_LOCKED = false

local Current = {
    weather = Config.DefaultWeather or 'EXTRASUNNY',
    hour = Config.DefaultHour or 12,
    minute = Config.DefaultMinute or 0,
    freeze = Config.FreezeTime ~= false
}

local function M1Lock(reason)
    M1_LOCKED = true
    print(('[%s] ^1M1 CLIENT LOCK:^7 %s'):format(RESOURCE, reason))
end

local function M1IntegrityCheck()
    if type(Config) ~= 'table' or type(Config.M1Connection) ~= 'table' then
        return M1Lock('Config.M1Connection bulunamadı.')
    end

    if RESOURCE ~= Config.M1Connection.resourceName then
        return M1Lock(('Resource adı yanlış. Beklenen: %s | Şu an: %s'):format(Config.M1Connection.resourceName, RESOURCE))
    end

    if Config.M1Connection.signature ~= 'M1WT-2026-LOCK-9F4A' then
        return M1Lock('M1 imza anahtarı değişmiş.')
    end

    M1_READY = true
    print(('[%s] ^2M1 client bağlantısı aktif.^7 İmza: %s'):format(RESOURCE, M1_CLIENT_SIGNATURE))
end

CreateThread(function()
    Wait(500)
    M1IntegrityCheck()
    Wait(1000)
    TriggerServerEvent('m1-weather-time:server:requestSync')
end)

local LastAppliedWeather = nil

local function IsRainWeather(weather)
    weather = tostring(weather or ''):upper()
    return weather == 'RAIN' or weather == 'THUNDER'
end

local function ApplyWeather(weather)
    weather = tostring(weather or ''):upper()
    if weather == '' then return end

    if LastAppliedWeather ~= weather then
        ClearOverrideWeather()
        ClearWeatherTypePersist()
        LastAppliedWeather = weather
    end

    -- Diğer weather scriptleri araya girerse bile M1 state'i geri basar.
    SetWeatherTypePersist(weather)
    SetWeatherTypeNow(weather)
    SetWeatherTypeNowPersist(weather)
    SetOverrideWeather(weather)

    local force = Config.ClientForceSync or {}
    if force.clearRainWhenNotRain ~= false then
        if weather == 'RAIN' then
            SetRainLevel(0.45)
        elseif weather == 'THUNDER' then
            SetRainLevel(0.85)
        else
            SetRainLevel(0.0)
            SetWindSpeed(0.0)
        end
    end
end

local function ApplyTime(hour, minute)
    local h = tonumber(hour) or 12
    local m = tonumber(minute) or 0

    if h < 0 then h = 0 end
    if h > 23 then h = 23 end
    if m < 0 then m = 0 end
    if m > 59 then m = 59 end

    NetworkOverrideClockTime(h, m, 0)
end

RegisterNetEvent('m1-weather-time:client:sync', function(data)
    if M1_LOCKED then return end
    if type(data) ~= 'table' then return end

    Current.weather = data.weather or Current.weather
    Current.hour = tonumber(data.hour) or Current.hour
    Current.minute = tonumber(data.minute) or Current.minute
    Current.freeze = data.freeze ~= false

    ApplyWeather(Current.weather)
    ApplyTime(Current.hour, Current.minute)

    SendNUIMessage({
        action = 'state',
        state = Current
    })
end)

RegisterNetEvent('m1-weather-time:client:open', function(mode, state, profile)
    if M1_LOCKED or not M1_READY then return end

    if type(state) == 'table' then
        Current.weather = state.weather or Current.weather
        Current.hour = tonumber(state.hour) or Current.hour
        Current.minute = tonumber(state.minute) or Current.minute
        Current.freeze = state.freeze ~= false
    end

    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'open',
        mode = mode,
        state = Current,
        options = Config.WeatherOptions or {},
        locale = Config.Locale or {},
        m1 = Config.M1Connection.uiSignature,
        playerName = GetPlayerName(PlayerId()) or 'Admin',
        profile = profile or { avatar = 'default-avatar.svg', source = 'default' }
    })
end)

RegisterNetEvent('m1-weather-time:client:profile', function(profile)
    SendNUIMessage({
        action = 'profile',
        profile = profile or { avatar = 'default-avatar.svg', source = 'default' }
    })
end)

RegisterNetEvent('m1-weather-time:client:notify', function(msg, nType)
    if GetResourceState('qbx_core') == 'started' then
        local qboxType = nType == 'primary' and 'inform' or nType
        local ok = pcall(function()
            exports.qbx_core:Notify(msg, qboxType or 'inform', 5000)
        end)
        if ok then return end
    end

    if GetResourceState('qb-core') == 'started' then
        local ok, QBCore = pcall(function()
            return exports['qb-core']:GetCoreObject()
        end)
        if ok and QBCore and QBCore.Functions and QBCore.Functions.Notify then
            QBCore.Functions.Notify(msg, nType or 'primary')
            return
        end
    end

    if GetResourceState('es_extended') == 'started' then
        local ok, ESX = pcall(function()
            return exports['es_extended']:getSharedObject()
        end)
        if ok and ESX and ESX.ShowNotification then
            ESX.ShowNotification(msg)
            return
        end
    end

    TriggerEvent('chat:addMessage', {
        color = { 70, 160, 255 },
        multiline = true,
        args = { 'M1 Weather', msg }
    })
end)

RegisterNUICallback('m1ready', function(data, cb)
    local ok = data and data.signature == Config.M1Connection.uiSignature
    if not ok then
        M1Lock('NUI imza kontrolü başarısız.')
        SetNuiFocus(false, false)
    end
    cb({ ok = ok })
end)

RegisterNUICallback('close', function(_, cb)
    SetNuiFocus(false, false)
    cb({ ok = true })
end)

RegisterNUICallback('applyWeather', function(data, cb)
    if M1_LOCKED then return cb({ ok = false }) end
    TriggerServerEvent('m1-weather-time:server:setWeather', data and data.weather)
    SetNuiFocus(false, false)
    cb({ ok = true })
end)

RegisterNUICallback('applyTime', function(data, cb)
    if M1_LOCKED then return cb({ ok = false }) end
    TriggerServerEvent('m1-weather-time:server:setTime', data and data.hour, data and data.minute)
    SetNuiFocus(false, false)
    cb({ ok = true })
end)

CreateThread(function()
    while true do
        local force = Config.ClientForceSync or {}
        local waitMs = tonumber(force.applyIntervalMs) or 250
        if waitMs < 100 then waitMs = 100 end

        Wait(waitMs)

        if not M1_LOCKED and force.enabled ~= false then
            ApplyWeather(Current.weather)
            if Current.freeze then
                ApplyTime(Current.hour, Current.minute)
            end
        end
    end
end)

CreateThread(function()
    Wait(5000)
    while true do
        local force = Config.ClientForceSync or {}
        local seconds = tonumber(force.requestServerSyncSeconds) or 25
        if seconds < 10 then seconds = 10 end

        Wait(seconds * 1000)

        if not M1_LOCKED then
            TriggerServerEvent('m1-weather-time:server:requestSync')
        end
    end
end)

AddEventHandler('onClientResourceStart', function(resourceName)
    if resourceName == RESOURCE then
        SetTimeout(1500, function()
            TriggerServerEvent('m1-weather-time:server:requestSync')
        end)
    end
end)
