# Reloj03: colisión y salida

Dos problemas verificados en la geometría y durante la partida:

1. TimeKeeper86 bajaba de su pivote WAR6,87m al suelo real5,9918m,
   pero su caja/cone de colisión se quedaba en un cuerpo estático separado.
   La caja nativa es flags2,[-40,-147,-20]..[17,13,32].
2. El triángulo de colisión6628 invade el costado del hueco visible:
   (5.87,9.35,-44.34),(6.34,9.53,-46.49),(5.93,6.78,-46.27).
   Un rayoX6/Y7,75/Z-50→-43 chocaba con él, aunque pasaba limpio
   contra la geometría renderizada del escenario original.

TimeKeeper posee ahora su collider original, sin duplicado global. Espera
al registro de las formas en física antes de SnapToGround y excluye sus
propios RIDs. Al aterrizar mueve collider y modelo al mismo punto.
La caja sigue alineada al mundo, independiente del giro del arte del reloj.
La corrección compartida se aplica también a los importadores01/02.

El nivel03 configura `clock_collision_region` en `port_balance.json`:
origen `Vector3(2.5,5,-50)`, tamaño `Vector3(5,9,8)`. Solo ese tramo
sustituye las caras de colisión simplificadas por las caras sólidas del
escenario visible, respetando las paredes, suelo y techo reales.
Las caras exteriores se conservan exactamente. El archivo WAR y la
colisión nativa exportada no se sobrescriben; la forma corregida mantiene
metadatos de7084 triángulos fuente. No se añade un teletransporte ni se
habilita atravesar paredes globalmente.

`tools/test_level03_clock_passage.gd` comprueba collider alineado, ausencia
de duplicado, rayo libre en el costado invisible, igualdad de caras fuera
de la región, activación real del reloj/progreso y tránsito físico en ambos
sentidos después de activarlo. La entrada tiene un labio elevado visible:
la prueba salta ese escalón real y luego camina por el pasadizo.
Las partidas de prueba usan un directorio temporal independiente.
