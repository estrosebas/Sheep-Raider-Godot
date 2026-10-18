# Nivel03: base original importada

Fuente: Lvl-03.war / Lvl-03.DAV / Lvl-03.SND / Lvl-03.MLT del PC original.
`scenes/levels/Level03.tscn` contiene mapa texturado y colisión persistidos para
navegar en el editor. F6 ejecuta esta escena; las puertas del laboratorio y
del plató la descubren por su nombre. En el plató exige completar02.

## Contenido y comportamiento ya conectado

- 85 registros de entidades,29 modelos de mundo,13 páginas DAV y7084
  triángulos de colisión. La conversión es la misma del00/01/02: X,-Y,-Z.
- 14 ovejas, Sam63 con30 trayectorias, zonas originales y2 checkpoints.
  Su lista de golpe es nula: Sam::PointInBoxListXYZ devuelve1 en ese caso;
  el adaptador conserva ese comportamiento en vez de impedir toda detección.
- Buzón79 entrega dinamita107 y cohete109. Buzón78 entrega elástico104.
  ACAISS01/model4 usa los contenedores colocados90/91 del buzón79: se
  caen desde las posiciones originales de sus contenidos107/109
  (21.11m/30.81m), a 8m/s como `box::Update`. Al aterrizar se
  mantienen cerrados sobre el balancín hasta el golpe de la roca55; la
  CIN1 los lanza y OPEN1 se ejecuta una vez al aterrizar. No se instancian
  cajas decorativas duplicadas ni se entregan los objetos prematuramente.
  El elástico104 usa el controlador compartido, modelo/icono originales,
  árboles98..101, retorno yo-yo, tirachinas de objetos y catapulta de Ralph.
  Los anclajes tendidos se conservan en el checkpoint.
  El panel de ajuste/medición de Suprimir queda archivado y comentado en
  Ralph; su HUD no se instancia en juego. El retorno después de colocar dinamita
  usa la rama original de interacción y conserva la mecha WAR de5s.
  La dinamita encendida sigue las plataformas móviles y resuelve la
  colocación al terminar PUT1A; la mecha/explosión usa su posición actual.
- 5 lechugas,4 carteles con textos de MLT79, reloj86 y meta123.
  La colisión del reloj acompaña su SnapToGround; el tramo del hueco de
  regreso usa la geometría visible para quitar una cara lateral invisible.
  La prueba `test_level03_clock_passage.gd` activa el reloj y recorre el
  pasadizo en ambos sentidos, conservando las caras exteriores originales.
- 3 balancines,2 rocas empujables,4 botones,2 elevadores y2 compuertas.
  Enlaces WAR:54→elevador56,58→elevador61,57→compuerta102,59→compuerta94.
  Compuertas reproducen MV_OPEN/MV_CLOSE y respetan la activación única.
  Las rocas85 que se rompen con dinamita usan el adaptador compartido.
- Música PC Mix Jami_v2, con límites de muestras originales del catálogo.
- Los modelos de objetos nuevos conservan sus páginas de este DAV; no se
  confunden con páginas del mismo número de Ralph o niveles anteriores.

## Lucas y cámaras

Se importan las siete CIN y sus actores, movimientos, animaciones y sonidos:

| CIN | Nombre original | Uso |
|---:|---|---|
| 0 | DAFFEXP | Lucas explica cómo esconderse detrás de rocas; voz26 |
| 1 | ROCK2C | Roca55 entra en BOX612 tras el envío: balancín y cajas90/91 |
| 2 | INTRO | Entrada del nivel desde ACTBOX622; después abre iris |
| 3 | DAFEXP2 | Reglas del ejercicio; voz27 y recordatorio34 |
| 4 | ROCKA | Misma roca sin envío solicitado: trayectoria sin cajas |
| 5 | STONEG | Cámara/acción de CinematicsManager desde ACTBOX624 |
| 6 | CINPANO | Cámara de CinematicsManager desde ACTBOX631 |

Lucas reutiliza la clase nativa DaffyLevel02, que en03 selecciona su variante
HiddenRocks. El controlador compartido recibe directorio, líneas114/115,
triggers y voces propios. Respuestas31/32/33 y fallos28/29/éxito30 no se toman
del tutorial del arbusto. Los menús, subtítulos y voces se localizan mediante
los bancos nativos existentes y overlays de este nivel.

Rock::StartLvl03Cinematic selecciona1/4 por MSG_MAILBOX_DELIVERED. Se conserva
CINE_NO_WOLF_FREEZE: Ralph puede moverse mientras corre la secuencia. Los
sólidos siguen las posiciones CIN y la cámara vuelve al jugador si sale de
BOX625. Las cámaras de ambas CIN tienen posiciones/ángulos constantes en
el PC original; no contienen una órbita360. El balancín52 tiene además
CamSetup600 para sus lanzamientos (CamShot permite cerrar la toma tras1s).
Las CIN5/6 sin pista de cámara conservan la vista actual.

En el balancín52, Ralph activa el lanzamiento de la roca60 desde la caja
original630. Al volver, el contacto descendente termina el arco de la roca
y conserva la velocidad de impacto antes de que Godot la anule contra la
tabla (`Rock::LAUNCHED` / `seesaw::AddBody`). Ese impacto lanza a Ralph por
la trayectoria589 hasta `(11.93, 10.87, -25.21)`, usando CamSetup600.

La detección de pasajeros reproduce `seesaw::OverlapXZ` sobre el volumen
del cuerpo: para Ralph se adapta al radio de su cápsula (.35m), de modo que
estar apoyado en un borde no lo excluya por tener el origen fuera de la tabla.
La velocidad vertical que aporta una tabla ascendente tampoco se confunde
con un salto del jugador. Durante el despegue se ignora sólo la tabla que lo
lanza hasta separar los pies .5m de su plano; esto adapta la colisión nativa
de la tabla y evita que la caja sólida de Godot cancele el arco al inclinarse.
El mismo patrón ya se usa al lanzar ovejas. El arco posee el movimiento de
Ralph hasta aterrizar; cerrar la cámara no vuelve a aplicar gravedad normal
durante el vuelo. Interrumpir/reaparecer restaura propiedad y colisiones.

CamShot usa un bloqueo específico de entrada (`launch_controls_locked`),
como el MSG_FREEZE nativo, en lugar de detener la física con el bloqueo de
cinemática. Al acabar el arco, Ralph cae hasta apoyar sus pies sobre el suelo
y pasa a LAND/IDLE; la toma se cierra automáticamente en ese aterrizaje.
Se conserva la salida manual tras1s. Esto evita quedar suspendido en FALL
encima de la plataforma final; el objeto elástico104 no tiene collider sólido.

Las rocas empujables comparten la comprobación de aplastamiento de
`Rock::CrushObjectsBelow`: una caja de 1m de altura bajo la roca, con
30cm de margen interior en X/Z. El descenso barre esa caja entre dos
fotogramas para detectar a Ralph durante el regreso de la roca60 desde
el balancín52. Se reproduce `SQUASH3` original (0.61s), se deja terminar
la caída de la roca sin apoyarse en la cápsula y se vuelve al checkpoint
con iris tras la animación más los 2s de `Wolf::Die(KILL_CRUSH)`. Al reaparecer se restauran
las colisiones. Una roca apoyada en el balancín no aplasta por ese contacto.
La CIN de la roca55 también comprueba la zona inferior como el C++ original.

Las ocho HiddenRocks35 usan el adaptador global OriginalHiddenRock y Ralph
dispone de COVER_ENTER/HIDDEN con las animaciones nativas HIDE1/HIDE2.
Ctrl y una separación de hasta10cm entre las cajas activa la cobertura;
la cápsula de Godot adapta el radio del Wolf original. HIDE1 dura1s y HIDE2
repite su pose. Al soltar el movimiento manteniendoCtrl sigue oculto; al
alejarse o moverse de lado vuelve directamente a SNEAK. Entrar no genera
alertas por ruido. Lucas y Sam comparten el test nativo IsOnSameSideAs:
la roca oculta frente al observador del lado opuesto, no al que la rodea.
Se conserva la cámara libre del port. El laboratorio añade dos copias del
modelo13 con la misma lógica para probarlo. Se cancela la cobertura al morir,
recargar o empezar una interacción/cinemática.
La entrada reproduce también COVER_APPROACH: durante HIDE1 Ralph se mueve
suavemente al centro de la cara seleccionada, que permanece fijada desde
la esquina de entrada. La cápsula conserva su tamaño y permanece fuera
de la caja sólida. Se ajusta sólo el desplazamiento visual del torso para
contactar con los triángulos inclinados reales de la roca (margen1,5cm),
evitando la separación que provocaba la cápsula más ancha. Salir o cancelar
restaura el origen de la malla; si otra colisión bloquea el centro, cancela
la cobertura sin teletransportar. El controlador se comparte con04 y laboratorio.
Se conserva la pose START al decodificar las animaciones parciales de Sam
para evitar brazos torcidos durante la entrada.

## Guardado y trabajo pendiente

Se reutilizan inventario, salud/caídas, colisiones, checkpoint, selección de
idioma, pantallas de carga, meta y guardado automático de victoria. Los
checkpoints también almacenan compuertas y secuencias ya vistas. Completar
la meta usa el mismo cierre suave con oveja y autosave de los niveles anteriores.

Las exclusivas siguientes tienen geometría, iconos y propiedades originales
extraídas: elástico/yo-yo/tirachinas y sus4 árboles de anclaje. No se consideran terminadas las
mecánicas de esos puzles sólo por importar sus modelos. La escena ya permite
recorrer el mapa y probar lo compartido mientras se implementan esos sistemas.

## Herramientas y pruebas

Pipeline: `extract_level_scene.py --all-animations`, `extract_level_runtime.py`,
`extract_level_goals.py`, `extract_imported_level_content.py`,
`localize_imported_level.py`, `configure_native_level_textures.py`,
`build_level_scene.gd`, `build_level_runtime.gd`,
`build_imported_level_content.gd` y `create_imported_level_scene.py`.
La localización sólo registra el nuevo nivel y conserva los overlays anteriores.

`test_level03_foundation.gd` comprueba mapa, spawn, IA, ambas entregas reales,
objetos originales, switches, reloj, música, idiomas y restauración del guardado.
`test_level03_tutorial.gd` prueba activación, ambas explicaciones, pregunta,
línea de inicio, voces de feedback, cubierta física y estado de las secuencias.
También se verifican los tutoriales del02, Sam del01 y el catálogo de cámaras.
`extract_level_scene.py --verify --all-animations --runtime-adjusted`
contrasta geometría, texturas, entidades y rigs con WAR/DAV, incluyendo la
convención del renderer y la pose parcial WIN de Sam heredada de PUNCH7.

`test_level03_rock_delivery.gd` verifica ambos disparos, posición/cámara
original, caída desde las alturas de contenido, entrega real sin bucles y
guardado de cajas en caída/cerradas y estado de roca.

`test_level03_seesaw_launch.gd` recorre la secuencia completa del segundo
balancín: salto desde la caja original, vuelo de roca, impacto de regreso,
lanzamiento de Ralph, llegada al destino y devolución del control/cámara.
Usa los callbacks físicos reales del nivel, sin avanzar el manager a mano.
`-- --free-camera --edge` descarta la cámara, mantiene a Ralph apoyado en
el borde de la tabla y comprueba trayectoria, salida limpia e interrupción.
La prueba exige además contacto real con suelo, regreso automático de
cámara/control y movimiento mediante Input después de aterrizar; no cierra
la cámara a mano para conseguir esos estados. Captura: `validation/level03_seesaw_landed.png`.

`extract_rock_crush.py` recupera SQUASH3 para el banco global.
`test_level03_rock_crush.gd` prueba el regreso real del balancín, márgenes
seguros, repetición de contactos, iris y restauración del checkpoint/cámara.

`extract_rock_cover.py` extrae los dos clips y documenta las reglas de C++;
`build_run_animations.gd` los integra al banco global usando la matriz ZXY
original. `test_rock_cover.gd` comprueba entrada/salida conInput real, pose
persistente, ambos lados de cobertura y los detectores reales de Lucas/Sam.
`test_cover_alignment.gd` prueba las cuatro esquinas, el desplazamiento
gradual al centro, la cápsula real, visibilidad, interrupciones y un centro
bloqueado por otro cuerpo. Con renderizador captura
`validation/rock_cover_corner_centered.png`.
