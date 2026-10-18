# Primer bloque de Lucas: cámara en tercera persona

## Original recuperado

La función `DaffyTrainingLevel::Update` (`src/objects/daffytraininglevel.cpp`, modo IDLE) calcula la dirección de Lucas desde la cámara y exige que permanezca cerca de esa dirección durante `0x1000` ticks: **un segundo**. Los tags `$LOCK$` y `$VIEW$` controlan el bloqueo y la espera por mirada. La adaptación mantiene ese segundo, sustituyendo los límites angulares y la vista interna por una consulta física desde la cámara normal.

La secuencia que sigue a la intro es **CIN 5**, de 13.968 s, con la voz 80. También está recuperada del WAR y se reproduce antes de las ayudas. Mantiene sus posiciones, rotaciones, clips y cámara originales; E permite continuarla, como permiten sus flags. La intro CIN 1 sigue sin aceptar salto por defecto.

`extract_camera_training.py` lee el MLT original: encabezado/CRC, siete idiomas, 34 listas; español en bloque 2 y la lista de clase 22 en índice 23. Recupera los cuatro primeros slots de `g_trainingHelpProps`:

| Slot / texto | Ruta original | Gait | Voz BSV |
|---|---|---|---|
| 0 / TEXT_3 (23): introducción a cámara | 611, tres nodos | 2, HIDE2 | 88, `txt_lvl_002.wav` |
| 1 / TEXT_2 (20): Lucas detrás | 614, dos nodos | 3, warp | 89, `txt_lvl_003.wav` |
| 2 / TEXT_1 (21): esconderse arriba | 612, tres nodos | 2, HIDE2 | 91, `txt_lvl_005.wav` |
| 3 / TEXT00 (22): felicitación | 613, tres nodos | 2, HIDE2 | 90, `txt_lvl_004.wav` |

La voz 80 del seguimiento inicial es **`txt_lvl_001.wav`**, «¡Oh, no ha funcionado demasiado bien!». `StreamPlayer::PlayVoice` (0x563940, `src/engine/stream_player.cpp:248`) usa **`clipNames[currentClip - 1]`**: las voces empiezan en ID 1. El primer extractor había usado `names[ID]`, desplazando todas las voces una entrada; queda corregido y probado. La voz de la carrera, ID **81**, es **`txt_lvl_0010.wav`** y corresponde al slot 11 / texto 9, más adelante.

Los nombres se resuelven desde `References/MusicVoice.BSV`; las 16 muestras españolas del tutorial se copian sin alterar sus bytes. El manifest conserva los 20 slots originales en `tutorial_voice_catalog`, incluyendo los slots sin voz (ID 0), para conectar futuras lecciones sin adivinar archivos. Los textos originales, cajas, tipos y puntos también se conservan en `assets/cinematics/camera_training/lessons.json`. Este ajuste no se aplica a los efectos SND ni al índice de música: usan mecanismos distintos.

| Momento posterior | Voz / archivo original |
|---|---|
| Salto | 92 / `txt_lvl_006.wav` |
| Doble salto | 93 / `txt_lvl_007.wav` |
| Broma sobre volar | 94 / `txt_lvl_008.wav` |
| Respuesta a la broma | 95 / `txt_lvl_009.wav` |
| Carrera | 81 / `txt_lvl_0010.wav` |
| Reintentar carrera | 82 / `txt_lvl_0011.wav` |
| Carrera superada | 83 / `txt_lvl_0012.wav` |
| Ovejas / objetos / columpios | 84 / `txt_lvl_0013.wav` |
| Inventario y buzones | 85 / `txt_lvl_0014.wav` |
| Cohete | 86 / `txt_lvl_0015.wav` |
| Llegada con ovejas | 87 / `txt_lvl_0016.wav` |

La ruta elevada termina en coordenadas Godot `(-57.02,7.34,46.43)`. Para los primeros saltos, `MoveTo` reproduce HIDE2, mantiene X/Z, interpola altura y cambia al nodo al finalizar el clip; también ajusta al suelo. La adaptación conserva ese comportamiento de las rutas tempranas.

## Cambios solicitados

- Después de la explicación, girar la cámara con el **ratón**, encontrar a Lucas detrás y mantenerlo en el centro un segundo.
- Lucas sigue su ruta original para esconderse arriba. Apuntarlo otro segundo con la cámara normal activa su felicitación.
- La línea que ordenaba mantener pulsada la vista interna se sustituye por una instrucción escrita de apuntar con la cámara. Su voz original 91 está archivada pero **no se reproduce**, para evitar que el audio pida una acción que ya no existe. Las voces compatibles se mantienen originales; no se ha generado un doblaje nuevo.
- Se bloquean caminar, saltar e inventario durante las ayudas, pero el ratón continúa funcionando. E avanza cada explicación. Al terminar se restaura el movimiento y Lucas vuelve por su ruta original.

`CameraFocusProbe` es reutilizable: raycast de hasta 50 m, desde `Camera3D.get_camera_transform()` en su dirección frontal. Incluye los offsets reales de cámara ([API Camera3D](https://docs.godotengine.org/en/4.7/classes/class_camera3d.html)). Ignora el cuerpo de Ralph y acepta el área de mirada de Lucas en capa 9. El suelo/paredes permanecen en la consulta: si algo bloquea el rayo, no progresa. Desviar la mirada reinicia el segundo acumulado.

Durante estas lecciones se desplaza la cámara 0.8 m lateralmente para que Ralph no tape a Lucas en el centro. El offset se restaura al terminar. La inclinación máxima superior pasa a 65° para permitir mirar el techo, y el SpringArm excluye a Ralph y usa una esfera de protección de 0.2 m para no pegar la cámara al suelo.

`DaffyCameraTraining` coordina las voces, texto adaptado, HIDE2, rutas y esperas por mirada. `OriginalSequence` cambia a CIN 5 reutilizando los actores. Los assets de Lucas incluyen ahora TALK1, WALK1, STAND1A y HIDE2, además de los clips de la intro. El círculo alrededor del centro indica el segundo de mirada acumulado; solo aparece en las dos esperas.

## Verificación y límite del bloque

- `tools/test_camera_training.gd`: enlace CIN 1→5→ayudas, voz española, bloqueo parcial, giro del ratón, detección real, pérdida de mirada, pared que bloquea, ruta elevada, detección con la cámara normal del personaje y restauración al terminar.
- `extract_camera_training.py ... --verify`: datos MLT/WAR y muestras BSV/WAV sin diferencias con el original.
- `extract_tutorial_intro.py ... --verify`: secuencias y recursos de CIN 1/CIN 5 contrastados con WAR/DAV/SND.
- Capturas GPU: `training_follow.png`, `training_camera_dialogue.png`, `training_camera_focus.png`, `training_roof_focus.png`.

Este documento describe las cuatro primeras ayudas de cámara. El recorrido posterior de salto, doble salto, carrera y checkpoints ya está enlazado: ver [tutorial_progression.md](tutorial_progression.md). La UI de subtítulos usa la fuente y panel del port, no la fuente bitmap original; TALK1 acompaña las voces, sin replicar todavía el análisis de amplitud del motor original.
