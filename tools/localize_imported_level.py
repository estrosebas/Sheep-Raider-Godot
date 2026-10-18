"""Register only a newly imported level's localized data; preserve existing overlays."""
import json,sys
from pathlib import Path
root=Path(__file__).resolve().parents[1]; slug=sys.argv[1]
path=root/'assets/localization/manifest.json'; manifest=json.loads(path.read_text(encoding='utf8'))
banks={locale:json.loads((root/'assets/localization/levels'/slug/(locale+'.json')).read_text(encoding='utf8'))['lists'] for locale in manifest['languages']}
indexes={}
for i,strings in enumerate(banks['es']):
    for j,text in enumerate(strings):
        if text:indexes.setdefault(text,(i,j))
voice_ids={Path(value).name:key for key,value in manifest['languages']['es']['voices'].items()}
for source in list((root/'assets/levels'/slug/'data').glob('*.json'))+list((root/'assets/levels'/slug/'cinematics').glob('sequence_*.json')):
    if source.stat().st_size>300000:continue
    value=json.loads(source.read_text(encoding='utf8')); resource='res://'+source.relative_to(root).as_posix(); variants={}
    for locale,bank in banks.items():
        changed=[False]
        def translate(value):
            if isinstance(value,dict):return {k:translate(v) for k,v in value.items()}
            if isinstance(value,list):return [translate(v) for v in value]
            if not isinstance(value,str):return value
            if value in indexes:
                i,j=indexes[value]; changed[0]=True; return bank[i][j]
            if '/voices/' in value and Path(value).name in voice_ids:
                changed[0]=True;return manifest['languages'][locale]['voices'][voice_ids[Path(value).name]]
            return value
        translated=translate(value)
        if changed[0]:
            destination=root/'assets/localization/overlays'/slug/locale/source.name;destination.parent.mkdir(parents=True,exist_ok=True)
            destination.write_text(json.dumps(translated,ensure_ascii=False,separators=(',',':')),encoding='utf8');variants[locale]='res://'+destination.relative_to(root).as_posix()
    if variants:manifest['files'][resource]=variants
path.write_text(json.dumps(manifest,ensure_ascii=False,separators=(',',':')),encoding='utf8')
catalog_path=root/'assets/cinematics/camera_catalog.json';catalog=json.loads(catalog_path.read_text(encoding='utf8'))
audit=json.loads((root/'assets/levels'/slug/'data/import_audit.json').read_text())
names={0:'rock_cover_demo',1:'rock_second_camera',2:'intro_camera',3:'rock_cover_rules',4:'rock_first_camera',5:'stone_camera',6:'panorama_camera'}
intro_id=audit.get('intro_cine_id')
tutorial_ids=audit.get('tutorial_cine_ids',[])
descriptors=audit.get('cinematic_descriptors',{})
entry_name=None
for sequence in audit['sequences']:
    identity=sequence['cine_id']
    descriptor=descriptors.get(str(identity),{})
    # Lv03's existing names remain stable, while subsequent WARs may number
    # intro and tutorial movies differently (Lv04 uses CIN1 and CIN2).
    short_name=descriptor.get('name',names.get(identity,'sequence_%d'%identity) if slug=='lvl_03' else ('intro_camera' if identity==intro_id else 'sequence_%d'%identity))
    name=slug.replace('_','')+'_'+short_name
    intro=identity==intro_id; tutorial=identity in tutorial_ids
    catalog['sequences'][name]={'source':f'res://assets/levels/{slug}/cinematics/sequence_{identity}.json','level':slug,'cine_id':identity,
        'kind':'intro_cinematic' if intro else ('tutorial_cinematic' if tutorial else 'camera_animation'),
        'trigger':'level_entry' if intro else ('tutorial' if tutorial else 'world_trigger'),
        'return_transition':'iris' if intro else 'none','description':descriptor.get('description',short_name.replace('_',' '))}
    if intro: entry_name=name
if entry_name:
    catalog['entries']['res://assets/levels/'+slug]={'director':'LevelCinematics','first':entry_name,'last':entry_name}
catalog_path.write_text(json.dumps(catalog,ensure_ascii=False,indent=2)+'\n',encoding='utf8')
print('Localized',slug,'in',list(banks),'; registered',len(audit['sequences']),'camera sequences')
