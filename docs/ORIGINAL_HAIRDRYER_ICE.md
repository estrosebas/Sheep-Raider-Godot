# Secador, hielo y Lucas militar

Fuentes locales: `sdw-decomp/src/objects/hairdryer.cpp`, `icecube.cpp`,
`daffymilitary.cpp` y `seesaw.cpp`; recursos del WAR/MLT/SND de Lvl-06.
El nivel nevado mostrado al jugador corresponde a esta carpeta interna.

- HairDryerItem conserva el modelo15 y su unión nativa al joint18. Usa
  HELD_FAN de Ralph (STANDV1/WALKV1), sin reutilizar el modelo del ventilador.
  Encender/apagar con la acción de usar. Radio horizontal4m, semicono409/4096
  de vuelta, volumen vertical[-1,+3]m desde el objeto sujeto. El origen de
  consulta sigue la mano; no se añade una prueba de oclusión ajena al original.
  Sonido283 en bucle, detenido al guardar/cambiar objeto, morir o iniciar cine.
- OriginalIceThaw mantiene STAND2 inicialmente. FOND1 solo avanza al recibir
  calor; conserva calor parcial al apagar el aparato. Con1s acumulado desactiva
  la colisión y libera a Lucas; FOND1 termina por sí sola y deja FLAC1.
  La caja mantiene su base fija y reduce la altura durante el calor. Se usa
  una reducción acotada por progreso, en lugar del incremento acumulativo con
  máscara de bits del ejecutable antiguo, para evitar depender del framerate.
- Level06 cinematics posee exclusivamente CIN1 (53.296s, voz38), reservada
  por el director. Guarda el secador en inventario, no lo consume. Al acabar,
  Lucas adopta STAND2, su colisión se coloca con él y ofrece tres consultas.
  Voces96/97/98 y textos MLT58 localizados en los cuatro idiomas existentes.
  STAND2 cambia a TALK1 después de2s; gira hacia Ralph al hablar.
- Una bomba junto a Lucas libre aplica el tinte negro y congela su pose.
  Hablar por primera vez inicia la réplica original cin_lvl_0105, con sus
  páginas temporizadas y bloqueo de Ralph hasta terminar, sin permitir saltarla.
  No se repite hasta el reinicio. Volver a hablar conserva las consultas.
- El guardado conserva hielo derretido, lección terminada, posición de Lucas,
  tinte y castigo. Reiniciar sin completar la lección vuelve a congelarlo;
  reiniciar ya libre lo mantiene libre y limpia tinte/castigo como el nativo.

## Dos balancines del tramo final

Res36 es el lanzador con la roca38: límites15°/15°, las dos trayectorias
nativas de1.024s y cámara original focal562/eye[8004,-2456,5394], flagNO_FREEZE.
Su primer arco lleva a Ralph a la tabla de equilibrio35; no se inventa fuerza.

Res35 es la tabla con flagSLIDE y límites1°/80°. Peso nativo: Ralph60,
oveja40, roca120. La lechuga no tiene peso nativo: sirve para posicionar la
oveja y contrapesar a Ralph. Sus momentos dependen de la distancia al centro.
Por encima de56 unidades angulares (unos4.92°), el controlador compartido
envía el aviso de deslizamiento. Ralph recibe la deriva de sin(tilt) m/s;
la oveja entra en FALL con tiempo inicial0.5s, gravedad15m/s² y tope14m/s,
resolviendo la bajada sobre el plano y conservando el movimiento al salir del borde. La huella de apoyo se calcula sobre el plano
rotado para no sostener actores sobre una tabla que ya se volvió vertical.
La lechuga conserva el soporte móvil existente y cae si pierde superficie.

Pruebas: tools/test_level06_thaw_seesaws.gd y regresiones de balancines02/03.

## Correcciones de la secuencia oveja/roca

El contacto CustomCollide nativo llama AddBody antes de Update: el port conserva
ahora el evento de aterrizaje y su velocidad entre prioridades de física, lo
consume una vez y registra también el golpe de la oveja que llega a la tabla35.
El impulso no se pierde entre los pasos fijos de40ms del balancín. Las caras
inclinadas que sostienen una oveja no se descartan por velocidad positiva del
soporte. Se cuenta el margen mundial de su caja también en una tabla rotada.

CamShot original permite cualquier entrada de salto después de1s; no termina
por sí mismo. El port conserva esa opción y, para la cámara libre, añade retorno
automático al finalizar el vuelo del sujeto real (roca, oveja o Ralph), sin
esperar siempre un aterrizaje de Ralph. Cada nuevo lanzamiento rearma el sujeto.

`test_level06_seesaw_chain.gd` repite la caída real de roca desde tres posiciones,
con prioridades distintas, verifica llegada y caída sin contrapeso, retorno de
la cámara para roca/oveja y equilibrio estable con Ralph. No teletransporta la
roca al impacto ni finaliza manualmente las cámaras durante la comprobación.

La oveja en espera sobre una tabla sin SLIDE conserva su posición X/Z:
se neutraliza el arrastre lateral de la plataforma de Godot y la proyección
de gravedad sobre su inclinación. Sigue la altura de apoyo y puede caminar
hacia comida/llamadas; el lanzamiento sigue activo. Solo la tabla35 con SLIDE
aplica la caída/deslizamiento. La prueba de cadena comprueba120 frames de
espera estable sobre la tabla36 antes de soltar la roca.

## Ajuste del segundo balancín al recoger la oveja

port_balance.json habilita free_tilt SOLO en la tabla35 del nevado. La suma
de momentos impulsa su inclinación de forma continua hasta el límite nativo
80°, en vez de fijar un pequeño ángulo de reposo. Si el peso queda compensado
se detiene; al salir los ocupantes conserva el impulso hacia el tope.
Es un ajuste de comportamiento del port, no un nuevo parámetro recuperado del
WAR. No cambia la masa nativa de Ralph ni cuenta dos veces a la oveja cargada.
El descenso de Ralph sobre esta tabla se resuelve por el controlador de
pendientes también en carga (SLIDE4), manteniendo la oveja sujeta. La tabla
lanzadora36 queda intacta. Reiniciar restablece el ángulo y el impulso.
La prueba de cadena reproduce ahora Ralph con oveja en mano en el extremo,
además de la espera estable y el contrapeso de ambos en extremos opuestos.
