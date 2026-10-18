# Exportación web

En Godot: **Proyecto → Exportar → Web → Exportar proyecto**.
El destino predeterminado es `builds/web/index.html`. El preset utiliza
`web/shell.html`, la ilustración del proyecto y los filtros para los JSON.
No necesitas compilar Godot desde su código fuente.

Para exportar y preparar el ZIP de alojamiento desde PowerShell:

```powershell
.\tools\build_web.ps1 -GodotPath 'C:\ruta\a\Godot_v4.7.2-stable_win64_console.exe'
```

El archivo `builds/RalphWolf-Web.zip` contiene únicamente los archivos de esta
exportación. Descomprímelos directamente en la raíz pública del subdominio,
con `index.html` junto a `index.js`, `index.wasm`, `index.pck` y las imágenes
y módulos de audio generados. Actualiza el conjunto completo, no solo el HTML.

El cargador muestra el progreso real de descarga y después la preparación del
escenario. Presenta los errores de inicio en pantalla. Evita utilizar versiones
antiguas del motor guardadas en caché, incluso con políticas largas para JS.
Los recursos del motor se revalidan durante el arranque; el fetch normal del
navegador se restaura una vez que arranca el juego.

Si tenías abierta una versión anterior, recarga con Ctrl+F5 después de subir
la nueva. No hace falta borrar las partidas del navegador.

Para probar localmente, sirve `builds/web` mediante HTTP. Abrir el HTML con doble
clic no equivale a una página alojada en un servidor. En web, pulsa dentro del
juego para capturar el ratón después de la pantalla de idioma.

En web, el sigilo se hace manteniendo **C**. En Windows se conserva **Ctrl**.
Las indicaciones del tutorial y el laboratorio consultan la tecla asignada.
Los atajos reservados del navegador no se pueden bloquear de forma universal;
Ctrl+W puede cerrar una pestaña aunque el juego tenga capturado el ratón.
En pantalla completa, la plantilla solicita Keyboard Lock para las teclas
de juego en los navegadores compatibles. Al salir, libera la captura. Si el
navegador no lo permite, el sigilo con C sigue disponible; Escape y los atajos
del sistema operativo permanecen accesibles.

Referencias oficiales: [exportación web](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_web.html),
[plantilla HTML personalizada](https://docs.godotengine.org/en/stable/tutorials/platform/web/customizing_html5_shell.html).
