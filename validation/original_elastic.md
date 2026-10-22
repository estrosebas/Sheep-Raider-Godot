# Elástico: implementación compartida y procedencia

Fuentes locales: `sdw-decomp/src/objects/elastic.cpp`, `elastictree.cpp`,
`game/wolf.cpp` y `game/wolf_move.cpp`; datos de Lvl-03.war/SND.
No se generaron modelos ni animaciones sustitutos.

## Qué configura el nivel

`tools/extract_elastic_assets.py` extrae las propiedades de cada clase42 y
los destinos de cada clase45 a `assets/levels/<nivel>/data/elastic.json`.
Forma parte de `extract_imported_level_content.py`, también para siguientes
niveles. No hay una rama exclusiva de Level03 en el controlador.

| Propiedad WAR | Nivel03, convertido a Godot |
|---|---:|
| DISTANCE_PROJECTION,0x0 | 50m, multiplicados por la tensión al disparar |
| HAUTEUR_PROJECTION,0x4 | 5m, multiplicados por la tensión |
| cámara,0x8 | CamSetup596, focal619 y ojo original |
| LONGUEUR_MAX,0xc | 11,5m |
| VITESSE_PROJECTION,0x10 | 20m/s |

LONGUEUR_MAX limita el vector de estiramiento que usa `ApplyTension`.
Con dos extremos, ese vector es `2*Ralph-(anchorA+anchorB)`; **no es una
longitud máxima de separación entre árboles**. El código original no
impone otra comprobación de distancia al enganchar el segundo extremo.

Cada árbol conserva el identificador de restricción de cámara y el
**mínimo de su BOX de retorno**, convertido X,-Y,-Z. No se usa el centro
del BOX ni un destino calculado a partir del árbol. La cámara libre del
port se mantiene al usar árboles; el lanzamiento de otro objeto sí usa
el CamSetup original y devuelve cámara/control al finalizar.

## Componentes reutilizables

- `OriginalElasticItem`: clase42 del catálogo/inventario, modelo21,
  icono42, STAND y unión exacta a la mano18.
- `OriginalElasticTree`: modelo original, anclaje a80 unidades sobre
  su origen, información de retorno y detección horizontal80/vertical128.
- `OriginalElasticController`: enganchar, recuperar, desenganchar un
  extremo, tensión, cruce de banda, yo-yo, tirachinas y catapulta.
  El movimiento se conecta a Ralph mediante un modificador compartido
  de desplazamiento y un propietario temporal del vuelo/retorno.
  Otros objetos pueden participar agregándose al grupo
  `elastic_launch_targets`, además de ovejas, rocas, cajas y GameItem.
- Guardado opcional de ambos IDs de árbol dentro del registro del objeto.
  Partidas anteriores sin este campo siguen funcionando. Al reaparecer,
  la banda tendida se conserva y las acciones transitorias se cancelan;
  una banda con un único extremo vuelve a ser un objeto.

La banda original es geometría procedural opaca: seis vértices, anchura
vertical12 unidades, doble cara. Se reconstruye sin textura inventada.
La tensión comienza a la mitad de LONGUEUR_MAX. El impulso por cruce se
activa al saltar o sostener tensión>=0xe00 durante1000ms.

El retorno usa el coseno original hasta0xa00 y velocidad0x266=6,14m/s.
BOX.min es el punto alto de ese coseno: **no se teletransporta al destino**
al terminar. La física vuelve a resolver el aterrizaje. La proyección usa
la trayectoria seno original y tres subpasos de colisión. La vibración
refleja su parámetro y reduce su amplitud a3/4 en cada rebote.

`DRAU1` y `DRAU2` se extrajeron con31 huesos, se integraron al banco global
como `elastic_pull_idle/move`, usando ZXY y los signos del renderer nativo.
PUT1A/PUT1B y TAKE1A reutilizan los clips compartidos existentes. El sonido
del elástico es SND_SEAELAST235 de SND original.

Adaptaciones de física: el modificador cambia el desplazamiento sin
retroalimentar la velocidad de gravedad; conserva los truncados Vec3s y
el cálculo entero de fuerza/ms. La recuperación de contacto de Godot
mantiene plantados los pies antes de saltar. Un objeto disparado ignora
temporalmente el cuerpo de Ralph para salir sin atascarse, restaurando
la excepción anterior al aterrizar o cancelar.

## Laboratorio y prueba

En `scenes/testing/ItemLab.tscn`, árboles a la izquierda, al fondo:
X=-20/-12,Z=-24; elástico cercano X=-21,Z=-26 y oveja al costado.
Recoger conE, equipar desde el inventario, E junto al árbol para enganchar;
E junto al segundo para tenderlo. E en la banda para tirar, movimiento
para tensar y E para soltar cerca de una oveja/objeto. Para catapultar a
Ralph, cruzar la banda, seguir tensando y saltar. Junto a un extremo,
E lo desengancha; junto al único extremo restante, E recupera el objeto.

Otra estación al extremo izquierdo tiene escalones y una plataforma de
14m, árbol y segundo elástico para probar el yo-yo. Su punto alto se
configura por encima de la plataforma como los BOX originales.

`tools/test_original_elastic.gd` prueba con física real las acciones del
inventario, radios, DRAU1/DRAU2, lanzamiento de oveja, catapulta de Ralph,
aterrizaje, restitución de cámara, desenganche/recuperación, caída/retorno
a plataforma, cuatro árboles originales y restauración del checkpoint.
Usa un directorio temporal de partidas y no toca las partidas del usuario.

Validación: prueba propia headless y GPU, estaciones previas del
laboratorio y lanzamiento del segundo balancín03: cero fallos.
Captura: `validation/elastic_lab.png`.

## Ajuste de jugabilidad del nivel03

`assets/levels/lvl_03/data/port_balance.json` configura únicamente este nivel:
el vector de tensado con dos extremos pasa de11,5m a9,5m. El alcance de
un extremo continúa usando11,5m para que siga siendo posible enganchar
los árboles originales separados11,52m. Los registros WAR extraídos no
se sobrescriben; el laboratorio copia este mismo perfil para probarlo.

Catapulta y tirachinas exigen carga completa; el margen del98% absorbe
la resolución de centímetros y se muestra/usa como100%. La catapulta
puede dispararse saltando con carga completa o manteniendo el máximo
durante1s, sin necesidad de saltar. Soltar manualmente con carga parcial
destensa la banda, sin lanzar la oveja con un recorrido insuficiente.
La proyección completa conserva50m de recorrido y5m de altura originales.

Se corrigió el contacto con pendientes pequeñas: un paso de hasta15cm
respecto del suelo, sin salto real, conserva el contacto del rider en vez
de activar la rama aérea que reducía a1/4 su avance. Antes quedaba cerca
del80% y podía lanzar por una pérdida momentánea de contacto. Se conserva
la velocidad acumulada y se añade un desplazamiento de contacto hacia
abajo; la gravedad y los saltos normales siguen resolviéndose en Ralph.

El bucle de estiramiento es **SND_SEABOUCL284/SEABOUCL.WAV**, recuperado
de `Wolf::UpdateMoveLoopSound` en `wolf_misc.cpp`. Es una pista separada
del golpe **SND_SEAELAST235**, con PCM original y sin modificar el tono.
Se detiene al dejar de tensar, soltar, lanzar, cancelar o morir; el golpe
se reproduce en la posición de la banda en vez del origen del mundo.

`tools/test_elastic_level03_balance.gd` prueba la carga parcial en el aire,
el bucle original, llegada real al100%, lanzamiento caminando, liberación
manual parcial/completa y devolución de controles/cámara. En Level03
recorre el hueco de los árboles99/101 con Ralph y con una oveja, verificando
aterrizaje en terreno al otro lado. Directorio de partidas temporal.

## Panel de medición (Suprimir)

**Estado actual:** desactivado a petición del usuario. Las líneas que lo
instancian en Ralph están comentadas; no responde a Suprimir ni crea HUD.
El código y sus pruebas se conservan. La prueba instancia explícitamente
el panel archivado, sin habilitarlo en el juego normal.

`scripts/testing/elastic_tuning_menu.gd` se conecta una vez al controlador
compartido de Ralph; está disponible donde existan elásticos, incluido el
laboratorio. Suprimir abre/cierra; Escape vuelve al juego. El editor usa
controles numéricos para longitud con uno/dos extremos, fuerza de resorte,
velocidad de retorno, carga mínima/completa, espera y proyección. Se puede
aplicar a uno o a todos los objetos presentes, y guardar el perfil en
`user://elastic_tuning.cfg`, independiente de partidas, progreso e idioma.
El archivo se separa por nivel y se vuelve a leer al crear el controlador.

Valores originales toma constantes de C++ y propiedades WAR; Ajuste del
nivel restaura el perfil del port. Aplicar afecta la prueba actual; Guardar
ajuste lo conserva para próximas entradas. Cambiar longitud de un extremo
a menos de la separación entre árboles puede impedir completar el enlace;
por eso los controles de un extremo y de tensado son independientes.

La ventana pausa la física y la mecha, devuelve el ratón y evita abrir
simultáneamente el menú de Escape. Al cerrar restaura el control del ratón.
El monitor opcional muestra tensión/estado, cronómetro manual de juego,
medición automática de bajada/espera, colocación y subida/aterrizaje, la
mecha real de cada bomba encendida y margen estimado durante el retorno.
Una medición interrumpida se señala y el tiempo dentro del panel no cuenta.

Revisión del original: `elastic::MSG_MODIFY_MOVE / ELASTIC_SUB_WOLF_INTERACTING`
retorna inmediatamente tras acabar la acción estando más de300 unidades
debajo del anclaje, sin exigir LONGUEUR_MAX otra vez. Esta rama faltaba y
ahora se activa después de PUT1A/PUT1B o de empujar un objeto. `StartPullUp`
conserva0x266=6,14m/s y el coseno hasta0xa00; la resistencia conserva el
truncado entero original, con multiplicador1 por defecto.

La cápsula de Godot puede perder el borde al acabar en BOX.min. En el tramo
final del coseno se acomoda XZ suavemente al suelo superior válido más
cercano (hasta2m), comprobando cinco rayos y el volumen de la cápsula.
Se conservan altura y tiempo de la curva original; no hay teletransporte
al suelo. Si no existe punto válido, conserva el destino original.

El WAR del nivel03 configura dinamita107 con0x0=5000, es decir **5s**, no8s.
El importador ahora asigna el tiempo de cada instancia desde su propiedad
nativa, en vez de depender del valor por defecto del script global.
No se amplió la mecha para ocultar el problema del retorno.

`test_elastic_tuning_menu.gd` usa Suprimir/Escape reales, edición mediante
SpinBox, pausa de la mecha, persistencia en config temporal, ambos presets
y colocación real de dinamita junto a la roca85 con anclaje100. Requiere
suelo real después del retorno, sin aceptar la bandera is_on_floor que
puede quedar antigua mientras la curva posee el movimiento.
Medición de esa colocación/retorno: **3,12s**, quedan **2,27s** de mecha.
Captura del panel: `validation/elastic_tuning_menu.png`.
# Corrección compartida: oveja y reaparición (22/10/2026)

`Wolf::Move` (`src/game/wolf_move.cpp`) aplica los modificadores registrados
también al usar el banco de movimiento de cargar oveja. El port de
`OriginalSheepCarry` omitía esa fase antes de `move_and_slide`: la liga se
dibujaba, pero no limitaba el movimiento ni activaba el regreso. Ahora aplica
el mismo modificador y conserva la velocidad base con resolución de normales.

`elastic.cpp`, `MSG_MODIFY_MOVE`, `ELASTIC_ST_TIED_ONE`:
al terminar la interacción, si Ralph está más de 300 unidades nativas bajo el
anclaje, `StartPullUp(..., 0x266)` inicia el regreso. Recoger una oveja arriba
no dispara un regreso incondicional. El mismo retorno conserva la oveja en
brazos y usa su animación de caída de carga.

En la reaparición normal, el elástico de un extremo vuelve al inventario
oculto, sin crear una recogida en el suelo: reset/store/add, equivalente a
`Wolf::StoreActiveItemInInventory`. Se conservan identificador, icono y estado
kept. Una liga entre dos árboles permanece colocada. Restaurar un checkpoint
usa exclusivamente los anclajes guardados, sin añadir simultáneamente el
objeto al inventario.

`test_elastic_carry_and_respawn.gd`: recogida real de oveja bajo una plataforma,
retorno con carga, suelo superior, muerte Sam, inventario sin duplicados,
modelo listo para reequipar, liga entre dos árboles y carga real de checkpoint
del05: **0 fallos**. Regresión `test_original_elastic.gd`: **0 fallos**.
