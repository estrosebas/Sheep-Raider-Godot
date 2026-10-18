# Laboratorio con puertas y base del nivel 01

## Acceso

**F8** desde los niveles 00/01 abre el laboratorio existente. Se conservan los objetos de prueba y se añaden dos puertas: **Nivel 00** y **Nivel 01**, con **E** para entrar. APORTE01, sus texturas y siete animaciones se recuperan de **Scene.WAR/DAV**, recurso DoorLevel 25/modelo 9: es el estudio de selección original, distinto de Intro.WAR cinematográfico. La entrada reproduce OPEN, bloquea acciones de Ralph y hace el fundido. La ubicación de las puertas en el laboratorio es una adaptación; no se ha reconstruido aún todo el estudio.

El commit **052fd07** conserva todo el cierre del nivel 00, guardado manual, menús originales, doble salto/coyote time, frenado aéreo y estas puertas.

## Nivel 01 montado

`tools/extract_level_scene.py` convierte de forma reutilizable WAR/DAV usando los decodificadores verificados de sdw-decomp. `tools/build_level_scene.gd -- lvl_01` crea los recursos nativos. Ambos separan el escenario y cielo, conservan RGB/UV, interpretan el modo de cada página DAV y comparten las páginas de texturas entre modelos del mismo nivel.

- **21.477 vértices de escenario** y **2.688 de cielo**.
- **4.051 triángulos de colisión** del recurso 0x81, con orientación frontal corregida para Godot.
- **99 registros de entidades**, propiedades de diseño y colocación/rotación originales. Se extraen **21 modelos únicos**, con poses/animaciones básicas; Ralph usa el controlador y esqueleto compartidos.
- **11 páginas DAV** sin pérdidas; filtro nearest/linear con F6. El cielo conserva el shader lejano sin paralaje y sin superponerse al mundo.
- Spawn original `(891,-11,-1273)` → Godot **(8.91,.11,12.73)**. Al asentarse por física queda en y≈.0798.
- Puentes, rocas, árboles/estructuras y otros objetos disponen de sus cajas sólidas de modelo, ignorando las cajas de trigger. Se mantiene la regla original de cajas traducidas sin rotarlas con el arte.
- Sam, ovejas, Lucas, Porky, buzón, lechugas y elementos del mapa aparecen como assets originales; aún son la representación del escenario, no un nivel 01 terminado.

`ImportedLevel` monta recursos según manifest sin copiar el constructor del tutorial. Reutiliza movimiento, salto/doble salto/coyote time, carrera/frenado, polvo, cámara, interpretación de colisiones, inventario, pausa y ayuda H. La pausa funciona y puede cargar una ranura del nivel 00; el adaptador de checkpoints/guardado del nivel 01 queda pendiente y Guardar no inventa checkpoints.

## Próximas mecánicas

Antes de declarar completo el nivel 01 faltan IA/vigilancia y golpe de Sam, seguimiento/carga de las ovejas del rebaño, instrucciones de Lucas/Porky, uso/entrega de lechuga y dinamita, comportamiento de puentes y reloj, checkpoints, meta y pistas de música/voces propias. Los registros originales ya están decodificados para implementar cada clase sin nuevas posiciones inventadas.

## Validación

`extract_level_scene.py --verify`: compara escenarios, sky, rigs, props, colisión y píxeles de páginas con los binarios originales. **Verificado**.

`tools/test_level01_base.gd`: spawn sobre suelo real, conversión de coordenadas, las 4.051 caras de colisión, entidades/solidos, actor assets propios, caminar físicamente sin caer, F8 al laboratorio y entrada real por puerta APORTE01 al nivel 01: **0 fallos**, también con render GPU y captura. Pruebas de objetos compartidos: **0 fallos**.

Capturas: [nivel 01](level01_spawn.png), [puertas](lab_studio_doors.png).
