param(
    [Parameter(Mandatory=$true)][string]$HostName,
    [Parameter(Mandatory=$true)][string]$RemoteUpdatesDirectory,
    [string]$LocalUpdatesDirectory=(Join-Path $PSScriptRoot '../builds/updates'),
    [string]$IdentityFile='',
    [string]$KnownHostsFile='',
    [int]$Port=22
)
$ErrorActionPreference='Stop'
if ($HostName -notmatch '^[A-Za-z0-9_.@-]+$') { throw 'Host SSH inválido.' }
if ($RemoteUpdatesDirectory -notmatch '^/[A-Za-z0-9_./-]+/updates$' -or $RemoteUpdatesDirectory.Contains('..')) { throw 'La ruta pública absoluta debe terminar en /updates, sin espacios ni ..' }
$sshOptions=@('-o','BatchMode=yes','-o','StrictHostKeyChecking=yes','-o','ServerAliveInterval=15','-o','ServerAliveCountMax=4')
if ($IdentityFile) { $sshOptions+=@('-i',$IdentityFile) }
if ($KnownHostsFile) { $sshOptions+=@('-o',"UserKnownHostsFile=$KnownHostsFile") }
$localRoot=(Resolve-Path -LiteralPath $LocalUpdatesDirectory).Path
if (-not (Test-Path -LiteralPath (Join-Path $localRoot 'releases'))) { throw 'No hay paquetes locales.' }
# Do not overwrite immutable releases. Stable pointers are published LAST.
foreach ($manifest in Get-ChildItem -LiteralPath (Join-Path $localRoot 'stable') -Filter 'manifest.json' -Recurse -File) {
    $envelope=Get-Content -LiteralPath $manifest.FullName -Raw | ConvertFrom-Json
    $payload=[Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($envelope.payload_base64)) | ConvertFrom-Json
    $relative=[string]$payload.package.path
    if ($relative -notmatch '^releases/[A-Za-z0-9_./-]+/content.zip$' -or $relative.Contains('..')) { throw 'Ruta de paquete inválida.' }
    $localPackage=Join-Path $localRoot $relative
    $localHash=(Get-FileHash -LiteralPath $localPackage -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($localHash -ne $payload.package.sha256) { throw 'El paquete local cambió después de firmarlo.' }
    $remotePackage="$RemoteUpdatesDirectory/$relative"
    $remoteFolder=$remotePackage.Substring(0,$remotePackage.LastIndexOf('/'))
    $remoteHash=(& ssh @sshOptions -p $Port $HostName "if test -f '$remotePackage'; then sha256sum '$remotePackage'; fi")
    if ($LASTEXITCODE -ne 0) { throw 'No se pudo consultar el servidor.' }
    if ($remoteHash) {
        if (([string]$remoteHash).Split(' ')[0] -ne $localHash) { throw 'Ese número de versión ya existe en el VPS con otro contenido.' }
    } else {
        & ssh @sshOptions -p $Port $HostName "mkdir -p '$remoteFolder'"
        if ($LASTEXITCODE -ne 0) { throw 'No se pudo crear el destino.' }
        & scp @sshOptions -P $Port $localPackage "$($HostName):$remotePackage.next"
        if ($LASTEXITCODE -ne 0) { throw 'Subida incompleta; no se activa el manifiesto.' }
        $uploadedHash=(& ssh @sshOptions -p $Port $HostName "sha256sum '$remotePackage.next'")
        if ($LASTEXITCODE -ne 0 -or -not $uploadedHash -or ([string]$uploadedHash).Split(' ')[0] -ne $localHash) { throw 'El paquete remoto no coincide; no se activa el manifiesto.' }
        & ssh @sshOptions -p $Port $HostName "mv '$remotePackage.next' '$remotePackage'"
        if ($LASTEXITCODE -ne 0) { throw 'No se pudo activar el paquete.' }
    }
    $platform=[string]$payload.platform
    if ($platform -notin @('windows-x86_64','android-arm64')) { throw 'Plataforma inválida.' }
    & ssh @sshOptions -p $Port $HostName "mkdir -p '$RemoteUpdatesDirectory/stable/$platform'"
    if ($LASTEXITCODE -ne 0) { throw 'No se pudo crear el canal.' }
    & scp @sshOptions -P $Port $manifest.FullName "$($HostName):$RemoteUpdatesDirectory/stable/$platform/manifest.json.next"
    if ($LASTEXITCODE -ne 0) { throw 'Falló el manifiesto.' }
    & ssh @sshOptions -p $Port $HostName "mv '$RemoteUpdatesDirectory/stable/$platform/manifest.json.next' '$RemoteUpdatesDirectory/stable/$platform/manifest.json'"
    if ($LASTEXITCODE -ne 0) { throw 'No se pudo activar el manifiesto.' }
}
Write-Output 'Publicación completa: paquetes verificados, manifiestos activados al final.'
