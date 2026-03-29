const root = document.getElementById('root');
const alarmBadge = document.getElementById('alarmBadge');
const stageName = document.getElementById('stageName');
const waterLevel = document.getElementById('waterLevel');
const holdRemaining = document.getElementById('holdRemaining');
const statusText = document.getElementById('statusText');
const safeState = document.getElementById('safeState');
const summary = document.getElementById('summary');

const defaultAlarmConfig = {
  enabled: true,
  useNuiSiren: true,
  sirenDurationMs: 6200,
  sirenVolume: 0.30,
  mode: 'bulletin',
  bulletinLowHz: 853,
  bulletinHighHz: 960,
  bulletinOnMs: 950,
  bulletinOffMs: 260,
  bulletinCycles: 4,
  bulletinStaticMs: 120,
  useFrontendFallback: false,
};

let alarmContext;
let alarmStopTimer = null;
let activeAudioNodes = [];
let holdRemainingEndsAt = 0;
let holdRemainingTimer = null;

function formatHold(seconds) {
  const total = Math.max(0, Math.ceil(Number(seconds || 0)));
  const mins = String(Math.floor(total / 60)).padStart(2, '0');
  const secs = String(total % 60).padStart(2, '0');
  return `${mins}:${secs}`;
}

function renderHoldRemaining() {
  if (holdRemainingEndsAt <= 0) {
    holdRemaining.textContent = formatHold(0);
    return;
  }

  const remainingSeconds = Math.max(0, (holdRemainingEndsAt - Date.now()) / 1000);
  holdRemaining.textContent = formatHold(remainingSeconds);

  if (remainingSeconds <= 0) {
    holdRemainingEndsAt = 0;
    if (holdRemainingTimer) {
      window.clearInterval(holdRemainingTimer);
      holdRemainingTimer = null;
    }
  }
}

function setHoldRemaining(seconds) {
  const total = Math.max(0, Number(seconds || 0));

  if (total <= 0) {
    holdRemainingEndsAt = 0;
    if (holdRemainingTimer) {
      window.clearInterval(holdRemainingTimer);
      holdRemainingTimer = null;
    }
    renderHoldRemaining();
    return;
  }

  holdRemainingEndsAt = Date.now() + (total * 1000);
  renderHoldRemaining();

  if (!holdRemainingTimer) {
    holdRemainingTimer = window.setInterval(renderHoldRemaining, 250);
  }
}

function clampVolume(volume) {
  return Math.max(0, Math.min(1, Number(volume ?? defaultAlarmConfig.sirenVolume)));
}

function getAlarmContext() {
  if (!alarmContext) {
    const AudioCtor = window.AudioContext || window.webkitAudioContext;
    if (!AudioCtor) {
      return null;
    }

    alarmContext = new AudioCtor();
  }

  return alarmContext;
}

function trackNode(node) {
  activeAudioNodes.push(node);
  return node;
}

function clearActiveAudioNodes() {
  for (const node of activeAudioNodes) {
    try {
      if (typeof node.stop === 'function') {
        node.stop();
      }
    } catch (_) {}

    try {
      if (typeof node.disconnect === 'function') {
        node.disconnect();
      }
    } catch (_) {}
  }

  activeAudioNodes = [];
}

function stopAlarm() {
  if (alarmStopTimer) {
    clearTimeout(alarmStopTimer);
    alarmStopTimer = null;
  }

  clearActiveAudioNodes();
}

function playOscillatorBurst(ctx, frequency, startAt, durationSec, volume, type) {
  if (durationSec <= 0 || volume <= 0) {
    return;
  }

  const attack = Math.min(0.012, durationSec * 0.25);
  const release = Math.min(0.028, durationSec * 0.35);
  const endAt = startAt + durationSec;
  const sustainAt = Math.max(startAt + attack, endAt - release);

  const oscillator = trackNode(ctx.createOscillator());
  const gain = trackNode(ctx.createGain());

  oscillator.type = type;
  oscillator.frequency.setValueAtTime(frequency, startAt);

  gain.gain.setValueAtTime(0, startAt);
  gain.gain.linearRampToValueAtTime(volume, startAt + attack);
  gain.gain.setValueAtTime(volume, sustainAt);
  gain.gain.linearRampToValueAtTime(0, endAt);

  oscillator.connect(gain);
  gain.connect(ctx.destination);

  oscillator.start(startAt);
  oscillator.stop(endAt + 0.01);
}

function playNoiseBurst(ctx, startAt, durationSec, volume) {
  if (durationSec <= 0 || volume <= 0) {
    return;
  }

  const bufferSize = Math.max(1, Math.ceil(ctx.sampleRate * durationSec));
  const buffer = ctx.createBuffer(1, bufferSize, ctx.sampleRate);
  const channel = buffer.getChannelData(0);

  for (let i = 0; i < bufferSize; i += 1) {
    channel[i] = (Math.random() * 2) - 1;
  }

  const source = trackNode(ctx.createBufferSource());
  const gain = trackNode(ctx.createGain());
  const endAt = startAt + durationSec;

  source.buffer = buffer;
  gain.gain.setValueAtTime(0, startAt);
  gain.gain.linearRampToValueAtTime(volume, startAt + Math.min(0.01, durationSec * 0.25));
  gain.gain.linearRampToValueAtTime(0, endAt);

  source.connect(gain);
  gain.connect(ctx.destination);

  source.start(startAt);
  source.stop(endAt + 0.01);
}

function playBulletinSiren(config) {
  const ctx = getAlarmContext();
  if (!ctx) {
    return;
  }

  ctx.resume().catch(() => {});
  stopAlarm();

  const volume = clampVolume(config.sirenVolume);
  const totalDurationSec = Math.max(0.5, Number(config.sirenDurationMs || defaultAlarmConfig.sirenDurationMs) / 1000);
  const onSec = Math.max(0.05, Number(config.bulletinOnMs || defaultAlarmConfig.bulletinOnMs) / 1000);
  const offSec = Math.max(0, Number(config.bulletinOffMs || defaultAlarmConfig.bulletinOffMs) / 1000);
  const cycles = Math.max(1, Number(config.bulletinCycles || defaultAlarmConfig.bulletinCycles));
  const staticSec = Math.max(0, Number(config.bulletinStaticMs || defaultAlarmConfig.bulletinStaticMs) / 1000);
  const lowHz = Math.max(40, Number(config.bulletinLowHz || defaultAlarmConfig.bulletinLowHz));
  const highHz = Math.max(40, Number(config.bulletinHighHz || defaultAlarmConfig.bulletinHighHz));

  const startAt = ctx.currentTime + 0.03;
  const endAt = startAt + totalDurationSec;
  let cursor = startAt;

  for (let cycle = 0; cycle < cycles; cycle += 1) {
    const burstDuration = Math.min(onSec, Math.max(0, endAt - cursor));
    playOscillatorBurst(ctx, lowHz, cursor, burstDuration, volume * 0.72, 'sine');
    playOscillatorBurst(ctx, highHz, cursor, burstDuration, volume * 0.72, 'sine');
    playOscillatorBurst(ctx, lowHz * 2, cursor, burstDuration, volume * 0.10, 'triangle');
    playOscillatorBurst(ctx, highHz * 2, cursor, burstDuration, volume * 0.10, 'triangle');
    cursor += onSec;

    if (cycle < cycles - 1) {
      cursor += offSec;
    }
  }

  const staticStartAt = Math.max(startAt, endAt - staticSec);
  const sustainDuration = Math.max(0, staticStartAt - cursor);
  if (sustainDuration > 0) {
    playOscillatorBurst(ctx, lowHz, cursor, sustainDuration, volume * 0.66, 'sine');
    playOscillatorBurst(ctx, highHz, cursor, sustainDuration, volume * 0.66, 'sine');
    playOscillatorBurst(ctx, lowHz * 2, cursor, sustainDuration, volume * 0.08, 'triangle');
    playOscillatorBurst(ctx, highHz * 2, cursor, sustainDuration, volume * 0.08, 'triangle');
  }

  if (staticSec > 0) {
    playOscillatorBurst(ctx, lowHz, staticStartAt, staticSec, volume * 0.38, 'sine');
    playOscillatorBurst(ctx, highHz, staticStartAt, staticSec, volume * 0.38, 'sine');
    playNoiseBurst(ctx, staticStartAt, staticSec, volume * 0.18);
  }

  alarmStopTimer = window.setTimeout(() => {
    clearActiveAudioNodes();
    alarmStopTimer = null;
  }, Math.ceil(totalDurationSec * 1000) + 120);
}

function playAlarmFromConfig(rawConfig) {
  const config = { ...defaultAlarmConfig, ...(rawConfig || {}) };

  if (config.enabled === false) {
    stopAlarm();
    return;
  }

  if (config.useNuiSiren !== false && config.mode === 'bulletin') {
    playBulletinSiren(config);
    return;
  }
}

window.addEventListener('message', (event) => {
  const data = event.data;

  if (data.action === 'setVisible') {
    document.body.classList.toggle('nui-visible', !!data.visible);
    document.body.classList.toggle('nui-hidden', !data.visible);
    root.classList.toggle('hidden', !data.visible);
    return;
  }

  if (data.action === 'alarm') {
    alarmBadge.classList.toggle('active', !!data.enabled);
    if (data.enabled) {
      playAlarmFromConfig(data.config);
    } else {
      stopAlarm();
    }
    return;
  }

  if (data.action === 'update') {
    const payload = data.payload || {};
    stageName.textContent = payload.stageName || 'Idle';
    waterLevel.textContent = `${Number(payload.level || 0).toFixed(2)} / ${Number(payload.maxLevel || 0).toFixed(2)}`;
    setHoldRemaining(payload.holdRemaining);
    statusText.textContent = payload.statusText || 'Monitoring';

    safeState.textContent = payload.statusText || 'Monitoring';
    safeState.className = `pill ${payload.stateClass || 'safe'}`;
    summary.textContent = payload.summary || 'Flood event inactive.';
  }
});
