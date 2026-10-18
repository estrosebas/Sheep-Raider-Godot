# Reposo en sigilo

Fuente: `sdw-decomp/src/game/wolf.cpp`, tabla Ralph y casos
WOLF_ST_SNEAK_IDLE / WOLF_ST_SNEAK_MOVE. El reposo usa STAND11 en bucle,
estacionario y silencioso; el movimiento usa TIPTOE1. STAND11 se recuperó del
WAR Lvl-01, modelo Ralph:31 articulaciones, duración2.46s, sin cues de sonido.
Extractor: `tools/extract_sneak_idle.py PATH_TO_LVL_01`.

El controlador mantiene WolfState.SNEAK al detenerse mientras se mantiene la
acción sneak. Alterna los clips sneak/sneak_idle según el movimiento, sin
reiniciar la secuencia de ocho pasos al parar. Así conserva las condiciones
compartidas de percepción, acciones y cobertura. Soltar sigilo quieto devuelve
IDLE. El controlador específico de llevar oveja conserva sus propias poses.
La importación de STAND11 usa ejes ZXY y signo Z de la ruta de poses originales.

Validación: test_sneak_idle.gd y test_cover_alignment.gd, cero fallos.
La prueba antigua test_inventory_mechanics.gd reportó8 fallos en casos del
inventario/cohete; se comparó con las dos modificaciones de lógica de sigilo
retiradas temporalmente y reprodujo los mismos8 fallos. No es una regresión
introducida por este cambio; el controlador final se restauró tras comparar.
