# Web, instaladores y actualizaciones

Dominio: https://sheepraider.nooxtools.me/

Distribución 1.0.5: Windows x64, Android arm64 y web; niveles00–05.
El nivel05 incluye balsas con transporte de ovejas, plataformas móviles,
acceso al reloj mediante el elástico y salida por lianas con animaciones
y sonidos originales. La rueda de idiomas
aparece sólo cuando no existe un idioma guardado; después se entra directamente
al escenario. Ayuda inicial compartida, inventario táctil con interruptor y
flechas, y retorno directo al escenario al completar un nivel. Se conserva
la identidad de firma de las APK anteriores.

[GitHub Actions 39143675884](https://github.com/estrosebas/Sheep-Raider-Godot/actions/runs/39143675884)
completó un despliegue real de la portada a la VPS (mode=website, deploy=true),
incluidos los secrets SSH temporales, hashes remotos y activación de enlaces.
El runner terminó el trabajo y se cerró. Las exportaciones completas y la
publicación de los instaladores se ejecutaron y verificaron desde el PC.

| Ruta | Servicio |
|---|---|
| / | Portada del proyecto, controles y enlaces de descarga |
| /play/ | Exportación web de Godot |
| /downloads/latest.json | Versión, rutas, tamaños y SHA256 de los instaladores |
| /downloads/windows/VERSION/RalphWolf-Windows.zip | ZIP de Windows x64 |
| /downloads/android/VERSION/RalphWolf.apk | APK Android arm64 firmada |
| /updates/stable/PLATFORM/manifest.json | Manifiesto de contenido firmado |
| /updates/releases/SEQUENCE-VERSION/PLATFORM/content.zip | Paquete de contenido inmutable |

## Infraestructura

HestiaCP/Nginx en 64.181.219.10. Solo se modificó este dominio.
Los hooks deploy/nginx-site.conf se instalan como nginx.conf_ralphwolf y
nginx.ssl.conf_ralphwolf en /home/noox/conf/web/sheepraider.nooxtools.me/.
No se editan las plantillas generadas de Hestia ni la configuración de otros sitios.
Nginx valida la configuración antes de recargarla.

Document root: /home/noox/web/sheepraider.nooxtools.me/public_html.
Las versiones web viven fuera del document root, en deployments/, y se activan
mediante enlaces play y site-assets. Cada publicación verifica los SHA256
remotos antes de activar los enlaces; publica latest.json e index.html al final.
Los instaladores versionados existentes no se sobrescriben si sus bytes difieren.

La web anterior se respaldó antes de cambiar nada:
/var/backups/ralphwolf/20261018T153911Z/public_html.tar.
Las versiones web previas se conservan en deployments/ para poder restaurarlas.
El código está clonado fuera del document root en
/home/noox/web/sheepraider.nooxtools.me/source. No se sirve el repositorio Git.

El usuario ralphdeploy tiene acceso de escritura a este proyecto y no tiene sudo.
Se verificó que no puede escribir en el document root de otro dominio.
La contraseña root NO se almacena en el repositorio ni en GitHub Actions.

## Publicar contenido del juego

Usar el workflow **Build and publish game content** que ya estaba preparado.
Variables y secrets de SSH ya están configurados en el repositorio:

- UPDATES_SSH_HOST: usuario de despliegue y servidor.
- UPDATES_REMOTE_DIRECTORY: directorio updates del dominio.
- UPDATES_SSH_KEY y UPDATES_KNOWN_HOSTS: secrets cifrados, sin acceso root.

La base 1.0.5 contiene bundled_sequence=4, igual que su paquete de contenido
1.0.5 para instalaciones anteriores. Las instalaciones nuevas no descargan
el mismo contenido ni montan un parche guardado más antiguo que su base.
La siguiente publicación de contenido debe usar una secuencia mayor que 4
y una versión nueva; las publicaciones son inmutables.

## Publicar la portada o una nueva distribución

Workflow **Publish website, web game and installers**:

- mode=website: cambia únicamente la portada y sus assets; conserva jugable,
  instaladores y latest.json. No necesita reexportar Godot.
- mode=web: exporta portada y jugable web; conserva los instaladores.
- mode=all: exporta web, Windows y Android y crea una nueva distribución.
  La versión debe coincidir con project.godot; al cambiar la APK hay que
  incrementar también version/name y version/code de Android en export_presets.cfg.
- mode=native: exporta solo Windows y Android; conserva la portada y el jugable.
- deploy=false permite revisar el artefacto; deploy=true lo sube y activa.

El runner vive en el PC y debe estar encendido:

    & "$env:USERPROFILE\.ralphwolf\actions-runner\run.cmd" --once

Atiende un trabajo y se cierra. No se instaló un servicio automático.
Dependencias adicionales: python -m pip install -r tools/requirements-deploy.txt.

Comandos locales equivalentes:

    python tools/build_distribution.py --godot RUTA_GODOT --version 1.0.5 --output builds/NUEVA_CARPETA
    python tools/publish_site.py --bundle builds/NUEVA_CARPETA --host ralphdeploy@64.181.219.10 --identity RUTA_CLAVE_SSH --known-hosts RUTA_KNOWN_HOSTS

Añadir --site-only al primer comando para actualizar solo la portada.
Usar --native-only para actualizar solo instaladores y latest.json.

## Android y claves que hay que conservar

La APK usa el identificador me.nooxtools.sheepraider y una firma de publicación
propia. Se instala junto a APKs de prueba anteriores; las partidas de esas
otras aplicaciones NO se importan automáticamente. No hace falta desinstalarlas.
La exportación se verificó con apksigner (firmas v2/v3); falta prueba en teléfono real.

Fuera del repositorio, en C:\Users\estro\.ralphwolf:

- updates-private.pem: firma de los paquetes de contenido.
- android-release.keystore y android-signing.json: firma permanente de las APK.
- vps-deploy-ed25519: clave SSH del usuario de despliegue.
- vps_known_hosts: identidad comprobada del servidor.

Respaldar las claves y la configuración de Android en almacenamiento privado.
No regenerar la firma de Android para una versión siguiente: impediría instalar
la APK nueva como actualización de la anterior. El build lee la configuración
local mediante ANDROID_SIGNING_CONFIG_PATH; las claves no van al servidor web.

## Caché y web

La portada y latest.json se revalidan; los manifiestos usan no-store.
ZIP/APK y paquetes versionados son inmutables y admiten caché larga.
/play/ devuelve los headers de aislamiento necesarios, MIME application/wasm,
application/octet-stream para PCK y versiones gzip precomprimidas. Los archivos
del juego se revalidan para evitar mezclar una exportación nueva con la anterior.
Los assets de la portada incluyen un identificador de contenido en su URL para
que los cambios de estilos e imágenes no queden ocultos por la caché del navegador.

La primera consulta de Godot mostró timeouts intermitentes con un límite de
6 segundos bajo carga. La base 1.0.2 amplía el plazo a 20 segundos; el botón
Jugar permite continuar durante la consulta. La comprobación HTTPS real pasó
con manifiesto firmado y estado current; la matriz local completó 16 casos.
