# Regreso de ovejas al plató

Fuente: `objects/scenesheeppanel.cpp::PostLoadInit/Update`, propiedad CIN en
0x04. En Scene.WAR vale0. La CIN0 dura14.624s, usa al Wolf14/model0 y a la
Sheep15/model4 y contiene las posiciones, orientaciones, cámara y focal1236.
Ralph alterna STAND1/STAND2/STAND3 y la oveja STAND1/WALK3. Los cues de sus
animaciones referencian los sonidos4,5,61 del Scene.SND.

`extract_studio_arrival.py DECOMP SCENE_FOLDER` extrae esos registros,
modelos, animaciones y audio sin inventar trayectorias. Después importar los
recursos y ejecutar `build_studio_arrival.gd`. La secuencia está registrada
en el catálogo de cámaras como `studio_sheep_arrival`, sin iris al terminar.
El reproductor compartido `OriginalLevelSequence` ejecuta la toma.

Antes de reemplazar el autosave de victoria, SaveFiles compara el número
actual de ovejas con el último archivo guardado. Solo si aumenta se encolan
las identidades completadas que faltaban en ese archivo. El autosave conserva
`studio_arrivals`, un campo opcional compatible con los guardados anteriores.
Así la nueva partida ganada sigue segura aunque se cierre durante la toma.

Al entrar al plató, el corral oculta las ovejas pendientes para evitar dobles,
el contador conserva la cifra anterior y cada llegada reproduce la CIN0.
Al acabar se muestra su oveja, cambia el contador y se elimina la llegada
pendiente del autosave. Las ranuras manuales quedan intactas. Repetir un nivel
ya completado no incrementa el contador ni reproduce otra llegada. Varias
llegadas pendientes se procesan sucesivamente.

La distribución del corral utiliza17 posiciones con semilla fija y separación
por mejor candidato. Todas quedan dentro del recinto563, con margen65cm de
la valla. Cada oveja tiene orientación, fase y velocidad propias, y alterna
entre los originales STAND1..4. Las posiciones son estables al refrescar la
interfaz o cambiar idioma; no se reorganiza todo el rebaño al ganar otra.

Validación: `test_studio_sheep_arrival.gd` compara guardado previo/victoria,
reproduce la toma, reinicia a mitad y comprueba confirmación persistente,
ausencia de duplicados/repeticiones y distribución de las17 ovejas. Incluye
capturas `validation/studio_sheep_arrival.png` y `studio_corral_layout.png`.
