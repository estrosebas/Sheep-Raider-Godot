# Tutorial de Lucas: arbusto

El checkpoint del avance anterior es `0e698b4`. Esta implementación adapta
`sdw-decomp/src/objects/daffylevel02.cpp`, no los diálogos del nivel 01.

- Entrada: ACTBOX 601 del WAR, después de la piedra. CIN01, voz BSV14,
  texto MLT48[0]. Incluye APPEAR1 y la demostración del arbusto.
  El port anticipa esta entrada al corredor tras la roca (X 8.5..20,
  Z -54.3..-40), para no exigir acercarse al NPC.
  intro_clearance añade 2 m al disparador anterior de X 6.5; se aplica
  también al ACTBOX original y espera a terminar el empuje/animación de manos.
- Pregunta original MLT48[2]: aceptar reproduce CIN02, voz BSV15,
  MLT48[1]. Rechazar permite continuar y volver a preguntar con E.
- Ejercicio: salida ACTBOX599, llegada ACTBOX600, zona ACTBOX598.
  Lucas barre la cabeza ±70°, a 500 unidades angulares por segundo;
  el cono de detección es de 56 unidades sobre 4096.
  Adaptación para cámara manual: a 1.5 m de la caja de salida empieza una
  vista previa del barrido. Sigue moviéndose sobre la línea y conserva su
  fase al salir; la detección sólo se evalúa fuera de la caja de salida.
  El original detenía el barrido dentro de esa caja.
  El cono y el retrato consultan el forward evaluado del joint4, incluido
  el giro de sus padres y la reflexión de exportación. Así la dirección
  visible del pico corresponde al test angular, con semiancho 56/4096.
  El oído se adapta por estados de locomoción y velocidad horizontal;
  la velocidad vertical residual estando quieto no produce ruido falso.
- Fallos: ruido 0203, moverse escondido 0204, quedar visible 0205,
  no usar disfraz 0206. Éxito 0207 con OK1. Recordatorio 0208 y espera
  en la salida de 7 segundos (3 tras ciertos fallos), 0209.
- Después del éxito: menú original MLT48[10], opciones [11,13,15],
  respuestas [12,14,16] y voces 0212, 0210, 0211B.

Los textos y voces usan los idiomas existentes (es/en/pt_BR/it). Las
cinemáticas conservan las pistas originales de cámara, animación y sonido.
Los indicadores usan ATEROB01 y los colores originales compartidos con Sam.
Se reutilizan OriginalNpcConversation, OriginalLevelSequence, OriginalTextBox,
OriginalLevelDialogue, GameLocalization y ImportedCheckpointSave. El estado
de introducción, explicación y reto superado se conserva con el checkpoint;
reiniciar el nivel lo vuelve a habilitar. No se añade guardado automático.

Adaptación deliberada: el arbusto conserva la regla del port de ocultar a
Ralph cuando está quieto. El feedback congela las acciones sin quitárselo.
Los controles de los textos se traducen a E/Ctrl mediante el HUD compartido.
El recurso 90 es un doble cinematográfico de Lucas con arbusto; permanece
oculto durante el juego. Los recursos 86/87 son las líneas blancas animadas.

Reconstrucción: `extract_level02_tutorial.py DECOMP GAME`,
`extract_localization.py GAME`, importar en Godot y ejecutar
`build_level02_tutorial.gd`. Validación: `test_level02_tutorial.gd` y
`test_level02_foundation.gd`; `-- --capture` genera capturas en user://.

## Entorno y correcciones del nivel

`OriginalLevelEnvironment` carga `environment.json`: zonas de agua del WAR,
contacto del balancín, trayectorias y cajas de impulso. El contacto original
del balancín tiene flag especial 1, que el importador estático descartaba.
Se reutiliza `OriginalSeesaw` para su colisión y movimiento.

Las pirañas usan PIRANA2 al nadar, la trayectoria original de cuatro puntos
al saltar y PIRANA3 en el tramo de superficie. Velocidad nativa: 500 unidades
por segundo (5 m/s). Sólo una ataca; espera 1000 ms y reproduce PIRANA1 junto
a la animación PIRANA1 de Ralph, extraída a `ralph_water_data.json`.
Las zonas de agua tienen prioridad sobre el detector de caída al vacío.
PIRANA1 de la piraña lleva los eventos de audio: 77 a 1.50 s y 138 a 2.34 s.
El controlador los ejecuta al cruzar cada marca de tiempo de la mordida;
PIRANA1 de Ralph no tiene eventos y no debe usarse como fuente de esos sonidos.

El río desplaza las ocho regiones originales del atlas DAV. El chapoteo usa
sprites originales IGLTIDE; sus emisores se adaptan a las intersecciones entre
la geometría y la superficie del río (no son coordenadas de emisores nativos).
Las lechugas conservan posición y rotación de entidad originales, con el rig
completo y la convención de huesos ZXY/signos [1,1,-1].
Su pose de spawn/reposo/reaparición es OBJET, como Salad::PostLoadInit y Reset;
STAND inclinaba el joint de las hojas hasta dejarlas de canto. La altura del
visual plantado se calcula sobre OBJET, sin añadir un ángulo artificial.

El perfume consulta los ventiladores activos para que el orden de actualización
no anule el viento; conserva el alcance, cono y carga de `ItemRules` y la
respuesta compartida de `OriginalFlock`. La cámara de muerte se separa del
SpringArm durante la caída directa y recupera su padre al reaparecer.

Reconstrucción adicional: ejecutar `build_run_animations.gd` tras la extracción.
Validación de estas correcciones: `test_level02_environment.gd`, incluida una
prueba física del balancín, la cámara y la reacción real del rebaño al perfume.

## Botones y elevador

`switches.json` conserva la lista WAR 475: botón 45 -> elevador 47.
`OriginalPressureButton` arranca en OFF (levantado), pasa a ON mientras hay
ocupantes y vuelve a OFF al salir el último. Usa el volumen original y el
sonido SBONMBTN (54); no se añade una acción E para pisarlo.
`OriginalWoodenLift` reemplaza la decoración y su colisión estática por un
cuerpo móvil: endpoint 580 -> Y 5.8 m, velocidad 4*30 -> 1.2 m/s,
sonido SPFASCEN (94). La plataforma lleva a Ralph mediante la física de Godot.
Los controladores son compartidos; los vínculos y medidas vienen de cada nivel.

`Sheep::ThinkThisFrame` reparte las decisiones por índice dentro del segundo.
Se adapta a un turno por oveja cada segundo, sin atarlo al framerate de PC.
`FindNearestAttractor` usa radio 600 (6 m), altura +/-150 (1.5 m), una reserva
por botón y penalización de puntuación 720000 (72 m²) frente a la comida.
La oveja termina su animación de interés antes de caminar a 2.5 m/s, llega
al centro (`BUTTON_WALK`, distancia final 0) y permanece en STAND2 sin comer.
No existe una espera fija de varios segundos antes de buscar un botón.
Tras detectarlo se ejecutan ATTR_TURN (WALK1 quieta), ATTR_LOOK (STAND2)
y ATTR_WALK (WALK3) antes del último metro BUTTON_WALK (WALK1). Cada espera
depende de terminar su clip a la velocidad aleatoria nativa; no es un timer
inventado. La traslación sigue a 2.5 m/s aunque varíe la velocidad de animación.
Los tipos HIDDEN (12) y NO_SHEEP (14) conservan sus excepciones originales.
Prueba: `tools/test_level02_buttons.gd` incluye pulsación, liberación, recorrido,
pasajero real, acercamiento de oveja, altura/radio y prioridad de la lechuga.

## Reacción al perfume

`OriginalSheepScent` comparte los estados nativos SCENT_TURN/SNIFF/WALK:
STAND2 para girarse, SMEL1 para olfatear y WALK2 para acercarse a saltitos,
con velocidades de animación 16..20/16, 16..20/16 y 12..20/16. El avance
físico conserva 250 unidades/s y el radio final de 80 unidades. No come
el perfume ni reproduce el sonido de comer lechuga. Las ovejas del lab
usan el rig completo de AMOUTO01, en lugar del recurso con sólo STAND2.

Perfume conserva el reporte nativo de oveja/proximidad durante 0.5 s
(0x800), el ventilador lo consulta y el HUD compartido muestra el crayon
y el icono original de oveja. Usa los mismos colores y transición que el
indicador original de objeto; la estela por sí sola no activa ese reporte.
`test_perfume_reaction.gd` verifica animaciones, movimiento, feedback y
desaparición del indicador tanto en el nivel como en el laboratorio.

Se corrige también la posición de origen de las ovejas importadas: se
registra después de asignar el transform del WAR, incluso si el primer
raycast de suelo falla antes de registrarse las colisiones en física.

## Agua compartida

`OriginalWaterMotion` adapta WaterSinkStep/SwimMove/SwimStateStep y consulta
proveedores del grupo `water_regions`. La física de nado no depende de las
pirañas: entrada y frenado de inmersión, reposo SWIM2, movimiento SWIM3,
agua poco profunda SWIM1/SWIM4, subir con salto, bajar con carrera y salto
desde superficie. Offset de superficie: 90 unidades; perfil normal 8:
velocidad 300, aceleración 1000, velocidad vertical 300. Pitch hasta +/-45°.
Las cuatro animaciones y el loop 35 se extraen del juego original.

Adaptaciones: física de Godot; el nado del nivel 02 permite superficie aunque
las zonas nativas tengan flags especiales de hundimiento. Las variantes de
agua congelada/corrientes requieren su adaptador de zona al montar esos mapas.
El peligro de nivel 02 espera un segundo real en el estado de agua sin
congelar a Ralph antes de PIRANA1. Al morder se separa la cámara del SpringArm
y se encuadra a 4 m de distancia/1.6 m de altura; el respawn restaura la cámara.

## Colocación en el balancín

El bloqueo de input durante THROW_PLACE no elimina el peso de Ralph.
`OriginalSeesaw` conserva contacto y altura del personaje inmóvil, adaptando
MSG_SEESAW_TOUCH; sólo excluye muertes/objetos lanzados. El probe para objetos
pequeños despeja el volumen respecto a la normal del suelo inclinado y devuelve
el soporte. `OriginalMovingSupport` conserva la posición local del objeto
colocado sobre el balancín/elevador hasta recogerlo. No se excluye la tabla
de las pruebas de obstrucción: siguen rechazándose paredes y falta de suelo.
`test_seesaw_placement.gd` verifica ambos extremos inclinados, peso durante
el bloqueo de acciones, colocación y seguimiento de la lechuga.

Las lechugas y perfumes desplegados crean automáticamente `MovingSupport`,
incluso al cargar un objeto sin vínculo previo. Después del movimiento de las
plataformas, un raycast corto comprueba el apoyo y ajusta el pivote al suelo.
Si no hay apoyo, cae con aceleración 15 m/s² y límite 20 m/s, con un raycast
que cubre el desplazamiento del frame. Los personajes quedan excluidos como
soportes. Recoger, consumir o restaurar el objeto elimina este seguimiento.
Son valores adaptados para los objetos colocados del port.

Balance del port para cámara manual: `data/port_balance.json` establece
`sam_chase_speed_multiplier: 1.15`. Sólo la persecución de Sam del nivel 02
pasa de 11 a 12.65 m/s. El controlador compartido conserva multiplicador 1
por defecto; vigilancia, investigación, retorno, radios y zonas no cambian.
Este ajuste es deliberado y no altera los datos extraídos del original.

Controles de agua del port: Espacio sube, Shift baja; no se convierte la
pulsación en un salto al tocar la superficie. La entrada desde altura conserva
la velocidad previa a `interrupt_actions`, frena hasta 20 m/s y permite la
inmersión. El límite de superficie afecta sólo a la subida; el fondo del
volumen limita la bajada para conservar el estado durante la espera de pirañas.
La prueba de entorno incluye caída con velocidad 30 m/s, ataque al segundo
y entradas reales de las acciones de subir/bajar.

## Haces de luz sin colisión

La reconciliación de paredes/techo `OriginalVisualCollision` toma sólo superficies
sólidas y excluye `retro_add` (luz/efectos aditivos). Antes usaba Mesh.get_faces()
sin filtrar y añadía haces decorativos al collider de Ralph y de la cámara.
La geometría visual sigue renderizándose íntegra. La prueba
`test_level02_light_collision.gd` cruza 36 triángulos de luz del inicio con
raycasts en ambas capas y comprueba que techo opaco y suelo conservan colisión.

## Atajo del tronco junto a la roca inicial

`StartPassageBoundary` añade dos laterales y un límite superior invisibles
en X 5.2/Z -45.1, centrados en la posición original de Rock_49. Conserva un
paso central de 2.1 m de ancho y 2.2 m de alto: la roca lo bloquea hasta
moverla, pero no puede saltarse por el tronco lateral ni por encima.
La capa 8 sólo la consulta Ralph; cámara, piedra y NPC mantienen sus capas,
para no bloquear los dos ejes originales de empuje o limitar la cámara libre.
Es una adaptación de límites del port, no un collider recuperado del WAR.
La prueba `test_level02_start_passage.gd` verifica laterales/altura, piedra
bloqueando el centro y cápsula real de Ralph atravesándolo tras moverla.

## Acceso al reloj y cámara de agua

WoodenPlatForm_46 aplica el peso original: vacío vuelve a Y -0.39, oveja
elige el punto medio, Ralph/roca baja a Y -3.8, velocidad 5*30 = 1.5 m/s.
La lista WAR 501 enlaza SecretDoor_73; al bajar la plataforma la puerta
sube la misma distancia, tanto visual como collider. Rock_48 puede caer
sobre ella y mantener abierto el pasadizo. Antes ambas eran decoración
con colisión estática. `OriginalWeightedPlatform` adapta esa lógica compartida;
la altura se incluye opcionalmente en el checkpoint para conservar el mecanismo
al cargar archivos nuevos, sin invalidar partidas anteriores.

El plano de mordida evalúa ocho orientaciones y tres alturas con raycasts
en capas de mundo/cámara y comprueba el volumen de la cámara. Si una pared
interrumpe el plano, se acerca desde el lado visible; no atraviesa el muro.
El encuadre permanece fijo durante la animación y se restaura en respawn.

El menú resuelve CheckpointSave al abrirse y al guardar: _ready del menú
se ejecutaba antes de crearse ese nodo y guardaba null, rechazando ranuras
aunque existiera un checkpoint válido. `test_water_clock_manual_save.gd`
prueba cámara obstruida, roca cayendo sobre plataforma, pasadizo liberado,
recolección del reloj, restauración del mecanismo y guardado/reescritura
desde el menú real del nivel 01, también después de completar la meta.

El balancín incluye las ovejas sueltas del mismo nivel como cuerpos de carga.
Sheep::PostLoadInit fija peso 40; Ralph pesa 60 y las rocas de tutorial 120.
El adapter anterior sólo pasaba a Ralph a step y omitía todas las ovejas.
Se excluyen ovejas cargadas o muertas, y se exige apoyo físico próximo a la
superficie. `test_level02_sheep_seesaw.gd` verifica contacto, inclinación en
ambos extremos, soporte al girar, exclusiones y retorno sin carga.

Las rocas empujables también se pasan al balancín con peso 120. Antes el adapter
sólo lanzaba a Ralph y dejaba la roca como un cuerpo sin enlace al mecanismo.
Rock::ApplyGravity usa aceleración 4000 u/s², velocidad 200..3000 u/s
(40 m/s², mínimo 2 y máximo 30 m/s), tanto al caer como al empujar.
En ON_SEESAW la roca conserva apoyo/posición horizontal y no se empuja;
un aterrizaje de Ralph en el extremo opuesto desde la caja de impulso original
activa la trayectoria de tres puntos del WAR. La trayectoria izquierda devuelve
la roca hacia la cornisa de partida. LaunchArc usa el mismo tiempo 1.024 s.
Rock_44 tiene RESET=1 y vuelve a su origen al reset de checkpoint si se pierde;
Rock_48 (peso que abre el reloj) conserva RESET=0 y no se reinicia por ese motivo.
`test_level02_rock_seesaw.gd` verifica caída, carga, impulso contrario,
recorrido de retorno y recuperación; la prueba del reloj se mantiene válida.

## Lanzamiento de la oveja hacia la meta

`OriginalSeesaw` recoge cuerpos por proximidad al plano (-20..50 unidades
originales), sin depender del `is_on_floor()` del fotograma anterior. La oveja
recibe el ajuste de apoyo en la esquina más alta de su caja de 70x80x70,
equivalente a `MSG_SEESAW_TOUCH`; el cálculo del plano coincide con el collider
inclinado y su desplazamiento local. El golpe de una roca conserva la velocidad
entrante antes de ajustar su apoyo, incluso si el contacto del balancín ocurre
antes de que CharacterBody registre el suelo.

El adaptador ahora envía el lanzamiento a la oveja, además de Ralph y las rocas.
`SHEEP_ST_LAUNCHED` (fila 32 de `g_sheepStateTable`, `sheep.cpp`) usa STAND1;
durante la trayectoria se suspenden gravedad, atracción e interacción. Conserva
la parábola nativa de 1.024 s y las colisiones del escenario. La excepción de
colisión con la tabla sólo dura hasta separarse de ella. Como en `seesaw.cpp`,
un impacto de Ralph produce un salto vertical de 3 m; la roca dispara la
trayectoria WAR completa. En el extremo derecho termina aproximadamente en
X -21.4 / Y 8.91 / Z 22.65, dentro de Goal_110, donde espera a Ralph.

Se mantiene el peso original 40 de la oveja: sola inclina parcialmente la tabla
según su distancia al pivote; no fuerza siempre el límite de 15 grados. El
impacto y el peso 120 de la roca completan el movimiento del mecanismo.
`test_level02_sheep_seesaw.gd` prueba el puzle completo con el procesamiento
automático del entorno: oveja apoyada, roca cayendo desde la altura de su
cornisa, lanzamiento y aterrizaje real dentro de la meta, salto vertical y
limpieza de estado al reiniciar el checkpoint.

## Ovejas y arbustos; cierre y guardado automático

El radio de búsqueda nativo del arbusto era600 unidades (6m). El port lo
reduce a2.5m, configurable en `OriginalBush.sheep_detection_radius`, para
equilibrar la cámara libre. Tanto selección como reserva se miden desde la
oveja, sin heredar el origen de la última lechuga. La aproximación usa los
estados nativos ATTR_TURN/ATTR_LOOK/ATTR_WALK (WALK1, STAND2, WALK3); EAT_BUSH
se detiene a120 unidades (1.2m). El laboratorio también selecciona WALK3,
para no desplazar una oveja con su pose de reposo.

El cierre del tutorial y niveles01/02 comparte `OriginalLevelCompletion`.
La oveja se deposita mediante PUT2A/PUT2B antes del fundido, con una interpolación
final que elimina el salto del enganche de la mano al suelo. Después se guarda
la victoria en `user://saves/autosave.json`, con checksum y respaldo rotativo.
La fila Guardado automático aparece arriba de las tres ranuras manuales;
puede cargarse pero no sobrescribirse desde Guardar. El arranque restaura el
archivo válido más reciente, incluidos niveles superados y relojes. Las
pruebas `test_bush_sheep_range.gd` y `test_victory_autosave.gd` verifican el
radio real/reservas, la animación, los tres goals, guardado/carga por el menú
y que las ranuras manuales permanezcan byte por byte iguales.
