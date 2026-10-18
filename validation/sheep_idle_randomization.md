# Animaciones de reposo del rebaño

## Reposo de ovejas sin sincronización

Sheep::EnterIdleState usa Rand_Range(5,10); NextIdleAnim elige STAND4 (1..3 repeticiones) o BAH (1..2), vuelve al reposo con3..6 y selecciona velocidad12..20/16. El port antes arrancaba todos los visuales a t=0, velocidad1 y contador6. Ahora usa velocidades/contadores independientes, fase inicial aleatoria y también desfasa SLEEP1/pensamiento del sueño. OriginalCinematicActor.idle_speed vale1 por defecto; solo las ovejas en reposo lo aleatorizan, y carga/persecución de alimento vuelven a velocidad1.

Por petición del usuario se añade exclusión por OriginalFlock: una sola oveja puede reproducir STAND4/BAH a la vez, sin cola sincronizada; las demás siguen su reposo y reintentan al completar un ciclo posterior. La propiedad se libera al terminar, atraer, cargar o reiniciar, y no bloquea la comida ni la locomoción. Esta exclusión es una adaptación de presentación; g_pSheepFxOwner original corresponde a efectos de agua/hielo y no demuestra una exclusión original de STAND4/BAH.

Prueba tools/test_sheep_idle_randomization.gd: 80s simulados, fases y velocidades distintas, pico1 variante simultánea, siete ovejas distintas participando, liberación por interrupción y checkpoint; 0 fallos. test_bridge_lettuce_chain.gd: la cadena real sobre el puente sigue consumiéndose, 0 fallos.
