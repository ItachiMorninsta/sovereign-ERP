#define AppName "Sovereign ERP"
#define AppVersion "1.0.0"
#define AppPublisher "Sovereign ERP"

[Setup]
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher={#AppPublisher}
DefaultDirName=C:\SovereignERP
DefaultGroupName={#AppName}
DisableProgramGroupPage=yes
OutputDir=output
OutputBaseFilename=SovereignERP-Setup
Compression=lzma2/max
SolidCompression=yes
PrivilegesRequired=admin
ArchitecturesInstallIn64BitMode=x64compatible
WizardStyle=modern
UninstallDisplayName={#AppName}

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Files]
Source: "stack\docker-compose.yml"; DestDir: "{app}"; Flags: ignoreversion
Source: "stack\config\*"; DestDir: "{app}\config"; Flags: ignoreversion recursesubdirs
Source: "stack\addons\*"; DestDir: "{app}\addons"; Flags: ignoreversion recursesubdirs
Source: "first-run.ps1"; DestDir: "{app}"; Flags: ignoreversion
Source: "open-erp.ps1"; DestDir: "{app}"; Flags: ignoreversion
Source: "lib\*"; DestDir: "{app}\lib"; Flags: ignoreversion
Source: "vendor\tailscale-setup.exe"; DestDir: "{tmp}"; Flags: deleteafterinstall
Source: "vendor\DockerDesktopInstaller.exe"; DestDir: "{tmp}"; Flags: deleteafterinstall

[Dirs]
Name: "{app}\data"

[Icons]
Name: "{autodesktop}\Open Sovereign ERP"; Filename: "powershell.exe"; Parameters: "-ExecutionPolicy Bypass -WindowStyle Hidden -File ""{app}\open-erp.ps1"""; WorkingDir: "{app}"
Name: "{group}\Uninstall Sovereign ERP"; Filename: "{uninstallexe}"

[Registry]
Root: HKLM; Subkey: "SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce"; ValueName: "SovereignERPFirstRun"; ValueType: string; ValueData: "powershell.exe -ExecutionPolicy Bypass -File ""{app}\first-run.ps1"" -InstallDir ""{app}"""; Flags: uninsdeletevalue

[UninstallRun]
Filename: "docker"; Parameters: "compose down"; WorkingDir: "{app}"; Flags: runhidden skipifdoesNotExist; RunOnceId: "StopStack"

[UninstallDelete]
Type: filesandordirs; Name: "{app}"

[Code]
var
  GlobalRebootNeeded: Boolean;

function IsRebootPending(): Boolean;
begin
  Result :=
    RegKeyExists(HKLM, 'SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending') or
    RegKeyExists(HKLM, 'SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired') or
    RegValueExists(HKLM, 'SYSTEM\CurrentControlSet\Control\Session Manager', 'PendingFileRenameOperations');
end;

procedure CurStepChanged(CurStep: TSetupStep);
var
  ResultCode: Integer;
begin
  if CurStep = ssPostInstall then
  begin
    WizardForm.StatusLabel.Caption := 'Installing Tailscale...';
    if not Exec(ExpandConstant('{tmp}\tailscale-setup.exe'), '/quiet /norestart', '', SW_HIDE, ewWaitUntilTerminated, ResultCode) then
      RaiseException('Could not launch the Tailscale installer (the bundled file is missing or was blocked).');
    if (ResultCode <> 0) and (ResultCode <> 3010) then
      RaiseException('Tailscale installation failed (code ' + IntToStr(ResultCode) + ').');
    if ResultCode = 3010 then GlobalRebootNeeded := True;

    WizardForm.StatusLabel.Caption := 'Installing Docker Desktop (enables WSL2, may take several minutes)...';
    if not Exec(ExpandConstant('{tmp}\DockerDesktopInstaller.exe'), 'install --quiet --accept-license', '', SW_HIDE, ewWaitUntilTerminated, ResultCode) then
      RaiseException('Could not launch the Docker Desktop installer (the bundled file is missing or was blocked).');
    if (ResultCode <> 0) and (ResultCode <> 3010) then
      RaiseException('Docker Desktop installation failed (code ' + IntToStr(ResultCode) + '). Common cause: virtualization disabled in BIOS/UEFI, or WSL2 could not be enabled. Enable virtualization (Intel VT-x / AMD-V) in BIOS and ensure Windows version is 10 2004+ or 11, then run setup again.');
    if ResultCode = 3010 then GlobalRebootNeeded := True;

    WizardForm.StatusLabel.Caption := 'Generating ERP passwords...';
    Exec('powershell.exe', ExpandConstant('-ExecutionPolicy Bypass -Command ". ''{app}\lib\Stack.ps1''; New-SecretFiles -InstallDir ''{app}''"'), '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
    if ResultCode <> 0 then
      RaiseException('Failed to generate ERP passwords.');

    if GlobalRebootNeeded or IsRebootPending() then
    begin
      if MsgBox('Sovereign ERP needs a restart to finish enabling Windows subsystems. Restart now? Setup continues automatically after you log back in.', mbConfirmation, MB_YESNO) = IDYES then
        Exec(ExpandConstant('{sys}\shutdown.exe'), '/r /t 5 /c "Sovereign ERP setup restart"', '', SW_HIDE, ewNoWait, ResultCode);
    end
    else
      Exec('powershell.exe', ExpandConstant('-ExecutionPolicy Bypass -File "{app}\first-run.ps1" -InstallDir "{app}"'), '', SW_SHOW, ewNoWait, ResultCode);
  end;
end;

procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
var
  ResultCode: Integer;
  DockerUninstaller: String;
begin
  if CurUninstallStep = usUninstall then
  begin
    if MsgBox('Delete the ERP database and ALL business data? Choose No to keep data for a future re-install.', mbConfirmation, MB_YESNO or MB_DEFBUTTON2) = IDYES then
      Exec('docker', 'volume rm sovereign-ERP_odoo-db-data sovereign-ERP_odoo-web-data', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
    DockerUninstaller := ExpandConstant('{commonpf64}\Docker\Docker\Docker Desktop Installer.exe');
    if FileExists(DockerUninstaller) then
      Exec(DockerUninstaller, 'uninstall --quiet', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
  end;
end;
