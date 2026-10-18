# Plató original y entrada al juego

`Studio.tscn` utiliza Scene.WAR/Scene.DAV: 64 registros, nueve modelos, quince
páginas de texturas y 1438 triángulos de colisión. El decorado y las colisiones
están guardados en la escena para poder navegar por ella en el editor.
Lucas, ambos grupos de público, los pasillos y las puertas conservan sus
transformaciones originales. Las puertas de niveles aún sin portar son decorado.
Las de 00, 01 y 02 permiten entrar; el laboratorio tiene una puerta adicional.
F8 alterna entre plató y laboratorio. Elegir idioma al arrancar lleva al plató.
En el plató las entradas verifican progreso secuencial: 00 está disponible
desde el principio, completar00 habilita01 y completar01 habilita02.
Los niveles ya completados siguen disponibles para repetirlos, incluso en
guardados antiguos con flags incompletos de niveles previos. Esta comprobación
también rechaza E en una puerta bloqueada si se llega saltando el pasillo.
Las puertas del laboratorio conservan acceso libre para pruebas.

## Progreso y guardado

`OriginalProgress` sigue siendo la fuente única de los 17 flags de extracción.
El panel de SceneSheepPanel muestra las ovejas **restantes**, como el original.
No se muestran leyendas de progreso/acciones en la esquina superior izquierda.
Al acercarse a una puerta, se muestra abajo el nombre y estado del nivel,
siguiendo DoorLevel::MSG_QUERY_ACTION/Text_PrintfStyled y los textos nativos
de la lista MLT171: no superado, superado, completamente superado. El último
requiere oveja extraída y reloj activado; el tutorial00 sólo exige completarlo,
como en el original. Estos estados utilizan `OriginalProgress`, que se guarda
y restaura en las ranuras manuales y en el guardado automático de victoria.
El idioma se toma del banco original actual.
Sus IDs de animación se resuelven desde la tabla
WAR, no desde el orden de los nombres. El material del panel descarta caras
traseras porque sus segmentos apagados se giran 180 grados.
DoorWorld abre el paso y elimina su colisión según el nivel enlazado por WAR.

Como adaptación del port, una oveja decorativa por nivel completado permanece
en la zona original de recogida (export563). Cada una tiene un identificador
de nivel y una fase de reposo independiente. No son ovejas de laboratorio ni
pueden duplicarse al repetir un nivel. El original retiraba la oveja al contarla;
esta galería hace visible el progreso persistente. No se implementan aquí los
diálogos ni la cinemática completa de recepción del plató.

Al iniciar se lee la ranura válida más reciente (manual o automática) y se restaura su progreso
en el plató. No se entra automáticamente al nivel guardado. Si hay un checkpoint
de un nivel pendiente, su puerta permite retomarlo; los niveles ya completados
se vuelven a jugar desde el principio. Esc conserva la opción de cargar otro
archivo en el plató o continuar explícitamente desde su checkpoint.

El esquema versión1 acepta ahora `level: studio` con progreso y un checkpoint
de nivel opcional, además de los archivos antiguos de los niveles. Guardar en
el plató preserva ambos. La victoria en00/01/02 utiliza `OriginalLevelCompletion`:
PUT2A/PUT2B dejan la oveja suavemente en el suelo, se escribe `autosave.json`
y después comienza el fundido de salida. Esa ranura adicional aparece arriba
de las tres manuales y sólo se actualiza al completar un nivel. Nunca modifica
las ranuras1/2/3. Los checkpoints, relojes por sí solos, puertas y cambios de
escena no escriben archivos automáticamente; Guardar sigue disponible para
conservar avances parciales. El guardado de victoria vuelve al plató y conserva
las banderas de niveles/relojes y un snapshot de nivel opcional. Si falla la
escritura, el resultado informa del error y conserva la posibilidad de guardar.

## Regeneración y comprobación

- `extract_level_scene.py DECOMP LEVELS/Scene --all-animations` extrae la base.
- `build_level_scene.gd -- scene` construye mallas, rigs y colisión Godot.
- `extract_studio_metadata.py LEVELS/Scene` extrae los IDs del contador, el
  recinto de recogida y los enlaces de DoorWorld.
- `test_studio_progress.gd`: partida nueva, flags únicos, contador, puertas,
  guardado desde pausa, arranque nuevo y compatibilidad con ranuras antiguas.
- `test_studio_door_resume.gd`: puerta original y restauración del checkpoint
  real de nivel02 conservando el progreso de otros niveles.
- `test_studio_door_status.gd`: estados originales de puerta, excepción del
  tutorial, cuatro idiomas, reloj y completado persistidos en guardado manual,
  aparición por proximidad y eliminación de la leyenda superior izquierda.
- `test_language_startup_transition.gd`: rueda de idioma → transición → plató.

También se verifican los guardados existentes y el laboratorio de objetos.
