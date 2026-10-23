# Nivel06: importación y mecánicas a revisar

Base local extraída del PC `Levels/Lvl-06` (WAR/DAV/SND/MLT), cotejada con
`sdw-decomp/src/objects`. Escena: `scenes/levels/Level06.tscn`, visible con
texturas en el editor y ejecutable conF6. Es una base para pruebas; todavía
conserva pendientes el secador, el deshielo y el diálogo militar de Lucas. Las minas y la transición de Sam ya son funcionales.

## Escenario y materiales

- 67 entidades,21 modelos principales y5882 triángulos de colisión nativos.
- 12 páginas DAV:0..6 opacas,7..10 con transparencia y11 aditiva. Conservan
  el shader retro y colores originales, sin reconstruir la nieve ni el hielo.
- Texturas sin compresión con pérdida, mipmaps ni corrección artificial de
  bordes alfa. Agua/hielo conservan su material original; el encabezado WAR
  no declara regiones de desplazamiento UV, por lo que no se inventa flujo.
- Cielo original y fondo del WAR `#283868` en el perfil actual; el motor PC
  usa el valor reducido `#141c34`. El FogManager84 queda pendiente de adaptar.
- Cinco volúmenes nativos de agua conectados a la natación compartida.
- Música original `Luney_v2` con tramo y bucle del catálogo compartido.

## Personajes, voces y cinemáticas

- Sam41 y11 ovejas42..52 usan los controladores compartidos. Sam conserva
  las correcciones de poses vigilando y victoria trasPUNCH3.
- Lucas55 es `DaffyMilitary`: empieza congelado en el cubo56, no es el Lucas
  de los ejercicios de sigilo. Su estado inicial usaSTAND1 sin reproducir
  automáticamente acciones; el hielo usaSTAND2 congelado.
- CIN0: entrada16.624s, registrada `intro_cinematic` con iris al devolver
  el control. CIN1: lección de minas53.296s, voz38 y textoMLT58[0]. Solo debe
  ejecutarse después de liberar a Lucas. CIN2: demostración12.864s relacionada
  con minas; conectada a la flauta mediante OriginalSamFluteEncounter.
- Diálogo militar: pregunta y tres respuestas originales, voces96/97/98 y
  réplica de castigo. Se conservan en `exclusive_mechanics.json`, con overlays
  de inglés, español, portugués de Brasil e italiano. Todavía no existe la
  interacción de hablar/descongelar de esta variante.
- Dos letreros originales: mensaje de Sam y explicación de la catapulta.

## Controladores reutilizados

- Catapulta37, botón39 y roca transportable58. El alcance regulable del06
  es±20m, frente a±5m en05; dimensiones, trayectorias y cámara vienen del WAR.
- Balancines35 y36, roca empujable38, rocas de escondite57/62, telescopio59.
- Tres lechugas68/75/77, cohete76 y flauta78. El cohete hereda los límites
  de vuelo de este nivel; la flauta se obtiene del buzón54 y activa CIN2 ante Sam, que la retira y pasa a su patrulla original.
- Buzón53 entrega secador74; buzón54 entrega flauta78. El secador usa un
  adaptador de importación para caja/recogida/inventario y su modelo original;
  `prototype_only` indica que su efecto exclusivo todavía no está portado.
- Reloj63, goal90 y seis checkpoints con guardado/progreso compartidos.
- El plató encuentra automáticamente la escena06 y la desbloquea tras05.
  Laboratorio: añadida séptima puerta (Nivel06), sobre el suelo ampliado.

## Mecánicas nuevas: análisis del original

1. `hairdryer.cpp`: al soplar consulta objetivos activos no sujetos en un
   volumen de4m. Comprueba distancia horizontal de hasta4m y semicono409
   unidades angulares (unos36°), y envíaMSG_THAW. Faltan su animación de
   uso en mano, aire caliente y sonido activo; no sustituirlo por ventilador.
2. `icecube.cpp`: FROZEN/STAND2 → MELTING/FOND1, avanzando solo cuando recibe
   calor; tras1s acumulado libera al prisionero medianteMSG_THAW y deja
   de bloquear. Termina su animación y pasa a charco. Actualiza la caja de
   colisión mientras se derrite y respeta el progreso de deshielo alReset.
3. `daffymilitary.cpp`: el deshielo disparaCIN1 y su explicación, después
   permite conversar. Incluye tres respuestas, voz, giro hacia Ralph y
   reacción quemada/castigo. Falta conectarlo al hielo y al diálogo compartido.
4. `mine.cpp::DefusableMine`: once minas64..67/69..73/79/80 con código,
   longitud2..4, desfase y radio propios. La fase va en ciclos de3s, con
   medias fases1.5s; hay demostración de botones y repetición rítmica con
   tolerancia±0.25s. Un error o entrada fuera de tiempo provoca explosión.
   Implementadas ondas, activación, explosión/sonido, panel original con flechas,
   teclado/joystick y persistencia. Véase ORIGINAL_DEFUSABLE_MINES.md.

Orden sugerido para el siguiente hito: secador → cubo → liberación y charla
de Lucas. Las once minas, CIN2 y su restauración ya están implementadas.

## Reproducir y validar

Con `DECOMP` y `LVL` apuntando al repositorio nativo y a `Levels/Lvl-06`:

```text
python tools/extract_level_scene.py DECOMP LVL --all-animations --runtime-adjusted
python tools/extract_level_runtime.py DECOMP LVL
python tools/extract_imported_level_content.py DECOMP LVL
python tools/extract_catapult_mechanics.py DECOMP LVL --level-data-only
python tools/extract_level04_environment.py DECOMP LVL
python tools/extract_level_goals.py LVL
python tools/extract_level06_supplement.py LVL
python tools/localize_imported_level.py lvl_06
python tools/create_imported_level_scene.py lvl_06
```

Importar en Godot, ejecutar `configure_native_level_textures.py lvl_06`,
reimportar y construir con `build_level_scene.gd`, `build_level_runtime.gd`
y `build_imported_level_content.gd`, cada uno con `-- lvl_06`.

`test_level06_foundation.gd`: geometría, materiales, entrada real,11 ovejas,
Sam, buzones, flauta, referencias pendientes, telescopio, reloj/goal, agua,
catapulta, balancines, música y escritura real de un checkpoint temporal.
Captura OpenGL: `validation/level06_overview.png`.
