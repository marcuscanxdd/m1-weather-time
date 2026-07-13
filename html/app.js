const M1_UI_BRIDGE_SIGNATURE = 'M1WT-NUI-BRIDGE-v1';
const resource = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'm1-weather-time';

const app = document.getElementById('app');
const weatherView = document.getElementById('weatherView');
const timeView = document.getElementById('timeView');
const weatherTab = document.getElementById('weatherTab');
const timeTab = document.getElementById('timeTab');
const closeBtn = document.getElementById('closeBtn');
const weatherGrid = document.getElementById('weatherGrid');
const weatherSearch = document.getElementById('weatherSearch');
const applyWeatherBtn = document.getElementById('applyWeatherBtn');
const applyTimeBtn = document.getElementById('applyTimeBtn');
const hourInput = document.getElementById('hourInput');
const minuteInput = document.getElementById('minuteInput');
const profileAvatar = document.getElementById('profileAvatar');

let options = [];
let locale = {};
let state = {
    weather: 'EXTRASUNNY',
    hour: 12,
    minute: 0
};
let selectedWeather = 'EXTRASUNNY';
let timeEditLocked = false;
let timeEditUnlockTimer = null;

function post(name, data = {}) {
    return fetch(`https://${resource}/${name}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify(data)
    }).catch(() => undefined);
}

post('m1ready', { signature: M1_UI_BRIDGE_SIGNATURE });

function pad(value) {
    const number = Number(value);
    return String(Number.isFinite(number) ? number : 0).padStart(2, '0');
}

function markTimeEditing() {
    timeEditLocked = true;
    if (timeEditUnlockTimer) clearTimeout(timeEditUnlockTimer);
    timeEditUnlockTimer = setTimeout(() => {
        const active = document.activeElement;
        if (active !== hourInput && active !== minuteInput) {
            timeEditLocked = false;
        }
    }, 5000);
}

function isTimePanelOpen() {
    return !app.classList.contains('hidden') && !timeView.classList.contains('hidden');
}

function shouldKeepLocalTimeInputs() {
    const active = document.activeElement;
    return isTimePanelOpen() && (timeEditLocked || active === hourInput || active === minuteInput);
}

function normalizeNumber(value, fallback, min, max, wrap) {
    let number = Number(value);
    if (!Number.isFinite(number)) number = fallback;
    number = Math.floor(number);

    if (wrap) {
        if (number < min) return max;
        if (number > max) return min;
        return number;
    }

    if (number < min) return min;
    if (number > max) return max;
    return number;
}

function commitInput(input, wrap = false) {
    const min = Number(input.min);
    const max = Number(input.max);
    const fallback = Number(input.dataset.lastValue ?? input.defaultValue ?? min);
    const value = normalizeNumber(input.value, fallback, min, max, wrap);
    input.value = value;
    input.dataset.lastValue = String(value);
    return value;
}

function setTimeInputs(hour, minute) {
    const h = normalizeNumber(hour, 12, 0, 23, false);
    const m = normalizeNumber(minute, 0, 0, 59, false);
    hourInput.value = h;
    minuteInput.value = m;
    hourInput.dataset.lastValue = String(h);
    minuteInput.dataset.lastValue = String(m);
}

function getTimeDisplayValue(input) {
    if (input.value === '' || input.value === '-' || input.value === '+') {
        return input.dataset.lastValue ?? input.defaultValue ?? 0;
    }
    return input.value;
}

function updateCurrentCards() {
    const weather = options.find((item) => item.value === selectedWeather) || options[0] || { icon: '☀', value: selectedWeather };
    document.getElementById('currentWeatherIcon').textContent = weather.icon || '☀';
    document.getElementById('currentWeatherText').textContent = selectedWeather;
    document.getElementById('currentTimeText').textContent = `${pad(getTimeDisplayValue(hourInput))}:${pad(getTimeDisplayValue(minuteInput))}`;
}

function renderWeather() {
    const query = (weatherSearch.value || '').toLocaleLowerCase('tr-TR').trim();
    weatherGrid.innerHTML = '';

    options
        .filter((item) => {
            const haystack = `${item.label} ${item.value}`.toLocaleLowerCase('tr-TR');
            return haystack.includes(query);
        })
        .forEach((item) => {
            const button = document.createElement('button');
            button.className = `m1-weather-item ${item.value === selectedWeather ? 'selected' : ''}`;
            button.innerHTML = `
                <span class="icon">${item.icon || '◌'}</span>
                <span class="name">${item.label || item.value}</span>
                <span class="code">${item.value}</span>
            `;
            button.addEventListener('click', () => {
                selectedWeather = item.value;
                renderWeather();
                updateCurrentCards();
            });
            weatherGrid.appendChild(button);
        });
}

function switchView(mode) {
    const weather = mode === 'weather';
    weatherView.classList.toggle('hidden', !weather);
    timeView.classList.toggle('hidden', weather);
    weatherTab.classList.toggle('active', weather);
    timeTab.classList.toggle('active', !weather);
}

function setProfile(profile = {}) {
    const fallback = 'default-avatar.svg';
    const avatar = typeof profile.avatar === 'string' && profile.avatar.trim() !== ''
        ? profile.avatar.trim()
        : fallback;

    profileAvatar.onerror = () => {
        profileAvatar.onerror = null;
        profileAvatar.src = fallback;
    };
    profileAvatar.src = avatar;
    profileAvatar.dataset.source = profile.source || 'default';
}

function applyLocale() {
    document.getElementById('welcomeBlue').textContent = locale.welcomeBlue || 'Hoş geldin,';
    document.getElementById('weatherTitle').textContent = locale.subtitleWeather || 'Havayı Yönet';
    document.getElementById('timeTitle').textContent = locale.subtitleTime || 'Saati Yönet';
    document.getElementById('weatherHint').textContent = locale.weatherHint || 'Sunucu havasını seç ve bütün oyunculara uygula.';
    document.getElementById('timeHint').textContent = locale.timeHint || 'Sunucu saatini ve dakikasını belirle.';
    weatherSearch.placeholder = locale.searchWeather || 'Hava ara...';
    document.getElementById('hourLabel').textContent = locale.hour || 'Saat';
    document.getElementById('minuteLabel').textContent = locale.minute || 'Dakika';
    applyWeatherBtn.textContent = locale.apply || 'Uygula';
    applyTimeBtn.textContent = locale.apply || 'Uygula';
}

function openPanel(payload) {
    if (!payload || payload.m1 !== M1_UI_BRIDGE_SIGNATURE) return;

    options = Array.isArray(payload.options) ? payload.options : [];
    locale = payload.locale || {};
    state = payload.state || state;
    selectedWeather = state.weather || selectedWeather;
    setTimeInputs(state.hour ?? 12, state.minute ?? 0);
    timeEditLocked = false;

    document.getElementById('playerName').textContent = payload.playerName || 'Admin';
    setProfile(payload.profile || {});
    applyLocale();
    renderWeather();
    updateCurrentCards();
    switchView(payload.mode === 'time' ? 'time' : 'weather');
    app.classList.remove('hidden');
}

function closePanel() {
    app.classList.add('hidden');
    timeEditLocked = false;
    post('close');
}

window.addEventListener('message', (event) => {
    const payload = event.data || {};

    if (payload.action === 'open') {
        openPanel(payload);
    }

    if (payload.action === 'profile') {
        setProfile(payload.profile || {});
    }

    if (payload.action === 'state' && payload.state) {
        state = payload.state;
        selectedWeather = state.weather || selectedWeather;

        if (!shouldKeepLocalTimeInputs()) {
            setTimeInputs(state.hour ?? getTimeDisplayValue(hourInput), state.minute ?? getTimeDisplayValue(minuteInput));
        }

        renderWeather();
        updateCurrentCards();
    }
});

weatherTab.addEventListener('click', () => switchView('weather'));
timeTab.addEventListener('click', () => switchView('time'));
closeBtn.addEventListener('click', closePanel);
weatherSearch.addEventListener('input', renderWeather);

applyWeatherBtn.addEventListener('click', () => {
    post('applyWeather', { weather: selectedWeather });
    app.classList.add('hidden');
});

applyTimeBtn.addEventListener('click', () => {
    const hour = commitInput(hourInput, false);
    const minute = commitInput(minuteInput, false);
    timeEditLocked = false;
    post('applyTime', { hour, minute });
    app.classList.add('hidden');
});

document.querySelectorAll('.m1-step').forEach((button) => {
    button.addEventListener('click', () => {
        const input = document.getElementById(button.dataset.target);
        const min = Number(input.min);
        const max = Number(input.max);
        const fallback = Number(input.dataset.lastValue ?? input.defaultValue ?? min);
        const nextValue = fallback + Number(button.dataset.step || 0);
        input.value = normalizeNumber(nextValue, fallback, min, max, true);
        commitInput(input, true);
        markTimeEditing();
        updateCurrentCards();
    });
});

document.querySelectorAll('.m1-time-presets button').forEach((button) => {
    button.addEventListener('click', () => {
        setTimeInputs(Number(button.dataset.hour || 12), Number(button.dataset.minute || 0));
        markTimeEditing();
        updateCurrentCards();
    });
});

[hourInput, minuteInput].forEach((input) => {
    input.addEventListener('focus', markTimeEditing);
    input.addEventListener('input', () => {
        markTimeEditing();
        updateCurrentCards();
    });
    input.addEventListener('blur', () => {
        commitInput(input, false);
        updateCurrentCards();
        setTimeout(() => {
            if (document.activeElement !== hourInput && document.activeElement !== minuteInput) {
                timeEditLocked = false;
            }
        }, 150);
    });
});

document.addEventListener('keydown', (event) => {
    if (event.key === 'Escape') closePanel();
});
