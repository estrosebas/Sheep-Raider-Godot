# Nivel 01: Lucas quemado, Porky, reloj y pendientes

Revisión del port contra `sdw-decomp`, 2026-10-06. Las pruebas comprueban las mecánicas implementadas; todavía no se puede completar el recorrido original de principio a fin.

## Implementado en este hito

- **Lucas y dinamita:** `daffylevel01.cpp` recibe `MSG_KILL/KILL_GENERIC`, activa `burnt` y aplica tinte negro con intensidad 4096. No reproduce una muerte nueva: permanece vivo. La siguiente conversación selecciona respuesta 5, `cin_lvl_0105.wav`, y después vuelve a sus preguntas habituales. Esta respuesta desactiva el avance manual. El port comparte conversación y tinte con otros NPC; Lucas conserva el control bloqueado hasta terminar sus páginas originales. Al reaparecer se restablecen tinte y banderas según `Reset`.
- **Ralph quemado:** `wolf.cpp` combina muerte por explosión con `WOLF_FA_BURNT`. Se conserva EXPLOS1 y se aplica el mismo tinte negro durante la reacción; se limpia al reaparecer.
- **Porky:** `porkylevel01.cpp` activa CIN 2 sin oveja y CIN 3 cuando una oveja está a menos de 200 unidades originales. Se usan la caja 593, voces y cámaras originales. La oveja cercana se vincula al actor de la escena. Las ocho lechugas están ocultas inicialmente; aparecen con APPEAR tras el retardo original de 10 ms y luego cada 500 ms. Terminar o saltar la escena revela las restantes. Las tres preguntas usan banco 31 y voces 59/60/61 (`cintxt_lvl_0103/04/05.wav`). La reacción quemada usa banco 31[9], voz 65 y el comportamiento de una sola respuesta de `Porky::Reset`.
- **Páginas de texto:** `ScrollText_Run`, en `engine/text.cpp`, interpreta `$n$` y `$(n)$` como duración de página en décimas de segundo. Se conservan páginas vacías y duraciones. La frase de Lucas que menciona un minuto no impone un temporizador de 60 s: sus páginas duran 41,6 s; su voz, aproximadamente 38,49 s. Las conversaciones normales conservan E para cerrar la respuesta como adaptación de controles.
- **Reloj secreto:** entidad TimeKeeper 65, modelo 37, ubicación original y ajuste al suelo. Se recuperan CLOCK1 → CLOCK2 → CLOCK3 → CLOCK4 → CLOCK1, uso CLOCK2 de Ralph y sonidos 250/248/249. La recompensa se concede una sola vez por nivel; el reloj permanece visible e inactivo después. `OriginalProgress` mantiene el bit y puntos entre muertes y escenas, y el guardado manual incluye esos datos. No añade guardado automático.

## Lo que falta para cerrar el nivel

| Prioridad | Pendiente | Evidencia original y estado del port |
| --- | --- | --- |
| 1 | Puente que se rompe al cruzar con oveja | `objects/bridge.cpp`, entidades 40/41, modelo 10, zona 579. El peso de Ralph y oveja activa crujidos, bloqueo y derrumbe; envía daño a la zona. Actualmente son geometría con colisión fija. Las animaciones de una cinemática no sustituyen esta lógica durante el juego. |
| 1 | Meta y regreso al estudio | `objects/goal.cpp`, entidad 115, modelo 33. Comprueba presencia de Ralph y oveja, radio y altura, y envía `MSG_WOLF_WIN`. El importador todavía omite esta entidad lógica; falta victoria y transición/progreso del nivel 01. |
| 2 | Sam devuelve ovejas robadas | `objects/sam.cpp`, objetivos FETCH/CARRY y búsqueda de ovejas fuera de su zona. El port implementa vigilancia, persecución, captura y retorno al puesto, pero no la recuperación y transporte de ovejas por Sam. |
| 2 | Guardar/cargar el checkpoint del nivel 01 | Los checkpoints originales ya funcionan en memoria. `SaveFiles` todavía admite instantáneas de nivel 00; falta esquema y restauración de nivel 01, incluyendo lecciones de Porky, lechugas, objetos, puente y estado del rebaño. Los datos globales del reloj se guardan cuando se escribe una ranura compatible, pero esto no convierte el nivel 01 en un nivel guardable. |
| 3 | Mapa e indicador de distancia a lechugas | `map.cpp`, `maplocation.cpp` y el indicador de inventario mostrado por Porky. Las lechugas ya atraen ovejas; falta el apoyo visual de cercanía y las ubicaciones originales del mapa. |
| 3 | Restricciones de cámara y visibilidad | Las entidades CameraRestriction y VisibilityManager siguen sin una implementación equivalente. Revisar especialmente la zona del reloj y el ocultamiento de geometría, además de los límites de cámara. |
| 3 | Ambiente y acabado audiovisual | AmbientSoundManager, FogManager y activación del pájaro decorativo siguen pendientes. El habla del NPC usa actividad de voz para alternar TALK/STAND; el original consulta amplitud de audio. Comparar estos detalles durante una partida completa. |

El siguiente hito funcional debe ser **puente y meta**, seguido de recuperación de ovejas por Sam y guardado del nivel. Después hace falta una partida completa por la ruta original: buzón/dinamita, oveja, puente, Porky/lechugas, secreto y entrega final.

## Verificación

- `tools/extract_level01_ai.py DECOMP GAME --verify`: datos, texturas, clips y voces contrastados con los archivos originales.
- `tools/test_level01_porky_clock_and_blast.gd`: explosión real, tinte, respuesta única de Lucas, temporización y bloqueo, menú y reacción de Porky, triggers con/sin oveja, aparición de lechugas, secuencia del reloj, recompensa única y persistencia tras muerte.
- `tools/test_save_files.gd`: guardado manual, progreso del reloj, restauración en escena nueva y compatibilidad de ranuras.
- Regresiones de nivel: `test_level01_ai.gd`, `test_level01_essentials.gd`, `test_level01_refinements.gd`.
- Resultado de las pruebas anteriores en Godot 4.7.2: **0 fallos**. La importación final y la captura con OpenGL/NVIDIA terminaron sin errores.
- Capturas GPU: `capture_level01_porky_clock_and_blast.gd`, Lucas quemado y diálogo, Ralph quemado, menú de Porky y modelo del reloj. El script recoloca actores solamente para inspección visual; no altera las posiciones del nivel.

Esta revisión no declara completado el nivel ni sustituye la prueba de recorrido completo.
