<div align="center">

# M1 Weather & Time

**QBCore, Qbox ve ESX için senkronize hava durumu ve saat yönetim sistemi.**

![FiveM](https://img.shields.io/badge/FiveM-Cerulean-orange?style=flat-square)
![Lua](https://img.shields.io/badge/Lua-5.4-blue?style=flat-square)
![Framework](https://img.shields.io/badge/Framework-QBCore%20%7C%20Qbox%20%7C%20ESX-57a6ff?style=flat-square)
![Version](https://img.shields.io/badge/Version-1.1.1-green?style=flat-square)
![License](https://img.shields.io/badge/License-MIT-yellow?style=flat-square)

</div>

`m1-weather-time`, sunucudaki bütün oyunculara aynı hava ve saat durumunu uygulayan, yönetici kontrollü bir FiveM resource'udur. Modern NUI paneli, otomatik gün/gece döngüsü, dengeli dinamik hava geçişleri, framework tabanlı yönetici kontrolü ve Discord → Steam profil görseli desteği içerir.

## Özellikler

- Bütün oyuncular için server-side senkronize hava ve saat.
- Modern ve kullanımı kolay NUI yönetim paneli.
- Menüde oyuncunun Discord profil görseli.
- Discord görseli alınamazsa otomatik Steam avatarı.
- Discord ve Steam kullanılamazsa yerel standart kullanıcı profil görseli.
- QBCore, Qbox ve ESX otomatik framework algılama.
- Script özel ACE izni olmadan standart framework yönetici grupları.
- Ayarlanabilir gündüz ve gece süreleri.
- Dengeli ve kademeli otomatik hava geçişleri.
- Manuel değişiklikten sonra ayarlanabilir otomatik hava kilidi.
- Yağmur, fırtına, kar ve özel hava türlerini panelden yönetme.
- Yeni bağlanan oyunculara otomatik state senkronizasyonu.
- Client tarafında periyodik zorunlu hava/saat uygulaması.
- Bilinen weather ve time resource'larını otomatik durdurma desteği.
- QBCore, Qbox, ESX ve chat bildirim desteği.
- Türkçe arayüz ve yapılandırılabilir komutlar.
- MIT lisansı, Lua/FiveM uyumlu `.gitignore` ve GitHub Lua dil algısı için `.gitattributes`.

## Gereksinimler

- Güncel FiveM / FXServer kurulumu.
- QBCore, Qbox veya ESX frameworklerinden biri.
- OneSync kullanılması önerilir.
- Discord avatarı için geçerli bir Discord bot tokeni.
- Steam yedeği için geçerli bir Steam Web API key.

> Profil anahtarları zorunlu değildir. Anahtarlar tanımlanmazsa sistem çalışmaya devam eder ve yerel standart kullanıcı görselini kullanır.

## Kurulum

1. `m1-weather-time` klasörünü sunucunun `resources` dizinine yükle.
2. Klasör adını değiştirme. Resource adı `m1-weather-time` olarak kalmalıdır.
3. Framework resource'unun bu scriptten önce başladığından emin ol.
4. `server.cfg` dosyana ekle:

```cfg
ensure m1-weather-time
```

Örnek başlatma sırası:

```cfg
# QBCore
ensure qb-core
ensure m1-weather-time
```

```cfg
# Qbox
ensure qbx_core
ensure m1-weather-time
```

```cfg
# ESX
ensure es_extended
ensure m1-weather-time
```

Sunucuda başka bir weather/time resource'u bulunuyorsa onu `server.cfg` üzerinden kaldırmak en temiz çözümdür.

## Yetkilendirme

Bu sürümde `m1.weather` veya başka bir script özel ACE izni **yoktur**. Script aktif frameworkü algılar ve yalnızca standart yönetici yetkilerini kontrol eder.

| Framework | Kabul edilen yetki |
|---|---|
| QBCore | `god`, `admin` |
| Qbox | Resmi `admin` ACE / `group.admin` |
| ESX | Standart `admin` grubu |

Framework algılama sırası:

```text
qbx_core → qb-core → es_extended
```

Gerekirse `config.lua` üzerinden frameworkü sabitleyebilirsin:

```lua
Config.Permissions.framework = 'qbcore' -- qbcore | qbox | esx | auto
```

### QBCore örneği

Mevcut QBCore permission sistemini kullan. Script için ayrıca `add_ace` ekleme.

```cfg
add_principal identifier.license:LICENSE_DEGERI qbcore.god
```

veya:

```cfg
add_principal identifier.license:LICENSE_DEGERI qbcore.admin
```

### Qbox örneği

Qbox resmi permissions yapılandırmasındaki `group.admin` kullanılır:

```cfg
add_principal identifier.license:LICENSE_DEGERI group.admin
add_ace group.admin admin allow
```

### ESX örneği

ESX kullanıcısının grubu `admin` olmalıdır. ESX'in kendi `/setgroup` komutu veya mevcut yönetici sistemi kullanılabilir:

```text
/setgroup ID admin
```

Script için ayrı bir ACE oluşturulmasına gerek yoktur.

## Discord ve Steam Profil Görseli

Profil görseli şu sırayla çözülür:

```text
Discord özel avatarı → Steam avatarı → Yerel standart kullanıcı avatarı
```

Menü hemen açılır. Profil isteği tamamlandığında görsel panel açıkken otomatik güncellenir. Başarılı sonuçlar varsayılan olarak 30 dakika, başarısız sonuçlar 5 dakika önbelleğe alınır.

### Profil sistemini hazırlama

#### 1. Discord avatarını etkinleştirme

1. Discord Developer Portal üzerinden bir uygulama ve bot oluştur.
2. Bot sekmesinden tokeni kopyala.
3. Botu kendi Discord sunucuna ekle. Oyuncunun da aynı Discord sunucusunda bulunması önerilir.
4. Tokeni `config.lua` içine değil, `server.cfg` içine convar olarak yaz:

```cfg
set m1_discordBotToken "DISCORD_BOT_TOKEN"
```

5. Oyuncu Discord açıkken FiveM'e bağlanmalıdır. Bağlantıda `discord:` identifier bulunursa script önce Discord profil fotoğrafını dener.

> Bot tokenini GitHub, Tebex paketi, ekran görüntüsü, client dosyası veya NUI içine kesinlikle koyma.

#### 2. Steam yedeğini etkinleştirme

Discord fotoğrafı alınamazsa Steam profil fotoğrafının kullanılabilmesi için Steam Web API key oluştur ve FiveM'in standart convarına ekle:

```cfg
set steam_webApiKey "STEAM_WEB_API_KEY"
```

Oyuncu Steam açık şekilde bağlanmalı ve bağlantısında `steam:` identifier bulunmalıdır.

#### 3. Değişiklikleri uygulama

`server.cfg` değişikliğinden sonra konsoldan resource'u yeniden başlat:

```text
restart m1-weather-time
```

Profil sonuçları önbelleğe alındığı için token veya API key değişikliğinden sonra restart yapılması önerilir.

#### 4. Anahtar kullanılmazsa ne olur?

Hiçbir ayar yapmasan da menü çalışır. Discord resmi alınamazsa Steam denenir; Steam de alınamazsa `html/default-avatar.svg` içindeki standart kullanıcı silüeti gösterilir. Bu dosya tamamen yereldir, internet bağlantısı istemez ve kırık profil görseli oluşmasını engeller. İstersen aynı dosya adını koruyarak kendi varsayılan profil görselinle değiştirebilirsin.

### Config üzerinden alternatif kullanım

Convar kullanmak istemiyorsan aşağıdaki alanlara değer yazılabilir; güvenlik nedeniyle önerilmez:

```lua
Config.Profile.discordBotToken = ''
Config.Profile.steamWebApiKey = ''
```

## Komutlar

| Komut | Açıklama | Yetki |
|---|---|---|
| `/weather` | Hava durumu yönetim panelini açar. | Framework yöneticisi |
| `/time` | Saat yönetim panelini açar. | Framework yöneticisi |
| `/m1forcesync` | Çakışan resource'ları kontrol eder ve state'i yeniden gönderir. | Framework yöneticisi |

Komut adları `config.lua` içerisinden değiştirilebilir:

```lua
Config.Commands = {
    weather = 'weather',
    time = 'time'
}
```

## Temel Yapılandırma

### Varsayılan hava ve saat

```lua
Config.DefaultWeather = 'EXTRASUNNY'
Config.DefaultHour = 8
Config.DefaultMinute = 0
```

### Gün ve gece döngüsü

```lua
Config.TimeCycle = {
    enabled = true,
    dayStartHour = 6,
    nightStartHour = 22,
    dayDurationMinutes = 30,
    nightDurationMinutes = 20
}
```

Varsayılan ayarda 06.00–22.00 arasındaki oyun gündüzü 30 gerçek dakika, 22.00–06.00 arasındaki oyun gecesi 20 gerçek dakika sürer.

### Dinamik hava

```lua
Config.DynamicWeather = {
    enabled = true,
    intervalMinutes = 30,
    manualLockMinutes = 30
}
```

`manualLockMinutes`, yönetici panelden hava seçtikten sonra otomatik sistemin ne kadar süre hava değiştirmeyeceğini belirler.

### Client senkronizasyonu

```lua
Config.ClientForceSync = {
    enabled = true,
    applyIntervalMs = 250,
    requestServerSyncSeconds = 25,
    clearRainWhenNotRain = true
}
```

Bu sistem başka bir resource hava veya saati değiştirmeye çalışsa bile sunucu state'ini oyuncuya tekrar uygular.

## Desteklenen Hava Türleri

`EXTRASUNNY`, `CLEAR`, `NEUTRAL`, `SMOG`, `FOGGY`, `OVERCAST`, `CLOUDS`, `CLEARING`, `RAIN`, `THUNDER`, `SNOW`, `BLIZZARD`, `SNOWLIGHT`, `XMAS`, `HALLOWEEN`

Panelde gösterilen isim, ikon ve sıralama `Config.WeatherOptions` tablosundan düzenlenebilir.

## Çakışan Resource Koruması

Script bilinen weather/time sistemlerini kontrol edebilir ve çakışmayı önlemek için durdurabilir. Varsayılan listede şunlar bulunur:

- `qb-weathersync`
- `cd_easytime`
- `vSync`
- `renewed-weathersync`
- `av_weather`
- `zSync`
- `weathersync`

Resource adında `weather`, `weathersync`, `easytime`, `vsync` veya `timesync` geçen sistemler de isteğe bağlı olarak engellenir.

> Hava sistemi olmayan başka bir resource adında `weather` kelimesi bulunuyorsa `Config.AutoDisableConflictingResources.blockByKeyword` ayarını kapat veya kelime listesini düzenle.

## Dosya Yapısı

```text
m1-weather-time/
├── html/
│   ├── app.js
│   ├── default-avatar.svg
│   ├── index.html
│   └── style.css
├── .gitattributes
├── .gitignore
├── LICENSE
├── README.md
├── client.lua
├── config.lua
├── fxmanifest.lua
└── server.lua
```

## Sorun Giderme

### Panel açılmıyor

- Frameworkün scriptten önce başladığını kontrol et.
- `Config.Permissions.framework` ayarını `auto` olarak bırak veya doğru frameworkü seç.
- Oyuncunun standart framework yönetici grubuna sahip olduğunu doğrula.
- Resource klasörünün tam olarak `m1-weather-time` olduğundan emin ol.
- F8 ve server konsolundaki hata mesajlarını kontrol et.

### Discord avatarı görünmüyor

- `m1_discordBotToken` convarının doğru tanımlandığını kontrol et.
- Bot tokeninin geçerli ve iptal edilmemiş olduğundan emin ol.
- Oyuncunun FiveM identifier listesinde `discord:` bulunduğunu kontrol et.
- Oyuncunun özel Discord avatarı yoksa Steam yedeği denenir.
- Testten sonra önbelleği sıfırlamak için resource'u restart et.
- Discord alınamazsa Steam denenir; o da alınamazsa yerel standart kullanıcı avatarının görünmesi normaldir.

### Steam avatarı görünmüyor

- `steam_webApiKey` değerini kontrol et.
- Oyuncunun Steam açık şekilde bağlandığını ve `steam:` identifier bulunduğunu doğrula.
- Steam profilinin gizlilik ayarlarını kontrol et.

### Hava veya saat geri değişiyor

- Başka bir weather/time resource'unun çalışmadığından emin ol.
- `/m1forcesync` komutunu kullan.
- `Config.ClientForceSync.enabled` değerinin `true` olduğunu kontrol et.
- Çakışan resource'u `server.cfg` dosyasından tamamen kaldır.

### Oyuncular farklı hava görüyor

- OneSync durumunu kontrol et.
- Resource'u yeniden başlat.
- `requestServerSyncSeconds` değerini çok yüksek kullanma.
- Client veya server tarafında hava kontrol eden başka scriptleri devre dışı bırak.

## Güvenlik

- Discord bot tokenini client dosyalarına veya NUI tarafına yazma.
- API anahtarları yalnızca server-side okunur ve oyunculara gönderilmez.
- Hava ve saat değiştirme eventleri server tarafında tekrar yetki kontrolünden geçer.
- Profil sonuçları API yükünü azaltmak için önbelleğe alınır.

## M1 Bağlantıları

- Web sitesi: https://m1bots.com.tr/
- Discord: https://discord.gg/m1bots
- GitHub: https://github.com/marcuscanxdd
- Tebex mağazası: https://m1bots.tebex.io/

## Lisans

Bu proje [MIT License](LICENSE) ile lisanslanmıştır.

Copyright © 2026 M1 Development.
