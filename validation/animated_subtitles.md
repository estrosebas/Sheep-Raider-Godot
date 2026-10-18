# Letras animadas y tamaño de subtítulos

OriginalLevelDialogue conservaba una Label con BMFont, que dibujaba celdas estáticas a 36 píxeles sin ajustar a la resolución. Ahora esa Label conserva texto, paginación y sincronización de voz, mientras OriginalSubtitleCanvas dibuja directamente el mismo atlas original que la pausa.

El subtítulo usa celdas de 15 × 15, interlínea 17 y márgenes horizontales 32 en coordenadas virtuales 512 × 240; se escala uniformemente a la ventana. Valores verificados en Text_LoadFontAtlas (cellGeometry=2) y Dialogue_Show de text.cpp/interface.cpp. El color amarillo se ajusta a la captura PS1 del usuario; se mantienen franjas negras y páginas originales de audio/texto. CameraTraining del tutorial 00 usa también este renderer, manteniendo la indicación de controles del port.

OriginalGameFont.animated_glyph comparte con pausa y carteles las tablas Fwd/Rev recuperadas en assets/ui/pause/source.json. Alterna adelante, atrás y base cada 62 ms (ciclo 186 ms), según Text_BlinkButtonGlyphs. El código PC distingue este parpadeo de botones del shuffle estático Text_ScrambleGlyphs al cargar el banco: aplicar la animación de pausa a todos los diálogos y carteles es la adaptación solicitada, no una afirmación de que ambos caminos nativos PC fueran iguales.

Validación: test_ui_polish.gd verifica variantes por fase, medidas originales y conserva pruebas de idiomas, paginación de subtítulos y pausa. Ejecución headless y GPU: cero fallos. Captura comparativa de la frase de la referencia: animated_subtitles.png.
