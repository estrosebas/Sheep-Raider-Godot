"""Shared Flute/Wolf mechanics, decoded from original Lvl-04 WAR/DAV/SND.
python tools/extract_flute_mechanics.py DECOMP_REPO LEVEL04_FOLDER
Only writes its own flute outputs; does not rewrite shared item definitions.
"""
import json
import re
import struct
import sys
from pathlib import Path
from extract_run_assets import decode
from extract_shared_items import read_rig, page_image
from extract_inventory_ui import read_lists

ROOT = Path(__file__).resolve().parents[1]


def extract(decomp, folder):
    decomp, folder = Path(decomp), Path(folder)
    sys.path.insert(0, str(decomp / "tools"))
    import level_editor as editor
    import war_meshes
    war = next(folder.glob("*.[wW][aA][rR]")).read_bytes()
    table = struct.unpack_from("<%dI" % struct.unpack_from("<I", war, 12)[0], war, 16)
    wolf = table[0] & 0xffffff
    anim_table = struct.unpack_from("<I", war, wolf + 16)[0]
    joints = struct.unpack_from("<H", war, wolf + 24)[0]
    count = struct.unpack_from("<I", war, anim_table)[0]
    names = {war[p:p+8].split(b"\0")[0].decode().lower(): p
             for p in struct.unpack_from("<%dI" % count, war, anim_table + 4) if p}
    player_animations = {alias: decode(war, names[name], joints) for name, alias in [
        ("flute1", "flute_idle"), ("walkf1", "flute_walk"), ("standf1", "flute_fidget"),
        ("punch6", "bull_death")]}
    player_path = ROOT / "assets/models/ralph_flute_data.json"
    player_path.write_text(json.dumps(player_animations, separators=(",", ":")), encoding="utf8")

    flute_entity = next(i for i, value in enumerate(table)
                        if value >> 24 == 5 and struct.unpack_from("<H", war, (value & 0xffffff) + 10)[0] == 41)
    model = struct.unpack_from("<H", war, table[flute_entity] & 0xffffff)[0]
    dav_path = next(folder.glob("*.[dD][aA][vV]"))
    raw = dav_path.read_bytes()
    dav = war_meshes.read_dav(dav_path)
    dt = editor.dav_tables(raw)
    rig = read_rig(war, table[model], editor, war_meshes, dt,
                   {name: name for name in ["link", "flute1", "walkf1", "standf1", "objet"]})
    rig.update(rotation_order="ZXY", rotation_axis_sign=[1, 1, -1])
    base = ROOT / "assets/items/flute"
    (base / "textures").mkdir(parents=True, exist_ok=True)
    materials = {}
    for page in rig["surfaces"]:
        if int(page) < 0:
            continue
        record = dav["pages"][int(page)]
        page_image(raw, record).save(base / "textures" / ("page_%s.png" % page))
        materials[page] = record["kind"]
    (base / "worn_data.json").write_text(json.dumps(rig, separators=(",", ":")), encoding="utf8")
    (base / "mesh_data.json").write_text(json.dumps(rig["surfaces"], separators=(",", ":")), encoding="utf8")
    definition = {"class_id": 41, "slug": "flute", "label": "Flauta",
                  "mesh": "res://assets/items/flute/worn.tres", "materials": materials,
                  "source_level": folder.name, "source_resource": flute_entity, "source_model": model,
                  "loop_animations": ["flute1", "walkf1", "standf1", "objet", "link"],
                  "attach_joint": 18, "playing_speed": 2.0, "sam_radius": 3.0,
                  "sound_id": 37, "sound_path": "res://assets/items/flute/flute_tune.wav"}
    definition['held_pose'] = 'link'
    definition['held_pose_source'] = 'Flute::MSG_PICKUP selects LINK; HELD_STATE_BEGIN/END only changes state/sound'
    (base / "definition.json").write_text(json.dumps(definition, ensure_ascii=False, indent=2), encoding="utf8")
    # EmitterDriftParams ends with sheetIndex=8; 6 is its sizeStart.
    # emitter.cpp s_effectSheetRes[8] = DAV_IDI_IFTNOTE_ (209).
    groups, bitmap_banks = read_lists(raw)
    header = (decomp / "src/include/scenaric_props.h").read_text()
    sam_icon_id = int(re.search(r"\bDAV_IDI_IFTTSAM_\s*=\s*(\d+)", header)[1])
    sam_bitmap = groups[sam_icon_id][0]
    x, width, y, height, page = dav["rects"][sam_bitmap]
    page_image(raw, dav["pages"][page]).crop((x, y, x+width, y+height)).save(base / "target_sam.png")
    first = groups[209][0]
    note_bitmaps = next(bank for bank in bitmap_banks if first in bank)
    (base / "notes").mkdir(exist_ok=True)
    notes = []
    for index, bitmap in enumerate(note_bitmaps):
        x, width, y, height, page = dav["rects"][bitmap]
        path = base / "notes" / ("frame_%d.png" % index)
        page_image(raw, dav["pages"][page]).crop((x, y, x + width, y + height)).save(path)
        notes.append("res://" + path.relative_to(ROOT).as_posix())
    pointer = next(value & 0xffffff for value in table if value >> 24 == 0x82)
    count = struct.unpack_from("<I", war, pointer)[0]
    pointer += 4
    exports = {}
    for _ in range(count):
        identity, length = struct.unpack_from("<HH", war, pointer)
        exports[identity] = struct.unpack_from("<%dI" % length, war, pointer + 4)
        pointer += 4 + length * 4
    hypnotized = []
    for pointer in exports.get(544, []):
        flags, *corners = struct.unpack_from("<I6h", war, pointer)
        hypnotized.append({"flags": flags, "min": corners[:3], "max": corners[3:]})
    rules = {"resource": flute_entity, "class_id": 41, "model": model, "sam_resource": 42,
             "attach_joint": 18, "sam_radius": 3.0, "noise_radius": 6.0,
             "note_aim_radius": 20.0, "wolf_speed": 2.0,
             "sound_id": 37, "sound_path": definition["sound_path"],
             "hypnosis": {"message": 0x481, "refresh_seconds": 1.0, "speed": 2.0,
                          "stop_distance": 2.0, "stop_delay_seconds": .2,
                          "zone_export_id": 544, "zones": hypnotized,
                          "start_animation": "hypnos1", "idle_animation": "hypnos2", "walk_animation": "walk2",
                          "entry_states": ["lookafter"],
                          "excluded_state": "lookafter_timed"},
             "notes": {"sheet_index": 8, "dav_export_id": 209, "frames": notes,
                       "life_seconds": 4.0, "interval_seconds": 2730 / 4096,
                       "h_speed": 1.0, "v_speed": .75, "size_start": .06, "size_end": .4,
                       "origin_forward": .6, "origin_up": 1.1, "origin_jitter": .1}}
    data_dir = ROOT / "assets/levels/lvl_04/data"
    data_dir.mkdir(parents=True, exist_ok=True)
    (data_dir / "flute.json").write_text(json.dumps(rules, ensure_ascii=False, indent=2), encoding="utf8")
    # Shared defaults contain no map coordinates. Each level supplies its
    # own Sam zone; laboratory and future item fixtures reuse these defaults.
    shared = json.loads(json.dumps(rules))
    for key in ["resource", "model", "sam_resource"]: shared.pop(key, None)
    shared["hypnosis"]["zones"] = []
    shared["hypnosis"].pop("zone_export_id", None)
    (base / "rules.json").write_text(json.dumps(shared, ensure_ascii=False, indent=2), encoding="utf8")
    snd = next(folder.glob("*.[sS][nN][dD]")).read_bytes()
    at = 12
    found = False
    for _ in range(struct.unpack_from("<I", snd, 8)[0]):
        identity, size, _flags = struct.unpack_from("<III", snd, at)
        if identity == 37:
            (base / "flute_tune.wav").write_bytes(snd[at+12:at+12+size])
            found = True
        at += 12 + size
    assert found, "Native flute tune 37 missing"
    assert all(clip["original_name"] == source for source, alias in
               [("flute1", "flute_idle"), ("walkf1", "flute_walk"), ("standf1", "flute_fidget"), ("punch6", "bull_death")]
               for clip in [player_animations[alias]])
    print("Flute: entity", flute_entity, "model", model, "joint 18; Wolf",
          [(k, v["original_name"], v["duration"]) for k, v in player_animations.items()])


if __name__ == "__main__":
    extract(*sys.argv[1:3])
