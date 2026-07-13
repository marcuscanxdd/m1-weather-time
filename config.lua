Config = {}

-- M1 local lock: Scriptin başka isimle veya eksik dosyayla çalışmasını engeller.
-- Dış bağlantı / lisans sunucusu yoktur; tamamen local kontrol yapar.
Config.M1Connection = {
    resourceName = 'm1-weather-time',
    signature = 'M1WT-2026-LOCK-9F4A',
    uiSignature = 'M1WT-NUI-BRIDGE-v1',
    styleSignature = 'M1WT-STYLE-GUARD-v1'
}

Config.AdminOnly = true

-- Framework yetkilendirmesi. Script özel ACE kullanmaz.
-- auto: qbx_core -> qb-core -> es_extended sırasıyla aktif frameworkü algılar.
Config.Permissions = {
    framework = 'auto', -- auto | qbcore | qbox | esx

    -- QBCore kendi standart ACE tabanlı permission sistemini kullanır.
    qbcore = { 'god', 'admin' },

    -- Qbox resmi recipe içinde group.admin grubuna "admin" ACE'i verilir.
    qboxAce = { 'admin' },

    -- ESX yalnızca frameworkün standart admin grubunu kullanır.
    esxGroups = { 'admin' }
}

-- Menü profil görseli:
-- 1) Discord özel avatarı, 2) Steam avatarı, 3) yerel standart kullanıcı görseli.
-- Token ve API key'i doğrudan confige yazmak yerine server.cfg convar kullanılması önerilir.
Config.Profile = {
    enabled = true,
    discordBotToken = '',
    discordBotTokenConvar = 'm1_discordBotToken',
    steamWebApiKey = '',
    steamWebApiKeyConvar = 'steam_webApiKey',
    cacheMinutes = 30,
    failedCacheMinutes = 5,
    defaultAvatar = 'default-avatar.svg'
}

Config.Commands = {
    weather = 'weather',
    time = 'time'
}

Config.DefaultWeather = 'EXTRASUNNY'
Config.DefaultHour = 8
Config.DefaultMinute = 0

-- Client tarafında zamanı server saatine sabitler. TimeCycle açıkken true kalması önerilir.
Config.FreezeTime = true

-- Başka weather/time scriptleri açıksa otomatik durdurur.
-- Böylece qb-weathersync / cd_easytime / vSync gibi scriptler saat ve havayı bozmaz.
Config.AutoDisableConflictingResources = {
    enabled = true,
    checkOnStart = true,
    stopIfStartedLater = true,

    -- Listedeki isimler dışında resource adında aşağıdaki kelimeler varsa da durdurur.
    -- Örnek: my-weathersync, qbx_weathersync, custom-weather gibi.
    blockByKeyword = true,
    blockedKeywords = { 'weather', 'weathersync', 'easytime', 'vsync', 'timesync' },

    resources = {
        'qb-weathersync',
        'cd_easytime',
        'vSync',
        'vsync',
        'Renewed-Weathersync',
        'renewed-weathersync',
        'av_weather',
        'zSync',
        'zs_weather',
        'weathersync'
    }
}

-- Client tarafında hava/saat sürekli zorla uygulanır.
-- Başka script araya girse bile oyuncularda aynı saat/hava kalması için açık bırak.
Config.ClientForceSync = {
    enabled = true,
    applyIntervalMs = 250,
    requestServerSyncSeconds = 25,
    clearRainWhenNotRain = true
}

-- Gün/gece döngüsü:
-- 06:00 - 22:00 arası 30 gerçek dakika sürer.
-- 22:00 - 06:00 arası 20 gerçek dakika sürer.
Config.TimeCycle = {
    enabled = true,
    dayStartHour = 6,
    nightStartHour = 22,
    dayDurationMinutes = 30,
    nightDurationMinutes = 20
}

-- Otomatik hava sistemi:
-- Herkeste aynı server state kullanılır.
-- Menüden manuel hava seçilince otomatik değişim ManualLockMinutes kadar bekler.
-- Böylece EXTRASUNNY yaptıktan 2 dakika sonra otomatik yağmur/fırtına gelmez.
Config.DynamicWeather = {
    enabled = true,
    intervalMinutes = 30,
    manualLockMinutes = 30,

    -- Otomatik sistem artık yağmur/fırtına seçmez.
    -- Yağmur/fırtına sadece admin menüden manuel seçerse gelir.
    -- Kar / özel event havaları da manuelden seçilebilir.
    allowedAutoWeather = {
        'EXTRASUNNY', 'CLEAR', 'CLOUDS', 'OVERCAST', 'CLEARING', 'FOGGY', 'SMOG'
    },

    -- Dengeli geçişler. Güneşliden direkt yağmur/fırtınaya zıplatmaz.
    transitions = {
        EXTRASUNNY = { 'EXTRASUNNY', 'CLEAR', 'CLOUDS' },
        CLEAR      = { 'EXTRASUNNY', 'CLEAR', 'CLOUDS', 'CLEARING' },
        CLOUDS     = { 'CLEAR', 'CLOUDS', 'OVERCAST', 'CLEARING' },
        OVERCAST   = { 'CLOUDS', 'OVERCAST', 'CLEARING', 'RAIN' },
        CLEARING   = { 'CLEAR', 'CLOUDS', 'OVERCAST', 'EXTRASUNNY' },
        FOGGY      = { 'CLEAR', 'CLOUDS', 'FOGGY', 'SMOG' },
        SMOG       = { 'CLEAR', 'CLOUDS', 'SMOG', 'FOGGY' },
        RAIN       = { 'OVERCAST', 'RAIN', 'CLEARING', 'CLOUDS' },
        THUNDER    = { 'RAIN', 'OVERCAST', 'CLEARING' }
    }
}

Config.WeatherOptions = {
    { value = 'EXTRASUNNY', label = 'Ekstra Güneşli', icon = '☀' },
    { value = 'CLEAR',      label = 'Açık',            icon = '◌' },
    { value = 'NEUTRAL',    label = 'Normal',          icon = '◎' },
    { value = 'SMOG',       label = 'Sisli Hava',      icon = '▧' },
    { value = 'FOGGY',      label = 'Yoğun Sis',       icon = '≋' },
    { value = 'OVERCAST',   label = 'Kapalı',          icon = '☁' },
    { value = 'CLOUDS',     label = 'Bulutlu',         icon = '☁' },
    { value = 'CLEARING',   label = 'Açılıyor',        icon = '◒' },
    { value = 'RAIN',       label = 'Yağmur',          icon = '☂' },
    { value = 'THUNDER',    label = 'Fırtına',         icon = 'ϟ' },
    { value = 'SNOW',       label = 'Kar',             icon = '✦' },
    { value = 'BLIZZARD',   label = 'Tipi',            icon = '✺' },
    { value = 'SNOWLIGHT',  label = 'Hafif Kar',       icon = '✧' },
    { value = 'XMAS',       label = 'Yılbaşı',         icon = '★' },
    { value = 'HALLOWEEN',  label = 'Cadılar Bayramı', icon = '☾' }
}

Config.Locale = {
    welcomeBlue = 'Hoş geldin,',
    subtitleWeather = 'Havayı Yönet',
    subtitleTime = 'Saati Yönet',
    weatherHint = 'Sunucu havasını seç ve bütün oyunculara uygula.',
    timeHint = 'Sunucu saatini ve dakikasını belirle.',
    searchWeather = 'Hava ara...',
    hour = 'Saat',
    minute = 'Dakika',
    apply = 'Uygula',
    close = 'Kapat',
    selected = 'Seçili',
    noPermission = 'Bu komutu kullanmak için yetkin yok.',
    weatherChanged = 'Sunucu hava durumu değiştirildi: %s',
    timeChanged = 'Sunucu saati değiştirildi: %02d:%02d',
    m1Locked = 'M1 kilidi doğrulanamadı. Script kilitlendi.'
}
