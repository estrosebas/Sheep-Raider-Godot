# Nivel 02: piedras, arbustos, ventilador y perfume

Implementación compartida a partir de Rock.cpp, Bush.cpp, Wolf.cpp, Fan.cpp, Perfume.cpp y Sheep.cpp del repositorio sdw-decomp y de los modelos, animaciones, cajas y propiedades de Lvl-02.WAR/DAV.

- Piedras: PUSH1A/B/C de Ralph, rodadura por desplazamiento/radio, sonido SCOPUSH 262, perfil original de 1,5 m/s y aceleración de 8 m/s². Respeta los ejes y zonas de cada entidad; el control adaptado es mantener E. El laboratorio tiene una piedra de prueba. La posición se conserva en los snapshots manuales.
- Arbusto: entrada JUMP6, disfraz ABCOYO01, salida OUT6, marcha normal y sigilosa y reacción al ventilador. Quieto oculta a Ralph, con la excepción de detección a muy corta distancia de Sam. La ocultación automática al parar es una adaptación del control original. Las ovejas pueden consumirlo durante 20 segundos; reaparece tras 7 segundos. El crecimiento original se simplifica a desaparición y reaparición, sin reproducir aún su deformación progresiva.
- Ventilador: agarre al hueso 18 y poses LINK/STANDV1B/STANDV1/WALKV1 originales; incluye la geometría animada del viento. Ralph gira con el ventilador sin caminar. El cono de alcance es de 4 m.
- Perfume: colocación animada y partículas de la hoja original. El viento amplía el alcance hasta unos 20 m; las ovejas siguen el corredor de olor de 2 m a cada lado hacia el frasco. El alcance crece y decae según los tiempos originales. No se afirma reproducir todo el ciclo de olfateo original.
- Inicio: las colisiones del área inicial se reconcilian con la malla visible. El techo y escenario usan una capa adicional exclusiva de cámara; los rayos de suelo, colocación y visibilidad de Sam usan la capa de juego.
- Buzón: cámara en coordenadas globales; solo se gira el modelo, conservando las cajas originales sin rotación del padre.

Validación: test_level02_interactions.gd (headless y GPU), test_shared_items.gd, test_level02_foundation.gd, test_level_completion_and_save.gd, test_run_mechanics.gd, test_sheep_lettuce_bridge.gd y test_lab_stations.gd: cero fallos. Capturas GPU de agarre/viento/perfume, arbusto, inicio y cámara del buzón. Estos controles no sustituyen un recorrido completo manual del nivel.
