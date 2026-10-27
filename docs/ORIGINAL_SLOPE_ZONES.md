# Resbaladilla nevada y controles relativos a la cámara

Fuentes: sdw-decomp/src/game/scn_controllable.cpp GetStickHeading(0x49246f)
y Wolf_SurfaceVelocity(0x49303c); wolf.cpp Update/estado9/InitMoveConfig;
objects/camerarestriction.cpp PostLoadInit y objects/camera.cpp ApplyRestriction.

El disco Lvl-06 tiene8 exportaciones WAR_IDO_SLIDEBOX104 y ninguna ICEBOX92.
La rampa de aspecto helado usa las zonas de deslizamiento y sus pendientes;
no se inventó una trayectoria de lanzamiento ni una fricción de ICEBOX.

`tools/extract_level06_slopes.py` recupera las cajas con altura completa,
las7 restricciones de cámara (ámbitos, pitch/yaw, distancias, focal),
y las poses nativas Ralph SLIDE3 y carga SLIDE4. `build_run_animations.gd`
las integra con el orden de rotación de los demás clips nativos.

`OriginalSlopeZones` es un controlador reutilizable por archivo slopes.json.
Sobre una pendiente dentro de SLIDEBOX aplica el tirón original del terreno:
1+14*t m/s normal /2+20*t en carga, máximo80 antes de proyectar sobre la normal;
velocidad manual máxima6 /4.5m/s, límites X/Z12m/s, vertical20m/s,
componente vertical mínima1.2m/s. Selecciona las poses propias y mantiene la
oveja en la mano. Puede dirigirse con teclado/joystick y saltarse desde el suelo;
respeta colisión, acciones, muerte, natación y cinemáticas. La oveja suelta
resuelve su caída en pendientes mediante el comportamiento compartido.
La física nativa de punto fijo se adapta a metros y delta de Godot.

La cámara aplica límites de pitch/yaw/distancia de la última restricción cuyo
volumen contiene a Ralph, con transición suave sobre el SpringArm y colisión
existente. Al salir restaura los valores de la cámara libre. No toma la cámara
actual a una secuencia de lanzamiento ni bloquea sus controles.

GetStickHeading original usa atan2(stickX,stickY)-g_camera.rot.y+2048.
Por tanto los controles SE ADAPTAN a la cámara visible, también con CamShot.
El port utilizaba el pivot libre incluso si otra Camera3D era actual; ahora
movement_camera_basis devuelve la orientación horizontal de la cámara activa.
Se comparte entre marcha/salto/carrera en aire, ventilador/secador y carga de
ovejas. Una cámara cenital conserva un eje horizontal estable a partir de su
vector derecho. No depende del teclado: el joystick móvil usa las mismas acciones.

Verificación: test_level06_slopes.gd recorre la rampa curva con entradas reales,
comprueba descenso con colisión, poses normal/carga, cámara/restauración,
base cenital y movimiento real con una cámara activa distinta del pivot.
Regresiones: test_level03_seesaw_launch y test_level06_seesaw_chain.

## Transiciones suaves de cámara

La entrada/cambio de restricción interpola ángulo (arco más corto), distancia
y FOV durante0.9s con smootherstep, con velocidad/aceleración cero en ambos
extremos. Salir restaura la vista libre con la misma curva durante1s, en vez
de asignar la transformación y focal guardadas en un frame. Si se entra en
otra zona durante la salida, el nuevo recorrido parte de la vista mostrada
y conserva la referencia libre original. El reset/respawn restaura de inmediato
bajo su iris. El movimiento/controles no se bloquea durante estas transiciones.
La prueba cubre entrada/salida de la cámara102 de bombas, focal/distancia,
retorno completo y reentrada durante una transición.

## Controlador general de cámara

Las cámaras se han extraído a OriginalCameraZones/camera_zones.json. Ya no
pertenecen al controlador de pendientes; comparten preferencias y tratamiento
con todos los niveles00..06. Véase ORIGINAL_CAMERA_ASSISTS.md. slopes.json
conserva únicamente cajas/ajustes de movimiento. La preferencia OFF no modifica
la física de la resbaladilla ni el contrapeso de las tablas.
