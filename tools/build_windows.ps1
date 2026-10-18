param(
    [Parameter(Mandatory = $true)][string]$GodotPath
)
$ErrorActionPreference = 'Stop'
$projectDirectory = Split-Path -Parent $PSScriptRoot
$buildDirectory = Join-Path $projectDirectory 'builds/windows'
$archivePath = Join-Path $projectDirectory 'builds/RalphWolf-Windows-Prueba.zip'
New-Item -ItemType Directory -Force -Path $buildDirectory | Out-Null
& $GodotPath --headless --path $projectDirectory --export-release 'Windows Desktop' (Join-Path $buildDirectory 'RalphWolf.exe')
if ($LASTEXITCODE -ne 0) { throw 'La exportación falló. Revisa las plantillas y los errores de Godot.' }
& $GodotPath --headless --path $projectDirectory --script (Join-Path $PSScriptRoot 'export_engine_notices.gd') -- (Join-Path $buildDirectory 'Licencias_Godot.txt')
if ($LASTEXITCODE -ne 0) { throw 'No se pudieron generar las licencias del motor.' }
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'windows_test_readme.txt') -Destination (Join-Path $buildDirectory 'LEEME.txt')
Compress-Archive -Path (Join-Path $buildDirectory '*') -DestinationPath $archivePath -Force
Write-Output "Listo para compartir: $archivePath"
