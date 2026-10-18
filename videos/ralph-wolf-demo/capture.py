"""Capture directed portrait cameras without changing the game project or saves.

python videos/ralph-wolf-demo/capture.py --godot /path/to/godot_console.exe
Native viewport PNGs avoid MovieWriter's locked landscape resolution. FFmpeg
encodes each shot, then joins them. Only the generated PNGs are removed after
successful encoding; source assets and user saves are never edited.
"""
import argparse
from pathlib import Path
import subprocess
import re

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent.parent
SHOTS = ['ralph', 'sam', 'forest', 'elastic', 'canyon', 'studio', 'race', 'strike', 'crush']
ACTIONS = {'race':2, 'strike':5, 'crush':5}
# Preserve all established shots, give the actions their full native setup/payoff.
EDIT = [('ralph',3),('race',2),('sam',4),('strike',5),('forest',4),
        ('elastic',5),('crush',5),('canyon',7),('studio',7)]

def run(args, **kwargs):
    return subprocess.run([str(a) for a in args], check=True, **kwargs)

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--godot', required=True)
    parser.add_argument('--reuse', action='store_true')
    options = parser.parse_args()
    (HERE / 'raw').mkdir(exist_ok=True)
    (HERE / 'assets').mkdir(exist_ok=True)
    for shot in SHOTS:
        output = HERE / 'raw' / (shot + '.mp4')
        if options.reuse and output.exists():
            continue
        command = [options.godot, '--path', ROOT, '--fixed-fps', '30']
        movie = HERE / 'raw' / (shot + '-audio.avi')
        if shot in ACTIONS:
            # MovieWriter provides deterministic, frame-synchronous game audio.
            # Its landscape video is discarded; our viewport PNGs stay portrait.
            command += ['--write-movie', movie]
        result = run(command + ['--script',
                      'tools/capture_presentation.gd', '--', '--shot=' + shot, '--frames'],
                     cwd=ROOT, capture_output=True, text=True, encoding='utf-8', errors='replace')
        (HERE / 'raw' / (shot + '.log')).write_text(result.stdout + result.stderr, encoding='utf-8')
        if 'SCRIPT ERROR' in result.stdout + result.stderr or '\nERROR:' in result.stdout + result.stderr:
            raise RuntimeError('Godot capture failed; inspect ' + shot + '.log')
        frames = HERE / 'raw' / shot
        count = ACTIONS.get(shot,7)*30
        if len(list(frames.glob('frame_*.png'))) != count:
            raise RuntimeError('Incomplete capture: ' + shot)
        run(['ffmpeg', '-y', '-hide_banner', '-loglevel', 'error', '-framerate', '30',
             '-i', frames / 'frame_%04d.png', '-frames:v', str(count), '-c:v', 'libx264',
             '-preset', 'fast', '-crf', '17', '-pix_fmt', 'yuv420p', '-movflags', '+faststart', output])
        if shot in ACTIONS:
            match = re.search(r'PRESENTATION_START '+shot+r' frame=(\d+)', result.stdout)
            if not match:
                raise RuntimeError('Missing synchronized audio marker: ' + shot)
            run(['ffmpeg','-y','-hide_banner','-loglevel','error','-i',movie,
                 '-ss',str((int(match[1])+1)/30),'-t',str(ACTIONS[shot]),'-vn',
                 '-ar','48000','-ac','2',HERE/'assets'/('action-'+shot+'.wav')])
            if shot == 'crush' and 'death=crush_death' not in result.stdout:
                raise RuntimeError('Rock did not trigger the actual crush sequence')
            if 'started=true' not in result.stdout:
                raise RuntimeError('Action did not start: ' + shot)
            movie.unlink()
        # Remove only exact frame files inside this shot's known output directory.
        for frame in frames.glob('frame_*.png'):
            if frame.resolve().parent == frames.resolve():
                frame.unlink()
        print('Captured:', shot, flush=True)
    concat = HERE / 'raw' / 'shots.txt'
    cuts = []
    for name, seconds in EDIT:
        cut = HERE/'raw'/(name+'-cut-v3.mp4')
        run(['ffmpeg','-y','-hide_banner','-loglevel','error','-i',HERE/'raw'/(name+'.mp4'),
             '-t',str(seconds),'-an','-c:v','libx264','-preset','fast','-crf','17',
             '-pix_fmt','yuv420p','-movflags','+faststart',cut])
        cuts.append(cut.name)
    concat.write_text('\n'.join("file '" + name + "'" for name in cuts) + '\n', encoding='utf-8')
    run(['ffmpeg', '-y', '-hide_banner', '-loglevel', 'error', '-f', 'concat', '-safe', '0',
         '-i', concat, '-c', 'copy', HERE / 'assets' / 'tour-v3.mp4'])
    run(['ffmpeg', '-y', '-hide_banner', '-loglevel', 'error', '-i',
         ROOT / 'assets' / 'audio' / 'music' / 'trip_v1.wav', '-t', '42', '-af',
         'afade=t=in:d=0.3,afade=t=out:st=40:d=2,loudnorm=I=-16:TP=-1.5:LRA=11',
         HERE / 'assets' / 'music-v2.wav'])
    print('Portrait footage ready:', HERE / 'assets' / 'tour-v3.mp4')

if __name__ == '__main__':
    main()
