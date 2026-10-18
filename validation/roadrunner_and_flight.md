# Correcaminos de la carrera y postura de vuelo

## Fuente original

`sdw-decomp/src/objects/bipbip.cpp`, `src/engine/approach.cpp` y el recurso **55**, clase **31**, modelo **16** de Lvl-00.WAR. No se reutiliza el actor de CIN 1: la carrera tiene su propio Correcaminos, inicialmente oculto.

- BOX_DECL **666** activa la carrera al entrar Ralph. Se comprueban los tres ejes.
- TRAJECTORY **605** aporta 13 puntos; velocidades de diseñador **1700/1200** unidades por segundo. `OriginalPathFollower` reproduce el paso recto, rate entero, milisegundos e interpolación 12-bit, incluida la posición calculada antes de avanzar el tiempo. El cambio de SPEED_TWO sucede después de `BeginSegment`, como en C++.
- La animación inicial mapeada **0** es **ABIPBIP RUN1**, cuatro poses en **0.16 s**, sin sonidos propios. Se recupera del WAR y se cierra el bucle; no se usa BIPBIP, la animación de la intro, ni se inventa un pitido.
- Polvo original compartido: pool 16, vida 2608/4096 s, intervalo 163/4096 s, tamaño 40→120 unidades y deriva de 100 horizontal/-20 vertical.
- Último tramo: TRAJ_WALL **606** empieza con el mismo rate del recorrido; deja de emitir polvo y se oculta la sombra. El shader traslada las posiciones proyectadas del modelo del punto de carretera al punto de pared, y coloca su vértice más lejano a la profundidad de esa pared: adaptación de `bipbip::Render` al pipeline de Godot. No se desplaza físicamente el modelo a través del muro.
- Al acabar se oculta, limpia el polvo y queda esperando otra entrada. Respawn también reinicia el actor para reintentos. El adaptador pausa su avance cuando el tutorial bloquea a Ralph; la sombra de radio original .2 m es una aproximación geométrica, no el sistema completo de Shadow del motor original.

`RocketItem` mantiene A/D y solo invierte Y: W baja y S sube. La secuencia original de Ralph es `ROCKET0 → ROCKET2 → ROCKET3`; faltaban el pitch por velocidad vertical y el balanceo durante el giro de `Wolf::RocketFlyStep`. Se aplican y se limpian al dejar el cohete. La aceleración angular/rebote completos del perfil C++ siguen fuera de este cambio.

## Validación

- `tools/test_roadrunner.gd`: ocultación, trigger real, animación/bucle, velocidades, entrada al túnel, proyección y profundidad, polvo, fin y reintento; **0 fallos**. `-- --capture` verifica además el render GPU y guarda las capturas.
- `tools/test_tutorial_finish.gd`: dirección A/D, W/S, pitch, bank, restauración erguida, FLYBOX, oveja y meta; **0 fallos**.
- Extractores de tutorial/intro con `--verify`: datos, poses y assets iguales a WAR/DAV/SND. Render/materiales GPU, buzón y cámara del tutorial: **0 fallos**.

Capturas: [carretera](roadrunner_road.png), [túnel](roadrunner_tunnel.png), [vuelo](rocket_flight_original.png).
