# Sam: regreso, velocidad y vigilancia

2026-10-07. Contraste con `sdw-decomp` y pruebas en Godot 4.7.2.

## Código original y cambios

`Sam::SetGoalWolf` y `SetState`, en `src/objects/sam.cpp`, fijan persecución a **1100 unidades/s, 11 m/s**. La propiedad del nivel 01 es `0x10000`, CHASE_CAMERA. No es ALT_BEHAVIOUR (`0x20000`) ni LEVEL_VARIANT (`0x8000`). El port aplicaba incorrectamente 200 unidades/s a todo regreso. Ahora este nivel vuelve a 11 m/s con RUN2, mientras la persecución usa START → RUN1. Los modos alternativos conservan sus excepciones: ALT_BEHAVIOUR cambia a WALK1/200 unidades/s cerca de casa, a menos de 400 unidades de distancia Manhattan XZ. El modo de nodos conserva la velocidad de persecución de 1,5×.

La ruta de regreso ya no se reemplaza cada 350 ms por una que empieza en el nodo más cercano, que podía quedar detrás. Se conserva el avance y solo se recalcula por cambio de objetivo, agotamiento de ruta o atasco. Las conexiones se toman del grafo original de 58 rutas. La selección de entrada comprueba espacio para la cápsula y continuidad del suelo, siguiendo su pendiente. No usa la visibilidad como prueba suficiente de paso físico.

`UpdateStallTracker`, FOLLOWNODES y REACHGOAL vuelven a búsqueda de nodos cuando no avanzan durante unos 200 ms. El adaptador usa 250 ms y 10 cm de avance: mide el movimiento solicitado antes de que `move_and_slide` ponga la velocidad a cero. Evita temporalmente el nodo obstruido durante dos segundos, también dentro de la búsqueda AStar, y prueba otro acceso. Esto es una adaptación a las colisiones de Godot, no una reproducción de todas las estructuras de navegación legacy. Se conservan los límites XZ y el retorno al abandonar la persecución; un objetivo fuera del terreno puede acercarse hasta un nodo alcanzable y provocar vuelta al puesto. No teletransporta a Sam para solucionar rutas.

## Pose original, sin reemplazos inventados

LOOKAFTER utiliza **HEAD2**, con mano en la frente y otra en la cintura. El recurso estaba presente, pero sus rotaciones compuestas se convertían mal:

- `load_warmeshes.cpp`: las claves de animación son ángulos en sentido horario; `Math_Angle4096ToRadians` y `Math_Angle128ToRadians` niegan el ángulo.
- `Mat44::SetRotYXZ`, en `engine/mat44.cpp`, utiliza vectores fila. La matriz transpuesta para Godot es una composición **ZXY**, tras reflejar el eje Y.
- El importador de Sam declara orden ZXY y signos `[1,1,-1]` respecto a los valores del decodificador compartido. Se reconstruyen las animaciones de Sam, también las instancias cinematográficas. Otros personajes conservan su configuración existente.
- `SetJointOverride(9)` usa el conversor positivo `_2`, distinto del de las claves. Se aplica el giro positivo en el hueso 9; gira el tronco superior, los brazos y la cabeza manteniendo la postura original.

Capturas de HEAD2: [centro](sam_guard_0.png), [izquierda](sam_guard_-0.7.png), [derecha](sam_guard_0.7.png). Se generan con `validation/capture_sam_guard.gd`; usa la posición real de Sam y no recoloca el mapa.

## Verificación

`tools/test_sam_navigation_and_pose.gd` comprueba matrices contra una transcripción independiente del C++, posición de ambas manos, giro, velocidades y desplazamiento físico de unos 1,1 m en 100 ms. Prueba retornos desde seis puntos de las rutas originales, persecución a un objetivo exterior y recuperación de una ruta ya elegida que queda bloqueada por una pared sólida. **0 fallos**.

Regresiones: `test_level01_ai.gd`, `test_sam_respawn_and_steps.gd` y `test_level01_refinements.gd`: **0 fallos**. La comparación de extracción `extract_level01_ai.py --verify` comprueba los datos originales. Las capturas OpenGL/NVIDIA verifican la postura visible, sin errores de ejecución.

Pendientes de la IA completa: recuperación/transporte de ovejas por Sam y estados de salto específicos del motor original. Este ajuste corrige vigilancia, persecución y retorno sobre el terreno/rutas verificados; no declara completados todos los estados legacy.

## Límite corto y recuperación del golpe

El original usa IsWolfOutsideHitZone (zona XYZ con gracia de 200ms) y authorizedZoneBoxes para movimiento XZ; no se identificó un radio global de persecución. Para recortar el alcance según lo solicitado, el port añade chase_leash_distance=14m desde home (export configurable; 0 desactiva esta adaptación). Se evalúa tanto a Ralph como a Sam; detectar de nuevo fuera de ese radio queda inhibido. Los nodos fuera de las zonas autorizadas se excluyen del AStar, incluidos los de regreso, evitando excursiones hacia el puente al buscar una ruta entre árboles.

Al acabar PUNCH7, SAM_STT_CATCHDONE usa SAM_ANIM_CATCHDONE=19, traducido a WIN por g_samAnimTable. El port ahora cambia a WIN y conserva las claves omitidas heredando el final de PUNCH7. WIN incluye sonido77 a los 0,94s, recuperado del SND original. El regreso al checkpoint de Ralph mantiene su secuencia de muerte.

Verificación: test_sam_leash_and_recovery (radio, reservas de ruta, WIN y sonido77), test_sam_respawn_and_steps (límites nativos aislados con leash=0, checkpoints y audio), test_sam_navigation_and_pose (regreso desde seis posiciones y recuperación de obstáculos).

## Restauración del alcance original

El círculo de 14m recortaba el rectángulo naranja: Sam nace en X=-33,92/Z=-53,99; la zona naranja principal ocupa X=-48,15..-22,64 y Z=-65,31..-35,16 (25,51×30,15m). Por ejemplo, X=-47/Z=-36,5 está dentro de naranja/verde pero a más de 14m de Sam; ese recorte inhibía la detección. Se desactiva el leash por defecto (0). Sigue disponible como ajuste opcional, probado explicitamente con14m.

Se comprobaron directamente las cajas del export WAR contra sam.json: green1/orange2/authorized1/hit2 coinciden. `IsWolfOutsideHitZone` usa XYZ, 200ms de gracia; `Sam::Update` hace volver a casa al salir Ralph de esa región y frena el movimiento si routeEnd sale de authorizedZoneBoxes XZ. No se encontró un radio fijo de persecución original. Naranja se evalúa únicamente cuando Ralph está dentro del verde; la segunda caja naranja del archivo queda fuera del verde principal.

Zona autorizada de movimiento: X=-46,69..11,81/Z=-73,63..-34,31. Zona del puente: X=4,56..9,55/Z=-32,78..-17,13. El borde de movimiento de Sam queda 1,53m antes del comienzo de esa zona. Se conservan las correcciones de navegación/regreso y WIN/sonido77.

Captura reproducible `validation/capture_sam_original_zones.gd` → `sam_original_zones_vs_14m.png`: verde proximidad del HUD; naranja condiciona detección dentro de verde; rojo región XYZ de Ralph que conserva persecución; cian movimiento XZ de Sam; blanco antiguo recorte circular; amarillo puente. Es proyección XZ, no promesa de visión ilimitada: altura, ruido, disfraz y cono de mirada siguen aplicándose.

## Pose de vigilancia durante la cámara de entrada

CIN00 empieza alrededor de0,2s y activa cinematic_controls_locked antes de que Sam termine START (0,44s). El bloqueo anterior detenía también el evaluador visual y la transición a HEAD2, dejando sus brazos en un fotograma intermedio. Ahora, mientras Ralph está bloqueado, Sam puede completar START y animar HEAD2/barrido de cabeza; sigue sin detectar, atacar ni navegar. Las demás animaciones de navegación conservan la pausa cinematográfica.

`tools/test_sam_intro_pose.gd` arranca Level01 sin saltarse la intro: comprueba el bloqueo real de CIN00, transición START→HEAD2, mano a la frente con las matrices originales, barrido activo sin desplazamiento, ausencia de ataque ante Ralph cercano y desbloqueo al terminar. 0 fallos.
