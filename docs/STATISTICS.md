# Estadísticas opcionales

El juego pregunta al terminar de entrar en la rueda de idiomas. Aceptar envía
una sesión por apertura de la aplicación; rechazar deja jugar y actualizar
normalmente. La decisión se guarda en `user://privacy.cfg`, fuera de las partidas.
Se cambia desde Pausa > Opciones > Privacidad. En el editor y en ejecuciones
headless no se cuentan sesiones. Las pruebas de transporte sólo permiten una
excepción explícita contra localhost en compilaciones de desarrollo.

La web pregunta antes de contar una solicitud de descarga. Su decisión se guarda
en el navegador, separada de la decisión dentro del juego, y se puede cambiar
en el botón Privacidad del pie de página. Si se cierra el diálogo, no se cuenta
ni se inicia esa descarga: se puede volver a pulsar el enlace.

## Qué significan los números

- `session`: una apertura consentida, con plataforma `web`, `android` o `windows`.
  La versión identifica la versión base instalada; los parches de contenido no
  cambian el número del ejecutable o APK.
- `download`: solicitud consentida desde un botón de la web, con plataforma y
  versión del instalador; no confirma que termine la transferencia.
- No son personas únicas. Repetir una descarga o abrir de nuevo el juego puede
  aumentar el contador. Las personas que rechazan no figuran en estas cifras.
- No se cuentan descargas directas, botones con modificadores o archivos
  compartidos por otros medios. No hay seguimiento de duración ni ubicación.
- La API es pública y puede recibir eventos fabricados; estos datos sirven para
  orientar el proyecto, no para facturación o cifras auditadas.

El cuerpo del evento contiene únicamente tipo, plataforma, versión, aceptación
de la política y un token aleatorio nuevo por evento. El servidor sólo mantiene
contadores por día UTC, tipo, plataforma y versión. Los tokens para evitar contar
reintentos se borran transcurridos dos días; nunca identifican una instalación.
No se archivan cuerpos de eventos, IP, cuentas, partidas, cookies o IDs de
dispositivos en la base estadística. Se desactiva el access log de esta ruta.
Las demás rutas del servidor conservan sus registros técnicos habituales.
Al retirar el consentimiento cesan nuevos envíos; los contadores ya agregados
no se pueden atribuir a una persona para retirarlos individualmente.

## Consultar los resultados (propietario)

Desde la carpeta del proyecto:

```powershell
python tools/statistics_report.py
```

Utiliza la clave SSH de despliegue ya guardada fuera del repositorio y la clave
del servidor fijada en `~/.ralphwolf/vps_known_hosts`. No existe un informe público
ni un token administrativo dentro del juego. El usuario `ralphdeploy` pertenece
al grupo de lectura de estadísticas; no puede modificar la base.

## Servicio y publicación

`deploy/statistics_service.py` usa Python estándar, SQLite y escucha sólo en
`127.0.0.1:4939`. Systemd lo ejecuta con el usuario restringido `ralphstats`.
La base vive en `/var/lib/ralphwolf-stats/counts.sqlite`, fuera de la web.
Nginx publica únicamente `/api/stats/`. La especificación está en
`postman/statistics.openapi.yaml`.

La provisión inicial usa `python tools/provision_statistics.py`, que solicita la
contraseña de root interactivamente; no la escribe en archivos. Conserva una
copia de la configuración anterior en `/var/backups/ralphwolf/statistics`.
Los cambios futuros del servicio requieren reinstalarlo y reiniciarlo. Los
cambios del juego se distribuyen por paquetes firmados del actualizador; los
del navegador requieren una exportación web nueva.

## Verificación

```powershell
python -m unittest discover -s tools -p test_statistics_service.py
godot --headless --path . --script tools/test_statistics_consent.gd
postman simulation run postman/simulations/statistics.sim.yaml --port 4940 --output ndjson
# En otra terminal, usando el ejecutable consola de Godot:
godot --headless --path . --script tools/test_statistics_http.gd
```

La simulación modela el contrato localmente; su log debe mostrar un único POST
de Godot, después de aceptar. La prueba de SQLite ejecuta el servicio HTTP real
con una base temporal, sin inflar los contadores públicos. La prueba de
consentimiento usa un archivo temporal independiente de las preferencias reales.
