param([Parameter(Mandatory = $true)][string]$GodotPath)
$ErrorActionPreference = 'Stop'
$projectDirectory = Split-Path -Parent $PSScriptRoot
$webDirectory = Join-Path $projectDirectory 'builds/web'
New-Item -ItemType Directory -Force -Path $webDirectory | Out-Null
& $GodotPath --headless --path $projectDirectory --export-release Web (Join-Path $webDirectory 'index.html')
if ($LASTEXITCODE -ne 0) { throw 'La exportación web falló. Revisa los errores de Godot.' }
# Select this export explicitly: never include a previous ZIP or stale exports.
$webFiles = Get-ChildItem -LiteralPath $webDirectory -File | Where-Object { $_.Name -like 'index.*' -and $_.Name -notlike '*.import' }
Compress-Archive -LiteralPath $webFiles.FullName -DestinationPath (Join-Path $projectDirectory 'builds/RalphWolf-Web.zip') -Force
Write-Output 'Listo: builds/RalphWolf-Web.zip. Sube su contenido completo a la raíz de la página.'
