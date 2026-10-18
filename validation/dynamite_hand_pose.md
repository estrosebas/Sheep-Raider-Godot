# Mano y pose originales de dinamita

Wolf::EquipItem (wolf_misc.cpp, 0x48f120) envía MSG_PICKUP con hueso0x12 (18) para objetos normales y3 para el cohete. Dynamite::HandleMessage adjunta a ese hueso sin offset ni rotación extra y escoge ADYNAM01 LINK. El port usaba posición de hueso21 y orientaba la dinamita hacia delante con look_at, perdiendo la base de la muñeca. Ahora item_hand_position devuelve18 y la dinamita usa la matriz completa de ese hueso, cancelando solo la reflexión interna de exportación antes de evaluar su propio skin.

Las claves de TAKE1A/B, TAKE4, PUT4 y PUT1A/B emplean la conversión original de rotaciones ZXY/signoZ y tiempo inicial de segmentos, igual que los clips de cargar oveja. LINK del rig ADYNAM01 también se reconstruye con esa conversión. La salida de inventario activa LINK antes del vuelo hacia la mano, sin alterar el vuelo de recogida desde el suelo (ItemFly_Start original usa la posición del objeto).

Wolf::SetIdleState escoge STAND10 al tener un objeto no cohete. Se recupera como held_item_idle y se usa al sostener dinamita, en vez de STAND1 con manos vacías. Las poses de carrera, salto, oveja y cohete no se fuerzan al reposo de dinamita.

Reproducible: extract_run_assets.py incluye STAND10; extract_level01_mechanics.py conserva los metadatos de conversión del rig de dinamita; build_run_animations.gd y build_dynamite_hand_pose.gd reconstruyen las bibliotecas.

Pruebas: test_dynamite_hand_pose.gd verifica STAND10, anclaje18 separado de21, orientación completa de muñeca y LINK original. Captura GPU dynamite_original_hand_pose.png. test_level01_essentials.gd comprueba entrega, recogida, encendido/colocación, explosión y reaparición.
