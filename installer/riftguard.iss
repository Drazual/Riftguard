; Windows installer for the Godot build. godot.yml compiles it with Inno Setup after the export:
;   iscc /DAppVersion=<version> installer/riftguard.iss
; It installs for the current user only (no admin prompt), into %LOCALAPPDATA%\Programs\Riftguard, so the
; game's self-updater can swap the exe without admin rights. It always adds a desktop and a Start menu shortcut.

#ifndef AppVersion
  #define AppVersion "0.0.0"
#endif

[Setup]
; Never change AppId: Windows uses it to tell this install apart from others, and updates from new ones.
AppId={{6F1C2E7A-3B8D-4C52-9A1E-52D4F0B7C9E3}
AppName=Riftguard
AppVersion={#AppVersion}
AppPublisher=Drazual
AppPublisherURL=https://github.com/Drazual/riftguard
DefaultDirName={autopf}\Riftguard
DefaultGroupName=Riftguard
PrivilegesRequired=lowest
DisableProgramGroupPage=yes
DisableDirPage=yes
DisableReadyPage=yes
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
UninstallDisplayIcon={app}\Riftguard.exe
UninstallDisplayName=Riftguard
OutputDir=..\godot\build
OutputBaseFilename=Riftguard-setup
Compression=lzma2
SolidCompression=yes
WizardStyle=modern

[Files]
Source: "..\godot\build\Riftguard.exe"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{autodesktop}\Riftguard"; Filename: "{app}\Riftguard.exe"; WorkingDir: "{app}"
Name: "{autoprograms}\Riftguard"; Filename: "{app}\Riftguard.exe"; WorkingDir: "{app}"

[Run]
Filename: "{app}\Riftguard.exe"; Description: "Play Riftguard"; Flags: nowait postinstall skipifsilent

[UninstallDelete]
; Left behind by the self-updater while it swaps versions.
Type: files; Name: "{app}\Riftguard.exe.old"
Type: files; Name: "{app}\Riftguard.exe.new"
