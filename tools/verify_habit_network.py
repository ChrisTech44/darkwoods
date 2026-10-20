"""Two-process real ENet brain-state/cue checks; accepted playback, no microphones."""
import json,os,re,socket,subprocess,time
from godot_cli import ROOT,godot_binary

def main():
 out=ROOT/'artifacts/wheel_monsters';out.mkdir(parents=True,exist_ok=True)
 with socket.socket(socket.AF_INET,socket.SOCK_DGRAM) as sock:sock.bind(('127.0.0.1',0));port=sock.getsockname()[1]
 jobs=[];streams=[]
 try:
  for side in ['host','client']:
   path=out/f'habit_{side}.log';stream=path.open('w');streams.append(stream)
   env=os.environ.copy();env.update(HABIT_SIDE=side,HABIT_PORT=str(port))
   cmd=[godot_binary(),'--headless','--path',str(ROOT),'--audio-driver','Dummy','--script','res://tests/integration/habit_peer.gd']
   jobs.append((subprocess.Popen(cmd,cwd=ROOT,env=env,stdout=stream,stderr=subprocess.STDOUT),path))
   if side=='host':time.sleep(.5)
  deadline=time.monotonic()+180
  while any(p.poll() is None for p,_ in jobs) and time.monotonic()<deadline:
   if any(p.poll() not in (None,0) for p,_ in jobs):break
   time.sleep(.1)
 finally:
  for p,_ in jobs:
   if p.poll() is None:p.terminate();p.wait(timeout=5)
  for stream in streams:stream.close()
 results=[]
 for p,path in jobs:
  lines=path.read_text().splitlines();rows=[json.loads(x) for x in lines if x.startswith('{') and json.loads(x).get('event')=='test_result'];errors=[x for x in lines if re.search(r'(?:SCRIPT ERROR|ERROR|WARNING):',x)]
  results.append(dict(passed=p.returncode==0 and len(rows)==1 and rows[0]['failures']==0 and not errors,result=rows,errors=errors,log=str(path.relative_to(ROOT))))
 report=dict(passed=all(x['passed'] for x in results),results=results)
 (out/'habit_network.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report));return 0 if report['passed'] else 1
if __name__=='__main__':raise SystemExit(main())
