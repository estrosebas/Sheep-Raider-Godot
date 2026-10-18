"""Copy native PC music without splitting it; record exact sample boundaries."""
import argparse
import json
import shutil
import wave
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DEFAULT = Path('C:/Users/estro/Downloads/Sheep.Dog.and.Wolf/Sheep.Dog.and.Wolf/Sheep.Dog.and.Wolf/Musics')
LEVEL_TRACKS = ['Jungle_v1', 'Trip_v1', 'JAMI Full', 'Mix Jami_v2', 'JAZZ90_v3',
                'Trip_v1', 'Luney_v2', 'Luney_v2', 'Zilla_v2', 'JUNGLERHODES01_v2',
                'ROAD MARECAGE_v2', 'ROAD MARECAGE_v2', 'Zilla_v2', 'JAZZ90_v3',
                'DNBASS_v2', 'NEWS1LAST_v2', 'JUNGLETUTORIAL_v2', 'FRONZYLAST_v3']

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source', type=Path, nargs='?', default=DEFAULT)
    args = parser.parse_args()
    out = ROOT / 'assets/audio/music'
    out.mkdir(parents=True, exist_ok=True)
    tracks = []
    for title in dict.fromkeys(LEVEL_TRACKS):
        source = args.source / (title + '.wav')
        filename = title.lower().replace(' ', '_') + '.wav'
        target = out / filename
        if not target.exists() or target.read_bytes() != source.read_bytes():
            shutil.copyfile(source, target)
        with wave.open(str(source)) as wav:
            rate, frames = wav.getframerate(), wav.getnframes()
        tracks.append(dict(id=title, title=title, path='res://assets/audio/music/' + filename,
                           start_time=0.0, end_time=frames/rate,
                           loop_start=0.0, start_sample=0, end_sample=frames,
                           sample_rate=rate, levels=[i for i, name in enumerate(LEVEL_TRACKS) if name == title]))
    (out/'catalog.json').write_text(json.dumps(dict(
        source='PC StreamPlayer::g_levelMusicClip / LoaderThread and StreamSound::ReadWave looping ResetFile',
        bounds='Entire native PC files, no invented subtrack cuts. End is exclusive.',
        tracks=tracks), ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
    print(f'{len(tracks)} native music files catalogued')

if __name__ == '__main__':
    main()
