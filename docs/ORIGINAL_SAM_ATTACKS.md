# Sam: captura y golpe

Fuente: `Sam::TryCatchWolf`, `SAM_STT_CATCHWOLF` y
`Wolf::MSG_WOLF_CAUGHT` del código decompilado.

- Al mismo nivel (Ralph entre -0.5 y +0.3 m respecto a Sam), 50 % de
  probabilidad de captura: Sam/Ralph PUNCH7. Al terminar Sam, Ralph pasa a
  DIEPNCH2 y Sam a WIN.
- En otro caso, dentro de -1 a +1.5 m: Sam/Ralph PUNCH3. Ralph empieza su
  muerte inmediatamente; al terminar el golpe, Sam pasa a WIN sin cambiar
  la animación de Ralph a DIEPNCH2.
- Ambas muertes añaden los dos segundos originales al final de la animación.
- Las claves de audio se recuperan de SND; 344 es SND_RUMBLE, sin audio en PC.
- WIN usa claves parciales. `win_after_hit` hereda la última pose de PUNCH3;
  WIN conserva la herencia de PUNCH7 para la captura.

La selección pertenece al controlador compartido y funciona en los niveles
01–05. No es una lista de muertes elegidas aleatoriamente: cada ataque tiene
su secuencia. El caso especial de captura con disfraz de oveja del original
no se incorpora con este cambio. La cámara conserva el encuadre de muerte
del port; el cambio original de modo de cámara a los dos segundos de PUNCH3
no se reproduce por separado.

Extracción: `tools/extract_sam_attacks.py LVL_01`; regeneración:
`tools/build_sam_attacks.gd` y `tools/build_run_animations.gd`.
Pruebas: `tools/test_sam_leash_and_recovery.gd`.

## Corrección del audio compartido

GRAB reproduce los eventos de Ralph29 a2.10s y80 a2.64s incluso mientras
Sam bloquea sus controles. HIT reproduce81 a2.06s desde la muerte de Ralph.
La reacción WIN de Sam lleva77 a0.94s. Son muestras y tiempos del original;
344 sigue siendo vibración del mando, sin muestra de sonido en PC.

Los eventos de Sam se disparan únicamente al cruzar su tiempo, evitando que
los eventos pasados reinicien el sonido en cada fotograma. Un pequeño grupo
de voces permite solaparlos sin cortar la muestra anterior.

Los efectos de Sam y las reacciones de Ralph a sus ataques usan la curva de
`sound_mgr.cpp::Sound_SetDistanceFalloff(200,5000,0,1)`: volumen completo
hasta2m, descenso lineal hasta50m. La atenuación inversa predeterminada de
Godot los hacía demasiado débiles con nuestra cámara libre. El resto de
efectos de animación de Ralph conserva su configuración anterior.

Prueba adicional: `tools/test_sam_attack_audio.gd`, que comprueba ambos
ataques, sus claves, solapamiento, ausencia de reinicios y curva de volumen.
