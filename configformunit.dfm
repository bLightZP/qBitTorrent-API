object ConfigForm: TConfigForm
  Left = 667
  Top = 279
  BorderStyle = bsDialog
  Caption = 'Plugin configuration'
  ClientHeight = 331
  ClientWidth = 391
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'MS Sans Serif'
  Font.Style = []
  KeyPreview = True
  OldCreateOrder = False
  OnActivate = FormActivate
  OnCreate = FormCreate
  OnKeyPress = FormKeyPress
  PixelsPerInch = 96
  TextHeight = 13
  object ShapeNotRunning: TShape
    Left = 100
    Top = 292
    Width = 191
    Height = 25
    Brush.Color = clRed
    Pen.Color = clWhite
    Pen.Style = psDot
    Visible = False
  end
  object LabelNotRunning: TTntLabel
    Left = 136
    Top = 298
    Width = 120
    Height = 13
    Caption = 'qBittornet is not running!!!'
    Color = clWhite
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clWhite
    Font.Height = -11
    Font.Name = 'MS Sans Serif'
    Font.Style = []
    ParentColor = False
    ParentFont = False
    Transparent = True
    Visible = False
  end
  object OKButton: TButton
    Left = 303
    Top = 289
    Width = 75
    Height = 30
    Caption = 'OK'
    ModalResult = 1
    TabOrder = 1
  end
  object CancelButton: TButton
    Left = 12
    Top = 289
    Width = 75
    Height = 30
    Caption = 'Cancel'
    ModalResult = 2
    TabOrder = 2
  end
  object QBittorrentGB: TTntGroupBox
    Left = 12
    Top = 8
    Width = 367
    Height = 193
    Caption = ' qBittorrent file tracking : '
    TabOrder = 0
    object LabelQBitPort: TTntLabel
      Left = 12
      Top = 57
      Width = 75
      Height = 13
      Caption = 'Connection port'
    end
    object LabelQbitDLFolder: TTntLabel
      Left = 12
      Top = 105
      Width = 260
      Height = 13
      Caption = 'Download Folder (leave empty for qBittorrent'#39's default) :'
    end
    object LabelQbitDLSpeed: TTntLabel
      Left = 135
      Top = 57
      Width = 89
      Height = 13
      Caption = 'Download limit (kb)'
    end
    object LabelQbitULSpeed: TTntLabel
      Left = 259
      Top = 57
      Width = 75
      Height = 13
      Caption = 'Upload limit (kb)'
    end
    object OPQBitTorrentEnabled: TTntCheckBox
      Left = 10
      Top = 26
      Width = 83
      Height = 17
      Caption = 'Enabled'
      TabOrder = 0
    end
    object OPqBitTorrentPort: TTntEdit
      Left = 10
      Top = 71
      Width = 100
      Height = 21
      MaxLength = 5
      TabOrder = 1
      OnKeyPress = OPqBitTorrentPortKeyPress
    end
    object OPQBitTorrentDLFolder: TTntEdit
      Left = 10
      Top = 119
      Width = 347
      Height = 21
      TabOrder = 4
    end
    object OPQBitTorrentDLSpeed: TTntEdit
      Left = 133
      Top = 71
      Width = 100
      Height = 21
      TabOrder = 2
      OnKeyPress = OPqBitTorrentPortKeyPress
    end
    object OPQBitTorrentULSpeed: TTntEdit
      Left = 257
      Top = 71
      Width = 100
      Height = 21
      TabOrder = 3
      OnKeyPress = OPqBitTorrentPortKeyPress
    end
    object OPQBitTorrentSkipFiles: TTntCheckBox
      Left = 10
      Top = 146
      Width = 347
      Height = 17
      Caption = 'Skip files that do not exist (never downloaded/erased/etc...)'
      TabOrder = 5
    end
    object OPQBitTorrentSkipDND: TTntCheckBox
      Left = 10
      Top = 167
      Width = 347
      Height = 17
      Caption = 'Skip files marked as "do not download"'
      TabOrder = 6
    end
  end
  object MediaReadyGB: TTntGroupBox
    Left = 12
    Top = 206
    Width = 365
    Height = 71
    Caption = ' Mark media as ready for playback when downloaded : '
    TabOrder = 3
    object LabelDLStart: TTntLabel
      Left = 60
      Top = 23
      Width = 80
      Height = 13
      Alignment = taCenter
      AutoSize = False
      Caption = 'start of file'
    end
    object LabelPctStart: TTntLabel
      Left = 142
      Top = 41
      Width = 8
      Height = 13
      Caption = '%'
    end
    object LabelDLEnd: TTntLabel
      Left = 208
      Top = 23
      Width = 80
      Height = 13
      Alignment = taCenter
      AutoSize = False
      Caption = 'end of file'
    end
    object LabelPctEnd: TTntLabel
      Left = 290
      Top = 41
      Width = 8
      Height = 13
      Caption = '%'
    end
    object OPqBitTorrentDLStart: TTntEdit
      Left = 60
      Top = 37
      Width = 80
      Height = 21
      TabOrder = 0
      OnKeyPress = OPqBitTorrentDLStartKeyPress
    end
    object OPqBitTorrentDLEnd: TTntEdit
      Left = 208
      Top = 37
      Width = 80
      Height = 21
      TabOrder = 1
      OnKeyPress = OPqBitTorrentDLStartKeyPress
    end
  end
end
