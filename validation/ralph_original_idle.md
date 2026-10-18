# Reposo original de Ralph

El port reproducía un único idle importado anteriormente. Se recupera STAND0 del ACOYOT01 de Lvl01 como base, más las cuatro variantes STAND1, STAND2, STAND3 y STAND5. La rotación usa la transcripción de Mat44::SetRotYXZ reflejada en Y (Godot ZXY deshaciendo el signo Z extra del decoder), igual que la corrección de carga de oveja. Se conservan las posiciones y escalas nativas y los tiempos de inicio de los segmentos, sin forzar manos ni offsets artificiales.

Wolf::g_wolfIdleAnims define STAND0 (3..5), STAND1 (1..2), STAND2 (5..6), STAND3 (5..6), STAND5 (1). Wolf::SetIdleState y ScnControllable::NextIdleAnim usan un contador decrementado al terminar cada bucle: al llegar a cero desde la base escogen aleatoriamente una de cuatro variantes; luego vuelven a STAND0. OriginalRalphIdle implementa esa tabla y ese decremento, incluidas las claves de sonido de STAND2 y STAND3. Se suspende durante cinemáticas, transporte de oveja, vuelo del cohete, ventilador en uso y controles bloqueados.

Con objetos equipados, `Wolf::SetIdleState` (wolf.cpp, 0x48786d) cambia de banco: STAND10 para objetos de mano y ROCKET1 para el cohete en la espalda. `IdleAnimStep` (0x48797d) conserva STAND10 durante Rand_Bounded(5), es decir contador0..4; al terminar intercala una STAND9 y vuelve a STAND10. El C++ reserva variantes particulares para flauta y bufanda, aún no implementadas como objetos jugables aquí. Los objetos actuales de mano comparten STAND10/STAND9; ROCKET1 se mantiene en bucle sin esa variación. La selección depende del objeto realmente adjunto a Ralph, no de una lista que sólo incluya dinamita/ventilador/perfume. El fin de una acción y el regreso a reposo tras moverse eligen directamente el banco correcto.

La lechuga sigue `Salad::MSG_PICKUP`: pose ALAITU01 LINK y matriz completa del hueso18, sin desplazamiento adicional. Ya no orienta el objeto con look_at ni conserva la elevación visual usada por la planta en el suelo.

La biblioteca se regenera con tools/extract_run_assets.py y tools/build_run_animations.gd. El preview del editor también usa el idle corregido de la misma biblioteca.

`tools/extract_held_idle.py PATH_TO_LVL_03` recupera STAND10/STAND9/ROCKET1 con sus31 huesos, posiciones, escalas y tiempos. Se integran a la misma biblioteca global usando la matriz original ZXY; no se fuerzan brazos ni coordenadas de mano.

Prueba test_ralph_idle.gd: compara todas las matrices de la primera pose de las cinco animaciones con una transcripción independiente del C++, verifica contadores, variantes, regreso a reposo y supresión en cinemáticas. Captura GPU: ralph_original_idle.png. La regresión de carrera comprueba restauración de escala al idle nativo, que contiene escalas distintas de uno; no exige eliminar las escalas originales junto al squash del choque.

`test_held_item_idle.gd` comprueba lechuga equipada, matriz de muñeca y LINK, STAND9 y regreso a STAND10, transición desde caminar y desde acciones, objetos compartidos, ROCKET1 y regreso a manos vacías. Captura GPU: `lettuce_original_hand_idle.png`. Regresiones: `test_dynamite_hand_pose.gd` y `test_level02_interactions.gd`.
