# Controles táctiles compartidos

`MobileControls` es un autoload que funciona en Android y web móvil.
Se activa en Android/iOS, al detectar pantalla táctil o al recibir el primer
toque. En PC se mantiene oculto. Para probarlo en el editor, en los argumentos
de ejecución del proyecto añadir `--touch-controls`; desde consola:

    Godot --path . -- --touch-controls

El parámetro muestra los controles; para operarlos con ratón en PC puede
activarse temporalmente **Emulate Touch From Mouse** en los ajustes de Godot.
Eso simula un dedo; las combinaciones de varios dedos requieren un dispositivo
táctil o la prueba automatizada.

- Joystick izquierdo: movimiento analógico. En menús navega en cuatro direcciones.
- Arrastrar por la zona derecha libre: girar cámara, con los límites del ratón.
- Saltar: salto/doble salto; en el agua, subir.
- Correr: carrera; en el agua, bajar.
- Sigilo: bot�n de la derecha; un toque activa el modo y otro lo desactiva.
- E: interactuar, recoger, hablar y continuar diálogos.
- Usar: acción del objeto equipado (R en PC).
- Objetos: mantener con un dedo, girar el inventario con otro en el joystick,
  soltar Objetos para seleccionar y cerrar, igual que Tab en PC.
- Pausa/Volver y Aceptar: menú original, ranuras, opciones y confirmaciones.
- Idioma: abre la rueda original (F5), joystick izquierda/derecha y Aceptar.

No se añade la acción descartada de tirar objetos con Q.
La interfaz se ajusta al tamaño del viewport y al área segura nativa; se solicita
orientación horizontal. Las teclas de botones se envían a los menús existentes
y a InputMap; el joystick usa fuerza analógica durante el juego. Los menús que
consumían todos los eventos dejan pasar los dedos hasta este traductor común.
La cámara táctil y el ratón comparten `RalphController.rotate_view`, incluidas
las restricciones de cinematográficas y muertes.

Al perder el foco, cambiar de escena o pasar a un menú se liberan las acciones
correspondientes. La capa se procesa también cuando el juego está en pausa.

Validación: `tools/test_mobile_controls.gd` envía eventos táctiles con varios
índices y comprueba movimiento analógico, salto simultáneo, cámara, bloqueo de
cinemática, inventario, pausa, pérdida de foco y retirada de las pruebas A–G.
Con ventana genera `validation/mobile_controls.png`.
Falta validar tacto, tamaño y rendimiento en un teléfono real. Esto prepara la
entrada; no instala plantillas Android ni genera APK ni reexporta la web.

## Arte integrado

Botones sin texto: salto jump.png, carrera runv1.png y sigilo sneakv1.png
del usuario; mano original, nube e icono equipado. Pausa/Volver e Idioma son
s�mbolos vectoriales. Conservan todas las acciones y �reas t�ctiles anteriores.

Interactuar usa la mano original del atlas FONT_GAME (0x9F). Usar se oculta
con las manos vac�as y aparece con el icono del GameItem sostenido por Ralph.

La carga admite tocar cualquier punto cuando est� lista, con el mensaje t�ctil
localizado en ambos estilos. Los toques antes de terminar no saltan la carga.
El sigilo se libera temporalmente en men�s y se restaura al jugar; cambiar de
escena o perder el foco limpia el interruptor para evitar entradas atascadas.
