# Lianas y escalada

Las lianas de la salida del reloj05 forman parte del escenario. Su lógica no
es una cuerda dinámica: `Wolf::PostLoadInit` carga las regiones `CLIMBBOXES`
desde la propiedad0 del jugador. `Wolf::ClimbStep` controla el movimiento,
`ClampDeltaToBox` sus límites y `WOLF_ST_CLIMB_ZONE` las salidas.

## Datos y controlador reutilizables

- `tools/extract_climb_mechanics.py` extrae regiones, dirección, flags,
  animaciones y sonidos de una carpeta de nivel original. Sólo escribe sus
  propios archivos; conserva los ajustes y las importaciones del escenario.
- `original_climb_zone.gd` instala las regiones cuando un nivel importado
  contiene `data/climb.json`. No añade colisión ni duplica las lianas visuales.
- `original_climb_motion.gd` contiene los estados libre, agarrado, subir,
  bajar, izquierda, derecha y salida superior. El jugador mantiene un estado
  `CLIMB`; el controlador selecciona la animación correspondiente.

El perfil nativo6 utiliza100u/s y aceleración/deceleración1000u/s², es decir,
1m/s y10m/s². El vector contra la pared se aplica durante el movimiento y
durante el primer segundo en reposo. El movimiento usa el plano de la pared,
independientemente de la cámara. Se respetan los límites laterales e inferior;
el flag0x02000000 decide si también se limita la parte superior.

`CLIMB1..5` se convierten a `climb_up`, `climb_down`, `climb_left`,
`climb_right`, `climb_idle`, con la rotación nativa ZXY y el renderer de huesos
que ya utiliza Ralph. Se extraen sus cues14/77/129 y el bucle de agarre40
(`SND_SCOCOLD`). Las manos quedan libres guardando el objeto equipado en el
inventario, sin consumirlo ni soltarlo en el mundo.

## Uso

E/acción agarra dentro de la región. W/S suben y bajan; A/D recorren la pared.
E/acción vuelve a soltar y Espacio inicia un salto para separarse. Los mismos
inputs sirven para el joystick, el botón de acción y el de salto en móvil.
El inventario queda cerrado durante la escalada; muerte, reaparición e
interrupción cinematográfica limpian el controlador y su sonido.

## Salida del reloj05

Propiedad del jugador55: recurso582, una región con flags0x20000000.
Coordenadas originales min(-400,-686,2125), max(399,413,2325), heading0.
En Godot: X[-4,3.99], Y[-4.13,6.86], Z[-23.25,-21.25], mirando hacia+Z.

El original cambia a `JUMP_ASCEND` al superar el límite superior. El port
utiliza la altura/duración normales de salto y conserva brevemente el avance
contra la pared para salir a la repisa. Esta orientación durante la salida
adapta el control a la cámara libre. No teletransporta ni omite las colisiones.

El flag0x04000000 (`CLIMBBOXWALK`, caminar sobre una zona de agarre) se exporta
para mapas futuros; su mecánica horizontal especial no se activa en05 y queda
pendiente. Este controlador implementa la escalada vertical/lateral de lianas.

## Reproducción

Ejecutar `python tools/extract_climb_mechanics.py RUTA_ORIGINAL_LVL_05`,
importar los nuevos WAV y ejecutar Godot con
`--headless --path . --script tools/build_run_animations.gd`.

`tools/test_elastic_level05_clock.gd` recorre el resorte, entrada al recinto,
acercamiento al reloj, las cinco animaciones de trepar, soltarse, saltar y
salida superior por el escenario real. Usa guardados separados y progreso
en memoria. En modo gráfico captura `validation/level05_climbing.png`.

Validación inicial: recorrido completo por el escenario real, cinco poses,
sonido en reposo, E para soltar, salto, transición superior y restauración de
controles:0fallos. Revisión visual OpenGL en `level05_climbing.png`.
