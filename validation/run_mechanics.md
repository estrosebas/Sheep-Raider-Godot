# Carrera y choques básicos

Las reglas están en `scripts/player/ralph_run_rules.gd`: funciones sin lectura de
Input, escena, reproducción de audio ni animación. El controlador es el adaptador
que suministra pulsaciones y contactos y ejecuta los resultados.

## Correspondencia con sdw-decomp

| Original | Adaptación |
| --- | --- |
| `Wolf::RunTapCheck`, wolf_misc.cpp, 0x48def7 | `run_tap_check`: ventana 0x199..0xc00 ticks, aproximadamente 0,10..0,75 s. El timeout tiene prioridad sobre una nueva pulsación. |
| `ScnControllable::SteerRun`, scn_controllable.cpp, 0x492d9f | `run_speed_step`: perfil normal 1200 unidades/s, aceleración/frenado 1200 unidades/s²; giro limitado según el perfil. |
| `Wolf::RunSound`, wolf_misc.cpp, 0x48d6eb | `begin_run_sound` / `update_run_sound`: SCOSRUN1 una vez, espera su final, SCOSRUN4 en bucle en el mismo canal. |
| Estados 0x22/0x23/0x24, wolf.cpp | RUN_START → RUN → RUN_STOP. El arranque y el frenado duran sus animaciones importadas, sin cortes fijos de 0,35/0,45 s. |
| Estado 0x2d, wolf.cpp | RUN_RECOVER / STAND7; salir al caminar o tras cinco segundos en reposo. |
| `Wolf::RunMove`, wolf_move.cpp, 0x48bc2d | `is_run_crash`: al menos media velocidad, impacto frontal dentro de aproximadamente 60°, contacto al menos 0,7 m sobre los pies. |
| `Wolf::RunStep`, wolf_move.cpp, 0x48cf34 | Parar movimiento y pasar a RUN_CRASH / STRIKE1 hasta terminar su animación. |

El original sostiene la carrera con pulsaciones, no con una barra de resistencia
que se vacíe al mantener el botón. Mantener Shift ya no renueva el temporizador.

Se extrajeron STRIKE1 (1,58 s) y STAND7 (0,696 s) del WAR original. Se conservaron
las demás animaciones. `ralph_run_data.json` contiene poses, duraciones, sonidos
por fotograma y la correspondencia entre IDs SND y WAV existentes, verificada
comparando bytes. Se reproducen las señales de audio de frenado, choque y
recuperación en sus tiempos originales; RUN_STOP antes usaba SCOGLISS, que es
el sonido de deslizamiento y no los sonidos asociados a SLIDE1.

La deformación usa `Instance_DrawAnimParts` (animation.cpp, 0x550e98): jerarquía
de rotación/traslación sin heredar escalas, offset de cada hijo multiplicado por
la escala de su padre, y escala individual de cada pieza al final. Esta regla
también es una función neutra: `reaction_pose_transforms`. El adaptador utiliza
poses globales en Skeleton3D para evitar que Godot acumule escalas no uniformes.
Los overrides se limpian al salir y se restablecen las escalas antes de clips
antiguos que no tienen esas pistas.

## Extensión a objetos y efectos

El controlador emite `run_impact(collider, normal, point, speed)` y
`run_recovery_started`. Un cuerpo puede implementar
`on_ralph_run_impact(ralph, point, normal, speed)` como adaptación del mensaje
original MSG_BUMP. La metadata `run_impact_exempt = true` evita la reacción, como
la exclusión original por bandera de clase. Los contactos se evalúan con la
velocidad anterior a `move_and_slide`, antes de que la pared la elimine.

Las funciones permiten añadir objetos rompibles, partículas, sacudida de cámara
o respuestas específicas sin cambiar las reglas de carrera. El salto y doble
salto conservan su física; durante choque/frenado el estado bloquea el salto.

## Verificación

Ejecutar con Godot desde la raíz:

```powershell
godot --headless --path . --script tools/test_run_mechanics.gd
```

La prueba comprueba ventanas de pulsación, mantener Shift, aceleración,
recuperación, continuidad de audio más allá de la duración del WAV, choque
contra una pared física real, bloqueo y liberación de la animación, ausencia de
impactos repetidos, salto y doble salto. Comprueba también las exclusiones de
contactos lentos, bajos y tangenciales con entradas controladas.

Para volver a extraer/construir las animaciones añadidas:

```powershell
python tools/extract_run_assets.py "ruta/Levels/Lvl-00"
godot --headless --path . --script tools/build_run_animations.gd
```

La equivalencia completa sigue pendiente para RUN_AIR, superficies heladas,
pendientes especiales, sacudida/estrellas del choque, zonas y movimiento sobre
plataformas. Godot resuelve los contactos con una cápsula; el motor original
utiliza su propio barrido y datos de contacto. No se afirma igualdad exacta de
todas las trayectorias ni de los tiempos visuales del interpolador original.

Referencia de la repetición de WAV en Godot:
[AudioStreamWAV](https://docs.godotengine.org/en/stable/classes/class_audiostreamwav.html).
