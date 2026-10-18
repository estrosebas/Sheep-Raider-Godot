# Dinamita sobre plataformas móviles

La bomba encendida tiene `available=false` para impedir recogerla.
El adaptador de soporte exigía `available=true` y además solo se agregaba
automáticamente a las clases3/39: la clase2 no era transportada.

`GameItem.follows_ground_support()` separa el estado de carga del estado
de interacción; Dynamite lo mantiene durante la mecha y explosión.
`OriginalMovingSupport` sigue la transformación del soporte, mantiene
el punto local y usa la superficie actual de lift/balancín/plataforma.
Esto evita seguir un paso atrás debido al transform anterior del raycast.

La colocación de dinamita vuelve a consultar suelo al terminar PUT1A y
registra el soporte. Ralph conserva su punto local durante PUT1A/PUT1B
si la plataforma se mueve durante la animación. El soporte se actualiza
con prioridad física150 y la bomba con200, de modo que la explosión usa
la posición actual del mismo tick. La mecha no se reinicia ni se amplía.
Respawn/restauración elimina la relación de soporte anterior.

El menú/HUD de Suprimir quedó comentado en `ralph_controller.gd` y no se
instancia. Se conservan scripts y pruebas para futuras sesiones de ajuste.

`tools/test_level03_dynamite_lift.gd` ejecuta colocación real con la plataforma
56 moviéndose durante PUT1A, descenso, ascenso al extremo nativo, mecha,
explosión durante movimiento, limpieza y descubrimiento de soporte desde
una creación sin soporte explícito. También comprueba que Suprimir no
abra el panel ni pause el juego. Headless y GPU: cero fallos.

Regresiones: colocar lechugas sobre ambos bordes del balancín02 y retorno
del elástico después de colocar la bomba03: cero fallos. Las partidas se
guardan en directorios temporales de prueba; no se modificó la del usuario.
