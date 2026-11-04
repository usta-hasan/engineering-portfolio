object FormMain: TFormMain
  Left = 0
  Top = 0
  BorderStyle = bsSingle
  BorderIcons = [biSystemMenu, biMinimize]
  Caption = 'Akvarium'
  ClientHeight = 722
  ClientWidth = 1112
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  OldCreateOrder = False
  OnClose = FormClose
  OnCreate = FormCreate
  DesignSize = (
    1112
    722)
  PixelsPerInch = 96
  TextHeight = 13
  object LabelSystemLog: TLabel
    Left = 933
    Top = 6
    Width = 61
    Height = 13
    Anchors = [akTop, akRight]
    Caption = 'SYSTEM LOG'
    ExplicitLeft = 840
  end
  object Panel4: TPanel
    Left = 0
    Top = 0
    Width = 824
    Height = 722
    Align = alClient
    TabOrder = 0
    ExplicitWidth = 826
    object Panel3: TPanel
      AlignWithMargins = True
      Left = 31
      Top = 468
      Width = 762
      Height = 223
      Margins.Left = 30
      Margins.Top = 10
      Margins.Right = 30
      Margins.Bottom = 30
      Align = alBottom
      TabOrder = 0
      ExplicitWidth = 764
      object LabelCompressors: TLabel
        Left = 330
        Top = 6
        Width = 87
        Height = 13
        Caption = 'KOMPRESSORLAR'
      end
      object LabelK1: TLabel
        Left = 88
        Top = 22
        Width = 12
        Height = 13
        Caption = 'K1'
      end
      object LabelK2: TLabel
        Left = 256
        Top = 22
        Width = 12
        Height = 13
        Caption = 'K2'
      end
      object LabelK3: TLabel
        Left = 440
        Top = 22
        Width = 12
        Height = 13
        Caption = 'K3'
      end
      object LabelK4: TLabel
        Left = 608
        Top = 22
        Width = 12
        Height = 13
        Caption = 'K4'
      end
      object LabelJSON: TLabel
        Left = 187
        Top = 108
        Width = 81
        Height = 13
        Caption = 'JSON COMMAND'
      end
      object BitBtn1: TBitBtn
        Left = 48
        Top = 40
        Width = 97
        Height = 57
        Caption = 'On'
        Font.Charset = RUSSIAN_CHARSET
        Font.Color = clWindowText
        Font.Height = -31
        Font.Name = 'Times New Roman'
        Font.Style = []
        ParentFont = False
        TabOrder = 0
        OnClick = MotorClick
      end
      object BitBtn2: TBitBtn
        Left = 216
        Top = 40
        Width = 97
        Height = 57
        Caption = 'On'
        Font.Charset = RUSSIAN_CHARSET
        Font.Color = clWindowText
        Font.Height = -31
        Font.Name = 'Times New Roman'
        Font.Style = []
        ParentFont = False
        TabOrder = 1
        OnClick = MotorClick
      end
      object BitBtn3: TBitBtn
        Left = 400
        Top = 40
        Width = 97
        Height = 57
        Caption = 'On'
        Font.Charset = RUSSIAN_CHARSET
        Font.Color = clWindowText
        Font.Height = -31
        Font.Name = 'Times New Roman'
        Font.Style = []
        ParentFont = False
        TabOrder = 2
        OnClick = MotorClick
      end
      object BitBtn4: TBitBtn
        Left = 568
        Top = 40
        Width = 97
        Height = 57
        Caption = 'On'
        Font.Charset = RUSSIAN_CHARSET
        Font.Color = clWindowText
        Font.Height = -31
        Font.Name = 'Times New Roman'
        Font.Style = []
        ParentFont = False
        TabOrder = 3
        OnClick = MotorClick
      end
      object Edit2: TEdit
        Left = 175
        Top = 127
        Width = 418
        Height = 74
        Font.Charset = RUSSIAN_CHARSET
        Font.Color = clWindowText
        Font.Height = -21
        Font.Name = 'Times New Roman'
        Font.Style = []
        ParentFont = False
        ReadOnly = True
        TabOrder = 4
      end
      object ButtonSend: TButton
        Left = 608
        Top = 120
        Width = 137
        Height = 65
        Caption = 'Send'
        Default = True
        Font.Charset = RUSSIAN_CHARSET
        Font.Color = clWindowText
        Font.Height = -48
        Font.Name = 'Times New Roman'
        Font.Style = []
        ParentFont = False
        TabOrder = 5
        OnClick = ButtonSendClick
      end
      object ButtonComport: TButton
        Left = 16
        Top = 128
        Width = 153
        Height = 65
        Caption = 'Comport'
        Font.Charset = RUSSIAN_CHARSET
        Font.Color = clWindowText
        Font.Height = -35
        Font.Name = 'Times New Roman'
        Font.Style = []
        ParentFont = False
        TabOrder = 6
        OnClick = ButtonComportClick
      end
    end
    object Panel1: TPanel
      AlignWithMargins = True
      Left = 31
      Top = 31
      Width = 762
      Height = 217
      Margins.Left = 30
      Margins.Top = 30
      Margins.Right = 30
      Margins.Bottom = 10
      Align = alTop
      Padding.Left = 30
      Padding.Top = 30
      Padding.Right = 30
      Padding.Bottom = 30
      TabOrder = 1
      ExplicitWidth = 764
      object LabelMin: TLabel
        Left = 80
        Top = 68
        Width = 36
        Height = 13
        Caption = 'MIN O2'
      end
      object LabelCurrent: TLabel
        Left = 280
        Top = 68
        Width = 64
        Height = 13
        Caption = 'CURRENT O2'
      end
      object LabelMax: TLabel
        Left = 528
        Top = 68
        Width = 38
        Height = 13
        Caption = 'MAX O2'
      end
      object LabelMinUnit: TLabel
        Left = 80
        Top = 180
        Width = 23
        Height = 13
        Caption = 'mg/L'
      end
      object LabelCurrentUnit: TLabel
        Left = 280
        Top = 180
        Width = 23
        Height = 13
        Caption = 'mg/L'
      end
      object LabelMaxUnit: TLabel
        Left = 528
        Top = 180
        Width = 23
        Height = 13
        Caption = 'mg/L'
      end
      object LabelO2Status: TLabel
        Left = 370
        Top = 180
        Width = 40
        Height = 13
        Caption = 'O2 LOW'
      end
      object Auto: TCheckBox
        Left = 24
        Top = 40
        Width = 97
        Height = 17
        Caption = 'Auto'
        TabOrder = 0
        OnClick = ModeClick
      end
      object SpinEdit1: TEdit
        Left = 80
        Top = 88
        Width = 177
        Height = 81
        Font.Charset = RUSSIAN_CHARSET
        Font.Color = clWindowText
        Font.Height = -64
        Font.Name = 'Times New Roman'
        Font.Style = []
        ParentFont = False
        TabOrder = 1
        OnExit = AutoLimitsExit
        OnChange = InputChanged
      end
      object SpinEdit2: TEdit
        Left = 528
        Top = 88
        Width = 153
        Height = 81
        Font.Charset = RUSSIAN_CHARSET
        Font.Color = clWindowText
        Font.Height = -64
        Font.Name = 'Times New Roman'
        Font.Style = []
        ParentFont = False
        TabOrder = 2
        OnExit = AutoLimitsExit
        OnChange = InputChanged
      end
      object Edit1: TEdit
        Left = 280
        Top = 88
        Width = 185
        Height = 81
        Alignment = taCenter
        Font.Charset = RUSSIAN_CHARSET
        Font.Color = clWindowText
        Font.Height = -64
        Font.Name = 'Times New Roman'
        Font.Style = []
        ParentFont = False
        ReadOnly = True
        TabOrder = 3
        Text = '0'
      end
    end
    object Panel2: TPanel
      AlignWithMargins = True
      Left = 31
      Top = 268
      Width = 762
      Height = 180
      Margins.Left = 30
      Margins.Top = 10
      Margins.Right = 30
      Margins.Bottom = 10
      Align = alClient
      Padding.Left = 30
      Padding.Top = 30
      Padding.Right = 30
      Padding.Bottom = 30
      TabOrder = 2
      ExplicitWidth = 764
      object LabelMotor1: TLabel
        Left = 48
        Top = 40
        Width = 65
        Height = 13
        Caption = 'Kompressor 1'
      end
      object LabelPercent1: TLabel
        Left = 173
        Top = 90
        Width = 11
        Height = 13
        Caption = '%'
      end
      object LabelMotor2: TLabel
        Left = 216
        Top = 40
        Width = 65
        Height = 13
        Caption = 'Kompressor 2'
      end
      object LabelPercent2: TLabel
        Left = 341
        Top = 90
        Width = 11
        Height = 13
        Caption = '%'
      end
      object LabelMotor3: TLabel
        Left = 400
        Top = 40
        Width = 65
        Height = 13
        Caption = 'Kompressor 3'
      end
      object LabelPercent3: TLabel
        Left = 525
        Top = 90
        Width = 11
        Height = 13
        Caption = '%'
      end
      object LabelMotor4: TLabel
        Left = 568
        Top = 40
        Width = 65
        Height = 13
        Caption = 'Kompressor 4'
      end
      object LabelPercent4: TLabel
        Left = 693
        Top = 90
        Width = 11
        Height = 13
        Caption = '%'
      end
      object qolda: TCheckBox
        Left = 24
        Top = 8
        Width = 97
        Height = 17
        Caption = 'Qo`lda'
        TabOrder = 0
        OnClick = ModeClick
      end
      object SpinEdit3: TSpinEdit
        Left = 48
        Top = 64
        Width = 121
        Height = 65
        Font.Charset = RUSSIAN_CHARSET
        Font.Color = clWindowText
        Font.Height = -48
        Font.Name = 'Times New Roman'
        Font.Style = []
        MaxValue = 0
        MinValue = 0
        ParentFont = False
        TabOrder = 1
        Value = 0
        OnChange = InputChanged
      end
      object SpinEdit4: TSpinEdit
        Left = 216
        Top = 64
        Width = 121
        Height = 65
        Font.Charset = RUSSIAN_CHARSET
        Font.Color = clWindowText
        Font.Height = -48
        Font.Name = 'Times New Roman'
        Font.Style = []
        MaxValue = 0
        MinValue = 0
        ParentFont = False
        TabOrder = 2
        Value = 0
        OnChange = InputChanged
      end
      object SpinEdit5: TSpinEdit
        Left = 568
        Top = 64
        Width = 121
        Height = 65
        Font.Charset = RUSSIAN_CHARSET
        Font.Color = clWindowText
        Font.Height = -48
        Font.Name = 'Times New Roman'
        Font.Style = []
        MaxValue = 0
        MinValue = 0
        ParentFont = False
        TabOrder = 3
        Value = 0
        OnChange = InputChanged
      end
      object SpinEdit6: TSpinEdit
        Left = 400
        Top = 64
        Width = 121
        Height = 65
        Font.Charset = RUSSIAN_CHARSET
        Font.Color = clWindowText
        Font.Height = -48
        Font.Name = 'Times New Roman'
        Font.Style = []
        MaxValue = 0
        MinValue = 0
        ParentFont = False
        TabOrder = 4
        Value = 0
        OnChange = InputChanged
      end
    end
  end
  object Memo1: TMemo
    AlignWithMargins = True
    Left = 832
    Top = 25
    Width = 280
    Height = 697
    Margins.Left = 0
    Margins.Top = 25
    Margins.Right = 0
    Margins.Bottom = 0
    Align = alRight
    Lines.Strings = (
      '')
    ReadOnly = True
    ScrollBars = ssBoth
    TabOrder = 1
    WordWrap = False
  end
  object cxSplitter1: TcxSplitter
    Left = 824
    Top = 0
    Width = 8
    Height = 722
    HotZoneClassName = 'TcxMediaPlayer9Style'
    AlignSplitter = salRight
    AllowHotZoneDrag = False
    Control = Memo1
    OnMoved = LogSplitterMoved
    OnCanResize = LogSplitterCanResize
    ExplicitLeft = 839
    ExplicitTop = 8
  end
  object O2Timer: TTimer
    Enabled = False
    Interval = 200
    OnTimer = O2TimerTimer
    Left = 720
    Top = 32
  end
  object SerialTimer: TTimer
    Enabled = False
    Interval = 100
    OnTimer = SerialTimerTimer
    Left = 760
    Top = 32
  end
  object ComPort1: TComPort
    BaudRate = br9600
    Port = 'COM1'
    Parity.Bits = prNone
    StopBits = sbOneStopBit
    DataBits = dbEight
    Events = [evRxChar, evTxEmpty, evRxFlag, evRing, evBreak, evCTS, evDSR, evError, evRLSD, evRx80Full]
    FlowControl.OutCTSFlow = False
    FlowControl.OutDSRFlow = False
    FlowControl.ControlDTR = dtrDisable
    FlowControl.ControlRTS = rtsDisable
    FlowControl.XonXoffOut = False
    FlowControl.XonXoffIn = False
    StoredProps = [spBasic]
    TriggersOnRxChar = False
    Left = 783
    Top = 111
  end
  object ComDataPacket1: TComDataPacket
    ComPort = ComPort1
    Left = 864
    Top = 120
  end
end

