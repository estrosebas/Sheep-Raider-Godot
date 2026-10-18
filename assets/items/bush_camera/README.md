# Tercera variante: follaje orientado a cámara

Copia independiente e intacta de los datos/malla/texturas de bush_world; el
disfraz correspondiente está en bush_camera_disguise. En ItemLab aparece
como ORIENTADO A CAMARA, en (13,0,16), junto a las otras dos versiones.

El shader bush_camera_facing.gdshader se aplica en ejecución exclusivamente
a las superficies de follaje page_11/page_9. Primero evalúa el skin original,
después orienta visualmente las hojas hacia la cámara alrededor del eje Y.
El cuerpo de Ralph, huesos, colisiones y dirección de movimiento no giran.
El asset original y la segunda variante no cambian.

Es una prueba de billboard cilíndrico: evita mostrar el follaje de canto al
orbitar horizontalmente. No resuelve la vista cenital ni convierte el asset
en un volumen real; ciertas partes de Ralph pueden cruzar las hojas al
mirarlo desde atrás. Hay capturas GPU bush_camera_0/1/2.png en validation.
test_level02_interactions.gd comprueba interacción y materiales aislados.
