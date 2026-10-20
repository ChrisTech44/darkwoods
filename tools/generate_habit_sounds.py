"""Reproducible original synthetic creature cues; no recordings, downloads or voice clones."""
import hashlib,json,math,random,struct,subprocess,tempfile,wave
from pathlib import Path
ROOT=Path(__file__).resolve().parent.parent
CUES={
 'lifeguard_whistle':(1.2,'whistle',False),
 'nightlight_whimper':(3.2,'whimper',True),'nightlight_scream':(1.0,'scream',False),
 'vulture_squawk':(0.8,'squawk',False),'vulture_peck':(0.25,'peck',False),'vulture_wings':(0.7,'wings',False),
 'huntmaster_horn':(1.4,'horn',False),'huntmaster_inhale':(1.5,'breath',False),
 'magician_drumroll':(1.5,'drum',False),'magician_tada':(0.8,'tada',False),
 'nobody_breathing':(4.0,'breath',True),'nobody_exhale':(0.5,'breath',False),
 'shade_inhale':(1.8,'breath',False),'shade_strike':(0.4,'peck',False)}
def main():
 manifest=ROOT/'assets/audio/manifest.json';data=json.loads(manifest.read_text())
 for cue,(length,kind,loop) in CUES.items():
  # Preserve user recordings that have replaced these prototypes.
  if cue in data["cues"] and data["cues"][cue].get("creator")!="Project procedural audio":continue
  rng=random.Random(cue);rate=24000;count=int(rate*length);buf=[];smooth=0.0
  for i in range(count):
   t=i/rate;u=t/length;env=math.sin(math.pi*u)**2;noise=rng.uniform(-1,1);smooth=.88*smooth+.12*noise
   if kind=='whistle': value=.14*(math.sin(2*math.pi*2450*t+.15*math.sin(2*math.pi*29*t))+.3*math.sin(2*math.pi*4900*t))
   elif kind=='horn':
    f=185 if u<.48 else 247;value=.12*(math.sin(2*math.pi*f*t)+.4*math.sin(2*math.pi*f*2*t)+.2*math.sin(2*math.pi*f*3*t))
   elif kind in ('breath','wings'):value=smooth*(.8 if kind=='breath' else 1.3)*(0.5+.5*math.sin(2*math.pi*(.5 if kind=='breath' else 6)*t)**2)
   elif kind=='peck':value=(noise*.25+math.sin(2*math.pi*140*t)*.18)*math.exp(-t*18)
   elif kind=='drum':value=noise*.3*math.exp(-((t*18)%1)*8)
   elif kind=='tada':value=.09*sum(math.sin(2*math.pi*f*t) for f in (392,494,587))+noise*.03
   else:
    f={'whimper':430,'scream':1100,'squawk':560}[kind];value=.16*math.sin(2*math.pi*f*t+3*math.sin(2*math.pi*7*t))+.08*smooth
   buf.append(struct.pack('<h',int(max(-.8,min(.8,value*env))*32767)))
  target=ROOT/'assets/audio'/f'{cue}.mp3'
  with tempfile.TemporaryDirectory() as folder:
   raw=Path(folder)/'cue.wav'
   with wave.open(str(raw),'wb') as out:out.setnchannels(1);out.setsampwidth(2);out.setframerate(rate);out.writeframes(b''.join(buf))
   subprocess.run(['ffmpeg','-loglevel','error','-y','-i',str(raw),'-codec:a','libmp3lame','-q:a','4',str(target)],check=True)
  data['cues'][cue]={'path':f'res://assets/audio/{cue}.mp3','bus':'Effects','loop':loop,'gain_db':(-10 if cue=='lifeguard_whistle' and 'lifeguard_shout' in data['cues'] else -2),'duration_seconds':length,'sha256':hashlib.sha256(target.read_bytes()).hexdigest(),'source':'tools/generate_habit_sounds.py, deterministic original synthesis','creator':'Project procedural audio','license':'Original project-generated asset','edits':'Mono synthesized PCM encoded MP3; no sampled recordings','format':'MP3; native Godot import','limit':'Bounded positional voices or round-owned following loop'}
 manifest.write_text(json.dumps(data,indent=2)+'\n')
if __name__=='__main__':main()
