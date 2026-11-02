# Puertas y efectos animados del plató

El modelo APORTE01 tiene su base enY0. Las posiciones de DoorLevel del WAR
incluyen pequeños desplazamientos artísticos: la puerta de lvl_07 estaba aY0.31
con suelo a-0.01597. OriginalStudio ajusta las puertas a la colisión real mediante
un rayo local después de dos frames de física, con margen0.005m. Conserva X/Z,
rotación y el escenario elevado del bonus (lvl_05, suelo a3.104m).
Se aplica tanto a portales de niveles importados como a puertas decorativas.
No se eliminan colisiones del plató ni se desplaza su escenografía.

DoorLevel::Update solo usa las animaciones de apertura/cierre de APORTE01;
la nieve y los efectos ambientales de cada decorado pertenecen a texturas DAV.
Scene.WAR declara cuatro listas de scroll en su cabecera0x83:393/397/369/412,
rectángulos de páginas2/5/12/14. `tools/extract_texture_scroll.py DECOMP Scene`
los importa sin recrear los sprites. OriginalTextureScroll aplica el movimiento
nativo de una fila por tick60Hz dentro de cada región, con materiales locales.
El controlador compartido admite ahora escenas sin effects.json ni emisores de río.

Pruebas: test_studio_door_ground_and_effects.gd verifica las ocho puertas
jugables, el pedestal elevado, los cuatro rectángulos, cambios reales de píxeles
y su conexión a materiales. Captura OpenGL:validation/studio_snow_door.png.
También pasó test_studio_progress.gd (guardado, desbloqueo y retorno al plató).
