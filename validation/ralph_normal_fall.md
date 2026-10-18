# Caída normal sin carga

assets/models/ralph_anims.json documentaba el alias fall con orig_name=fall2. wolf.cpp asigna ACOYOT01_ANIM_FALL1 al estado normal 0x06 WOLF_ST_FALL, con WSF_LOOP_ANIM; la tabla de modo transporte usa ACOYOT01_ANIM_FALL2. Se recupera FALL1 del WAR de Lvl01 mediante extract_run_assets.py y se reconstruye el alias fall en la biblioteca compartida de Ralph.

Se conservan todos los huesos (incluidas orejas), escalas, posiciones y claves originales con la conversión de matrices ZXY/signo Z corregida. Las claves usan el inicio de cada segmento nativo y cierran el bucle. No se inventa una animación de viento ni se altera la física del salto/descenso.

La caída fatal directa sigue siendo DEAD1/fall_death con cámara detenida; agotamiento de carrera aérea sigue usando STRIKE2/pit_fall; transportar oveja mantiene FALL2/sheep_carry_fall. La tabla original reserva STRIKE4 para WOLF_ST_ROCKET_CRASH: la identificación del fallo como uso de FALL2 no implica afirmar que esa misma animación sea el choque del cohete.

test_ralph_normal_fall.gd compara las rotaciones de todos los huesos en todas las claves de FALL1 con una transcripción independiente de Mat44::SetRotYXZ, verifica repetición, caída con oveja y separación de las dos muertes al vacío. Regresión: test_level00_closure.gd valida doble salto, carrera aérea y fundido/respawn.
