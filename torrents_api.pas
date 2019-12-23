{$I PLUGIN_DEFINES.INC}

unit torrents_api;

interface

uses sysutils, classes, tntsysutils, superobject, misc_utils_unit;


const
  strLocalHost             : String = 'localhost';

  playableFalse            : Integer = 0;
  playableTrue             : Integer = 1;
  playableUnknown          : Integer = 2;

  sPriorityUnknown         : String = 'Unknown';
  sPriorityDoNotDownload   : String = 'Do not download';
  sPriorityNormalPriority  : String = 'Normal';
  sPriorityHighPriority    : String = 'High';
  sPriorityMaximalPriority : String = 'Maximum';

  iPriorityDoNotDownload   = 0;
  iPriorityNormalPriority1 = 1;
  iPriorityNormalPriority2 = 4;
  iPriorityHighPriority    = 6;
  iPriorityMaximalPriority = 7;

  dlstateUnknown           = -1;
  dlstateError             =  0;
  dlstatePaused            =  1;
  dlstateQueued            =  2;
  dlstateUpload            =  3;
  dlstateDownload          =  4;

  piecestateNotDownloaded  =  0;
  piecestateDownloading    =  1;
  piecestateDownloaded     =  2;


type
  TQBitFileRecord =
  Record
    qbitTorrentHash   : String;         // The torrent's hash (used for torrent commands).
    qbitFileID        : Integer;        // File file's ID within the torrent (used when changing priority).
    qbitFileName      : WideString;     // file name.
    qbitDLPath        : WideString;     // Download Path.
    qbitCategory      : WideString;     // Category.
    qbitProgress      : Double;         // Download progress (0 - 100%).
    qbitFileSize      : Int64;          // file size in bytes.
    qbitCanErase      : Boolean;        // Can this entry be erased.
    qbitCanStop       : Boolean;        // Can this entry be stopped.
    qbitPlayable      : Integer;        // Is this entry playbable, see "playable" codes above.
    qbitPriority      : Integer;        // Download priority, see "iPriority" codes above.
    qbitState         : Integer;        // Download state, See "dlstate" codes above.
    qbitPriorityStr   : WideString;     // Text string describing the current priority.
    qbitStartPiece    : Integer;        // The starting piece within a torrent for this particular file
    qbitEndPiece      : Integer;        // The ending piece within a torrent for this particular file
  End;
  PQBitFileRecord = ^TQBitFileRecord;


  TQBitTorrentRecord =
  Record
    torrentHash       : String;         // The torrent's hash
    torrentPieceCount : Integer;        // Number of pieces
    torrentPieceSize  : Integer;        // Piece size in bytes
    torrentPieces     : TList;          // An array of the piece states
    torrentTotalSize  : Int64;          // Total file size in bytes of the entire torrent
  End;
  PQBitTorrentRecord = ^TQBitTorrentRecord;


var
  qBitReferer               : String;
  qBittorrentDLFolder       : WideString = '';
  qBittorrentDLSpeed        : Integer    = 0;
  qBittorrentULSpeed        : Integer    = 0;
  qBittorrentRequireAtStart : Double     = 2; // % of download to require at the start of the file
  qBittorrentRequireAtEnd   : Double     = 1; // % of download to require at the end of the file
  qBitTorrentSkipFiles      : Boolean    = False;
  qBitTorrentSkipDND        : Boolean    = False;


function  qBitRecordToString(Entry : PQBitFileRecord) : WideString;
function  qBittorrent_ReadyForPlayback(cItem : PQBitFileRecord; TorrentList : TList) : Integer;
procedure qBittorrent_ClearItemList(FileList : TList);
procedure qBittorrent_ClearTorrentList(TorrentList : TList);
procedure qBittorrent_ItemID_to_HashAndFileID(sItemID : WideString; var iFileIndex : Integer; var sHash : String);

procedure qBittorrent_GetFileList(Address : String; Port : Integer; TorrentList,FileList : TList; AbortFlag : PBoolean);
procedure qBittorrent_PauseTorrent(Address : String; Port : Integer; TorrentHash : String);
procedure qBittorrent_ResumeTorrent(Address : String; Port : Integer; TorrentHash : String);
procedure qBittorrent_IncreaseFilePriority(Address : String; Port,FileID : Integer; TorrentHash : String; FileList : TList);
procedure qBittorrent_DecreaseFilePriority(Address : String; Port,FileID : Integer; TorrentHash : String; FileList : TList);
procedure qBittorrent_EraseTorrent(Address : String; Port : Integer; TorrentHash : String);
procedure qBittorrent_DownloadTorrent(Address : String; Port : Integer; sDownload : AnsiString);



implementation


procedure qBitTorrent_DownloadTorrent(Address : String; Port : Integer; sDownload : AnsiString);
var
  sPost     : AnsiString;
  sHeader   : AnsiString;
  sSavePath : AnsiString;
  sDLSpeed  : AnsiString;
  sULSpeed  : AnsiString;
begin
  {$IFDEF LOCALTRACE}DebugMsgFT(logPath,'qBitTorrent_DownloadTorrent('+sDownload+') (before)');{$ENDIF}

  If qBitTorrentDLFolder <> '' then
  Begin
    sSavePath :=
      'Content-Disposition: form-data; name="savepath"'+CRLF+
      CRLF+
      UTF8Encode(qBitTorrentDLFolder)+CRLF+
      '-----------------------------104658442414806918371937271680'+CRLF;
  End
  Else sSavePath := '';

  If qBitTorrentDLSpeed > 0 then
  Begin
    sDLSpeed :=
      'Content-Disposition: form-data; name="dlLimit"'+CRLF+   // new: set torrent download limit (bytes)
      CRLF+
      IntToStr(qBitTorrentDLSpeed*1024)+CRLF+
      '-----------------------------104658442414806918371937271680'+CRLF;
  End
  Else sDLSpeed := '';

  If qBitTorrentULSpeed > 0 then
  Begin
    sULSpeed :=
      'Content-Disposition: form-data; name="upLimit"'+CRLF+   // new: set torrent upload limit (bytes)
      CRLF+
      IntToStr(qBitTorrentULSpeed*1024)+CRLF+
      '-----------------------------104658442414806918371937271680'+CRLF;
  End
  Else sULSpeed := '';

  sPost :=
    '-----------------------------104658442414806918371937271680'+CRLF+
    'Content-Disposition: form-data; name="urls"'+CRLF+
    CRLF+
    sDownload+CRLF+
    '-----------------------------104658442414806918371937271680'+CRLF+
    'Content-Disposition: form-data; name="paused"'+CRLF+
    CRLF+
    'false'+CRLF+
    '-----------------------------104658442414806918371937271680'+CRLF+
    sSavePath+
    sDLSpeed+
    sULSpeed+
    'Content-Disposition: form-data; name="sequentialDownload"'+CRLF+    // new: set torrent sequential Download
    CRLF+
    'true'+CRLF+
    '-----------------------------104658442414806918371937271680'+CRLF+
    'Content-Disposition: form-data; name="firstLastPiecePrio"'+CRLF+  // new: set torrent first last piece priority
    CRLF+
    'true'+CRLF+
    '-----------------------------104658442414806918371937271680--'+CRLF;


    // Unused :
    //'-----------------------------6688794727912'+CRLF+
    //'Content-Disposition: form-data; name="cookie"'+CRLF+
    //CRLF+
    //'ui=28979218048197'+CRLF+
    //'-----------------------------6688794727912'+CRLF+
    //'Content-Disposition: form-data; name="category"'+CRLF+
    //CRLF+
    //'movies'+CRLF+
    //'-----------------------------6688794727912'+CRLF+
    //'Content-Disposition: form-data; name="skip_checking"'+CRLF+
    //CRLF+
    //'true'+CRLF+
    //'-----------------------------6688794727912'+CRLF+


    // New in qbittorrent 3.4 :
    //'-----------------------------104658442414806918371937271680'+CRLF+
    //'Content-Disposition: form-data; name="fileselect[]"; filename="abc.torrent"'+CRLF+
    //'Content-Type: application/octet-stream'+CRLF+
    //CRLF+
    //'<omitted>'+CRLF+
    //'-----------------------------104658442414806918371937271680'+CRLF+
    //'Content-Disposition: form-data; name="rename"    // new: rename torrent'+CRLF+
    //CRLF+
    //'new_name'+CRLF+
    //'-----------------------------104658442414806918371937271680--'+CRLF+



  sHeader := 'Content-Type: multipart/form-data; boundary=---------------------------104658442414806918371937271680';

  {$IFDEF LOCALTRACE}DebugMsgFT(logPath,'Post data : '+CRLF+sPost);{$ENDIF}

  //sDownload := HTTPPostRequest(sPost, qBitReferer, qBitTorrentPort);
  Try
    //sDownload := HTTPPostData(URLIdentifier, qbitReferer, Address, Port, '/command/download',sHeader, sPost);
    sDownload := HTTPPostData(URLIdentifier, qbitReferer, Address, Port, '/api/v2/torrents/add',sHeader, sPost);
  Except
  End;
  {$IFDEF LOCALTRACE}DebugMsgFT(logPath,'qBitTorrent_DownloadTorrent (after)'+CRLF);{$ENDIF}
end;


procedure qBitTorrent_EraseTorrent(Address : String; Port : Integer; TorrentHash : String);
var
  sPost   : String;
  S       : String;
  sHeader : String;
begin
  {$IFDEF LOCALTRACE}DebugMsgFT(logPath,'qBitTorrent_EraseTorrent('+TorrentHash+') (before)');{$ENDIF}
  sPost   := 'hashes='+TorrentHash+'&deleteFiles=false';
  sHeader := 'Content-Type: application/x-www-form-urlencoded'+CRLF+'Content-Length: '+IntToStr(Length(sPost));
  {$IFDEF LOCALTRACE}DebugMsgFT(logPath,'HTTPPostData = "'+sPost+'"');{$ENDIF}
  Try
    S := HTTPPostData(URLIdentifier, qbitReferer, Address, Port, '/api/v2/torrents/delete',sHeader, sPost);
  Except
  End;
  {$IFDEF LOCALTRACE}DebugMsgFT(logPath,'qBitTorrent_EraseTorrent, result = "'+S+'"'+CRLF);{$ENDIF}
end;


procedure qBitTorrent_PauseTorrent(Address : String; Port : Integer; TorrentHash : String);
var
  sPost   : String;
  S       : String;
  sHeader : String;
begin
  {$IFDEF LOCALTRACE}DebugMsgFT(logPath,'qBitTorrent_PauseTorrent('+TorrentHash+') (before)');{$ENDIF}

  sPost   := 'hashes='+TorrentHash;
  sHeader := 'Content-Type: application/x-www-form-urlencoded'+CRLF+'Content-Length: '+IntToStr(Length(sPost));
  {$IFDEF LOCALTRACE}DebugMsgFT(logPath,'HTTPPostData = "'+sPost+'"');{$ENDIF}
  Try
    //S := HTTPPostData(URLIdentifier, qbitReferer, Address, Port, '/command/pause',sHeader, sPost);
    S := HTTPPostData(URLIdentifier, qbitReferer, Address, Port, '/api/v2/torrents/pause',sHeader, sPost);
  Except
  End;
  {$IFDEF LOCALTRACE}DebugMsgFT(logPath,'qBitTorrent_PauseTorrent, result = "'+S+'"'+CRLF);{$ENDIF}
end;


procedure qBitTorrent_ResumeTorrent(Address : String; Port : Integer; TorrentHash : String);
var
  sPost   : String;
  S       : String;
  sHeader : String;
begin
  {$IFDEF LOCALTRACE}DebugMsgFT(logPath,'qBitTorrent_ResumeTorrent('+TorrentHash+') (before)');{$ENDIF}
  sPost   := 'hashes='+TorrentHash;
  sHeader := 'Content-Type: application/x-www-form-urlencoded'+CRLF+'Content-Length: '+IntToStr(Length(sPost));
  {$IFDEF LOCALTRACE}DebugMsgFT(logPath,'HTTPPostData = "'+sPost+'"');{$ENDIF}
  Try
    S := HTTPPostData(URLIdentifier, qbitReferer, Address, Port, '/api/v2/torrents/resume',sHeader, sPost);
  Except
  End;
  {$IFDEF LOCALTRACE}DebugMsgFT(logPath,'qBitTorrent_ResumeTorrent, result = "'+S+'"'+CRLF);{$ENDIF}
end;


procedure qBitTorrent_ItemID_to_HashAndFileID(sItemID : WideString; var iFileIndex : Integer; var sHash : String);
var
  iPos : Integer;
begin
  iFileIndex := -1;
  sHash      := '';

  iPos := Pos(',',sItemID);
  If iPos > 0 then
  Begin
    iFileIndex := StrToIntDef(Copy(sItemID,1,iPos-1),-1);
    sHash      := Copy(sItemID,iPos+1,Length(sItemID)-iPos);
  End;
end;


procedure qBitTorrent_ClearItemList(FileList : TList);
var
  I : Integer;
begin
  If FileList.Count > 0 then
  Begin
    For I := 0 to FileList.Count-1 do Dispose(PQBitFileRecord(FileList[I]));
    FileList.Clear;
  End;
end;


procedure qBitTorrent_ClearTorrentList(TorrentList : TList);
var
  I : Integer;
begin
  If TorrentList.Count > 0 then
  Begin
    For I := 0 to TorrentList.Count-1 do
    Begin
      PQBitTorrentRecord(TorrentList[I])^.torrentPieces.Free;
      Dispose(PQBitTorrentRecord(TorrentList[I]));
    End;
    TorrentList.Clear;
  End;
end;


procedure QBitTorrent_IncreaseFilePriority(Address : String; Port,FileID : Integer; TorrentHash : String; FileList : TList);
var
  I       : Integer;
  sPost   : String;
  S       : String;
  sHeader : String;
begin
  // POST /command/setFilePrio HTTP/1.1
  // User-Agent: Fiddler
  // Host: 127.0.0.1
  // Cookie: SID=your_sid
  // Content-Type: application/x-www-form-urlencoded
  // Content-Length: length
  //
  // hash=8c212779b4abde7c6bc608063a0d008b7e40ce32&id=0&priority=7
  //
  {$IFDEF LOCALTRACE}DebugMsgFT(logPath,'QBitTorrent_IncreaseFilePriority('+IntToStr(FileID)+','+TorrentHash+') (before)');{$ENDIF}
  // Locate Torrent and File
  For I := 0 to FileList.Count-1 do With PQBitFileRecord(FileList[I])^ do If (qbitFileID = FileID) and (qbitTorrentHash = TorrentHash) then
  Begin
    If qbitPriority < iPriorityMaximalPriority then
    Begin
      Case qbitPriority of
        iPriorityDoNotDownload    : qbitPriority := iPriorityNormalPriority1;
        iPriorityNormalPriority1,
        iPriorityNormalPriority2  : qbitPriority := iPriorityHighPriority;
        iPriorityHighPriority     : qbitPriority := iPriorityMaximalPriority;
      End;
      sPost   := 'hash='+TorrentHash+'&id='+IntToStr(FileID)+'&priority='+IntToStr(qbitPriority);
      sHeader := 'Content-Type: application/x-www-form-urlencoded'+CRLF+'Content-Length: '+IntToStr(Length(sPost));
      {$IFDEF LOCALTRACE}DebugMsgFT(logPath,'HTTPPostData = "'+sPost+'"');{$ENDIF}
      Try
        //S := HTTPPostData(URLIdentifier, qbitReferer, Address, Port, '/command/setFilePrio',sHeader, sPost);
        S := HTTPPostData(URLIdentifier, qbitReferer, Address, Port, '/api/v2/torrents/filePrio',sHeader, sPost);
      Except
      End;
      {$IFDEF LOCALTRACE}DebugMsgFT(logPath,'HTTPPostData result = "'+S+'"');{$ENDIF}
    End;
    Break;
  End;
  {$IFDEF LOCALTRACE}DebugMsgFT(logPath,'QBitTorrent_IncreaseFilePriority (after)'+CRLF);{$ENDIF}
end;


procedure QBitTorrent_DecreaseFilePriority(Address : String; Port,FileID : Integer; TorrentHash : String; FileList : TList);
var
  I       : Integer;
  sPost   : String;
  S       : String;
  sHeader : String;
begin
  {$IFDEF LOCALTRACE}DebugMsgFT(logPath,'QBitTorrent_DecreaseFilePriority('+IntToStr(FileID)+','+TorrentHash+') (before)');{$ENDIF}
  // Locate Torrent and File
  For I := 0 to FileList.Count-1 do With PQBitFileRecord(FileList[I])^ do If (qbitFileID = FileID) and (qbitTorrentHash = TorrentHash) then
  Begin
    If qbitPriority > iPriorityDoNotDownload then
    Begin
      Case qbitPriority of
        iPriorityNormalPriority1,
        iPriorityNormalPriority2  : qbitPriority := iPriorityDoNotDownload;
        iPriorityHighPriority     : qbitPriority := iPriorityNormalPriority1;
        iPriorityMaximalPriority  : qbitPriority := iPriorityHighPriority;
      End;
      sPost   := 'hash='+TorrentHash+'&id='+IntToStr(FileID)+'&priority='+IntToStr(qbitPriority);
      sHeader := 'Content-Type: application/x-www-form-urlencoded'+CRLF+'Content-Length: '+IntToStr(Length(sPost));
      {$IFDEF LOCALTRACE}DebugMsgFT(logPath,'HTTPPostData = "'+sPost+'"');{$ENDIF}
      Try
        //S := HTTPPostData(URLIdentifier, qbitReferer, Address, Port, '/command/setFilePrio',sHeader, sPost);
        S := HTTPPostData(URLIdentifier, qbitReferer, Address, Port, '/api/v2/torrents/filePrio',sHeader, sPost);
      Except
      End;
      {$IFDEF LOCALTRACE}DebugMsgFT(logPath,'HTTPPostData result = "'+S+'"');{$ENDIF}
    End;
    Break;
  End;
  {$IFDEF LOCALTRACE}DebugMsgFT(logPath,'QBitTorrent_DecreaseFilePriority (after)'+CRLF);{$ENDIF}
end;


procedure qBittorrent_GetFileList(Address : String; Port : Integer; TorrentList,FileList : TList; AbortFlag : PBoolean);
var
  sList         : TStringList;
  jHashList     : ISuperObject;
  jHashObj      : ISuperObject;
  jDirObj       : ISuperObject;
  jFileList     : ISuperObject;
  jFileObj      : ISuperObject;
  jPieceList    : ISuperObject;
  I,I1,I2       : Integer;
  S             : WideString;
  sHash         : String;
  sDLFolder     : WideString; // Download folder
  sDLTorrent    : Widestring; // Torrent folder
  sCategory     : Widestring; // Torrent category
  sState        : WideString; // Torrent Status
  sFileName     : WideString; // File name
  iFilePriority : Integer;
  iPieceCount   : Integer;    // Number of pieces in the torrent
  iPieceSize    : Integer;    // Piece size in byte
  iTotalSize    : Int64;      // Total torrent size
  dProgress     : Double;
  nItem         : PQBitFileRecord;
  nTorrent      : PQBitTorrentRecord;
  B             : Boolean;
  SkipFile      : Boolean;
  SkipCount     : Integer;

begin
  {$IFDEF LOCALTRACE}DebugMsgFT(logPath,'QBitTorrent_GetFileList('+Address+','+IntToStr(Port)+') (before)');{$ENDIF}
  qBitTorrent_ClearItemList(FileList);
  qBitTorrent_ClearTorrentList(TorrentList);

  //Application.MessageBox(PAnsiChar(String()),'',mb_ok);
  sList     := TStringList.Create;
  SkipCount := 0;
  {$IFDEF LOCALTRACE}DebugMsgFT(logPath,'Download torrent hashes');{$ENDIF}
  // Older versions of QBitTorrent
  //B := DownloadFileToStringListWithReferer('http://'+Address+':'+IntToStr(Port)+'/query/torrents',qBitReferer,sList);
  B := DownloadFileToStringListWithReferer('http://'+Address+':'+IntToStr(Port)+'/api/v2/torrents/info',qBitReferer,sList);

  // Get Hashes
  If B = True then
  Begin
    {$IFDEF LOCALTRACE}DebugMsgFT(logPath,'Download successful');{$ENDIF}
    If sList.Count > 0 then
    Begin
      {$IFDEF DUMPINPUT}DebugMsgFT(logPathInput,'JSON result:'+CRLF+sList.Text);{$ENDIF}
      jHashList := SO(sList[0]);
      If jHashList <> nil then
      Begin
        {$IFDEF LOCALTRACE}DebugMsgFT(logPath,'Successfully received a hash list object'+CRLF);{$ENDIF}
        For I := 0 to jHashList.AsArray.Length-1 do If AbortFlag^ = False then
        Begin
          jHashObj := jHashList.AsArray[I];
          If jHashObj <> nil then
          Begin
            {$IFDEF LOCALTRACE}DebugMsgFT(logPath,'Successfully received a hash object');{$ENDIF}
            sHash       := jHashObj.S['hash'];
            sDLTorrent  := UTF8Decode(jHashObj.S['name']);
            sCategory   := UTF8Decode(jHashObj.S['category']);
            sState      := jHashObj.S['state'];
            If sHash <> '' then
            Begin
              // Found the Hash field
              {$IFDEF LOCALTRACE}DebugMsgFT(logPath,'Hash : '+sHash);{$ENDIF}

              // Get download folder
              sList.Clear;
              {$IFDEF LOCALTRACE}DebugMsgFT(logPath,'Get Download folder');{$ENDIF}
              B := False;
              If AbortFlag^ = False then
              Begin
                //B := DownloadFileToStringListWithReferer('http://'+Address+':'+IntToStr(Port)+'/query/propertiesGeneral/'+sHash,qBitReferer,sList);
                B := DownloadFileToStringListWithReferer('http://'+Address+':'+IntToStr(Port)+'/api/v2/torrents/properties?hash='+sHash,qBitReferer,sList);
              End;
              
              If B = True then If sList.Count > 0 then
              Begin
                jDirObj := SO(sList[0]);
                If jDirObj <> nil then
                Begin
                  {$IFDEF LOCALTRACE}DebugMsgFT(logPath,'Successfully received download folder object.');{$ENDIF}
                  {$IFDEF DUMPINPUT}DebugMsgFT(logPathInput,'JSON result:'+CRLF+sList.Text);{$ENDIF}
                  sDLFolder   := jDirObj.S['save_path'];
                  iPieceCount := jDirObj.I['pieces_num'];
                  iPieceSize  := jDirObj.I['piece_size'];
                  iTotalSize  := jDirObj.I['total_size'];
                  If sDLFolder <> '' then
                  Begin
                    sDLFolder := AddBackSlash(TNT_WideStringReplace(sDLFolder,'/','\',[rfReplaceAll,rfIgnoreCase]));

                    {$IFDEF LOCALTRACE}DebugMsgFT(logPath,'Download Folder : '+sDLFolder);{$ENDIF}

                    New(nTorrent);
                    nTorrent^.torrentHash       := sHash;
                    nTorrent^.torrentPieceSize  := iPieceSize;
                    nTorrent^.torrentPieceCount := iPieceCount;
                    nTorrent^.torrentPieces     := TList.Create;
                    nTorrent^.torrentTotalSize  := iTotalSize;

                    // Get pieces states
                    sList.Clear;
                    //B := DownloadFileToStringListWithReferer('http://'+Address+':'+IntToStr(Port)+'/query/getPieceStates/'+sHash,qBitReferer,sList);
                    B := DownloadFileToStringListWithReferer('http://'+Address+':'+IntToStr(Port)+'/api/v2/torrents/pieceStates?hash='+sHash,qBitReferer,sList);
                    {$IFDEF LOCALTRACE}DebugMsgFT(logPath,'Download piece states success : '+BoolToStr(B,True));{$ENDIF}
                    {$IFDEF DUMPINPUT}DebugMsgFT(logPathInput,'Download piece states success : '+BoolToStr(B,True)+', values:'+CRLF+sList.Text);{$ENDIF}
                    // Parse piece states
                    If sList.Text <> '' then
                    Begin
                      jPieceList := SO(sList[0]);
                      If jPieceList <> nil then
                      Begin
                        I2 := jPieceList.AsArray.Length;
                        For I1 := 0 to I2-1 do nTorrent^.torrentPieces.Add(Pointer(jPieceList.AsArray[I1].AsInteger));
                        jPieceList := nil;
                      End
                      {$IFDEF LOCALTRACE}Else DebugMsgFT(logPath,'Parsing: jPieceList = nil!'){$ENDIF};
                    End
                    {$IFDEF LOCALTRACE}Else DebugMsgFT(logPath,'No pieces returned to parse'){$ENDIF};

                    TorrentList.Add(nTorrent);

                    // Get file data
                    sList.Clear;
                    B := False;
                    If AbortFlag^ = False then
                    Begin
                      //B := DownloadFileToStringListWithReferer('http://'+Address+':'+IntToStr(Port)+'/query/propertiesFiles/'+sHash,qBitReferer,sList);
                      B := DownloadFileToStringListWithReferer('http://'+Address+':'+IntToStr(Port)+'/api/v2/torrents/files?hash='+sHash,qBitReferer,sList);
                    End;

                    If B = True then If sList.Count > 0 then
                    Begin
                      jFileList := SO(sList[0]);
                      If jFileList <> nil then
                      Begin
                        {$IFDEF LOCALTRACE}DebugMsgFT(logPath,'Successfully received the file list object');{$ENDIF}
                        {$IFDEF DUMPINPUT}DebugMsgFT(logPathInput,'JSON result:'+CRLF+sList.Text);{$ENDIF}
                        For I1 := 0 to jFileList.AsArray.Length-1 do If AbortFlag^ = False then
                        Begin
                          jFileObj := jFileList.AsArray[I1];
                          If jFileObj <> nil then
                          Begin
                            // Successfully received the file object
                            SkipFile      := False;
                            sFileName     := UTF8Decode(jFileObj.S['name']);
                            dProgress     := jFileObj.D['progress']*100;
                            iFilePriority := StrToIntDef(jFileObj.S['priority'],-1);
                            {$IFDEF LOCALTRACE}DebugMsgFT(logPath,'File Name : '+sFileName);{$ENDIF}
                            {$IFDEF LOCALTRACE}DebugMsgFT(logPath,'Progress  : '+FloatToStr(dProgress));{$ENDIF}
                            {$IFDEF LOCALTRACE}DebugMsgFT(logPath,'Priority  : '+IntToStr(iFilePriority)+' src "'+jFileObj.S['priority']+'"');{$ENDIF}

                            If sFileName <> '' then
                            Begin
                              // Found the file name, due to a bug in QBitTorrent, the download folder may be wrongly reported if it was renamed on the initial download dialog
                              If (qBitTorrentSkipDND = False) or (iFilePriority <> iPriorityDoNotDownload) then
                              Begin
                                New(nItem);

                                {If Pos('out of the black',Lowercase(sFileName)) > 0 then
                                Begin
                                  nItem^.qbitTorrentHash := 'bla';
                                End;}

                                nItem^.qbitTorrentHash := sHash;
                                nItem^.qbitFileID      := I1; // used by "/setFilePrio" to set a file's priority.
                                nItem^.qbitDLPath      := sDLFolder;
                                nItem^.qbitCategory    := sCategory;
                                nItem^.qbitCanErase    := True;
                                nItem^.qbitCanStop     := True;
                                nItem^.qbitPriority    := StrToIntDef(jFileObj.S['priority'],-1);
                                Case nItem^.qbitPriority of
                                  iPriorityDoNotDownload   : nItem^.qbitPriorityStr := sPriorityDoNotDownload;
                                  iPriorityNormalPriority1,
                                  iPriorityNormalPriority2 : nItem^.qbitPriorityStr := sPriorityNormalPriority;
                                  iPriorityHighPriority    : nItem^.qbitPriorityStr := sPriorityHighPriority;
                                  iPriorityMaximalPriority : nItem^.qbitPriorityStr := sPriorityMaximalPriority;
                                  else                       nItem^.qbitPriorityStr := sPriorityUnknown;
                                End;
                                If (WideFileExists(sDLFolder+sFileName) = True) or (dProgress = 0) then
                                Begin
                                  nItem^.qbitFileName := sFileName;
                                  If dProgress > 0 then
                                    nItem^.qbitFileSize := GetFileSize64(sDLFolder+nItem^.qbitFileName) else
                                    nItem^.qbitFileSize := 0;
                                End
                                  else
                                If WideFileExists(sDLFolder+AddBackSlash(sDLTorrent)+sFileName) = True then
                                Begin
                                  nItem^.qbitFileName := AddBackSlash(sDLTorrent)+sFileName;
                                  nItem^.qbitFileSize := GetFileSize64(sDLFolder+nItem^.qbitFileName);
                                End
                                  else
                                If qBitTorrentSkipFiles = False then
                                Begin
                                  // Line below commented as it was causing non-existing files to be listed in the root
                                  //nItem^.qbitFileName := WideExtractFileName(sFileName);
                                  nItem^.qbitFileName := sFileName;
                                  nItem^.qbitFileSize := 0;
                                End
                                  else
                                Begin
                                  {$IFDEF LOCALTRACE}DebugMsgFT(logPath,'Skipping, not found on disk');{$ENDIF}
                                  // Get rid of the file, can't find it on disk
                                  SkipFile := True;
                                  Inc(SkipCount);
                                  Dispose(nItem);
                                End;

                                If SkipFile = False then
                                Begin
                                  If sState = 'error'       then nItem^.qbitState := dlstateError    else
                                  If sState = 'pausedUP'    then nItem^.qbitState := dlstatePaused   else
                                  If sState = 'pausedDL'    then nItem^.qbitState := dlstatePaused   else
                                  If sState = 'queuedUP'    then nItem^.qbitState := dlstateQueued   else
                                  If sState = 'queuedDL'    then nItem^.qbitState := dlstateQueued   else
                                  If sState = 'uploading'   then nItem^.qbitState := dlstateUpload   else
                                  If sState = 'forcedUP'    then nItem^.qbitState := dlstateUpload   else
                                  If sState = 'stalledUP'   then nItem^.qbitState := dlstateUpload   else
                                  If sState = 'checkingUP'  then nItem^.qbitState := dlstateUpload   else
                                  If sState = 'checkingDL'  then nItem^.qbitState := dlstateDownload else
                                  If sState = 'downloading' then nItem^.qbitState := dlstateDownload else
                                  If sState = 'stalledDL'   then nItem^.qbitState := dlstateDownload else
                                  If sState = 'forceDL'     then nItem^.qbitState := dlstateDownload else
                                  If sState = 'metaDL'      then nItem^.qbitState := dlstateDownload else
                                                                 nItem^.qbitState := dlstateUnknown;

                                  nItem^.qbitProgress       := dProgress;
                                  nItem^.qbitStartPiece     := -1; // Initialize value
                                  nItem^.qbitEndPiece       := -1; // Initialize value

                                  // Get piece range
                                  jPieceList := SO(jFileObj.S['piece_range']);
                                  If jPieceList <> nil then
                                  Begin
                                    If jPieceList.AsString <> '' then
                                    Begin
                                      I2 := jPieceList.AsArray.Length;
                                      If I2 = 2 then
                                      Begin
                                        nItem^.qbitStartPiece := jPieceList.AsArray[0].AsInteger;
                                        nItem^.qbitEndPiece   := jPieceList.AsArray[1].AsInteger;
                                      End;
                                    End
                                    {$IFDEF LOCALTRACE}Else DebugMsgFT(logPath,'File Range: jPieceList empty'){$ENDIF};
                                    jPieceList := nil;
                                  End
                                  {$IFDEF LOCALTRACE}Else DebugMsgFT(logPath,'File Range: jPieceList = nil!'){$ENDIF};

                                  // Check if the media is playable based on downloaded pieces
                                  nItem^.qbitPlayable := qBitTorrent_ReadyForPlayback(nItem,TorrentList);

                                  FileList.Add(nItem);
                                End
                                {$IFDEF LOCALTRACE}Else DebugMsgFT(logPath,'Skipping file on "do not download" priority'){$ENDIF};
                              End;
                            End
                            {$IFDEF LOCALTRACE}Else DebugMsgFT(logPath,'Error: Filename is empty'){$ENDIF};
                            jFileObj.Clear(True);
                            jFileObj := nil;
                          End;
                        End;
                        jFileList.Clear(True);
                        jFileList := nil;
                        {$IFDEF LOCALTRACE}DebugMsgFT(logPath,'Finished parsing file list object'+CRLF);{$ENDIF}
                      End;
                    End;
                  End;
                  jDirObj.Clear(True);
                  jDirObj := nil;
                End;
              End;
            End;
            jHashObj.Clear(True);
            jHashObj := nil;
          End;
        End;
        jHashList.Clear(True);
        jHashList := nil;
      End;
    End;
  End;
  sList.Free;
  S          := '';
  sFileName  := '';
  sDLFolder  := '';
  sDLTorrent := '';
  {$IFDEF LOCALTRACE}DebugMsgFT(logPath,'Skipped '+IntToStr(SkipCount)+' files');{$ENDIF}
  {$IFDEF LOCALTRACE}DebugMsgFT(logPath,'QBitTorrent_GetFileList (after)'+CRLF);{$ENDIF}
end;


function qBitRecordToString(Entry : PQBitFileRecord) : WideString;
Begin
    // [ID]         : A method for the download plugin to later identify specific entries, in our case Hash,FileID
    // [Title]      : A title to display to the end user, if not specified the file name is shown
    // [FileName]   : The file's relative path and name.
    // [DLPath]     : The file's download path.
    // [Category]   : The file's category
    // [FileDate]   : The file's date (if available, in Delphi's TDateTime floating point time format)
    // [FileSize]   : The file's size in bytes (if available)
    // [Progress]   : A floating point value from 0 to 100 (e.g. "50.52").
    // [State]      : The torrent's state (download/upload/paused/etc)
    // [Duration]   : A media file's duration (if available)
    // [CanErase]   : 0 = No, 1 = Yes (used with the EraseDownload function).
    // [CanStop]    : 0 = No, 1 = Yes (used with the StopDownload function).
    // [Playable]   : 0 = No, 1 = Yes, 2 = Unknown (return the best value based on your understanding of the file format being downloaded)
    // [Priority]   : The file/torrent's priority as it should display to the end user

  Result := '"ID='          +IntToStr        (Entry^.qbitFileID)          +','+Entry^.qbitTorrentHash+'",'+
            '"FileName='    +                 Entry^.qbitFileName         +'",'+
          //'"FileName='    +EncodeTextTags  (Entry^.qbitFileName,True)   +'",'+
            '"FileSize='    +IntToStr        (Entry^.qbitFileSize)        +'",'+
          //'"DLPath='      +EncodeTextTags  (Entry^.qbitDLPath,True)     +'",'+
            '"DLPath='      +                 Entry^.qbitDLPath           +'",'+
            '"Category='    +EncodeTextTags  (Entry^.qbitCategory,True)   +'",'+
            '"CanErase='    +IntToStr(Integer(Entry^.qbitCanErase))       +'",'+
            '"CanStop='     +IntToStr(Integer(Entry^.qbitCanStop))        +'",'+
            '"Playable='    +IntToStr(Integer(Entry^.qbitPlayable))       +'",'+
            '"State='       +IntToStr(        Entry^.qbitState)           +'",'+
            '"Priority='    +EncodeTextTags  (Entry^.qbitPriorityStr,True)+'",'+
            '"Progress='    +FloatToStr      (Entry^.qbitProgress)        +'"';
End;


function qBitTorrent_ReadyForPlayback(cItem : PQBitFileRecord; TorrentList : TList) : Integer;
var
  I,I1         : Integer;
  PiecePercent : Double;
  dlStart      : Double;
  dlEnd        : Double;
begin
  Result := playableUnknown;

  If (cItem^.qbitEndPiece >= cItem^.qbitStartPiece) and (cItem^.qbitStartPiece > -1) and (cItem^.qbitEndPiece > -1) then
  Begin
    // First find which torrent the file belongs to
    For I := 0 to TorrentList.Count-1 do With PQBitTorrentRecord(TorrentList[I])^ do If torrentHash = cItem^.qbitTorrentHash then
    Begin
      If cItem^.qbitProgress < 100 then
      Begin
        PiecePercent := (torrentPieceSize*100) / cItem^.qbitFileSize;
        dlStart      := 0;
        dlEnd        := 0;
        For I1 := cItem^.qbitStartPiece to cItem^.qbitEndPiece     do If Integer(torrentPieces[I1]) = piecestateDownloaded then dlStart := dlStart+PiecePercent else Break;
        For I1 := cItem^.qbitEndPiece downto cItem^.qbitStartPiece do If Integer(torrentPieces[I1]) = piecestateDownloaded then dlEnd   := dlEnd  +PiecePercent else Break;

        If dlStart >= qBittorrentRequireAtStart then
        Begin
          If dlEnd >= qBittorrentRequireAtEnd then Result := playableTrue;
        End
        Else Result := playableFalse;
        {$IFDEF LOCALTRACE}DebugMsgFT(logPath,'Ready for Playback / Start : '+FloatToStrF(dlStart,ffFixed,15,1)+'% / End : '+FloatToStrF(dlEnd,ffFixed,15,1)+'%');{$ENDIF}
      End
        else
      Begin
        Result := playableTrue;
        {$IFDEF LOCALTRACE}DebugMsgFT(logPath,'Ready for Playback / 100% progress');{$ENDIF}
      End;

      Break;
    End;
  End;
end;


end.
