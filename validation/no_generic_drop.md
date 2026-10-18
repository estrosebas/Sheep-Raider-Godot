# Q desactivada para soltar objetos

La rama genérica drop_item de InventoryComponent se conserva comentada como
referencia del atajo de pruebas que se había añadido al port. La acción del
InputMap queda sin teclas y el laboratorio ya no anuncia Q para colocar.

No se desactiva allow_world_placement: la lechuga y el perfume conservan su
colocación mediante use_item (E/R), animación y comprobación del suelo. El
cohete conserva su uso y fin de uso propios; Q no lo suelta ni lo desmonta.

test_shared_items.gd pasó sin fallos: un evento sintético drop_item conserva
el imán equipado y el cohete activo; los usos normales de lechuga/perfume
siguen colocando sus objetos y sus interacciones continúan funcionando.
