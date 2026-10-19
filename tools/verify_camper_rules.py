"""Verify disabled camper powers with real listen-host and dedicated processes."""
from pathlib import Path
import argparse,json,os,re,subprocess,time
from godot_cli import ROOT,godot_binary

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--pack',type=Path)
    args=parser.parse_args()
    if args.pack and not args.pack.is_file():parser.error('Pack does not exist')
    out=ROOT/('artifacts/ability_polish/rules_pack' if args.pack else 'artifacts/ability_polish/rules');out.mkdir(parents=True,exist_ok=True)
    results=[]
    for dedicated in (False,True):
        if args.pack and not dedicated:continue
        port=29381+int(dedicated);running=[];streams=[]
        specs=[('server' if dedicated else 'host',0)]+[('client',i) for i in range(0 if dedicated else 1,4)]
        for side,index in specs:
            path=out/f'{"dedicated" if dedicated else "listen"}_{side}_{index}.log'
            stream=path.open('w');streams.append(stream)
            env=os.environ.copy();env.update(LNAC_RULE_SIDE=side,LNAC_RULE_PORT=str(port),LNAC_RULE_INDEX=str(index),LNAC_RULE_HUMANS='4')
            cmd=[godot_binary(),'--headless','--audio-driver','Dummy']
            if side=='server' and args.pack:cmd+=['--main-pack',str(args.pack.resolve())]
            else:cmd+=['--path',str(ROOT)]
            cmd+=['--script',str(ROOT/'tests/integration/camper_rule_peer.gd')]
            if side=='server':cmd+=['--','--dedicated-server','--port',str(port),'--mode','camp','--seed','42','--min-players','4','--start-delay','1','--no-camper-abilities']
            proc=subprocess.Popen(cmd,cwd=ROOT,env=env,stdout=stream,stderr=subprocess.STDOUT)
            running.append((proc,path));time.sleep(.3)
        end=time.monotonic()+120
        while any(p.poll() is None for p,_ in running) and time.monotonic()<end:time.sleep(.2)
        for proc,path in running:
            if proc.poll() is None:proc.kill();proc.wait()
            text=path.read_text();events=[json.loads(x) for x in text.splitlines() if x.startswith('{')];summary=[e for e in events if e.get('event')=='test_result']
            errors=re.findall(r'.*(?:SCRIPT ERROR|ERROR|WARNING):.*',text)
            ok=proc.returncode==0 and len(summary)==1 and summary[0]['failures']==0 and not errors
            results.append(dict(log=str(path.relative_to(ROOT)),passed=ok,result=summary,errors=errors));print(json.dumps(results[-1]),flush=True)
        for stream in streams:stream.close()
        if not all(r['passed'] for r in results):break
    (out/'summary.json').write_text(json.dumps(results,indent=2)+'\n')
    return 0 if all(r['passed'] for r in results) else 1
if __name__=='__main__':raise SystemExit(main())
