# Cielo, interrupciones y carteles

El cielo del tutorial contiene nueve recursos WAR tipo `0x26` (201–209), 11094 vértices sin textura. `src/objects/world_draw.cpp::WorldObj_DrawSky` usa mundo identidad y elimina la traslación de la matriz de vista. Antes se agregaban esos recursos al terreno: las nubes parecían objetos pequeños sobre el mapa. Ahora tienen una malla independiente con la rotación de cámara original, sin paralaje, niebla, colisión ni escritura de profundidad. Se conserva la escala original y se coloca su profundidad al fondo para que no tape el terreno. `scenery_data.json` sigue siendo el archivo bruto para auditorías; `scenery_world_data.json` excluye el cielo.

`RalphController.interrupt_actions()` cancela carrera, salto/doble salto, impulsos externos, polvo y sonidos, inicia reposo y detiene los usos activos de ventilador/cohete. Se llama al comenzar cinemáticas, instrucciones de Lucas y lectura de carteles; los bloqueos mantienen a Ralph quieto durante la escena. Disfraces equipados e inventario se conservan.

Los textos proceden de la MLT original, bloque español 2 y lista `class_id + 1`. `interface.cpp::Dialogue_Show` usa una ventana inferior paginada con `FONT_GAME` y letterbox; `Ui_DrawSubtitleBox` añade panel y marco para carteles. La presentación de Godot se adapta a lo pedido: sin fondo, texto blanco con contorno negro, manteniendo texto, páginas y controles de PC. No se ha importado la fuente bitmap original.

`SignPost::PostLoadInit`, `HandleMessage` y `Update` recuperan las distancias Manhattan XZ de 200/200/500 unidades, los textos 0/1/2 elegidos por orden de primera lectura, y cámaras 622/623/624. **E** lee/cierra; en la pregunta **A/D** selecciona Sí/No y **E** confirma; **Esc** cierra. La variante se mantiene al releer. Sí envía el equivalente a `MSG_ANVIL_DROP` y `MSG_WOLF_DAZE`: animaciones originales ANVIL1 de ambos actores, ANVIL2 del yunque, sonidos de sus claves y cámara específica. Como `Anvil::Update`, la cámara se libera tras 2000 ms de espera y ANVIL2 continúa hasta ocultarse. Componente reutilizable mediante `definitions_path`, `player_path` y el grupo `world_interactables`.

Validación:

- `tools/extract_sky_signs.py --verify`: verifica geometría y textos/cámaras contra WAR/DAV/MLT originales.
- `tools/test_sky_signs.gd`: separación sin pérdida de vértices, interrupción de carrera/salto y audio, estilo transparente, interacción E, distancia original, orden/relectura y yunque/cámara/restauración.
- `validation/capture_sky_signs.gd`: capturas del cartel, yunque y subtítulos; comparación GPU del cielo con cámaras trasladadas 250/80/−150 m. Sin movimiento del cielo; diferencia máxima de redondeo MSAA 1/255 en 11 píxeles.
- Pruebas existentes de tutorial, cámara, inventario, coordenadas y materiales.

Corrección de profundidad: Godot utiliza Z invertida. El plano lejano es `CLIP_SPACE_FAR` (−1 en Compatibility, 0 en Forward+/Mobile). El shader previo usaba +1 para Compatibility, que es el plano cercano y hacía que las nubes taparan montañas y actores. Ahora proyecta el cielo en `CLIP_SPACE_FAR + epsilon`. `tools/test_sky_depth.gd` verifica en GPU que un objeto delante del cielo mantiene exactamente el mismo color que con el cielo oculto; `sky_depth_corrected.png` confirma las montañas delante del fondo.
