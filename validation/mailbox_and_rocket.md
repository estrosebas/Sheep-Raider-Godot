# Buzón y cohete del tutorial

Hito implementado desde los WAR/DAV/SND originales y las funciones C++ del repositorio `sdw-decomp`.

## Uso

Después del puzzle, sigue a Lucas hasta el buzón. Acércate y mira hacia él; **E** solicita el envío. Ralph golpea el buzón, la cámara original muestra la caja cayendo y esta se abre automáticamente al tocar el suelo. **E** recoge el cohete: Ralph ejecuta TAKE1A/B y el objeto vuela hacia el inventario antes de desaparecer. Mantén **Tab**, selecciona con **A/D** y suelta Tab: TAKE4 devuelve el cohete a la espalda. **E/R** inicia ROCKET0 → ROCKET2 → ROCKET3. Elegir manos vacías guarda el objeto con PUT4 y el vuelo al inventario.

## Trazabilidad

- `objects/mailbox.cpp`: PostLoadInit guarda y retira el contenido, export 518 resuelve Rocket 77; MSG_USE abre una sola vez, LETTER1 del buzón, SGLPLANE (251) a velocidad 0xc00/4096, cámara export 627 durante 3000 ms, Deliver crea ACAISS01 en la posición original del objeto. Commit/Rollback conserva pedidos confirmados y restaura los anteriores al checkpoint.
- `game/scn_controllable.cpp::ScanInteractables` y `wolf_misc.cpp::ScanContextActions`: distancia entre cajas de colisión de 60 unidades y margen angular de 1024/4096; objetos sin cajas usan radio de 100 unidades y rango vertical 50. Se conserva la escala de 100 unidades por metro.
- `game/wolf.cpp`: ACTIVATE/END = LETTER1A/B (0.56/0.31 s), PICKUP_ITEM/END = TAKE1A/B (0.5/0.5 s); el mensaje de uso y la incorporación al inventario esperan el final de la primera animación.
- `objects/box.cpp::Update`: descenso constante de 800 unidades/s; colisión original de ACAISS01, OPEN1 (0.82 s), liberación del contenido y eliminación de la caja al terminar. El original **no espera una segunda pulsación para abrir la caja**.
- `engine/progress_inventory.cpp::ItemFly_Start/Inventory_UpdateFx`: interpolación hacia el punto de cámara `(0,-120,384)`, tiempo 4096/9600 s, aparición de la nube durante el vuelo. La recogida conserva el punto original de inicio del efecto; no inventa un anclaje a la mano. Los objetos ordinarios se equipan en la mano al seleccionarlos.
- `wolf_misc.cpp::EquipItem` y `objects/rocket.cpp::HandleMessage`: el cohete se equipa en el hueso **3**, con offset original `(0,10,20)`; el resto de objetos sigue el anclaje de mano existente. MSG_INVENTORY_STORED restablece combustible y resistencia. ROCKET0 monta el cohete en 0.38 s; ROCKET2 enciende, ROCKET3 vuela. Se recuperó también el modelo animado AFUSEE01.
- Lucas sigue los caminos y triggers 15, 16 y 17 originales, voces españolas 85 y 86. Los textos indican los controles actuales de PC. Esta etapa termina después de la instrucción de volar hacia la meta.

## Reutilización

`OriginalMailbox` recibe la definición, lista de objetos, definición de caja y sonidos; no crea un inventario específico del nivel. `OriginalDeliveryBox` y `OriginalItemActions` implementan entrega y presentación compartidas. Recursos de buzón, caja y cohete animado en `assets/items/{mailbox,delivery_box,rocket}`. El nivel 00 solo resuelve los exports, coloca las instancias y conecta checkpoints. Se retira el buzón de la geometría/collision estática duplicada.

El buzón puede entregar varios objetos; este hito cubre cajas normales generadas como las de Lvl-00. Las variantes de cajas flotantes, cajas explícitas y la piedra especial de Lvl-03 aún requieren sus adaptadores. El mapa/guía original sigue pendiente. La meta con oveja y las correcciones posteriores del cohete están documentadas en [tutorial_finish.md](tutorial_finish.md).

## Comprobación

- `tools/test_mailbox.gd`: proximidad/orientación, objeto oculto antes del pedido, tiempos de activación, entrega única, caída física, apertura/liberación, cámara e input restaurados, recogida almacenada, equipamiento a espalda, montaje/ignición/vuelo, interrupción y rollback/commit, voces de Lucas.
- Regresión: inventario/puntillas, siete clases de objetos, puzzle/balancines, continuidad de tutorial, cámara y orientación del mapa.
- `tools/verify_materials.gd`: colores originales, importación sin pérdida y muestras de GPU. Se desactiva `detect_3d/compress_to` en páginas de texturas para que Godot no vuelva a convertirlas automáticamente a compresión VRAM y mipmaps al usarlas en 3D.
- `extract_puzzle.py --verify`: comparación directa de rigs, frames, export de contenido, cámara, sonidos y páginas recuperadas.

Capturas: [pedido](mailbox_request.png), [caja cayendo](mailbox_delivery.png), [recogida](mailbox_pickup.png), [cohete en espalda](rocket_back.png).
