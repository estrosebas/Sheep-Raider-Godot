# Corrección de orientación del mundo

El visor original del repositorio establece en `tools/editor/level_editor.html:197`:

```javascript
// game space -> view space: the game's y points down, and z is turned too so the view is not a mirror image
const toGL = v => [v[0], -v[1], -v[2]];
```

Nuestros exportadores intermedios habían negado solo Y, usando `(x,-y,z)`. El mundo aparecía en espejo: la carretera, los letreros y hasta las letras del cartel ACME quedaban invertidos lateralmente.

`scripts/levels/game_space.gd` centraliza la conversión. Los JSON/OBJ intermedios se conservan para compararlos con el decoder original; al construir recursos nativos se aplica la Z que faltaba. No se aplican escalas negativas a cuerpos físicos ni una inversión de imagen a la cámara.

- Escenario, objetos del nivel, Daffy, oveja y modelos estáticos compartidos: vértices con Z negada; índices de cada triángulo invertidos para conservar culling y normales. UV y colores se conservan.
- Colisión: misma conversión, antes de crear el `ConcavePolygonShape3D`.
- Entidades: posición del cohete convertida desde el JSON. Spawn y personajes de `Level00.tscn` actualizados. La cámara inicial mira en la dirección equivalente después de la conversión.
- Ralph y modelos vestidos: sus poses y bind vertices permanecen en el espacio de los exportadores; `LegacySkinRenderer` convierte el resultado evaluado una sola vez. La mano recibe la misma transformación. Orientación del controlador y de objetos equipados adaptada a la cara frontal +Z del modelo convertido.
- Generadores: `build_native_resources.gd` y `tools/build_shared_items.gd` conservan la corrección al regenerar recursos. Los extractores siguen produciendo datos intermedios, sin una segunda inversión accidental.

El spawn jugable pasa de `(-87.41,0.50,-43.45)` a `(-87.41,0.50,43.45)`. El cohete pasa de `(-93,8.22,-2.85)` a `(-93,8.22,2.85)`. X no cambia; izquierda/derecha vuelve a coincidir al corregir la orientación del mundo y su cámara.

`tools/capture_level.gd` convierte también su cámara fija, permitiendo comparar las mismas posiciones originales antes/después. Capturas: `map_orientation_before.png` y `map_orientation_after.png`; el cartel ACME es legible en la segunda.

Validación: `tools/test_game_space.gd` comprueba **69,153 vértices** del escenario/objetos/cohete, orden de triángulos, spawn, cámara, cohete, raycast al suelo y aterrizaje real. Las pruebas de carrera, inventario y objetos pasan después del cambio. La verificación de materiales mantiene los colores/páginas originales y la prueba GPU de articulaciones.
