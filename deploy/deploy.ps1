# GridPop — publish the web build from Windows (PowerShell).
#
#   .\deploy\deploy.ps1 -Server ubuntu@203.0.113.10
#   .\deploy\deploy.ps1 -Server ubuntu@game.example.com -KeyPath $HOME\.ssh\gridpop.pem
#
# Uses only tools that ship with Windows 10/11 (tar, ssh, scp): the build is
# packed into one archive, uploaded and unpacked on the server, so a bad
# connection can never leave a half copied web root behind.

param(
    [Parameter(Mandatory = $true)]
    [string]$Server,

    [string]$KeyPath = "",
    [int]$Port = 22,
    [string]$Target = "/var/www/gridpop"
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path "build\web\index.html")) {
    throw "build\web is missing. Run: flutter build web --release --pwa-strategy=none --no-web-resources-cdn"
}

$sshArgs = @()
if ($KeyPath -ne "") {
    if (-not (Test-Path $KeyPath)) { throw "key not found: $KeyPath" }
    $sshArgs += @("-i", $KeyPath)
}
$sshArgs += @("-p", "$Port", "-o", "StrictHostKeyChecking=accept-new")

$scpArgs = @("-P", "$Port", "-o", "StrictHostKeyChecking=accept-new")
if ($KeyPath -ne "") { $scpArgs += @("-i", $KeyPath) }

$archive = Join-Path $env:TEMP "gridpop-web.tgz"

Write-Host "==> packing build/web"
tar -czf $archive -C build\web .
if ($LASTEXITCODE -ne 0) { throw "tar failed" }

Write-Host "==> uploading to $Server"
& scp @scpArgs $archive "${Server}:/tmp/gridpop-web.tgz"
if ($LASTEXITCODE -ne 0) { throw "scp failed" }

Write-Host "==> unpacking and reloading nginx"
$remoteScript = @"
set -e
sudo mkdir -p $Target
sudo chown -R `$(id -u):`$(id -g) $Target
sudo rm -rf $Target/*
tar -xzf /tmp/gridpop-web.tgz -C $Target
rm -f /tmp/gridpop-web.tgz
sudo nginx -t
sudo systemctl reload nginx
"@
& ssh @sshArgs $Server $remoteScript
if ($LASTEXITCODE -ne 0) { throw "remote deploy failed" }

Remove-Item $archive -Force -ErrorAction SilentlyContinue

Write-Host "==> done"
Write-Host "    http://$($Server.Split('@')[-1])/"
