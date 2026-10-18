# Guardado manual y pausa

**Escape** abre/cierra el menú y pausa el árbol completo: física, animaciones, Lucas, cronómetro de carrera y entregas. Se conserva la acción en curso al continuar. Flechas/W/S seleccionan; Enter/E/Espacio aceptan. La pausa está disponible también en animaciones del tutorial.

## Archivos de partida

- Tres ranuras manuales: **Guardar → Ranura 1/2/3**. No se escribe nada al iniciar, alcanzar un checkpoint, morir, consumir el cohete o terminar el nivel.
- Alcanzar un checkpoint genera únicamente una instantánea en memoria. Guardar escribe esa instantánea: posición de reaparición original, índice y checkpoints alcanzados, etapa/postura de Lucas, inventario comprometido, buzón, objetos disponibles, piedras y plataformas/puerta del puzzle. No se captura la posición al pulsar Guardar ni los objetos/progreso posteriores al checkpoint.
- No se permite guardar antes del primer checkpoint. Sobrescribir una ranura, reiniciar o salir requieren confirmación dentro del menú.
- **Cargar → Ranura → Continuar desde checkpoint / Reiniciar nivel**. Cargar crea una escena nueva y aplica el estado; reiniciar crea una escena limpia sin borrar ni sobrescribir la ranura. En una nueva ejecución con archivos existentes se muestra la selección de carga.
- Se restaura con manos vacías y fundido de entrada; se retoma la etapa del tutorial en el checkpoint. Una conversación se reinicia desde su ayuda completa, no desde una sílaba ni una pose intermedia. No se reproducen acciones/cajas posteriores al checkpoint ni se duplica el contenido de un buzón comprometido.
- Formato JSON versionado, payload con SHA-256, validación de estructura y vectores. Escritura mediante `.tmp` y reemplazo manteniendo `.bak` de la versión anterior. Un archivo inválido aparece como ranura vacía/no válida; nunca se ejecuta código de la partida. El checksum detecta corrupción, no pretende impedir edición deliberada.
- Ubicación Godot: `user://saves/slot_1.json`, etc. En este proyecto Windows corresponde a `%APPDATA%/Godot/app_userdata/Ralph Wolf - Sheep Raider Native/saves/`.

`SaveFiles` maneja archivos/ranuras; `LevelCheckpointSave` adapta el estado del nivel 00. Los futuros niveles deberán suministrar su propia captura/restauración y ampliar el registro de niveles; no se anuncia compatibilidad con mapas aún no porteados.

## Menú original

Fuentes: `sdw-decomp/src/engine/pause_menu.cpp`, `src/objects/menu.cpp`, `src/engine/text.cpp` y `src/engine/list.cpp`.

- La textura de letras es el **DAV_IDI_IGLTYPO_ 36** real del Lvl-00.DAV, atlas 256×224. `Font_LoadFromRes` divide en celdas 16×16; `Font_CloneResized(FONT_GAME,FONT_GAME_SMALL,10,12)` dibuja letras con avance 9, alto 13 y fila 17. `tools/extract_pause_ui.py --verify` compara píxeles RGBA con el DAV original.
- El fondo de pausa del original no es una imagen almacenada: `Menu_CreateNoiseTexture` crea 256×256 de ruido ARGB4444 azul con alfa 6..9, y `PauseMenu_DrawNoiseOverlay` lo repite por toda la pantalla con gris 0xc0c0c0. Se reproduce esa generación en Godot, visible sobre la escena congelada.
- Se conserva menú centrado, título/ayuda, tipografía y tintes originales, con **Guardar/Cargar** incorporados. Opciones del port: música, pantalla completa, perfil de texturas y mostrar controles. No se portan en este hito los submenús completos de audio DirectSound, mandos Win32 o configuración de niebla del ejecutable original.
- Salir del nivel lleva a una pantalla de selección con cargar, comenzar nivel 00 o salir del juego. No hay guardado automático al salir.

## Verificación

`tools/test_save_files.gd`: guardar antes del checkpoint rechazado, checkpoint sin escritura automática, instantánea independiente del estado actual, ranuras separadas, sobrescritura, corruptos y campos ausentes, restauración en una escena fresca con inventario/buzón/Lucas, Escape real, congelación de animaciones, oferta de carga al volver, rutas reales de Cargar/Reiniciar mediante `reload_current_scene`, y reinicio que conserva el archivo manual: **0 fallos**. Usa un directorio temporal de pruebas y no toca ranuras del jugador.

El tutorial de cámara y la entrega física de la oveja hasta la meta también pasan. Menú revisado en render GPU: [pausa](pause_original_font.png), [ranuras](pause_save_slots.png).

Corrección de resaltado/sonidos: la fila seleccionada usa `Text_BlinkButtonGlyphs`, tablas `s_glyphVariantFwdTable/RevTable` originales extraídas de `text.cpp`, con tres fases de **62 ms** (variantes adelante, atrás, base). La vibración cambia el dibujo real de las letras del atlas; no desplaza el renglón con ruido inventado. `prompt.cpp` aporta los sonidos originales **SGLCHGLI 90** (mover), **SBONMBTN 54** (aceptar) y **SMOJPMOV 62** (volver), recuperados byte a byte de Lvl-00.SND. Siguen funcionando durante pausa gracias al reproductor del menú. El extractor verifica tablas, fuente, marco y WAV; `test_save_files` verifica las tres fases y los sonidos al abrir/mover.

Carteles adaptados a solo lectura: `OriginalTextBox` replica `Ui_DrawSubtitleBox` con rectángulo **(50,50,412,140)**, relleno 0x080808, fuente **FONT_GAME** y cuatro tiras de marco **DAV_IDI_IGLCADP_ 21**. E cierra, A/D no decide; la antigua pregunta se sustituye por la advertencia original. Se elimina el disparo del yunque desde la confirmación del cartel, por lo que no puede volver a encadenar preguntas y yunques. La intro del nivel conserva su yunque cinematográfico. También se corrigió la salida de la reacción heredada para no reabrir la pregunta si otro código la invoca. `test_sky_signs` verifica leer/cerrar/releer los tres carteles sin decisiones, caída de yunques ni bloqueo de controles; **0 fallos**. [Cuadro original](sign_original_textbox.png).

Transparencia del cuadro: `Ui_DrawPanelFill` no carga un fondo desde DAV; pinta una textura temporal 4×4 con alfa ARGB4444 **0x8** y mezcla invertida. Se replica como negro de opacidad **7/15 ≈ 46.7 %**, manteniendo marco y letras opacos. La captura GPU confirma que se ve el escenario detrás del texto.
