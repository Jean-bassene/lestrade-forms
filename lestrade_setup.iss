; Lestrade Forms — Script Inno Setup
; Genere pour le build Desktop Windows

#define AppName "Lestrade Forms"
#define AppVersion "1.0.0"
#define AppPublisher "Caritas"
#define AppDir "c:\Projets\CaritasR\enquete\LestradeApp"
#define OutputDir "c:\Projets\CaritasR\enquete\installer_output"

[Setup]
AppName={#AppName}
AppVersion={#AppVersion}
AppVerName={#AppName} {#AppVersion}
AppPublisher={#AppPublisher}
AppId={{8F3A2D1E-4B5C-6D7E-8F9A-0B1C2D3E4F5A}
DefaultDirName={autopf}\{#AppName}
DefaultGroupName={#AppName}
OutputDir={#OutputDir}
OutputBaseFilename=Lestrade_Forms_Setup_v{#AppVersion}
SetupIconFile={#AppDir}\app_icon.ico
UninstallDisplayIcon={app}\app_icon.ico
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog
DisableProgramGroupPage=yes
CloseApplications=no
ShowLanguageDialog=no
MinVersion=6.1

[Languages]
Name: "french"; MessagesFile: "compiler:Languages\French.isl"

[Tasks]
Name: "desktopicon"; Description: "Raccourci sur le &bureau"; GroupDescription: "Raccourcis supplementaires:";

[Files]
; Application Shiny
Source: "{#AppDir}\inst\app\*"; DestDir: "{app}\app"; Flags: ignoreversion recursesubdirs createallsubdirs
; Launcher et donnees
Source: "{#AppDir}\launcher.R"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#AppDir}\Lestrade Forms.bat"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#AppDir}\inst\extdata\questionnaires_empty.db"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#AppDir}\app_icon.ico"; DestDir: "{app}"; Flags: ignoreversion
; R-Portable complet avec tous les packages
Source: "{#AppDir}\R-Portable\*"; DestDir: "{app}\R-Portable"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#AppName}"; Filename: "{app}\Lestrade Forms.bat"; WorkingDir: "{app}"; IconFilename: "{app}\app_icon.ico"
Name: "{group}\Desinstaller {#AppName}"; Filename: "{uninstallexe}"
Name: "{commondesktop}\{#AppName}"; Filename: "{app}\Lestrade Forms.bat"; WorkingDir: "{app}"; IconFilename: "{app}\app_icon.ico"; Tasks: desktopicon

[Run]
Filename: "{app}\Lestrade Forms.bat"; Description: "Lancer {#AppName} maintenant"; Flags: nowait postinstall skipifsilent shellexec

[UninstallDelete]
Type: filesandordirs; Name: "{app}"

[Code]
procedure InitializeWizard();
begin
  WizardForm.WelcomeLabel2.Caption :=
    'Lestrade Forms est une application de collecte de donnees terrain pour Caritas.' + #13#10 +
    '- Fonctionne sans connexion internet' + #13#10 +
    '- Synchronisation via panier (Google Sheets)' + #13#10 +
    '- Compatible avec l''application mobile Lestrade' + #13#10 +
    'Aucune installation de R n''est necessaire.';
end;
