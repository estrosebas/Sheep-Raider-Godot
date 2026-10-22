"""Write an editor-visible foundation scene from its native level manifest."""
from pathlib import Path
import json,sys
root=Path(__file__).resolve().parents[1]
slug=sys.argv[1];identity=slug.removeprefix('lvl_');base=f'res://assets/levels/{slug}'
manifest=json.loads((root/'assets/levels'/slug/'data/manifest.json').read_text(encoding='utf8'))
x,y,z=manifest['spawn']['pos']
background_path=root/'assets/levels'/slug/'data/background.json'
background_data=json.loads(background_path.read_text(encoding='utf8')) if background_path.exists() else {}
background=background_data.get('render_clear_rgb',background_data.get('pc_clear_rgb'))
background_color=','.join(str(channel/255.0) for channel in background) if background else '0.52,0.66,0.82'
scene=f'''[gd_scene load_steps=6 format=3]
[ext_resource type="Script" path="res://scripts/levels/imported_level.gd" id="1"]
[ext_resource type="PackedScene" path="res://scenes/characters/Ralph.tscn" id="2"]
[ext_resource type="Shape3D" path="{base}/collision.tres" id="3"]
[ext_resource type="ArrayMesh" path="{base}/scenery.tres" id="4"]
[sub_resource type="Environment" id="environment"]
background_mode = 1
background_color = Color({background_color},1)
tonemap_mode = 0
[node name="Level{identity}" type="Node3D"]
script = ExtResource("1")
asset_directory = "{base}"
foundation_mode = true
[node name="WorldEnvironment" type="WorldEnvironment" parent="."]
environment = SubResource("environment")
[node name="Scenery" type="MeshInstance3D" parent="."]
mesh = ExtResource("4")
[node name="Collision" type="StaticBody3D" parent="."]
collision_layer = 3
[node name="CollisionShape3D" type="CollisionShape3D" parent="Collision"]
shape = ExtResource("3")
[node name="Player" parent="." instance=ExtResource("2")]
position = Vector3({x},{y},{-z})
[node name="BGMPlayer" type="AudioStreamPlayer" parent="."]
[node name="HUD" type="CanvasLayer" parent="."]
[node name="Label" type="Label" parent="HUD"]
offset_left = 24.0
offset_top = 24.0
text = "NIVEL {identity} · F8: Laboratorio · H: Ayuda · Escape: Pausa"
'''
(root/'scenes/levels'/f'Level{identity}.tscn').write_text(scene,encoding='utf8')
