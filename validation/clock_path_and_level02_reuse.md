# Reloj, hueco del camino y reutilización

Revisión del código y archivos originales, 2026-10-07.

## Correcciones del reloj

`OriginalTimeKeeper` conserva entidad 65/modelo 37, ubicación XZ nativa, CLOCK1/2/3/4, uso CLOCK2 de Ralph, sonidos originales y recompensa única por nivel. El modelo permanece visible después de usarlo.

Se sustituye la búsqueda de suelo de respawn de Ralph (3 m por encima) por la de `ScnObject::SnapToGround` (`src/engine/scenaric.cpp:1465`), desde 50 unidades originales, equivalentes a 0,5 m. La búsqueda anterior podía alcanzar el techo del escondite. La base de la malla se alinea con el suelo y el aviso se sitúa encima del modelo.

`ScnControllable::ScanInteractables` (`src/game/scn_controllable.cpp:399`) considera cajas de los modelos; `Wolf::ScanContextActions` utiliza 60 unidades como separación máxima entre cajas. El port adapta esa búsqueda a los límites de la malla CLOCK1, la cápsula de Ralph de radio 0,35 m y una separación de 0,6 m. Mantiene la restricción de uso desde el suelo y sin oveja en brazos; una comprobación corta de suelo tolera el desfase de un fotograma de `is_on_floor`. No es una reproducción completa de la selección original entre todas las cajas.

La clase recibe identidad del nivel, directorio del modelo y banco de sonidos desde el importador. Los relojes de niveles distintos no comparten el bit de recogida; el nivel 16 concede dos puntos, como `Progress::AwardTimeKeeper`.

## Hueco del camino secreto

`OriginalFallZone` es un componente reutilizable. Sus límites y altura se cargan desde el archivo opcional `data/fall_zones.json` de cada nivel. En el nivel 01 cubre X 18–36, Z -34–-12 y activa la caída debajo de Y -3 m, en coordenadas del port.

Este límite local es una adaptación solicitada para el hueco del camino del reloj, no un trigger recuperado del original. Activa el mismo estado PIT_FALL/STRIKE2, cámara detenida y transición de respawn ya implementados. Protege salto, gracia del segundo salto, coyote time, carrera aérea, cohete y cinemáticas. No modifica la duración de vuelo ni los umbrales globales del raycast. Un muestreo del terreno encontró 117 superficies por encima del límite, con mínima Y -1,487 m. Sigue pendiente recorrer el camino a mano en una partida completa.

Después de que el usuario marcó el hueco en el editor, se añadió `SecretPathUpperGapFall`: X 28–39, Z -5–4, activación debajo de Y -3 m. Este tramo quedaba fuera del primer límite. El raycast original del port intersecta allí caras de roca con normales casi horizontales: en X30/Z0 alcanza Y -4,286 con normal Y 0,068, y lo interpreta como suelo cercano. La prueba comprueba ahora ese caso con la geometría real, sin añadir un suelo artificial. También recorre la caída con física, revisa las superficies caminables vecinas y preserva las protecciones aéreas. El nuevo límite es una adaptación local; no cambia la función global de raycast.

### Pozo rectangular confirmado antes del primer salto

La captura cercana del usuario y su aclaración permitieron identificar el pozo real en X≈27/Z≈20. Los dos límites anteriores cubrían otros tramos. El fondo rectangular verde es una superficie horizontal original a Y=-9,51 m; el borde está aproximadamente a Y=-1,5 m. La captura `secret_shaft.png` reproduce el mismo pozo desde la geometría guardada, sin actores ni modificaciones del escenario.

`SecretPathEntryShaftFall` cubre X25,8–28,05/Z17,8–22,8. Usa una guarda bajo el borde (Y=-1,65) y la altura del primer salto menos `max(DOUBLE_JUMP_HEIGHT * jump_height_scale, jump_void_drop_margin)`. Con los valores actuales, desde el borde activa la caída por debajo de Y=-2,85 m. No toma el segundo ápice como referencia. Mantiene las protecciones de salto, gracia aérea, coyote time, carrera aérea, cohete y cinemáticas. La referencia mínima del borde impide que aterrizar en el fondo verde haga seguro el pozo. Esta regla es una adaptación solicitada por el usuario y queda configurada únicamente para este pozo.

`tools/test_secret_shaft_fall.gd` verifica fondo real, oportunidad de recuperación, altura original variable, protección del salto y vuelo, aislamiento espacial, aterrizaje inválido en el fondo, gravedad y colisión reales, animación, cámara y regreso al checkpoint. La caída física se dispara en Y=-2,929; el respawn vuelve a (8,91; 0,080; 12,73). Esta prueba y las regresiones `test_clock_path_fall.gd` y `test_deep_floor_void.gd` terminan con 0 fallos.

## Qué se reutiliza y qué depende del nivel

| Sistema | Estado real |
| --- | --- |
| Movimiento, salto, sigilo, carrera, caída, cámara de muerte y llevar oveja | Componentes compartidos. |
| Inventario, clases de objetos, buzón/caja/recogida, carteles, pausa, diálogos y secuencias | Componentes compartidos; necesitan datos y conexiones del nivel. |
| Sam y rebaño | Clases compartidas. Rutas, zonas, banco de audio y parámetros proceden del nivel; Sam aún no recupera ovejas robadas mediante FETCH/CARRY. |
| Reloj y zonas de caída | Configurables por nivel después de este cambio. |
| Checkpoints | Gestor compartido en memoria. El guardado manual de escenas todavía admite solo el nivel 00. |
| Lucas, Porky y tutorial | Directores específicos de nivel sobre componentes comunes de conversación/cinemática. Sus condiciones y secuencia forman parte de cada puzzle. |
| Carga del nivel y extracción de IA | Importación de geometría general, pero `ImportedLevel` todavía tiene claves, buzón, música y directores fijados al 01; `extract_level01_ai.py` también necesita generalización. |

## Trabajo para nivel 02

El WAR original Lvl-02 incluye dos buzones, ventilador, perfume, cuatro lechugas, Sam, catorce ovejas, un balancín, un botón, plataforma de madera, elevador, puerta secreta, tres pirañas y reloj. `objects/daffylevel02.cpp` coordina sus propias fases y condiciones del tutorial/puzzle.

Se podrán reutilizar el controlador, objetos, buzón, ovejas, Sam y presentación. Antes de montarlo conviene configurar por nivel música, director, IDs de objetos, múltiples buzones y datos de IA. Habrá que conectar o completar los mecanismos de plataforma/elevador/botón/puerta y pirañas, además de secuencias, checkpoints, victoria y estado de guardado. Por ello, la base jugable se estima de dificultad media; completar fielmente el puzzle requiere trabajo adicional, no solo sustituir posiciones y audio. Esta valoración procede de comparar las clases originales con los componentes presentes, no de una partida completa del nivel 02.

## Verificación

- `tools/test_timekeeper_reuse.gd`: acercamiento en el escondite real, tecla E por el viewport, alineación de base, alcance desde el borde, rechazo en salto, prueba de techo, recompensa e independencia entre niveles 01/02/16.
- `tools/test_clock_path_fall.gd`: suelo oculto a 8 m que no dispara el raycast global, activación local, animación/cámara, límite de altura, doble salto, coyote time, carrera aérea y aislamiento espacial.
- `tools/test_deep_floor_void.gd`: regresión de caída general, suelo profundo y protecciones aéreas.
- `tools/test_level01_porky_clock_and_blast.gd`: regresión de reloj, Lucas/Porky, explosión y lechugas.
- Godot 4.7.2: las cuatro pruebas terminan con 0 fallos. Captura GPU en `validation/clock_original_location.png`.
