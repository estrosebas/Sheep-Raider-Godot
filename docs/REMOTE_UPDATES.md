# Propuesta: actualizaciones remotas PC / Android

Estado: implementación local disponible. Cliente y generador de paquetes firmados
para Windows y Android mediante APK directa; dominio configurado:
https://sheepraider.nooxtools.me/updates/. El despliegue sigue pendiente y se dejó
local a petición del usuario. Guía vigente: [UPDATES_DEPLOYMENT.md](UPDATES_DEPLOYMENT.md).
El resto de este documento conserva el diseño inicial como referencia.

## Dos versiones independientes

- Bootstrap/binario: motor Godot, arquitectura, permisos, plugins nativos,
  clave de firma Android y código del propio actualizador.
- Contenido: mapas, texturas, audio, escenas y scripts que permita cargar la
  arquitectura de arranque. No prometer actualización universal de scripts:
  hay preload(), autoloads y clases globales que requieren una prueba real de
  arranque y resolución de dependencias antes de permitirlo en una publicación.

Los PCK no sustituyen las bibliotecas del motor ni los permisos del APK.
Una APK nueva necesita conservar package ID y clave de firma; normalmente el
usuario deberá aceptar su instalación. En Google Play el binario usa el canal
de actualización de Play; evaluar por separado sus políticas antes de incluir
descarga de scripts. No se garantiza aceptación de un mecanismo por la tienda.

## Primera versión propuesta

1. Instalar una versión base nueva, una vez, con la pantalla de actualización.
2. Consultar un manifiesto HTTPS específico de plataforma y canal.
3. Comparar versión de contenido y compatibilidad con bootstrap/motor.
4. Mostrar tamaño y descargar el paquete a un archivo temporal en user://.
5. Validar firma del manifiesto y tamaño/SHA256 del paquete antes de montarlo.
6. Activar mediante puntero local; mantener la versión anterior para recuperar
   una descarga corrupta o incompleta. Nunca escribir sobre el archivo activo.
7. Montar en el próximo arranque, antes de cargar escenas/autoloads del juego.
8. Si no hay conexión, arrancar con la última versión válida disponible.

Los guardados y language.cfg quedan fuera de los paquetes de contenido.
El esquema de guardado necesita su propia versión y migraciones cuando cambie.
La primera prueba puede usar paquetes completos por plataforma. Después se
pueden separar paquetes por nivel/recursos compartidos; una descarga incremental
no debe prometerse hasta medir dependencias y tamaño real de las exportaciones.

## Servidor y contrato mínimo

Puede servirse con Nginx estático en HestiaCP; para este flujo no es obligatorio
crear una API dinámica ni una base de datos.

- GET /updates/stable/windows-x86_64/manifest.json
- GET /updates/stable/android-arm64/manifest.json
- GET /updates/releases/<version>/<platform>/content.pck

Manifiesto firmado propuesto: un sobre con payload_base64 y signature_base64.
El payload decodificado es JSON UTF-8; la firma verifica exactamente esos bytes
con una clave pública incluida en el bootstrap. La clave privada de publicación
queda fuera de Git, del cliente y del directorio web. Elegir un algoritmo
compatible con Crypto del Godot usado y verificarlo en PC y Android.
SHA256 por sí solo detecta corrupción; no autentica un manifiesto alterado.

Campos del payload a concretar en el contrato:

- schema_version, product_id, channel, platform, content_version.
- engine_version y bootstrap_abi compatibles.
- released_at, notas y paquete: ruta HTTPS permitida, bytes, sha256.

HTTP: manifiesto con no-cache/revalidación; versiones publicadas inmutables con
cache larga. Un 404, timeout o JSON/firma inválidos no activan nada. No permitir
rutas locales recibidas del servidor ni redirecciones hacia otros orígenes sin
una política explícita. El cliente no necesita secretos para descargar recursos
públicos; las credenciales de despliegue son exclusivas del publicador.

## Publicación desde el PC

Cambiar código/arte -> probar -> exportar PCK por plataforma -> calcular tamaño
y hash -> firmar manifiesto -> subir archivos de versión -> cambiar el
manifiesto estable al final. Publicación atómica para que nadie descargue una
versión a medio subir. Git conserva el código y dispara un proceso de CI o un
despliegue; no es necesario guardar APK/PCK pesados dentro del repositorio.

Web conserva su despliegue separado (HTML/JS/WASM/PCK y política de caché).
Evitar usar el mismo PCK comprimido para Windows y Android sin verificar los
formatos de textura y arquitectura; conservar la misma versión lógica.

## Verificaciones antes de activarlo

- Paquete real nuevo visible tras arrancar, con texturas y audio en cada destino.
- Recursos precargados, clases globales, autoloads e importados se resuelven.
- Descarga interrumpida, hash/firma erróneos y manifiesto incompatible conservan
  la versión anterior y los guardados.
- Arranque sin conexión; espacio insuficiente; no descargar de nuevo lo vigente.
- Cambio de motor o bootstrap deriva a actualización binaria, no a un PCK roto.

Fuentes oficiales:
https://docs.godotengine.org/en/stable/tutorials/export/exporting_pcks.html
https://support.google.com/googleplay/android-developer/answer/16559646
