; Windows 安装包（Inno Setup 6）。CI 里这样调用：
;   iscc /DAppVersion=0.2.0 /DSourceDir=<Flutter Release 目录> /DCliExe=<yetease.exe> /DOutputDir=<输出目录> yetease.iss
; 开始菜单与桌面快捷方式：中文系统显示「网易云音乐Yet」，其他语言显示 "YetEase Music"。

#ifndef AppVersion
  #define AppVersion "0.0.0"
#endif

[Setup]
AppId={{7C5E3A42-9E1B-4C3F-9D6B-2F4A8E1C0B77}
AppName=YetEase Music
AppVersion={#AppVersion}
AppVerName=YetEase Music {#AppVersion}
AppPublisher=YetEase Music
AppPublisherURL=https://github.com/Gloridust/YetEaseMusic
AppSupportURL=https://github.com/Gloridust/YetEaseMusic/issues
DefaultDirName={autopf}\YetEase Music
DefaultGroupName=YetEase Music
DisableProgramGroupPage=yes
OutputDir={#OutputDir}
OutputBaseFilename=yetease-music-{#AppVersion}-windows-x64-setup
SetupIconFile=..\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\yetease-music.exe
Compression=lzma2/max
SolidCompression=yes
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
PrivilegesRequiredOverridesAllowed=dialog
WizardStyle=modern
LicenseFile=..\..\..\LICENSE

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"
; 部分 Inno Setup 版本才自带简体中文翻译，没有时只用英文界面
#if FileExists(AddBackslash(CompilerPath) + "Languages\ChineseSimplified.isl")
Name: "chinesesimplified"; MessagesFile: "compiler:Languages\ChineseSimplified.isl"
#endif

[CustomMessages]
english.AppDisplayName=YetEase Music
#if FileExists(AddBackslash(CompilerPath) + "Languages\ChineseSimplified.isl")
chinesesimplified.AppDisplayName=网易云音乐Yet
#endif

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

[Files]
Source: "{#SourceDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "{#CliExe}"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{group}\{cm:AppDisplayName}"; Filename: "{app}\yetease-music.exe"
Name: "{autodesktop}\{cm:AppDisplayName}"; Filename: "{app}\yetease-music.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\yetease-music.exe"; Description: "{cm:LaunchProgram,{cm:AppDisplayName}}"; Flags: nowait postinstall skipifsilent
