# Validación del renderizado

Se comparó el nivel Lvl-00 de PC con el decodificador del repositorio
`SheepStealer2001/sdw-decomp` disponible localmente. Su visor actual usa WebGL
directo, no Three.js.

- Las 14 páginas PNG coinciden byte por byte con RGB/alpha decodificados del DAV.
- Los 60.828 vértices del escenario coinciden en posición, UV y color con el
  decodificador del repositorio, después de convertir las unidades/eje vertical.
- Godot conserva los 71.241 colores de escenario, objetos y personajes con error
  menor a 0.0001 respecto al JSON: ahora guarda los bytes originales / 255 y
  recupera la modulación / 128 para superficies texturizadas en el shader.
- Las 14 texturas importadas conservan todos los bytes originales y no tienen
  mipmaps. Se desactivaron compresión VRAM con pérdida y reparación del borde alfa.
- Verificación en GPU de color sin textura, modulación superior a 1, mezcla alfa
  y suma: cero fallos, tolerancia RGB de 0.015.

El modo predeterminado usa Nearest y el descarte alfa del visor. F6 activa Linear,
solicitado por `src/engine/polybatcher.cpp` del juego de PC, y elimina ese descarte.
Compatibility permite multiplicar y mezclar en RGB codificado como el renderizador
antiguo. Los shaders también convierten su resultado a lineal si se ejecutan en
Forward+/Mobile; la mezcla transparente de esos renderizadores puede diferir.

Las capturas usan una cámara fija y muestran el render anterior, el corregido
Nearest y el corregido Linear. No equivalen a una comparación píxel por píxel con
una captura del juego original: aún pueden diferir cámara, animación, niebla,
orden de transparencias, sombras y efectos. No se ha validado la fidelidad del
renderizador de PS1; estos recursos provienen de la versión de PC.

Para repetir, desde la raíz del proyecto con el ejecutable de Godot:

```powershell
godot --headless --path . --editor --import
godot --headless --path . --script build_native_resources.gd
godot --path . --script tools/verify_materials.gd
godot --path . --script tools/capture_level.gd -- --output=validation/after_viewer.png
godot --path . --script tools/capture_level.gd -- --pc --output=validation/after_pc.png
python tools/audit_source.py --decomp "ruta/sdw-decomp" --level "ruta/Levels/Lvl-00"
```
