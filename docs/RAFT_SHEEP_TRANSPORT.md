# Balsas y ovejas: transporte compartido (22/10/2026)

En `src/objects/raft.cpp::Raft::Update`, la balsa consulta los ocupantes de
su caja superior y llama `Translate(delta)` para cada uno. Después envía
`MSG_SET_ANCHOR` a las ovejas: posición nueva de la balsa y radio50 unidades
(0,5m). No requiere que Ralph esté encima para transportar ocupantes por
corriente. Su presencia sólo condiciona la propulsión del ventilador.

`Sheep::MSG_SET_ANCHOR` conserva ese destino sin reemplazar `homePos`.
Sin un atractor, la oveja vuelve hacia ese centro cuando supera el radio;
no intenta volver a su rebaño mientras sigue sobre la balsa. Las lechugas,
perfume, llamada y botones conservan sus respuestas normales.

## Fallo y corrección

El port sólo aplicaba desplazamiento manual a objetos sin física activa,
confiando en `move_and_slide` para todas las ovejas activas. Una oveja cuya
IA no ejecutaba movimiento (por ejemplo durante una secuencia) quedaba
atrás mientras la balsa continuaba. Al perder el contacto también perdía
el anclaje y podía intentar volver a casa.

Ahora OriginalRaft aplica el delta real de movimiento a las ovejas, estén
activas o detenidas. Durante ese apoyo se desactiva su seguimiento automático
de plataformas de Godot para evitar recibir el mismo delta dos veces.
La física de la oveja corre después de la balsa (prioridades100 y50).
Se restauran las propiedades originales al recogerla, abandonar cubierta,
morir, lanzar desde un balancín o restablecer el checkpoint.

Ralph sigue usando el transporte automático ya probado; las lechugas y
otros objetos colocados siguen MovingSupport. No se reparenta la oveja ni
se cambia su identidad, posición de reaparición, guardado o interacción.

## Pruebas

`tools/test_level05_raft_sheep.gd` usa la balsa original49 en un canal
original amplio del05. La corriente la mueve con una sola oveja, Ralph
en tierra y sin ningún atractor. Incluye un segundo de cámara/acción
bloqueada, parada de la balsa, espera prolongada y regreso al centro.
Antes: 2,3875m recorridos y deriva relativa máxima0,6771m.
Con el transporte explícito: mismos2,3875m y deriva0,0000m.

Se comprueban también la ocupación, conservación de home, liberación del
anclaje y restauración de los parámetros de plataformas al desembarcar.
