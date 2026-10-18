# Hojarasca: pruebas pendientes de elección

**Archivado:** todas las variantes A–G se retiraron del laboratorio a petición
del usuario: seguían percibiéndose planas. El laboratorio conserva únicamente
BullLeafHeap, la referencia original, con un TODO en item_lab.gd para revisar
la superposición de caras y la geometría más adelante. Las herramientas de
captura antiguas dependían de estas estaciones y se conservan como referencia;
no ejecutarlas sin volver a montar expresamente los experimentos.

La textura nativa DAV3/rect166 es opaca. Su malla es una superficie de terreno
de67 triángulos y unos19×21m, con altura0–1.16m; no es el arbusto animado de Ralph.
El parche `bush_backface_cutout` fue rechazado aquí: quitar caras inferiores
no cierra sus bordes ni añade volumen. Las primeras capturas desde arriba no
permitían evaluar ese problema. Se conserva el código previo para referencia.

En F8, cruzar la muestra central hasta la extensión del suelo al fondo:

- A, izquierda(-25,0,-56): original de dos caras. Misma geometría, textura y UV.
- B, centro(0,0,-56): mantiene la superficie y cierra sus bordes abiertos hasta
  el suelo. Los laterales nuevos usan la textura original y un tono más oscuro.
- C, derecha(25,0,-56): extiende la base45cm para inclinar los bordes hacia el
  suelo, con vértices compartidos en las esquinas. Descarta el fondo verde de la
  textura mediante shader; conserva el PNG original. Evalúa un borde más suave,
  aunque puede dejar agujeros demasiado grandes: todavía no es una solución aceptada.

Todas tienen colisión en la superficie original: en el laboratorio faltaba ese
suelo y Ralph podía quedar por debajo de la hojarasca. Son pruebas visuales:
la extensión no añade toro ni zonas de ruido; la muestra central conserva
su zona, sonido y partículas. No cambian `scenery.tres`, las colisiones ni
los mecanismos del nivel04, ni el arbusto de Ralph. No rotan hacia la cámara.

Capturas de comparación: `tools/capture_leaf_heap_experiments.gd`.

## Segunda serie: fragmento real del mapa (D–G)

Detrás de A–C hay cuatro copias de la zona original, en dos filas. Incluyen
ambos montículos (130 triángulos) y los triángulos del terreno circundante que
intersectan sus límites ampliados 3 metros. Se conservan completos los
triángulos del borde del recorte: no se recortan UV ni se inventan superficies.
La única transformación es una traslación; cada copia tiene colisión.

- D, primera fila izquierda: material actual del nivel.
- E, primera fila derecha: hojas opacas con profundidad y ambas caras.
- F, segunda fila izquierda: opacas, descartando caras posteriores.
- G, segunda fila derecha: opacas, descartando caras frontales. Es un control
  de orientación; que desaparezcan hojas desde arriba sería esperable.

Solo cambia el material de las hojas entre copias. Las rocas, suelo y demás
materiales conservan los del mapa. Los límites del fragmento están abiertos
por la extracción; no representan agujeros nuevos en el nivel.
No se ha elegido ni aplicado una nueva variante al nivel 04.

Código: `leaf_map_fragment.gd`. Verificación y capturas desde dos lados:
`tools/test_leaf_map_fragment.gd` (con ventana produce imágenes en validation).
Comprueba que ambos montículos conservan posiciones originales y que las
cuatro variantes tienen geometría y UV idénticas. La inspección inicial no
confirma un problema de orden de transparencia; las uniones de la superficie
siguen visibles en la prueba opaca. Falta comparar jugando desde varios lados.
