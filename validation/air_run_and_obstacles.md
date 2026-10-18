# Salto, carrera sobre el vacío, objetos sólidos y polvo

## Salto

El C++ original fija el salto normal en 200 unidades (2 m), duración `0x4fd / 4096`, y el doble salto en 150 unidades (1.5 m), duración `0x4cc / 4096`. La gravedad de caída es 2900 unidades/s², límite vertical 2000 unidades/s.

Se conserva la curva y gravedad y se añade `RalphController.jump_height_scale = 0.9`, aplicable a ambos saltos: reducción deliberada del 10 % solicitada para el port. Puede ajustarse en el inspector. En el paso físico de 60 Hz, el salto aislado alcanza aproximadamente 1.905 m frente al valor anterior de aproximadamente 2.117 m; la diferencia con la altura nominal se debe a la integración por pasos del controlador. También se corrigió el doble salto iniciado durante FALL, que necesitaba volver al estado JUMP para evaluar su ascenso.

## Carrera en el aire y caída

Fuentes locales del repositorio sdw-decomp:

- `src/game/wolf.cpp`, `Wolf::InitMoveConfig`: `params[7] = 0xbb8` (30 m), `params[8] = 0xc00` (0.75 s).
- `src/game/wolf_move.cpp`, `Wolf::RunStep`, 0x48cf34: solo permite RUN_AIR con carrera activa, velocidad al menos de caminar y desnivel mayor de 30 m.
- `src/game/wolf.cpp`, estado `WOLF_ST_RUN_AIR` 0x26: mantiene la altura, permite dirección/carrera; pasados 0.75 s desactiva el impulso independientemente de nuevas pulsaciones. La desaceleración continúa hasta bajar de la velocidad de caminar. Regresa a RUN al hallar suelo a menos de 2 m; pared → FALL; velocidad insuficiente sobre un pozo → `WOLF_ST_DIE_FALL_PIT`.
- Descriptor de estado 0x0c: `ACOYOT01_ANIM_STRIKE2`, cámara `CAM_REQ_DIR_HOLD`. `Wolf::Die` programa reinicio al acabar la animación más `0x2000` (2 s).

**Los 4–5 segundos recordados no son el límite del impulso aéreo.** `STRIKE2` dura 5.36 s: Ralph permanece suspendido, se da cuenta del vacío y finalmente se desploma. La caída está en la animación: la pose del cuerpo acaba unos 11.81 m por debajo de su origen. Los sonidos embebidos son ID 78 a los 5 s e ID 81 a los 5.24 s; se recuperaron del SND del tutorial y se reproducen por las marcas originales.

Implementación reutilizable: `ralph_air_rules.gd` contiene las condiciones numéricas; el controlador consulta suelo con un raycast descendente, mantiene RUNF2 y su audio al entrar/salir de RUN_AIR, y reproduce la animación/cues originales al agotar la carrera. No se convierte un pequeño hueco transitable en vuelo automático.

La adaptación de cámara solicitada fija su posición mundial, la gira suavemente hacia un punto ligeramente delante de Ralph y bloquea el ratón durante la escena. El C++ original pide conservar la orientación; el encuadre ligero hacia delante es un ajuste del port. Al reiniciar se restaura la cámara normal. A falta de un gestor completo de checkpoints del mundo, se vuelve al último suelo con apoyo comprobado bajo todo el pie; se descarta la parte no confirmada del inventario. Esto no implementa todavía el fade y rollback completo del mundo original.

## Colisiones del tutorial

El trimesh previo incluía el terreno, pero las entidades dibujadas en la malla combinada no tenían sus sólidos individuales. `tools/extract_level_mechanics.py` lee los `ModelBoxList` del WAR: cuenta u32, seguida de `CollBox` de 16 bytes (flags y esquinas s16). No divide entre ocho las cajas de modelos animados: ya están expresadas en unidades del mundo.

Se recuperaron **33 entidades / 33 cajas sólidas**, incluidos 13 cactus, 2 rocas, 3 rocas móviles, 9 estructuras MiscStatic, 3 letreros, buzón, puerta y botón. El bit NON_SOLID se excluye: los triggers no se convierten en obstáculos. Las posiciones usan la conversión corregida `(x,-y,-z)`; las cajas originales se trasladan y no giran junto al modelo.

`OriginalSolidBuilder` crea cuerpos estáticos: cajas, conos, elipsoides y cilindros según los flags originales. Las formas curvas son aproximaciones convexas con 16 segmentos y 9 anillos. Las rocas móviles/puertas tienen su sólido inicial; moverlas por guion necesita enlazar su cuerpo con la futura lógica de cada entidad. No se portó todavía la animación BOOM del cactus al recibir MSG_BUMP.

El choque al correr usa la altura superior del solapamiento de las cajas originales, en lugar del punto tangente que la cápsula de Godot puede devolver cerca del pie. Conserva velocidad mínima, dirección frontal y altura de impacto. Un choque en cactus/roca/estructura activa STRIKE1 y los sonidos que ya estaban recuperados.

## Polvo original

`g_wolfDustParams = {100,-20,2608,163,40,120,0}` en `wolf.cpp`. `Emitter_UpdateDrift` en `src/engine/emitter.cpp` define desplazamiento contrario a la carrera a 1 m/s, ascenso 0.2 m/s, vida 2608/4096 s, tamaño 0.4→1.2 m y brillo que crece durante el primer cuarto y decae durante los tres restantes. Intervalo base 163/4096 s, ajustado inversamente con la velocidad. `Wolf_UpdateTrailFx` emite también en RUN_AIR.

La hoja cero es `DAV_IDI_IGLSMOK_`, recurso 34. Sus cuatro fotogramas originales son los bitmaps 91–94 de la página 13 del DAV, de tipo **aditivo**. Están en `assets/effects/run_dust`, con manifest de trazabilidad y PNG sin mipmaps ni retoque de alfa. `RalphRunDust` mantiene un pool de 32 partículas en coordenadas mundiales; las partículas anteriores se quedan atrás cuando se mueve el personaje. El shader usa mezcla aditiva y el brillo original, sin inventar dibujos nuevos. Referencia de la API del shader: [Godot Spatial shaders](https://docs.godotengine.org/en/4.6/tutorials/shaders/shader_reference/spatial_shader.html).

## Verificación

`tools/test_air_obstacles.gd` comprueba salto/aterrizaje, colisión física y STRIKE1 contra cajas originales de cactus/roca/estructura, carrera sobre un borde real, altura sostenida, agotamiento, cámara congelada, cues y desplazamiento de STRIKE2, retorno al suelo y partículas en espacio mundial. `test_run_mechanics.gd`, `test_game_space.gd`, `test_inventory_mechanics.gd` y `test_shared_items.gd` comprueban regresiones.

Capturas con GPU OpenGL real: `original_run_dust.png` y `original_pit_fall.png`, generadas por `validation/capture_air_dust.gd`.

`extract_level_mechanics.py ... --verify` compara las 33 cajas con el WAR y los cuatro sprites RGBA con el DAV, sin modificar archivos: sin diferencias.
