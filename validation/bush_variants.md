# Comparación de arbustos

Decisión final: opción 2 (caras frontales) aceptada y aplicada a bush_world
y bush_disguise, con respaldos worn.tres.bak. Banco de pruebas desactivado;
ver scripts/testing/experiments/README.md para motivos y restauración.

Estado actual: se descartó la variante de lóbulos y sus shaders por petición
del usuario. El segundo arbusto ahora usa copias independientes del asset
original en bush_custom y bush_custom_disguise, con sus texturas y referencias
propias. Se identifica como COPIA PARA EDITAR en el laboratorio. Tiene el
aspecto original como base para el próximo rediseño; no tiene aún volumen
adicional en ese punto. Después se añadió una cubierta interior de caras
derivadas de los vértices nativos, conservando superficies y huesos originales.
Ver assets/items/bush_custom/README.md para reproducción y limitaciones.
Los párrafos siguientes documentan los intentos anteriores.

ItemLab conserva Bush original en (5,0,16) y añade BushVolume en (9,0,16), con rótulos en el suelo. E permite probar entrada, ocultación, movimiento y salida en ambos. El nivel 02 sigue usando el original hasta elegir una variante.

La variante opcional volumetric construye follaje cerrado con ocho lóbulos y reutiliza un área verde de la textura original page_11. Sustituye las superficies de hojas del disfraz, conserva las partes de Ralph y sigue la transformación animada del hueso 1. No cambia las reglas de detección, comida, alcance ni colisiones.

JUMP6 y OUT6 ya contenían cues 30/33, pero no estaban en la tabla de sonidos de Ralph. Se registran los WAV originales extraídos de Lvl-02 al iniciar la interacción; OriginalItemActions los reproduce en sus tiempos originales.

test_level02_interactions.gd comprueba ambas variantes y la resolución de los sonidos. Comparación GPU: bush_variants.png.

Refinamiento: follaje con shader de tres bandas y contorno por caras invertidas. HEAD1 bloquea el desplazamiento hasta completar la incorporación (estado estacionario original); el cambio a WALK1/2 se muestrea inmediatamente. El OUT6 del arbusto restaurado se sincroniza con el de Ralph y vuelve a STAND1 al terminar, en vez de quedarse en bucle. Los WAV 14, 30 y 33 se verificaron por SHA-256 contra sus entradas originales de Lvl-02.SND: idénticos. OUT6 de Ralph indica 30 en 0, 0,20 y 0,42 s, y 33 en 0,82 s; se conservan esos eventos, sin sustituirlos por un sonido supuesto.
