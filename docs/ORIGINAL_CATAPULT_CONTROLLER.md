# Catapulta y roca transportable

Fuentes: `objects/catapult.cpp`, `objects/smallrock.cpp`,
`Wolf::WOLF_ST_CATAPULT_OPERATE` y `Wolf::CanPutDownHeldObj`.

## Configuración y reutilización

`scripts/levels/original_catapult.gd` recibe `data/catapults.json` y el banco
SND del nivel. El importador instancia las clases56 y65 con controladores
cuando el fichero contiene `rules`, excluyendo las colisiones estáticas
provisionales. El nivel05 conserva46/74 y el botón51 dirige su señal a46.

El controlador comparte potencia, cubeta, selección de carga, recorrido,
animación del brazo, sonidos y cámara. Por nivel cambian los datos WAR:
activación, dimensiones, orientación, trayectoria, alcance y CamSetup.
El laboratorio usa el mismo controlador; solo traslada el conjunto y ajusta
la altura final de la trayectoria a su suelo plano.

## Reglas recuperadas

- Potencia0..1024, centro512. Paso original6 por actualización, normalizado
  a360 unidades/segundo en Godot para no depender de los FPS.
- Brazo: `0xe60 + (power * 0x140 >> 10)`. Huesos6/7/8/9 conservan las
  fórmulas nativas de rueda y segmentos, con conversión ZXY del port y
  signo Z negativo del rig exportado. Así el disparo eleva la pala.
- Cubeta: extensiones de la caja no sólida, longitudes86/144/145,
  altura90 y offset-135 originales del05. Se expone un suelo móvil y se
  admite una carga suelta a la vez. Dos cargas impiden disparar. La cubeta
  conserva su colisión dinámica. Como adaptación, el chasis tiene colisión
  triangular de su geometría visible (huesos0..6), sin rellenar sus huecos
  con una caja. La activación acepta contacto de la cápsula a40cm del área
  nativa para alcanzar el regulador desde fuera del cuerpo sólido.
- Trayectoria cuadrática original, pasando por los tres puntos del WAR.
  La potencia desplaza el alcance±5m en05. `FindFreeLandingSpot` busca
  espacio lateral en pasos50, máximo1000 unidades.
- Lanzamiento kinemático durante la primera mitad; barridos en tres pasos
  durante la segunda. Las locomociones propias y la IA no compiten con el
  controlador. Después se devuelve el movimiento normal.
- La señal continua del botón dispara una sola vez hasta que se suelta.
- SND118 al regular, SND263 al disparar. Ralph alterna STAND0/TURN.
- HUD: ICTJAUG1, recurso DAV71, con fondo IGLCRAI2/DAV55. Flecha negra
  original en `x=(power*84>>10)+24`, y39. En móvil se baja bajo la fila de
  inventario/ayuda para evitar superponer controles.
- CamSetup572: ojo nativo(-322,-1825,3915), focal1236. El ojo permanece
  fijo y apunta al proyectil, manteniendo la toma dos segundos tras aterrizar.
  El port centra el objetivo visual0.35m por encima de su origen.

La cámara utiliza los datos originales; no introduce cierre/apertura circular
porque esta toma es una cámara de mecanismo, no una intro de nivel.

## Roca

`scripts/items/original_small_rock.gd` usa recogida/colocación del modo de
carga de Ralph y comparte su locomoción con `OriginalSheepCarry`. La roca
se une al joint18 con offset10 y no pasa por el inventario ni por el descarteQ.
La colocación comprueba ocho posiciones del cuerpo y suelo inferior, suelta
la roca a70 unidades sobre Ralph y92 delante, y después aplica gravedad15m/s²
con velocidad máxima10m/s. Su cono de colisión procede de los límites nativos.
El laboratorio tiene suelo140x140m, la catapulta en(-8,0,48), separada de
las puertas, y una repisa0.8m para reproducir el acceso desde el terreno
alto junto a la roca original, sin alterar el salto1.3m del modo de carga.

La roca pulsa botones. Un impacto de catapulta reproduce AROCHE5B/BREAK,
su cue93 y el golpe que puede dejar a Sam aplastado. Cuando termina BREAK,
vuelve al origen; también se recupera al caer al agua, al vacío o al reiniciar.
Un fin de trayectoria sin impacto retoma gravedad, como MSG_LANDED(0).

Los estados futuros de roca congelada/flotante y deslizamiento no se portan
en este cambio: el registro74 del05 no utiliza esas propiedades.

## Controles y verificación

- E: recoger/colocar roca, entrar/salir del regulador.
- A/D o cruceta/joystick: reducir/aumentar potencia.
- Pisar el botón: disparar la carga de la cubeta.

Extracción: `tools/extract_catapult_mechanics.py DECOMP LVL`; se incluye al
final del suplemento05. Después importar texturas, ejecutar
`tools/build_catapult_assets.gd` y `tools/build_run_animations.gd`.

Pruebas: `test_catapult_controller.gd` cubre laboratorio, recogida y colocación,
límites, sonidos, rueda, HUD, señal continua, las tres cargas y recuperación
ante muerte. `test_level05_catapult.gd` verifica la geometría real del05,
potencias0/512/1024, ojo572, seguimiento y liberación al aterrizar.
