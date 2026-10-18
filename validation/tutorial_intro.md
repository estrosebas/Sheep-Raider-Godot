# Intro del tutorial: CIN 1 original

La secuencia pedida pertenece al tutorial **Lvl-00**, no a Lvl-01. Se activa al entrar en la caja original `CIN01ACTBOX` (export 662), alrededor de la línea de salida de ACME. No se ha añadido inventario inicial ni un trigger colocado a ojo.

## Datos y comportamiento

`CinematicsManager::PostLoadInit/Update` en `src/objects/cinematicsmanager.cpp` carga las propiedades del manager (entidad 129). Su primera entrada especifica CIN 1, ACTBOX 662 y flags 2314 (`0x90a`). El tipo WAR `0x85` contiene el script; `Cine::Load` lo resuelve por ID.

`tools/extract_tutorial_intro.py` recupera **8 pistas / 100 claves / 18.16 s**, siete actores con 23 clips utilizados y ocho muestras de sonido. Los datos y recursos compartidos se guardan en `assets/cinematics/tutorial_intro`; la secuencia es `sequence.json`.

| Pista original | Actor / recurso de modelo |
|---|---|
| selector 2, entidad 52 | Ralph / modelo 0: `ANVIL1`, `SQUASH2`, `STAND7`, `STAND0` |
| selector 2, entidad 56 | Lucas / modelo 8: `STAND1`, `OK1`, `NO`, `OVER1` |
| selector 4, índice 0 | Prop del Correcaminos / modelo 15 |
| selector 4, índice 1 | Correcaminos / modelo 16: `BIPBIP`, `STOP`, `STARTCIN`, `STAND` |
| selector 4, índice 2 | Telón GAME OVER / modelo 17: `STAND3`, `FALL`, `STAND2`, `UP` |
| selector 4, índice 3 | Yunque / modelo 19: `ANVIL1`, `ANVIL3` |
| selector 4, índice 7 | Prop adicional de la secuencia / modelo 18 |
| selector 0 | Posición, rotación y focal de cámara |

Los identificadores de animación del guion usan la **tabla mapeada** del modelo, situada después de su tabla directa. Usar el índice directo daría clips equivocados: por ejemplo, Ralph ID 66 es `ANVIL1`, ID 59 es `SQUASH2`; Lucas ID 24 es `OVER1`. Se conserva la correspondencia en el manifest.

El telón es geometría y textura originales animadas, no un panel UI inventado. El yunque y el aplastamiento se reproducen por los clips y claves del guion. No se combina este script con la reacción independiente de `Anvil::HandleMessage(MSG_ANVIL_DROP)` usada por los letreros: son dos sistemas originales distintos.

## Reproducción e integración

`OriginalCinematicActor` construye los esqueletos y usa `LegacySkinRenderer`, incluidas escalas independientes. `OriginalSequence` interpreta posición, rotación, animación, visibilidad y focal. Las claves usan pasos de 16 ms; los modos hold/lerp y las rotaciones por el arco más corto se conservan. Las pistas 7/8 de attachment de esta secuencia están vacías.

El lector de visibilidad respeta las fases de los opcodes 4/5. Por ejemplo, el yunque se oculta a los 13.888 s y el telón a los 15.824 s. Los sonidos siguen las marcas embebidas de cada clip, limitadas por el siguiente cambio de animación para evitar cues de clips interrumpidos.

La focal del guion es una escala: `Camera_StartScripted` calcula `(512 * focalScale) >> 10`; escala 1066 → distancia de proyección 533. Se conserva el encuadre original **4:3** con barras laterales en pantallas anchas, evitando recortar los personajes verticalmente.

El director bloquea movimiento, salto, ratón e inventario; oculta los modelos jugables/NPC rígidos para evitar duplicados. Al acabar restaura cámara, HUD y control, mantiene las posiciones finales del guion y deja a Lucas con su modelo animado en `STAND1`. La zona solo lo activa una vez por carga del nivel. `start_sequence(true)` permite repetir la escena para desarrollo sin duplicar actores.

Los flags originales incluyen `CINE_NO_INPUT`, por lo que la escena no se salta por defecto. El inspector permite activar `allow_skip` para desarrollo; en ese caso E/Esc termina en el estado final. El guion tiene `voice_id = 0`: esta intro usa SND y no una voz de streaming. La conversación posterior CIN 5 y las primeras ayudas de cámara ya están enlazadas: ver [camera_training.md](camera_training.md).

## Pruebas y alcance

`tools/test_tutorial_intro.gd` comprueba caja de activación, bloqueo/restauración, cámara/focal, aplastamiento, clips del Correcaminos/Lucas, visibilidad del telón/yunque, reproducción completa, posición final, NPC animado, uso único y repetición. Se verificó también con renderizador OpenGL real en `intro_anvil.png`, `intro_squashed.png`, `intro_curtain.png` e `intro_daffy.png`.

La base ya permite importar y ensamblar Lvl-01. Para cerrar su misión aún faltan IA completa de Sam/ovejas, condiciones de captura/entrega, gestor de checkpoints del mundo y diálogos/guiones propios. La intro implementada corresponde únicamente a CIN 1 del tutorial; no declara portadas todas las cinemáticas ni todo el tutorial de Lucas.

`extract_tutorial_intro.py ... --verify` compara la secuencia, esqueletos, canales de animación, páginas DAV y las ocho muestras SND con los archivos originales, sin sobrescribirlos.
