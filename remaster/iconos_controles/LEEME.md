# Iconos para los controles móviles

VISTA_PREVIA.png muestra todos los PNG incluidos. Los archivos originales son
copias sin cambios de tamaño, color o transparencia. catalogo.json incluye
origen, descripción y huella SHA256. Los source.json conservan IDs y rectángulos DAV.

## Ya disponibles

- originales/controles: mano, Usar resaltado, flecha y puerta/salir.
- originales/nubes: tres fotogramas de la nube del inventario.
- originales/inventario: todos los iconos extraídos del inventario, incluso
  objetos cuya mecánica todavía no se ha implementado. El nombre icon_N mantiene
  el ID de clase original; catalogo.json identifica los nombres conocidos.
- originales/hud: oveja, lechuga y Sam de la flauta, como referencias adicionales.

La mano, la nube y los iconos de objeto equipado ya se usan en los controles.
Las flechas, puerta y otros dibujos se incluyen como referencia; no todos están
asignados a un botón. Este paquete reúne los iconos 2D extraídos que sirven como
referencia, no todas las texturas ni mallas del juego.

## Necesitamos estos cinco dibujos

| Archivo a entregar | Acción | Idea visual |
|---|---|---|
| nuevos/jump.png | Saltar | Ralph saltando o pies con impulso |
| nuevos/run.png | Correr | Piernas girando o Ralph corriendo |
| nuevos/sneak.png | Sigilo | Ralph caminando de puntillas |
| nuevos/pause.png | Pausa | Dos barras con trazo del juego |
| nuevos/language.png | Idioma | Rueda de idiomas simplificada |

Los tres primeros son prioritarios. No hace falta rehacer mano, inventario ni
los objetos. Si quieres remasterizarlos también, conserva su nombre y pon las
versiones nuevas en nuevos/, sin sobrescribir originales/.

## Formato

PNG RGBA con fondo realmente transparente, 256×256 píxeles recomendado.
Un archivo por icono, sin texto, sin círculo y sin fondo: la interfaz ya los
coloca y traduce las etiquetas. Deja un margen del10–15% alrededor. Mantén el
mismo grosor de trazo, paleta y nivel de detalle; deben leerse a40–50px.
No hace falta una versión pulsada: el botón ya cambia su fondo al tocarlo.

Guarda los cinco PNG en nuevos/ y pásame esta ruta para integrarlos.
