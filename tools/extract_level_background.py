"""Recover the native framebuffer backdrop from WAR header bytes8..10.

Load_DAVnWAR (engine/list.cpp) halves each channel before SetClearColor and
SetFogColor. This backdrop is visible through water and outside world meshes;
it must not be replaced by a generic blue sky or by an invented collision floor.
The Godot legacy materials retain source RGB rather than the PC loader's
halved vertex colors; render_clear_rgb must use that same encoding to meet
the river gradient. pc_clear_rgb records the native PC value for auditing.
Usage: python tools/extract_level_background.py ORIGINAL_LEVEL_FOLDER
"""
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def extract(folder):
    folder = Path(folder)
    source = next(folder.glob('*.[wW][aA][rR]'))
    raw = source.read_bytes()
    if raw[4:8] != b'V2.6':
        raise ValueError('Expected original Black Sheep WAR V2.6 header')
    rgb = list(raw[8:11])
    slug = folder.name.lower().replace('-', '_')
    destination = ROOT/'assets/levels'/slug/'data/background.json'
    destination.parent.mkdir(parents=True, exist_ok=True)
    data = {'source': source.name, 'header_offset': 8, 'header_rgb': rgb,
            'render_clear_rgb': rgb,
            'render_color_encoding': 'source_rgb_matching_legacy_materials',
            'pc_clear_rgb': [channel >> 1 for channel in rgb],
            'native_function': 'engine/list.cpp::Load_DAVnWAR -> PolyBatcher::SetClearColor; Frustrum::SetFogColor'}
    destination.write_text(json.dumps(data, indent=2)+'\n', encoding='utf8')
    print(slug, 'native header', rgb, 'PC clear', data['pc_clear_rgb'])
    return data


if __name__ == '__main__':
    extract(sys.argv[1])
