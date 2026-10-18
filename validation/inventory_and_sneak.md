# Puntillas y selección de objetos

## Referencias originales comprobadas

Repositorio local: `C:\Users\estro\Downloads\Sheep.Dog.and.Wolf\sdw-decomp`.

- `src/game/wolf_misc.cpp`, `Wolf::SneakStepSound`, **0x48d627**: SND `0x48`, dos pasos por ciclo, solo ocho pasos. Tono `(0x800 + n*0x100)/4096`; volumen entero `((8-n)*255)/8`. `SNDF_POSITIONAL | SNDF_NO_RETRIGGER`.
- `src/game/wolf.cpp`, `Wolf::EnterState`, **0x48716f**: reinicia los temporizadores y contador de pasos al cambiar de estado.
- `src/engine/progress_inventory.cpp`: listas por clase (0–199), inserción al principio, selección por clase, cantidades y manos vacías (`0xffff`). `Inventory_Add` **0x50c4ac**, `Remove` **0x50c59e**, `GetSelectedObject` **0x50c635**, `SelectNext` **0x50c6a1**, `SelectPrev` **0x50c75c**.
- La rueda de una sola clase conserva la primera pulsación que solo gira desde manos vacías y su indicador de lado.
- `Wolf::QuickInventory`, **0x48f69a**: mantener botón para abrir, izquierda/derecha mientras no gira, equipar al soltar; bloquea el control del personaje (`CanControl`, **0x48e030**).
- `Inventory_DropUncommitted` **0x50d180**, `CommitAtCheckpoint` **0x50d37f**: devolver recogidas sin checkpoint; retener las confirmadas.
- `scn_register.cpp`: Rocket/clase **10** tiene `SCN_CF_INVENTORY_ITEM`. El tutorial contiene el objeto WAR **77**, modelo **5**, en `(-93, 8.22, -2.85)`.

La muestra `assets/audio/sfx/sneak_step.wav` coincide byte a byte con el RIFF del sonido **0x48** del SND original. Cambió su reproducción, no el archivo.

## Reutilizar en otros niveles

`scripts/player/ralph_step_rules.gd` devuelve tono, volumen e intervalo sin nodos, audio ni Input.

`scripts/inventory/inventory_state.gd` es un `RefCounted` independiente de la escena, de Input y de los objetos 3D. Sus registros son diccionarios:

```gdscript
{"id": "nivel:objeto", "class_id": 10, "label": "Cohete", "icon": "", "kept": false}
```

API: `add`, `remove`, `count_class`, `next_class`, `prev_class`, `select_class`, `select_next`, `select_prev`, `clear_selection`, `get_selected_object`, `commit_at_checkpoint`, `drop_uncommitted`, `reset`. Señales: `changed`, `selection_changed`, `rolled_back`.

`inventory_component.gd` adapta esa lógica a Ralph y a `scenes/ui/InventoryWheel.tscn`. Ralph lo crea para cada instancia/nivel. Los pickups reutilizan `inventory_pickup.gd`: configura identificador, clase, nombre e icono y coloca su modelo como hijo. **E** recoge el objeto disponible más cercano dentro de 2.5 m. El pickup se oculta y vuelve mediante rollback.

Cada clase registra su implementación de uso:

```gdscript
player.inventory.register_use_handler(10, usar_cohete)

func usar_cohete(item: Dictionary, actor: Node) -> Dictionary:
    # Implementar aquí la mecánica específica del objeto.
    return {"success": true, "consumed": false}
```

Un handler ausente o rechazado conserva el objeto. Solo `{success: true, consumed: true}` lo consume. Las señales `equipped`, `use_requested` e `item_used` permiten conectar modelos en mano y efectos particulares. El gestor de checkpoint puede llamar a `player.inventory.state.commit_at_checkpoint()` y `drop_uncommitted()`.

Controles: mantener **Tab**, **A/D** o flechas para girar, soltar **Tab** para equipar, **Esc** para cancelar/restaurar selección, **E** para recoger/usar. El mundo continúa simulándose y la gravedad sigue activa durante el menú.

## Geometría y comprobaciones

`extract_inventory_assets.py` separa los **138 triángulos** del cohete comprobándolos contra el WAR/DAV. La suma de malla estática y cohete conserva los **8,325 vértices** de objetos, con posiciones, UV y colores exactos del JSON previo. `level_objects_data.json` conserva el export completo original; `level_static_data.json` excluye el cohete. `build_inventory_assets.gd` genera ambas mallas sin reconstruir las animaciones del personaje.

- `tools/test_inventory_mechanics.gd`: sin fallos. Agrupación, orden, selección especial de una clase, manos vacías, duplicados, checkpoint, eventos reales de entrada, bloqueo físico de movimiento/salto, equipar, cancelar, recoger/ocultar/restaurar el cohete, handlers de uso y ocho pasos con el tono original.
- `tools/test_run_mechanics.gd`: sin fallos tras integrar inventario/puntillas; mantiene carrera, cansancio, impacto real, salto y doble salto.
- `tools/verify_materials.gd`: incluye ahora la malla separada del cohete.
- `inventory_wheel.png`: captura con renderizador real; sus objetos adicionales son fixtures de visualización, no inventario inicial del nivel.

## Alcance pendiente

La rueda usa ahora la animación de crayón y los iconos originales del DAV, junto con la posición, brillo y movimiento del C++; ver [original_inventory_ui.md](original_inventory_ui.md). No se portó el menú completo de mapa/combinar objetos de `map.cpp` ni el efecto `ItemFly`. Los modelos en la mano, disfraces vestidos y vuelo básico del cohete ya están implementados mediante clases compartidas: ver [shared_items.md](shared_items.md). Los mensajes de objetos compuestos, rollback del mundo/buzones y condiciones de entrega y activación por guion todavía requieren integración.
