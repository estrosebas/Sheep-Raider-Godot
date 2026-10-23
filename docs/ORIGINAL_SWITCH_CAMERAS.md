# Cámaras de las compuertas

Fuente: `FallingGate::PostLoadInit` y `FallingGate::HandleMessage`.
La propiedad 0x8 referencia un CamSetup: focal, tres ángulos y posición.
Los índices de modelo >=10 indican que se conserva la cámara hasta soltar
el interruptor. En nivel 05 los tres encuadres usan esa opción.

| Botón | Compuertas | CamSetup | Posición Godot |
|---|---|---|---|
| 48 | 66, 68 | 569 | (-56.34, 16.41, -25.75) |
| 53 | 69, 70 | 570 | (-52.89, 17.12, -1.38) |
| 54 | 72, 73 | 571 | (-41.23, 13.14, 11.76) |

Los datos se guardan en `switches.json`; dos compuertas vinculadas comparten
una cámara por botón, evitando que compitan por la vista. Posición, rotación
y focal proceden del WAR. Se usa la misma conversión CamSetup del buzón.

Adaptación a la cámara libre: la vista aparece mientras Ralph ocupa el botón.
Una oveja manteniendo un interruptor a distancia no roba la vista ni congela
a Ralph. Al apartarse se restaura la cámara anterior y su orientación.
Diálogos, otras cámaras y muertes interrumpen este encuadre.

La extracción genérica llama a `extract_switch_cameras.py`. También puede
ejecutarse de forma independiente con la carpeta original `Lvl-05`, sin
reimportar el mapa ni sobrescribir ajustes de sus mecanismos.

Validación: `tools/test_level05_switch_cameras.gd`, incluidos solapes reales
con los tres botones, activación de las seis compuertas, paso dentro del
frustum, restauración y prioridad de cámaras. Capturas opcionales con render
en `validation/level05_gate_camera_48.png`, `_53.png` y `_54.png`.
