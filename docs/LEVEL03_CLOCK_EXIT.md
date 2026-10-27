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

## Boca final y giro hacia la izquierda

La prueba anterior terminaba al llegar aZ=-42.3; el atasco reportado estaba
más adelante, enZ≈-40.1. Las caras nativas6639/6640 son la pared real de la
curva, también presente en el escenario visible. Su cara trasera no se ve
desde dentro del túnel. Detrás de ella, haciaX≥5 yZ>-39, no existe suelo.
La salida segura gira haciaX≈3.3 y desciende hastaZ=-34.

No se eliminan esas caras ni se amplía la reconstrucción de terreno. El
adaptador `original_local_walk_profile.gd`, configurado mediante
`port_balance.json -> walking_collision_profiles`, permite deslizarse por
la esquina al caminar: `wall_min_slide_angle=0` y `floor_block_on_wall=false`.
Solo se activa sobre suelo, en estados de caminar/reposo/sigilo/aterrizaje,
dentro de la boca del túnel. Restaura las opciones previas al salir de ella,
al correr, saltar o entrar en una cinemática. No fuerza dirección ni posición.

La prueba ahora recorre la salida completa hastaZ=-34.3, regresa aZ=-49 y
reproduce el atasco desdeX5.0,5.8 y6.6. Comprueba que llega andando al suelo
exterior, conserva la pared del acantilado, restaura las opciones fuera de
la zona y no modifica las colisiones de carrera.

## Pieza caída delante de la abertura (CIN5 / MiscStatic112)

La captura exterior permitió identificar otro bloqueo, más adelante todavía:
el objeto112 se desplaza en CIN5 de(3.40,5.11,-31.91) a(3.40,0.17,-31.40).
El dibujo bajaba4.94m, pero `OriginalObjectCollisions/MiscStatic_112` seguía
en su origen. Su caja llegaba hastaY10.16, bloqueando el paso por encima de
la pieza caída, cuya caja correcta termina enY5.22.

`original_cinematic_prop_collision.gd` enlaza las cajas de MiscStatic usados
en películas con sus actores, incluidas las posiciones durante la cinemática.
Se conserva la orientación mundial de las cajas nativas. Guarda y restaura
posición, rotación del dibujo y visibilidad mediante el mecanismo compartido
de controladores de checkpoint. Para partidas anteriores, recupera la pose
final de las películas marcadas como reproducidas. Los identificadores JSON
se comparan numéricamente al restaurar el progreso cinematográfico.

La prueba ejecuta realmenteCIN5 antes de atravesar el pasadizo, comprueba la
caja baja y camina hastaZ=-29.8, descendiendo al suelo exteriorY≈0.14. Las
versiones anteriores se detenían enZ=-34.3, antes de alcanzar este objeto.
El regreso andando se comprueba desde la cornisa superior: después de bajar
al suelo exterior, volver implicaría subir un desnivel de unos5m.
