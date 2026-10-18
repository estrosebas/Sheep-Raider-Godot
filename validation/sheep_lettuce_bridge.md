# Lechugas, ovejas y puente original

## Evidencia recuperada

- `src/objects/salad.cpp`, MSG_QUERY_NEAREST_TARGET: radio XZ de 600 unidades (6 m), ventana Y de ±150 (±1,5 m); puntuación de oveja = distancia² y de lechuga = distancia² + 360000. Valor HUD = distancia ×65535 /600. La búsqueda original denominada Vision comprueba disponibilidad y alcance, sin raycast de oclusión (`src/objects/sheep.cpp`, Flock_GetObjNearestAvailableSheep_Vision). La adaptación muestra por separado la oveja y la siguiente lechuga, con distancia y barra, para que ambos indicadores sean consultables.
- `src/game/scn_controllable.cpp`, Hud_DrawItemPrompt: crayon animado IGLCRAI1, icono de clase y aviso de límite a partir de 0xe665 (~90% del radio). Se recuperaron sus fotogramas del DAV y el icono original de oveja IMОICONA (47).
- `src/game/wolf.cpp`: WOLF_ST_THROW_ITEM usa PUT1A y luego PUT1B o STANDNO al rechazar; PUT2A/PUT2B para dejar la oveja. `wolf_misc.cpp`, CanPutDownHeldObj: ocho comprobaciones de cuerpo estático, offset cercano (0,-2,0), frontal (0,-70,-92), más offset de anclaje de la oveja (0,7,0). Resultado adaptado: 0,92 m delante y punto de prueba 0,63 m sobre Ralph. La adaptación añade soporte de suelo bajo las cuatro esquinas y limita el desnivel a 0,8 m, evitando depositarla sobre vacío y falsos rechazos en pendientes.
- `src/objects/sheep.cpp`: hueso de Ralph 0x12 (18), offset original (0,7,0), orientación de raíz. En los modelos del port, a t=0,15 de STAND8, lana Y mínima=0,774 y Ralph Y máxima=1,149: se añade una corrección visual de 0,38 m, manteniendo el anclaje y el offset originales. La corrección entra durante TAKE2B y sale durante PUT2A. Esta altura adicional es una adaptación medida del port, no un nuevo valor atribuido al ejecutable original.
- Se verificó también el volumen nativo del modelo1: flags2, límites (-35,-80,-35)..(35,0,35), equivalentes a 0,7×0,8×0,7 m. El port conserva su caja conservadora con esas medidas y centro Y=0,4 m.
- Sheep::MSG_KILL: KILL_FALL_PIT activa caída sin colisión y Fade_StartRestart(0x7000), 7 s; KILL_GENERIC aplica tint negro y Fade_StartRestart(0x3000), 3 s. Ambos vuelven al checkpoint y restauran ovejas y puente, con fundido de salida. Se contemplan tanto vacío profundo como los pozos locales declarados en OriginalFallZone.
- `src/objects/bridge.cpp`: dos mitades, zonas FALLINGZONE del export WAR579, maestro OTHERPART461. POSE2 dura 0,24 s; contador 6 congela a Ralph, contador 12 colapsa con BRAKE2 (2,08 s), después FBRAKE2. Si desaparece el peso adicional, se cancela y vuelve POSE1. Cámara lateral si la separación supera 3 m, distancia mínima de cámara 6 m y altura 1 m. Sonidos recuperados: 105 crujido; 14 y 66 durante BRAKE2. La adaptación elimina los dos colliders al colapsar y los reconstruye al reiniciar.

## Componentes compartidos

OriginalPlacement, OriginalLettuceGuidance, OriginalLettucePrompt y OriginalSheep contienen las reglas reutilizables. OriginalBridge recibe definición de zona, directorio del modelo y banco de sonidos; el importador del nivel 01 solo le asigna los datos recuperados. El laboratorio usa ahora OriginalSheep para probar transporte, indicadores y pérdida con las mismas funciones.

## Comprobación

- `tools/test_sheep_lettuce_bridge.gd`: suelo real, muro, borde, rechazo sin pérdida, colocación válida, PUT1A/B, liberación de inventario, estado OBJET, umbrales XZ/Y, indicadores de oveja y cadena, puente con Ralph solo/con oveja, crujido105, dos suelos retirados, rollback tras caída, explosión real y vacío libre.
- `tools/test_level01_refinements.gd`: carga real con TAKE2A/B, anclaje elevado, fatiga, sigilo, salto único y PUT2A/B sobre suelo despejado.
- `tools/test_level01_porky_clock_and_blast.gd`, `tools/test_porky_interaction_prompt.gd`, `tools/test_level01_essentials.gd`: regresiones de diálogos, oveja de la lección, HUD y mecánicas existentes.
- Capturas GPU: `lettuce_distance_and_sheep.png`, `lettuce_native_put1a.png`, `level01_sheep_carry_idle.png`, `bridge_native_pose1.png`, `bridge_native_brake2.png`.

Extracción reproducible: `tools/extract_sheep_bridge_mechanics.py DECOMP GAME`, `tools/build_sheep_bridge_mechanics.gd`. STANDNO se agrega con el extractor y constructor de animaciones de Ralph existentes.

Extracci�n independiente del HUD: `tools/extract_lettuce_prompt.py DECOMP GAME`.

## Refinamiento: iconos, cadena y cantidades

- `engine/scn_register.cpp` registra SALAD con ILAICONB en el primer argumento de icono, y SHEEP con IMOICONB. `engine/scenaric.cpp::Scenaric_RegisterClass_2` guarda ese argumento en registry.iconA; `Scenaric_DrawClassIcon(useIconB=0)` usa ese registro. Por tanto los archivos cuyo NOMBRE termina en ICONB son los que corresponden al HUD, no los ICONA usados en la primera extracci�n. Fondo IGLCRAI1 confirmado tambi�n por `Interface_Init` y `Sam::DrawZoneIndicator`.
- `Sheep::FindNearestAttractor(1)` busca a �150 Y/600 XZ de `lastFoodPos` despu�s de comer, y SHSF_KEEPS_RESERVATION conserva el objetivo. El port ahora conserva reservas durante aproximaci�n/comida, y contin�a la cadena desde la �ltima lechuga sin repetir SMEL1 entre cada paso. Prueba f�sica de dos lechugas separadas 5,5 m sobre el puente real: ambas consumidas, reserva estable ante otra oveja cercana.
- `InvWheel_DrawSlot`: Text_SetCursor(x+2,y+2) es coordenada superior, no baseline. Se suma el ascenso de fuente y se dibujan cantidades despu�s de todas las nubes/iconos; captura con siete lechugas seleccionadas muestra x7.
- Sam conserva TRES estados del original: verde #2a701f, naranja #a0500f, rojo #f01000. `capture_sam_palette.gd` comprob� los p�xeles GPU contra esos tres valores; no se a�adi� brillo arbitrario. Lechuga conserva DOS tintes (azul #282850 y rojo #501010), umbral 0xe665. Son constantes de funciones distintas, aunque comparten el crayon.
- Verificaciones: `tools/test_bridge_lettuce_chain.gd`, `validation/test_inventory_count_capture.gd`, `validation/test_capture_lettuce_hud.gd`, `validation/capture_sam_palette.gd`.

## Correcci�n de pose de carga

La separaci�n de .38 m y posteriormente .08 m compensaba una pose incorrecta. La conversi�n de los clips sheep_* de Ralph usaba YXZ y un signo Z equivocado. Se corrigi� a ZXY y se deshizo la negaci�n Z del decoder, igual que en Sam. `tools/test_ralph_carry_pose.gd` compara cada hueso de la primera clave de todos esos clips con una transcripci�n independiente de `Mat44::SetRotYXZ` (row vectors, �ngulos clockwise y reflexi�n Y). Ambas manos quedan por encima de los hombros y carry_visual_lift vuelve a 0: solo anclaje nativo hueso18 y offset -0,07 m.

El Skeleton3D de Ralph tiene ahora `ralph_editor_preview.gd` (@tool): eval�a idle con el mismo LegacySkinRenderer del juego �nicamente en el editor. En runtime no inicializa nada. La malla WAR contiene piezas y requiere su paleta de matrices; el editor antes mostraba piezas sin esa deformaci�n. `validation/test_ralph_editor_preview.gd` comprueba Engine.is_editor_hint, paleta inicializada y material use_legacy_skin. La regeneraci�n es `tools/build_run_animations.gd`; capturas de idle/fatiga/sigilo/salto fueron actualizadas.
