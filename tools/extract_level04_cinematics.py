"""Adapt Lv04's DaffyElf metadata after the shared WAR cinematic extraction.

python tools/extract_level04_cinematics.py ORIGINAL_LEVEL_FOLDER
No geometry or camera keyframes are invented: the common extractor owns those.
"""
import json
import struct
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def main():
    folder = Path(sys.argv[1])
    base = ROOT / "assets/levels/lvl_04"
    war = next(folder.glob("*.[wW][aA][rR]")).read_bytes()
    table = struct.unpack_from("<%dI" % struct.unpack_from("<I", war, 12)[0], war, 16)
    at = next(entry & 0xFFFFFF for entry in table if entry >> 24 == 0x82)
    count = struct.unpack_from("<I", war, at)[0]
    at += 4
    external = {}
    for _ in range(count):
        identity, length = struct.unpack_from("<HH", war, at)
        external[identity] = struct.unpack_from("<%dI" % length, war, at + 4)
        at += 4 + length * 4

    def boxes(identity):
        return [dict(flags=values[0], min=list(values[1:4]), max=list(values[4:]))
                for pointer in external.get(identity, [])
                for values in [struct.unpack_from("<I6h", war, pointer)]]

    def read(path):
        return json.loads(path.read_text(encoding="utf8"))

    def save(path, data):
        path.write_text(json.dumps(data, ensure_ascii=False, separators=(",", ":")), encoding="utf8")

    elf = next(entity for entity in read(base / "data/entities.json") if entity["class_id"] == 55)
    props = elf["props"]
    texts = read(ROOT / "assets/localization/levels/lvl_04/es.json")["lists"][56]
    languages = read(ROOT / "assets/localization/manifest.json")
    voices = languages["languages"]["es"]["voices"]
    # DaffyElf::PostLoadInit (0x4361bb): answer voices 0x35 and 0x0b.
    first = props["0x4"]
    data = dict(resource=elf["res"], source_level="lvl_04", variant="flute_elf",
                cine_id=props["0x8"], cine_flags=props["0x10"],
                trigger=boxes(props["0xc"]), sheep=boxes(props["0x14"]),
                text_list=56, text_index=props["0x18"], question=texts[first],
                answers=[dict(choice=texts[first+1+i*2], text=texts[first+2+i*2],
                              voice_id=identity, voice_path=voices[str(identity)])
                         for i, identity in enumerate([53, 11][:props["0x0"]])],
                calling_sound_id=37, interaction_distance=2.0,
                # The common conversation's localization contract expects this
                # slot. DaffyElf does not implement the burnt exchange.
                burnt={"text": "", "voice_path": ""},
                source_functions=["DaffyElf::PostLoadInit", "DaffyElf::Update", "DaffyElf::SetState"])
    save(base / "data/daffy.json", data)
    sequence_path = base / "cinematics" / ("sequence_%d.json" % data["cine_id"])
    sequence = read(sequence_path)
    sequence["text"] = texts[data["text_index"]]
    sequence["trigger"] = data["trigger"][0]
    save(sequence_path, sequence)

    # Remove the former COME1 -> tune37 inference: DaffyElf::Update only
    # calls Sound_Play37 in WATCH, after Cine_IsFinished, never in a movie.
    for path in (base / "cinematics").glob("sequence_*.json"):
        cinematic = read(path)
        cinematic.pop("elf_flute_windows", None)
        save(path, cinematic)

    # Unlike Lv03, Lv04's manager plays CIN1; the Elf owns CIN2.
    audit_path = base / "data/import_audit.json"
    audit = read(audit_path)
    audit.update(intro_cine_id=1, tutorial_cine_ids=[data["cine_id"]],
                 implemented_exclusive_classes=[41, 43, 50, 52, 54, 55, 191],
                 pending_exclusive_classes=[53, 162, 184],
                 cinematic_symbols={"1": "INTRO", str(data["cine_id"]): "DAFFY_ELF_FLUTE"},
                 cinematic_descriptors={
                     "1": {"name": "intro_camera", "description": "Recorrido de entrada del nivel 04"},
                     str(data["cine_id"]): {"name": "flute_lesson", "description": "Lucas, el elfo y la flauta mágica"}})
    save(audit_path, audit)
    assert sequence["voice_id"] == 52, "The native Elf lesson must use CINFL_LVL0401"
    print("Lv04: manager CIN1, Elf CIN%d, voices 52 / 53 / 11, native MLT56" % data["cine_id"])


if __name__ == "__main__":
    main()
