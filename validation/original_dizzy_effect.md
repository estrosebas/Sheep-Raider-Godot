# Efecto de mareo al chocar

Fuente: wolf_move.cpp, Wolf::RunAirFallStep, rama WOLF_RUN_CRASH: StopMotion, SetState(WOLF_ST_RUN_CRASH), vibración/camera shake y Fx0_Start. wolf_misc.cpp, Wolf::Fx0_Start, muestra WOLF_PROP_ETOIL (AETOIL01) con TURN1 repetido y lo adjunta al joint 0 con offset nativo (0,-150,0). Wolf::SetState en wolf.cpp llama Fx0_Stop al cambiar de estado. En los assets PC recuperados este modelo dibuja estrellas amarillas girando; se conserva el asset original, aunque el usuario lo describió como pajaritos.

tools/extract_dizzy_effect.py resuelve WAR_IDO_AETOIL01=2 mediante la tabla de exportaciones de Lvl00.WAR, recupera geometría, huesos, TURN1 y páginas DAV. source.json registra recurso, joint y offsets; el extractor no busca un modelo por parecido visual. tools/build_dizzy_effect.gd genera exclusivamente este actor reutilizando el importador compartido, con conversión ZXY y corrección de signo Z. TURN1 tiene duración nativa de 0,8 segundos.

OriginalDizzyEffect se añade al controlador compartido de Ralph. Al entrar en RUN_CRASH activa el modelo y su bucle; su transformación sigue la matriz real del root joint más 1,5 m. Cualquier salida del estado, interrupción de cinemática o respawn limpia el efecto. Mantiene la animación y sonido de choque existentes.

Validación: test_dizzy_effect.gd verifica origen TURN1/duración, animación real, altura/attachment, movimiento con Ralph y limpieza de estado/cinemática/checkpoint. Captura GPU: original_dizzy_effect.png. test_run_mechanics.gd verifica activación y desaparición también al chocar realmente contra un muro físico.
