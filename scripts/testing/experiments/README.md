# Archivo de pruebas del arbusto

## Decisión vigente

El usuario eligió la opción **2: caras frontales** porque evita las
superposiciones en esquinas que vio en 1 y 3. Se usa en el arbusto de suelo y
en el disfraz de Ralph, con geometría, textura, huesos y animaciones originales.
El shader bush_backface_cutout descarta transparencia del atlas, escribe
profundidad y descarta caras traseras. Solo se cambia el follaje de páginas
11 y 9. Los materiales del cuerpo de Ralph siguen intactos.

## Copias originales .bak

- assets/items/bush_world/worn.tres.bak: malla/material original de suelo.
- assets/items/bush_disguise/worn.tres.bak: malla/material original del disfraz.
- scripts/items/original_bush.gd.bak: controlador anterior a aceptar opción 2.

Los .bak no se cargan en el juego y no se sobrescriben al repetir la herramienta
apply_bush_rendering.gd. Para restaurar el aspecto anterior, copiar ambos .bak
sobre sus respectivos worn.tres y elegir render_variant=0 en el controlador.
No es necesario restaurar texturas ni animaciones: no se modificaron.

## Experimentos conservados, desactivados

El laboratorio normal crea un único arbusto con la opción elegida. Su llamada
al banco comparativo está comentada. Para volver a probarlo, invocar
bush_render_experiments.gd.setup(lab), como hace la prueba automatizada.

| Prueba | Implementación conservada | Motivo del descarte |
| --- | --- | --- |
| Lóbulos/esferas | lobes_prototype.gd.txt y capturas antiguas | Cambió demasiado el diseño y el volumen originales; al usuario no le agradó. |
| Material nativo sobre lóbulos | Notas en lobes_prototype.gd.txt | Reutilizar la textura no corrigió la forma artificial. |
| Cubierta interior desde vértices nativos | assets/items/bush_custom*, tools/close_bush_copy.py, tools/build_bush_copy.gd | Conserva huesos pero simplifica entrantes, estira UV y se ve más angulosa que opción 2. |
| Billboard hacia cámara | assets/items/bush_camera*, shaders/bush_camera_facing.gdshader | Interpretación equivocada de la petición; gira hojas y produce cruces con Ralph. |
| 1: capa visible | shaders/bush_depth_cutout.gdshader | Oculta capas posteriores, pero dibuja ambas caras; el usuario vio superposición en esquinas. |
| 2: caras frontales | shaders/bush_backface_cutout.gdshader | **Aceptada**, incluida también en el banco comparativo. |
| 3: alfa + profundidad | shaders/bush_alpha_prepass.gdshader | Conserva mezcla y prepaso; al usuario le gustó menos la superposición en esquinas. |

Los archivos de assets custom y camera se conservan en sus rutas para poder
reabrirlos y mantener válidas sus referencias; no son instanciados normalmente.

## Coste

La opción 2 no añade vértices, texturas ni un prepaso de transparencia. El
arbusto de suelo original tiene 76 triángulos/2 superficies; el disfraz tiene
204 triángulos/4 superficies, de las que se cambian las 2 de follaje. El
descarte de caras reduce fragmentos dibujados, no el trabajo de animar huesos.
No se ha medido un coste GPU aislado en ms ni una diferencia de FPS.
