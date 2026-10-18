# Publicar actualizaciones con GitHub Actions y HestiaCP

## Qué está implementado

**Repositorio conectado:** https://github.com/estrosebas/Sheep-Raider-Godot.
El workflow ya está publicado en main y se registró el runner Windows
ralphwolf-estro-pc, instalado fuera del proyecto en
C:\Users\estro\.ralphwolf\actions-runner. Se configuraron las variables de Godot
y de ubicación de la clave de firma. El acceso al VPS sigue pendiente.

La publicación inicial es una instantánea limpia del proyecto. El historial
anterior, que contiene un ZIP de build de 165 MiB, se conserva en la rama local
master. Trabajar en codex/github-publication, que sigue origin/main; para subir:

    git push origin HEAD:main

El arranque consulta https://sheepraider.nooxtools.me/updates/ en PC y Android.
Web mantiene su despliegue normal; en editor/F6 se evita la consulta salvo
--enable-updates. Las descargas se ofrecen mostrando versión y tamaño.
Se valida firma RSA/SHA256, plataforma, motor4.7.2, ABI1, tamaño, hash y contenido
del archivo ZIP antes de activarlo. El ZIP es un resource pack nativo de Godot.

La versión instalada se monta ANTES de compilar los servicios reales del juego.
Se conservan autoloads por nombre mediante puentes mínimos, sin precargas.
Una descarga nueva requiere reiniciar: en PC se ofrece reinicio, en Android
cerrar y volver a abrir. Se conserva el paquete anterior y se recupera si el
primer arranque no confirma su llegada a la rueda de idiomas. Esto no sustituye
probar cada nivel: no detecta automáticamente todos los errores de una partida.
Sin red/manifest válido se puede pulsar Jugar con el contenido instalado.
No se toca language.cfg ni los guardados.

**Primera instalación:** reexportar EXE/APK una vez para incorporar el actualizador
y su clave pública. Las APK existentes no pueden adquirirlo por sí mismas.
En futuras actualizaciones de motor/permisos/plugins/actualizador se vuelve a
exportar un binario. Los cambios compatibles del juego se entregan por paquetes.
Android tiene permiso INTERNET activado y exporta los JSON de datos.

Esta primera versión descarga un paquete completo por plataforma; NO hace delta
binario ni descarga solo los archivos cambiados. Los paquetes se mantienen en
user://updates. Tras confirmar un arranque se conserva el activo y el anterior,
y se eliminan las versiones más antiguas del caché del actualizador.
Para recuperar/limpiar manualmente hay que cerrar el juego primero.

## Claves

Ya se generó la clave de publicación local:

    C:\Users\estro\.ralphwolf\updates-private.pem

La pública está en config/updates_public.pem y se incluye en los binarios.
Conservar y respaldar la privada: NO subirla al repositorio ni al directorio web.
La necesita únicamente el equipo publicador. No crear otra para cada versión.
El generador se niega a sobrescribir una pública diferente.
La clave SSH de acceso al VPS es otra clave distinta.

## Workflow preparado

.github/workflows/content-updates.yml

Se eligió un runner Windows en TU PC para usar exactamente el Godot y plantillas
ya instalados. No requiere compilar dentro de la VPS.

1. El repositorio ya está subido y origin está configurado.
2. En GitHub, Settings -> Actions -> Runners -> New self-hosted runner, Windows.
   Instalarlo FUERA de este repositorio y añadir la etiqueta ralphwolf.
   Ejecutarlo bajo tu usuario, con acceso a Godot y a la clave de publicación.
   Usar un runner actualizado, compatible con los actions de Node24.
3. Instalar Python y la dependencia:

       python -m pip install -r tools/requirements-updates.txt

4. Crear estas Repository Variables:

| Variable | Valor |
|---|---|
| GODOT_CONSOLE_PATH | Ruta absoluta a Godot_v4.7.2-stable_win64_console.exe |
| UPDATE_SIGNING_KEY_PATH | Ruta anterior de updates-private.pem; opcional si corre bajo tu usuario |
| UPDATES_SSH_HOST | usuario_hestia@host_del_vps |
| UPDATES_REMOTE_DIRECTORY | Ruta pública absoluta terminada en /updates |

Ejemplo de ruta Hestia (sustituir USUARIO real):

    /home/USUARIO/web/sheepraider.nooxtools.me/public_html/updates

5. Crear estos Actions Secrets:

| Secret | Contenido |
|---|---|
| UPDATES_SSH_KEY | Clave privada SSH de despliegue con acceso a esa carpeta |
| UPDATES_KNOWN_HOSTS | Línea known_hosts del VPS, con huella comprobada por ti |

El workflow usa SSH estricto. No acepta cualquier huella ni imprime claves.
No hay triggers de pull requests: el runner publicador solo procesa ejecuciones
manuales o etiquetas de publicación del propio repositorio.

## Primera publicación

En Actions -> Build and publish game content -> Run workflow:

- version:1.0.1
- sequence:1 (entero creciente)
- platform:both
- deploy:false para revisar el primer artefacto sin subirlo.

Descargar el artefacto updates-1-1.0.1 y revisar sus dos manifiestos y paquetes.
Luego ejecutar una publicación con deploy:true. El servidor recibe primero los
paquetes completos y solo al final cambia cada manifest.json. Las versiones
publicadas no se sobrescriben si su hash difiere.

También puede dispararse un build+deploy con una etiqueta explícita:

    git tag content-2-v1.0.2
    git push origin content-2-v1.0.2

El push normal de código no publica una actualización accidentalmente.
Cada etiqueta usa secuencia nueva y versión; conservar las anteriores.
El host publicador descarga el commit de GitHub, exporta ambos ZIP, firma
manifiestos y publica. La clave de firma queda en el PC, no en GitHub/VPS.

## Servidor

No necesita Node, PHP ni base de datos. Nginx/Hestia sirve:

    updates/stable/windows-x86_64/manifest.json
    updates/stable/android-arm64/manifest.json
    updates/releases/00000001-1.0.1/windows-x86_64/content.zip
    updates/releases/00000001-1.0.1/android-arm64/content.zip

Evitar reescrituras a index.html bajo /updates/. El manifiesto debe devolver
application/json y permitir revalidación/no-cache. ZIP con application/zip y
cache larga/inmutable. HTTPS válido; no redirecciones para estos endpoints.
No hace falta tocar la web Godot que vive en la raíz del dominio.
No poner claves privadas ni archivos del repositorio en public_html.

La consulta real del endpoint Windows respondió404 durante la implementación:
todavía no hay publicación en ese dominio. GitHub y el runner ya están
configurados; faltan las variables de destino VPS y sus dos secrets SSH.

## Encender el runner para una publicación

No se instaló un servicio automático. Para atender un único trabajo y salir:

    & "$env:USERPROFILE\.ralphwolf\actions-runner\run.cmd" --once

Ejecutarlo en PowerShell y después iniciar el workflow desde GitHub (o viceversa,
el trabajo esperará en cola). El PC debe permanecer encendido y conectado hasta
que finalice. La etiqueta ralphwolf ya está asignada al runner.

## Publicación local opcional

    python tools/release_updates.py build --godot RUTA_GODOT_CONSOLA --platform windows-x86_64 --version 1.0.1 --sequence 1 --private-key RUTA_PRIVADA
    python tools/release_updates.py build --godot RUTA_GODOT_CONSOLA --platform android-arm64 --version 1.0.1 --sequence 1 --private-key RUTA_PRIVADA

Salida por defecto: builds/updates. Para otra ejecución usar --output distinto:
el generador no sobrescribe paquetes locales de la misma versión.

    powershell -File tools/publish_updates.ps1 -HostName usuario@vps -RemoteUpdatesDirectory /home/USUARIO/web/sheepraider.nooxtools.me/public_html/updates

## Pruebas

Contrato: postman/updates.openapi.yaml. Mock propio derivado de ese contrato,
sin servicio propietario previo, guardado en postman/mocks/updates.

    python tools/test_update_distribution.py --godot RUTA_GODOT_CONSOLA

Requiere Postman CLI1.74+ disponible en PATH. Lanza la simulación local, ejecuta
Godot de verdad contra HTTP, comprueba los logs de solicitudes y usa cachés y
claves de TEST aisladas. Nunca publica ni usa la clave privada real.
Incluye descarga, montaje frío de autoload/controlador, confirmación, rollback,
no repetir descarga, firma/hash incorrectos, ABI incompatible, plataforma/rutas
inválidas, HTTP503 HTML,404, timeout y servidor inaccesible.
El cold-start se comprueba en Windows; Android requiere prueba en teléfono real.

Verificación local realizada: 15/15 casos HTTP con Postman y Godot; paquete real
exportado con scripts compilados y recursos importados, montaje y limpieza de
caché: 0 fallos. Controles móviles y botón táctil Jugar del actualizador: 0 fallos.
Los paquetes de contenido 1.0.1, secuencia 1, están en builds/updates para Windows
y Android arm64 (~151 MiB cada uno). No son EXE/APK: son los ZIP de actualización.
builds/updates-initial-validation conserva la primera exportación de prueba y no
se debe publicar. No se han reexportado los binarios base ni probado una descarga
en un teléfono real. La subida SSH al VPS sigue pendiente de activar.
