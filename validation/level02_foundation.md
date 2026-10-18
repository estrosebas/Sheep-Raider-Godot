# Primera base jugable del nivel 02

El avance anterior completo se guardó en ef348fc antes de empezar esta importación. Level02.tscn usa el escenario y collision.tres persistidos para verlo con texturas y navegar en el editor, y F6 inicia este nivel. Hay una tercera puerta NIVEL 02 en el laboratorio.

Datos extraídos de Lvl-02.WAR/DAV/SND: 97 entidades, 28 modelos, 13 páginas de textura y 4.435 triángulos de terreno. Se cargan el cielo y las cajas de colisión originales de objetos. El inicio usa la posición y dirección originales de Ralph. foundation_mode de ImportedLevel selecciona un ensamblador reutilizable sin copiar escenas ni triggers de tutorial del nivel 01.

Activos: Sam con zonas/rutas nativas y su postura HEAD2 derivada de START, 14 ovejas con comportamiento compartido y carga, lechugas, dos buzones con entrega del ventilador y perfume, tres carteles del banco MLT 79 del nivel 02 con cambio de idioma, reloj secreto, Goal nativo y cuatro checkpoints. La música JAMI Full se elige por la tabla original de niveles del catálogo, en bucle completo con límites exactos de muestras. FanItem, PerfumeItem, ovejas, Ralph, inventario, efectos y muerte son las clases existentes.

ImportedCheckpointSave admite niveles sin DaffyLessons/PorkyLessons; conserva el formato de guardado, progreso y carga existentes. Los checkpoints siguen siendo memoria en ejecución: guardar en disco requiere la opción de pausa. Las modificaciones del nivel 01 siguen pasando su prueba de guardar/cargar/Goal.

Pendiente para terminar el nivel: secuencias CIN y lecciones de DaffyLevel02; lógica específica de balancín, elevador, plataforma móvil y botón; puerta secreta, pirañas y gestores ambientales/visibilidad. Los modelos con esas clases son por ahora representaciones del escenario, con sus colisiones de base cuando existen; no se afirma que sus mecanismos estén terminados. Piedras, arbustos y la interacción ventilador/perfume se incorporaron después; ver level02_interactions.md.

Reproducción: extract_level_scene.py DECOMP Lvl-02; extract_level_runtime.py DECOMP Lvl-02; extract_level_goals.py Lvl-02; importar recursos con Godot; build_level_scene.gd -- lvl_02; build_level_runtime.gd -- lvl_02; create_imported_level_scene.py lvl_02.

Validación: test_level02_foundation.gd comprueba terreno/spawn, zonas de Sam, ovejas, ambos buzones y liberación real del ventilador, idiomas de carteles, música, snapshot y escritura/lectura/restauración de save y resolución de escena. Regresiones: test_level_completion_and_save.gd y test_lab_stations.gd. Captura GPU: level02_start.png.
