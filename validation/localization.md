# Localización compartida

El arranque principal (F5) es `scenes/startup/LanguageWheel.tscn`. Reutiliza los modelos DAV/WAR de Wheel (DaffyWheel clase187/modelo1 y Scene_Wheel clase152/modelo2), PUSH y PUSH1/PUSH2; mantiene rotación del hueso1 y orden original english, Português, español, italiano. Izquierda/derecha o A/D seleccionan; Enter/E confirma y abre Level00. La cámara y los rótulos se adaptan al arranque del port; no se pretende reproducir todavía toda la transición cinematográfica del frontend original. F6 sigue ejecutando directamente la escena abierta con el último idioma guardado.

## Datos y carga

- `assets/localization/manifest.json`: idiomas, config_id original, bloque MLT, voces por ID BSV, bancos por nivel y rutas de overlays localizados. Todo usa res://; no necesita los directorios originales al jugar/exportar.
- `GameLocalization`: preferencia global en user://language.cfg, independiente de las partidas/checkpoints. Valor inicial español si no existe preferencia. Configura también TranslationServer.locale. Selección anterior al montaje del nivel, sin duplicar escenas ni sus mecánicas.
- `GameLocalization.load_data(path)`: resuelve el overlay de datos según idioma, con fallback español; conservar el path común de la escena.
- `GameLocalization.text(level,list_id,index)`: acceso por índices originales del MLT. Ejemplo: text("lvl_01",34,0), pregunta de Lucas.
- `GameLocalization.voice_path(id)`: archivo original de Voices/<Language>, con IDs compartidos de MusicVoice.BSV. Ejemplo: 59, primera respuesta de Porky.
- `GameLocalization.ui(message)`: textos propios del port (controles adaptados, interacción, cantidades/mensajes, pausa y nombres de objetos), separados de los textos originales en `ui.json`.

Se extrajeron los bancos de texto de 23 carpetas originales, incluidas lvl_00..lvl_17; los 116 IDs de voz de BSV disponibles para cada uno de los cuatro idiomas; y ocho overlays usados por las escenas actuales. Los overlays solo cambian texto/voces: sky_signs, lessons, daffy, notes, porky, sequence_2/3/4. CIN00 no contiene texto/voz, de modo que mantiene su archivo común. Música y efectos SND siguen compartidos.

## Fuentes verificadas

- `jpeg_mlt.cpp::Mlt_MapLanguageToBlock`: en→1, es→2, it→3, pt_BR→6 (no asumir índices consecutivos).
- `stream_player.cpp::StreamPlayer::PlayVoice`: Voices/<Language>, clipNames[clip-1].
- `scene_wheel.cpp`: nombres, orden {0,3,1,2}, pasos π/2 y giro de joint1 X.
- `daffywheel.cpp`: PUSH inicial y alternancia PUSH1/PUSH2.
- Los bancos conservan `$tiempo$` y `$B_CONTROL$`; el UI adapta únicamente los botones del port. Las cinemáticas esperan la grabación de cada idioma si dura más que los tracks visuales.

## Añadir un nivel

Importar sus mecánicas una sola vez. Volver a ejecutar `python tools/extract_localization.py GAME` registra sus JSON de data/cinemáticas y las rutas por idioma; usar GameLocalization.load_data en cualquier consumidor nuevo. Los modelos, triggers, inventario y IA no contienen variantes por idioma. Usar text/voice_path por índice si el consumidor se construye directamente de props originales. Si se agregan mensajes propios del port, registrar sus cuatro traducciones en ui.json. El extractor no traduce ni genera voces.

Rueda: `python tools/extract_language_wheel.py DECOMP GAME`, importar recursos en Godot y ejecutar `tools/build_language_wheel.gd`.

## Validación

- `tools/extract_localization.py GAME --verify`: igualdad de JSON con MLT/BSV y de todos los WAV con sus bytes originales.
- `tools/test_localization.gd`: cuatro escenas reales, pregunta nativa MLT, notas, audio Lucas/Porky, voz CIN04, duración de grabación, desbloqueo tras escena, banco Level00, idioma inválido y persistencia de la rueda. 0 fallos.
- `tools/test_level01_porky_clock_and_blast.gd`, `tools/test_level00_closure.gd`, `tools/test_save_files.gd`: 0 fallos.
- Capturas GPU `original_language_wheel.png`, `level01_english_dialogue.png`.

## F5 durante el juego y escenario original

La rueda recupera ahora los GEOM colocados del WAR Wheel y sus páginas DAV para mostrar el estudio original. La cámara encuadra los límites evaluados de las poses PUSH finales de Lucas/rueda. Durante los 5,13 segundos de PUSH se respetan las claves originales del hueso1: el override de selección se aplica únicamente después; antes lo sustituía desde el fotograma cero y detenía el giro.

`LanguageMenu` es un autoload compartido: con foco en la ventana del juego, F5 abre un CanvasLayer/SubViewport con World3D independiente. Pausa el árbol, suspende input del nivel (incluido el menú Escape), conserva mouse/pausa anteriores y mantiene la instancia del nivel. No carga checkpoint, no reinicia ni teletransporta. Enter/E confirma y persiste; Escape/F5 cancela. Al volver, métodos reload_localization actualizan NPC, CIN, notas, carteles, tutorial, nombres de inventario y pausa; se conservan los objetos/estados existentes. Una cancelación sin cambio no reinicia texto/audio. Godot sigue usando F5 como Run cuando el foco está en el editor.

`tools/test_language_menu_modal.gd`: eventos de teclado reales F5/derecha/Escape, giro nativo durante PUSH, escenario original presente, confirmación, misma instancia/posición/cámara/inventario, nuevo texto/voz y cancelación. 0 fallos. `validation/language_startup_test.log`: arranque normal del proyecto con autoload, sin errores de script.

## Base, calibración de idioma, música y fundidos

- Soporte original: recurso10 del WAR Wheel, clase12 MiscStatic/modelo3. Su pose `PUSH` coloca el hueso1 a Z exportado -2,36 m; `Default` lo dejaba a un lado. Se recupera ese modelo y se muestra PUSH, conservando posición/yaw nativos. La rueda ahora cae sobre la base y su indicador amarillo queda debajo de la cara seleccionada.
- Calibración: en el atlas de la rueda, inglés ocupa +X local (page4, mitad inferior UV); portugués -Y (page4, mitad superior), español -X (page2) e italiano +Y (page3). El offset del port es -π/2 para alinear la cara con el indicador inferior del soporte; orden/IDs originales permanecen en,pt_BR,es,it. Las cuatro posiciones se verifican evaluando sus centros de geometría con las matrices reales, no comparando únicamente la función de ángulo contra sí misma.
- Música: `StreamPlayer::LoadLevelMusic/RestartLevelMusic` reduce los índices frontend/Wheel fuera de SCENE_LVL_00..17 a SCENE_LVL_00; g_levelMusicClip[0]=VOICE_JUNGLE_V1. Se copia Musics/Jungle_v1.wav directamente y se reproduce en bucle desde la rueda. La música del nivel conserva su pausa/reanudación y no se reinicia al cerrar.
- Fundidos del port: mismo `OriginalRestartFade` usado en muerte, 1 s hacia negro y 1 s para revelar. Se monta/desmonta la ventana debajo del negro; selección e input del nivel bloqueados durante la transición. También cubre el paso inicial de la rueda a Level00. La capa persistente300 permite completar la salida aunque se libere la escena del selector.
- `tools/test_language_menu_modal.gd`: música sonando/en bucle con árbol pausado, geometría de las cuatro banderas contra el indicador inferior, soporte PUSH, fade de entrada, misma partida y cancelación: 0 fallos.
- `tools/test_language_startup_transition.gd`: negro inicial, revelado, confirmación y llegada a Level00 bajo fundido: 0 fallos.
