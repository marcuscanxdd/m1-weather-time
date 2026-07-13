local RESOURCE = GetCurrentResourceName()
local M1_SERVER_SIGNATURE = 'M1WT-SERVER-GUARD-v2'
local M1_LOCKED = false
local StopAllConflictingResources

local State = {
    weather = Config.DefaultWeather or 'EXTRASUNNY',
    hour = Config.DefaultHour or 8,
    minute = Config.DefaultMinute or 0,
    freeze = Config.FreezeTime ~= false,
    manualWeatherLockUntil = 0
}

local NextDynamicWeatherAt = os.time() + ((Config.DynamicWeather and Config.DynamicWeather.intervalMinutes or 30) * 60)

local function M1Print(msg)
    print(('[%s] %s'):format(RESOURCE, msg))
end

local function M1Lock(reason)
    M1_LOCKED = true
    M1Print(('^1M1 LOCK:^7 %s'):format(reason))
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

    local app = LoadResourceFile(RESOURCE, 'html/app.js') or ''
    local css = LoadResourceFile(RESOURCE, 'html/style.css') or ''
    local html = LoadResourceFile(RESOURCE, 'html/index.html') or ''

    if not app:find("M1_UI_BRIDGE_SIGNATURE = 'M1WT%-NUI%-BRIDGE%-v1'", 1, false) then
        return M1Lock('NUI bridge imzası bozuk veya silinmiş.')
    end

    if not css:find('M1WT-STYLE-GUARD-v1', 1, true) then
        return M1Lock('Style guard imzası bozuk veya silinmiş.')
    end

    if not html:find('data-m1="M1WT-HTML-GUARD-v1"', 1, true) then
        return M1Lock('HTML guard imzası bozuk veya silinmiş.')
    end

    local autoDisable = Config.AutoDisableConflictingResources or {}
    if autoDisable.enabled and autoDisable.checkOnStart ~= false then
        StopAllConflictingResources('M1 ana weather/time sistemi aktif')
    else
        M1Print('^3UYARI:^7 AutoDisableConflictingResources kapalı. Başka weather/time scriptleri saat/havayı bozabilir.')
    end

    M1Print(('^2M1 bağlantısı aktif.^7 Server imza: %s'):format(M1_SERVER_SIGNATURE))
end

math.randomseed(os.time())

local function IsConflictResource(resourceName)
    local autoDisable = Config.AutoDisableConflictingResources or {}
    local lowerName = tostring(resourceName or ''):lower()

    if lowerName == '' or lowerName == RESOURCE:lower() then
        return false
    end

    for _, name in ipairs(autoDisable.resources or {}) do
        if lowerName == tostring(name):lower() then
            return true
        end
    end

    if autoDisable.blockByKeyword == true then
        for _, keyword in ipairs(autoDisable.blockedKeywords or {}) do
            keyword = tostring(keyword or ''):lower()
            if keyword ~= '' and lowerName:find(keyword, 1, true) then
                return true
            end
        end
    end

    return false
end

local function StopConflictingResource(resourceName, reason)
    local autoDisable = Config.AutoDisableConflictingResources or {}
    if autoDisable.enabled ~= true then return false end
    if not IsConflictResource(resourceName) then return false end

    local state = GetResourceState(resourceName)
    if state ~= 'started' and state ~= 'starting' then return false end

    M1Print(('^3Çakışan weather/time resource durduruluyor:^7 %s ^5(%s)^7 | Sebep: %s'):format(resourceName, state, reason or 'm1-sync'))
    StopResource(resourceName)
    return true
end

StopAllConflictingResources = function(reason)
    local autoDisable = Config.AutoDisableConflictingResources or {}
    if autoDisable.enabled ~= true then return end

    local checked = {}
    for _, resourceName in ipairs(autoDisable.resources or {}) do
        checked[resourceName] = true
        StopConflictingResource(resourceName, reason or 'başlangıç kontrolü')
    end

    if autoDisable.blockByKeyword == true then
        local resourceCount = GetNumResources()
        for i = 0, resourceCount - 1 do
            local resourceName = GetResourceByFindIndex(i)
            if resourceName and not checked[resourceName] then
                StopConflictingResource(resourceName, reason or 'keyword başlangıç kontrolü')
            end
        end
    end
end

CreateThread(M1IntegrityCheck)

local function Notify(src, msg, nType)
    if src == 0 then
        M1Print(msg)
        return
    end
    TriggerClientEvent('m1-weather-time:client:notify', src, msg, nType or 'primary')
end

local function DetectFramework()
    local configured = tostring((Config.Permissions and Config.Permissions.framework) or 'auto'):lower()
    if configured ~= 'auto' then
        return configured
    end

    if GetResourceState('qbx_core') == 'started' then return 'qbox' end
    if GetResourceState('qb-core') == 'started' then return 'qbcore' end
    if GetResourceState('es_extended') == 'started' then return 'esx' end

    return 'unknown'
end

local function HasQBCorePermission(src)
    if GetResourceState('qb-core') ~= 'started' then return false end

    local ok, QBCore = pcall(function()
        return exports['qb-core']:GetCoreObject()
    end)

    if not ok or not QBCore or not QBCore.Functions or not QBCore.Functions.HasPermission then
        return false
    end

    for _, permission in ipairs((Config.Permissions and Config.Permissions.qbcore) or { 'god', 'admin' }) do
        local success, allowed = pcall(function()
            return QBCore.Functions.HasPermission(src, permission)
        end)

        if success and allowed then
            return true
        end
    end

    return false
end

local function HasQboxPermission(src)
    if GetResourceState('qbx_core') ~= 'started' then return false end

    for _, ace in ipairs((Config.Permissions and Config.Permissions.qboxAce) or { 'admin' }) do
        if IsPlayerAceAllowed(src, ace) then
            return true
        end
    end

    return false
end

local function HasESXPermission(src)
    if GetResourceState('es_extended') ~= 'started' then return false end

    local ok, ESX = pcall(function()
        return exports['es_extended']:getSharedObject()
    end)

    if not ok or not ESX or not ESX.GetPlayerFromId then
        return false
    end

    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer or not xPlayer.getGroup then return false end

    local group = tostring(xPlayer.getGroup() or ''):lower()
    for _, allowedGroup in ipairs((Config.Permissions and Config.Permissions.esxGroups) or { 'admin' }) do
        if group == tostring(allowedGroup):lower() then
            return true
        end
    end

    return false
end

local function HasPermission(src)
    if src == 0 then return true end
    if not Config.AdminOnly then return true end

    local framework = DetectFramework()
    if framework == 'qbox' then return HasQboxPermission(src) end
    if framework == 'qbcore' then return HasQBCorePermission(src) end
    if framework == 'esx' then return HasESXPermission(src) end

    return false
end

local function IsWeatherValid(weather)
    if type(weather) ~= 'string' then return false end
    weather = weather:upper()
    for _, option in ipairs(Config.WeatherOptions or {}) do
        if option.value == weather then
            return true, weather
        end
    end
    return false
end

local function SendState(src)
    TriggerClientEvent('m1-weather-time:client:sync', src, State)
end

local function BroadcastState()
    GlobalState.m1_weather_time_weather = State.weather
    GlobalState.m1_weather_time_hour = State.hour
    GlobalState.m1_weather_time_minute = State.minute
    GlobalState.m1_weather_time_freeze = State.freeze
    GlobalState.m1_weather_time_manual_lock_until = State.manualWeatherLockUntil or 0
    TriggerClientEvent('m1-weather-time:client:sync', -1, State)
end

local ProfileCache = {}
local ProfilePending = {}

local function Trim(value)
    return tostring(value or ''):match('^%s*(.-)%s*$') or ''
end

local function GetProfileConfigValue(directValue, convarName)
    local value = Trim(directValue)
    if value == '' and Trim(convarName) ~= '' then
        value = Trim(GetConvar(convarName, ''))
    end

    if value:lower() == 'none' then return '' end
    return value
end

local function UrlEncode(value)
    return tostring(value or ''):gsub('\n', '\r\n'):gsub('([^%w%-_%.~])', function(char)
        return ('%%%02X'):format(string.byte(char))
    end)
end

local function DecodeJson(body)
    if type(body) ~= 'string' or body == '' then return nil end
    local ok, decoded = pcall(json.decode, body)
    if not ok or type(decoded) ~= 'table' then return nil end
    return decoded
end

local function GetIdentifiers(src)
    local identifiers = {}
    for _, identifier in ipairs(GetPlayerIdentifiers(src)) do
        local kind, value = identifier:match('^([^:]+):(.+)$')
        if kind and value and identifiers[kind] == nil then
            identifiers[kind] = value
        end
    end
    return identifiers
end

local function GetProfileCacheKey(src, identifiers)
    identifiers = identifiers or GetIdentifiers(src)
    return identifiers.license or identifiers.license2 or identifiers.fivem or ('source:%s'):format(src)
end

local function DefaultProfile()
    local profile = Config.Profile or {}
    return {
        avatar = Trim(profile.defaultAvatar) ~= '' and profile.defaultAvatar or 'default-avatar.svg',
        source = 'default'
    }
end

local function ResolveDiscordAvatar(discordId, callback)
    local profile = Config.Profile or {}
    local token = GetProfileConfigValue(profile.discordBotToken, profile.discordBotTokenConvar)

    if token == '' or not tostring(discordId or ''):match('^%d+$') then
        return callback(nil)
    end

    local url = ('https://discord.com/api/v10/users/%s'):format(discordId)
    PerformHttpRequest(url, function(statusCode, body)
        if statusCode ~= 200 then return callback(nil) end

        local data = DecodeJson(body)
        local avatarHash = data and type(data.avatar) == 'string' and Trim(data.avatar) or ''
        if avatarHash == '' then return callback(nil) end

        callback({
            avatar = ('https://cdn.discordapp.com/avatars/%s/%s.webp?size=256'):format(discordId, avatarHash),
            source = 'discord'
        })
    end, 'GET', '', {
        ['Authorization'] = 'Bot ' .. token,
        ['Content-Type'] = 'application/json'
    })
end

local function SteamHexToDecimal(steamHex)
    steamHex = Trim(steamHex)
    if steamHex == '' or not steamHex:match('^[%da-fA-F]+$') then return nil end

    local number = tonumber(steamHex, 16)
    if not number then return nil end
    return string.format('%d', number)
end

local function ResolveSteamAvatar(steamHex, callback)
    local profile = Config.Profile or {}
    local apiKey = GetProfileConfigValue(profile.steamWebApiKey, profile.steamWebApiKeyConvar)
    local steamId64 = SteamHexToDecimal(steamHex)

    if apiKey == '' or not steamId64 then
        return callback(nil)
    end

    local url = ('https://api.steampowered.com/ISteamUser/GetPlayerSummaries/v2/?key=%s&steamids=%s')
        :format(UrlEncode(apiKey), UrlEncode(steamId64))

    PerformHttpRequest(url, function(statusCode, body)
        if statusCode ~= 200 then return callback(nil) end

        local data = DecodeJson(body)
        local players = data and data.response and data.response.players
        local steamProfile = type(players) == 'table' and players[1] or nil
        local avatar = steamProfile and (steamProfile.avatarfull or steamProfile.avatarmedium)

        if Trim(avatar) == '' then return callback(nil) end
        callback({ avatar = avatar, source = 'steam' })
    end, 'GET', '', {})
end

local function FinishProfileRequest(cacheKey, result)
    local profile = result or DefaultProfile()
    local config = Config.Profile or {}
    local cacheMinutes = profile.source == 'default'
        and (tonumber(config.failedCacheMinutes) or 5)
        or (tonumber(config.cacheMinutes) or 30)

    ProfileCache[cacheKey] = {
        data = profile,
        expiresAt = os.time() + math.max(1, cacheMinutes) * 60
    }

    local callbacks = ProfilePending[cacheKey] or {}
    ProfilePending[cacheKey] = nil
    for _, callback in ipairs(callbacks) do
        callback(profile)
    end
end

local function ResolvePlayerProfile(src, callback)
    local profileConfig = Config.Profile or {}
    if profileConfig.enabled == false then
        return callback(DefaultProfile())
    end

    local identifiers = GetIdentifiers(src)
    local cacheKey = GetProfileCacheKey(src, identifiers)
    local cached = ProfileCache[cacheKey]

    if cached and cached.expiresAt > os.time() then
        return callback(cached.data)
    end

    if ProfilePending[cacheKey] then
        ProfilePending[cacheKey][#ProfilePending[cacheKey] + 1] = callback
        return
    end

    ProfilePending[cacheKey] = { callback }

    ResolveDiscordAvatar(identifiers.discord, function(discordProfile)
        if discordProfile then
            return FinishProfileRequest(cacheKey, discordProfile)
        end

        ResolveSteamAvatar(identifiers.steam, function(steamProfile)
            FinishProfileRequest(cacheKey, steamProfile)
        end)
    end)
end

local function GetCachedPlayerProfile(src)
    local identifiers = GetIdentifiers(src)
    local cacheKey = GetProfileCacheKey(src, identifiers)
    local cached = ProfileCache[cacheKey]
    if cached and cached.expiresAt > os.time() then
        return cached.data, cacheKey
    end
    return DefaultProfile(), cacheKey
end

local function OpenMenu(src, mode)
    if src == 0 then
        M1Print('Bu menü komutu yalnızca oyun içinden kullanılabilir.')
        return
    end

    if M1_LOCKED then
        Notify(src, Config.Locale.m1Locked, 'error')
        return
    end

    if not HasPermission(src) then
        Notify(src, Config.Locale.noPermission, 'error')
        return
    end

    local initialProfile, expectedCacheKey = GetCachedPlayerProfile(src)
    TriggerClientEvent('m1-weather-time:client:open', src, mode, State, initialProfile)

    ResolvePlayerProfile(src, function(profile)
        if not GetPlayerName(src) then return end
        if GetProfileCacheKey(src) ~= expectedCacheKey then return end
        TriggerClientEvent('m1-weather-time:client:profile', src, profile)
    end)
end

RegisterCommand(Config.Commands.weather or 'weather', function(source)
    OpenMenu(source, 'weather')
end, false)

RegisterCommand(Config.Commands.time or 'time', function(source)
    OpenMenu(source, 'time')
end, false)

RegisterNetEvent('m1-weather-time:server:requestSync', function()
    SendState(source)
end)

local function SetServerWeather(weather, src, isManual)
    local valid, fixedWeather = IsWeatherValid(weather)
    if not valid then
        if src then Notify(src, 'Geçersiz hava tipi.', 'error') end
        return false
    end

    State.weather = fixedWeather

    if isManual then
        local lockMinutes = Config.DynamicWeather and Config.DynamicWeather.manualLockMinutes or 30
        State.manualWeatherLockUntil = os.time() + (lockMinutes * 60)
        NextDynamicWeatherAt = State.manualWeatherLockUntil + ((Config.DynamicWeather and Config.DynamicWeather.intervalMinutes or 30) * 60)
    end

    BroadcastState()
    return true, fixedWeather
end

RegisterNetEvent('m1-weather-time:server:setWeather', function(weather)
    local src = source
    if M1_LOCKED then return Notify(src, Config.Locale.m1Locked, 'error') end
    if not HasPermission(src) then return Notify(src, Config.Locale.noPermission, 'error') end

    local ok, fixedWeather = SetServerWeather(weather, src, true)
    if ok then
        Notify(src, (Config.Locale.weatherChanged):format(fixedWeather), 'success')
    end
end)

RegisterNetEvent('m1-weather-time:server:setTime', function(hour, minute)
    local src = source
    if M1_LOCKED then return Notify(src, Config.Locale.m1Locked, 'error') end
    if not HasPermission(src) then return Notify(src, Config.Locale.noPermission, 'error') end

    hour = tonumber(hour)
    minute = tonumber(minute)

    if not hour or not minute then return Notify(src, 'Saat veya dakika geçersiz.', 'error') end
    hour = math.floor(hour)
    minute = math.floor(minute)

    if hour < 0 or hour > 23 or minute < 0 or minute > 59 then
        return Notify(src, 'Saat 0-23, dakika 0-59 arasında olmalı.', 'error')
    end

    State.hour = hour
    State.minute = minute
    BroadcastState()
    Notify(src, (Config.Locale.timeChanged):format(hour, minute), 'success')
end)

local function GetClockTotalMinutes(hour, minute)
    return ((tonumber(hour) or 0) * 60) + (tonumber(minute) or 0)
end

local function GetPeriodLengthMinutes(startHour, endHour)
    local startMinute = (tonumber(startHour) or 0) * 60
    local endMinute = (tonumber(endHour) or 0) * 60
    local length = endMinute - startMinute
    if length <= 0 then
        length = length + 1440
    end
    return length
end

local function IsClockInRange(hour, minute, startHour, endHour)
    local now = GetClockTotalMinutes(hour, minute)
    local startMinute = (tonumber(startHour) or 0) * 60
    local endMinute = (tonumber(endHour) or 0) * 60

    if startMinute < endMinute then
        return now >= startMinute and now < endMinute
    end

    return now >= startMinute or now < endMinute
end

local function GetCycleWaitMs()
    local cycle = Config.TimeCycle or {}
    local dayStart = cycle.dayStartHour or 6
    local nightStart = cycle.nightStartHour or 22
    local isDay = IsClockInRange(State.hour, State.minute, dayStart, nightStart)
    local dayLengthGameMinutes = GetPeriodLengthMinutes(dayStart, nightStart)
    local nightLengthGameMinutes = 1440 - dayLengthGameMinutes

    local realDurationMinutes = isDay and (cycle.dayDurationMinutes or 30) or (cycle.nightDurationMinutes or 20)
    local gameDurationMinutes = isDay and dayLengthGameMinutes or nightLengthGameMinutes

    if gameDurationMinutes <= 0 then gameDurationMinutes = 1 end
    local waitMs = (realDurationMinutes * 60 * 1000) / gameDurationMinutes

    return math.max(250, math.floor(waitMs))
end

local function AddGameMinute()
    State.minute = State.minute + 1
    if State.minute >= 60 then
        State.minute = 0
        State.hour = State.hour + 1
        if State.hour >= 24 then
            State.hour = 0
        end
    end
end

CreateThread(function()
    Wait(1500)
    BroadcastState()

    while true do
        if M1_LOCKED or not (Config.TimeCycle and Config.TimeCycle.enabled) then
            Wait(5000)
        else
            Wait(GetCycleWaitMs())
            AddGameMinute()
            BroadcastState()
        end
    end
end)

local function ArrayContains(array, value)
    for _, item in ipairs(array or {}) do
        if item == value then return true end
    end
    return false
end

local function PickRandomWeather()
    local dynamic = Config.DynamicWeather or {}
    local allowed = dynamic.allowedAutoWeather or { 'EXTRASUNNY', 'CLEAR', 'CLOUDS', 'OVERCAST', 'CLEARING' }
    local transitions = dynamic.transitions or {}
    local choices = transitions[State.weather] or allowed
    local filtered = {}

    for _, weather in ipairs(choices) do
        if ArrayContains(allowed, weather) then
            filtered[#filtered + 1] = weather
        end
    end

    if #filtered == 0 then
        filtered = allowed
    end

    return filtered[math.random(1, #filtered)]
end

CreateThread(function()
    while true do
        Wait(60000)

        local dynamic = Config.DynamicWeather or {}
        if not M1_LOCKED and dynamic.enabled then
            local now = os.time()

            if now >= NextDynamicWeatherAt then
                if now >= (State.manualWeatherLockUntil or 0) then
                    local newWeather = PickRandomWeather()
                    if newWeather and newWeather ~= State.weather then
                        SetServerWeather(newWeather, 0, false)
                        M1Print(('Otomatik hava değişti: %s'):format(newWeather))
                    else
                        BroadcastState()
                    end
                end

                NextDynamicWeatherAt = now + ((dynamic.intervalMinutes or 30) * 60)
            end
        end
    end
end)

AddEventHandler('playerJoining', function()
    local src = source
    SetTimeout(2500, function()
        if GetPlayerPing(src) then
            SendState(src)
        end
    end)
end)

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName == RESOURCE then return end

    local autoDisable = Config.AutoDisableConflictingResources or {}
    if autoDisable.enabled and autoDisable.stopIfStartedLater ~= false and IsConflictResource(resourceName) then
        SetTimeout(750, function()
            if StopConflictingResource(resourceName, 'sonradan startlandı') then
                SetTimeout(500, BroadcastState)
            end
        end)
    end
end)

RegisterCommand('m1forcesync', function(source)
    if not HasPermission(source) then
        return Notify(source, Config.Locale.noPermission, 'error')
    end

    StopAllConflictingResources('manuel force sync')
    BroadcastState()
    Notify(source, 'M1 hava/saat senkronu bütün oyunculara yeniden gönderildi.', 'success')
end, false)
