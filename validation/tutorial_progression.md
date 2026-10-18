# Continuidad del tutorial, música e inventario

## Correcciones de presentación

El WAV de fondo `jungle_v1.wav` se duplicaba como recurso cargado, pero no tenía bucle configurado. `level_setup.gd` ahora activa `AudioStreamWAV.LOOP_FORWARD` sobre una copia por nivel, desde la muestra cero hasta el final calculado en frames de audio. Las transiciones CIN 1/CIN 5 y las voces siguen usando reproductores separados y no detienen la música.

Las nubes originales ya no dependen de `Engine.get_process_frames()`. Se usa `cloud_frame_seconds = 0.2`: cinco fotogramas por segundo y un ciclo completo de tres fotogramas en 0.6 s, configurable en el inspector. Se conservaron los PNG y el dibujo de la rueda; la reducción de velocidad solicitada funciona igual con distintos FPS.

## Guía jugable ampliada

Se extrajeron las **20 ayudas** del WAR/MLT, con cajas de entrada, rutas, gait y voces originales. Después del bloque de cámara, la guía continúa hasta la explicación de los columpios:

- Salto: slot 4 / texto 1 / voz 92 (`txt_lvl_006.wav`). Se activa en la caja 673. Lucas camina y salta por los nodos originales.
- Doble salto: slot 6 / texto 3 / voz 93 (`txt_lvl_007.wav`), en la caja 645.
- Broma de volar: slot 9 / texto 6 / voz 94. Si Ralph cae y vuelve al checkpoint, se reproduce la respuesta/broma original de texto 7, voz 95 y clip JOKE.
- Carrera: slot 11 / texto 9 / voz 81. La UI adapta el control a pulsaciones repetidas de Shift. El original arma el cronómetro al entrar en X/Z de RACEBEGIN (678) y lo inicia al salir de su caja. RACETIME = 500 × 100 ms = **50 s**. Llegar a RACEEND (660) detiene el contador y reproduce la voz 83; el fallo/reintento usa la voz 82.
- Explicación de columpios: slot 14 / texto 14 / voz 84, caja **651**, enlazada con **CIN 3**. No se dispara durante el doble salto: esa ayuda usa otra caja.

Las explicaciones del nivel 00 usan `OriginalLevelDialogue`, el mismo componente de los niveles 01, 02 y 03: franjas negras, letras originales amarillas y páginas que avanzan con la voz. Los marcadores `$n$` / `$(n)$` del MLT conservan su duración original de `n × 100 ms`. El reloj espera a que se abran las franjas y empiece el audio. Las instrucciones adaptadas a PC se reparten en páginas de dos líneas durante la grabación; la instrucción sin voz usa un tiempo de lectura. E permite omitir la explicación, pero ya no es obligatorio para avanzar. Se sustituyen los tokens de mando por Espacio/Shift/Tab/Ctrl/E. Caminar/jump se desbloquea mientras Lucas se desplaza entre las ayudas posteriores a cámara, y se bloquea durante la explicación.

`DaffyTrainingLevel::MoveTo` usa gait 0/1 para caminar a 600 unidades/s; gait 2, en las ayudas posteriores, separa JUMP3 (despegue), JUMP4/JUMP5 (arco), JUMP6 (aterrizaje). El arco central dura 400 ms y añade `sin(pi*t)*100` unidades de altura. Los gaits 3/4 cambian de posición directamente. La adaptación traslada esos estados a metros/segundos y conserva los nodos de las rutas.

## CIN 3 y escenario construido

El script original tiene **24 pistas y 36.496 s**: Lucas, cámara y 22 piezas estáticas. Sus datos, modelos y páginas DAV se recuperan con el extractor de cinemáticas. La escena puede continuarse con E. Al finalizar, conserva las piezas que el guion dejó visibles. La investigación del puzzle confirmó que estas piezas decorativas no tienen cajas sólidas originales; se retiró la colisión de malla que se había añadido. Los balancines, las piedras, el botón y la puerta poseen sus colisiones independientes: [tutorial_puzzle.md](tutorial_puzzle.md).

El reproductor ahora preserva la posición de Ralph si la cinemática no contiene una pista suya, como ocurre en CIN 3. Esto evita devolverlo por error a la posición final de CIN 5.

## Piedra que cierra el camino

`FallingRock::PostLoadInit` (`src/objects/fallingrock.cpp`) indica que las tres FallingRock empiezan **ocultas y sin contacto**. Se habían quedado incluidas en la malla visual combinada y con sólidos activos desde el inicio.

`extract_tutorial_progress.py` separa sus triángulos de la malla combinada; también mantiene separado el cohete. Se conservaron posiciones, UV y colores del export completo. La malla estática queda con 7,461 vértices: +414 del cohete y +450 de las tres piedras = 8,325 originales.

| Piedra / entidad | Activación original | Checkpoint asociado |
|---|---|---|
| FallingRock 58 | export 634 | índice 2 |
| FallingRock 59 | export 667 | índice 4 |
| FallingRock 60 | export 640 | índice 5 |

`TutorialProgress` recupera los seis checkpoints del manager y las cajas de destino de Ralph. Al entrar apoyado en su zona, guarda la posición de reaparición y confirma el inventario. La piedra correspondiente aparece una sola vez, baja desde 20 m sobre su posición en cinco pasos de 4 m y queda sólida. La cadencia se adapta a pasos de 40 ms; el sonido de impacto es el SND original 68 (`SR2ROFA2`). Las otras piedras siguen ausentes hasta sus respectivos checkpoints.

La aparición se vincula al checkpoint alcanzado, como pidió el usuario. El C++ de FallingRock por sí solo comprueba X/Z de esa misma caja; la adaptación evita activarla al pasar volando sin guardar el checkpoint. Las piedras caídas permanecen al reaparecer y no vuelven a caer al cruzar su zona otra vez.

Ralph conserva una posición de checkpoint separada de su último apoyo local. La caída de carrera y el fallo del cronómetro usan ese destino. Se añadió una red de seguridad para saltos normales al vacío: si cae 30 m por debajo de su apoyo y fuera del mapa, vuelve al checkpoint en vez de descender indefinidamente. Es una adaptación provisional, pendiente de portar todas las zonas letales y sus fades originales.

## Comprobación y alcance pendiente

`tools/test_tutorial_progress.gd` comprueba bucle de música/transiciones, reloj de nube, piedra invisible/sin colisión antes del checkpoint, aparición única/caída, reaparición, salto/doble salto, carrera de 50 s, fallo/reintento/éxito y persistencia de CIN 3. Los extractores admiten `--verify` para comparar con WAR/DAV/MLT/SND originales.

`tools/test_automatic_tutorial_dialogue.gd` comprueba los tiempos desde la reproducción real de la voz, el avance sin pulsar E, el ajuste de textos largos a dos líneas y las cuatro traducciones. Captura de la presentación compartida: `level00_automatic_subtitles.png`.

Capturas GPU: `checkpoint_rock_before.png`, `checkpoint_rock_after.png`, `tutorial_jump_instruction.png`, `tutorial_seesaw_cinematic.png`.

Este hito cubre el recorrido y las ayudas de movimiento, la carrera y la presentación de los columpios. **No se declara terminado el nivel completo.** Falta conectar el funcionamiento físico/scriptado de ambos columpios y las rocas móviles, el botón/puerta, buzón/pedidos, la guía de inventario y la condición final de entrega/meta. Los objetos compartidos y el cohete siguen disponibles; las lecciones 15–19 tienen sus datos/voz recuperados, pero no se avanzan sin sus mecánicas de mundo.
