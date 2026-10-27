# Ayudas de cámara compartidas y configurables

OriginalCameraZones es independiente de la física de pendientes y se instala
en Level00 y todos los ImportedLevel. Consume data/camera_zones.json.
Extracción reproducible: tools/extract_camera_zones.py Levels/Lvl-00 ...
Procedencia: CameraRestriction::PostLoadInit/Update y
Camera_FollowTrajectory/Camera_ClampToTrajectory, WAR class19.

Importados los56 registros nativos y20 recorridos:
00:12 zonas/1 recorrido;01:9/3;02:14/5;03:4/2;04:4/3;05:6/6;06:7/0.
Se incluyen volúmenes XYZ, límites de ángulos/distancia/focal, desplazamiento
del objetivo y trayectorias. Se respetan arcos de yaw que cruzan0° y los
modos FOLLOW frente a registros exclusivos del robot. Los recorridos se
adaptan a un SpringArm con colisión: proyección del ojo deseado sobre sus
segmentos y conversión a ángulo/distancia. No se duplica la máquina global
de suavizado del ejecutable ni sus modos de robot todavía no implementados.

Entrada/cambio0.9s, salida1s, smootherstep sobre rotación/distancia/FOV y
desplazamiento. Al salir o desactivar vuelve a la vista libre guardada;
reentrar durante el retorno parte de la pose actual. Reset bajo iris es inmediato.
El controlador de pendientes conserva exclusivamente movimiento/poses.

Opciones -> Ayudas de cámara: Sí/No, desactivado por defecto en instalaciones nuevas; respeta preferencias guardadas. GameLocalization
persiste camera/assists en user://language.cfg sin reemplazar idioma ni
pantallas de carga. Traducciones en español/inglés/portugués/italiano.
Funciona con el menú existente de PC/web/móvil y al cambiar de nivel.

OFF libera las zonas y evita los planos opcionales de balancín, buzón,
puertas por botón, catapulta y la cámara de roca dinámica de03. Los objetos
siguen realizando sus acciones; no se elimina la cinemática de la roca que
anima objetos, solo su toma de cámara. Las cinemáticas de entrada, diálogos,
lecciones y cámaras de muerte permanecen: el ajuste solo cambia las ayudas
durante juego. La dirección del movimiento sigue usando la cámara visible.

Pruebas: test_camera_assists.gd carga los7 niveles, activa sus zonas,
prueba ON/OFF, restauración suave, opción de pausa y persistencia real en
un config temporal aislado. Comprueba caminos/arcos y que una cinemática
permanezca disponible en modo libre. Regresiones: test_level06_slopes,
test_level03_seesaw_launch y test_level05_switch_cameras.
