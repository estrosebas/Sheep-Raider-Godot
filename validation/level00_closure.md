# Cierre del nivel 00

## Cohete

La inclinación ya no cambia instantáneamente al invertir A/D. `RocketItem` usa los límites del perfil normal **9** de `g_wolfMoveProfilesNormal`: **1024** unidades angulares/s y aceleración **2048** unidades/s². El balanceo de `Wolf::RocketFlyStep` sigue esa velocidad angular y pasa gradualmente por cero al cambiar de dirección. Se conserva solo el eje Y invertido: W baja, S sube.

Al terminar voluntariamente, agotar combustible o perder integridad, se retira del inventario/equipamiento. `Wolf::Update`, estado ROCKET_FLY, hace `Inventory_Remove` y envía `MSG_DROP(placed=1)`; `Rocket::HandleMessage/Update` reproduce **AFUSEE01 CRASH1** (.89 s), sonido **68** a .05 s, oculta el objeto y espera **0x3000/4096 = 3 s** antes de volver al punto de entrega. El port reproduce ese descarte, sonido, espera y regreso físico con combustible/integridad restaurados; volver a recogerlo es necesario. No se devuelve automáticamente al inventario. La oscilación de aparición posterior del motor original aún no está adaptada.

El efecto y sonido son compartidos. `extract_puzzle.py --verify` confirma que `assets/items/audio/rocket_crash.wav` conserva los bytes originales de SND 68.

## Ayuda y colocación

Las leyendas superiores del HUD y los textos auxiliares inferiores del inventario arrancan ocultos. **H** alterna ambos; las nubes/iconos del inventario y los diálogos originales siguen visibles cuando corresponde.

En el nivel 00, `allow_world_placement=false` desactiva Q y rechaza llamadas a `GameItem.place_in_world`. La configuración es por nivel para conservar las mecánicas de objetos reutilizables en los futuros niveles y el laboratorio de desarrollo. Cargar/dejar la oveja con E sigue disponible, pues es necesario para la meta.

## Caída y reinicio

- Ralph consulta el suelo por raycast en cada paso, también durante salto, vuelo y transporte. Se excluye la oveja cargada. La consulta empieza .5 m encima de los pies para evitar falsos vacíos durante la recuperación de penetración al aterrizar; tiene una breve espera inicial mientras Godot registra las colisiones.
- Si no hay suelo bajo la caída, o está a 30 m o más, caminar/descender y terminar el cohete llevan al mismo estado PIT_FALL. Los saltos ascendentes y trayectorias de catapulta pueden completar su ascenso. Si hay terreno próximo, se mantiene una caída/aterrizaje normal.
- Carrera en el aire: límite original de `Wolf::InitMoveConfig`, parámetro **8 = 0xc00/4096 = .75 s**. Superarlo inicia la caída incluso si se continúa pulsando Shift. Es una adaptación más estricta que el C++, que primero quita la carrera y espera que la desaceleración baje la velocidad. Al volver a tener terreno se vuelve a RUN y un futuro hueco tiene un nuevo presupuesto.
- Caída al vacío: **ACOYOT01 STRIKE2**, duración **5.36 s**, sonidos **78/81**, cámara inmóvil que gira ligeramente hacia delante de Ralph y movimiento visual del esqueleto original. Se utiliza también al caer cargando la oveja; esta vuelve a su punto de inicio. No se reemplaza esa pose por una animación inventada ni se teletransporta al personaje bajo y=-30.
- `Wolf::Die` espera la duración de la animación más **0x2000/4096 = 2 s**. `Fade_StartRestart/Fade_Update` oscurece únicamente durante el último segundo; el checkpoint se restaura completamente cubierto. `Wolf::Reset` aplica luego `Fade_StartOut(0x1000)`: un segundo de entrada. `OriginalRestartFade` replica los niveles de opacidad 0..31 → ARGB4444 de `Fade_DrawOverlay`.

## Validación

Corrección posterior de RUN_AIR: los **.75 s** del parámetro 8 limitan el impulso, no ordenan muerte inmediata. Como en `Wolf::Update/ScnControllable::SteerRun`, se mantiene altura mientras se frena a **12 m/s²** desde **12 m/s**; se decide FALL/STRIKE2 solo cuando la velocidad es inferior a **6 m/s**. Partiendo de máxima velocidad y manteniendo las pulsaciones hasta el corte, el tiempo aéreo total ronda **1.25 s**, con unos **13.5 m** de recorrido. El estado RUN_AIR sigue gestionando el suelo por su cuenta: el raycast genérico no cancela esa fase. Esta corrección sustituye la adaptación estricta descrita arriba. `test_air_run_braking.gd` recorre físicamente un hueco de **12 m**, llega a la plataforma opuesta durante el frenado y vuelve a RUN; `test_air_obstacles` comprueba también altura tras .75 s y muerte al agotar velocidad.

Coyote time solicitado: `RalphController.coyote_time` da **.18 s** desde que se pierde el suelo para iniciar el primer salto, con su altura completa y el segundo salto aún disponible. Se consume al saltar y se limpia al morir, reaparecer o interrumpir acciones. El raycast no inicia muerte durante ese margen; al expirar conserva el flujo normal de caída. No habilita salto durante carrera/frenado ni añade saltos extra. `tools/test_coyote_time.gd` comprueba salida de una plataforma física, salto tardío, segundo salto y expiración sin salto: **0 fallos**.

Corrección del doble salto: la decisión de vacío se hace después de leer Espacio. El primer salto reserva un margen acotado de `JUMP_DURATION + DOUBLE_JUMP_DURATION` (.612 s) para pulsar el segundo incluso después del primer ápice; el segundo reserva su ascenso completo (.300 s), incluido el instante de velocidad cero. Al terminar ese margen se evalúa el vacío. Aterrizar, interrumpir una acción o reaparecer limpia el margen. `test_level00_closure` ejecuta ambos saltos con input real sobre vacío y comprueba que STRIKE2 solo comienza al terminar el segundo.

`tools/test_level00_closure.gd`: ayuda H, rechazo de colocación, giro gradual/reversión, consumo real por inventario, CRASH1/sonido/regreso sin reotorgar el objeto, raycast al vacío, STRIKE2/cámara, fundidos y bloqueo temporal de acciones, límite aéreo que Shift no puede prolongar y suelo próximo que permite aterrizar: **0 fallos**.

También pasan `test_air_obstacles`, `test_shared_items`, `test_inventory_mechanics`, `test_mailbox`, `test_camera_training`, `test_puzzle` y `test_tutorial_finish`: el puzzle sigue catapultando físicamente a Ralph y las piedras, y se lleva la oveja caminando hasta la meta. Se verificó el render GPU del HUD, STRIKE2 y fundido con `validation/capture_level00_closure.gd`.

Capturas: [pantalla limpia](level00_clean_hud.png), [ayuda H](level00_help_h.png), [caída](level00_pit_original.png), [fundido](level00_restart_fade.png).

Corrección de caída tras doble salto: `DOUBLEJUMP_FALL` original ejecuta `FallStateStep(32000)`; terminar el ascenso no ordena una muerte al vacío. El port guarda `jump_origin_y` en el primer salto (altura del último suelo si fue coyote time), conserva ese origen durante el segundo, y deja seguir la caída normal. La adaptación solicitada permite STRIKE2 solamente si Ralph desciende por debajo de **origen −1 m** y el raycast no encuentra ningún suelo. El margen de 1 m es la adaptación del usuario, no una constante atribuida al C++. Aterrizar, interrumpir acciones y reaparecer limpian el origen; RUN_AIR conserva su lógica separada. Las pruebas comprueban origen invariable, ápice del segundo salto, descenso físico y frontera .99/1.01 m; **0 fallos**.
## Corrección posterior: suelo lejano

La comprobación de vacío ahora distingue suelo cercano de suelo al fondo de un agujero profundo. No exige que el raycast sea infinito para terminar un salto en STRIKE2. Véase [deep_ground_void.md](deep_ground_void.md), con pruebas de doble salto, coyote time y la repisa del reloj del nivel 01.
