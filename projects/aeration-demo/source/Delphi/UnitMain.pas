unit UnitMain;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Classes, System.Math, System.JSON,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.ExtCtrls,
  Vcl.StdCtrls, Vcl.Samples.Spin, Vcl.Buttons, cxGraphics, cxControls,
  cxLookAndFeels, cxLookAndFeelPainters, dxSkinsCore, dxSkinsDefaultPainters,
  cxSplitter, CPort;

type
  TMotorValues = array[0..3] of Integer;
  TBitBtn = class(Vcl.Buttons.TBitBtn)
  private
    FStateColor: TColor;
    procedure CNDrawItem(var Message: TWMDrawItem); message CN_DRAWITEM;
  public
    property StateColor: TColor read FStateColor write FStateColor;
  end;

  TFormMain = class(TForm)
    Panel1: TPanel;
    Panel3: TPanel;
    Panel4: TPanel;
    Panel2: TPanel;
    Memo1: TMemo;
    cxSplitter1: TcxSplitter;
    Auto: TCheckBox;
    qolda: TCheckBox;
    SpinEdit1: TEdit;
    SpinEdit2: TEdit;
    Edit1: TEdit;
    SpinEdit3: TSpinEdit;
    SpinEdit4: TSpinEdit;
    SpinEdit5: TSpinEdit;
    SpinEdit6: TSpinEdit;
    BitBtn1: TBitBtn;
    BitBtn2: TBitBtn;
    BitBtn3: TBitBtn;
    BitBtn4: TBitBtn;
    Edit2: TEdit;
    ButtonSend: TButton;
    ButtonComport: TButton;
    O2Timer: TTimer;
    SerialTimer: TTimer;
    LabelO2Status: TLabel;
    LabelSystemLog: TLabel;
    ComPort1: TComPort;
    ComDataPacket1: TComDataPacket;
    procedure InputChanged(Sender: TObject);
    procedure LogSplitterCanResize(Sender: TObject; var NewSize: Integer; var Accept: Boolean);
    procedure LogSplitterMoved(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure ModeClick(Sender: TObject);
    procedure MotorClick(Sender: TObject);
    procedure ButtonSendClick(Sender: TObject);
    procedure ButtonComportClick(Sender: TObject);
    procedure O2TimerTimer(Sender: TObject);
    procedure SerialTimerTimer(Sender: TObject);
    procedure AutoLimitsExit(Sender: TObject);
  private
    FMotorEnabled: array[0..3] of Boolean;
    FSpeeds: array[0..3] of TSpinEdit;
    FButtons: array[0..3] of TBitBtn;
    FApplied: TMotorValues;
    FLastSpeed: TMotorValues;
    FUpdating: Boolean;
    FInitialized: Boolean;
    function PreviewJSON(out S: string): Boolean;
    procedure LogJSONEvent(const EventText, JSON: string);
  private
    FLogWidth: Integer;
    FClosing: Boolean;
    FApplyQueued: Boolean;
    FApplying: Boolean;
    FComHandle: THandle;
    FComName: string;
    FReceiveBuffer: AnsiString;
    FReceiveOverflow: Boolean;
    FPendingJSON: string;
    FReadyAt: UInt64;
    FInFlightJSON: string;
    FAckDeadline: UInt64;
    FAwaitingAck: Boolean;
    FDemoMode: Boolean;
    FO2Running: Boolean;
    FO2Start: Double;
    FO2End: Double;
    FO2StartedAt: UInt64;
    FO2Duration: Cardinal;
    FO2NoiseEnabled: Boolean;
    FO2NoiseAt: UInt64;
    procedure StartO2Transition;
    procedure ApplyAutoAfterExit(var Message: TMessage); message WM_APP + 42;
    procedure SetMode(Automatic: Boolean);
    function ApplySettings(const EventText: string = ''; ShowErrors: Boolean = True): Boolean;
    function ReadMotorValues(out P: TMotorValues): Boolean;
    procedure CommitMotors(const P: TMotorValues; const EventText: string; Transmit: Boolean = True);
    procedure SetTargetFromApplied;
    function WriteJSON(const S: string): Boolean;
  protected
    function O2Clock: UInt64; virtual;
    function SerialClock: UInt64; virtual;
    function SerialConnected: Boolean; virtual;
    function SerialWrite(const Data: AnsiString; out Written: DWORD): Boolean; virtual;
    function SerialRead(var Buffer; Size: DWORD; out Count: DWORD): Boolean; virtual;
    procedure CloseSerialTransport; virtual;
    procedure SerialSessionOpened(const Port: string);
  public
    CurrentO2: Double;
    TargetO2: Double;
    procedure AddLog(const S: string);
    procedure SendJSON(const S: string);
    procedure UpdateO2Status;
    procedure UpdateMotorControls;
    procedure ConnectComPort;
    procedure DisconnectComPort(StopMotors: Boolean = True);
    procedure ProcessSerialLine(const S: string);
    procedure SetMeasuredO2(const Value: Double);
  end;

function ParseMotorReply(const S: string; out P: TMotorValues; out ErrorText: string): Integer;
function CalculateO2(P1, P2, P3, P4: Integer): Double;
function BuildMotorJSON(P1, P2, P3, P4: Integer): string;
function ParseFloatFlexible(const S: string; out Value: Double): Boolean;

var
  FormMain: TFormMain;

implementation

{$R *.dfm}

function ParseMotorReply(const S: string; out P: TMotorValues; out ErrorText: string): Integer;
var
  Root, Value: TJSONValue;
  Obj: TJSONObject;
  I, OK: Integer;
  function IntegerField(const Name: string; out N: Integer): Boolean;
  var
    V: TJSONValue;
  begin
    V := Obj.GetValue(Name);
    Result := (V is TJSONNumber) and TryStrToInt(V.Value, N);
  end;
begin
  Result := -1;
  FillChar(P, SizeOf(P), 0);
  ErrorText := '';
  Root := TJSONObject.ParseJSONValue(S);
  try
    if not (Root is TJSONObject) then Exit;
    Obj := TJSONObject(Root);
    if not IntegerField('ok', OK) then Exit;
    if OK = 1 then
    begin
      if Obj.Count <> 5 then Exit;
      for I := 0 to 3 do
        if not IntegerField('m' + IntToStr(I + 1), P[I]) or
           (P[I] < 0) or (P[I] > 100) then Exit;
      if Trim(S) <> Format('{"ok":1,"m1":%d,"m2":%d,"m3":%d,"m4":%d}',
        [P[0], P[1], P[2], P[3]]) then Exit;
      Result := 1;
    end
    else if OK = 0 then
    begin
      if Obj.Count <> 2 then Exit;
      Value := Obj.GetValue('error');
      if not (Value is TJSONString) then Exit;
      ErrorText := Value.Value;
      if (ErrorText = 'INVALID_JSON') or (ErrorText = 'INVALID_VALUE') or
         (ErrorText = 'BUFFER_OVERFLOW') then
        if Trim(S) = '{"ok":0,"error":"' + ErrorText + '"}' then Result := 0;
    end;
  finally
    Root.Free;
  end;
end;

function TFormMain.SerialClock: UInt64;
begin
  Result := GetTickCount64;
end;

function TFormMain.SerialConnected: Boolean;
begin
  Result := FComHandle <> INVALID_HANDLE_VALUE;
end;

function TFormMain.SerialWrite(const Data: AnsiString; out Written: DWORD): Boolean;
begin
  Written := 0;
  Result := WriteFile(FComHandle, Data[1], Length(Data), Written, nil);
end;

function TFormMain.SerialRead(var Buffer; Size: DWORD; out Count: DWORD): Boolean;
begin
  Result := ReadFile(FComHandle, Buffer, Size, Count, nil);
end;

procedure TFormMain.CloseSerialTransport;
begin
  if FComHandle <> INVALID_HANDLE_VALUE then CloseHandle(FComHandle);
  FComHandle := INVALID_HANDLE_VALUE;
end;

procedure TFormMain.SerialSessionOpened(const Port: string);
begin
  FComName := Port;
  FReceiveBuffer := '';
  FReceiveOverflow := False;
  FPendingJSON := '';
  FInFlightJSON := '';
  FAwaitingAck := False;
  FReadyAt := SerialClock + 2000;
  ButtonComport.Caption := Port;
  AddLog(Port + ' connected; Arduino ACK hali tasdiqlanmagan');
end;

function CalculateO2(P1, P2, P3, P4: Integer): Double;
begin
  Result := 1.8 + 3.9 * (P1 + P2 + P3 + P4) / 400;
end;

function BuildMotorJSON(P1, P2, P3, P4: Integer): string;
begin
  Result := Format('{"cmd":"set","m1":%d,"m2":%d,"m3":%d,"m4":%d}',
    [P1, P2, P3, P4]);
end;

function ParseFloatFlexible(const S: string; out Value: Double): Boolean;
var
  FS: TFormatSettings;
begin
  FS := TFormatSettings.Create;
  FS.DecimalSeparator := '.';
  FS.ThousandSeparator := #0;
  Result := TryStrToFloat(StringReplace(Trim(S), ',', '.', [rfReplaceAll]), Value, FS);
  if Result then
    Result := not IsNan(Value) and not IsInfinite(Value) and (Abs(Value) < 1000000);
end;

function O2Text(Value: Double): string;
var
  FS: TFormatSettings;
begin
  FS := TFormatSettings.Create;
  FS.DecimalSeparator := '.';
  Result := FormatFloat('0.00', Value, FS);
end;

procedure TBitBtn.CNDrawItem(var Message: TWMDrawItem);
var
  C: TCanvas;
  R: TRect;
begin
  C := TCanvas.Create;
  try
    C.Handle := Message.DrawItemStruct.hDC;
    R := Message.DrawItemStruct.rcItem;
    C.Brush.Color := FStateColor;
    C.FillRect(R);
    C.Font.Assign(Font);
    C.Font.Color := clWhite;
    SetBkMode(C.Handle, TRANSPARENT);
    DrawText(C.Handle, PChar(Caption), Length(Caption), R,
      DT_CENTER or DT_VCENTER or DT_SINGLELINE);
    if (Message.DrawItemStruct.itemState and ODS_FOCUS) <> 0 then
    begin
      InflateRect(R, -3, -3);
      C.DrawFocusRect(R);
    end;
    C.Handle := 0;
  finally
    C.Free;
  end;
  Message.Result := 1;
end;

procedure TFormMain.FormCreate(Sender: TObject);
var
  I: Integer;
begin
  FComHandle := INVALID_HANDLE_VALUE;
  FDemoMode := True;
  Randomize;
  CurrentO2 := 1.8;
  TargetO2 := 1.8;
  FSpeeds[0] := SpinEdit3;
  FSpeeds[1] := SpinEdit4;
  FSpeeds[2] := SpinEdit6;
  FSpeeds[3] := SpinEdit5;
  FButtons[0] := BitBtn1;
  FButtons[1] := BitBtn2;
  FButtons[2] := BitBtn3;
  FButtons[3] := BitBtn4;
  for I := 0 to 3 do
  begin
    FMotorEnabled[I] := True;
    FApplied[I] := 0;
    FSpeeds[I].Tag := I;
    FSpeeds[I].MinValue := 0;
    FSpeeds[I].MaxValue := 100;
    FSpeeds[I].Value := 0;
    FButtons[I].Tag := I;
    FButtons[I].Font.Size := 23;
  end;
  FUpdating := True;
  Auto.Checked := False;
  qolda.Checked := True;
  FUpdating := False;
  SpinEdit1.Text := '2.50';
  SpinEdit2.Text := '3.50';
  Edit1.Text := '1.80';
  Edit2.ReadOnly := True;
  Edit2.Text := BuildMotorJSON(0, 0, 0, 0);
  ButtonComport.Caption := 'Comport';
  Memo1.Clear;
  AddLog('Program started');
  UpdateMotorControls;
  UpdateO2Status;
  FLogWidth := Memo1.Width;
  cxSplitter1.CloseSplitter;
  O2Timer.Enabled := True;
  SerialTimer.Enabled := True;
  FInitialized := True;
end;

function TFormMain.ReadMotorValues(out P: TMotorValues): Boolean;
var
  I: Integer;
begin
  Result := False;
  for I := 0 to 3 do
  begin
    P[I] := 0;
    if FMotorEnabled[I] then
      if not Assigned(FSpeeds[I]) or
         not TryStrToInt(Trim(FSpeeds[I].Text), P[I]) or
         (P[I] < 0) or (P[I] > 100) then Exit;
  end;
  Result := True;
end;

function TFormMain.PreviewJSON(out S: string): Boolean;
var
  P: TMotorValues;
begin
  Result := ReadMotorValues(P);
  if not Result then P := FApplied;
  S := BuildMotorJSON(P[0], P[1], P[2], P[3]);
end;

procedure TFormMain.CommitMotors(const P: TMotorValues; const EventText: string;
  Transmit: Boolean);
var
  I: Integer;
  JSON: string;
  WasUpdating: Boolean;
begin
  WasUpdating := FUpdating;
  FUpdating := True;
  try
    for I := 0 to 3 do
    begin
      if FMotorEnabled[I] then FApplied[I] := EnsureRange(P[I], 0, 100)
      else FApplied[I] := 0;
      FSpeeds[I].Value := FApplied[I];
      if FMotorEnabled[I] then FLastSpeed[I] := FApplied[I];
    end;
    UpdateMotorControls;
  finally
    FUpdating := WasUpdating;
  end;
  JSON := BuildMotorJSON(FApplied[0], FApplied[1], FApplied[2], FApplied[3]);
  Edit2.Text := JSON;
  LogJSONEvent(EventText, JSON);
  SetTargetFromApplied;
  if Transmit then SendJSON(JSON);
end;

procedure TFormMain.LogJSONEvent(const EventText, JSON: string);
begin
  Memo1.Lines.BeginUpdate;
  try
    while Memo1.Lines.Count > 498 do
    begin
      Memo1.Lines.Delete(0);
      if Memo1.Lines.Count > 0 then Memo1.Lines.Delete(0);
    end;
    Memo1.Lines.Add('[' + FormatDateTime('yyyy-mm-dd hh:nn:ss.zzz', Now) + '] ' + EventText);
    Memo1.Lines.Add(JSON);
    Memo1.SelStart := Length(Memo1.Text);
    Memo1.SelLength := 0;
  finally
    Memo1.Lines.EndUpdate;
  end;
  SendMessage(Memo1.Handle, EM_SCROLLCARET, 0, 0);
end;

procedure TFormMain.AddLog(const S: string);
var
  JSON: string;
begin
  if PreviewJSON(JSON) then LogJSONEvent(S, JSON)
  else LogJSONEvent(S + ' [kiritish tugallanmagan; oxirgi qollangan JSON]', JSON);
end;

procedure TFormMain.InputChanged(Sender: TObject);
var
  JSON, Description: string;
begin
  if not FInitialized or FUpdating or FApplying or FClosing then Exit;
  if Sender = SpinEdit1 then Description := 'MIN O2: ' + SpinEdit1.Text
  else if Sender = SpinEdit2 then Description := 'MAX O2: ' + SpinEdit2.Text
  else Description := Format('Motor %d speed: %s%% [PREVIEW; SEND kutilmoqda]',
    [TComponent(Sender).Tag + 1, TSpinEdit(Sender).Text]);
  if PreviewJSON(JSON) then
  begin
    Edit2.Text := JSON;
    LogJSONEvent(Description, JSON);
  end
  else
  begin
    Edit2.Clear;
    LogJSONEvent(Description + ' [INVALID; yuborilmaydi; oxirgi qollangan JSON]', JSON);
  end;
end;

procedure TFormMain.LogSplitterCanResize(Sender: TObject; var NewSize: Integer;
  var Accept: Boolean);
begin
  Accept := False; // Hot-zone open/close remains available.
end;

procedure TFormMain.UpdateMotorControls;
var
  I: Integer;
begin
  for I := 0 to 3 do
  begin
    FSpeeds[I].Enabled := qolda.Checked and FMotorEnabled[I];
    if FMotorEnabled[I] then
    begin
      FButtons[I].Caption := 'ON';
      FButtons[I].StateColor := clGreen;
    end
    else
    begin
      FSpeeds[I].Value := 0;
      FButtons[I].Caption := 'OFF';
      FButtons[I].StateColor := clRed;
    end;
    FButtons[I].Invalidate;
  end;
end;

procedure TFormMain.SetMode(Automatic: Boolean);
var
  JSON: string;
begin
  FApplyQueued := False;
  FUpdating := True;
  try
    Auto.Checked := Automatic;
    qolda.Checked := not Automatic;
  finally
    FUpdating := False;
  end;
  if Automatic and not ApplySettings('AUTO MODE') then
  begin
    FUpdating := True;
    try
      Auto.Checked := False;
      qolda.Checked := True;
    finally
      FUpdating := False;
    end;
    AddLog('AUTO bekor qilindi; MANUAL MODE');
  end
  else if not Automatic then AddLog('MANUAL MODE');
  UpdateMotorControls;
  if PreviewJSON(JSON) then Edit2.Text := JSON else Edit2.Clear;
end;

procedure TFormMain.ModeClick(Sender: TObject);
begin
  if FUpdating then Exit;
  if Sender = Auto then SetMode(Auto.Checked)
  else SetMode(not qolda.Checked);
end;

procedure TFormMain.SetTargetFromApplied;
begin
  if FDemoMode then
  begin
    TargetO2 := CalculateO2(FApplied[0], FApplied[1], FApplied[2], FApplied[3]);
    LogJSONEvent('O2 Target: ' + O2Text(TargetO2),
      BuildMotorJSON(FApplied[0], FApplied[1], FApplied[2], FApplied[3]));
  end;
end;

procedure TFormMain.MotorClick(Sender: TObject);
var
  I, J, N, Saved: Integer;
  P: TMotorValues;
  EventText: string;
begin
  if FClosing or FApplying then Exit;
  I := TComponent(Sender).Tag;
  if (I < 0) or (I > 3) then Exit;
  if FMotorEnabled[I] then
  begin
    if TryStrToInt(Trim(FSpeeds[I].Text), Saved) and (Saved >= 0) and (Saved <= 100) then
      FLastSpeed[I] := Saved
    else FLastSpeed[I] := FApplied[I];
  end;
  FMotorEnabled[I] := not FMotorEnabled[I];
  FUpdating := True;
  try
    if FMotorEnabled[I] then FSpeeds[I].Value := FLastSpeed[I]
    else FSpeeds[I].Value := 0;
    UpdateMotorControls;
  finally
    FUpdating := False;
  end;
  if FMotorEnabled[I] then EventText := Format('Motor %d ON', [I + 1])
  else EventText := Format('Motor %d OFF', [I + 1]);
  N := 0;
  for J := 0 to 3 do if FMotorEnabled[J] then Inc(N);
  if Auto.Checked and (N > 0) then
  begin
    if ApplySettings(EventText, False) then Exit;
    FUpdating := True;
    try
      Auto.Checked := False;
      qolda.Checked := True;
    finally
      FUpdating := False;
    end;
    EventText := EventText + ' [AUTO xato; MANUAL MODE]';
  end;
  if not ReadMotorValues(P) then
  begin
    P := FApplied;
    if FMotorEnabled[I] then P[I] := FLastSpeed[I] else P[I] := 0;
    EventText := EventText + ' [noto''g''ri kiritish bekor qilindi]';
  end;
  CommitMotors(P, EventText);
  if Auto.Checked and (N = 0) then
    AddLog('Kamida bitta kompressorni yoqing.');
end;

function TFormMain.ApplySettings(const EventText: string; ShowErrors: Boolean): Boolean;
var
  I, N, Power: Integer;
  P: TMotorValues;
  Description: string;
  CapacityLimited: Boolean;
  MinO2, MaxO2, AutoTargetO2, RawPower: Double;
begin
  Result := False;
  CapacityLimited := False;
  if FApplying or FClosing then Exit;
  FApplying := True;
  try
  if Auto.Checked then
  begin
    if not ParseFloatFlexible(SpinEdit1.Text, MinO2) or
       not ParseFloatFlexible(SpinEdit2.Text, MaxO2) then
    begin
      AddLog('MIN/MAX O2 qiymatlarini son bilan kiriting.');
      if ShowErrors then ShowMessage('MIN/MAX O2 qiymatlarini son bilan kiriting.');
      Exit;
    end;
    if MinO2 >= MaxO2 then
    begin
      AddLog('MIN O2 MAX O2 dan kichik bo''lishi shart.');
      if ShowErrors then ShowMessage('MIN O2 MAX O2 dan kichik bo''lishi shart.');
      Exit;
    end;
    N := 0;
    for I := 0 to 3 do
      if FMotorEnabled[I] then Inc(N);
    if N = 0 then
    begin
      AddLog('Kamida bitta kompressorni yoqing.');
      if ShowErrors then ShowMessage('Kamida bitta kompressorni yoqing.');
      Exit;
    end;
    AutoTargetO2 := (MinO2 + MaxO2) / 2;
    RawPower := 400 * (AutoTargetO2 - 1.8) / (3.9 * N);
    Power := Round(EnsureRange(RawPower, 0.0, 100.0));
    CapacityLimited := RawPower > 100;
    for I := 0 to 3 do
      if FMotorEnabled[I] then P[I] := Power else P[I] := 0;
  end
  else
    for I := 0 to 3 do
    begin
      P[I] := 0;
      if FMotorEnabled[I] then
        if not TryStrToInt(Trim(FSpeeds[I].Text), P[I]) or
           (P[I] < 0) or (P[I] > 100) then
        begin
          Edit2.Clear;
          AddLog(Format('Kompressor %d: noto''g''ri tezlik; SEND bekor qilindi.', [I + 1]));
          if ShowErrors then ShowMessage(Format('Kompressor %d: 0...100 oralig''idagi butun son kiriting.', [I + 1]));
          Exit;
        end;
    end;
  Description := EventText;
  if Description = '' then
    if Auto.Checked then Description := 'AUTO hisoblandi' else Description := 'MANUAL SEND';
  CommitMotors(P, Description);
  Result := True;
  if CapacityLimited then
  begin
    AddLog('AUTO LIMIT: Tanlangan O2 qiymatiga erishish uchun yoqilgan kompressorlar soni yetarli emas.');
    if ShowErrors then ShowMessage('Tanlangan O2 qiymatiga erishish uchun yoqilgan kompressorlar soni yetarli emas.');
  end;
  finally
    FApplying := False;
  end;
end;

procedure TFormMain.ButtonSendClick(Sender: TObject);
begin
  if ApplySettings('SEND bosildi') and FDemoMode then StartO2Transition;
end;

procedure TFormMain.AutoLimitsExit(Sender: TObject);
begin
  if Auto.Checked and not FUpdating and not FApplying and not FClosing and
     not FApplyQueued then
  begin
    FApplyQueued := True;
    PostMessage(Handle, WM_APP + 42, 0, 0);
  end;
end;

procedure TFormMain.ApplyAutoAfterExit(var Message: TMessage);
begin
  if not FApplyQueued then Exit;
  FApplyQueued := False;
  if FClosing or not Auto.Checked then Exit;
  // Finish focus changes before applying; button events already handle commands.
  if (ActiveControl = SpinEdit1) or (ActiveControl = SpinEdit2) or
     (ActiveControl = ButtonSend) or (ActiveControl = ButtonComport) or
     (ActiveControl = BitBtn1) or (ActiveControl = BitBtn2) or
     (ActiveControl = BitBtn3) or (ActiveControl = BitBtn4) or
     (ActiveControl = Auto) or (ActiveControl = qolda) then Exit;
  ApplySettings;
end;

procedure TFormMain.LogSplitterMoved(Sender: TObject);
var
  Delta: Integer;
begin
  Delta := Memo1.Width - FLogWidth;
  FLogWidth := Memo1.Width;
  DisableAlign;
  try
    ClientWidth := ClientWidth + Delta;
    LabelSystemLog.Visible := FLogWidth > 0;
  finally
    EnableAlign;
  end;
  LabelSystemLog.Left := Memo1.Left + 6;
  if FInitialized then
    if FLogWidth > 0 then AddLog('SYSTEM LOG ochildi')
    else AddLog('SYSTEM LOG yopildi');
end;

procedure TFormMain.UpdateO2Status;
begin
  if CurrentO2 < 2.10 then
  begin
    LabelO2Status.Caption := 'O2 LOW';
    LabelO2Status.Font.Color := clRed;
  end
  else if CurrentO2 <= 5.00 then
  begin
    LabelO2Status.Caption := 'NORMAL';
    LabelO2Status.Font.Color := clGreen;
  end
  else
  begin
    LabelO2Status.Caption := 'O2 HIGH';
    LabelO2Status.Font.Color := clRed;
  end;
end;

function TFormMain.O2Clock: UInt64;
begin
  Result := GetTickCount64;
end;

procedure TFormMain.StartO2Transition;
begin
  FO2Start := CurrentO2;
  FO2End := TargetO2; // Capture this SEND; later edits cannot redirect the ramp.
  FO2StartedAt := O2Clock;
  FO2Duration := 3000 + Cardinal(Random(4001));
  FO2Running := Abs(FO2End - FO2Start) > 0.0000001;
  FO2NoiseEnabled := True;
  FO2NoiseAt := O2Clock + 2000;
  LogJSONEvent(Format('O2 DEMO: %s -> %s mg/L; %d ms; chiziqli; keyin +/-5%% har 2 s',
    [O2Text(FO2Start), O2Text(FO2End), FO2Duration]),
    BuildMotorJSON(FApplied[0], FApplied[1], FApplied[2], FApplied[3]));
end;

procedure TFormMain.O2TimerTimer(Sender: TObject);
var
  Elapsed, NowMs: UInt64;
  LowCents, HighCents, OldCents, NewCents: Integer;
begin
  if FClosing or not FDemoMode then Exit;
  NowMs := O2Clock;
  if FO2Running then
  begin
    Elapsed := NowMs - FO2StartedAt;
    if Elapsed >= FO2Duration then
    begin
      CurrentO2 := FO2End;
      FO2Running := False;
      FO2NoiseAt := NowMs + 2000;
    end
    else
      CurrentO2 := FO2Start + (FO2End - FO2Start) * (Elapsed / FO2Duration);
  end
  else if FO2NoiseEnabled and (NowMs >= FO2NoiseAt) then
  begin
    // Always use the SEND baseline, never compound the previous noise sample.
    LowCents := Ceil(FO2End * 0.95 * 100);
    HighCents := Floor(FO2End * 1.05 * 100);
    OldCents := Round(CurrentO2 * 100);
    if HighCents > LowCents then
    begin
      if (OldCents >= LowCents) and (OldCents <= HighCents) then
      begin
        NewCents := LowCents + Random(HighCents - LowCents);
        if NewCents >= OldCents then Inc(NewCents);
      end
      else
        NewCents := LowCents + Random(HighCents - LowCents + 1);
      CurrentO2 := NewCents / 100;
    end
    else CurrentO2 := FO2End;
    FO2NoiseAt := NowMs + 2000;
  end
  else Exit;
  Edit1.Text := O2Text(CurrentO2);
  UpdateO2Status;
end;

procedure TFormMain.SetMeasuredO2(const Value: Double);
begin
  if IsNan(Value) or IsInfinite(Value) or (Value < 0) then Exit;
  FDemoMode := False;
  FO2Running := False;
  FO2NoiseEnabled := False;
  TargetO2 := Value;
  CurrentO2 := Value;
  Edit1.Text := O2Text(CurrentO2);
  UpdateO2Status;
end;

procedure TFormMain.ConnectComPort;
var
  Ports: TStringList;
  I: Integer;
  Device: array[0..1023] of Char;
  Port, Selected: string;
  DCB: TDCB;
  Timeouts: TCommTimeouts;
  ErrorCode: DWORD;
begin
  Ports := TStringList.Create;
  try
    for I := 1 to 20 do
    begin
      Port := 'COM' + IntToStr(I);
      if QueryDosDevice(PChar(Port), Device, Length(Device)) <> 0 then
      begin
        Ports.Add(Port);
        AddLog('Found: ' + Port);
      end;
    end;
    if Ports.Count = 0 then
    begin
      AddLog('COM port not found');
      ShowMessage('Arduino COM port topilmadi.');
      Exit;
    end;
    Selected := Ports[0];
    if Ports.Count > 1 then
    begin
      Selected := '';
      if not InputQuery('COM port', 'Arduino portini tanlang: ' +
        StringReplace(Trim(Ports.Text), sLineBreak, ', ', [rfReplaceAll]), Selected) then Exit;
      Selected := UpperCase(Trim(Selected));
      if Ports.IndexOf(Selected) < 0 then
      begin
        ShowMessage('Ro''yxatdagi COM port nomini kiriting.');
        Exit;
      end;
    end;
    FComHandle := CreateFile(PChar('\\.\' + Selected), GENERIC_READ or GENERIC_WRITE,
      0, nil, OPEN_EXISTING, 0, 0);
    if FComHandle = INVALID_HANDLE_VALUE then
    begin
      ErrorCode := GetLastError;
      AddLog(Selected + ': ' + SysErrorMessage(ErrorCode));
      ShowMessage('Arduino COM port topilmadi. Port band yoki ochib bo''lmaydi.');
      Exit;
    end;
    try
      FillChar(DCB, SizeOf(DCB), 0);
      DCB.DCBlength := SizeOf(DCB);
      if not GetCommState(FComHandle, DCB) then RaiseLastOSError;
      DCB.BaudRate := 9600;
      DCB.ByteSize := 8;
      DCB.Parity := NOPARITY;
      DCB.StopBits := ONESTOPBIT;
      DCB.Flags := 1; // Binary, no flow control; DTR/RTS disabled.
      if not SetCommState(FComHandle, DCB) then RaiseLastOSError;
      FillChar(Timeouts, SizeOf(Timeouts), 0);
      Timeouts.ReadIntervalTimeout := MAXDWORD;
      Timeouts.WriteTotalTimeoutConstant := 150;
      if not SetCommTimeouts(FComHandle, Timeouts) then RaiseLastOSError;
      if not PurgeComm(FComHandle, PURGE_RXCLEAR or PURGE_TXCLEAR) then RaiseLastOSError;
      SerialSessionOpened(Selected);
    except
      on E: Exception do
      begin
        CloseHandle(FComHandle);
        FComHandle := INVALID_HANDLE_VALUE;
        AddLog('COM error: ' + E.Message);
        ShowMessage(E.Message);
      end;
    end;
  finally
    Ports.Free;
  end;
end;

function TFormMain.WriteJSON(const S: string): Boolean;
var
  Data: AnsiString;
  Written: DWORD;
begin
  Result := False;
  if not SerialConnected then Exit;
  Data := AnsiString(S + #10);
  Written := 0;
  if not SerialWrite(Data, Written) or
     (Written <> DWORD(Length(Data))) then
  begin
    LogJSONEvent('TX XATO: COM write failed; connection closed', S);
    DisconnectComPort(False);
    Exit;
  end;
  FInFlightJSON := S;
  FAwaitingAck := True;
  FAckDeadline := SerialClock + 2000;
  LogJSONEvent('TX: yuborildi; ACK kutilmoqda', S);
  Result := True;
end;

procedure TFormMain.SendJSON(const S: string);
begin
  Edit2.Text := S;
  Edit2.SelStart := 0;
  if not SerialConnected then
  begin
    LogJSONEvent('YUBORILMADI: COM ulanmagan (DEMO)', S);
    Exit;
  end;
  if (S = BuildMotorJSON(0, 0, 0, 0)) and (SerialClock >= FReadyAt) then
  begin
    FPendingJSON := '';
    WriteJSON(S); // STOP takes priority over a pending acknowledgement.
    Exit;
  end;
  FPendingJSON := S;
  if (SerialClock < FReadyAt) or FAwaitingAck then
    LogJSONEvent('NAVBAT: reset/ACK kutilmoqda; eng oxirgi buyruq saqlandi', S)
  else
  begin
    FPendingJSON := '';
    WriteJSON(S);
  end;
end;

procedure TFormMain.ProcessSerialLine(const S: string);
var
  P: TMotorValues;
  Code: Integer;
  ErrorText, Confirmed: string;
begin
  LogJSONEvent('RX: Arduino javobi', S);
  Code := ParseMotorReply(S, P, ErrorText);
  if Code < 0 then
  begin
    LogJSONEvent('RX INVALID: javob formati rad etildi', S);
    Exit;
  end;
  if not FAwaitingAck then
  begin
    LogJSONEvent('RX: kutilmagan/eski javob; buyruq tasdiqlanmadi', S);
    Exit;
  end;
  if Code = 0 then
  begin
    LogJSONEvent('Arduino xatosi: ' + ErrorText + '; navbat bekor qilindi', S);
    DisconnectComPort(True);
    Exit;
  end;
  Confirmed := BuildMotorJSON(P[0], P[1], P[2], P[3]);
  if Confirmed <> FInFlightJSON then
  begin
    LogJSONEvent('ACK MOS EMAS: yuborilgan qiymatlar tasdiqlanmadi', S);
    Exit;
  end;
  FAwaitingAck := False;
  FInFlightJSON := '';
  LogJSONEvent('ACK OK: Arduino motor qiymatlarini tasdiqladi', Confirmed);
end;

procedure TFormMain.SerialTimerTimer(Sender: TObject);
var
  Buffer: array[0..511] of AnsiChar;
  Count: DWORD;
  I: Integer;
  S: string;
begin
  if not SerialConnected then Exit;
  // Consume replies before sending the next queued command.
  if not SerialRead(Buffer, SizeOf(Buffer), Count) then
  begin
    AddLog('COM read failed: ' + SysErrorMessage(GetLastError));
    DisconnectComPort(False);
    Exit;
  end;
  for I := 0 to Integer(Count) - 1 do
  begin
    if Buffer[I] = #10 then
    begin
      if FReceiveOverflow then AddLog('RX: BUFFER_OVERFLOW')
      else if FReceiveBuffer <> '' then ProcessSerialLine(string(FReceiveBuffer));
      FReceiveBuffer := '';
      FReceiveOverflow := False;
    end
    else if Buffer[I] <> #13 then
      if not FReceiveOverflow then
        if Length(FReceiveBuffer) < 1024 then
          FReceiveBuffer := FReceiveBuffer + Buffer[I]
        else FReceiveOverflow := True;
    if not SerialConnected then Exit;
  end;
  if FAwaitingAck and (SerialClock >= FAckDeadline) then
  begin
    LogJSONEvent('ACK TIMEOUT: navbat bekor qilindi; STOP urinishi va COM yopilishi', FInFlightJSON);
    DisconnectComPort(True);
    Exit;
  end;
  if not FAwaitingAck and (FPendingJSON <> '') and (SerialClock >= FReadyAt) then
  begin
    S := FPendingJSON;
    FPendingJSON := '';
    WriteJSON(S);
  end;
end;

procedure TFormMain.DisconnectComPort(StopMotors: Boolean);
var
  OldPort: string;
  P: TMotorValues;
  Sent: Boolean;
begin
  FPendingJSON := '';
  FAwaitingAck := False;
  FInFlightJSON := '';
  if not SerialConnected then Exit;
  OldPort := FComName;
  if StopMotors then
  begin
    Edit2.Text := BuildMotorJSON(0, 0, 0, 0);
    Sent := WriteJSON(Edit2.Text);
    if Sent then
    begin
      Sleep(50);
      LogJSONEvent('STOP yuborildi; yopilishdan oldin ACK tekshirilmagan', Edit2.Text);
    end;
    FillChar(P, SizeOf(P), 0);
    CommitMotors(P, 'COM STOP: barcha tezliklar 0', False);
    if not Sent then Exit;
  end;
  CloseSerialTransport;
  FAwaitingAck := False;
  FInFlightJSON := '';
  FComName := '';
  FReceiveBuffer := '';
  ButtonComport.Caption := 'Comport';
  AddLog(OldPort + ' disconnected');
end;

procedure TFormMain.ButtonComportClick(Sender: TObject);
begin
  if not SerialConnected then ConnectComPort
  else DisconnectComPort;
end;

procedure TFormMain.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  FClosing := True;
  SerialTimer.Enabled := False;
  O2Timer.Enabled := False;
  DisconnectComPort;
end;

end.










