{$I PLUGIN_DEFINES.INC}

library torrents;

uses
  FastMM4,
  FastMove,
  FastCode,
  Windows,
  SysUtils,
  Classes,
  Forms,
  Controls,
  DateUtils,
  SyncObjs,
  Dialogs,
  StrUtils,
  TNTClasses,
  TNTSysUtils,
  SuperObject,
  WinInet,
  ShlObj,
  misc_utils_unit,
  configformunit in 'configformunit.pas',
  torrents_api in 'torrents_api.pas';

{$R *.res}

Type
  TDownloadItemList =
  Record
    dlItems      : PChar;
    // Format:
    // Each entry contains multiple parameters (listed below).
    // Entries are separated by the "|" character.
    // Any use of the quote character must be encoded as "&quot".
    // "FileName=[FileName]","FilePath=[FilePath]","Progress=[Progress]","CanErase=[CanErase]","CanStop=[CanErase]"|"FileName=[FileName]","FilePath=[FilePath]","Progress=[Progress]","CanErase=[CanErase]","CanStop=[CanErase]"|etc...
    //
    // Values:
    // [ID]         : A method for the download plugin to later identify specific entries, in our case Hash,FileID
    // [Title]      : A title to display to the end user, if not specified the file name is shown
    // [FileName]   : The file's name with no path!
    // [FilePath]   : The file's relative path (e.g. "Pictures\December\").
    // [FileDate]   : The file's date (if available, in Delphi's TDateTime floating point time format)
    // [FileSize]   : The file's size in bytes (if available)
    // [Progress]   : A floating point value from 0 to 100 (e.g. "50.52").
    // [Duration]   : A media file's duration (if available)
    // [CanErase]   : 0 = No, 1 = Yes (used with the EraseDownload function).
    // [CanStop]    : 0 = No, 1 = Yes (used with the StopDownload function).
    // [Playable]   : 0 = No, 1 = Yes (return the best value based on your understanding of the file format being downloaded)
    // [Priority]   : The file/torrent's priority as it should display to the end user
  End;
  PDownloadItemList = ^TDownloadItemList;


Const
  PluginRegKey                     : String = 'Software\VirtuaMedia\ZoomPlayer\DownloadPlugins\Torrents';
  RegKey_qBitTorrentPort           : String = 'qBitTorrentPort';
  RegKey_qBitTorrentEnabled        : String = 'qBitTorrentEnabled';
  RegKey_qBitTorrentDLFolder       : String = 'qBitTorrentDLFolder';
  RegKey_qBitTorrentSkipFiles      : String = 'qBitTorrentSkipFiles';
  RegKey_qBitTorrentSkipDND        : String = 'qBitTorrentSkipDND';
  RegKey_qBitTorrentDLSpeed        : String = 'qBitTorrentDLSpeed';
  RegKey_qBitTorrentULSpeed        : String = 'qBitTorrentULSpeed';
  RegKey_qBittorrentRequireAtStart : String = 'qBitTorrentRequireAtStart';
  RegKey_qBittorrentRequireAtEnd   : String = 'qBitTorrentRequireAtEnd';

  qBittorrentPath                  : String = 'qBittorrent\';
  qBittorrentEXE                   : String = 'qbittorrent.exe';


var
  qBitTorrentEnabled   : Boolean    = True;
  qBitTorrentPort      : Integer    = 8080;
  qBitFileList         : TList      = nil;
  qBitTorrentList      : TList      = nil;
  qBitItemListCache    : WideString = '';


// Called by Zoom Player to free any resources allocated in the DLL prior to unloading the DLL.
// Keep this function light, it slows down Zoom Player's closing time.
Procedure FreePlugin; stdcall;
begin
  {$IFDEF LOCALTRACE}DebugMsgFT(logPath,'Free Plugin (before)');{$ENDIF}
  If qBitFileList <> nil then
  Begin
    qBitTorrent_ClearItemList(qBitFileList);
    qBitFileList.Free;
  End;
  If qBitTorrentList <> nil then
  Begin
    qBitTorrent_ClearTorrentList(qBitTorrentList);
    qBitTorrentList.Free;
  End;
  {$IFDEF LOCALTRACE}DebugMsgFT(logPath,'Free Plugin (after)'+CRLF);{$ENDIF}

  {$IFDEF TRACEDEBUGMEMORY}
  FinalizeDebugList;
  {$ENDIF}
end;


// Called by Zoom Player to init any resources.
// Keep this function light, it slows down Zoom Player's launch time.
function InitPlugin : Bool; stdcall;
var
  I : Integer;
begin
  {$IFDEF LOCALTRACE}DebugMsgFT(logPath,'Init Plugin (before)');{$ENDIF}
  // Read Registery value
  I := GetRegDWord(HKEY_CURRENT_USER,PluginRegKey,RegKey_qBitTorrentEnabled);
  If I > -1 then qBitTorrentEnabled := Boolean(I);
  I := GetRegDWord(HKEY_CURRENT_USER,PluginRegKey,RegKey_qBitTorrentPort);
  If I > -1 then qBitTorrentPort    := I;
  I := GetRegDWord(HKEY_CURRENT_USER,PluginRegKey,RegKey_qBitTorrentDLSpeed);
  If I > -1 then qBitTorrentDLSpeed    := I;
  I := GetRegDWord(HKEY_CURRENT_USER,PluginRegKey,RegKey_qBitTorrentULSpeed);
  If I > -1 then qBitTorrentULSpeed    := I;
  qBitTorrentDLFolder := UTF8Decode(GetRegString(HKEY_CURRENT_USER,PluginRegKey,RegKey_qBitTorrentDLfolder));
  I := GetRegDWord(HKEY_CURRENT_USER,PluginRegKey,RegKey_qBitTorrentSkipFiles);
  If I > -1 then qBitTorrentSkipFiles := Boolean(I);
  I := GetRegDWord(HKEY_CURRENT_USER,PluginRegKey,RegKey_qBitTorrentSkipDND);
  If I > -1 then qBitTorrentSkipDND := Boolean(I);
  I := GetRegDWord(HKEY_CURRENT_USER,PluginRegKey,RegKey_qBittorrentRequireAtStart);
  If I > -1 then qBittorrentRequireAtStart := I/1000;
  I := GetRegDWord(HKEY_CURRENT_USER,PluginRegKey,RegKey_qBittorrentRequireAtEnd);
  If I > -1 then qBittorrentRequireAtEnd := I/1000;

  qBitReferer := 'http://'+strLocalHost+':'+IntToStr(qBitTorrentPort)+'/';

  Result := True;
  {$IFDEF LOCALTRACE}DebugMsgFT(logPath,'Init Plugin (after)'+CRLF);{$ENDIF}
end;


// Download a new Item
Function DownloadItem(ItemName : PChar) : Integer; stdcall;
var
  qBittorrentRunning : Boolean;
  sInstallPath       : WideString;
  sEXEPath           : WideString;
  iCount             : Integer;
begin
  {$IFDEF LOCALTRACE}DebugMsgFT(logPath,'DownloadItem "'+ItemName+'" (before)');{$ENDIF}
  Result := E_FAIL;
  qBittorrentRunning := processExists(qBittorrentEXE);
  If qBittorrentRunning = True then
  Begin
    qBitTorrent_DownloadTorrent(strLocalHost,qBitTorrentPort,String(ItemName));
    Result := S_OK;
  End
    else
  Begin
    If MessageDLG('qBittorrent is not currently running.'#10#10'Would you like to start it now?',mtConfirmation,[mbok,mbcancel],0) = mrOK then
    Begin
      sInstallPath := GetRegString(HKEY_LOCAL_MACHINE,'software\qBittorrent','InstallLocation');
      sEXEPath     := AddBackSlash(sInstallPath)+qBittorrentEXE;
      If WideFileExists(sEXEPath) = True then
      Begin
        {$IFDEF LOCALTRACE}DebugMsgFT(logPath,'Running qBitTorrent');{$ENDIF}
        WinExecAndWait32(sEXEPath,SW_NORMAL,False,False);
        iCount := 0;
        While (processExists(qBittorrentEXE) = False) and (iCount < 10) do
        Begin
          Sleep(500);
          Inc(iCount);
        End;
        If iCount < 10 then
        Begin
          {$IFDEF LOCALTRACE}DebugMsgFT(logPath,'qBitTorrent is running now');{$ENDIF}
          Result := DownloadItem(ItemName);
        End
          else
        Begin
          {$IFDEF LOCALTRACE}DebugMsgFT(logPath,'Timed out trying to wait for qBitTorrent to run.');{$ENDIF}
        End;
      End
        else
      Begin
        {$IFDEF LOCALTRACE}DebugMsgFT(logPath,'qBitTorrent was not found at "'+sEXEPath+'"');{$ENDIF}
        MessageDLG(qBittorrentEXE+' was not found!',mtError,[mbok],0);
      End;
    End;
    {$IFDEF LOCALTRACE}DebugMsgFT(logPath,'qBitTorrent is not running!');{$ENDIF}
  End;
  {$IFDEF LOCALTRACE}DebugMsgFT(logPath,'DownloadItem (after)');{$ENDIF}
end;


// Stop a download
Function StopDownload(ItemID : PChar) : Integer; stdcall;
var
  sHash      : String;
  iFileIndex : Integer;
begin
  {$IFDEF LOCALTRACE}DebugMsgFT(logPath,'StopDownload "'+ItemID+'" (before)');{$ENDIF}
  Result  := E_FAIL;
  qBitTorrent_ItemID_to_HashAndFileID(DecodeTextTags(UTF8Decode(ItemID),True),iFileIndex,sHash);
  {$IFDEF LOCALTRACE}DebugMsgFT(logPath,'Torrent Hash : '+sHash);{$ENDIF}
  If (iFileIndex > -1) and (sHash <> '') then
  Begin
    qBitTorrent_PauseTorrent(strLocalHost,qBitTorrentPort,sHash);
    Result := S_OK;
  End;
  {$IFDEF LOCALTRACE}DebugMsgFT(logPath,'StopDownload (after)'+CRLF);{$ENDIF}
end;


// Resume a download
Function ResumeDownload(ItemID : PChar) : Integer; stdcall;
var
  sHash      : String;
  iFileIndex : Integer;
begin
  {$IFDEF LOCALTRACE}DebugMsgFT(logPath,'StopDownload "'+ItemID+'" (before)');{$ENDIF}
  Result  := E_FAIL;
  qBitTorrent_ItemID_to_HashAndFileID(DecodeTextTags(UTF8Decode(ItemID),True),iFileIndex,sHash);
  {$IFDEF LOCALTRACE}DebugMsgFT(logPath,'Torrent Hash : '+sHash);{$ENDIF}
  If (iFileIndex > -1) and (sHash <> '') then
  Begin
    qBitTorrent_ResumeTorrent(strLocalHost,qBitTorrentPort,sHash);
    Result := S_OK;
  End;
  {$IFDEF LOCALTRACE}DebugMsgFT(logPath,'StopDownload (after)'+CRLF);{$ENDIF}
end;


// Erase a download
Function EraseDownload(ItemID : PChar) : Integer; stdcall;
var
  sHash      : String;
  iFileIndex : Integer;
begin
  {$IFDEF LOCALTRACE}DebugMsgFT(logPath,'EraseDownload "'+ItemID+'" (before)');{$ENDIF}
  Result  := E_FAIL;
  qBitTorrent_ItemID_to_HashAndFileID(DecodeTextTags(UTF8Decode(ItemID),True),iFileIndex,sHash);
  {$IFDEF LOCALTRACE}DebugMsgFT(logPath,'Torrent Hash : '+sHash);{$ENDIF}
  If (iFileIndex > -1) and (sHash <> '') then
  Begin
    QBitTorrent_EraseTorrent(strLocalHost,qBitTorrentPort,sHash);
    Result := S_OK;
  End;
  {$IFDEF LOCALTRACE}DebugMsgFT(logPath,'EraseDownload (after)'+CRLF);{$ENDIF}
end;


// Verify that the download item is supported by this plugin
Function SupportedDownload(ItemName : PChar) : Bool; stdcall;
var
  FileName : WideString;
  fExt     : String;
begin
  {$IFDEF LOCALTRACE}DebugMsgFT(logPath,'SupportedDownload "'+ItemName+'" (before)');{$ENDIF}
  Result := False;
  FileName := TNT_WideLowercase(UTF8Decode(ItemName));
  fExt := WideExtractFileExt(FileName);
  If (fExt = '.torrent') or (Pos('magnet:',FileName) = 1) or (Pos('.torrent?',FileName) > 0) then Result := True;
  {$IFDEF LOCALTRACE}DebugMsgFT(logPath,'SupportedDownload result : '+BoolToStr(Result,True)+CRLF);{$ENDIF}
end;


// Increase download priority
Function IncreasePriority(ItemID : PChar) : Integer; stdcall;
var
  sHash      : String;
  iFileIndex : Integer;
begin
  {$IFDEF LOCALTRACE}DebugMsgFT(logPath,'IncreasePriority "'+ItemID+'" (before)');{$ENDIF}
  Result  := E_FAIL;
  If qBitFileList <> nil then
  Begin
    qBitTorrent_ItemID_to_HashAndFileID(DecodeTextTags(UTF8Decode(ItemID),True),iFileIndex,sHash);
    {$IFDEF LOCALTRACE}DebugMsgFT(logPath,'File Index   : '+IntToStr(iFileIndex));{$ENDIF}
    {$IFDEF LOCALTRACE}DebugMsgFT(logPath,'Torrent Hash : '+sHash);{$ENDIF}
    If (iFileIndex > -1) and (sHash <> '') then
    Begin
      QBitTorrent_IncreaseFilePriority(strLocalHost,qBitTorrentPort,iFileIndex,sHash,qBitFileList);
      Result := S_OK;
    End;
  End;
  {$IFDEF LOCALTRACE}DebugMsgFT(logPath,'IncreasePriority (after)'+CRLF);{$ENDIF}
end;


// Decrease download priority
Function DecreasePriority(ItemID : PChar) : Integer; stdcall;
var
  sHash      : String;
  iFileIndex : Integer;
begin
  {$IFDEF LOCALTRACE}DebugMsgFT(logPath,'DecreasePriority "'+ItemID+'" (before)');{$ENDIF}
  Result  := E_FAIL;
  If qBitFileList <> nil then
  Begin
    qBitTorrent_ItemID_to_HashAndFileID(DecodeTextTags(UTF8Decode(ItemID),True),iFileIndex,sHash);
    {$IFDEF LOCALTRACE}DebugMsgFT(logPath,'File Index   : '+IntToStr(iFileIndex));{$ENDIF}
    {$IFDEF LOCALTRACE}DebugMsgFT(logPath,'Torrent Hash : '+sHash);{$ENDIF}
    If (iFileIndex > -1) and (sHash <> '') then
    Begin
      QBitTorrent_DecreaseFilePriority(strLocalHost,qBitTorrentPort,iFileIndex,sHash,qBitFileList);
      Result := S_OK;
    End;
  End;
  {$IFDEF LOCALTRACE}DebugMsgFT(logPath,'DecreasePriority (after)'+CRLF);{$ENDIF}
end;


// Get an item list of all Items available to the plugin
Function GetItemList(ItemList : PDownloadItemList; AbortFlag : PBoolean) : Integer; stdcall;
{$IFDEF LOCALTRACESTRESS}
const
  StressTestAmount : Integer = 6;
{$ENDIF}
var
  I         : Integer;
  sItemList : WideString;
  sUTF8     : String;
  iLen      : Integer;
  mStream   : TMemoryStream;
Begin
  {$IFDEF LOCALTRACE}DebugMsgFT(logPath,'GetList (before)');{$ENDIF}
  Result := E_FAIL;
  mStream := TMemoryStream.Create;

  If qBitTorrentEnabled = True then
  Begin
    If processExists(qBittorrentEXE) = True then
    Begin
      {$IFDEF LOCALTRACE}DebugMsgFT(logPath,'qBittorrent process found');{$ENDIF}
      // Get New results
      If qBitFileList    = nil then qBitFileList    := TList.Create;
      If qBitTorrentList = nil then qBitTorrentList := TList.Create;

      qBitTorrent_GetFileList(strLocalHost,qBitTorrentPort,qBitTorrentList,qBitFileList,AbortFlag);
      {$IFDEF LOCALTRACE}DebugMsgFT(logPath,'Files found : '+IntToStr(qBitFileList.Count{$IFDEF LOCALTRACESTRESS}*StressTestAmount{$ENDIF}));{$ENDIF}

      {$IFDEF LOCALTRACE}DebugMsgFT(logPath,'Generate result (before)');{$ENDIF}

      {$IFDEF LOCALTRACESTRESS}
      For iLen := 0 to StressTestAmount-1 do
        For I := 0 to (qBitFileList.Count)-1 do
      Begin
        If (I = 0) and (iLen = 0) then
          sUTF8 := UTF8Encode(QBitRecordToString(PQBitFileRecord(qBitFileList[I]))) else
          sUTF8 := CRLF+UTF8Encode(QBitRecordToString(PQBitFileRecord(qBitFileList[I])));
        mStream.Write(sUTF8[1],Length(sUTF8));
      End;
      {$ELSE}
      For I := 0 to qBitFileList.Count-1 do
      Begin
        If I = 0 then                                                           
          sUTF8 := UTF8Encode(QBitRecordToString(PQBitFileRecord(qBitFileList[I]))) else
          sUTF8 := CRLF+UTF8Encode(QBitRecordToString(PQBitFileRecord(qBitFileList[I])));
          //sItemList := QBitRecordToString(PQBitFileRecord(qBitFileList[I])) else
          //sItemList := sItemList+'|'+QBitRecordToString(PQBitFileRecord(qBitFileList[I]));

        mStream.Write(sUTF8[1],Length(sUTF8));
      End;
      {$ENDIF}

      qBitItemListCache  := sItemList;
      {$IFDEF LOCALTRACE}DebugMsgFT(logPath,'Generate result (after)');{$ENDIF}
    End;
  End
  {$IFDEF LOCALTRACE}Else DebugMsgFT(LogPath,'qBitTorrentEnabled = False'){$ENDIF};

  // Encode the text
  //If sItemList <> '' then
  If mStream.Size > 0 then
  Begin
    //{$IFDEF LOCALTRACE}DebugMsgFT(LogPath,'UTF8Encode (before)');{$ENDIF}
    //sUTF8 := UTF8Encode(sItemList);
    //{$IFDEF LOCALTRACE}DebugMsgFT(LogPath,'UTF8Encode (after)');{$ENDIF}
    //iLen  := Length(sUTF8);
    //{$IFDEF LOCALTRACE}DebugMsgFT(LogPath,'Result size : '+IntToStr(iLen)+' bytes');{$ENDIF}
    {$IFDEF LOCALTRACE}DebugMsgFT(LogPath,'Result size : '+IntToStr(mStream.Size)+' bytes');{$ENDIF}

    If mStream.Size < 1024*1024*10 then
    Begin
      {$IFDEF LOCALTRACE}DebugMsgFT(LogPath,'Move (before)');{$ENDIF}
      //Move(sUTF8[1],ItemList^.dlItems^,iLen);
      sUTF8 := #0;
      mStream.Write(sUTF8[1],1);
      mStream.Position := 0;
      mStream.Read(ItemList^.dlItems^,mStream.Size);
      {$IFDEF LOCALTRACE}DebugMsgFT(LogPath,'Move (after)');{$ENDIF}
      Result := S_OK;
    End
    {$IFDEF LOCALTRACE}Else DebugMsgFT(LogPath,'Parsed results larger than the 10mb buffer!!!'){$ENDIF};
  End
  {$IFDEF LOCALTRACE}Else DebugMsgFT(LogPath,'No entries found!'){$ENDIF};


  mStream.Free;
  {$IFDEF LOCALTRACE}DebugMsgFT(logPath,'GetList (after)'+CRLF);{$ENDIF}
end;


// Called by Zoom Player to verify if a configuration dialog is available.
// Return True if a dialog exits and False if no configuration dialog exists.
function CanConfigure : Bool; stdcall;
begin
  {$IFDEF LOCALTRACE}DebugMsgFT(logPath,'CanConfigure (before)');{$ENDIF}
  Result := True;
  {$IFDEF LOCALTRACE}DebugMsgFT(logPath,'CanConfigure (after)'+CRLF);{$ENDIF}
end;


// Called by Zoom Player to show the plugin's configuration dialog.
Procedure Configure(CenterOnWindow : HWND); stdcall;
const
  qBittorrentSettingCount = 3;
  qBittorrentSettings : Array[0..qBittorrentSettingCount-1] of String =
  ('Downloads\UseIncompleteExtension',  // should be set to "false"
   'WebUI\Enabled',                     // should be set to "true"
   'WebUI\LocalHostAuth');              // should be set to "false"

  qBittorrentValues   : Array[0..qBittorrentSettingCount-1] of String =
  ('false',
   'true',
   'false');

  qBittorrentWarnings : Array[0..qBittorrentSettingCount-1] of String =
  ('qBittorent should not add a temporary ".!qB" file extension :'#10'qBittorrent / Tools / Options / Downloads > "Append .!qB extension to incomplete files".',
   'Web UI is not enabled :'#10'qBittorrent / Tools / Options / Web UI > "Web User Interface (Remote Control)".',
   'Web UI needs to allow local connections :'#10'qBittorrent / Tools / Options / Web UI > "Bypass authentication for localhost".');

  qBittorrentPrefrences : String = '[Preferences]';

var
  CenterOnRect  : TRect;
  sConfigPath   : WideString;
  sConfigFile   : TStringList;
  sList         : TStringList;
  sValue        : String;
  fConfigStream : TTNTFileStream;
  I,I1          : Integer;
  iPos          : Integer;
  iPrefrences   : Integer;
  sMsg          : String;
  FoundEntries  : Array[0..qBittorrentSettingCount-1] of Boolean;
begin
  {$IFDEF LOCALTRACE}DebugMsgFT(logPath,'Configure (before)');{$ENDIF}
  If GetWindowRect(CenterOnWindow,CenterOnRect) = False then
    GetWindowRect(0,CenterOnRect); // Can't find window, center on screen

  // Locate qBittorrent's configuration INI file and check if certain settings are incompatible with ZP.
  sConfigPath := AddBackSlash(GetWindowsSystemPath(CenterOnWindow,CSIDL_APPDATA))+qBittorrentPath+'qBittorrent.ini';
  If WideFileExists(sConfigPath) = True then
  Begin
    Try fConfigStream := TTNTFileStream.Create(sConfigPath,fmOpenRead or fmShareDenyNone); Except fConfigStream := nil; End;

    If fConfigStream <> nil then
    Begin
      sConfigFile := TStringList.Create;
      Try sConfigFile.LoadFromStream(fConfigStream); Except End;
      fConfigStream.Free;

      If sConfigFile.Count > 0 then
      Begin
        For I := 0 to qBittorrentSettingCount-1 do FoundEntries[I] := False;

        sList := TStringList.Create;
        For I := 0 to sConfigFile.Count-1 do
        Begin
          For I1 := 0 to qBittorrentSettingCount-1 do
          Begin
            If Pos(qBittorrentSettings[I1],sConfigFile[I]) = 1 then
            Begin
              FoundEntries[I1] := True;
              iPos := Pos('=',sConfigFile[I]);
              If iPos > 0 then
              Begin
                sValue := Copy(sConfigFile[I],iPos+1,Length(sConfigFile[I])-iPos);
                If CompareText(sValue,qBittorrentValues[I1]) <> 0 then
                Begin
                  // Wrong value encountered!
                  sList.Add(qBittorrentWarnings[I1])
                End;
              End;
              Break;
            End;
          End;
        End;

        // Add missing configuration entries to the warning message
        For I := 0 to qBittorrentSettingCount-1 do If FoundEntries[I] = False then
          sList.Add(qBittorrentWarnings[I]);

        If sList.Count > 0 then
        Begin
          sMsg := 'The following problems were identified in qBittorrent''s configuration:'#10#10;
          For I := 0 to sList.Count-1 do sMsg := sMsg+sList[I]+#10#10;
          sMsg := sMsg+'To automatically fix these issues, close qBittorrent and press OK.';

          // Bad settings found
          If MessageDLG(sMsg,mtWarning,[mbok,mbcancel],0) = mrOK then
          Begin
            // Find preferences section
            iPrefrences := -1;
            For I := 0 to sConfigFile.Count-1 do If WideCompareText(qBittorrentPrefrences,sConfigFile[I]) = 0 then
            Begin
              iPrefrences := I;
              Break;
            End;
            If iPrefrences = -1 then
            Begin
              iPrefrences := 1;
              sConfigFile.Insert(0,qBittorrentPrefrences);
              sConfigFile.Insert(1,'');
            End;

            // Add entries that were not found
            For I := 0 to qBittorrentSettingCount-1 do If FoundEntries[I] = False then
              sConfigFile.Insert(iPrefrences,qBittorrentSettings[I]+'='+qBittorrentValues[I]);

            // Update qBittorrent settings
            For I := 0 to sConfigFile.Count-1 do
            Begin
              For I1 := 0 to qBittorrentSettingCount-1 do
              Begin
                If Pos(qBittorrentSettings[I1],sConfigFile[I]) = 1 then
                Begin
                  sConfigFile[I] := qBittorrentSettings[I1]+'='+qBittorrentValues[I1];
                  Break;
                End;
              End;
            End;

            // Save updated config file
            Try fConfigStream := TTNTFileStream.Create(sConfigPath,fmCreate); Except fConfigStream := nil; End;
            If fConfigStream <> nil then
            Begin
              sConfigFile.SaveToStream(fConfigStream);
              fConfigStream.Free;
            End;
          End;
        End;
        sList.Free;
      End;

      sConfigFile.Free;
    End;
  End;

  ConfigForm := TConfigForm.Create(nil);
  ConfigForm.SetBounds(CenterOnRect.Left+(((CenterOnRect.Right -CenterOnRect.Left)-ConfigForm.Width)  div 2),
                       CenterOnRect.Top +(((CenterOnRect.Bottom-CenterOnRect.Top )-ConfigForm.Height) div 2),ConfigForm.Width,ConfigForm.Height);

  ConfigForm.OPqBitTorrentEnabled.Checked   := qBitTorrentEnabled;
  ConfigForm.OPqBitTorrentPort.Text         := IntToStr(qBitTorrentPort);
  ConfigForm.OPqBitTorrentDLSpeed.Text      := IntToStr(qBitTorrentDLSpeed);
  ConfigForm.OPqBitTorrentULSpeed.Text      := IntToStr(qBitTorrentULSpeed);
  ConfigForm.OPqBitTorrentDLFolder.Text     := qBitTorrentDLFolder;
  ConfigForm.OPQBitTorrentSkipFiles.Checked := qBitTorrentSkipFiles;
  ConfigForm.OPQBitTorrentSkipDND.Checked   := qBitTorrentSkipDND;
  ConfigForm.OPqBitTorrentDLStart.Text      := FloatToStrF(qBitTorrentRequireAtStart,ffFixed,15,2);
  ConfigForm.OPqBitTorrentDLEnd.Text        := FloatToStrF(qBitTorrentRequireAtEnd,ffFixed,15,2);

  If processExists(qBittorrentEXE) = False then
  Begin
    ConfigForm.LabelNotRunning.Visible := True;
    ConfigForm.ShapeNotRunning.Visible := True;
  End;

  If ConfigForm.ShowModal = mrOK then
  Begin
    qBitTorrentEnabled        := ConfigForm.OPqBitTorrentEnabled.Checked;
    qBitTorrentPort           := StrToIntDef(ConfigForm.OPqBitTorrentPort.Text,8080);
    qBitTorrentDLSpeed        := StrToIntDef(ConfigForm.OPqBitTorrentDLSpeed.Text,0);
    qBitTorrentULSpeed        := StrToIntDef(ConfigForm.OPqBitTorrentULSpeed.Text,0);
    qBitTorrentDLFolder       := ConfigForm.OPqBitTorrentDLFolder.Text;
    qBitTorrentSkipFiles      := ConfigForm.OPQBitTorrentSkipFiles.Checked;
    qBitTorrentSkipDND        := ConfigForm.OPQBitTorrentSkipDND.Checked;
    qBitTorrentRequireAtStart := StrToFloatDef(ConfigForm.OPqBitTorrentDLStart.Text,2);
    qBitTorrentRequireAtEnd   := StrToFloatDef(ConfigForm.OPqBitTorrentDLEnd.Text,1);

    // Save to registry
    SetRegDWord (HKEY_CURRENT_USER,PluginRegKey,RegKey_qBitTorrentEnabled       ,Integer(qBitTorrentEnabled));
    SetRegDWord (HKEY_CURRENT_USER,PluginRegKey,RegKey_qBitTorrentPort          ,qBitTorrentPort);
    SetRegDWord (HKEY_CURRENT_USER,PluginRegKey,RegKey_qBitTorrentDLSpeed       ,qBitTorrentDLSpeed);
    SetRegDWord (HKEY_CURRENT_USER,PluginRegKey,RegKey_qBitTorrentULSpeed       ,qBitTorrentULSpeed);
    SetRegString(HKEY_CURRENT_USER,PluginRegKey,RegKey_qBitTorrentDLFolder      ,UTF8Encode(qBitTorrentDLFolder));
    SetRegDWord (HKEY_CURRENT_USER,PluginRegKey,RegKey_qBitTorrentSkipFiles     ,Integer(qBitTorrentSkipFiles));
    SetRegDWord (HKEY_CURRENT_USER,PluginRegKey,RegKey_qBitTorrentSkipDND       ,Integer(qBitTorrentSkipDND));
    SetRegDWord (HKEY_CURRENT_USER,PluginRegKey,RegKey_qBittorrentRequireAtStart,Trunc(qBitTorrentRequireAtStart*1000));
    SetRegDWord (HKEY_CURRENT_USER,PluginRegKey,RegKey_qBittorrentRequireAtEnd  ,Trunc(qBitTorrentRequireAtEnd  *1000));
  End;
  ConfigForm.Free;
  {$IFDEF LOCALTRACE}DebugMsgFT(logPath,'Configure (after)'+CRLF);{$ENDIF}
end;


function PluginInfo : PChar;
begin
  {$IFDEF LOCALTRACE}DebugMsgFT(logPath,'Plugin info (before)'+CRLF);{$ENDIF}
  Result := 'This plugin downloads ".torrent" files and magnet links using the open-source qBittorent app.\n\nqBittorrent v4 or newer must be installed and running for the plugin to work.';
  {$IFDEF LOCALTRACE}DebugMsgFT(logPath,'Plugin info (after)'+CRLF);{$ENDIF}
end;


Exports
  InitPlugin,
  FreePlugin,
  DownloadItem,
  StopDownload,
  ResumeDownload,
  EraseDownload,
  SupportedDownload,
  IncreasePriority,
  DecreasePriority,
  GetItemList,
  CanConfigure,
  PluginInfo,
  Configure;

begin
  // Required to notify the memory manager that this DLL is being called from a multi-threaded application!
  IsMultiThread := True;
end.
