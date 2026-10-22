# Nivel 05: base importada

Importación local del 22/10/2026 desde PC `Levels/Lvl-05` (WAR/DAV/SND/MLT)
y funciones de `sdw-decomp/src/objects`. No implica que el nivel ya esté
completado de principio a fin.

## Listo para probar

- `scenes/levels/Level05.tscn`: mapa texturizado visible en el editor y F6.
- 74 entidades originales, 24 modelos principales, 11 páginas DAV y 7124
  triángulos originales de colisión. Coordenadas y escala compartidas con 00–04.
- CIN0: recorrido de entrada original de 16,624 s, registrado como
  `intro_cinematic`, con apertura circular al devolver el control.
- No existe actor de Lucas ni tutorial con voz en este WAR. Los bancos MLT
  de los cuatro idiomas ya estaban extraídos; se registra el contenido del 05
  en el catálogo compartido sin copiar conversaciones de otros mapas.
- Música Trip_v1: tramo y bucle del catálogo original (también usado por 01).
- Fondo violeta original del WAR (`#302840` en el perfil de materiales actual;
  `#181420` es el valor reducido que usa el motorPC), en editor y en juego;
  sustituye el azul genérico que se veía a través del río. Ver auditoría
  `LEVEL05_WATER_AND_CLOCK.md`.
- Sam y una oveja con sus controladores compartidos; toro dormido y cinco
  polígonos ruidosos de hojarasca con sus avisos, sonido y partículas.
- Dos buzones: 58 entrega ventilador83 y 59 entrega elástico86. Reutilizan
  caída/apertura de cajas, recogida, inventario y cámaras de sus propios datos.
- Dos balsas, seis árboles de elástico y tres lechugas en posiciones nativas.
- Cinco botones y seis compuertas conectados por referencias originales.
  FallingGate hace SwapModel según la propiedad16: se extraen AGRILL01 y
  AGRILL05, incluyendo sus propias cajas, texturas y animaciones. No se usa
  el modelo provisional17 para todas las compuertas.
- Plataforma RCarpetMobile52: trayectoria559 de dos puntos, botón50,
  avance/retorno a 400 unidades/s (4 m/s), ratio100%, suelo móvil y sonido94.
  Ralph/oveja reciben velocidad de suelo y los objetos usan MovingSupport.
  Distancia recorrida incluida en checkpoints; archivos antiguos siguen válidos.
- 16 volúmenes de agua para natación compartida y pirañas81; cuatro regiones
  de UV animadas, espuma de balsas y tres emisores de agua de cascadas.
- Reloj61, goal96 y cinco checkpoints vinculados a `lvl_05`; progreso,
  guardado manual y finalización usan la misma infraestructura que 00–04.
- El plató reconoce automáticamente la nueva escena y mantiene el desbloqueo
  secuencial. El laboratorio ahora incluye una sexta puerta (Nivel05).

## Pendiente de jugabilidad específica

- Catapult56: modelo, animaciones, colisiones, caja de activación, trayectoria
  de tres puntos, dimensiones del brazo y límite de tiro extraídos en
  `data/catapults.json`. Falta portar su control de potencia, cubeta, lanzamiento,
  cámara y relación con el botón51. Actualmente es un objeto importado.
- SmallRock65: arte/colisión presentes; falta su recogida/transporte y empleo
  con la catapulta.
- Fish162 y Firefly159 están importados como ambientales; falta su movimiento
  propio. Leaf191 sí usa el controlador compartido.
- La hojarasca conserva la geometría original y sus límites visuales conocidos;
  no se aplican los experimentos descartados del laboratorio.
- Falta recorrido humano completo: especialmente catapulta, reloj bajo el
  escenario, navegación de Sam entre compuertas y extracción de la oveja.

## Reproducir la extracción

Con las rutas de la instalación original y del repositorio decomp como
`DECOMP` y `LVL` (esta última termina en `Levels/Lvl-05`):

```text
python tools/extract_level_scene.py DECOMP LVL --all-animations --runtime-adjusted
python tools/extract_level_runtime.py DECOMP LVL
python tools/extract_imported_level_content.py DECOMP LVL
python tools/extract_level04_wildlife.py DECOMP LVL
python tools/extract_level04_environment.py DECOMP LVL
python tools/extract_raft_mechanics.py assets/levels/lvl_05
python tools/extract_level_goals.py LVL
python tools/extract_level05_supplement.py DECOMP LVL
python tools/localize_imported_level.py lvl_05
```

Después: Godot `--headless --editor --path . --import --quit`,
`python tools/configure_native_level_textures.py lvl_05`, repetir importación,
y ejecutar con Godot `--headless --path . --script` estos scripts,
añadiendo `-- lvl_05` en cada uno:

- `tools/build_level_scene.gd`
- `tools/build_level_runtime.gd`
- `tools/build_imported_level_content.gd`

`python tools/create_imported_level_scene.py lvl_05` crea la escena inicial.
Los extractores compartidos se ejecutan antes del suplemento05 para que no
sobrescriban sus variantes de compuerta y clasificación de cámara.

## Verificación

- `test_level05_foundation.gd`: 0 fallos, tanto headless como OpenGL. Comprueba
  entrada, geometría, personajes, cajas, elástico, agua, variantes de compuerta,
  avance/retorno de plataforma y restauración real de un guardado temporal.
- `test_level04_raft.gd`: 0 fallos (transporte de Ralph y restauración de balsa04).
- `test_level_completion_and_save.gd`: 0 fallos (progreso y guardado del 01).
- Captura OpenGL: `validation/level05_overview.png`.
- Distribución y verificación de la versión1.0.5: ver `RELEASE_1_0_5.md`.
