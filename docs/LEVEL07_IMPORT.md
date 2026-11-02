# Siguiente nivel: Lvl-07 nativo (nivel6 del juego original)

Escena de pruebas: `scenes/levels/Level07.tscn` (F6). Octava puerta del
laboratorio; el plató descubre la escena mediante el sistema de progreso
existente, desbloqueada tras lvl_06. La numeración interna incluye el tutorial00.

## Importado y conectado

-75 entidades,19 modelos,11 páginas DAV y4617 triángulos de colisión.
  Escenario, cielo y modelos visibles en el editor. Materiales opacos0..6,
  transparencia7..9 y aditivo10; imágenes originales sin compresión con pérdida.
-Spawn original elevado, coordenadas y cajas nativas; no se recentra el mapa.
-Sam48 con su ruta y recuperación de golpes corregida;10 ovejas49..58.
-Dos buzones:59 entrega detector72 (vista previa);60 entrega disfraz71
  con el controlador compartido de disfraz de oveja y llamada.
-Cuatro botones36/37/39/42 y compuertas64..67, con sus objetivos y cámaras
  originales. Las cámaras respetan la opción de ayudas, desactivada por defecto.
-Cuatro minas73..76 usan OriginalDefusableMine, ondas, sonidos, panel, ritmo,
  códigos nativos y controles de teclado/móvil. No son el campo de minas ocultas.
-Reloj62, goal85, tres checkpoints, guardado/progreso compartidos.
-Tres letreros originales, música por segmento/bucle del catálogo, sonidos.
-CIN0 de16.624s: recorrido inicial y demostración, sin diálogo ni Lucas.
  Catalogada intro_cinematic, con iris al devolver el control.
-Once zonas de cámara, seis con trayectorias; dos regiones DAV animadas.

## Mecánicas nuevas conectadas

-SlidingIceCube33/34/40/43/45/46: empuje cardinal con los ejes y zonas
 originales, velocidad8m/s, rebote único y frenado8m/s². Colisión móvil,
 transporte de Ralph, ovejas y objetos; evita duplicar la velocidad de plataforma.
 Sonidos124/127. Los bloques activan las ondas de las minas y sobreviven al blast.
-IceGround32/35/38/41/44: explosión de mina/bomba dispara EXPLOD1, con sus
 sonidos originales si los hay; al terminar desaparece la colisión. Reset repara.
-SnowyGround31: sostiene a Ralph; otro cuerpo sólido encima dispara EXPLOD1
 y libera inmediatamente la colisión. Sin Reset nativo: conserva el colapso.
-Snowball63: empuje compartido, esfera inicial al25%, crecimiento durante20s
 efectivos de rodadura hasta0x333/1024, comprobando suelo y espacio; sonido123.
 Conserva posición/tamaño al morir, según Snowball::Reset vacío.
-MineDetector72: levantar DETEC3, DETEC1/2 al escanear quieto/caminando,
 bajar DETEC4. Pose del objeto y mano evaluadas juntas, loop258, medidor DAV
 original. Busca minas a2m y±1m de altura en semicono60°; para el campo enterrado
 traza el rayo por los bordes de hazardBoxes y safeBoxes originales.
-GroundMine61: campo oculto con sus siete zonas seguras. Entrar en una parte
 peligrosa dispara la explosión en el punto del personaje/oveja y daño alrededor.
-Huellas: tres PRINTSBOX y sprites IPASNE01 alternos, permanentes en anillo128;
 separación1.5m, tamaño nativo30 unidades; profundidad activa y proyección al suelo.
 No se estampan sobre objetos, en el aire ni con disfraz de oveja.
-Tres SLIDEBOX usan el controlador de pendientes compartido.
-Guardado de posición de bloques, tamaño/posición de bola y rotura de superficies
 a través de checkpoint_controllers. El detector se guarda como el resto de objetos.

Pendiente: MirrorManager91 (reflejo) y adaptación exacta del perfil de movimiento
sobre hielo plano (ICEBOX). Las pendientes sí están conectadas. Los estados de
bloques ligados a FrozenRiver en otros niveles quedan fuera de este mapa sin río.
No hay balancines, catapultas, Lucas ni diálogos suyos en este WAR.

## Reproducción

Con DECOMP apuntando a sdw-decomp y LVL a Levels/Lvl-07:

```text
python tools/extract_level_scene.py DECOMP LVL --all-animations --runtime-adjusted
python tools/extract_level_runtime.py DECOMP LVL
python tools/extract_imported_level_content.py DECOMP LVL
python tools/extract_level04_environment.py DECOMP LVL
python tools/extract_level_goals.py LVL
python tools/extract_camera_zones.py LVL
python tools/extract_mine_mechanics.py DECOMP LVL
python tools/extract_level07_supplement.py LVL
python tools/extract_snow_mechanics.py DECOMP LVL
python tools/localize_imported_level.py lvl_07
python tools/create_imported_level_scene.py lvl_07
```

Importar en Godot, ejecutar configure_native_level_textures.py lvl_07,
reimportar y construir con build_level_scene.gd, build_level_runtime.gd,
build_imported_level_content.gd y build_mine_assets.gd (cada uno -- lvl_07).

Validación: tools/test_level07_foundation.gd, entrada real, colisión del spawn,
actores, inventario de buzones, minas compartidas, cámaras y escritura de save
en carpeta temporal. Ejecutado con OpenGL,0 fallos. Captura:
validation/level07_overview.png. No valida completar todavía el nivel hasta el goal.

Validación de las mecánicas: tools/test_level07_snow.gd. Usa colisiones reales
para transporte y rebote, mina real para rotura, escaneo orientado con zonas
seguras, animación/audio del detector, crecimiento por desplazamiento de la bola,
colapso bajo peso, anillo de huellas y captura de checkpoints.0 fallos con OpenGL.
Esto cubre interacciones concretas, no una partida completa hasta el goal.

## Entrega, caída y reloj revisados

El encuadre de entrega espera la caída desde la altura original y la apertura de
la caja (adaptación de cámara libre: max del TIMER nativo y tiempo de caída/8
más1.5s). El detector sigue cayendo tras salir de la caja mediante MovingSupport:
la caja puede apoyarse en un borde, mientras el objeto más pequeño continúa hasta
el suelo real. Conserva las coordenadas originales de entrega.
La bola acepta empuje desde cualquiera de sus cuatro lados, con ajuste a90° de
Wolf::SnapHeadingToObject (respuesta0 al no sobreescribir QUERY_PUSH_AXIS). Sus zonas nativas siguen
limitando el lugar por donde se desplaza.
TimeKeeper62 está importado en la cámara inferior y se ha probado su interacción
real y la marca de progreso. No se duplica ni se mueve al indicador del techo.
Todas las cámaras nativas del mapa están importadas:11 zonas,6 recorridos,
2 de buzones,4 de botones yCIN0. Zonas y botones requieren Ayudas de cámara:Sí;
las cámaras de entrega se reproducen también con las ayudas desactivadas.
Prueba: tools/test_level07_delivery_clock.gd; entrega física, apertura, caída del
objeto hasta el suelo, selección cardinal, reloj y catálogo de cámaras.0 fallos.

## Paso estrecho y empuje dedicado del hielo

SlidingIceCube usa ICEPUSH1(0.4s) y ICEPUSH2(0.41s), correspondientes a
Wolf::PUSH_ICECUBE/KICK_ICECUBE_END; el mensaje USE se envía entre ambas.
El bloque puede desplazarse mientras termina la recuperación de Ralph.
El paso junto a cube33 tiene aproximadamente0.54m de ancho. El primer modelo
original de Ralph declara cajaX/Z[-18,18], frente a la cápsula general del port
con diámetro0.70m. OriginalIceAccess usa radio0.18m cerca del pie de los bloques,
sin tocar sus cajas ni las paredes; restaura0.35m al alejarse. El ajuste local
permite deslizarse por las esquinas sin eliminar la colisión real.
test_level07_ice_access.gd recorre físicamente ese paso en el mapa real, inicia
el empuje desde atrás, comprueba ICEPUSH1, desplazamiento y restauración de cápsula.

## Bola hacia el disfraz: prueba de recorrido nativo

Snowball no sobrescribe MSG_QUERY_PUSH_AXIS: devuelve0 y Ralph ajusta el rumbo
a90°. Las ZONE originales forman unaL estrecha: tramoX y después tramoZ.
Al crecer, el adaptador de roca conservaba la distancia original del empujador;
al terminar se restauraba colisión con Ralph dentro de la esfera. La recuperación
física expulsaba la bola fuera de su ZONE, impidiendo cualquier empuje posterior.
Se mantiene al empujador fuera del radio creciente mediante un movimiento con
colisión, antes de terminar el empuje. Se conservan paredes y zonas originales.
test_level07_snowball_route.gd mueve la bola real, sin trasladarla entre tramos:
X hasta257.734, después Z hasta-222.651 junto al disfraz, y vuelta hacia-224.3.
Incluye soltar/reenganchar desde otra cara con pequeño error de aproximación.
0 fallos. Las entregas de buzón son escenas de acción independientes del toggle
opcional de ayudas; ya no se omiten cuando este está desactivado.

## Rebote corto del hielo

Ajuste solicitado para el port: mantiene la ida a8m/s y el rebote único,
pero limita el impulso de retorno a3m/s con frenado8m/s². Así retrocede
aproximadamente0.54m en0.375s, en lugar de unos4m al invertir toda la velocidad.
El sonido y el transporte de pasajeros se conservan. test_level07_snow comprueba
contra una pared física que el retroceso final quede entre0.45 y0.65m y permita entrar a Ralph detrás.

El límite de zona ahora invoca el mismo rebote que la pared: anteriormente ese
caso ponía la velocidad a cero antes de llegar a la detección de colisión.
La prueba recorre físicamente el hueco de la pared con Ralph y vuelve a iniciar
el empuje desde ese lado; también verifica el endpoint sin pared.
