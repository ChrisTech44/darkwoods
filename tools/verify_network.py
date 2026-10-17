"""Launch independent real ENet processes and preserve their machine-readable results."""
import argparse,json,subprocess,time,re
from pathlib import Path
from godot_cli import ROOT,godot_binary

def run_case(mode,players,graphical=False):
    folder=ROOT/'artifacts'/'network';folder.mkdir(parents=True,exist_ok=True)
    engine=godot_binary();port=27941+(100 if mode=='woods' else 0)+players+(1000 if graphical else 0)
    running=[];streams=[]
    def spawn(side,index=0):
        name=f'{mode}_{players}_{side}_{index}'+('_graphical' if graphical else '');path=folder/(name+'.log')
        stream=path.open('w');streams.append(stream)
        cmd=[engine,'--path',str(ROOT),'--audio-driver','Dummy','--script','res://tests/integration/network_peer.gd']
        if not graphical:cmd.insert(1,'--headless')
        else:cmd[1:1]=['--position',f'{index*600},40','--resolution','576x324']
        cmd+=['--','--all-escapes','--side',side,'--mode',mode,'--port',str(port),'--peers',str(players),'--index',str(index)]
        if graphical:cmd+=['--capture']
        process=subprocess.Popen(cmd,cwd=ROOT,stdout=stream,stderr=subprocess.STDOUT)
        running.append((name,process,path,cmd))
    spawn('host');time.sleep(.5)
    for i in range(1,players):spawn('client',i)
    deadline=time.monotonic()+210;late=False
    while any(p.poll() is None for _,p,_,_ in running) and time.monotonic()<deadline:
        if players==2 and not late and '"stage":"movement"' in running[0][2].read_text():
            spawn('late',9);late=True
        time.sleep(.1)
    records=[]
    for name,process,path,cmd in running:
        if process.poll() is None:process.kill();process.wait()
        text=path.read_text();events=[]
        for line in text.splitlines():
            if line.startswith('{'):events.append(json.loads(line))
        summaries=[e for e in events if e.get('event')=='test_result']
        errors=[x for x in text.splitlines() if re.search(r'(?:SCRIPT ERROR|ERROR|WARNING):',x)]
        passed=process.returncode==0 and len(summaries)==1 and summaries[0]['failures']==0 and not errors
        record=dict(name=name,command=cmd,exit_code=process.returncode,passed=passed,errors=errors,result=summaries,log=str(path.relative_to(ROOT)))
        records.append(record);print(json.dumps(record),flush=True)
    for stream in streams:stream.close()
    return records

def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--graphical',action='store_true');parser.add_argument('--mode',choices=['camp','woods','all'],default='all');parser.add_argument('--players',type=int,choices=[2,4],default=2);args=parser.parse_args()
    records=[]
    for mode in (['camp','woods'] if args.mode=='all' else [args.mode]):
        records+=run_case(mode,args.players,args.graphical)
        if not all(r['passed'] for r in records):break
    passed=bool(records) and all(r['passed'] for r in records)
    name=f'summary_{args.mode}_{args.players}'+('_graphical' if args.graphical else '')+'.json'
    (ROOT/'artifacts'/'network'/name).write_text(json.dumps(dict(passed=passed,graphical=args.graphical,results=records),indent=2)+'\n')
    return 0 if passed else 1
if __name__=='__main__':raise SystemExit(main())
