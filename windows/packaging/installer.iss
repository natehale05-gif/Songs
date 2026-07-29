; Inno Setup script for the Songs of the Church Windows installer.
; Built in CI with:
;   ISCC /DAppVersion=1.0.0 windows\packaging\installer.iss
;
; PrivilegesRequired=lowest installs per-user under %LOCALAPPDATA%, so the
; installer runs without a UAC prompt — one less hurdle on first launch.

#ifndef AppVersion
  #define AppVersion "1.0.0"
#endif

#define AppName "Songs of the Church"
#define AppExe "songs_of_the_church.exe"

[Setup]
AppId={{8B1F4A62-6C2E-4E3D-9E0B-5B7A2C9D41F7}
AppName={#AppName}
AppVersion={#AppVersion}
AppVerName={#AppName} {#AppVersion}
AppPublisher=Songs of the Church
DefaultDirName={autopf}\Songs of the Church
DefaultGroupName={#AppName}
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
OutputDir=..\..\dist
OutputBaseFilename=songs-of-the-church-windows-setup
SetupIconFile=..\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\{#AppExe}
Compression=lzma2
SolidCompression=yes
WizardStyle=modern

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "Create a &desktop shortcut"; GroupDescription: "Additional shortcuts:"

[Files]
Source: "..\..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; \
  Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#AppName}"; Filename: "{app}\{#AppExe}"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\{#AppExe}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#AppExe}"; Description: "Launch {#AppName}"; \
  Flags: nowait postinstall skipifsilent
