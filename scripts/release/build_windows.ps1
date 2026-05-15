param(
  [string]$Version,
  [string]$Out = "release",
  [switch]$SkipInstaller
)

$ErrorActionPreference = "Stop"
$Root = Resolve-Path (Join-Path $PSScriptRoot "../..")
if ([string]::IsNullOrWhiteSpace($Version)) {
  $VersionLine = Select-String -Path (Join-Path $Root "pubspec.yaml") -Pattern "^version:\s*(.+)$"
  $Version = $VersionLine.Matches.Groups[1].Value.Trim()
}

$FlutterBin = if ([string]::IsNullOrWhiteSpace($env:FLUTTER_BIN)) { "flutter" } else { $env:FLUTTER_BIN }
$OutPath = Join-Path $Root $Out
$ZipPath = Join-Path $OutPath "Alembic-$Version-windows-x64.zip"
$ExePath = Join-Path $OutPath "Alembic-$Version-windows-x64.exe"

function Invoke-Native {
  param(
    [string]$FilePath,
    [string[]]$Arguments
  )

  & $FilePath @Arguments
  if ($LASTEXITCODE -ne 0) {
    throw "$FilePath $($Arguments -join ' ') failed with exit code $LASTEXITCODE"
  }
}

function Write-WindowsBuildDiagnostics {
  $BuildRoot = Join-Path $Root "build/windows"
  if (!(Test-Path $BuildRoot)) {
    return
  }

  Get-ChildItem -Path $BuildRoot -Recurse -Include "CMakeError.log", "CMakeOutput.log" -ErrorAction SilentlyContinue |
    ForEach-Object {
      Write-Host "==== $($_.FullName) ===="
      Get-Content -Path $_.FullName -Tail 200
    }
}

function Get-InnoSetupCompiler {
  if (![string]::IsNullOrWhiteSpace($env:INNO_SETUP_COMPILER)) {
    if (Test-Path $env:INNO_SETUP_COMPILER) {
      return $env:INNO_SETUP_COMPILER
    }
    throw "INNO_SETUP_COMPILER points to a missing file: $env:INNO_SETUP_COMPILER"
  }

  $Command = Get-Command "iscc.exe" -ErrorAction SilentlyContinue
  if ($null -ne $Command) {
    return $Command.Source
  }

  $Candidates = @()
  $ProgramFilesX86 = [Environment]::GetEnvironmentVariable("ProgramFiles(x86)")
  if (![string]::IsNullOrWhiteSpace($ProgramFilesX86)) {
    $Candidates += Join-Path $ProgramFilesX86 "Inno Setup 6/ISCC.exe"
  }
  if (![string]::IsNullOrWhiteSpace($env:ProgramFiles)) {
    $Candidates += Join-Path $env:ProgramFiles "Inno Setup 6/ISCC.exe"
  }

  foreach ($Candidate in $Candidates) {
    if (Test-Path $Candidate) {
      return $Candidate
    }
  }

  throw "Could not find Inno Setup compiler. Install Inno Setup or set INNO_SETUP_COMPILER."
}

function Write-InnoSetupScript {
  param(
    [string]$BuildDir,
    [string]$OutputDir,
    [string]$OutputBaseName
  )

  $ScriptDir = Join-Path $Root "build/release/windows"
  $ScriptPath = Join-Path $ScriptDir "Alembic.iss"
  $IconPath = Join-Path $Root "windows/runner/resources/app_icon.ico"
  $ResolvedBuildDir = (Resolve-Path $BuildDir).Path
  $ResolvedOutputDir = (Resolve-Path $OutputDir).Path
  $ResolvedIconPath = (Resolve-Path $IconPath).Path

  New-Item -ItemType Directory -Path $ScriptDir -Force | Out-Null
  @"
[Setup]
AppId={{8A7D6F09-7F5C-4E41-8B39-A01A87E78D41}
AppName=Alembic
AppVersion=$Version
AppPublisher=Arcane Arts
DefaultDirName={localappdata}\Programs\Alembic
DefaultGroupName=Alembic
DisableProgramGroupPage=yes
OutputDir=$ResolvedOutputDir
OutputBaseFilename=$OutputBaseName
SetupIconFile=$ResolvedIconPath
UninstallDisplayIcon={app}\Alembic.exe
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64
ArchitecturesInstallIn64BitMode=x64
PrivilegesRequired=lowest

[Files]
Source: "$ResolvedBuildDir\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\Alembic"; Filename: "{app}\Alembic.exe"

[Run]
Filename: "{app}\Alembic.exe"; Description: "Launch Alembic"; Flags: nowait postinstall skipifsilent
"@ | Set-Content -LiteralPath $ScriptPath -Encoding UTF8

  return $ScriptPath
}

New-Item -ItemType Directory -Path $OutPath -Force | Out-Null
Remove-Item -LiteralPath $ZipPath -Force -ErrorAction SilentlyContinue
Remove-Item -LiteralPath $ExePath -Force -ErrorAction SilentlyContinue

Push-Location $Root
try {
  Invoke-Native $FlutterBin @("pub", "get")
  Remove-Item -LiteralPath (Join-Path $Root "build/windows") -Recurse -Force -ErrorAction SilentlyContinue
  $BuildArguments = @("build", "windows", "--release")
  if (![string]::IsNullOrWhiteSpace($env:ALEMBIC_BUILD_ID)) {
    $BuildArguments += "--dart-define=ALEMBIC_BUILD_ID=$env:ALEMBIC_BUILD_ID"
  }
  try {
    Invoke-Native $FlutterBin $BuildArguments
  } catch {
    Write-WindowsBuildDiagnostics
    throw
  }

  $BuildDir = Join-Path $Root "build/windows/x64/runner/Release"
  if (!(Test-Path (Join-Path $BuildDir "Alembic.exe"))) {
    throw "Could not find built Alembic.exe"
  }
  Compress-Archive -Path (Join-Path $BuildDir "*") -DestinationPath $ZipPath -Force

  if ($SkipInstaller) {
    return
  }

  $InnoCompiler = Get-InnoSetupCompiler
  $OutputBaseName = "Alembic-$Version-windows-x64"
  $InstallerScript = Write-InnoSetupScript -BuildDir $BuildDir -OutputDir $OutPath -OutputBaseName $OutputBaseName
  Invoke-Native $InnoCompiler @($InstallerScript)
  if (!(Test-Path $ExePath)) {
    throw "Inno Setup did not produce $ExePath"
  }
} finally {
  Pop-Location
}
