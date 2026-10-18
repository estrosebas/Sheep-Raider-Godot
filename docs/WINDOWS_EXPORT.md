# Exportar una prueba para Windows

El proyecto utiliza Godot **4.7.2**. Instala las plantillas de la misma versión
en **Editor → Administrar plantillas de exportación**.

En **Proyecto → Exportar**, selecciona el preset **Windows Desktop** y pulsa
**Exportar proyecto**. Desactiva la exportación de depuración para una prueba
normal. El preset incluye los JSON que los niveles cargan por código y excluye
videos, herramientas y exportaciones previas. Mantén esos filtros.

Con `binary_format/embed_pck=true`, los recursos están dentro del ejecutable.
Para compartir, incluye también las instrucciones y las licencias del motor.
No compartas la carpeta del repositorio ni tus guardados personales.

El proceso completo, incluyendo ZIP, se puede repetir desde PowerShell:

```powershell
.\tools\build_windows.ps1 -GodotPath 'C:\ruta\a\Godot_v4.7.2-stable_win64_console.exe'
```

El resultado es `builds/RalphWolf-Windows-Prueba.zip`.
El destinatario descomprime todo y abre `RalphWolf.exe`.
En el escenario, F8 abre el laboratorio para probar las puertas de los niveles
00–03 sin esperar a desbloquearlas mediante la campaña.

Validación de recursos empaquetados (desde la carpeta del ejecutable):

```powershell
& 'C:\ruta\a\Godot_v4.7.2-stable_win64_console.exe' --headless --main-pack .\RalphWolf.exe --script 'C:\ruta\al\proyecto\tools\test_windows_export.gd'
```

Esta prueba utiliza guardados y configuración temporales, carga las siete
escenas principales, los cuatro idiomas y los segmentos del catálogo musical.
El ejecutable de lanzamiento también debe comprobarse por separado.

Referencia: https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_windows.html
