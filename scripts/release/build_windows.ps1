param(
  [string]$Version,
  [string]$Out = "release"
)

$ErrorActionPreference = "Stop"
$Root = Resolve-Path (Join-Path $PSScriptRoot "../..")
if ([string]::IsNullOrWhiteSpace($Version)) {
  $VersionLine = Select-String -Path (Join-Path $Root "pubspec.yaml") -Pattern "^version:\s*(.+)$"
  $Version = $VersionLine.Matches.Groups[1].Value.Trim()
}

$FlutterBin = if ([string]::IsNullOrWhiteSpace($env:FLUTTER_BIN)) { "flutter" } else { $env:FLUTTER_BIN }
$DartBin = if ([string]::IsNullOrWhiteSpace($env:DART_BIN)) { "dart" } else { $env:DART_BIN }
$OutPath = Join-Path $Root $Out
$ZipPath = Join-Path $OutPath "Alembic-$Version-windows-x64.zip"
$ExePath = Join-Path $OutPath "Alembic-$Version-windows-x64.exe"

New-Item -ItemType Directory -Path $OutPath -Force | Out-Null
Remove-Item -LiteralPath $ZipPath -Force -ErrorAction SilentlyContinue
Remove-Item -LiteralPath $ExePath -Force -ErrorAction SilentlyContinue

Push-Location $Root
try {
  & $FlutterBin pub get
  & $FlutterBin build windows --release

  $BuildDir = Join-Path $Root "build/windows/x64/runner/Release"
  if (!(Test-Path (Join-Path $BuildDir "Alembic.exe"))) {
    throw "Could not find built Alembic.exe"
  }
  Compress-Archive -Path (Join-Path $BuildDir "*") -DestinationPath $ZipPath -Force

  & $DartBin pub global activate flutter_distributor
  $PubCacheBin = Join-Path $env:LOCALAPPDATA "Pub/Cache/bin"
  if (Test-Path $PubCacheBin) {
    $env:PATH = "$PubCacheBin;$env:PATH"
  }
  & flutter_distributor package --platform windows --targets exe --skip-clean
  $Installer = Get-ChildItem -Path (Join-Path $Root "dist") -Recurse -Filter "*.exe" |
    Sort-Object Length -Descending |
    Select-Object -First 1
  if ($null -eq $Installer) {
    throw "flutter_distributor did not produce an exe installer"
  }
  Copy-Item -LiteralPath $Installer.FullName -Destination $ExePath -Force
} finally {
  Pop-Location
}
