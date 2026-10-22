# Ralph Wolf1.0.5 — nivel05

Versión de aplicación1.0.5, Android versionCode5, contenido firmado secuencia4.
Se conserva Godot4.7.2, ABI1, la clave pública del actualizador, el identificador
Android y su firma de publicación. Los guardados anteriores se conservan.

## Contenido

- Nivel05 con escenario, texturas, agua, personajes, buzones, objetos,
  reloj, goal, checkpoints, puertas y cinemática de entrada.
- Plataformas móviles con estado persistente y transporte de objetos.
- Transporte de ovejas en balsas incluso mientras Ralph acciona mecanismos
  desde tierra o una cinemática pausa la IA.
- Elástico aplicado también al cargar una oveja, recuperación en inventario
  al morir y ajuste del resorte62/67 para acceder a la entrada del reloj.
- Escalada reutilizable con zonas nativas, cinco animaciones, sonidos,
  movimiento lateral, salto, soltarse y salida superior desde el recinto.
- Fondo del río coherente con el degradado original y acceso05 desde el hub
  y el laboratorio. La portada anuncia niveles00–05.

La importación y sus limitaciones están detalladas en `LEVEL05_IMPORT.md`.
Se distribuye el avance jugable actual; no se declara portado todo el juego.

## Validación previa

Las pruebas del recorrido del reloj y salida por lianas, regresión del
elástico03 y cuatro casos de firma finalizaron sin fallos. Los tests usan
guardados aislados y no modifican las partidas del usuario.

La distribución reutiliza `build_distribution.py`, `release_updates.py`,
`publish_site.py` y `publish_updates.ps1`. Los artefactos se verifican mediante
SHA256 antes de activar los enlaces y manifiestos públicos. Las versiones
anteriores se conservan para recuperación. Las claves permanecen fuera de Git.

## Publicación realizada —22octubre2026

Commit de juego `57aa797`, subido a `origin/main`. Se compilaron la web,
Windows x64 y Android arm64. APK versionCode5, certificado SHA256 idéntico
al de1.0.4; apksigner verificó la firma. El ZIP de Windows pasó su CRC.

Distribución local: `builds/distribution/1.0.5`. Instaladores publicados:

- Windows: `/downloads/windows/1.0.5/RalphWolf-Windows.zip`,183139755bytes.
- Android: `/downloads/android/1.0.5/RalphWolf.apk`,175728033bytes.
- Web: `https://sheepraider.nooxtools.me/play/`.

Ambos paquetes de actualización están en `updates/releases/00000004-1.0.5/`,
con manifiestos activos secuencia4. Se verificaron firmas RSA públicas,
respuestasHTTP200 de instaladores, versión y metadatos mediante Postman.
Los hashes de todos los archivos se comprobaron en el servidor antes de
activar enlaces. Despliegue web retenido para rollback:
`/home/noox/web/sheepraider.nooxtools.me/deployments/1.0.5-6da9dbc293da`.

Los dos ZIP firmados cargaron realmente los scripts compilados, el nivel05,
las animaciones, el audio y el controlador de lianas:0fallos por plataforma
de paquete. La prueba del paquete Android se ejecuta en el motor Windows;
no sustituye una prueba en teléfono físico. La web pública arrancó en Chrome,
renderizó la rueda de idiomas y mostró el consentimiento de estadísticas,
sin errores de consola.

Evidencia local: `validation/release105_*.log` y
`output/playwright/release105-public.png`. Las partidas reales no se usaron
para las pruebas. No se modificó el servicio de estadísticas ni sus datos.
