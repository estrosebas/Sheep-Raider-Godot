# Catálogo de secuencias y cámaras

camera_catalog.json es configuración del port; no modifica pistas/IDs extraídos
del juego. OriginalCameraCatalog resuelve la ruta canónica aunque cambie idioma.

| kind | Uso | Círculo por defecto |
|---|---|---|
| intro_cinematic | Presentación de nivel/personajes | Sólo si return_transition lo indica |
| camera_animation | Barrido/recorrido de cámara sin obligación de diálogo | Sólo si return_transition lo indica |
| tutorial_cinematic | Explicación o demostración dentro del nivel | none |
| interaction_camera | Encuadre temporal de un objeto, como buzón | none |
| camera_focus | Visor/telescopio mantenido por el jugador | none |
| death_camera | Plano de muerte | Lo gestiona el respawn existente |
| menu_camera | Idioma u otro menú de escena | Lo gestiona el menú existente |

Tipo y transición son independientes. OriginalSequence y OriginalLevelSequence
exponen camera_kind y return_transition en el inspector (automatic usa catálogo).
Para una animación de cámara que deba abrir el círculo, se puede poner:

```json
{"kind":"camera_animation","return_transition":"iris"}
```

`none` restaura la cámara y controles normales; `iris` restaura primero la
cámara y física del jugador y luego abre OriginalRestartFade por un segundo.
También funciona cuando se salta la secuencia. No se abre un círculo en todas
las cámaras por inferirlo de su tipo. Una ruta desconocida cae en
camera_animation/none, para evitar transiciones inesperadas.

## Secuencias importadas actuales

| ID del catálogo | Nivel | CIN | Tipo | Al terminar |
|---|---|---:|---|---|
| lvl00_anvil_intro | 00 | 1 | intro_cinematic | none |
| lvl00_follow_camera | 00 | 5 | camera_animation | none |
| lvl00_platform_demo | 00 | 3 | tutorial_cinematic | none |
| lvl01_intro_camera | 01 | 0 | camera_animation | encadena lvl01_daffy_intro |
| lvl01_daffy_intro | 01 | 4 | intro_cinematic | iris |
| lvl01_porky_without_sheep | 01 | 2 | tutorial_cinematic | none |
| lvl01_porky_with_sheep | 01 | 3 | tutorial_cinematic | none |
| lvl02_bush_demo | 02 | 1 | tutorial_cinematic | none |
| lvl02_bush_rules | 02 | 2 | tutorial_cinematic | none |
| lvl03_intro_camera | 03 | 2 | intro_cinematic | iris |
| lvl03_rock_cover_demo | 03 | 0 | tutorial_cinematic | none |
| lvl03_rock_cover_rules | 03 | 3 | tutorial_cinematic | none |
| lvl03_rock_first_camera | 03 | 4 | camera_animation | none |
| lvl03_rock_second_camera | 03 | 1 | camera_animation | none |
| lvl03_stone_camera | 03 | 5 | camera_animation | none |
| lvl03_panorama_camera | 03 | 6 | camera_animation | none |

La intro de Lucas del 02 se dispara tras la roca, durante el juego: no pertenece
a la entrada por la puerta y no abre un círculo. Las cámaras procedurales
(buzones, telescopio, muerte y rueda de idioma) se documentan en procedural_cameras;
mantienen sus controladores y transiciones propios, no se convierten en CIN.

## Añadir un nivel

1. Registrar cada secuencia con ID legible, source, cine_id, kind y
   return_transition. next enlaza por ID estable, no por números dispersos.
2. Para una entrada, añadir en entries la asset_directory y el nombre del nodo
   director, junto a first y last. El director debe exponer movies y start_movie.
3. Los miembros intermedios de la cadena usan none; sólo el último usa iris.
4. Sin perfil de entrada, EntryController abre el círculo directamente. Si la
   última secuencia ya fue completada, no reproduce de nuevo la introducción.

Ejemplo de perfil:

```json
"res://assets/levels/lvl_03": {
  "director":"DaffyLessons", "first":"lvl03_overview", "last":"lvl03_intro"
}
```

No se requiere copiar OriginalLevelEntry ni añadir una comprobación de clase
por nivel. El nivel nuevo aporta sus assets y su director/activadores específicos.
