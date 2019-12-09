{$I PLUGIN_DEFINES.INC}

unit misc_utils_unit;


     {********************************************************************
      | This Source Code is subject to the terms of the                  |
      | Mozilla Public License, v. 2.0. If a copy of the MPL was not     |
      | distributed with this file, You can obtain one at                |
      | https://mozilla.org/MPL/2.0/.                                    |
      |                                                                  |
      | Software distributed under the License is distributed on an      |
      | "AS IS" basis, WITHOUT WARRANTY OF ANY KIND, either express or   |
      | implied. See the License for the specific language governing     |
      | rights and limitations under the License.                        |
      ********************************************************************}

      { This sample code uses the TNT Delphi Unicode Controls (compatiable
        with the last free version) to handle a few unicode tasks. }

interface

uses
  Windows, Classes, TNTClasses, SuperObject;


Const
{$IFDEF LOCALTRACE}
  logPath       : String = 'c:\log\.Torrents_plugin.txt';
  logPathInput  : String = 'c:\log\.Torrents_plugin_input.txt';
{$ENDIF}
  CRLF          : String = #13#10;
  cUserAgent    : String = 'Inmatrix';
  URLIdentifier : String = 'Zoom Player';

function  TickCount64 : Int64;

procedure DebugMsgF(FileName : WideString; Txt : WideString);
procedure DebugMsgFT(FileName : WideString; Txt : WideString);

function  DownloadFileToStringListWithReferer(URL,Referer : String; fStream : TStringList; var Status : String; TimeOut : DWord) : Boolean; overload;
function  DownloadFileToStringListWithReferer(URL,Referer : String; fStream : TStringList) : Boolean; overload;
function  DownloadFileToStream(URL : String; fStream : TMemoryStream) : Boolean; overload;
function  DownloadFileToStream(URL : String; fStream : TMemoryStream; var Status : String; TimeOut : DWord) : Boolean; overload;
function  DownloadFileToStream(URL, Referer : String; fStream : TMemoryStream; var Status : String; TimeOut : DWord) : Boolean; overload;

function  URLEncodeUTF8(stInput : widestring) : string;

function  SetRegDWord(BaseKey : HKey; SubKey : String; KeyEntry : String; KeyValue : Integer) : Boolean;
function  GetRegDWord(BaseKey : HKey; SubKey : String; KeyEntry : String) : Integer;
function  SetRegString(BaseKey : HKey; SubKey : String; KeyEntry : String; KeyValue : String) : Boolean;
function  GetRegString(BaseKey : HKey; SubKey : String; KeyEntry : String) : String;

function  AddBackSlash(S : WideString) : WideString; Overload;
function  ConvertCharsToSpaces(S : WideString) : WideString;

function  DecodeTextTags(S : WideString; RemoveSuffix : Boolean) : WideString;
function  EncodeTextTags(S : WideString; AddSuffix : Boolean) : WideString;

procedure FileExtIntoStringList(fPath,fExt : WideString; fList : TTNTStrings; Recursive : Boolean);

function  CalcGabestHash(const Stream: TStream): Int64; overload;
function  CalcGabestHash(const FileName: WideString): Int64; overload;

function  GetFileSize64(FileName : Widestring) : Int64;
//function  HTTPPostRequest(AData, Referer: AnsiString; Port : Integer): AnsiString;
function  HTTPPostData(UserAgent, Referer, Server : String; Port : Integer; Resource,Header : String; Data: AnsiString) : String;
function  GetWindowsSystemPath(wHandle : HWND; Folder: Integer): WideString;
function  processExists(exeFileName: string): Boolean;
Function  WinExecAndWait32(FileName : WideString; Visibility : integer; waitforexec,console : boolean):integer;
procedure Split(S : WideString; Ch : Char; sList : TTNTStrings);
{$IFDEF TRACEDEBUGMEMORY}
procedure FinalizeDebugList;
{$ENDIF}


implementation

uses
  SysUtils, SyncObjs, TNTSysUtils, wininet, shlobj, activex, tlhelp32;


{type
  TDownloadThread = Class(TThread)
    procedure execute; override;
  public
    DownloadEnded  : PBoolean;
    SuccessCode    : PBoolean;
    URL            : String;
    ImageFilePath  : WideString;
    ImageFileName  : WideString;
    Status         : PString;
    ErrorCode      : PInteger;
    TimeOut        : DWord;
  end;}

var
  TickCountLast    : DWORD = 0;
  TickCountBase    : Int64 = 0;
  DebugStartTime   : Int64 = -1;
  qTimer64Freq     : Int64;
  csDebug          : TCriticalSection;
  {$IFDEF TRACEDEBUGMEMORY}
  DebugList        : TTNTStringList = nil;
  {$ENDIF}


function TickCount64 : Int64;
begin
  Result := GetTickCount;
  If Result < TickCountLast then TickCountBase := TickCountBase+$100000000;
  TickCountLast := Result;
  Result := Result+TickCountBase;
end;


procedure DebugMsgFT(FileName : WideString; Txt : WideString);
var
  S,S1 : String;
  i64  : Int64;
begin
  If FileName <> '' then
  Begin
    QueryPerformanceCounter(i64);
    S := FloatToStrF(((i64-DebugStartTime)*1000) / qTimer64Freq,ffFixed,15,3);
    While Length(S) < 12 do S := ' '+S;
    S1 := DateToStr(Date)+' '+TimeToStr(Time);
    DebugMsgF(FileName,S1+' ['+S+'] : '+Txt);
  End;
end;


procedure DebugMsgF(FileName : WideString; Txt : WideString);
var
  fStream  : TTNTFileStream;
  S        : String;
begin
  If FileName <> '' then
  Begin
    csDebug.Enter;
    Try
      {$IFDEF TRACEDEBUGMEMORY}
      If (DebugList = nil) then DebugList := TTNTStringList.Create else DebugList.Add(FileName+'|'+Txt);
      {$ELSE}
      If WideFileExists(FileName) = True then
      Begin
        Try
          fStream := TTNTFileStream.Create(FileName,fmOpenWrite);
        Except
          fStream := nil;
        End;
      End
        else
      Begin
        Try
           fStream := TTNTFileStream.Create(FileName,fmCreate);
        Except
          fStream := nil;
        End;
      End;
      If fStream <> nil then
      Begin
        S := UTF8Encode(Txt)+CRLF;
        fStream.Seek(0,soFromEnd);
        fStream.Write(S[1],Length(S));
        fStream.Free;
      End;
      {$ENDIF}
    Finally
      csDebug.Leave;
    End;
  End;
end;


function  DownloadFileToStringListWithReferer(URL,Referer : String; fStream : TStringList; var Status : String; TimeOut : DWord) : Boolean;
var
  MemStream : TMemoryStream;
begin
  Result := False;
  If fStream <> nil then
  Begin
    MemStream := TMemoryStream.Create;
    If DownloadFileToStream(URL,Referer,MemStream,Status,TimeOut) = True then
    Begin
      MemStream.Position := 0;
      fStream.LoadFromStream(MemStream);
      Result := True;
    End;
    MemStream.Free;
  End;
end;


function DownloadFileToStringListWithReferer(URL,Referer : String; fStream : TStringList) : Boolean;
var
  Status    : String;
begin
  Result := DownloadFileToStringListWithReferer(URL,Referer,fStream,Status,0);
end;



function DownloadFileToStream(URL : String; fStream : TMemoryStream) : Boolean;
var
  S : String;
begin
  Result := DownloadFileToStream(URL,fStream,S,0);
end;


function DownloadFileToStream(URL : String; fStream : TMemoryStream; var Status : String; TimeOut : DWord) : Boolean;
begin
  Result := DownloadFileToStream(URL,'',fStream,Status,TimeOut);
end;


function DownloadFileToStream(URL, Referer : String; fStream : TMemoryStream; var Status : String; TimeOut : DWord) : Boolean;
type
  DLBufType = Array[0..1024] of Char;
var
  NetHandle  : HINTERNET;
  URLHandle  : HINTERNET;
  DLBuf      : ^DLBufType;
  BytesRead  : DWord;
  ByteCount  : Integer;
  infoBuffer : Array [0..512] of char;
  bufLen     : DWORD;
  Tmp        : DWord;
  pReferer   : PChar;
begin
  Result := False;
  If fStream <> nil then
  Begin
    NetHandle := InternetOpen(PChar(URLIdentifier),INTERNET_OPEN_TYPE_PRECONFIG, nil, nil, 0);
    If Assigned(NetHandle) then
    Begin
      If TimeOut > 0 then
      Begin
        InternetSetOption(NetHandle,INTERNET_OPTION_CONNECT_TIMEOUT,@TimeOut,Sizeof(TimeOut));
        InternetSetOption(NetHandle,INTERNET_OPTION_SEND_TIMEOUT   ,@TimeOut,Sizeof(TimeOut));
        InternetSetOption(NetHandle,INTERNET_OPTION_RECEIVE_TIMEOUT,@TimeOut,Sizeof(TimeOut));
      End;

      If Referer <> '' then
      Begin
        Referer := 'Referer: '+Referer;
        pReferer := PChar(Referer);
      end
      Else pReferer := nil;

      UrlHandle := InternetOpenUrl(NetHandle,PChar(URL),pReferer,Length(Referer),INTERNET_FLAG_RELOAD or INTERNET_FLAG_NO_CACHE_WRITE,0);
      If Assigned(UrlHandle) then
      Begin
        tmp    := 0;
        bufLen := Length(infoBuffer);
        Result := HttpQueryInfo(UrlHandle,HTTP_QUERY_STATUS_CODE,@infoBuffer[0],bufLen,tmp);
        Status := infoBuffer;

        If (Result = True) and (Status = '200') then
        Begin
          New(DLBuf);
          ByteCount := 0;
          Repeat
            ZeroMemory(DLBuf,Sizeof(DLBufType));
            If InternetReadFile(UrlHandle,DLBuf,SizeOf(DLBufType),BytesRead) = True then
            Begin
              If BytesRead > 0 then fStream.Write(DLBuf^,BytesRead);
              Inc(ByteCount,BytesRead);
              If BytesRead = 0 then Result := True; // EOF, non error
            End
              else
            Begin
            End;
          Until (BytesRead = 0);
          Dispose(DLBuf);
        End;
        InternetCloseHandle(UrlHandle);
      End;
      InternetCloseHandle(NetHandle);
    End;
  End;
end;

{
procedure TDownloadThread.execute;
begin
  SuccessCode^   := DownloadImageToFile(URL,ImageFilePath,ImageFileName,Status^,ErrorCode^,TimeOut);
  DownloadEnded^ := True;
end;


procedure DownloadImageToFileThreaded(URL : String; ImageFilePath, ImageFileName : WideString; var Status : String; var ErrorCode: Integer; TimeOut : DWord; var SuccessCode, DownloadEnded : Boolean);
var
  DownloadThread : TDownloadthread;
begin
  DownloadThread                    := TDownloadThread.Create(True);
  DownloadThread.Priority           := tpIdle;
  DownloadThread.FreeOnTerminate    := True;
  DownloadThread.URL                := URL;
  DownloadThread.ImageFilePath      := ImageFilePath;
  DownloadThread.ImageFileName      := ImageFileName;
  DownloadThread.Status             := @Status;
  DownloadThread.ErrorCode          := @ErrorCode;
  DownloadThread.TimeOut            := TimeOut;
  DownloadThread.SuccessCode        := @SuccessCode;
  DownloadThread.SuccessCode^       := False;
  DownloadThread.DownloadEnded      := @DownloadEnded;
  DownloadThread.DownloadEnded^     := False;

  DownloadThread.Resume;
end;}


{function  DownloadImageToFile(URL : String; ImageFilePath, ImageFileName : WideString; var Status : String; var ErrorCode: Integer; TimeOut : DWord) : Boolean;
var
  iStream : TMemoryStream;
  fStream : TTNTFileStream;
begin
  Result := False;
  // Download image to memory stream
  iStream := TMemoryStream.Create;
  iStream.Clear;
  If DownloadFileToStream(URL,iStream,Status,ErrorCode,TimeOut) = True then
  Begin
    If iStream.Size > 0 then
    Begin
      // Create the destination folder if it doesn't exist
      If WideDirectoryExists(ImageFilePath) = False then WideForceDirectories(ImageFilePath);

      // Save the source image to disk
      Try
        fStream := TTNTFileStream.Create(ImageFilePath+ImageFileName,fmCreate);
      Except
        fStream := nil
      End;
      If fStream <> nil then
      Begin
        iStream.Position := 0;
        Try
          fStream.CopyFrom(iStream,iStream.Size);
          Result := True;
        Finally
          fStream.Free;
        End;
      End;
    End;
  End;
  iStream.Free;
end;}


(*
function DownloadImageToFile(URL : String; ImageFilePath, ImageFileName : WideString) : Boolean;
var
  Status    : String;
  ErrorCode : DWord;
begin
  Result := DownloadImageToFile(URL,ImageFilePath,ImageFileName,Status,ErrorCode,0);
end;
(**)


function URLEncodeUTF8(stInput : widestring) : string;
const
  Hex : array[0..255] of string = (
    '%00', '%01', '%02', '%03', '%04', '%05', '%06', '%07',
    '%08', '%09', '%0a', '%0b', '%0c', '%0d', '%0e', '%0f',
    '%10', '%11', '%12', '%13', '%14', '%15', '%16', '%17',
    '%18', '%19', '%1a', '%1b', '%1c', '%1d', '%1e', '%1f',
    '%20', '%21', '%22', '%23', '%24', '%25', '%26', '%27',
    '%28', '%29', '%2a', '%2b', '%2c', '%2d', '%2e', '%2f',
    '%30', '%31', '%32', '%33', '%34', '%35', '%36', '%37',
    '%38', '%39', '%3a', '%3b', '%3c', '%3d', '%3e', '%3f',
    '%40', '%41', '%42', '%43', '%44', '%45', '%46', '%47',
    '%48', '%49', '%4a', '%4b', '%4c', '%4d', '%4e', '%4f',
    '%50', '%51', '%52', '%53', '%54', '%55', '%56', '%57',
    '%58', '%59', '%5a', '%5b', '%5c', '%5d', '%5e', '%5f',
    '%60', '%61', '%62', '%63', '%64', '%65', '%66', '%67',
    '%68', '%69', '%6a', '%6b', '%6c', '%6d', '%6e', '%6f',
    '%70', '%71', '%72', '%73', '%74', '%75', '%76', '%77',
    '%78', '%79', '%7a', '%7b', '%7c', '%7d', '%7e', '%7f',
    '%80', '%81', '%82', '%83', '%84', '%85', '%86', '%87',
    '%88', '%89', '%8a', '%8b', '%8c', '%8d', '%8e', '%8f',
    '%90', '%91', '%92', '%93', '%94', '%95', '%96', '%97',
    '%98', '%99', '%9a', '%9b', '%9c', '%9d', '%9e', '%9f',
    '%a0', '%a1', '%a2', '%a3', '%a4', '%a5', '%a6', '%a7',
    '%a8', '%a9', '%aa', '%ab', '%ac', '%ad', '%ae', '%af',
    '%b0', '%b1', '%b2', '%b3', '%b4', '%b5', '%b6', '%b7',
    '%b8', '%b9', '%ba', '%bb', '%bc', '%bd', '%be', '%bf',
    '%c0', '%c1', '%c2', '%c3', '%c4', '%c5', '%c6', '%c7',
    '%c8', '%c9', '%ca', '%cb', '%cc', '%cd', '%ce', '%cf',
    '%d0', '%d1', '%d2', '%d3', '%d4', '%d5', '%d6', '%d7',
    '%d8', '%d9', '%da', '%db', '%dc', '%dd', '%de', '%df',
    '%e0', '%e1', '%e2', '%e3', '%e4', '%e5', '%e6', '%e7',
    '%e8', '%e9', '%ea', '%eb', '%ec', '%ed', '%ee', '%ef',
    '%f0', '%f1', '%f2', '%f3', '%f4', '%f5', '%f6', '%f7',
    '%f8', '%f9', '%fa', '%fb', '%fc', '%fd', '%fe', '%ff');
var
  iLen,iIndex : integer;
  stEncoded   : string;
  ch          : widechar;
begin
  iLen := Length(stInput);
  stEncoded := '';
  for iIndex := 1 to iLen do
  begin
    ch := stInput[iIndex];
    If (ch >= 'A') and (ch <= 'Z') then stEncoded := stEncoded + ch
      else
    If (ch >= 'a') and (ch <= 'z') then stEncoded := stEncoded + ch
      else
    If (ch >= '0') and (ch <= '9') then stEncoded := stEncoded + ch
      else
    If (ch = ' ') then stEncoded := stEncoded + '%20'//'+'
      else
    If ((ch = '-') or (ch = '_') or (ch = '.') or (ch = '!') or (ch = '*') or (ch = '~') or (ch = '\')  or (ch = '(') or (ch = ')')) then stEncoded := stEncoded + ch
      else
    If (Ord(ch) <= $07F) then stEncoded := stEncoded + hex[Ord(ch)]
      else
    If (Ord(ch) <= $7FF) then
    begin
      stEncoded := stEncoded + hex[$c0 or (Ord(ch) shr 6)];
      stEncoded := stEncoded + hex[$80 or (Ord(ch) and $3F)];
    end
      else
    begin
      stEncoded := stEncoded + hex[$e0 or (Ord(ch) shr 12)];
      stEncoded := stEncoded + hex[$80 or ((Ord(ch) shr 6) and ($3F))];
      stEncoded := stEncoded + hex[$80 or ((Ord(ch)) and ($3F))];
    end;
  end;
  result := (stEncoded);
end;


function SetRegDWord(BaseKey : HKey; SubKey : String; KeyEntry : String; KeyValue : Integer) : Boolean;
var
  RegHandle : HKey;
  I         : Integer;
begin
  Result := False;
  If RegCreateKeyEx(BaseKey,PChar(SubKey),0,nil,REG_OPTION_NON_VOLATILE,KEY_ALL_ACCESS,nil,RegHandle,@I) = ERROR_SUCCESS then
  Begin
    If RegSetValueEx(RegHandle,PChar(KeyEntry),0,REG_DWORD,@KeyValue,4) = ERROR_SUCCESS then Result := True;
    RegCloseKey(RegHandle);
  End;
end;


function GetRegDWord(BaseKey : HKey; SubKey : String; KeyEntry : String) : Integer;
var
  RegHandle : HKey;
  RegType   : LPDWord;
  BufSize   : LPDWord;
  KeyValue  : Integer;
begin
  Result := -1;
  If RegOpenKeyEx(BaseKey,PChar(SubKey),0,KEY_READ,RegHandle) = ERROR_SUCCESS then
  Begin
    New(RegType);
    New(BufSize);
    RegType^ := Reg_DWORD;
    BufSize^ := 4;
    If RegQueryValueEx(RegHandle,PChar(KeyEntry),nil,RegType,@KeyValue,BufSize) = ERROR_SUCCESS then
    Begin
      Result := KeyValue;
    End;
    Dispose(BufSize);
    Dispose(RegType);
    RegCloseKey(RegHandle);
  End;
end;


function  GetRegString(BaseKey : HKey; SubKey : String; KeyEntry : String) : String;
var
  RegHandle : HKey;
  RegType   : LPDWord;
  BufSize   : LPDWord;
  KeyValue  : String;
begin
  Result := '';
  If RegOpenKeyEx(BaseKey,PChar(SubKey),0,KEY_READ,RegHandle) = ERROR_SUCCESS then
  Begin
    New(RegType);
    New(BufSize);
    RegType^ := Reg_SZ;
    BufSize^ := 1024;
    SetLength(KeyValue,1024);
    If RegQueryValueEx(RegHandle,PChar(KeyEntry),nil,RegType,@KeyValue[1],BufSize) = ERROR_SUCCESS then
    Begin
      If BufSize^ > 0 then SetLength(KeyValue,BufSize^-1) else KeyValue := '';
      Result := KeyValue;
    End;
    Dispose(BufSize);
    Dispose(RegType);
    RegCloseKey(RegHandle);
  End;
end;


function SetRegString(BaseKey : HKey; SubKey : String; KeyEntry : String; KeyValue : String) : Boolean;
var
  RegHandle : HKey;
  S         : String;
  I         : Integer;
begin
  Result := False;
  If RegCreateKeyEx(BaseKey,PChar(SubKey),0,nil,REG_OPTION_NON_VOLATILE,KEY_ALL_ACCESS,nil,RegHandle,@I) = ERROR_SUCCESS then
  Begin
    S := KeyValue;
    Result := RegSetValueEx(RegHandle,@KeyEntry[1],0,REG_SZ,@S[1],Length(S)) = ERROR_SUCCESS;
    RegCloseKey(RegHandle);
  End;
end;




function AddBackSlash(S : WideString) : WideString; Overload;
var I : Integer;
begin
  I := Length(S);
  If I > 0 then If (S[I] <> '\') and (S[I] <> '/') then S := S+'\';
  Result := S;
end;


function ConvertCharsToSpaces(S : WideString) : WideString;
begin
  Result := TNT_WideStringReplace(TNT_WideStringReplace(TNT_WideStringReplace(S,'-', ' ', [rfReplaceAll]), '.', ' ', [rfReplaceAll]), '_', ' ', [rfReplaceAll]);
end;


procedure FileExtIntoStringList(fPath,fExt : WideString; fList : TTNTStrings; Recursive : Boolean);
var
  sRec : TSearchRecW;
begin
  If WideFindFirst(fPath+'*.*',faAnyFile,sRec) = 0 then
  Begin
    Repeat
      If (Recursive = True) and (sRec.Attr and faDirectory = faDirectory) and (sRec.Name <> '.') and (sRec.Name <> '..') then
      Begin
        FileExtIntoStringList(AddBackSlash(fPath+sRec.Name),fExt,fList,Recursive);
      End
        else
      If (sRec.Attr and faVolumeID = 0) and (sRec.Attr and faDirectory = 0) then
      Begin
        If WideCompareText(WideExtractFileExt(sRec.Name),fExt) = 0 then
          fList.Add(fPath+sRec.Name);
      End;
    Until WideFindNext(sRec) <> 0;
    WideFindClose(sRec);
  End;
end;


function DecodeTextTags(S : WideString; RemoveSuffix : Boolean) : WideString;
var
  S1 : WideString;
begin
  If RemoveSuffix = True then S1 := ';' else S1 := '';
  S := TNT_WideStringReplace(S,'&apos' +S1,'''',[rfReplaceAll]);
  S := TNT_WideStringReplace(S,'&comma'+S1,',' ,[rfReplaceAll]);
  S := TNT_WideStringReplace(S,'&quot' +S1,'"' ,[rfReplaceAll]);
  S := TNT_WideStringReplace(S,'&lt'   +S1,'<' ,[rfReplaceAll]);
  S := TNT_WideStringReplace(S,'&gt'   +S1,'>' ,[rfReplaceAll]);
  S := TNT_WideStringReplace(S,'&amp'  +S1,'&' ,[rfReplaceAll]);
  S := TNT_WideStringReplace(S,'&pipe' +S1,'|' ,[rfReplaceAll]);
  Result := S;
end;


function EncodeTextTags(S : WideString; AddSuffix : Boolean) : WideString;
var
  S1 : WideString;
begin
  If AddSuffix = True then S1 := ';' else S1 := '';
  S := TNT_WideStringReplace(S,'&' ,'&amp'  +S1,[rfReplaceAll]);
  S := TNT_WideStringReplace(S,'''','&apos' +S1,[rfReplaceAll]);
  S := TNT_WideStringReplace(S,',' ,'&comma'+S1,[rfReplaceAll]);
  S := TNT_WideStringReplace(S,'"' ,'&quot' +S1,[rfReplaceAll]);
  S := TNT_WideStringReplace(S,'<' ,'&lt'   +S1,[rfReplaceAll]);
  S := TNT_WideStringReplace(S,'>' ,'&gt'   +S1,[rfReplaceAll]);
  S := TNT_WideStringReplace(S,'|' ,'&pipe' +S1,[rfReplaceAll]);
  S := TNT_WideStringReplace(S,CRLF,'\n'    +S1,[rfReplaceAll]);
  Result := S;
end;


function CalcGabestHash(const Stream: TStream): Int64; overload;
const HashPartSize = 1 shl 16; // 64 KiB

  procedure UpdateHashFromStream(const Stream: TStream; var Hash: Int64);
  var buffer: Array[0..HashPartSize div SizeOf(Int64) - 1] of Int64;
      i     : integer;
  begin
    Stream.ReadBuffer(buffer[0], SizeOf(buffer));
    for i := Low(buffer) to High(buffer) do
      Inc(Hash, buffer[i]);
  end;

begin
  result := Stream.Size;

  if result < HashPartSize then
  begin
    // stream too small return invalid hash
    result := 0;
    exit;
  end;

  // first 64 KiB
  Stream.Position:= 0;
  UpdateHashFromStream(Stream, result);

  // last 64 KiB
  Stream.Seek(-HashPartSize, soEnd);
  UpdateHashFromStream(Stream, result);

  // use "IntToHex(result, 16);" to get a string and "StrToInt64('$' + hash);" to get your Int64 back
end;


function CalcGabestHash(const FileName: WideString): Int64; overload;
var stream: TStream;
begin
  Stream := TTNTFileStream.Create(FileName, fmOpenRead or fmShareDenyWrite);
  Try
    Result := CalcGabestHash(stream);
  Except
    Result := 0;
  End;
  Stream.Free;
end;



function GetFileSize64(FileName : Widestring) : Int64;
var
  nLen  : Integer;
  fData : WIN32_FILE_ATTRIBUTE_DATA;
begin
  Result := -1;
  nLen := Length(FileName);
  If (nLen > 0) then
  Begin
    If Char(FileName[nLen]) in ['\','/'] then FileName := Copy(FileName,1,nLen-1);

    If Win32PlatformIsUnicode = False then
    Begin
      If GetFileAttributesExA(PChar(String(FileName)),GetFileExInfoStandard,@fData) = True then
        If fData.dwFileAttributes and FILE_ATTRIBUTE_DIRECTORY = 0 then
      Begin
        Int64Rec(Result).Lo := fData.nFileSizeLow;
        Int64Rec(Result).Hi := fData.nFileSizeHigh;
      End;
    End
      else
    Begin
      If GetFileAttributesExW(PWideChar(FileName),GetFileExInfoStandard,@fData) = True then
        If fData.dwFileAttributes and FILE_ATTRIBUTE_DIRECTORY = 0 then
      Begin
        Int64Rec(Result).Lo := fData.nFileSizeLow;
        Int64Rec(Result).Hi := fData.nFileSizeHigh;
      End;
    End;
  End;
end;



{function HTTPPostRequest(AData, Referer: AnsiString; Port : Integer): AnsiString;
var
  aBuffer     : Array[0..4096] of Char;
  Header      : TStringStream;
  BufStream   : TMemoryStream;
  BytesRead   : Cardinal;
  pSession    : HINTERNET;
  pConnection : HINTERNET;
  pRequest    : HINTERNET;
  //parsedURL   : TStringArray;
  flags       : DWord;
begin
  Result := '';

  pSession := InternetOpen(PChar(URLIdentifier), INTERNET_OPEN_TYPE_PRECONFIG, nil, nil, 0);

  if Assigned(pSession) then
  try
    pConnection := InternetConnect(pSession, PChar('127.0.0.1'), port, nil, nil, INTERNET_SERVICE_HTTP, 0, 0);


    if Assigned(pConnection) then
    try
      flags := INTERNET_SERVICE_HTTP;

      pRequest := HTTPOpenRequest(pConnection, 'POST', PChar(''), nil, nil, nil, flags, 0);

      if Assigned(pRequest) then
      try
        Header := TStringStream.Create('');
        try
          with Header do
          begin
            WriteString('Host: LocalHost' + sLineBreak);
            WriteString('Referer: '+Referer+SLineBreak);
            WriteString('User-Agent: '+URLIdentifier+SLineBreak);
            WriteString('Content-Type: multipart/form-data; boundary=---------------------------6688794727912'+SLineBreak);
            WriteString('Content-Length: '+IntToStr(Length(AData))+SLineBreak);
            //WriteString('Accept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8'+SLineBreak);
            //WriteString('Accept-Language: en-us,en;q=0.5' + SLineBreak);
            //WriteString('Accept-Charset: ISO-8859-1,utf-8;q=0.7,*;q=0.7'+SLineBreak);
            WriteString('Keep-Alive: 300'+ SLineBreak);
            WriteString('Connection: keep-alive'+ SlineBreak+SLineBreak);
          end;

          HttpAddRequestHeaders(pRequest, PChar(Header.DataString), Length(Header.DataString), HTTP_ADDREQ_FLAG_ADD);

          if HTTPSendRequest(pRequest, nil, 0, Pointer(AData), Length(AData)) then
          begin
            BufStream := TMemoryStream.Create;
            try
              while InternetReadFile(pRequest, @aBuffer, SizeOf(aBuffer), BytesRead) do
              begin
                if (BytesRead = 0) then Break;
                BufStream.Write(aBuffer, BytesRead);
              end;

              aBuffer[0] := #0;
              BufStream.Write(aBuffer, 1);
              Result := PChar(BufStream.Memory);
            finally
              BufStream.Free;
            end;
          end;
        finally
          Header.Free;
        end;
      finally
        InternetCloseHandle(pRequest);
      end;
    finally
      InternetCloseHandle(pConnection);
    end;
  finally
    InternetCloseHandle(pSession);
  end;
end;}


function HTTPPostData(UserAgent, Referer, Server : String; Port : Integer; Resource, Header : String; Data: AnsiString) : String;
var
  hInet   : HINTERNET;
  hHTTP   : HINTERNET;
  hReq    : HINTERNET;
  Buffer  : array[0..1023] of AnsiChar;
  sHeader : String;
  i, BufferLen: Cardinal;
const
  accept: packed array[0..1] of LPWSTR = ('*/*', nil);
begin
  Result := '';

  sHeader := Header+CRLF+'Referer : '+Referer;

  hInet := InternetOpen(PChar(UserAgent), INTERNET_OPEN_TYPE_PRECONFIG, nil, nil, 0);
  try
    hHTTP := InternetConnect(hInet, PChar(Server), Port, nil, nil, INTERNET_SERVICE_HTTP, 0, 1);
    try
      hReq := HttpOpenRequest(hHTTP, PChar('POST'), PChar(Resource), nil, nil, @accept, 0, 1);
      try
        if not HttpSendRequest(hReq, PChar(sHeader), Length(sHeader), PChar(Data), Length(Data)) then
          raise Exception.Create('HttpOpenRequest failed. ' + SysErrorMessage(GetLastError));
        repeat
          InternetReadFile(hReq, @Buffer, SizeOf(Buffer), BufferLen);
          if BufferLen = SizeOf(Buffer) then
            Result := Result + AnsiString(Buffer)
          else if BufferLen > 0 then
            for i := 0 to BufferLen - 1 do
              Result := Result + Buffer[i];
        until BufferLen = 0;
      finally
        InternetCloseHandle(hReq);
      end;
    finally
      InternetCloseHandle(hHTTP);
    end;
  finally
    InternetCloseHandle(hInet);
  end;
end;


function GetWindowsSystemPath(wHandle : HWND; Folder: Integer): WideString;
var
  PIDL: PItemIDList;
  Path: LPSTR;
  AMalloc: IMalloc;
begin
  Result := '';
  Path := StrAlloc(MAX_PATH);
  SHGetSpecialFolderLocation(wHandle, Folder, PIDL);
  If SHGetPathFromIDList(PIDL, Path) then Result := Path;
  SHGetMalloc(AMalloc);
  AMalloc.Free(PIDL);
  StrDispose(Path);
end;


function processExists(exeFileName: string): Boolean;
var
  ContinueLoop: BOOL;
  FSnapshotHandle: THandle;
  FProcessEntry32: TProcessEntry32;
begin
  FSnapshotHandle := CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
  FProcessEntry32.dwSize := SizeOf(FProcessEntry32);
  ContinueLoop := Process32First(FSnapshotHandle, FProcessEntry32);
  Result := False;
  while Integer(ContinueLoop) <> 0 do
  begin
    if ((UpperCase(ExtractFileName(FProcessEntry32.szExeFile)) =
      UpperCase(ExeFileName)) or (UpperCase(FProcessEntry32.szExeFile) =
      UpperCase(ExeFileName))) then
    begin
      Result := True;
    end;
    ContinueLoop := Process32Next(FSnapshotHandle, FProcessEntry32);
  end;
  CloseHandle(FSnapshotHandle);
end;


Function WinExecAndWait32(FileName : WideString; Visibility : integer; waitforexec,console : boolean):integer;
var
  FileNameA   : String;
  //WorkDir     : WideString;
  StartupInfo : TStartupInfo;
  ProcessInfo : TProcessInformation;
  RunResult   : LongBool;
  ECResult    : LongWord;
  Flags       : DWord;
  S,S1        : WideString;
begin
  FillChar(StartupInfo,Sizeof(StartupInfo),0);
  StartupInfo.cb          := Sizeof(StartupInfo);
  StartupInfo.dwFlags     := STARTF_USESHOWWINDOW;
  StartupInfo.wShowWindow := Visibility;
  If Console then Flags := CREATE_NEW_CONSOLE or NORMAL_PRIORITY_CLASS else Flags := NORMAL_PRIORITY_CLASS;

  If Win32PlatformIsUnicode = True then
  Begin
    FileName := FileName+#0;
    RunResult :=
      CreateProcessW(nil,
      @FileName[1],                  { pointer to command line string }
      nil,                           { pointer to process security attributes }
      nil,                           { pointer to thread security attributes }
      false,                         { handle inheritance flag }
      Flags,                         { creation flags }
      nil,                           { pointer to new environment block }
      nil,                           { pointer to current directory name }
      StartupInfo,                   { pointer to STARTUPINFO }
      ProcessInfo);                  { pointer to PROCESS_INF }
  End
    else
  Begin
    FileNameA := FileName+#0;
    RunResult :=
      CreateProcessA(nil,
      @FileNameA[1],                 { pointer to command line string }
      nil,                           { pointer to process security attributes }
      nil,                           { pointer to thread security attributes }
      false,                         { handle inheritance flag }
      flags,                         { creation flags }
      nil,                           { pointer to new environment block }
      nil,                           { pointer to current directory name }
      StartupInfo,                   { pointer to STARTUPINFO }
      ProcessInfo);                  { pointer to PROCESS_INF }
  End;
  If RunResult = False then Result := -1 else
  Begin
    If WaitForExec = True then
    Begin
      WaitforSingleObject(ProcessInfo.hProcess,INFINITE);
      GetExitCodeProcess(ProcessInfo.hProcess,ECResult);
      Result := ECResult;
    End
    Else Result := 0;
    CloseHandle(ProcessInfo.hProcess);
    CloseHandle(ProcessInfo.hThread);
  end;
end;


procedure Split(S : WideString; Ch : Char; sList : TTNTStrings); overload;
var
  I : Integer;
begin
  While Pos(Ch,S) > 0 do
  Begin
    I := Pos(Ch,S);
    sList.Add(Copy(S,1,I-1));
    Delete(S,1,I);
  End;
  If Length(S) > 0 then sList.Add(S);
end;


{$IFDEF TRACEDEBUGMEMORY}
procedure FinalizeDebugList;
var
  I,iPos    : Integer;
  FileName  : WideString;
  Txt       : WideString;
  sList     : TTNTStringList;
  fStream   : TTNTFileStream;
  S         : String;
begin
  If DebugList <> nil then
  Begin
    sList := TTNTStringList.Create;
    For I := 0 to DebugList.Count-1 do
    Begin
      sList.Clear;
      Split(DebugList[I],'|',sList);
      FileName := sList[0];
      If sList.Count > 1 then Txt := sList[1] else Txt := '';

      If WideFileExists(FileName) = True then
      Begin
        Try
          fStream := TTNTFileStream.Create(FileName,fmOpenWrite);
        Except
          fStream := nil;
        End;
      End
        else
      Begin
        Try
          fStream := TTNTFileStream.Create(FileName,fmCreate);
        Except
          fStream := nil;
        End;
      End;
      If fStream <> nil then
      Begin
        S := UTF8Encode(Txt)+CRLF;
        fStream.Seek(0,soFromEnd);
        fStream.Write(S[1],Length(S));
        fStream.Free;
      End;
    End;
    sList.Free;
    DebugList.Free;
  End;
end;
{$ENDIF}




initialization
  QueryPerformanceFrequency(qTimer64Freq);
  QueryPerformanceCounter(DebugStartTime);
  csDebug := TCriticalSection.Create;

finalization
  csDebug.Free;

end.

