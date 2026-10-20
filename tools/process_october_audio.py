"""Rebuild the 20 October user pack from preserved originals; ffmpeg + stdlib only."""
from pathlib import Path
import array,hashlib,json,math,shutil,struct,subprocess,tempfile,wave
ROOT=Path(__file__).resolve().parents[1]
SOURCE=ROOT/'art_sources/audio/2026-10-20'
OUT=ROOT/'assets/audio'
# cue, original, start/end seconds, mean ceiling, loop, optional exact windup length.
PLAN=[
 ('lifeguard_shout','NO_RUNNING.mp3',0,1.78,-22,False,None),
 ('nightlight_scream','LEAVE_IT_ON.mp3',.045,1.4,-22,False,None),
 ('nobody_breathing','slow_breathing_loop.mp3',2.65,13.25,-28,True,None),
 ('vulture_squawk','vulture_noises.mp3',.035,1.227,-23,False,None),
 ('magician_drumroll','drumroll_with_tada.mp3',.065,2.015,-24,False,1.5),
 ('magician_tada','drumroll_with_tada.mp3',2.015,4.55,-23,False,None),
 ('noise_tin_rattle','can_rattling.mp3',.36,2.15,-24,False,None),
 ('village_bell','church_bell_single_toll.mp3',.055,3.15,-24,False,None),
 ('flare_ignite','flare_noise_need_analyze.mp3',.18,2.65,-25,False,None),
 ('flare_hiss','flare_noise_need_analyze.mp3',2.75,10.75,-28,True,None),
 ('flashlight_on','flashlight_click.mp3',.08,.245,-26,False,None),
 ('flashlight_off','flashlight_click.mp3',.33,.49,-26,False,None),
 ('snore','snore.mp3',.14,1.64,-27,True,None),
 ('water_splash','water_splash.mp3',0,.89,-24,False,None),
 ('huntmaster_horn','mega_horn.mp3',0,4.22,-23,False,None),
]
def pcm(path,channel,start=0,end=None,tempo=None):
 filters=f'pan=mono|c0=c{channel},atrim=start={start}'
 if end is not None:filters+=f':end={end}'
 filters+=',asetpts=PTS-STARTPTS'
 if tempo:filters+=f',atempo={tempo:.9f}'
 return array.array('f',subprocess.check_output(['ffmpeg','-v','error','-i',str(path),'-af',filters,'-ar','48000','-f','f32le','-']))

def stats(data):
 return {'peak_db':20*math.log10(max(1e-12,max(abs(x) for x in data))), 'mean_db':20*math.log10(max(1e-12,math.sqrt(sum(x*x for x in data)/len(data))))}
def main():
 SOURCE.mkdir(parents=True,exist_ok=True)
 originals=sorted({r[1] for r in PLAN})
 for name in originals:
  src=OUT/name;dst=SOURCE/name
  if not dst.exists():shutil.copy2(src,dst)
  elif src.exists() and name not in ('water_splash.mp3','snore.mp3'):
   assert src.read_bytes()==dst.read_bytes(),f'Unexpected changed original: {name}'
 manifest=json.loads((OUT/'manifest.json').read_text());report=[]
 for cue,name,start,end,target_mean,loop,exact in PLAN:
  source=SOURCE/name
  info=json.loads(subprocess.check_output(['ffprobe','-v','error','-show_entries','stream=channels','-of','json',str(source)]))
  channels=info['streams'][0]['channels']
  channel=max(range(channels),key=lambda c:stats(pcm(source,c))['mean_db'])
  data=pcm(source,channel,start,end,(end-start)/exact if exact else None)
  if exact:
   size=round(exact*48000);data=array.array('f',(list(data)+[0.0]*max(0,size-len(data)))[:size])
  if loop:
   n=min(4800,len(data)//8)
   blend=array.array('f',(data[-n+i]*(1-i/n)+data[i]*(i/n) for i in range(n)))
   data=data[n:-n]+blend
  else:
   fade_in=min(240,len(data)//8);fade_out=min(1200,len(data)//8)
   for i in range(fade_in):data[i]*=i/fade_in
   for i in range(fade_out):data[-1-i]*=i/fade_out
  before=stats(data);gain=min(target_mean-before['mean_db'],(-8 if loop else -6)-before['peak_db'])
  data=array.array('f',(x*10**(gain/20) for x in data))
  destination=OUT/(cue+'.mp3')
  with tempfile.TemporaryDirectory() as folder:
   wav=Path(folder)/'cue.wav'
   with wave.open(str(wav),'wb') as f:
    f.setnchannels(1);f.setsampwidth(2);f.setframerate(48000)
    f.writeframes(b''.join(struct.pack('<h',max(-32768,min(32767,round(x*32767)))) for x in data))
   subprocess.run(['ffmpeg','-y','-v','error','-i',str(wav),'-c:a','libmp3lame','-b:a','128k',str(destination)],check=True)
  measured=stats(pcm(destination,0));assert measured['peak_db']<=-4.5,(cue,measured)
  duration=len(pcm(destination,0))/48000
  row={'cue':cue,'original':name,'original_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'channel':channel,'trim_seconds':[start,end],'gain_db':round(gain,3),'loop_crossfade_ms':100 if loop else 0,'exact_seconds':exact,'duration_seconds':duration,**measured}
  report.append(row)
  manifest['cues'][cue]={'path':f'res://assets/audio/{cue}.mp3','bus':'Effects','loop':loop,'gain_db':-4 if cue in ('flare_hiss','snore') else -2,'duration_seconds':duration,'sha256':hashlib.sha256(destination.read_bytes()).hexdigest(),'source':'User supplied, 20 October 2026','creator':'Not supplied','license':'Redistribution provenance pending user documentation','original_path':str(source.relative_to(ROOT)),'original_sha256':row['original_sha256'],'edits':f'Channel {channel} retained as mono; trim {start}–{end}s; gain {gain:.3f}dB; '+('100ms circular loop crossfade' if loop else '5ms attack / up to 25ms tail fades')+(f'; pitch-preserving tempo fit to {exact}s windup' if exact else ''),'format':'MP3 mono 48kHz / 128kbps; native Godot import','limit':'Round-owned following loop' if loop else 'One authoritative accepted event; bounded positional voice','measured':measured}
 manifest['cues']['lifeguard_whistle']['gain_db']=-10
 (OUT/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
 (SOURCE/'processing.json').write_text(json.dumps(report,indent=2)+'\n')
 # Upload names are retired only after every processed output passes decoding/peak checks.
 targets={cue+'.mp3' for cue,*_ in PLAN}
 for name in originals:
  if name not in targets:(OUT/name).unlink(missing_ok=True)
 print(json.dumps(report,indent=2))
if __name__=='__main__':main()
