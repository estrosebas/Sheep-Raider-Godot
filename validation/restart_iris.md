# Cierre circular al morir

La versión PC decompilada usa Fade_StartRestart/Fade_Update y Fade_DrawOverlay con alpha de pantalla completa. El usuario observó una transición de iris en PlayStation y pidió reproducirla: este cambio es la adaptación a esa referencia, no una extracción de una máscara del reproductor PC.

OriginalRestartFade admite un modo iris mediante restart_iris.gdshader. En muertes de Ralph (vacío normal, agotamiento de carrera, explosión y golpe de Sam) y muerte de oveja se activa un círculo centrado en pantalla. Negro opaco avanza desde fuera del círculo hacia el centro. El radio se calcula en píxeles para conservar un círculo en pantallas panorámicas. La suavidad del borde ocupa un píxel, no un difuminado global. Cierre completo cubre incluso el píxel central; apertura completa revela las esquinas.

Se mantienen los tiempos previos: último segundo de muerte para cerrar, respawn con pantalla negra, un segundo para abrir. Al terminar la reapertura el modo iris se desactiva; puertas, selector de idioma y demás transiciones mantienen el fundido anterior. overlay.color.a sigue exponiendo progreso cuantizado para compatibilidad con llamadas existentes, mientras el shader de iris dibuja máscara opaca y no ese alpha uniforme.

test_restart_iris.gd verifica mediante lectura real de píxeles con GPU el centro visible, esquinas opacas, radio idéntico horizontal/vertical, negro total y reapertura completa, además de la selección de modo para vacío, explosión y Sam. Regresión: test_level00_closure.gd y test_sheep_lettuce_bridge.gd conservan tiempos, reset, cámara y reapertura.
