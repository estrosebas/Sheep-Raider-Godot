# Salida del reloj: escalones que parecían una pared

La captura del fallo corresponde al nivel03, aunque el reporte lo llamaba02.
El recinto del reloj86 sale a la zona del segundo balancín, entre paredes
moradas. La puerta del reloj70 del02 se validó aparte con su plataforma48/46.

La colisión del03 ya se reconstruía localmente desde el escenario visible para
retirar una cara nativa que tapaba la abertura. Quedaban dos contrahuellas de
unos48cm, en Z=-48.3 y Z=-46.28. CharacterBody3D chocaba con ellas al caminar.
La prueba anterior saltaba sobre ese borde, por lo que no cubría el problema.

`port_balance.json -> clock_floor_seams` especifica ambos bordes inferiores.
`original_visual_collision.gd::soften_floor_seams` retrasa esos vértices1.2m,
uniendo la altura baja y alta mediante pendientes continuas. Se conserva el
suelo superior, las paredes, el techo y la altura del reloj. Los datos y la
selección se limitan al recinto ya corregido; no hay cambio global de salto,
teletransporte ni regla general que permita atravesar paredes.

`test_level03_clock_passage.gd` recoge realmente el reloj, cruza caminando
sin pulsar salto y vuelve por la misma abertura. También comprueba que los
triángulos completamente exteriores a la región siguen siendo los nativos.
