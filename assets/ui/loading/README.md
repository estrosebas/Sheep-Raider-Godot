# Pantallas de carga opcionales

Escape -> Opciones: Pantallas de carga Sí/No y Estilo Clásico/Moderno.
Por defecto: habilitadas, clásico. Se guardan en [loading] del mismo
user://language.cfg que [language]. Cambiar idioma conserva estas opciones.

Sólo las puertas LabLevelDoor llaman al autoload LevelLoading después de
su animación de entrada. F6/F5, reiniciar y cargar checkpoints no lo llaman.
El recurso se carga con load_threaded_request mientras el escenario anterior
permanece pausado. Después se cambia a la escena real detrás del overlay,
se termina _ready, la configuración diferida y un frame de renderizado antes
de ofrecer continuar. La barra es simulada y dura al menos 2 segundos; no llega
a 100% hasta completar esa preparación. E/Enter/Espacio
continúan. No se permite confirmar anticipadamente. Un fallo permite volver
con Escape. No se genera ningún checkpoint ni guardado de partida al cargar.
Al confirmar sólo se revela la instancia ya preparada: no se vuelve a cargar
ni a inicializar la escena. timing registra recurso/preparación/confirmación
en milisegundos para detectar regresiones. Antes sólo se esperaba el recurso,
y la inicialización completa se hacía después del botón (aprox. 3 s en prueba).

EntryController ordena la entrada independientemente de la carga:
en nivel 01 primero CIN00 (cámara), después CIN04 (Lucas), después iris hacia
afuera y juego. La primera cámara se selecciona antes de quitar la pantalla
de carga, sin mostrar antes un frame de Ralph. El iris comienza al recibir
finished de CIN04, también si se salta la cinemática. Otros niveles (o una intro
ya completada) abren el iris directamente. Se aplica igual sin pantallas de carga.
Usa OriginalRestartFade DURATION=1 s, equivalente a Fade_StartOut(0x1000).
OriginalSequence no puede iniciar durante un iris activo, para evitar detener
la física que lo anima. test_level01_entry_order.gd verifica ambos modos,
la cadena y el orden cámara/Lucas/círculo/controles.
La cadena, tipo y transición de cada secuencia están en
assets/cinematics/camera_catalog.json. CAMERA_CATALOG.md documenta los tipos,
las nueve secuencias actuales y las cámaras procedurales; EntryController
consulta entries sin comprobar clases de nivel ni fijar CIN00/CIN04 en código.

Clásico: ilustraciones originales PS1, con mensajes ya combinados en PNG
por idioma y dos variantes (cargando/listo). Se conserva el arte de cada nivel;
la segunda imagen de los EBS es una página de mensajes sin ese dibujo, así que
no sirve directamente como pantalla final. Usa la fuente bitmap compartida.
Moderno: remaster sin texto + textos localizados dibujados por Godot. Ambos
usan el idioma seleccionado (es/en/it/pt_BR). La barra se dibuja por separado.
bar_frame.png conserva los píxeles del marco de tiza del LEV00.EBS original.
El relleno se dibuja como color blanco sólido/opaco por encima del marco.
bar_fill.png conserva el ensayo previo con muestras del borde; se descartó
porque su alfa dejaba ver los objetos del escritorio. No se carga en runtime.
No se afirma que exista como textura separada en el juego. bar_source.json
guarda el recorte y posición exacta. Reconstrucción: extract_loading_bar.py.

La página de mensajes del EBS original usa letras amarillas con borde azul,
sin panel rectangular negro. Los modernos dibujan ese borde por glifo; los
clásicos lo combinan directamente en cada PNG localizado. Se quitaron los
rectángulos negros añadidos inicialmente por el port en ambos estilos.

La imagen completa se ajusta a la ventana conservando proporciones, con
franjas negras si hacen falta. No hay recorte de personajes ni estiramiento.
Para LEV16/17, mientras no haya remaster, moderno usa la ilustración original
con el texto dinámico. Las rutas se basan en el nombre de archivo del nivel,
no en la numeración visible, que difiere tras los niveles bonus.

Los archivos del usuario en remaster/pantallas_carga/remasters son JPEG con
extensión .png. Se mantienen intactos y .gdignore evita importarlos erróneamente.
tools/prepare_loading_remasters.py crea copias idénticas con extensión .jpg
en modern/. Tras actualizar esos archivos, ejecutar el script e importar Godot.
tools/prepare_loading_classics.py recompone las variantes clásicas si cambia
la fuente o las traducciones. Las imágenes originales permanecen intactas.

Validación: tools/test_loading_screens.gd, -- --capture para capturas gráficas.
Prueba opciones persistidas/reinicialización, cambio de idioma, puerta real,
ambos estilos, carga lista/confirmación, estilo desactivado y fallback.

En m�vil se contin�a tocando cualquier punto al terminar. El mensaje t�ctil
se traduce en cuatro idiomas; en cl�sico se cubre la instrucci�n de teclado
combinada en la imagen. PC conserva E/Enter/Espacio.
