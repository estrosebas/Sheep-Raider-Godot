# Objetos compartidos, inventario vacío y carrera

## Cómo probar

En el tutorial, **F8** abre `scenes/testing/ItemLab.tscn`. Hay siete objetos, metal móvil, una oveja y un receptor de sustos. F8 vuelve al tutorial. El inventario inicial continúa vacío: mantener **Tab** muestra su nube vacía; **A/D** selecciona y soltar Tab equipa. **Esc** cancela.

**E** recoge el objeto cercano o usa el equipado. **R** usa directamente el equipado, útil junto a otros pickups. **Q** coloca el objeto en el suelo. La colocación requiere una superficie válida delante del personaje. Para probar perfume: recogerlo, colocarlo con R, equipar el ventilador, apuntar hacia el frasco y encenderlo con R. La oveja del laboratorio responde al aroma.

En cohete: R despega/baja; **W/S** sube/baja, **A/D** gira y **Shift** acelera. El combustible y el daño aparecen en el laboratorio.

## Componentes reutilizables

Los siete modelos, páginas DAV, audios SND y modelos vestidos están en `assets/items`. No dependen de las texturas del nivel que los instancia. Las escenas `scenes/items/*.tscn` pueden arrastrarse a cualquier nivel; sus clases globales también se pueden crear directamente. Asignar un `item_id` único antes de añadir cada instancia.

```gdscript
var item = ItemCatalog.create_item(66, "nivel13:iman:1")
item.position = Vector3(2, 0, -3)
add_child(item)
# También: MagnetItem.new(), LettuceItem.new(), etc.
```

| Clase / ID original | Mecánica general implementada |
|---|---|
| `MagnetItem` / 66 | Atracción al estar equipado, hasta cuatro receptores; curva original de fuerza, radio 4 m, metal móvil o anclado. |
| `SheepCostumeItem` / 80 | Modelo vestido y animaciones originales, caminar a 2.5 m/s, balido y llamada a ovejas compatibles. |
| `GhostCostumeItem` / 125 | Modelo vestido y animaciones originales; acción de susto a receptores cercanos. |
| `LettuceItem` / 3 | Colocación, atracción de ovejas a 6 m, consumo acumulado de 3 s, retorno al punto de origen tras 10 s. |
| `PerfumeItem` / 39 | Colocación y fuente de aroma; el viento acumula/desvanece la distancia del aroma hasta aproximadamente 20 m. |
| `FanItem` / 7 | Encendido/apagado, audio de inicio y bucle, consulta de receptores en el cono original de 4 m. |
| `RocketItem` / 10 | Despegue, dirección, altura, impulso, combustible, daño por colisión, salida y animación `ROCKET3`. |

`GameItem` comparte recogida, equipamiento, mano, colocación, restauración, audio y señales. `ItemRules` contiene reglas numéricas sin referencias a escenas. `ItemCatalog` asocia los IDs con sus clases y recursos. Las propiedades exportadas permiten configurar instancias, por ejemplo el combustible y la durabilidad del cohete. El tutorial usa el cohete compartido con posición, pivote y propiedades de su entidad original.

Contratos para conectar objetos de cada nivel:

- Grupo `magnetic_targets`: `magnet_pull(source, strength, delta)`, `magnet_is_anchored()`, `magnet_contact(source)` y `magnet_release(source)`. `MagneticItemTarget` es un adaptador físico reutilizable.
- Grupo `fan_targets`: `on_fan_blow(direction, delta)`.
- Grupo `sheep_attractors`: `scent_position()`, `scent_strength()`, y opcionalmente `eat(delta)`.
- Grupo `sheep_targets`: `on_sheep_call(actor)`.
- Grupo `ghost_targets`: `on_ghost_boo(actor)`.

`SheepItemReceiver` demuestra seguimiento/consumo con física. El fantasma del laboratorio es un fixture que indica la recepción del susto. No sustituyen la IA completa de Flock, Sam o los fantasmas del juego. Las ovejas estáticas del tutorial todavía necesitan integrarse con su controlador de IA.

## Fuentes y fidelidad

Los modelos se extraen una vez de los WAR/DAV del juego PC: cohete Lvl-00, lechuga Lvl-01, ventilador/perfume Lvl-02, disfraz de oveja Lvl-07, imán Lvl-13 y disfraz de fantasma Lvl-14. `definitions.json` registra recursos y parámetros; `original_catalog.json` registra las clases inventariables encontradas en `scn_register.cpp`.

Las referencias de comportamiento están en `src/objects` del repositorio sdw-decomp: Magnet, Salad, Fan, Perfume, Rocket y los disfraces. Se recuperaron sus radios, curva de fuerza, tiempos de lechuga, acumulación de perfume y consumo de combustible. La integración es una base jugable: el cohete usa dirección/colisión adaptadas a Godot; no incluye todavía rebotes originales, FlyBoxes ni retirada automática al terminar el vuelo. Los disfraces notifican su acción al pulsar, sin reproducir todo el flujo de mensajes original. El perfume usa un receptor general de aroma, pendiente de la selección de estados original de Flock. La rueda ya usa los tres fotogramas de crayón y los 27 iconos extraídos del DAV original; ver [original_inventory_ui.md](original_inventory_ui.md).

El catálogo también identifica dinamita, flauta, elástico, secador, detector de minas, paraguas, mina desactivable, caña, caña con imán, cronómetro, semillas, disfraz de conejo, mando, miel, caña con lechuga, llave, aspiradora, oveja inflable, monedas y aspiradora instantánea. Estas clases están registradas como **no implementadas**; no se presentan como objetos funcionales.

## Carrera

`RUNF2` dura 0.2 s y tiene cuatro claves de 50 ms. Faltaban las escalas: muslos y espinillas colapsan y los pies se estiran/giran. El torso conserva su movimiento sutil original. La importación añade rotación, posición y escala, con claves en el inicio de cada segmento y cierre continuo del ciclo.

`Instance_DrawAnimParts` aplica escala a cada pieza de forma independiente y al desplazamiento de sus hijos, sin heredar la escala en sus rotaciones. `LegacySkinRenderer` y `legacy_skin.gdshaderinc` implementan esa transformación, incluida la escala cero, sin convertir matrices degeneradas en cuaterniones. Se usa también para los modelos vestidos. Cada instancia tiene su propia paleta/materiales.

## Verificación

- `tools/test_shared_items.gd`: inventario vacío, dirección de la mano, los siete objetos, interacciones, combustible, salida, cambio/reset de disfraces y continuidad de RUNF2.
- `tools/test_inventory_mechanics.gd`: selección, entrada real, checkpoint del inventario, handlers y puntillas.
- `tools/test_run_mechanics.gd`: carrera, cansancio, impacto real contra muro, recuperación y salto.
- `tools/verify_materials.gd`: 71,241 vértices previos y 2,256 de objetos/disfraces compartidos; 14 páginas del tutorial y 13 compartidas, comparadas byte a byte. Comprobación GPU de la paleta de articulaciones, modulación, alfa y adición.
- `validation/capture_item_mechanics.gd`: capturas con OpenGL real en `run_corrected.png`, `costumes.png` e `inventory_empty.png`.

El rollback del estado del inventario sigue disponible. Restaurar objetos que ya salieron del inventario, aromas activos y entidades de nivel requiere que el futuro gestor de checkpoint guarde/restaure también el estado del mundo.
