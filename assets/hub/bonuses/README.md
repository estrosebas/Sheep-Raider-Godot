# Extras del plató original

`Scene.WAR` coloca BonusManager13 (ACBONUS1/model12) y MCardManager48
(AMEMORY1/model11). Se conservan posición, rotación, STAND, colisiones nativas
y el radio ManhattanXZ de300unidades (3m). E activa cada pedestal; el texto
de acción aparece abajo, sin etiquetas sobre los objetos ni leyendas del suelo.

`BonusManager::g_bonusEntries` contiene ocho compras:

| Pack original | Imágenes | Precio |
|---|---:|---:|
| PERSO |25|1|
| DECOR |17|2|
| STORY |20|2|
| COLOR |17|1|
| TEAM |23|2|
| INTRO (guion gráfico, no vídeo)|8|3|
| Pista del nivel oculto otoño (MLT191/25)|—|3|
| Pista pasado-presente (MLT191/26)|—|3|

Los110 JPEG se extraen directamente de los seis packs SDW, usando su
directorio de24bytes (PackJpeg::Open), con nombres originales. El menú
reutiliza los iconos DAV229/230, fondo IMEMCMAP46, flechas IGLFLEC y FONT_GAME.
Las descripciones, pistas y avisos vienen de Scene.MLT191 en cuatro idiomas.
El visor conserva la proporción y sólo carga la imagen seleccionada.

Los relojes conceden puntos una vez; comprar descuenta el saldo y activa
un bit de `OriginalProgress.bonus_flags`. Los archivos antiguos sin esta
propiedad siguen funcionando y comienzan sin compras. Al cerrar el menú tras
comprar se escribe la ranura automática existente, preservando las manuales.
La tarjeta abre el menú de guardado actual con sus tres ranuras y autosave.
Las dos pistas indican rutas de niveles futuros: aquí se importa su texto,
no se implementan todavía esos mapas.

Herramientas: `extract_studio_extras.py`, `build_studio_extras.gd`.
Prueba: `test_studio_extras.gd` usa un directorio de guardado aislado.
