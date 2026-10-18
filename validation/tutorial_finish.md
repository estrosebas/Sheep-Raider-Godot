# Vuelo y final del nivel 00

## Correcciones

- **Cohete en la espalda:** `LegacySkinRenderer.last_matrices` transforma coordenadas locales exportadas `(x,-y,z)` al mundo nativo. La implementación anterior aplicaba también la reflexión Z al offset local, llevándolo al pecho, y volvía a reflejar la base del modelo animado. Se conserva el hueso 3 y `(0,10,20)` del C++, aplicando el offset exportado una sola vez y convirtiendo la base para recibir el modelo nativo. La prueba verifica que el desplazamiento queda detrás del torso y que la base tiene determinante positivo.
- **Límites de vuelo:** `Wolf::PostLoadInit` lee FLYBOX de la propiedad 4, export **629**. `RocketFlyStep` llama `ClampDeltaToBox(...,7)` antes de resolver colisiones. En Lvl-00, la caja nativa va de `(-273.77,-4.30,-115.72)` a `(-69.88,14.21,24.26)`. Se rechaza el despegue fuera de ella y se limita el desplazamiento en los tres ejes; no se sustituye por un límite inventado basado en el mapa visible.
- **Solo eje Y invertido**, según la corrección solicitada: W desciende, S asciende; A/D conservan el sentido normal del port. Shift conserva la aceleración y el consumo de combustible.
- **Oveja del final:** recurso **53**, modelo AMOUTO01 **2**, posición/rotación originales. El Node3D de muestra sin física queda oculto; una `OriginalSheep` animada usa la caja original de 70×80×70 unidades, gravedad y colisión de terreno. Pasa de y=4.49 a y≈4.001; las patas renderizadas quedan a menos de 1 cm del terreno. La postura no se corrige desplazando arbitrariamente el mesh.
- **Cargar/dejar:** E usa TAKE2A/B y PUT2A/B recuperadas de Ralph. `Sheep::MSG_PICKUP` utiliza hueso 18, offset `(0,7,0)`, orientación de raíz y giro relativo. Se desactiva la colisión de la oveja al cargarla. El [refinamiento compartido del modo de transporte](level01_ai.md) corrige el reposo a STAND8, añade STAND12 de cansancio, RUN2/SNEAK2 y un salto con sus animaciones originales. El inventario permanece bloqueado durante transporte.
- **Meta:** `Goal::PostLoadInit/Update`, recurso **122**, posición `(-78.76,4.26,-60.05)`, caja del modelo **38** y radio entero `197*90/128 = 138` unidades. Ralph debe estar en caja/radio/altura y la oveja también en radio/altura. No basta llegar solo. El adaptador usa la posición de juego del portador para la oveja cargada, separándola de su transformación de render.
- **Cierre:** equivalente a `Wolf::MSG_WOLF_WIN`: interrupción de acciones, bloqueo de controles y `Fade_StartLevelExit(0x3000)` (3 s). `level_completed` permite conectar el nivel siguiente; actualmente muestra “Nivel 00 completado” y Enter reinicia el tutorial. No se conecta un nivel 01 inexistente en este hito.
- Lucas continúa por los slots/caminos 18 y 19, con la voz española **87** y la explicación original de la meta.

## Comprobación

`tools/test_tutorial_finish.gd` verifica el cohete detrás del torso, límites y rechazo de despegue, solo eje Y invertido, inclinación/balanceo y restauración al salir, suelo real y patas visibles de la oveja, cargar/dejar, inventario bloqueado durante transporte y meta negativa/positiva. La prueba recorre físicamente unos 20 metros con la oveja cargada hasta activar la meta, sin teletransportarla allí; termina en `(-80.06,4.34,-59.70)`.

Se verifican también buzón/inventario, siete tipos de objetos, puzzle, tutorial, materiales originales y render GPU. Recursos compartidos: `assets/items/sheep`; parámetros del nivel recuperados en `puzzle/definitions.json` por `extract_puzzle.py`.

Capturas: [oveja en suelo](final_sheep_grounded.png), [oveja cargada](final_sheep_carried.png), [cohete corregido](rocket_back_corrected.png).

Postura de vuelo original y Correcaminos de la carrera: [roadrunner_and_flight.md](roadrunner_and_flight.md).
