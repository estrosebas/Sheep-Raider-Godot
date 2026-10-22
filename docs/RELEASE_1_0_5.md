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

Estado de publicación: pendiente de compilación y verificación pública.
