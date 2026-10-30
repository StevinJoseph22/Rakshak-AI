let activeOscillators: OscillatorNode[] = [];
let audioCtx: AudioContext | null = null;

export function playHospitalErSiren(durationSec: number = 3.2, volume: number = 0.2) {
  try {
    const AudioContextClass =
      window.AudioContext ||
      (window as unknown as { webkitAudioContext: typeof AudioContext }).webkitAudioContext;
    if (!audioCtx && AudioContextClass) {
      audioCtx = new AudioContextClass();
    }
    if (audioCtx && audioCtx.state === 'suspended') {
      audioCtx.resume();
    }
    if (!audioCtx) return;

    stopAllSirens();
    const osc = audioCtx.createOscillator();
    const gain = audioCtx.createGain();
    osc.type = 'sawtooth';
    osc.frequency.setValueAtTime(800, audioCtx.currentTime);
    osc.frequency.linearRampToValueAtTime(1200, audioCtx.currentTime + 0.4);
    osc.frequency.linearRampToValueAtTime(800, audioCtx.currentTime + 0.8);
    osc.frequency.linearRampToValueAtTime(1200, audioCtx.currentTime + 1.2);
    osc.frequency.linearRampToValueAtTime(800, audioCtx.currentTime + 1.6);
    gain.gain.setValueAtTime(volume, audioCtx.currentTime);
    gain.gain.exponentialRampToValueAtTime(0.01, audioCtx.currentTime + durationSec);
    osc.connect(gain);
    gain.connect(audioCtx.destination);
    osc.start();
    activeOscillators.push(osc);
    setTimeout(() => {
      stopAllSirens();
    }, durationSec * 1000);
  } catch (e) {
    console.warn('[sirenAudio] Web Audio failed:', e);
  }
}

export function stopAllSirens() {
  activeOscillators.forEach((osc) => {
    try {
      osc.stop();
      osc.disconnect();
    } catch (_) {}
  });
  activeOscillators = [];
}
