# Ralph Wolf 1.0.6

Aplicación 1.0.6, Android versionCode 6, contenido firmado secuencia 5.
Conserva las claves existentes, Godot 4.7.2, ABI 1 y guardados compatibles.

- Niveles 06 y 07, con sus recursos, personajes, objetos, reloj y cinemáticas.
- Bloques de hielo empujables, rebote corto para permitir volver a empujarlos,
  bola de nieve, detector de minas, superficies rompibles y huellas.
- Correcciones de entrega de buzones, bombas y puertas del escenario.
- Ayudas de cámara opcionales, desactivadas inicialmente.

Las pruebas automatizadas del nivel 07 cubren importación, hielo, recorrido de
bola de nieve, buzones y reloj; también se verifica el ciclo de explosión de
minas y las puertas del escenario. El recorrido completo requiere pruebas del
jugador; la ejecución del contenido Android en el motor de PC no sustituye
una prueba en un teléfono físico.

Publicación mediante las herramientas locales de distribución y actualización,
con comprobación de hashes antes de activar los archivos del servidor.

## Publicación verificada — 1 de noviembre de 2026

Commit de juego `05aafc7`, subido a origin/main. Exportaciones locales:
`builds/distribution/1.0.6`; paquetes firmados: `builds/updates-1.0.6`.

- Windows ZIP: 187680216 bytes; CRC verificado.
- Android APK: 181083652 bytes; firma verificada e idéntica a la 1.0.5.
- Manifiestos públicos Windows/Android: 1.0.6, secuencia 5, firmas RSA válidas.
- Web: index.html e index.js coinciden con el build; WASM y PCK responden 200
  con los tamaños correctos. Los instaladores y latest.json también coinciden.
- Todos los archivos fueron comprobados por SHA256 en el servidor antes de
  activar la distribución.
- Se conserva la publicación anterior para recuperación; nueva carpeta remota:
  `/home/noox/web/sheepraider.nooxtools.me/deployments/1.0.6-f9e1fc317b93`.

Ocho pruebas de mecánicas/cámaras y cuatro pruebas de firma sin fallos.
Ambos paquetes compilados cargaron los niveles 06 y 07 sin fallos en el motor
Windows, usando cachés y guardados aislados. Pendiente prueba física Android.
Evidencias locales: `validation/release106_*.log`.
