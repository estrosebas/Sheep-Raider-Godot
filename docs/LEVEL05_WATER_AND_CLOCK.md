# Nivel05: agua y ubicación del reloj (22/10/2026)

Revisión del WAR/DAV/SND de PC y del código decompilado. Los assets PS1
extraídos disponibles en la ruta proporcionada contienen solamente INTRO;
no se presenta esta inspección como una comparación visual confirmada de PS1.

## Agua

**Corrección de la revisión inicial:** los rayos contra el escenario no
bastaban para explicar el fondo visible del original. La captura aportada
por el usuario llevó a revisar también la configuración de renderizado.

`WarHeader.clearR/G/B`, bytes8..10 del WAR05, contiene `[48,40,64]`.
`src/engine/list.cpp::Load_DAVnWAR` divide los canales por2 y configura
`PolyBatcher::SetClearColor` y `Frustrum::SetFogColor` con `[24,20,32]`,
hexadecimal `#181420`. El port había puesto el azul genérico
`Color(.52,.66,.82)` en todas las escenas de base. Ese azul se veía por
las aberturas del escenario y a través del agua, en lugar del fondo violeta
oscuro original.

**Ajuste posterior al revisar los materiales:** no se puede usar ese valorPC
reducido con el shader actual de color de vértice, que conserva el RGB de
fuente como el visor del repositorio. Hay1698 vértices del escenario bajo
Y=0 cuyo color original es exactamente `[48,40,64]`: las franjas de río
terminan en ese color. Poner detrás `[24,20,32]` crea una silueta oscura
con aspecto de agujero. `render_clear_rgb` ahora usa `[48,40,64]` (`#302840`)
para coincidir con el degradado; `pc_clear_rgb` conserva `[24,20,32]` como
dato nativo documentado, sin mezclar ambas convenciones.

El agua combina superficies opacas sin textura con degradado Gouraud y
olas/espuma en DAV página10, formato0x12 (ARGB4444, aditivo). El motorPC
mezcla esa página con INVSRCALPHA/ONE y filtrado lineal. La extracción
invierte alfa para el SRCALPHA/ONE de Godot; el shader retro_add conserva
esa mezcla. No se encontró un material PBR ni una imagen de suelo que
faltase asignar. Los filtros nearest/linear siguen disponibles en el perfil
de texturas existente.

Se recuperó `data/background.json` con los bytes originales y el colorPC,
se actualizó Level05.tscn para el editor, y ImportedLevel restaura el fondo
desde datos al ejecutar. Los extractores de próximos niveles conservan
ahora esa configuración. Los demás niveles existentes no se reimportan
ni cambian en esta corrección.

El WAR contiene76 recursos de geometría tipo3 y4 de cielo tipo38, todos
incluidos en la extracción. También se inspeccionó el recurso170 tipo0x27:
es una pieza de8 triángulos en el planoXY con Z=0, no el lecho del río.
Load_WarMeshes no lo instala como una malla de mundo. No se agregó como
suelo ni se inventó una colisión para cubrir el fondo.

Comprobación de triángulos originales proyectados a XZ (sin depender del
culling o de las colisiones): en el centro del río cerca del inicio
X=2,08/Z=-8,22, y en los canales X=36,34/Z=-17,19 y X=-49,80/Z=-22,46,
no hay triángulo de escenario bajo la superficie. Esa prueba confirma
aberturas en esos puntos, pero **no** que el juego original careciera de
un fondo visual: el clear color se dibuja precisamente detrás de ellas.

El motor original de PC sí implementa `Camera_UpdateUnderwater`, en
`src/objects/camera.cpp:3179`: evalúa la posición de la cámara dentro de
los volúmenes, dibuja el bitmap `DAV_IDI_IGLALFA_` como filtro de pantalla
y reproduce en bucle `SND_UNDERWATER`128. El color proviene de
FogManager::PostLoadInit, propiedad24, y se escala por2,8 con tope160 por
canal en Camera_InitUnderwaterOverlay. FogManager115 del05 guarda
`g_waterColor=0x14141e`.

En el port, OriginalWaterMotion controla inmersión y nado de Ralph, pero
no existe ese filtro/ambiente dependiente de la posición de la cámara.
Además los shaders retro actuales desactivan fog, y la cámara libre permite
ver ángulos que el encuadre original restringía. Falta adaptar esos efectos;
la corrección del fondo no agrega un suelo inventado ni cambia la natación.

Capturas con idéntica cámara/escenario, cambiando sólo el fondo:
`validation/level05_river_material_before.png` (fondoPC reducido con
materialesRGB completos) y `validation/level05_river_material_after.png`
(color coherente con el degradado original). Reproducibles con
`tools/capture_level05_river_background.gd`. Importación del color:
`python tools/extract_level_background.py ORIGINAL_LEVEL_FOLDER`.

## Reloj

TimeKeeper61, modelo40. Posición original convertida a Godot:
`(7.83,-3.95,-24.88)`m. El controlador lo apoya en el suelo nativo Y=-3,99m.
Está en un pequeño recinto bajo la repisa cercana al toro60, no sobre
la zona de hojas. Se confirmó visualmente su modelo y suelo desde dentro.

Capturas reales OpenGL con marcadores de ubicación (no son montajes):

- `validation/level05_clock_location.png`: vista general, amarillo=reloj,
  naranja=toro, cian=posición de inicio.
- `validation/level05_clock_close.png`: reloj dentro de su recinto.

Generación reproducible: Godot con `--path . --rendering-method gl_compatibility
--script tools/capture_level05_clock.gd`. Se usan datos de prueba en memoria,
sin modificar partidas reales ni mover el reloj en la escena de juego.
