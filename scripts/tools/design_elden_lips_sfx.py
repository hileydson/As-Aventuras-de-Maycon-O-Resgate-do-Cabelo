"""Short, distinct combat Foley. Original synthesis plus Ogrebane's CC0 pain clip."""
from pathlib import Path
import subprocess
import numpy as np

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'assets/novos_audios/elden_lips/sfx'
OUT.mkdir(exist_ok=True)
RATE = 44100
rng = np.random.default_rng(2904)


def noise(t, cutoff):
    x = rng.normal(0, 1, len(t))
    spectrum = np.fft.rfft(x)
    frequencies = np.fft.rfftfreq(len(t), 1 / RATE)
    spectrum *= 1 / np.sqrt(1 + (frequencies / cutoff) ** 6)
    y = np.fft.irfft(spectrum, n=len(t))
    return y / max(np.std(y), .001)


def save(name, signal, peak=.78, loop=False):
    signal = np.asarray(signal)
    if not loop:
        fade = min(len(signal)//4, int(.008*RATE))
        signal[:fade] *= np.linspace(0, 1, fade)
        signal[-fade:] *= np.linspace(1, 0, fade)
    signal = np.tanh(signal)
    signal *= peak / max(np.max(np.abs(signal)), .001)
    subprocess.run(['ffmpeg', '-v', 'error', '-y', '-f', 'f32le', '-ar', str(RATE),
        '-ac', '1', '-i', 'pipe:0', '-c:a', 'libvorbis', '-q:a', '5',
        str(OUT/(name+'.ogg'))], input=signal.astype('<f4').tobytes(), check=True)


for i in range(3):
    t = np.arange(int(RATE*.32))/RATE
    # A soft body thud with a short, dry wooden contact; no breaking/explosion.
    body = np.sin(2*np.pi*(83+i*7)*t)*np.exp(-t*24)
    contact = noise(t, 1850+i*110)*np.exp(-t*72)*.30
    wood = sum(np.sin(2*np.pi*f*t)*np.exp(-t*decay)*gain
        for f, decay, gain in [(330+i*21,43,.28),(780,64,.12),(1280,90,.06)])
    save('wood_body_%d' % (i+1), body*.65+wood+contact, .72)
    save('shield_%d' % (i+1), wood*1.6+noise(t,2600)*np.exp(-t*100)*.35, .68)

t = np.arange(int(RATE*.50))/RATE
save('wood_body_heavy', np.sin(2*np.pi*(58*t+1.5*(1-np.exp(-t*18))))*
    np.exp(-t*12)+noise(t,1400)*np.exp(-t*55)*.42, .82)

pain_path = ROOT/'assets/novos_audios/calabouco_terror/zombie_pain_1.wav'
raw = subprocess.run(['ffmpeg','-v','error','-i',str(pain_path),'-f','f32le',
    '-ar',str(RATE),'-ac','1','pipe:1'],capture_output=True,check=True).stdout
pain = np.frombuffer(raw,dtype='<f4').astype(float)
for i, speed in enumerate([.93,1.02,1.10]):
    positions = np.arange(min(int(.45*RATE),int(len(pain)/speed)))*speed
    voice = np.interp(positions,np.arange(len(pain)),pain)
    voice *= np.minimum(np.arange(len(voice))/(RATE*.015),1)
    voice *= np.minimum((len(voice)-np.arange(len(voice)))/(RATE*.10),1)
    save('lips_pain_%d' % (i+1),voice,.58)
save('maycon_hurt',np.interp(np.arange(int(.34*RATE))*1.2,np.arange(len(pain)),pain)*
    np.exp(-np.arange(int(.34*RATE))/RATE*2),.55)

for name, duration in [('blade_swish',.32),('food_sweep',.64),('food_launch',.38)]:
    t=np.arange(int(RATE*duration))/RATE
    envelope=np.sin(np.pi*t/duration)**2
    save(name,noise(t,1900 if name=='blade_swish' else 950)*envelope*.30+
        np.sin(2*np.pi*(170*t-65*t*t))*envelope*.12,.62)

t=np.arange(int(RATE*1.12))/RATE
charge=(t/1.12)**1.5
save('food_charge',noise(t,700)*charge*.20+
    np.sin(2*np.pi*(43*t+25*t*t))*charge*.5,.65)
t=np.arange(int(RATE*.86))/RATE
save('food_slam',np.sin(2*np.pi*(47*t+2*(1-np.exp(-t*12))))*np.exp(-t*7)+
    noise(t,550)*np.exp(-t*16)*.65+noise(t,2800)*np.exp(-t*55)*.18,.88)
t=np.arange(int(RATE*.42))/RATE
splat=noise(t,900)*np.exp(-t*18)*.6
for delay in [.02,.067,.12]:
    local=np.maximum(0,t-delay)
    splat+=np.sin(2*np.pi*(180*local+15*np.sin(local*23)))*np.exp(-local*35)*(t>=delay)*.2
save('tomato_splat',splat,.72)
t=np.arange(int(RATE*.20))/RATE
save('wood_equip',np.sin(2*np.pi*260*t)*np.exp(-t*32)*.45+
    noise(t,1800)*np.exp(-t*75)*.3,.56)
t=np.arange(int(RATE*.28))/RATE
save('boss_step',np.sin(2*np.pi*68*t)*np.exp(-t*23)*.65+
    noise(t,620)*np.exp(-t*38)*.25,.65)

t=np.arange(int(RATE*4.8))/RATE
e=np.sin(np.pi*t/4.8)**1.5
save('world_shift',noise(t,650)*e*.25+
    sum(np.sin(2*np.pi*(f*t+8*t*t))*e*.09 for f in [31,47.3,71.8]),.76)
t=np.arange(int(RATE*3.2))/RATE
save('storm_thunder',noise(t,180)*np.exp(-t*1.2)*.6+
    noise(t,850)*np.exp(-t*6)*.24,.78)
t=np.arange(int(RATE*20))/RATE
wind=noise(t,350)*(.22+.09*np.sin(t*np.pi/10)+.06*np.sin(t*np.pi*3/10))
# FFT noise and its envelope share the 20-second period.
save('storm_wind',wind,.40,True)
print('Elden Lips:',len(list(OUT.glob('*.ogg'))),'short Foley/weather assets')
