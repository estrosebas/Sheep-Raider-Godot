# Comparación de capas sin rotación

Decisión posterior: el usuario eligió la opción 2. Ya es el acabado por defecto
del arbusto original. Las instancias comparativas se archivaron y dejaron de
crearse en el laboratorio normal. Ver scripts/testing/experiments/README.md.

Se retiró el billboard del laboratorio. Hay tres instancias nuevas del asset
original en la fila z=24 (x=4,9,14), con rótulos 1, 2 y 3. Conservan geometría,
UV, paleta de huesos y dirección; solo cambian los materiales duplicados por
instancia de las páginas de follaje 11 y 9. El cuerpo de Ralph conserva sus
materiales. El nivel 02 sigue usando el original.

1. CAPA VISIBLE: descarta píxeles transparentes y escribe profundidad como
   superficie opaca. Los píxeles delanteros ocultan las capas posteriores.
2. CARAS FRONTALES: añade descarte de caras traseras a la opción anterior;
   puede revelar huecos por la orientación de los polígonos originales.
3. ALFA + PROFUNDIDAD: conserva mezcla de transparencia con prepaso de
   profundidad; el resultado depende de la opacidad del atlas.

La prueba GPU de test_level02_interactions.gd terminó sin fallos.
Se verificó entrada/salida y ocultación en las tres instancias, materiales del
cuerpo sin cambiar y capturas desde tres ángulos de la opción 1. La comparación
está en bush_layer_comparison.png. Estas variantes corrigen orden/ocultación;
no añaden geometría a las siluetas vistas de canto.
