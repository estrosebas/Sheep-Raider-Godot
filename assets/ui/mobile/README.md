# Arte de los controles táctiles

Se conservan los círculos, fondo translúcido y tamaños táctiles anteriores.
Los PNG de esta carpeta son recortes DAV originales, sin repintar ni convertir
en iconos inventados. `source.json` registra archivo, ID, bitmap y rectángulo.
`tools/extract_mobile_ui.py` permite reproducir la extracción.

## Aplicado

| Botón | Recurso | Adaptación al control táctil |
|---|---|---|
| Interactuar / Aceptar | IGLUSEDA, ID37 | Mano original del menú; mismo sprite reutilizado aquí |
| Objetos | inventory/cloud_0.png, ID25 | Nube del inventario original |
| Usar | Icono original del objeto seleccionado | Cambia con la selección; mano si no hay objeto |

Se mantienen los textos pequeños bajo los iconos para explicar cada acción.
La mano procede de los botones de mapa/menú (`src/engine/map.cpp`), no de un
botón táctil original: el juego original no tenía esta interfaz móvil.

## Extraído como candidato, sin asignar

- IGLUSEDB, ID38: dibujo alternativo resaltado de Usar; visualmente diferente
  de la mano, por eso no se cambia automáticamente al pulsar.
- IGLFLEC_, ID28: flecha original de navegación de listas; no es un icono de salto.
- IGLEXITB, ID27: puerta/salida del menú; no se usa como Pausa para evitar ambigüedad.
- Hay iconos originales de los objetos del inventario: lechuga, imán, perfume,
  ventilador, flauta, cohete, dinamita, disfraces y demás clases importadas.

## Ilustraciones dedicadas pendientes

En los bancos UI inspeccionados y los IDs declarados no se localizaron dibujos
dedicados de **salto, carrera o sigilo**. Por ahora sus botones conservan texto.
Para completar la interfaz conviene dibujar:

1. Salto: Ralph saltando o pies con impulso.
2. Carrera: piernas girando o silueta corriendo.
3. Sigilo: Ralph de puntillas.
4. Pausa: dos barras con el trazo del juego (ahora símbolo tipográfico).
5. Idioma: rueda/idiomas simplificados (ahora texto).

Son propuestas de arte nuevo, no assets originales encontrados. Entrega sugerida:
PNG RGBA transparente, lienzo cuadrado de128×128 o256×256, margen libre del10–15%,
silueta legible a40–50px y paleta/trazo del juego. El círculo y el fondo los
dibuja la interfaz: no incluirlos en el PNG. Se conserva proporción al escalar.
Las flechas y los iconos originales son una referencia visual disponible.

## Correcci�n de interacci�n y visibilidad de Usar

Interactuar usa ahora `interact_hand.png`: pictograma de mano abierta azul del atlas nativo
FONT_GAME, glifo0x9F, recurso IGLTYPO_36. El recorte y la procedencia est�n en
interact_hand.json. El antiguo hand.png proced�a de IGLUSEDA y se hab�a
identificado incorrectamente como mano; se conserva solo como referencia del
men�, ya no se utiliza para Interactuar ni como respaldo de Usar.

Usar se dibuja y acepta toques �nicamente cuando el nodo equipado es un GameItem
v�lido y su holder es Ralph. Entonces muestra el icono del objeto. La selecci�n
de una casilla de inventario por s� sola no basta. No se muestran etiquetas.

Correcci�n: el glifo0xC6 anterior era una c�mara. Se sustituy� por la palma
abierta0x9F, inspeccionada en captura. Sigilo a la derecha y con interruptor.
