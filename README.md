# Ralph Wolf - Looney Tunes: Sheep Raider (Native Godot 4 Port)

**Prueba pública:** [web principal](https://sheepraider.nooxtools.me/) ·
[jugar en el navegador](https://sheepraider.nooxtools.me/play/) ·
[Windows y Android](https://sheepraider.nooxtools.me/#descargas).
Publicación, claves y auto-update: [docs/HOSTING.md](docs/HOSTING.md).

Proyecto remasterizado y port nativo en **Godot 4.7.2** del clásico videojuego de PS1/PC **"Sheep, Dog 'n' Wolf"** (conocido en América como *Looney Tunes: Sheep Raider*), desarrollado originalmente por Infogrames en 2001.

---

## 🎮 Cómo Jugar y Ejecutar

* **Para jugar directamente:** Haz doble clic en `Launch_Game.bat` dentro de esta carpeta.
* **Para abrir en el Editor de Godot:** Haz doble clic en `Open_In_Godot_Editor.bat`.
* **Para enviar una prueba de Windows:** Consulta [la guía de exportación](docs/WINDOWS_EXPORT.md). El ZIP generado queda en `builds/RalphWolf-Windows-Prueba.zip`.

### Controles:
* **WASD / Flechas:** Mover a Ralph Wolf.
* **Espacio:** Saltar.
* **Shift (Pulsar repetidamente):** Carrera rápida. Mantén el ritmo de pulsaciones (entre 0,10 y 0,75 segundos), como en el original; si dejas de pulsar, Ralph frena y se recupera.
* **Ctrl (Mantener):** Modo Sigilo / De puntillas (Velocidad baja sin alertar a Sam).
* **Ratón:** Girar la cámara libre en 3D (360° y ángulo vertical).
* **Escape (Esc):** Abrir/cerrar pausa; guardado manual y carga.

---

## 🗺️ Nivel Mapeado: Nivel 00 (Tutorial del Pato Lucas)

Todos los recursos se extrajeron de forma matemática directa desde los archivos binarios originales:

1. **Escenario Visual 3D (`assets/levels/lvl_00/scenery.obj`):**
   - **60.828 vértices** y **16.578 triángulos** originales con mapeo UV perfecto.
   - Texturas originales en formato PNG con canal alfa extraídas directamente del contenedor `Lvl-00.DAV`.
   - **F6** alterna entre Nearest (visor WebGL del repositorio) y Linear (filtrado del juego original de PC).
   - Importación sin pérdida y colores por vértice originales, sin recortar los multiplicadores superiores a 1.
2. **Malla de Colisión Física (`assets/levels/lvl_00/collision.obj`):**
   - **13.017 triángulos de colisión física** idénticos al milímetro extraídos del recurso `0x81` de `Lvl-00.war`.
   - Inicializados en tiempo real como `ConcavePolygonShape3D` (trimesh) en el nodo `StaticBody3D`.
3. **Puntos de Spawn y Entidades (`assets/levels/lvl_00/data/entities.json`):**
   - Las **66 entidades interactivas** del nivel con sus coordenadas `(X, Y, Z)`, rotación y parámetros de diseño.
   - **Ralph Wolf:** Spawn en espacio Godot `(-87.41, 0.50, 43.45)`, convertido de las coordenadas originales.
   - **Pato Lucas (Daffy Duck):** Modelo 3D original en el tutorial; entidades y geometría usan la misma conversión de coordenadas.
4. **Audio Original:**
   - **BGM:** Pista musical original sin comprimir `jungle_tutorial.wav`.
   - **SFX:** 53 efectos de sonido originales extraídos de `Lvl-00.SND`.
   - **Voces:** Doblaje original en español listo para asociar a los cuadros de diálogo.

---

## 🛠️ Estructura del Proyecto

```
RalphWolf/
├── assets/
│   ├── audio/
│   │   ├── music/       # Música original de fondo (WAV estéreo)
│   │   ├── sfx/         # 53 efectos de sonido originales (WAV)
│   │   └── voices/      # Muestras de voz en español (WAV)
│   ├── levels/
│   │   └── lvl_00/
│   │       ├── textures/# 14 páginas de textura (PNG 256x256 RGBA)
│   │       ├── data/    # entities.json con las 66 entidades del mapa
│   │       ├── scenery.obj / scenery.mtl # Geometría 3D visual
│   │       └── collision.obj             # Geometría física de colisión
│   └── models/
│       ├── ralph_wolf.obj / .mtl # Modelo 3D posado de Ralph
│       └── daffy_duck.obj / .mtl # Modelo 3D de Daffy Duck
├── scenes/
│   ├── characters/
│   │   └── Ralph.tscn   # Personaje jugable con cámara 3ra persona y física
│   └── levels/
│       └── Level00.tscn # Escena principal del Nivel 00 ensamblada
├── scripts/
│   ├── player/
│   │   └── ralph_controller.gd # Lógica de movimiento basada en wolf_move.cpp
│   └── levels/
│       └── level_setup.gd      # Constructor de colisiones y HUD
├── project.godot        # Configuración de Godot 4.7
├── Launch_Game.bat      # Lanzador directo del juego
└── Open_In_Godot_Editor.bat # Lanzador del editor
```

## Inventario y puntillas

Mantén **Tab** para abrir la rueda, incluso vacía; usa **A/D** o flechas y suelta **Tab** para equipar. **Esc** cancela; **E** recoge/usa, **R** usa directamente el equipado y **Q** lo coloca. En el tutorial, primero solicita el envío con **E** junto al buzón; la caja cae y se abre, después recoge el cohete y selecciónalo con **Tab** para colocarlo en la espalda.

La lógica reutilizable está en `scripts/inventory/inventory_state.gd` y `inventory_component.gd`; los pickups usan `inventory_pickup.gd`. Los handlers de uso y las señales permiten conectar cada objeto a su mecánica. Puntillas reproduce la muestra original solo en los primeros ocho pasos, con su volumen y tono originales.

Referencias, API, pruebas y límites: [validation/inventory_and_sneak.md](validation/inventory_and_sneak.md).

**F8** abre el laboratorio con imán, disfraces de oveja/fantasma, lechuga, perfume, ventilador y cohete. Sus clases globales y escenas usan recursos compartidos en `assets/items`, independientes de cada nivel. Carrera importa ahora las escalas originales de `RUNF2` y reproduce sus piezas sin herencia de escala. Uso, contratos, fuentes y alcance pendiente: [validation/shared_items.md](validation/shared_items.md).

La rueda utiliza los tres fotogramas de `IGLCRAI1` y los 27 iconos originales, extraídos de los DAV. Posiciones, brillo y movimiento proceden de `InvWheel_Draw` del C++. Trazabilidad y comprobaciones: [validation/original_inventory_ui.md](validation/original_inventory_ui.md).

La orientación del mundo coincide ahora con el visor original: `(x,-y,-z)`. Se corrigieron geometría, colisión, entidades, cámara y articulaciones; detalles y capturas: [validation/map_orientation.md](validation/map_orientation.md).

Salto reducido un 10 %, carrera sobre el vacío con condiciones originales, caída `STRIKE2` y sus sonidos, sólidos del tutorial y polvo original compartido: [validation/air_run_and_obstacles.md](validation/air_run_and_obstacles.md).

Al entrar en la zona original de salida de ACME se reproduce **CIN 1**: yunque, aplastamiento, Correcaminos, telón GAME OVER y entrada animada de Lucas. Recursos, tiempos y cámara recuperados del WAR/DAV/SND; [validation/tutorial_intro.md](validation/tutorial_intro.md).

Después se enlaza **CIN 5** con la voz española y las primeras cuatro ayudas de cámara. E continúa; el ratón busca a Lucas detrás y luego arriba. Mirarlo un segundo con la cámara normal avanza la ayuda, sin exigir vista interna: [validation/camera_training.md](validation/camera_training.md).

El recorrido continúa con salto, doble salto, carrera de 50 segundos y sus reintentos, hasta la presentación de columpios/CIN 3. Las piedras caen solo al alcanzar sus checkpoints; la música mantiene un bucle y las nubes del inventario van a 5 FPS: [validation/tutorial_progression.md](validation/tutorial_progression.md).

Cielo original sin paralaje, interrupción de acciones al iniciar escenas, subtítulos blancos con borde negro y carteles interactivos con E (incluida la pregunta y el yunque): [validation/sky_signs_and_interruptions.md](validation/sky_signs_and_interruptions.md).

Puzzle de balancines con colisión, piedras que caen y catapultas originales, botón que mantiene abierta la puerta, franjas horizontales de diálogo y salto bloqueado durante carrera/frenado: [validation/tutorial_puzzle.md](validation/tutorial_puzzle.md).

Buzón, entrega y apertura automática de caja, recogida y vuelo al inventario, equipamiento/guardado animado y cohete en el hueso original de la espalda. Lucas continúa hasta sus instrucciones del buzón y cohete: [validation/mailbox_and_rocket.md](validation/mailbox_and_rocket.md).

El vuelo queda limitado por FLYBOX original y solo su eje Y está invertido (W baja, S sube; A/D normales). En el final, guarda el cohete eligiendo manos vacías con Tab, carga la oveja con E y llévala caminando a la META. Ralph y la oveja juntos activan el cierre del tutorial: [validation/tutorial_finish.md](validation/tutorial_finish.md).

Correcaminos de la carrera con BOX_DECL, RUN1, trayectorias y entrada al túnel originales; cohete con inclinación y balanceo de vuelo: [validation/roadrunner_and_flight.md](validation/roadrunner_and_flight.md).

Cierre del nivel 00: cohete con giro gradual y consumo original, ayuda solo con H, colocación desactivada y caída/STRIKE2 con raycast, límite aéreo y fundido de checkpoint: [validation/level00_closure.md](validation/level00_closure.md).

Escape abre la pausa con la fuente original del DAV. Guardar es manual en tres ranuras y conserva únicamente la instantánea del último checkpoint; Cargar permite continuar o reiniciar sin sobrescribir la partida: [validation/save_files_and_pause.md](validation/save_files_and_pause.md).

F8 abre el laboratorio con puertas originales del estudio para entrar con E al Nivel 00 o Nivel 01. El nivel 01 ya tiene escenario, cielo, spawn, actores y colisiones originales para explorar; sus mecánicas propias continúan en el siguiente hito: [validation/level01_foundation.md](validation/level01_foundation.md).

Nivel 01: ovejas y Sam inicializados sobre terreno, triggers ocultos, flujo original del agua, buzón de dinamita/nota, dinamita con mecha/explosión y rocas destructibles, lechugas y telescopio; también disponibles en laboratorio: [validation/level01_essentials.md](validation/level01_essentials.md).

Nivel 01: música original Trip_v1 en bucle, entrada y explicaciones de Lucas, Sam con detección/ruido/persecución/captura y retrato 3D giratorio, rebaño con sueño, reservas de lechuga y regreso al puesto: [validation/level01_ai.md](validation/level01_ai.md).

Nivel 01: Lucas y Ralph quemados por dinamita, respuesta original de Lucas, conversaciones y lecciones de Porky con aparición de lechugas, y reloj secreto con recompensa única. Pendientes para completar el nivel: [validation/level01_completion_audit.md](validation/level01_completion_audit.md).

Sam: regreso por rutas con recuperación de atascos, velocidades originales y pose HEAD2 con mano en la frente/cintura durante el giro: [validation/sam_navigation_and_pose.md](validation/sam_navigation_and_pose.md).

Reloj: interacción por volumen, búsqueda original de suelo y configuración por nivel. Límite local de caída bajo el camino secreto, manteniendo las protecciones aéreas. Auditoría de reutilización y trabajo necesario para nivel 02: [validation/clock_path_and_level02_reuse.md](validation/clock_path_and_level02_reuse.md).

### Idioma de texto y voces

F5 abre la rueda original de Lucas: A/D o flechas seleccionan inglés, portugués brasileño, español o italiano; Enter/E confirma. F6 sigue abriendo directamente la escena actual con la preferencia guardada. La localización usa datos por idioma y comparte escenas/mecánicas. Documentación y extensión a nuevos niveles: [validation/localization.md](validation/localization.md).

Dentro de la ventana del juego, F5 abre la rueda de idioma sobre el nivel pausado. Enter/E confirma; Escape/F5 cancela y vuelve al mismo punto.
