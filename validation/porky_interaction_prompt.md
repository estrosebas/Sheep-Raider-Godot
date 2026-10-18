# Porky, lechugas y avisos contextuales

## Correcciones

- CIN03 vinculaba la oveja real al actor 2:59. Al terminar, OriginalLevelSequence aplicaba el último transform del actor cinematográfico, situado unos 18 metros fuera del huerto. Porky conserva el transform de entrada de la oveja y la devuelve al suelo al completar o saltar la lección; limpia el movimiento de demostración y restaura su postura de reposo.
- Las lechugas usan el modelo 5 original y su textura existente. La pose STAND rota y traslada las hojas respecto al pivote de la malla. Se evalúan los vértices con la misma paleta de piel del renderizador, se compensa la altura de esa pose y se ajusta cada planta al suelo. Se conservan APPEAR y OBJET al aparecer y al llevarla en la mano.
- Conversación con Porky: radio horizontal de 1 m y diferencia vertical máxima de 0,8 m. La lección automática mantiene su caja original y exige estar a menos de 2 m. Un objeto recogible cercano tiene prioridad sobre la conversación del NPC.
- Un único OriginalActionPrompt conectado a Ralph ofrece la misma selección que ejecuta E en nivel 00, nivel 01 y laboratorio. Usa DAV_IDI_IGLCRAI2 (55), bitmap 95, página 12, recorte 128×32 del DAV de nivel 00, fuente original e iconos de inventario. El movimiento de entrada/salida de medio segundo reproduce las ecuaciones de Wolf::DrawActionPrompt en scn_controllable.cpp; la tecla E adapta el botón de acción original.
- Las etiquetas Label3D heredadas permanecen ocultas para mantener compatibilidad con referencias existentes. El aviso se oculta durante cinemáticas, bloqueos de control e inventario abierto. La ayuda del laboratorio se muestra con H.

## Verificación

- `tools/test_porky_interaction_prompt.gd`: suelo de las ocho plantas animadas, alcance de Porky, prioridad y ejecución de recogida, lectura de notas, correspondencia entre aviso y E, ocultación durante cinemática y ausencia de etiquetas flotantes en los tres escenarios.
- `tools/test_level01_porky_clock_and_blast.gd`: salida normal y salida saltada de CIN03, oveja visible en la entrada del huerto; diálogos, lechugas y reloj existentes.
- `tools/test_level01_essentials.gd` y `tools/test_level00_closure.gd`: regresiones de mecánicas existentes.
- Captura con GPU: `porky_field_action_prompt.png`; muestra la oveja tras terminar la lección, las ocho lechugas y el aviso contextual original adaptado a E.
