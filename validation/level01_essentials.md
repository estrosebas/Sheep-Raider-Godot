# Nivel 01: actores, agua y objetos esenciales

## Formas blancas y actores

Había varios objetos distintos: el modelo del trigger **Goal 115** se estaba dibujando aunque `Goal::PostLoadInit` ejecuta `SetVisible(0)`; la nota **66** y la dinamita **70** aparecían en sus posiciones elevadas de entrega antes de abrir el buzón; y Bird **87** mostraba su pose de datos aunque `Bird::PostLoadInit` empieza oculto. Se respetan esas inicializaciones. El vuelo decorativo del pájaro queda para su adaptador posterior.

Las **17 ovejas** usan `OriginalSheep` compartida con el tutorial: cuerpo, gravedad, ajuste inicial al suelo, atracción por lechuga y cargar/dejar. Se usa su modelo **1** del nivel 01 y el reposo `STAND3` del estado inicial fuera de la zona naranja; no son meshes de preview sin física. Se conserva el rebaño en sus posiciones originales y no se elimina la lana blanca del asset.

Sam **43** recibe cuerpo/gravedad, ajuste al suelo y secuencia original `Sam::Reset`: `START` seguido de vigilancia `HEAD2`. Sus animaciones se extraen completas, con conservación de pose para los canales no presentes al pasar a HEAD2. Su inicialización visual/física está montada; **la IA completa de alerta, persecución, captura y devolución de ovejas sigue pendiente**. El reloj ya usa `CLOCK1` disponible y el ajuste al suelo; su bonus/registro todavía no están conectados.

## Catarata

`tex_scroll.cpp` lee las listas del header WAR **0x83**, mueve una fila de la textura por update y envuelve dentro del rectángulo. El port modifica copias locales de las páginas; no altera el PNG ni desplaza otras texturas del atlas. Se fija a **60 updates/s** para no depender de los FPS.

Regiones recuperadas `(x,y,width,height)`: página 10 `(64,64,132,64)` inversa; página 6 `(0,32,24,31)` hacia delante; página 10 `(96,32,4,31)` hacia delante; página 0 `(32,32,48,31)` hacia delante. Se reutilizan los mismos materiales/renderers y sus modos DAV.

Hay partículas de agua en las bases de las dos superficies altas: sprites originales de **IGLTIDE**, con posiciones derivadas de su geometría. La colocación, dispersión, vida y cadencia del spray son un adaptador visual (.08 s/.6 s), no se presentan como parámetros de un emisor de catarata recuperado del C++. Los sprites y el flujo de textura sí se verifican contra DAV/WAR.

## Buzón y dinamita

`Mailbox 61` referencia cámara **574**, duración **2500 ms**, y entregas **490→Dynamite 70**, **486→SignPostSimple 66**. La segunda caja contiene una nota, no el telescopio. Se reutilizan `OriginalMailbox`, LETTER1A/B de Ralph, ALETTR01 LETTER1, la caída a 800 unidades/s y OPEN1 de ACAISS01. Ambos contenidos permanecen ocultos antes de la entrega; E permite leer la nota en el cuadro original.

`DynamiteItem` compartida, clase **2**, modelo **ADYNAM01 8**:

- OBJET en el suelo, LINK en la mano, PUT1A/PUT1B de Ralph al usar, STAND1 encendida. Se planta a los pies con validación de suelo, como `CanPutDownHeldObj(1)` y offset `(0,-2,0)`; Q es la colocación general, R/E es el uso que enciende la mecha.
- Se retira del inventario al final de PUT1A. La propiedad FUSE **5000 ms** inicia una mecha de **5 segundos**.
- Sonido original **SDYMECHE 98** en bucle y sprites de `ITICPTR`, sheet 7. `Emitter_UpdateColumn` aporta ascenso 200 unidades/s, vida/periodo .5 s, tamaño 16→64 y pool 3.
- Radio horizontal **300 unidades**, altura **±200**, según `Dynamite::Update`. Las rocas **68** reaccionan a MSG_KILL con **AROCHE06 BOOM01** de 1.8 s y liberan su colisión cónica al terminar.
- Modelo alternativo **AEXPLOS1** resuelto por export **3→modelo 22**, no por índice de recurso 3 (este era el modelo auxiliar de cámaras/gestores). Reproduce BOOM **3 s** y su sonido **99**. Después espera **3 s** y reaparece en el lugar de entrega; debe recogerse otra vez.
- Ralph en el radio recibe **EXPLOS1** original de 1.6 s con caída y fundido de reinicio, en lugar de STRIKE2 de pozo. El broadcast de ruido a Sam se implementa en el [hito de IA](level01_ai.md); la sacudida de cámara completa continúa pendiente.

## Laboratorio y telescopio

Se añade **dinamita**, una barrera de **rocas destructibles** y un **telescopio** junto con los siete objetos anteriores. Las lechugas originales del mapa ahora son `LettuceItem` funcionales, en lugar de previews.

El telescopio **69** es un objeto fijo, no un objeto de inventario. E activa su cámara, congela a Ralph y E vuelve. Utiliza focos/distancias **2500/1200** normales y **200/200** invertidos, cajas de consulta originales y límites angulares `grados*11`. La máscara usa `I01LVU4/I01LVU5` del DAV, montadas en mosaico espejado como `Hud_DrawTelescopeMask`. El laboratorio usa una zona local de aproximación para poder probarlo fuera del mapa.

## Verificación

`tools/test_level01_essentials.gd`: las 17 ovejas y Sam pisan suelo; inicialización invisible de Goal/contenidos; movimiento de filas correcto y píxeles fuera de región intactos; emisiones de agua; buzón con dos cajas, liberación/recogida, LINK, PUT1A/B, consumo y mecha; chispas y sonidos; BOOM y ruptura/liberación de rocas; reposición; telescopio con máscara/zoom/restauración y muerte de Ralph por explosión: **0 fallos**.

Extractores de escenario y mecánicas con `--verify`: rigs, páginas, sonidos, referencias y scroll coinciden con WAR/DAV/SND. También pasan objetos compartidos y la entrega física de la oveja en la meta del nivel 00. Los tests del tutorial ignoran la oferta de partidas guardadas del jugador para evitar pausar la prueba; no leen ni escriben sus ranuras.

Capturas GPU: [rebaño/Sam](level01_grounded_flock.png), [agua](level01_waterfall.png), [entrega](level01_dynamite_delivery.png), [mecha](level01_dynamite_lit.png).

Corrección de manchas restantes: `CameraRestriction`, `CheckpointManager`, `VisibilityManager`, `FogManager`, `MapLocation`, `AmbientSoundManager`, `CinematicsManager` y `CreditsManager` son clases lógicas, registradas sin arte visible. Sus modelos auxiliares (habitualmente recurso 3, también recurso 12 en dos cámaras) se estaban instanciando como meshes del escenario. Ahora se conservan sus registros/propiedades, pero no se crean ni visuales ni sólidos de preview para esas clases. El test revisa cada entidad lógica del mapa para impedir su reaparición.

Carteles junto a entrega: rango de lectura adaptado a **.75 m**. Si un objeto recogible está más cerca que la nota, E prioriza recogerlo aun estando dentro de ambos rangos; no se cambia la posición original de la dinamita. Telescopio: cerrar con E consume ese mismo evento después de liberar a Ralph, evitando que el dispatcher del inventario vuelva a abrirlo en el mismo frame. La prueba usa el dispatcher compartido para la recogida y eventos reales de E para salir del visor.

Correcciones de atlas/cámara/entrada aérea: `OriginalTextureScroll` ahora comprueba el **atlas de origen**, no solo el número de página: únicamente enlaza texturas de `assets/levels/lvl_01/textures`. Ralph conserva el atlas compartido del nivel 00. Los meshes/materiales estáticos se copian para no modificar recursos cacheados y la recarga sigue creando su propia animación de agua; los materiales de skin conservan sus referencias de actualización de huesos.

A solicitud del usuario, la cámara del telescopio se adapta al centro óptico dentro de su modelo (85 % de la altura del mesh), sin órbita de 12 m ni desplazamiento extra de 1.8 m. La orientación cambia con las flechas, pero el origen se queda fijo. Ralph se oculta mientras se usa el visor y recupera su visibilidad anterior al salir con E. Se mantienen máscara, zoom y límites angulares originales.

`Wolf::JumpAscendStep/FallStep` llaman `Mobile_Steer` con el perfil normal de 600 unidades/s; Shift no activa un turbo durante el salto. Se eliminó la rama del port que daba `run_speed` por mantener Shift en JUMP/FALL. La carrera especial RUN_AIR sigue usando su propia lógica original. `tools/test_texture_scope_and_air_input.gd` verifica bancos de texturas, cache/recarga y Shift durante ascenso/caída; `test_level01_essentials` comprueba origen óptico fijo, visibilidad y cierre real del telescopio. Ambos pasan con **0 fallos**. Capturas: [Ralph corregido](level01_ralph_atlas_corrected.png), [vista óptica](level01_telescope_optical_view.png).
