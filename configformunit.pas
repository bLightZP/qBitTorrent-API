{$I PLUGIN_DEFINES.INC}

unit configformunit;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, TntStdCtrls, Buttons, TntButtons, ExtCtrls;

type
  TConfigForm = class(TForm)
    OKButton: TButton;
    CancelButton: TButton;
    QBittorrentGB: TTntGroupBox;
    LabelQBitPort: TTntLabel;
    OPQBitTorrentEnabled: TTntCheckBox;
    OPqBitTorrentPort: TTntEdit;
    LabelQbitDLFolder: TTntLabel;
    OPQBitTorrentDLFolder: TTntEdit;
    LabelQbitDLSpeed: TTntLabel;
    OPQBitTorrentDLSpeed: TTntEdit;
    LabelQbitULSpeed: TTntLabel;
    OPQBitTorrentULSpeed: TTntEdit;
    MediaReadyGB: TTntGroupBox;
    OPqBitTorrentDLStart: TTntEdit;
    LabelDLStart: TTntLabel;
    LabelPctStart: TTntLabel;
    OPqBitTorrentDLEnd: TTntEdit;
    LabelDLEnd: TTntLabel;
    LabelPctEnd: TTntLabel;
    ShapeNotRunning: TShape;
    LabelNotRunning: TTntLabel;
    OPQBitTorrentSkipFiles: TTntCheckBox;
    OPQBitTorrentSkipDND: TTntCheckBox;
    procedure FormKeyPress(Sender: TObject; var Key: Char);
    procedure FormCreate(Sender: TObject);
    procedure FormActivate(Sender: TObject);
    procedure OPqBitTorrentPortKeyPress(Sender: TObject; var Key: Char);
    procedure OPqBitTorrentDLStartKeyPress(Sender: TObject; var Key: Char);
  private
    { Private declarations }
  public
    { Public declarations }
    FormAfterActivate : Boolean;
  end;

var
  ConfigForm: TConfigForm = nil;

implementation

{$R *.dfm}

uses shellapi;


procedure TConfigForm.FormKeyPress(Sender: TObject; var Key: Char);
begin
  If Key = #27 then
  Begin
    Key := #0;
    Close;
  End;
end;


procedure TConfigForm.FormCreate(Sender: TObject);
begin
  FormAfterActivate := False;
end;


procedure TConfigForm.FormActivate(Sender: TObject);
begin
  FormAfterActivate := True;
end;


procedure TConfigForm.OPqBitTorrentPortKeyPress(Sender: TObject;
  var Key: Char);
begin
  If Key in [#8,'0'..'9'] = False then Key := #0;
end;


procedure TConfigForm.OPqBitTorrentDLStartKeyPress(Sender: TObject;
  var Key: Char);
begin
  If Key in [#8,',','.','0'..'9'] = False then Key := #0;
end;

end.
