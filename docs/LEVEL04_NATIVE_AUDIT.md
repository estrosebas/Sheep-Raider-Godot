# Nivel 04: auditoría nativa previa al montaje

Fecha: 2026-10-16. Auditoría de solo lectura de PC `Levels/Lvl-04/Lvl-04.WAR`, `.MLT`, y `sdw-decomp/src/objects`. Los números de recurso siguientes son índices WAR; no confundirlos con los IDs exportados de listas de referencias.

## Inventario real del mapa

72 entidades, 13 ovejas. No contiene ninguna roca empujable class 16, balancín class 15, elástico class 42 ni árbol de elástico class 45. La roca de este mapa es otro mecanismo, `TriggedStone` class 52, con animación y botón.

| Recurso | Clase | Posición Godot en metros | Estado de reutilización antes de este montaje |
|---|---|---|---|
| 39 | SensibleButton 24 | (37.01, .39, -31.81) | OriginalPressureButton; necesita conectar destino nuevo 65 |
| 40 | Raft 53 | (-25.53, -1.02, -41.66) | Controlador compartido OriginalRaft con ventilador, corriente y carga |
| 42 | Sam 1 | (7, 0, -27.57) | OriginalSam para vigilancia; falta hipnosis de flauta |
| 43–55 | Sheep 11 | Nativas, distintas | OriginalSheep / OriginalFlock |
| 56 | Mailbox 4 | (1.38, 0, -13.31) | OriginalMailbox, entrega flauta 74 |
| 57 | Mailbox 4 | (5.02, 5.58, -22.15) | OriginalMailbox, entrega ventilador 71 |
| 58 | DaffyElf 55 | (16.84, -.48, 20.50) | Falta adaptación; no es DaffyLevel02 class 47 |
| 59,61 | Shark 50 | (-46.65,-9.49,-31.35), (-47.66,-2.95,-12.50) | Falta IA de tiburón y muerte equivalente |
| 60 | bull 43 | (-1.44,.67,-3.53) | Falta toro dormido/ruido/carga |
| 62,63,64 | HiddenRocks 35 | (10.88,.07,-29.99), (14.98,.22,-33.97), (10.99,.07,-37.97) | OriginalHiddenRock; conserva sus tres posiciones |
| 65 | TriggedStone 52 | (36.97,4.79,-27.34) | Falta mecanismo de roca activada |
| 66,68,69 | SignPostSimple 78 | Posiciones nativas | OriginalWorldNote e i18n |
| 67 | TimeKeeper 38 | (-16.46,19.05,-23.93) | OriginalTimeKeeper; altura exacta WAR, revisar apoyo/acceso al probar |
| 70 | Bush 48 | (-23.02,0,-34.01) | OriginalBush |
| 71 | Fan 7 | (10.82,13.01,-39.90) | FanItem, entregado por buzón 57 |
| 72,73 | HeapOfLeaf 54 | (-5.79,-.30,-2.14), (11.34,0,-5.68) | Falta suelo ruidoso por polígonos |
| 74 | Flute 41 | (7.13,17.92,-9.03) | Falta ItemCatalog 41 y poses/uso de flauta |
| 76,83,84,85,88 | Fish 162 | Nativas | Falta ciclo ambiental de nadar/saltar |
| 99 | Goal 23 | (2.02,0,.05) | OriginalLevelGoal, extracción suave, progreso y autoguardado |
| 109 | Leaf 191 | (.10,0,5.86) | Falta efecto de hoja ambiental |
| 38 | ObjectManager 184 | (-6.61,0,-20.77) | Lógica invisible; activa reloj67 al entrar en lista598 |

Además: 9 MiscStatic, 7 AmbientSoundManager, 4 CameraRestriction, 4 VisibilityManager, CheckpointManager102, CinematicsManager104, FogManager108. Los managers no deben mostrarse como objetos de modelo 10.

## Propiedades y comportamientos exclusivos

### Balsa: raft.cpp:89–274

RESET=0 en este mapa. Su caja local original es `[-125,-12,-135]..[124,8,191]`: 2.49 × .20 × 3.26 m. El suelo personalizado acepta ocupantes en su cara superior; traslada a todos con el delta de la balsa y notifica ancla a ovejas.

Implementado18/10 en `scripts/levels/original_raft.gd` con extracción reproducible `tools/extract_raft_mechanics.py`. Se sustituye el actor decorativo y su caja estática por un cuerpo móvil. Godot transporta a los personajes mediante su velocidad de suelo; los objetos siguen `OriginalMovingSupport` para evitar aplicar dos veces el delta. Fan::Blow acepta solape XZ y Raft::Update exige Wolf sobre cubierta. El controlador consume el pulso después de FanItem, conserva Y, resuelve paredes y desacelera al soltar. Datos nativos por mapa, ancla de oveja.5m, estela2s/.25s y guardado de posición compatible con archivos antiguos. `test_level04_raft.gd` cubre estas interacciones sobre geometría04.

Solo propulsada por ventilador si Ralph está encima: velocidad objetivo350 unidades/s =3.5m/s. `Math_ApproachLinear` usa máximo350, aceleración200 y deceleración200. Suma corriente obtenida de la zona de agua (flujo máximo2000, aceleración50, deceleración100). La espuma sale por las esquinas. Cambia STAND1→ACTION1 cuando cambia la cantidad de ocupantes; vuelve a STAND1 al terminar. No equivale a una plataforma fija ni a una decoración.

FanItem ya transmite `on_fan_blow` a grupo `fan_targets`, por lo que puede reutilizarse esa interfaz. Es necesario mantener el ventilador montado correctamente en Ralph.

### Roca activada: triggedstone.cpp:90–244

Botón39 TARGET=478, que referencia entidad65. Roca65:
- CRASHINGZONE=548, IDCAMERA=541, TIMER=1000ms.
- Caja local `[-75,-180,-75]..[75,-30,75]`: 1.5³m.
- Cámara541: focal675, rotación nativa[170,1712,0], ojo[4117,-345,3810].
- Caja de aplastamiento548 original: min[3597,-359,3097], max[3797,-34,3284].
- Reposo STAND1; pulsar inicia espera, tras 1000ms FALL1; desde 11/16 de su duración mata Ralph, Sam u oveja dentro de la caja; finaliza con EXPLOD1 y luego STAND1.
- La cámara se toma si Ralph figura entre ocupantes del botón; soltar libera cámara y rearma; no dispara continuamente mientras se mantenga pulsado.
- Usar nombres de animación: los índices de lista de este WAR no coinciden necesariamente con valores globales del enum.

Revisado18/10, Sam::KnockOut (0x46b581) carga DEATHDURATIONMS de prop0x20:3000ms en04. SAM_STT_KNOCKEDOUT reproduce `SQUASH` (1,65s) una vez, luego `SQUASH1` en bucle con el contador3s y `SQUASH2` (3,83s) una vez; sólo al terminar llama SetGoalWolf/SAMU_START_SEARCH. Total8,48s desde el último KILL_CRUSH, más cuantización de fotograma. TriggedStone::CrushVictims renueva ese mensaje cada frame de impacto de FALL1; se conservó ese refresco para Sam. Se reemplazó el antiguo límite global3s que omitía las fases.

El modelo16 contiene120 triángulos:60 pares geométricamente coincidentes con orden inverso, colores/UV diferentes para exterior e interior fracturado. El shader bilateral mostraba las caras oscuras interiores encima de las exteriores. La variante opaca cull_back se limita a TriggedStone; mantiene ambas caras, geometría, UV y DAV5. Verificado con capturas de la cámara541. La malla animada supera el AABB genérico±4m (impactoZ=-5,60m, fragmentaciónZ=-7,27m en muestras); se calcula su AABB desde la pose evaluada para evitar desapariciones por descarte de cámara.

### Toro y hojarasca: bull.cpp, heapofleaf.cpp

Toro60: ASLEEP=1; ACTIVATIONBOX545, MOVEMENTBOX546; WAKEUPSPEED100. Despierta si Ralph hace ruido dentro545 o está a menos de200u=2m; MSG_LOUD_NOISE también lo despierta. Reproduce UP1A y carga al terminar. Velocidad normal800u/s=8m/s, algunas ramas usan1100u/s. No debe perseguir fuera de su zona de movimiento sin retorno/idle apropiado. Sus propiedades SHEEPBOX/SHEEPTRAJ/SHEEPCAM/NORETURNBOX/REDOBJECTS son0 en04: no importar lógica de otros niveles que no aplica aquí.

Hojarasca72 usa polígono ID533 (37 puntos);73 usa534 (24). Ambos GLOBALZONE565, guardian473→Toro60. Usa punto en polígono XZ y diferencia vertical<60u=.6m; consulta MSG_QUERY_MOVED a Ralph/oveja/toro. Al movimiento emite ruido129 (`S04FEMOR`) y hojas, avisa al toro. No asumir que cualquier posición de un gran AABB hace ruido: los polígonos son irregulares.

### Flauta e hipnosis: flute.cpp y sam.cpp:2426–2473,2847

Buzón56 O1=487→Flute74, cámara540, timer2300ms. Buzón57 O1=484→Fan71, cámara539, timer2700ms.

Flauta: WORLD/HELD/PLAYING; recoger usa anim LINK, mundo OBJET. Tocando: bucle sonido37 (SND_FLUTE_TUNE), partículas de notas, estados Ralph FLUTE_IDLE/FLUTE_WALK y200u/s=2m/s. No sirve dejar descanso normal de brazos: hay animaciones FLUTE1/WALKF1/STANDF1 en sus modelos.

En PLAYING renueva MSG_SAM_INVESTIGATE a Sam a<=300u=3m y muestra su proximidad normalizada0..65535; apunta notas hacia Sam si<=2000u=20m. Broadcast de ruido600u=6m.

Sam hipnotizado refresca timer1000ms, usa HYPNOS* y mueve200u/s=2m/s hacia el punto de flauta, se detiene a<200u=2m o al salirHYPNOTIZEDZONE544. Expirar vuelve a retorno normal. INVESTIGATE de ruido del port existente no es esta lógica completa.

**Corrección de interpretación:** MODE Sam04=16384=`SAM_MODE_NO_JUMP`0x4000, no patrulla. PATROL es bit bajo1, dentro máscara0x3ff. Aunque existe trayectoria530 (10 puntos), el estado inicial nativo es LOOKAFTER vigilante fijo. Mantener ese inicio.

### Tiburones: shark.cpp:165–468

Shark59: BOX547, TRAJ531 (12 puntos);61: BOX579, TRAJ535 (12). Ambos DETECTHEIGHT360u=3.6m, DETECTRANGE640u=6.4m, BOOLWATCHOVERCAVE=0. Patrulla350u/s=3.5m/s; apunta2000ms, preparación STAND2, embiste900u/s=9m/s hacia la posición capturada, muerde dentro160u=1.6m con KILL_SHARK5. Regresa nadando al inicio de embestida y continúa ruta.

No usar temporizador de pirañas del nivel02 para este mapa. El C++ de UpdateAi usa un umbral literal9600 en la prueba inicial de distancia además de la altura y BOX; no sustituirlo sin revisar por DETECTRANGE640 como si todos fueran equivalentes. Conserva burbujas profundas y estela de aleta al estar a150u de superficie.

Implementado18/10 en `scripts/actors/original_shark.gd`, con datos de `tools/extract_shark_mechanics.py`. Dos rutas y cajas WAR independientes, cajas trasladadas sin rotación, animaciones SWIM3/STAND1/STAND2/SWIM1/EAT/ATTACK1/HIT1/BRAKE/LOOK, sonidos nativos y sprites IGLBULL/IGLTIDE. Wolf EAT se extrajo a `ralph_shark_data.json`: KILL_SHARK5 copia origen y rotación de Shark; ambos EAT duran5,07s. Sonidos de la pista Shark:138 en0,30s;136 en2,24s;74 en2,89s. La cámara fija busca una vista sin pared con el adaptador compartido. Reset conserva trayectoria y estado, y sólo limpia efectos/biteAccepted. El regreso conserva el divisor nativo wolfDist; se limita el último paso a la distancia de embestida realmente recorrida para evitar sobrepasar el origen por delta variable.

### Lucas elfo y cinemáticas

DaffyElf58 class55, CINE2, CINEBOX583, FLAGS34, CINESHEEPBOX583, CINETEXT0, ANSWERTEXTINDEX1, ANSWERNUMBER2. Mira a Ralph, activa cine al entrar en cajaXZ cuando no hay otro activo y después ofrece hablar.

MLT español banco56:0 introducción;1 pregunta;2 opción flautas,3 explicación;4 opción mapa,5 explicación. Voces respuestas53 y11. Cine2 voz52. No reutilizar banco48 ni parámetros del entrenamiento de arbusto/rocas47. Cine1 tiene3 tracks y voz0, manager104FLAGS42; cine2 tiene3 tracks y voz52.

Audio verificado: `cinfl_lvl0401.wav` español dura 63.4819375 segundos y sus primeros 16.01 segundos son silencio original antes de la primera frase. La página inicial `$175$` también está vacía. No recortar ese comienzo ni adelantar la voz. COME1 no tiene señales de sonido en WAR. Revisado el18/10: daffyelf.cpp::Update sólo ejecuta Sound_Play(SND_FLUTE_TUNE,volume0x7f,SNDF_POSITIONAL) en WATCH, al terminar la cinemática; WAIT_CINE_BOX y CINEMATIC no lo ejecutan. El soundHandle permanece no nulo al finalizar el clip: reproduce una sola vez por entrada en WATCH, no en bucle. SetState detiene y limpia ese handle al entrar en diálogo/respuesta. Se retiró la reproducción37 forzada por COME1 porque era una inferencia incorrecta del port, no una pista nativa.

SignPostSimple banco79:
- index0: cómo nadar, salto sube y correr baja.
- index1: este botón puede resultar útil.
- index2: no despertar toro durmiente.
- index3: pasadizo secreto sin secreto todavía (texto existe en banco, sin un letrero con ese índice entre las entidades iniciales).

### Ambientales y controles ya reutilizables

Fish162: nadan250u/s=2.5m/s en dirección por cuadrante yaw, disparan salto al superar DISAPPEAR_DIST (1000,2000,1600,2000,1700u); SWIM→SWIM3→SWIM2, vuelven a origen al estar fuera de pantalla dos frames. Leaf109RANGE900u=9m, FLY con reinicio aleatorio750–2250ms, posiciónXZ aleatoria ±9m alrededororigen.

Agua: cuatro cajas de zona54; las mecánicas compartidas de nadar/subir/bajar ya existen en OriginalWaterMotion. Activar el proveedor de zonas sin habilitar muerte por pirañas exclusiva02.

Cuatro checkpoints nativos en manager102: entrada553/respawn554;555/556(oveja557);559/558(oveja560),yaw90;561/562,yaw180. OriginalCheckpointManager/ImportedCheckpointSave ya cubren el formato.

## Límites de esta auditoría

Esta lista refleja la base anterior al trabajo paralelo actual. Importar un modelo y sus animaciones no convierte por sí solo las clases nuevas en mecanismos jugables. No se modificaron assets ni scripts desde esta auditoría. Las distancias se convierten a metros con factor.01 y los puntos originales pasan[x,-y,-z]. El objetivo es distinguir una base lista para pruebas de un nivel ya completado.
