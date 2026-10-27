# Ralph congelado al caer al agua

Fuentes PC: wolf_move.cpp WaterSinkStep(0x48b664)/WaterFloatUpStep;
wolf.cpp estado0x4a WOLF_ST_FROZEN_FLOAT; wolf_misc.cpp Fx3or4_Start.

Se usa el flag nativo ZONE_WATER_FREEZING0x1000000, no el número del nivel.
Tras el hundimiento inicial, cuando se frena la caída, FREEZE1 sustituye a
la natación. El prop AGLACON1, export98, reproduce STAND2 sujeto al joint0
con offset cero. Modelo, esqueleto, texturas y pose se extraen del WAR/DAV.
El cuerpo reproduce FREEZE1 una vez y mantiene su última pose, sin repetir
SWIM ni la caída al vacío. No se inventan sonidos: FREEZE1 y STAND2 no tienen
cues nativos y el estado de flotación no solicita un sonido de congelación.

El bloque ignora el movimiento del jugador y flota200u/s hasta105u bajo
la superficie. Se aplica Zone_GetFlowVelocity: velocidades1/2/4m/s,
diagonales0.71, signos de corriente convertidos a Godot. El estado espera
los20s originales; luego cierra el iris1s, restablece checkpoint/inventario
y abre el iris compartido. La cámara libre puede seguir observando el bloque.
El secador/objeto equipado se guarda sin consumirlo. Si Ralph lleva una
oveja, esta vuelve a su origen al entrar en esta derrota, como las demás
muertes del port. No se implementa aquí el rescate/rotura del bloque en tierra
ni la carga de un FrozenRiver de niveles posteriores.

El agua sin el flag conserva la natación actual; NO_SURFACE no inicia esta
flotación. Las zonas contiguas actualizan superficie y corriente sin repetir
el cambio de estado. El efecto se elimina al reiniciar o cambiar de estado.

Extracción: tools/extract_frozen_water.py DECOMP LVL06; importar texturas;
tools/build_frozen_water.gd y tools/build_run_animations.gd.
Prueba: tools/test_frozen_water.gd (caída real, modelo/pose, corriente,
controles bloqueados, altura, timeout/iris, inventario y agua normal).
Captura visual: validation/level06_frozen_water.png.
