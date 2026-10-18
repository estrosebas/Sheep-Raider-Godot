# Primera presentación para TikTok

Resultado: `renders/ralph-wolf-tiktok-v3.mp4`, vertical 1080×1920, 30 fps,
42 segundos. Nueve tomas de los niveles 00–03 y del plató, con los
modelos y las animaciones del proyecto. Música: `trip_v1.wav`, segunda pista
del catálogo original (niveles 01 y 05).
El montaje intercala la carrera del Correcaminos, el golpe de Sam y la roca
aplastando a Ralph. Es una presentación dirigida, no una partida completa.

## Repetir la captura

Desde la raíz del juego:

```powershell
python videos/ralph-wolf-demo/capture.py --godot 'C:/Users/estro/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe'
```

`--reuse` reutiliza las tomas ya capturadas. El script guarda imágenes reales
del viewport vertical de Godot y las codifica con FFmpeg; evita el tamaño
horizontal fijo de MovieWriter y no necesita cambiar `project.godot`.
En las tres acciones, MovieWriter se usa además para mezclar los sonidos del
juego por fotograma; se descarta su video horizontal y se conserva el audio
sincronizado con las imágenes verticales. La música baja durante las acciones.
Cada toma tiene posición, objetivo y recorrido en `tools/capture_presentation.gd`.
Para probar una sola imagen, ejecutar Godot con `--script` y los argumentos
`-- --shot=studio --still` (ralph, sam, forest, elastic, canyon, studio, race,
strike o crush). Las acciones usan los controladores existentes: recorrido y
BOX_DECL del Correcaminos, `_catch_player` de Sam y caída/crush de Rock_60.
Las cámaras de acción comprueban las paredes antes de colocarse.

La captura usa un directorio de guardado temporal y no escribe preferencias de
idioma. La partida real no se modifica. Los tutoriales y el HUD se desactivan
solo dentro del proceso de captura, sin cambiar las escenas jugables.

## Montaje editable

```powershell
cd videos/ralph-wolf-demo
npx hyperframes check --at 1,4,7,11,16,20,25,31,38
npx hyperframes preview --background --no-open --port 3017
npx hyperframes render --quality high --fps 30 --output renders/ralph-wolf-tiktok-v3.mp4 --workers 2
```

Editar títulos en `index.html`; decisiones y orden en `BRIEF.md` y `STORYBOARD.md`.
Los videos, la música derivada y las capturas están excluidos de Git y se regeneran
con `capture.py`. El fuente del montaje y las cámaras sí quedan versionados.
