# Nivel 04: base importada

Escena: `res://scenes/levels/Level04.tscn`. Abrir en Godot y pulsar F6 para probarla directamente. También disponible en la puerta **Nivel 04** del laboratorio (F8). La puerta del escenario principal conserva el desbloqueo secuencial después de completar el 03.

## Listo para probar

- Mapa, cielo, texturas DAV y colisión WAR: 6.510 triángulos; escenario visible desde el editor.
- 72 registros originales, 24 modelos y sus animaciones; los managers y emisores lógicos no muestran sus mallas de referencia.
- 13 ovejas, vigilancia y zonas originales de Sam, tres rocas de ocultación, arbusto y ventilador con controladores compartidos.
- Dos buzones: 56 entrega flauta74; 57 entrega ventilador71. Caída y apertura de cajas, recogida e inventario compartidos.
- Flauta reutilizable (también en laboratorio): seleccionar y pulsar R para tocar/dejar de tocar. Poses nativas FLUTE1/WALKF1/STANDF1, unión al joint18, sonido37 en bucle y notas DAV209. Ralph camina a2m/s; la hipnosis entra desde vigilancia, respeta la zona544, se renueva a<=3m y expira1s después de dejar de recibirla. Sam usa HYPNOS1/HYPNOS2/WALK2, sigue a2m/s y para a2m.
- Toro con colisión propia, apoyado en el suelo sin alterar su pivote: duerme, despierta, embiste a8m/s, golpea con HIT1/PUNCH6 y vuelve a casa al salir Ralph de su zona. Al morir se reinicia. Los polígonos nativos de hojarasca533/534 producen sonido129 y partículas al moverse, incluso en sigilo, y despiertan al toro60.
- Hoja ambiental191: FLY completo sin bucle, origen en suelo, apariciones aleatorias±9m y pausas originales. Los emisores lógicos54 permanecen invisibles y sus partículas se desplazan en espacio mundial.
- Hojarasca del toro:130 triángulos originales de DAV3/rect166. El parche de caras frontales del arbusto de Ralph fue rechazado para esta superficie abierta: no añade grosor y a ras de suelo sigue pareciendo una lámina. El nivel conserva su material anterior mientras se prueban variantes; ninguna de las nuevas se aplica al mapa. En F8, la muestra central de67 triángulos (`BullLeafHeap`,1,0,-27) vuelve al material opaco de dos caras y ahora tiene su colisión superior, además del polígono72, sonido129 y partículas. Las pruebas A�G se retiraron del laboratorio por seguir pareciendo planas; quedan archivadas y hay un TODO en item_lab.gd para retomarlo. Véase `scripts/testing/experiments/LEAF_HEAPS.md`.
- Cuatro volúmenes de agua normales conectados a la natación compartida, desplazamiento de textura y sprites originales. Este mapa no activa el temporizador de pirañas del 02.
- Dos tiburones50 con IA compartida y sus trayectorias WAR de12 puntos: patrulla3,5m/s, apuntado2s, STAND2 de0,74s, embestida recta9m/s y mordisco a1,6m. Detectan únicamente dentro de su caja asignada, en agua y con desnivel<3,6m. UpdateAi compara con9600u=96m, aunque la propiedad DETECTRANGE sea640u=6,4m; se conserva el literal del C++. Recuperan el recorrido después del ataque. Wolf EAT y Shark EAT originales duran5,07s, comparten origen/rotación y disparan los sonidos138/136/74. Burbujas y estela DAV nativas; cámara de muerte fija con consulta de paredes. Reset limpia efectos y el bloqueo de mordisco, conservando posición/estado de patrulla como el original.
- Salida del agua compartida: mantener Espacio para ascender, soltar y pulsar otra vez a<=20 unidades de la línea de flotación para saltar fuera; se conserva el segundo salto. La zona no interrumpe el arco y vuelve a detectar natación al caer al agua. Shift sigue bajando; una orilla transitable por encima de la línea de flotación restaura caminar.
- Natación superficial compartida: SWIM1 en movimiento y SWIM4 en reposo; sumergido, SWIM3/SWIM2. Wolf::UpdateState cambia a superficie a<20 unidades bajo la línea de flotación y vuelve a sumergido a>50, evitando reiniciar animaciones en el límite. No depende de tocar el fondo. Mantener Espacio contra la superficie devuelve el cuerpo a posición vertical. Verificados los cuatro clips importados del02: son idénticos a los de WAR04.
- Botón39 enlazado a piedra65: espera nativa de 1s, FALL1, zona de aplastamiento desde 11/16, EXPLOD1, cámara541, sonidos66/93 y rearme al soltar.
- Sam aplastado compartido: `SQUASH` (1,65s, sin bucle) → `SQUASH1` (en bucle durante los3s de DEATHDURATIONMS del WAR04) → `SQUASH2` (3,83s, sin bucle). Total8,48s más cuantización de fotograma; no detecta ni persigue hasta terminar de levantarse. La piedra refresca KILL_CRUSH durante los últimos fotogramas de FALL1, como el original; reset de checkpoint restaura vigilancia. La roca conserva sus60 caras exteriores y60 interiores inversas: material con cull_back impide que las interiores oscuras tapen las texturas exteriores. Los límites de dibujo siguen la malla animada durante caída/fragmentación, sin tocar texturas, UV ni colores.
- CIN1 de entrada (19,952s), CIN2 de Lucas elfo (62,992s), conversación y voces52/53/11 originales, con textos y audios en los cuatro idiomas existentes.
- La entrada conserva las pistas de audio de la secuencia, sin añadir flauta37 por ejecutar COME1. DaffyElf::WATCH inicia ese sonido posicional una sola vez al terminar el tutorial, mientras espera conversación; lo detiene al hablar. El WAV52 español conserva sus16,01s iniciales de silencio y su duración63,48s; la secuencia espera el final de la voz para no cortarla.
- Letreros originales, cuatro checkpoints, reloj67, goal99, guardado manual y autoguardado de final compartidos. Se conserva la posición original del reloj; el recorrido completo de acceso queda para prueba jugable.
- Balsa53 (`OriginalRaft`): controlador compartido con malla, caja2.49×.20×3.26m y posiciones nativas. Ventilador sólo impulsa con Ralph encima, admite solape del portador fuera del cono, velocidad3.5m/s y aceleración/frenado2m/s². Empuja en sentido opuesto a donde apunta Ralph, como el original. Corrientes nativas por flags (lenta1/normal2/rápida4m/s), animaciones STAND1/ACTION1, estela IGLTIDE, transporte de personajes/carga y ancla de oveja. RESET0 conserva posición al morir; RESET1 la reinicia. Guardado incluye posición de balsas y acepta partidas anteriores sin ese campo.
- Música original con los límites de bucle del catálogo compartido.

No hay balancines, rocas empujables ni elásticos en los registros de este nivel. La piedra activada por botón es otra clase, no una copia del balancín del 03.

## Pendiente antes de considerar el nivel cerrado

1. Peces ambientales162: recorridos, saltos y reinicios originales. La hoja191 ya tiene su ciclo.
2. ObjectManager184: activación/visibilidad por cámara del reloj67. El manager permanece invisible; el reloj utiliza por ahora el controlador compartido siempre disponible.
3. Elegir visualmente una solución de hojarasca entre las pruebas del laboratorio; el parche de arbusto no resolvió este caso.
4. Partida completa desde entrada hasta entrega de oveja, incluyendo ruta al reloj, muerte/recuperación y cargar checkpoint. Las pruebas por mecanismo no equivalen a esa validación de recorrido.

La balsa ya está implementada y probada; no es una plataforma fija. Flauta y audio de superficie también están corregidos. El estado actual es jugable en pruebas por mecanismos, pendiente de cierre completo.

El controlador del toro cubre las propiedades activas de04; los pañuelos rojos, Gossamer y lanzamiento de ovejas de niveles posteriores requieren sus adaptadores cuando se importen.

Datos, medidas y referencias de las funciones C++: `docs/LEVEL04_NATIVE_AUDIT.md`.

## Reconstrucción

Ejecutar en orden, sin iniciar varios Godot simultáneos:

1. `python tools/extract_level_scene.py DECOMP PC_LEVEL_04 --all-animations --runtime-adjusted`
2. `python tools/extract_level_runtime.py DECOMP PC_LEVEL_04`
3. `python tools/extract_level_goals.py PC_LEVEL_04`
4. `python tools/extract_imported_level_content.py DECOMP PC_LEVEL_04`
5. `python tools/extract_level04_environment.py DECOMP PC_LEVEL_04`
   Después: `python tools/extract_level04_wildlife.py DECOMP PC_LEVEL_04`, `python tools/extract_flute_mechanics.py DECOMP PC_LEVEL_04`, `python tools/extract_shark_mechanics.py DECOMP PC_LEVEL_04` y `python tools/extract_level04_foliage.py DECOMP PC_LEVEL_04`.
6. `python tools/extract_level04_cinematics.py PC_LEVEL_04`
7. `python tools/localize_imported_level.py lvl_04`
8. `python tools/create_imported_level_scene.py lvl_04`
9. Godot `--headless --editor --path . --import --quit`
10. `python tools/configure_native_level_textures.py lvl_04` y repetir la importación de Godot.
11. Godot `--headless --path . --script tools/build_level_scene.gd -- lvl_04`
12. Godot `--headless --path . --script tools/build_level_runtime.gd -- lvl_04`
13. Godot `--headless --path . --script tools/build_imported_level_content.gd -- lvl_04`
14. Godot `--headless --path . --script tools/build_flute_assets.gd` y `--headless --path . --script tools/build_run_animations.gd`.

Prueba de integración: Godot `--headless --path . --script tools/test_level04_foundation.gd`. Usa un directorio de guardado de prueba, separado de las partidas del jugador. Con renderizador de escritorio genera capturas en `validation/level04_*.png`.

Prueba de flauta, hipnosis, polígonos de hojas, carga/golpe/reset de toro y ciclo ambiental: `--headless --path . --script tools/test_level04_flute_and_bull.gd`. Con renderizador genera `level04_flute_pose.png` y `level04_bull_grounded.png`.

Agarre de flauta: `Flute::MSG_PICKUP` mantiene LINK; `MSG_HELD_STATE_BEGIN/END` cambia estado/sonido y no selecciona los clips adicionales del objeto. Ralph sí usa FLUTE1/WALKF1/STANDF1. Reproducir ambos a la vez provocaba giros y estiramientos extra de hasta3.82×. El controlador compartido mantiene LINK, joint18 y la matriz de la mano recién evaluada en cada pose visible. `tools/test_flute_hand_pose.gd` verifica dimensiones constantes, orientación nativa, reposo, tocar quieto/caminando y fidget, además de la sincronización sin esperar otro tick físico. Con renderizador guarda `validation/flute_*.png`.

Prueba de salida de agua, segundo salto, retorno a natación, aterrizaje con colisión y recogida física del reloj en su alcoba: `--headless --path . --script tools/test_level04_water_exit.gd`. No prueba el recorrido completo hasta el reloj.

Audio de superficie compartido: `SWIM1` dispara el sonido nativo51 a los80ms de cada ciclo de1.5s (`ralph_water_data.json`). Muestra idéntica en02/04, conservada sin cambio de tono como `assets/audio/sfx/original_surface_swim.wav`; el extractor02 la reconstruye. `OriginalWaterMotion` procesa estas claves porque su movimiento retorna antes del actualizador de sonidos habitual. `SWIM4` en reposo no tiene claves de audio; `SWIM3` sumergido conserva su bucle35 independiente.

Prueba de tiburones, velocidad sobre geometría real, caja/agua, espera2s, embestida sin homing, recuperación, muerte EAT, sonidos y cámara fija: `--headless --path . --script tools/test_level04_sharks.gd`. Los tests de natación deshabilitan estos peligros para aislar los controles; el juego normal los mantiene activos.

Prueba de aplastamiento real por botón/piedra, fases y tiempos nativos de Sam, rearme/reset y límites animados: `--headless --path . --script tools/test_level04_sam_crush.gd`. Con renderizador captura `validation/level04_sam_crushed.png`. `tools/capture_level04_stone.gd` captura reposo, caída, impacto y fragmentación con la cámara nativa541; argumentos `-- front` / `-- back` permiten comparar el descarte de caras para diagnosticar la malla original.

Prueba de conservación de todos los triángulos del mapa, geometría y UV superiores originales de A/B/C, colisión física y ruido al caminar: `--headless --path . --script tools/test_level04_foliage.gd`. Capturas nuevas desde altura de ojos, lado opuesto y arriba: `--path . --script tools/capture_leaf_heap_experiments.gd` genera `validation/leaf_heap_[0-2]_[eye|reverse|above].png`. Las capturas antiguas `bull_leaf_heap_*` documentan el intento rechazado. El build de nivel conserva el material anterior; no exporta las variantes del laboratorio.

Extraer balsas para éste o futuros mapas: `python tools/extract_raft_mechanics.py assets/levels/lvl_04` después de exportar entidades, modelos, cajas y efectos acuáticos. El importador compartido instancia class53 con `data/rafts.json` y elimina la antigua colisión estática. Prueba: `--headless --path . --script tools/test_level04_raft.gd` verifica ventilador real, aceleración/freno, solape fuera del cono, Ralph/oveja/lechuga, orilla, corriente, RESET y guardado compatible. No se guardan pruebas en las partidas del jugador.
