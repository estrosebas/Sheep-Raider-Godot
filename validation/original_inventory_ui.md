# Rueda de inventario original

La nube procedural fue sustituida por el sprite de crayón original. La ilustración del juego es un parche blanco con trazos diagonales, no los círculos crema que tenía la versión provisional.

## Recursos recuperados

- `interface.cpp`, `Interface_Init`: `g_animSpriteCrayon1.InitFromRes(DAV_IDI_IGLCRAI1)`.
- `scenaric_props.h`: `DAV_IDI_IGLCRAI1 = 25`.
- `Lvl-00.DAV`, recurso 25: apunta al bitmap 67. `Res_FindBitmapGroup` busca su **dirección de registro**, no su alias en la tabla de índices; el grupo encontrado contiene los bitmaps **65, 66 y 67**, en ese orden.
- Tres fotogramas de **48×32** píxeles; `AnimSprite::InitFromRes` usa tamaño de dibujo **47×31**, descontando un píxel. `Tex_CornerUV` excluye el texel final de relleno. Las `AtlasTexture` de Godot reproducen esa región sin alterar los PNG extraídos.
- 27 iconos recuperados según el primer parámetro de icono de `Scenaric_RegisterClass_2`. Aunque varios recursos terminan en `ICONB`, son el campo `iconA` del registro que dibuja la rueda; el extractor respeta ese orden del C++.

Los PNG y su trazabilidad están en `assets/ui/inventory/original_ui.json`. Recursos compartidos: ningún nivel necesita volver a importar la nube o sus iconos. `tools/extract_inventory_ui.py` extrae directamente de DAV; `--verify` compara los 30 PNG contra sus recortes RGBA originales.

## Funciones trasladadas

Referencia: `src/engine/progress_inventory.cpp` del repositorio sdw-decomp.

| Función C++ | Implementación Godot |
|---|---|
| `InvWheel_DrawSlot`, 0x50c81f | Sprite de crayón, icono centrado y cantidad `xN`. Las manos vacías dibujan solo el sprite. |
| `InvWheel_GetSlotPosColor`, 0x50c98a | Espacio 512×240; X = 256 + cos·150; Y = −150 − sin·200 + slide. Frente en (256,50), color 0x808080; vecinos atenuados hasta 0x303030. |
| `InvWheel_Draw`, 0x50caca | Selección, vecinos, caso especial de una clase y cuarta casilla durante el giro. |
| `InvWheel_Render`, 0x50ccf1 | Fotograma `(frameCount >> 2) & 255`, con módulo de los tres fotogramas para la casilla seleccionada; vecinos usan el fotograma cero. |
| `ItemFly_Render`, avance de rueda | Giro a 0x400 unidades/s hacia 0xc00; paso 0x155, duración 341/1024 s. Entrada/salida a 180 unidades HUD/s, desplazamiento −32→0. |

Las fórmulas reutilizables están en `scripts/inventory/inventory_wheel_rules.gd`; `inventory_wheel.gd` realiza el dibujo y mantiene referencias a las texturas. Se eliminó el generador de nubes por círculos, el borde dorado, las etiquetas dentro de las casillas y los iconos derivados de modelos 3D. Los controles de ayuda y notificaciones siguen siendo los del port, y el contador usa la fuente de Godot: no se ha portado todavía `FONT_DEBUG`.

Cambio posterior solicitado: los tres fotogramas del crayón se actualizan ahora cada 0.2 s, mediante tiempo y no por FPS del motor. El giro/deslizamiento conserva sus reglas originales.

## Comprobaciones

- `extract_inventory_ui.py ... --verify`: 30 recortes idénticos byte a byte al DAV.
- `tools/test_inventory_ui.gd`: importación sin cambios de RGBA/mipmaps, tamaño/grupo, posición, brillo, giro y entrada/salida, sin fallos.
- `tools/test_inventory_mechanics.gd`: selección y entrada real, sin fallos con el tiempo de giro original.
- `tools/test_shared_items.gd`: objetos, equipamiento e inventario vacío, sin fallos.
- Capturas OpenGL reales: `validation/inventory_empty.png` y `validation/inventory_shared_items.png`.
