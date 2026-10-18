# Copia editable del arbusto original

Punto de partida: bush_world, sin la variante de lóbulos ni shaders nuevos.
Contiene copias independientes de geometría, animaciones, datos y texturas.
Las referencias internas apuntan a esta carpeta. El disfraz correspondiente
está en bush_custom_disguise. Editar aquí conserva intactos bush_world y
bush_disguise, utilizados por el nivel 02.

En el laboratorio: COPIA PARA EDITAR, junto a ORIGINAL. La copia ahora añade
una cubierta interior de 36 triángulos (30 en el disfraz), construida desde
los vértices originales. Conserva las superficies nativas y los huesos de
cada vértice; la cubierta queda ligeramente por dentro para mantener los
bordes pintados. Las UV se proyectan desde caras originales evitando el
negro/transparencia de los bordes del atlas. No cambia las interacciones.

Regeneración: python tools/close_bush_copy.py y Godot --headless --path .
--script tools/build_bush_copy.gd. Es un prototipo de cierre: la cubierta
convexa simplifica entrantes y su textura puede estirarse entre caras.
