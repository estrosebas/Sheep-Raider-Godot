# Puzzle de balancines, piedras, botón y puerta

Estado anterior guardado en `268b141`. El puzzle del nivel 00 tiene dos `seesaw` (47/48), dos `Rock` (49/50), `SensibleButton` 51 y `FallingGate` 57. Sus 1107 vértices se separaron del decorado combinado sin modificar los recursos originales. Los componentes del puzzle poseen ahora su representación y sus colisiones; se retiran los colliders estáticos duplicados.

Fuentes originales consultadas:

- `src/objects/seesaw.cpp`: `PostLoadInit`, `Update`, `AddBody`, `LaunchObject`, `ArcCoeffsFrom3Points`.
- `src/engine/launch_arc_inlines.h`: `LaunchArc::Step`.
- `src/objects/rock.cpp`: `PostLoadInit`, `ApplyGravity`, `Update`, `MSG_LAUNCH`.
- `src/objects/sensiblebutton.cpp`: ocupantes y mensajes `MSG_SWITCH_ON/OFF`.
- `src/objects/fallinggate.cpp`: estado cerrado, animaciones `mv_open/mv_close`, contacto al terminar la apertura.
- `src/engine/interface.cpp`: `Letterbox_Update`, `Dialogue_StartVoice`, `Dialogue_Show`.
- `src/engine/scenaric.cpp`: los recursos cinematográficos rígidos son objetos genéricos; no llevan colisión inventada a partir de su malla.

El balancín tiene una superficie caminable que se inclina con el peso y el brazo de palanca: Ralph 60, piedras 120, límite del diseñador ±20 grados. Conserva las reglas de torque, amortiguación, umbral de sonido y pasos angulares; la integración angular se adapta a ticks de 40 ms y la detección de ocupantes usa los contactos físicos de Godot. Las piedras utilizan gravedad original 40 m/s², mínimo 2 y máximo 30 m/s. Se apoyan en las tablas en lugar de flotar; se evita que la velocidad de una plataforma móvil de Godot las deslice espontáneamente.

Los exports 676/675 arman el impulso al saltar desde las plataformas elevadas. Las trayectorias 589/590/591 conservan sus tres puntos: `p(t)=p0+(-3p0-p2+4p1)t+2(p0+p2-2p1)t²`, 1,024 s. La caída sobre un extremo lanza al ocupante contrario. Primero se lanza la piedra grande, cuya vuelta lanza a Ralph; después se lanza la pequeña hacia el botón. La trayectoria de Ralph resuelve colisión a lo largo del movimiento: la plataforma elevada intercepta su arco **antes** del punto final. Teletransportarlo hasta ese punto lo hacía atravesar la plataforma y caer al vacío. Se usan las cámaras originales de los balancines.

La piedra pequeña mantiene pulsado el botón y abre la puerta. Se reproducen las animaciones y sonidos originales del botón y la puerta; el cierre restaura su colisión cuando el botón queda libre. La piedra grande se reinicia al reaparecer según su propiedad `reset`; la pequeña conserva el estado del puzzle. La física de empujar/rodar piedras a voluntad y aplastamientos no se incluye en este hito.

Los fragmentos decorativos de CIN 3 no tienen cajas sólidas en el WAR. Antes se habían convertido todos en colisión de malla, lo que atrapaba la piedra pequeña. Ahora se mantiene la visibilidad authored y solo se crean colliders cuando el modelo original declara cajas sólidas.

Los diálogos conservan el texto blanco con borde negro, y ahora muestran las franjas negras originales arriba y abajo. `Letterbox_Update` abre/cierra durante 1500 ms y llega a 48 líneas en un viewport virtual de 240 líneas. El texto se pagina en dos líneas en la franja inferior; la voz espera a que las franjas terminen de abrir. No se ha importado la fuente bitmap original.

Durante `RUN_START`, `RUN`, `RUN_AIR`, `RUN_STOP` o choque no se acepta salto. Inventario, objetos y lectura voluntaria de carteles siguen bloqueados durante carrera/frenado; los diálogos y cinemáticas pueden interrumpir esas acciones como antes. Al terminar `SLIDE1` vuelve a permitirse saltar.

Validación: `tools/test_puzzle.gd` prueba la caída y apoyo de ambas piedras, inclinación y colisión de tablas, ambas catapultas con contactos físicos, aterrizaje elevado, botón/puerta, cierre al retirar peso, bloqueo de salto/inventario, franjas y paginación. También pasan las pruebas de tutorial, cámara, inventario, carreras/obstáculos, coordenadas y materiales. `tools/extract_puzzle.py --verify` contrasta geometría, cajas, trayectorias, cámaras, animaciones, texturas y sonidos extraídos con los archivos del juego.

El recorrido completo del nivel 00 aún requiere el tutorial de buzones/encargos, la continuación de Lucas después de esta sección y la condición final de meta. Este hito termina el puzzle y los dos ajustes de presentación/control pedidos.
