"""Run Godot's real updater against the local Postman simulation.
python tools/test_update_distribution.py --godot GODOT_CONSOLE_EXE
"""
import argparse
import json
from pathlib import Path
import shutil
import socket
import subprocess
import time
import uuid
import os

ROOT=Path(__file__).resolve().parent.parent
def main():
    parser=argparse.ArgumentParser();parser.add_argument('--godot',required=True);parser.add_argument('--existing-simulation-log',type=Path);args=parser.parse_args()
    fixtures=ROOT/'validation/update-fixtures'
    if not (fixtures/'good.json').exists():
        subprocess.run([shutil.which('python'),str(ROOT/'tools/prepare_update_tests.py')],check=True)
    # Never touch a player's actual updater cache or saved games.
    run_id=uuid.uuid4().hex[:12]
    for p in fixtures.glob('*.json'):
        config=json.loads(p.read_text());config['storage']='user://validation_updates_'+run_id+'_'+p.stem;p.write_text(json.dumps(config))
    simulation=None;log=None
    log_path=args.existing_simulation_log or ROOT/'validation/updates-suite-sim.log'
    if not args.existing_simulation_log:
        try:
            with socket.create_connection(('127.0.0.1',4937),timeout=.3):
                raise RuntimeError('Port4937 already in use. Stop the earlier simulation first.')
        except OSError:pass
        log=log_path.open('w',encoding='utf-8')
        command=[shutil.which('postman'),'simulation','run',str(ROOT/'postman/simulations/updates.sim.yaml'),'--port','4937','--output','ndjson']
        env=os.environ.copy();env['RALPH_UPDATE_FIXTURES']=str(fixtures/'http')
        flags=subprocess.CREATE_NO_WINDOW if os.name=='nt' else 0
        simulation=subprocess.Popen(command,cwd=ROOT,stdout=log,stderr=subprocess.STDOUT,env=env,creationflags=flags)
    cases=[('good','download'),('good','mounted'),('good','rollback'),('good','download'),('good','confirmed'),('good','current'),('good','bundled')]
    cases += [(name,'download') for name in ['bad-signature','bad-hash','incompatible','wrong-platform','traversal','html-error','missing','timeout','unreachable']]
    # Each suite owns a fresh cache; repeated runs cannot reuse an earlier install.
    run_id=uuid.uuid4().hex[:10]
    configs={}
    for name,mode in cases:
        key=(name,'bundled' if mode=='bundled' else 'normal')
        if key in configs:continue
        config=json.loads((fixtures/(name+'.json')).read_text())
        config['bundled_sequence']=1 if mode=='bundled' else 0
        config['storage']='user://validation_updates_suite_'+run_id+'_'+name
        path=fixtures/('suite_'+run_id+'_'+name+'_'+key[1]+'.json')
        path.write_text(json.dumps(config));configs[key]=path
    try:
        for _ in range(1200):
            if simulation and simulation.poll() is not None:raise RuntimeError(log_path.read_text(encoding='utf-8'))
            if '"event":"listening"' in log_path.read_text(encoding='utf-8'):break
            time.sleep(.1)
        else:raise TimeoutError('Postman simulation did not start')
        for name,mode in cases:
            result=subprocess.run([args.godot,'--headless','--path',str(ROOT),'--script','tools/test_remote_updates.gd','--',
                    '--updates-test-config='+str(configs[(name,'bundled' if mode=='bundled' else 'normal')]),'--probe='+mode],cwd=ROOT,capture_output=True,text=True,timeout=45)
            report=result.stdout+result.stderr
            (ROOT/f'validation/update-suite-{name}-{mode}.log').write_text(report,encoding='utf-8')
            if result.returncode!=0 or 'SCRIPT ERROR' in report or '0 failures' not in report:raise AssertionError(report)
            print(name,mode,'PASS',flush=True)
        events=[]
        for line in log_path.read_text(encoding='utf-8').splitlines():
            try:events.append(json.loads(line))
            except json.JSONDecodeError:pass
        calls=[e for e in events if e.get('event')=='request' and 'GodotEngine' in str(e.get('requestHeaders',{}))]
        if not calls:raise AssertionError('No real Godot requests reached the simulation')
        print(f'{len(cases)} cases passed; {len(calls)} Godot HTTP calls recorded by Postman.',flush=True)
    finally:
        if simulation:
            if os.name=='nt':subprocess.run(['taskkill','/PID',str(simulation.pid),'/T','/F'],capture_output=True)
            else:simulation.terminate()
            simulation.wait(timeout=10)
        if log:log.close()

if __name__=='__main__':main()
