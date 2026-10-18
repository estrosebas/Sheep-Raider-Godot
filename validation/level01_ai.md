# Nivel 01: música, Sam, rebaño y Lucas



Implementación basada en `sdw-decomp/src/objects/sam.cpp`, `sheep.cpp`, `daffylevel01.cpp`, `cinematicsmanager.cpp`, `src/engine/navigation.cpp`, `stream_player.cpp` y los WAR/DAV/SND/MLT de Lvl-01. Las clases de comportamiento están separadas del importador del mapa para reutilizarlas con datos de otros niveles.



## Música y Lucas



`g_levelMusicClip[1]` selecciona `VOICE_TRIP_V1`: se importa `Musics/Trip_v1.wav` sin modificar sus bytes. BGMPlayer lo reproduce en bucle y continúa durante las escenas; la pausa conserva la posición del audio.



La caja original 580, donde está el spawn, enlaza CIN 0 (14.128 s, sin voz) con CIN 4 (60.688 s, voz española 9, `cin_lvl_0101.wav`). Se recuperan actores, cámaras, movimientos y animaciones originales. Lucas usa AROBIN01, su traje verde de este mapa. Durante la escena se interrumpen las acciones y se oculta el HUD; al terminar se restablecen actores y controles.



E junto a Lucas abre las tres preguntas originales: Sam (voz 10), lechugas (voz 12), otra cosa (voz 11). Flechas/W/S seleccionan y E/Enter reproduce la respuesta. E permite cerrarla. Los textos proceden del banco español MLT; las barras horizontales usan el componente compartido. Las marcas numéricas originales del banco MLT especifican la duración de cada página en décimas de segundo y ahora se respetan. CIN 2 y 3 se activan mediante Porky al entrar en su zona, sin oveja o con una oveja cercana, respectivamente. Véase [level01_completion_audit.md](level01_completion_audit.md).



## Sam



- Sam 43 conserva zonas verdes 69, naranja 70, autorizadas 592, de golpe 621 y las cajas de ocultación configuradas en WAR. Fuera del área se oculta su indicador.

- Barrido de cabeza: velocidad 2, máximo 45 grados y articulación 9. `DetectWolf` combina ruido, proximidad menor de 100 unidades y cono de cabeza de `0x71` sobre 4096. Puntillas elimina el ruido, pero no la visión. El disfraz de oveja evita la detección ordinaria.

- Se recuperan las 58 rutas del grafo de navegación. Persecución a 1100 unidades/s; salida de la región autorizada provoca vuelta al puesto a 1100 unidades/s con RUN2. El modo 0x10000 del nivel 01 es CHASE_CAMERA; la excepción de 200 unidades/s corresponde a otros modos. Véase [sam_navigation_and_pose.md](sam_navigation_and_pose.md). AStar y consultas físicas de Godot adaptan la búsqueda/colisión; no se ha trasladado la totalidad de los estados legacy de salto y recuperación de navegación de otros mapas.

- Captura: PUNCH7 de Sam/Ralph, DIEPNCH2 de Ralph, sonidos originales y transición al checkpoint. Se libera la oveja transportada y la reaparición restablece a Sam y el control.

- La dinamita comunica ruido de clase 2 dentro de las restricciones originales y fuerza alerta. KILL_GENERIC ennegrece cuerpo y retrato: no se interpreta como el aplastamiento que provoca KO en el original.

- Se conserva la pose START para articulaciones omitidas por HEAD2; no se sustituyen las animaciones por poses inventadas.



El indicador utiliza el modelo independiente ATESAM01, export 5/modelo 11, y el marco IGLCRAI1 del DAV. Verde/naranja/rojo se convierten desde los bytes del C++ (rojo en el byte bajo). La cabeza 3D gira con el ángulo relativo entre la mirada de Sam y Ralph, tal como explica Lucas. La detección original usa cajas, estado de ruido y ángulo; los rayos de ocultación son una adaptación del port, no un conjunto de raycasts recuperado del C++.



## Rebaño



`OriginalFlock` coordina las 17 ovejas con reservas de una oveja por señuelo y la regla de una oveja fuera de la zona vigilada. Las despiertas huelen con SMEL1, avanzan con WALK1 a 250 unidades/s, comen con STAND1/sonido 61 y regresan con WALK3. La distancia original de comida de .8 m admite .1 m de margen físico para evitar bloquearse contra las colisiones del rebaño.



El bit dormido selecciona el modelo alternativo AMOUTO03, export 82/modelo 36, SLEEP1 y ronquido 274. Las dormidas no reservan lechugas; al cargarlas se recupera el modelo de transporte. Se conservan el transporte, llamadas con disfraz y entrega de ovejas del componente compartido. La atracción por perfume/ventilador conserva la adaptación existente de olores; las variantes de agua/hielo/botones y estados especiales de otros niveles no forman parte de este hito.



## Verificación



Godot 4.7.2, 2026-10-06:



- `tools/extract_level01_ai.py DECOMP GAME --verify`: igualdad de datos, píxeles DAV, sonidos SND, voces y música respecto a los originales.

- `tools/test_level01_ai.gd`: música/intro, muestras de CIN 2/3/4, controles, zonas, ruido/disfraz, persecución/vuelta, dinamita, sueño, aproximación/comida real, captura/reaparición y menú E: **0 fallos**.

- `tools/test_level01_essentials.gd`: buzón, dinamita, rocas, agua y telescopio: **0 fallos**.

- `tools/test_level00_closure.gd` y `tools/test_tutorial_finish.gd`: regresiones de cierre/transporte/meta del tutorial: **0 fallos**.

- Capturas con OpenGL/NVIDIA, sin errores de ejecución: [Lucas](level01_lucas_original_intro.png), [Sam mirando de frente](level01_sam_orange_portrait.png), [retrato girado](level01_sam_turned_portrait.png), [modelo dormido](level01_sleeping_sheep.png).



Extracción: `tools/extract_level01_ai.py DECOMP GAME`; importar con el editor headless, ejecutar `tools/build_level01_ai.gd`, `tools/configure_level01_ai_imports.py` y volver a importar. El configurador conserva los píxeles DAV sin corrección de borde alfa, mipmaps ni compresión con pérdidas.



## Refinamiento: sincronización, retrato y transporte



La escena con voz sigue ahora `AudioStreamPlayer.get_playback_position`, compensando el bloque mezclado y la latencia de salida. Cargas o frames largos no adelantan la animación respecto al audio; después del fin de la voz se completa la cola del guion. Los subtítulos utilizan el mismo reloj. `Cine::OpStartAnim` llama `PlayAnim(id,1,0)`: todas las animaciones de las cinemáticas se repiten hasta la siguiente orden. En particular TIPTOE dura .52 s y debe repetirse durante el intervalo 54.256–57.696 de CIN 4. Los efectos repetidos mantienen un pool acotado y no reinician una muestra aún activa del mismo actor.



`Sam::Update` calcula `relAngleToWolf` en coordenadas nativas. La reflexión del mundo invierte el signo relativo: se usa `body_yaw - heading_to_Ralph - native_head_yaw`, con el barrido del frame actual. El retrato conserva ese ángulo según `Sam::Render`. Un estado WALK/LAND residual sin movimiento no se interpreta como pasos audibles; caminar realmente en naranja sigue alertando a Sam desde atrás, como indica `DetectWolf` y explica Lucas.



`OriginalSheepCarry` adapta la tabla `g_wolfStateTable1`, `g_wolfMoveProfilesCarry` y `g_wolfIdleAnimsCarry`, compartida por los niveles:



- Reposo STAND8, variación de cansancio STAND12 tras 3–5 vueltas; la variación dura 1–2 vueltas antes de regresar.

- RUN2 a 450 unidades/s y SNEAK2 a 200 unidades/s con Ctrl, con aceleración/desaceleración del perfil de transporte.

- Un salto: JUMP0B → JUMP4 → JUMP5/FALL2 → RECEPT4/RECEPT3. Altura 130 unidades y ascenso `0x48b/4096` s. Segunda pulsación en el aire no activa un doble salto. Mantiene la protección de caída respecto al origen del salto.

- La oveja responde al cue de transporte con STAND8 en reposo/aire y RUN2 al caminar; STAND2 queda para TAKE2B/PUT2A. Articulación 18, rotación de la raíz y desplazamiento original `(0,7,0)` conservados. La animación errónea de reposo de Ralph era STAND2 y provocaba la carga con un solo brazo.



`tools/extract_run_assets.py` importa las animaciones anteriores de ACOYOT01 del nivel 01 y sus sonidos; `tools/build_run_animations.gd` genera claves desde el inicio de cada segmento y cierra únicamente los loops correspondientes.



`tools/test_level01_refinements.gd`: reloj de voz durante un frame de 4 s/seek, TIPTOE repetido, ángulo reflejado, falsa alerta estática, recogida real, unión al hueso, cansancio, sigilo/velocidad, salto sin doble salto, aterrizaje y colocación: **0 fallos**. Regresiones `test_level01_ai`, `test_level01_essentials`, `test_tutorial_finish`, `test_tutorial_intro` y `test_camera_training`: **0 fallos**. Capturas GPU de [reposo](level01_sheep_carry_idle.png), [cansancio](level01_sheep_carry_tired.png), [sigilo](level01_sheep_carry_sneak.png) y [salto](level01_sheep_carry_jump.png), sin errores de ejecución.



## Límites, reaparición y audio de puntillas



Sam distingue `wolfCanBeHitZoneBoxes` (abandono de persecución después de 200 ms) de `authorizedZoneBoxes` (límite XZ de su propio desplazamiento). `OnGoalReached` vuelve a casa cuando Ralph está fuera de la zona autorizada y no está activo `SAM_MODE_NO_GIVEUP_OUTSIDE_ZONE`; dentro se solicita una nueva ruta. No se convierte `goalDist > 1400` en un radio de abandono: el C++ lo utiliza para cambiar de búsqueda de navegación.



`OriginalCheckpointManager` recupera CheckpointManager 117 y los exports 581–586: dos zonas, destinos de Ralph y oveja, orientaciones 0 y 3072. Inicializa un punto fijo al entrar al nivel y solo actualiza destinos tras dos segundos sin Sam en rojo, sin muerte/transición. Se respeta la condición conjunta de oveja/Ralph configurada por nivel. `MSG_WOLF_SAVE_RESPAWN` confirma inventario; el buzón conserva las entregas confirmadas. `Wolf::Reset` restablece destino y orientación y consulta suelo en ese punto. Estos checkpoints son de reaparición en memoria; no escriben archivos de guardado.



`Wolf::SneakStepSound` usa ocho pasos, no doce: SND 0x48, tasas 0x800+n*0x100 sobre 4096, volumen entero (8-n)*255/8 y dos pasos por ciclo de la animación activa. 12–20 corresponde a los tonos aleatorios de `FootstepSound`. La muestra de puntillas coincide byte por byte con la del SND y ahora se importa como PCM sin compresión con pérdidas. El transporte invoca este audio compartido, con el ciclo de SNEAK2; reiniciar la marcha inicia de nuevo la secuencia y detenerla corta la muestra.



Los tonos del marco ya eran correctos: `g_samZoneColors` / `Color_RgbToBgr` produce #2a701f, #a0500f, #f01000. `validation/capture_sam_palette.gd` verifica además esos mismos bytes en píxeles renderizados por OpenGL, usando el IGLCRAI1 original; no se ha ajustado la paleta a ojo.



Verificación adicional: `tools/test_sam_respawn_and_steps.gd` (límites separados, gracia, ambos checkpoints, captura/reaparición, orientación, inventario, PCM y variaciones de pasos); `tools/test_level01_refinements.gd` comprueba también audio durante transporte real. `test_level01_ai.gd` usa liberación de E entre pulsaciones sintéticas. La prueba antigua `test_inventory_mechanics.gd` presenta ocho fallos en la secuencia de cancelación del inventario/uso de cohete; las comprobaciones de puntillas de esa prueba pasan. Se deja registrado sin cambiar esas mecánicas durante este ajuste.
