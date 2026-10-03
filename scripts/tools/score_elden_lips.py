"""Original procedural score: two seamless, synchronised 32-bar combat stems."""
from pathlib import Path
import wave
import numpy as np

ROOT = Path(__file__).resolve().parents[2]
RATE = 22050
BPM = 96
BEAT = 60 / BPM
DURATION = 32 * 4 * BEAT
rng = np.random.default_rng(1407)


def frequency(note):
    return 440 * 2 ** ((note - 69) / 12)


def note(target, start, duration, midi, volume, kind):
    n = int(duration * RATE)
    t = np.arange(n) / RATE
    f = frequency(midi)
    if kind == 'choir':
        signal = sum(np.sin(2*np.pi*(f*ratio*t + .003*np.sin(t*4.7))) / ratio
            for ratio in [1, 2, 3, 5])
        attack = .75
    elif kind == 'strings':
        signal = sum(np.sin(2*np.pi*f*k*t + .03*np.sin(t*31)) / k
            for k in range(1, 9))
        attack = .16
    elif kind == 'bell':
        signal = sum(np.sin(2*np.pi*f*k*t)*np.exp(-t*(.5+k*.3)) / k
            for k in [1,2.01,2.74,4.07])
        attack = .01
    else:
        signal = np.sin(2*np.pi*f*t)+.3*np.sin(2*np.pi*f*2*t)
        attack = .08
    envelope = np.minimum(t/attack,1) * np.minimum((duration-t)/.6,1)
    signal = signal * np.maximum(envelope,0) * volume
    # Stereo placement and short room reflections are baked into the stem.
    pan = .28 + (midi % 7) * .07
    stereo = np.column_stack((signal*(1-pan), signal*pan))
    index = int(start * RATE)
    for delay, gain in [(0,1),(.13,.18),(.29,.12),(.47,.075)]:
        indices = (index + int(delay*RATE) + np.arange(n)) % len(target)
        target[indices] += stereo * gain


def drum(target,start,strong):
    duration=1.8 if strong else .75
    t=np.arange(int(RATE*duration))/RATE
    phase=2*np.pi*(39*t+1.1*(1-np.exp(-t*14)))
    signal=np.sin(phase)*np.exp(-t*4) + rng.normal(0,1,len(t))*.10*np.exp(-t*25)
    indices=(int(start*RATE)+np.arange(len(t)))%len(target)
    target[indices]+=signal[:,None]*(.28 if strong else .15)


base=np.zeros((int(RATE*DURATION),2),dtype=np.float32)
rage=np.zeros_like(base)
chords=[(38,45,50,53),(34,41,46,50),(37,44,49,52),(33,40,45,49)]
for bar in range(32):
    start=bar*4*BEAT
    chord=chords[(bar//2)%4]
    for pitch in chord:
        note(base,start,4*BEAT,pitch,.09,'choir')
        note(base,start,4*BEAT,pitch+12,.028,'strings')
    note(base,start,4*BEAT,chord[0]-12,.12,'bass')
    drum(base,start,True)
    drum(base,start+2*BEAT,False)
    for step in range(8):
        note(rage,start+step*.5*BEAT,.55*BEAT,chord[step%4]+24,.10,'strings')
        if step%2==0: drum(rage,start+step*.5*BEAT,step==0)
    if bar%4==0:
        note(base,start,6*BEAT,chord[2]+24,.065,'bell')
        note(rage,start,4*BEAT,chord[3]+24,.065,'choir')

out=ROOT/'assets/novos_audios/elden_lips'
out=out/'source'
out.mkdir(exist_ok=True)
for name,data in [('ritual',base),('frenzy',rage)]:
    data=np.tanh(data*1.2)*.72
    with wave.open(str(out/(name+'.wav')),'wb') as audio:
        audio.setnchannels(2);audio.setsampwidth(2);audio.setframerate(RATE)
        audio.writeframes((data*32767).astype('<i2').tobytes())
    print(name, DURATION, 'seconds')
