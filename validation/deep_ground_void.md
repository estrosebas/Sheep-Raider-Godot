# Caída al vacío con suelo lejano

2026-10-07, Godot 4.7.2.

`check_void_below` protegía indefinidamente cualquier salto cuyo raycast encontrase suelo: la condición `not is_inf(ground_distance)` impedía STRIKE2 incluso cuando ese suelo estaba muy lejos. Además, comprobar únicamente la distancia bajo los pies permitía que un agujero de 31 m dejase de superar el límite de 30 m al descender los primeros metros.

La comprobación considera ahora la profundidad desde el origen del primer salto, o desde el último suelo cuando Ralph caminaba. Mantiene el límite existente de 30 m; no aumenta la sensibilidad de muerte a cualquier escalón. Encontrar suelo lejano ya no invalida la caída al vacío. Se conservan ascenso, doble salto, margen de descenso de 1 m respecto al primer despegue, coyote time, protecciones de cohete/cinemáticas y el controlador separado de carrera aérea.

El límite de 3000 unidades y STRIKE2 proceden de la lógica original de RUN_AIR. La comprobación compartida de salto respecto al origen y sus protecciones son adaptaciones del port; no se presentan como una traducción literal de `FallStateStep(32000)`.

`tools/test_deep_floor_void.gd`: **0 fallos**. Prueba suelo real a 31 m, descenso que reduce la distancia actual a menos de 30 m, ascenso, segundo salto/margen final, coyote time y aterrizaje seguro sobre plataforma a 3 m. Comprueba también el vacío real junto a la repisa del reloj del nivel 01, en `(32,-1.1,-26)`, y la activación de STRIKE2 con cámara retenida.

Regresiones `test_coyote_time.gd`, `test_level00_closure.gd` y `test_level01_refinements.gd`: **0 fallos**. El test antiguo de coyote time conserva avisos de recursos durante su cierre; sus comprobaciones funcionales pasan.
