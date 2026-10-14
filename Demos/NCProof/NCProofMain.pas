{*******************************************************}
{                                                       }
{  FMR Ribbon for FireMonkey                            }
{  NCProof: FMX controls in the real non-client area    }
{                                                       }
{  MIT License. Copyright (c) 2026 Fasday               }
{                                                       }
{*******************************************************}

unit NCProofMain;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Messaging, FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics,
  FMX.StdCtrls, FMX.Edit, FMX.ComboEdit, FMX.Pickers, FMX.ListBox, FMX.Layouts, FMX.Objects, FMX.Controls.Presentation,
  FMR.Frame.Types, FMR.Frame.Host, FMR.Frame, FMR.Frame.Buttons, FMR.Frame.Form;

type
  /// <summary>Application icon of the caption row: SysMenu area (click: system menu, double click: close).</summary>
  TAppIcon = class(TControl, IFmrFrameHitTest)
  private
    FAccent: TAlphaColor;
  protected
    function FrameHitTest(const ALocalPoint: TPointF): TFmrHitArea;
    procedure Paint; override;
  public
    constructor Create(AOwner: TComponent); override;
    property Accent: TAlphaColor read FAccent write FAccent;
  end;

  /// <summary>Fake ribbon tab row: tabs are Client (they switch the selected tab), gaps are Caption (drag).</summary>
  TFakeTabRow = class(TControl, IFmrFrameHitTest)
  private
    FTabs: TArray<string>;
    FSelected: Integer;
    FHot: Integer;
    FDark: Boolean;
    FAccent: TAlphaColor;
    FOnChange: TNotifyEvent;
    function TabWidth(const AIndex: Integer): Single;
    function TabRect(const AIndex: Integer): TRectF;
    function TabAt(const APoint: TPointF): Integer;
    procedure SetDark(const Value: Boolean);
  protected
    function FrameHitTest(const ALocalPoint: TPointF): TFmrHitArea;
    procedure Paint; override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Single); override;
    procedure MouseMove(Shift: TShiftState; X, Y: Single); override;
    procedure DoMouseLeave; override;
  public
    constructor Create(AOwner: TComponent); override;
    property Selected: Integer read FSelected;
    property Tabs: TArray<string> read FTabs;
    property Dark: Boolean read FDark write SetDark;
    property OnChange: TNotifyEvent read FOnChange write FOnChange;
  end;

  TNCProofForm = class(TFmrForm)
  private
    // caption row
    FCaptionRow: TLayout;
    FDiamond: TRectangle;
    FRightBox: TLayout;
    FButtonsBox: TLayout;
    FAppIcon: TAppIcon;
    FQat: array [0..2] of TSpeedButton;
    FQatPaths: array [0..2] of TPath;
    FCombo: TComboBox;
    FZoom: TComboEdit;
    FTitle: TLabel;
    FSearch: TEdit;
    FMinButton, FMaxButton, FCloseButton: TFmrCaptionButton;
    FTabRow: TFakeTabRow;
    // client
    FBackground: TRectangle;
    FSidePanel: TRectangle;
    FModeLabel: TLabel;
    FBackdropLabel: TLabel;
    FClientLabel: TLabel;
    FModeRadios: array [TFmrFrameMode] of TRadioButton;
    FDarkCheck: TCheckBox;
    FTabRowCheck: TCheckBox;
    FBackdropCombo: TComboBox;
    FMaxToggle: TButton;
    FClientEdit: TEdit;
    FGeometry: TLabel;
    FExplain: TLabel;
    FTimer: TTimer;
    FLastAction: string;
    FUpdatingUI: Boolean;
    FAnimTest: Boolean;
    FHookLog: string;
    FLastHooked: Boolean;
    FStateMessages: Integer;
    FStateMsgId: TMessageSubscriptionId;
    FSimDpi: Cardinal;
    FDpiButton: TButton;
    procedure DpiButtonClick(Sender: TObject);
    procedure SimulateDpiChange;
    procedure AddImeInfo(const ALines: TStrings);
    procedure BuildCaption;
    procedure BuildClient;
    procedure ApplyCommandLine;
    procedure ApplyTheme;
    procedure UpdateGeometry(Sender: TObject);
    procedure ModeRadioChange(Sender: TObject);
    procedure DarkCheckChange(Sender: TObject);
    procedure TabRowCheckChange(Sender: TObject);
    procedure BackdropChange(Sender: TObject);
    procedure MaxToggleClick(Sender: TObject);
    procedure QatClick(Sender: TObject);
    procedure TabChange(Sender: TObject);
    procedure ComboChange(Sender: TObject);
    procedure ComboPopup(Sender: TObject);
    procedure ComboClosePopup(Sender: TObject);
    procedure AppException(Sender: TObject; E: Exception);
    procedure SearchChangeTracking(Sender: TObject);
    procedure FrameStateChanged(Sender: TObject);
    function MakeLabel(const AParent: TFmxObject; const AText: string; const AAlign: TAlignLayout;
      const AHeight: Single): TLabel;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
  end;

var
  NCProofForm: TNCProofForm;

implementation

uses
  System.Math, System.StrUtils, FMX.Text
  {$IFDEF MSWINDOWS}, Winapi.Windows, Winapi.Messages, Winapi.Dwmapi, Winapi.Imm, FMX.Platform.Win, FMR.Frame.Win{$ENDIF};

const
  LightCaption = $FFF3F3F3;
  DarkCaption = $FF202020;
  LightClient = $FFFFFFFF;
  DarkClient = $FF2B2B2B;
  LightPanel = $FFF7F7F7;
  DarkPanel = $FF252525;
  LightText = $FF1A1A1A;
  DarkText = $FFF0F0F0;
  LightAccent = $FF0067C0;
  DarkAccent = $FF4CC2FF;

  ModeNames: array [TFmrFrameMode] of string = ('Dwm', 'FullNC', 'NCStrip');

  SExplain =
    'Что доказывает эта панель. Строка заголовка (значок, панель быстрого доступа, выпадающий список, поле поиска, ' +
    'кнопки окна) и строка вкладок — обычные элементы FMX. В режимах FullNC и NCStrip они лежат в настоящей ' +
    'неклиентской области окна: GetClientRect начинается под ними (см. «non-client top» > 0), Windows возвращает ' +
    'HTCAPTION для пустого места (перетаскивание, двойной щелчок, системное меню), HTMAXBUTTON для кнопки ' +
    '«развернуть» (Snap Layouts в Windows 11) и HTCLIENT для элементов: в поле поиска можно печатать, выделять, ' +
    'копировать и вставлять, список раскрывается под собой. В режиме Dwm верхней неклиентской области нет ' +
    '(top = 0): заголовок нарисован FMX в клиентской области поверх рамки DWM.' + sLineBreak + sLineBreak +
    'What this panel proves. The caption row (icon, quick access toolbar, combo box, search box, window buttons) ' +
    'and the tab row are ordinary FMX controls. In the FullNC and NCStrip modes they live in the real non-client ' +
    'area: GetClientRect starts below them (non-client top > 0); Windows gets HTCAPTION for empty space (drag, ' +
    'double click, system menu), HTMAXBUTTON for the maximize button (Windows 11 Snap Layouts) and HTCLIENT for ' +
    'the controls: the search box takes typing, selection, copy and paste, the combo box drops down below itself. ' +
    'In the Dwm mode there is no top non-client area (top = 0): the caption is painted by FMX in the client area ' +
    'over the DWM frame.';

{ TAppIcon }

constructor TAppIcon.Create(AOwner: TComponent);
begin
  inherited;
  HitTest := True;
  FAccent := LightAccent;
end;

function TAppIcon.FrameHitTest(const ALocalPoint: TPointF): TFmrHitArea;
begin
  Result := TFmrHitArea.SysMenu;
end;

procedure TAppIcon.Paint;
var
  R: TRectF;
  Path: TPathData;
  State: TCanvasSaveState;
begin
  R := TRectF.Create(0, 0, 18, 18);
  R.SetLocation((Width - 18) / 2, (Height - 18) / 2);
  // Painted with a SaveState/RestoreState pair and clipping on purpose: in the non-client strip the glyph after
  // RestoreState lands where the background is only if the host paints without TCanvas.Offset.
  State := Canvas.SaveState;
  try
    Canvas.IntersectClipRect(R);
    Canvas.Fill.Kind := TBrushKind.Solid;
    Canvas.Fill.Color := FAccent;
    Canvas.FillRect(R, 4, 4, AllCorners, AbsoluteOpacity);
  finally
    Canvas.RestoreState(State);
  end;
  // A ribbon-like "R" glyph drawn with a path.
  Path := TPathData.Create;
  try
    Path.MoveTo(TPointF.Create(R.Left + 5, R.Top + 4));
    Path.LineTo(TPointF.Create(R.Left + 10.5, R.Top + 4));
    Path.CurveTo(TPointF.Create(R.Left + 14, R.Top + 4), TPointF.Create(R.Left + 14, R.Top + 9.5),
      TPointF.Create(R.Left + 10.5, R.Top + 9.5));
    Path.LineTo(TPointF.Create(R.Left + 5, R.Top + 9.5));
    Path.MoveTo(TPointF.Create(R.Left + 5, R.Top + 4));
    Path.LineTo(TPointF.Create(R.Left + 5, R.Top + 14));
    Path.MoveTo(TPointF.Create(R.Left + 9.5, R.Top + 9.5));
    Path.LineTo(TPointF.Create(R.Left + 13.5, R.Top + 14));
    Canvas.Stroke.Kind := TBrushKind.Solid;
    Canvas.Stroke.Color := TAlphaColors.White;
    Canvas.Stroke.Thickness := 1.6;
    Canvas.Stroke.Cap := TStrokeCap.Round;
    Canvas.Stroke.Join := TStrokeJoin.Round;
    Canvas.DrawPath(Path, AbsoluteOpacity);
  finally
    Path.Free;
  end;
end;

{ TFakeTabRow }

constructor TFakeTabRow.Create(AOwner: TComponent);
begin
  inherited;
  HitTest := True;
  FTabs := ['File', 'Home', 'Insert', 'Design', 'Layout', 'References', 'View', 'Help'];
  FSelected := 1;
  FHot := -1;
  FAccent := LightAccent;
end;

procedure TFakeTabRow.SetDark(const Value: Boolean);
begin
  FDark := Value;
  if FDark then
    FAccent := DarkAccent
  else
    FAccent := LightAccent;
  Repaint;
end;

function TFakeTabRow.TabWidth(const AIndex: Integer): Single;
begin
  if Canvas <> nil then
  begin
    Canvas.Font.Size := 12;
    Canvas.Font.Family := 'Segoe UI';
    Result := Ceil(Canvas.TextWidth(FTabs[AIndex])) + 24;
  end
  else
    Result := Length(FTabs[AIndex]) * 7 + 24;
end;

function TFakeTabRow.TabRect(const AIndex: Integer): TRectF;
var
  I: Integer;
  X: Single;
begin
  X := 8;
  for I := 0 to AIndex - 1 do
    X := X + TabWidth(I) + 2;
  Result := TRectF.Create(X, 3, X + TabWidth(AIndex), Height - 1);
end;

function TFakeTabRow.TabAt(const APoint: TPointF): Integer;
var
  I: Integer;
begin
  for I := 0 to High(FTabs) do
    if TabRect(I).Contains(APoint) then
      Exit(I);
  Result := -1;
end;

function TFakeTabRow.FrameHitTest(const ALocalPoint: TPointF): TFmrHitArea;
begin
  if TabAt(ALocalPoint) >= 0 then
    Result := TFmrHitArea.Client
  else
    Result := TFmrHitArea.Caption;
end;

procedure TFakeTabRow.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Single);
var
  Index: Integer;
begin
  inherited;
  Index := TabAt(TPointF.Create(X, Y));
  if (Button = TMouseButton.mbLeft) and (Index >= 0) and (Index <> FSelected) then
  begin
    FSelected := Index;
    Repaint;
    if Assigned(FOnChange) then
      FOnChange(Self);
  end;
end;

procedure TFakeTabRow.MouseMove(Shift: TShiftState; X, Y: Single);
var
  Index: Integer;
begin
  inherited;
  Index := TabAt(TPointF.Create(X, Y));
  if Index <> FHot then
  begin
    FHot := Index;
    Repaint;
  end;
end;

procedure TFakeTabRow.DoMouseLeave;
begin
  inherited;
  if FHot <> -1 then
  begin
    FHot := -1;
    Repaint;
  end;
end;

procedure TFakeTabRow.Paint;
var
  I: Integer;
  R: TRectF;
  TextColor: TAlphaColor;
begin
  Canvas.Font.Size := 12;
  Canvas.Font.Family := 'Segoe UI';
  for I := 0 to High(FTabs) do
  begin
    R := TabRect(I);
    if I = 0 then
    begin
      // "File" tab: accent background.
      Canvas.Fill.Kind := TBrushKind.Solid;
      Canvas.Fill.Color := FAccent;
      Canvas.FillRect(R, 3, 3, [TCorner.TopLeft, TCorner.TopRight], AbsoluteOpacity);
      TextColor := TAlphaColors.White;
    end
    else
    begin
      if I = FHot then
      begin
        Canvas.Fill.Kind := TBrushKind.Solid;
        if FDark then
          Canvas.Fill.Color := $18FFFFFF
        else
          Canvas.Fill.Color := $10000000;
        Canvas.FillRect(R, 3, 3, [TCorner.TopLeft, TCorner.TopRight], AbsoluteOpacity);
      end;
      if FDark then
        TextColor := DarkText
      else
        TextColor := LightText;
    end;
    Canvas.Fill.Kind := TBrushKind.Solid;
    Canvas.Fill.Color := TextColor;
    Canvas.FillText(R, FTabs[I], False, AbsoluteOpacity, [], TTextAlign.Center, TTextAlign.Center);
    if I = FSelected then
    begin
      Canvas.Fill.Color := FAccent;
      Canvas.FillRect(TRectF.Create(R.Left + 8, R.Bottom - 3, R.Right - 8, R.Bottom), 1, 1, AllCorners,
        AbsoluteOpacity);
    end;
  end;
  // Separator between the frame and the client area.
  Canvas.Stroke.Kind := TBrushKind.Solid;
  if FDark then
    Canvas.Stroke.Color := $FF3A3A3A
  else
    Canvas.Stroke.Color := $FFE0E0E0;
  Canvas.Stroke.Thickness := 1;
  Canvas.DrawLine(TPointF.Create(0, Height - 0.5), TPointF.Create(Width, Height - 0.5), AbsoluteOpacity);
end;

{$IFDEF MSWINDOWS}
function CursorShapeName: string;
const
  Ids: array [0..7] of PChar = (IDC_ARROW, IDC_IBEAM, IDC_HAND, IDC_SIZENS, IDC_SIZEWE, IDC_SIZENWSE, IDC_SIZENESW,
    IDC_SIZEALL);
  Names: array [0..7] of string = ('ARROW', 'IBEAM', 'HAND', 'SIZENS', 'SIZEWE', 'SIZENWSE', 'SIZENESW', 'SIZEALL');
var
  Info: TCursorInfo;
  I: Integer;
begin
  Info.cbSize := SizeOf(Info);
  if not GetCursorInfo(Info) then
    Exit('?');
  for I := Low(Ids) to High(Ids) do
    if Info.hCursor = LoadCursor(0, Ids[I]) then
      Exit(Names[I]);
  Result := Format('$%x', [Info.hCursor]);
end;
{$ENDIF}

{ TNCProofForm }

constructor TNCProofForm.Create(AOwner: TComponent);
{$IFDEF MSWINDOWS}
var
  I: Integer;
{$ENDIF}
begin
{$IFDEF MSWINDOWS}
  // The strategy is read when the frame attaches, i.e. while the form is created.
  for I := 1 to ParamCount do
    if SameText(ParamStr(I), '/strategy=keepcaption') then
      FmrWinFullNCStrategy := TFmrWinFullNCStrategy.KeepCaptionStyle
    else if SameText(ParamStr(I), '/strategy=allowncpaint') then
      FmrWinFullNCStrategy := TFmrWinFullNCStrategy.KeepCaptionAllowNCPaint
    else if SameText(ParamStr(I), '/strategy=nodwmframe') then
      FmrWinFullNCStrategy := TFmrWinFullNCStrategy.KeepCaptionNoDwmFrame
    else if SameText(ParamStr(I), '/strategy=animcaption') then
      FmrWinFullNCStrategy := TFmrWinFullNCStrategy.CaptionDuringAnimation;
{$ENDIF}
  // The form is built in code: no .fmx resource.
  inherited CreateNew(AOwner);
  // TFmrForm creates its frame in InitializeNewForm, which hooks the window at once.
  FLastHooked := Frame.Hooked;
  FHookLog := 'after CreateNew: Hooked=' + BoolToStr(FLastHooked, True);
  FStateMsgId := TMessageManager.DefaultManager.SubscribeToMessage(TFmrFrameStateMessage,
    procedure(const Sender: TObject; const M: System.Messaging.TMessage)
    begin
      if TFmrFrameStateMessage(M).Host = Frame.Host then
        Inc(FStateMessages);
    end);
  Caption := 'FMR NCProof';
  Width := 1180;
  Height := 760;
  Position := TFormPosition.ScreenCenter;
  Frame.CaptionHeight := 64;
  Frame.OnStateChanged := FrameStateChanged;
  BuildCaption;
  BuildClient;
  ApplyCommandLine;
  ApplyTheme;
  FTimer := TTimer.Create(Self);
  FTimer.Interval := 200;
  FTimer.OnTimer := UpdateGeometry;
  UpdateGeometry(nil);
end;

destructor TNCProofForm.Destroy;
begin
  TMessageManager.DefaultManager.Unsubscribe(TFmrFrameStateMessage, FStateMsgId);
  inherited;
end;

function TNCProofForm.MakeLabel(const AParent: TFmxObject; const AText: string; const AAlign: TAlignLayout;
  const AHeight: Single): TLabel;
begin
  Result := TLabel.Create(Self);
  Result.Parent := AParent;
  Result.Align := AAlign;
  Result.Height := AHeight;
  Result.Text := AText;
  Result.StyledSettings := Result.StyledSettings - [TStyledSetting.FontColor, TStyledSetting.Size];
  Result.TextSettings.Font.Size := 12;
end;

procedure TNCProofForm.BuildCaption;
const
  QatPaths: array [0..2] of string = (
    'M2,1 L11,1 L14,4 L14,14 L2,14 Z M4.5,1 L4.5,5 L10.5,5 L10.5,1 M4.5,14 L4.5,9 L11.5,9 L11.5,14',
    'M5,3 L1.5,6.5 L5,10 M1.5,6.5 L10,6.5 C13,6.5 14.5,8.5 14.5,11 C14.5,13 13.5,14 12,14',
    'M11,3 L14.5,6.5 L11,10 M14.5,6.5 L6,6.5 C3,6.5 1.5,8.5 1.5,11 C1.5,13 2.5,14 4,14');
  QatHints: array [0..2] of string = ('Save', 'Undo', 'Redo');
var
  Host: TFmrFrameHost;
  DiamondBox: TLayout;
  I: Integer;

  function MakeButton(const AKind: TFmrCaptionButtonKind; const AX: Single): TFmrCaptionButton;
  begin
    Result := TFmrCaptionButton.Create(Self);
    Result.Kind := AKind;
    Result.Parent := FButtonsBox;
    Result.Position.X := AX;
    Result.Align := TAlignLayout.Left;
  end;

begin
  Host := Frame.Host;

  FCaptionRow := TLayout.Create(Self);
  FCaptionRow.Parent := Host;
  FCaptionRow.Align := TAlignLayout.Top;
  FCaptionRow.Height := 32;

  // Search box and caption buttons, left to right (Left alignment keeps the order of creation with growing X).
  FRightBox := TLayout.Create(Self);
  FRightBox.Parent := FCaptionRow;
  FRightBox.Align := TAlignLayout.Right;
  FRightBox.Width := 256 + 3 * FmrCaptionButtonWidth;

  FButtonsBox := TLayout.Create(Self);
  FButtonsBox.Parent := FRightBox;
  FButtonsBox.Align := TAlignLayout.Right;
  FButtonsBox.Width := 3 * FmrCaptionButtonWidth;

  FSearch := TEdit.Create(Self);
  FSearch.Parent := FRightBox;
  FSearch.Align := TAlignLayout.Client;
  FSearch.Margins.Rect := TRectF.Create(4, 4, 12, 4);
  FSearch.TextPrompt := 'Search…';
  FSearch.OnChangeTracking := SearchChangeTracking;

  FMinButton := MakeButton(TFmrCaptionButtonKind.Minimize, 1000);
  FMaxButton := MakeButton(TFmrCaptionButtonKind.Maximize, 2000);
  FCloseButton := MakeButton(TFmrCaptionButtonKind.Close, 3000);

  FAppIcon := TAppIcon.Create(Self);
  FAppIcon.Parent := FCaptionRow;
  FAppIcon.Width := 40;
  FAppIcon.Position.X := 0;
  FAppIcon.Align := TAlignLayout.Left;

  for I := 0 to 2 do
  begin
    FQat[I] := TSpeedButton.Create(Self);
    FQat[I].Parent := FCaptionRow;
    FQat[I].Position.X := 50 + I * 40;
    FQat[I].Align := TAlignLayout.Left;
    FQat[I].Width := 32;
    FQat[I].Margins.Rect := TRectF.Create(1, 2, 1, 2);
    FQat[I].Hint := QatHints[I];
    FQat[I].ShowHint := True;
    FQat[I].Tag := I;
    FQat[I].OnClick := QatClick;
    FQatPaths[I] := TPath.Create(Self);
    FQatPaths[I].Parent := FQat[I];
    FQatPaths[I].Align := TAlignLayout.Client;
    FQatPaths[I].Margins.Rect := TRectF.Create(8, 7, 8, 7);
    FQatPaths[I].HitTest := False;
    FQatPaths[I].Data.Data := QatPaths[I];
    FQatPaths[I].Fill.Kind := TBrushKind.None;
    FQatPaths[I].Stroke.Thickness := 1.2;
    FQatPaths[I].WrapMode := TPathWrapMode.Fit;
  end;

  // A rotated child: transformed controls paint correctly in the non-client strip.
  DiamondBox := TLayout.Create(Self);
  DiamondBox.Parent := FCaptionRow;
  DiamondBox.Position.X := 190;
  DiamondBox.Align := TAlignLayout.Left;
  DiamondBox.Width := 26;
  FDiamond := TRectangle.Create(Self);
  FDiamond.Parent := DiamondBox;
  FDiamond.HitTest := False;
  FDiamond.SetBounds(7, 10, 12, 12);
  FDiamond.RotationAngle := 45;
  FDiamond.Stroke.Kind := TBrushKind.None;
  FDiamond.Fill.Color := $FFE81123;

  FCombo := TComboBox.Create(Self);
  FCombo.Parent := FCaptionRow;
  FCombo.Position.X := 200;
  FCombo.Align := TAlignLayout.Left;
  FCombo.Width := 130;
  FCombo.Margins.Rect := TRectF.Create(8, 4, 4, 4);
  FCombo.Items.AddStrings(['Document 1', 'Document 2', 'Report.docx', 'Notes.txt', 'Budget.xlsx']);
  FCombo.ItemIndex := 0;
  FCombo.OnChange := ComboChange;
  FCombo.OnPopup := ComboPopup;
  FCombo.OnClosePopup := ComboClosePopup;
  Application.OnException := AppException;

  // A TComboEdit with its own TPopup (Custom): it closes the drop-down when it thinks it was moved out of sight
  // (TStyledComboEdit.DoAbsoluteChanged).
  FZoom := TComboEdit.Create(Self);
  FZoom.Parent := FCaptionRow;
  FZoom.Position.X := 400;
  FZoom.Align := TAlignLayout.Left;
  FZoom.Width := 86;
  FZoom.Margins.Rect := TRectF.Create(4, 4, 4, 4);
  FZoom.Items.AddStrings(['50%', '75%', '100%', '150%', '200%']);
  FZoom.ItemIndex := 2;
  FZoom.DropDownKind := TDropDownKind.Custom;

  FTitle := TLabel.Create(Self);
  FTitle.Parent := FCaptionRow;
  FTitle.Align := TAlignLayout.Client;
  FTitle.HitTest := False;
  FTitle.Text := 'NCProof — FMX controls in the real non-client area';
  FTitle.StyledSettings := FTitle.StyledSettings - [TStyledSetting.FontColor, TStyledSetting.Size];
  FTitle.TextSettings.Font.Size := 12;
  FTitle.TextSettings.HorzAlign := TTextAlign.Center;
  FTitle.TextSettings.WordWrap := False;
  FTitle.TextSettings.Trimming := TTextTrimming.Character;

  FTabRow := TFakeTabRow.Create(Self);
  FTabRow.Parent := Host;
  FTabRow.Align := TAlignLayout.Client;
  FTabRow.OnChange := TabChange;
end;

procedure TNCProofForm.BuildClient;
var
  Panel: TLayout;
  ModeBox: TLayout;
  Mode: TFmrFrameMode;
begin
  FBackground := TRectangle.Create(Self);
  FBackground.Parent := Self;
  FBackground.Align := TAlignLayout.Client;
  FBackground.Stroke.Kind := TBrushKind.None;

  FSidePanel := TRectangle.Create(Self);
  FSidePanel.Parent := FBackground;
  FSidePanel.Align := TAlignLayout.Left;
  FSidePanel.Width := 300;
  FSidePanel.Stroke.Kind := TBrushKind.None;
  FSidePanel.Padding.Rect := TRectF.Create(16, 12, 16, 12);

  Panel := TLayout.Create(Self);
  Panel.Parent := FSidePanel;
  Panel.Align := TAlignLayout.Client;

  FModeLabel := MakeLabel(Panel, 'Frame mode (run time switch):', TAlignLayout.Top, 24);
  ModeBox := TLayout.Create(Self);
  ModeBox.Parent := Panel;
  ModeBox.Align := TAlignLayout.Top;
  ModeBox.Height := 84;
  ModeBox.Position.Y := 100;
  for Mode := Low(TFmrFrameMode) to High(TFmrFrameMode) do
  begin
    FModeRadios[Mode] := TRadioButton.Create(Self);
    FModeRadios[Mode].Parent := ModeBox;
    FModeRadios[Mode].Align := TAlignLayout.Top;
    FModeRadios[Mode].Position.Y := Ord(Mode) * 30;
    FModeRadios[Mode].Height := 26;
    FModeRadios[Mode].GroupName := 'Mode';
    FModeRadios[Mode].Text := ModeNames[Mode];
    FModeRadios[Mode].Tag := Ord(Mode);
    FModeRadios[Mode].StyledSettings := FModeRadios[Mode].StyledSettings - [TStyledSetting.FontColor];
    FModeRadios[Mode].OnChange := ModeRadioChange;
  end;

  FDarkCheck := TCheckBox.Create(Self);
  FDarkCheck.Parent := Panel;
  FDarkCheck.Align := TAlignLayout.Top;
  FDarkCheck.Position.Y := 200;
  FDarkCheck.Height := 28;
  FDarkCheck.Text := 'Dark theme';
  FDarkCheck.StyledSettings := FDarkCheck.StyledSettings - [TStyledSetting.FontColor];
  FDarkCheck.OnChange := DarkCheckChange;

  FTabRowCheck := TCheckBox.Create(Self);
  FTabRowCheck.Parent := Panel;
  FTabRowCheck.Align := TAlignLayout.Top;
  FTabRowCheck.Position.Y := 230;
  FTabRowCheck.Height := 28;
  FTabRowCheck.Text := 'Tab row in the frame (CaptionHeight 64/32)';
  FTabRowCheck.IsChecked := True;
  FTabRowCheck.StyledSettings := FTabRowCheck.StyledSettings - [TStyledSetting.FontColor];
  FTabRowCheck.OnChange := TabRowCheckChange;

  FBackdropLabel := MakeLabel(Panel, 'Backdrop (Dwm mode, Windows 11):', TAlignLayout.Top, 24);
  FBackdropLabel.Position.Y := 260;
  FBackdropCombo := TComboBox.Create(Self);
  FBackdropCombo.Parent := Panel;
  FBackdropCombo.Align := TAlignLayout.Top;
  FBackdropCombo.Position.Y := 290;
  FBackdropCombo.Items.AddStrings(['None', 'Mica', 'Acrylic', 'Tabbed (Mica Alt)']);
  FBackdropCombo.ItemIndex := 0;
  FBackdropCombo.Margins.Bottom := 8;
  FBackdropCombo.OnChange := BackdropChange;

  FMaxToggle := TButton.Create(Self);
  FMaxToggle.Parent := Panel;
  FMaxToggle.Align := TAlignLayout.Top;
  FMaxToggle.Position.Y := 330;
  FMaxToggle.Height := 30;
  FMaxToggle.Text := 'Maximize / restore';
  FMaxToggle.Margins.Bottom := 8;
  FMaxToggle.OnClick := MaxToggleClick;

  // One monitor only here: WM_DPICHANGED is simulated (FMX takes the DPI from the message; the frame recomputes
  // the strip for the new scale).
  FDpiButton := TButton.Create(Self);
  FDpiButton.Parent := Panel;
  FDpiButton.Align := TAlignLayout.Top;
  FDpiButton.Position.Y := 365;
  FDpiButton.Height := 30;
  FDpiButton.Text := 'Simulate WM_DPICHANGED (120 dpi)';
  FDpiButton.Margins.Bottom := 8;
  FDpiButton.OnClick := DpiButtonClick;

  FClientLabel := MakeLabel(Panel, 'Client edit (focus comparison):', TAlignLayout.Top, 24);
  FClientLabel.Position.Y := 370;
  FClientEdit := TEdit.Create(Self);
  FClientEdit.Parent := Panel;
  FClientEdit.Align := TAlignLayout.Top;
  FClientEdit.Position.Y := 400;
  FClientEdit.TextPrompt := 'Client area TEdit';

  FExplain := MakeLabel(Panel, SExplain, TAlignLayout.Client, 100);
  FExplain.Margins.Top := 12;
  FExplain.WordWrap := True;
  FExplain.TextSettings.VertAlign := TTextAlign.Leading;
  FExplain.TextSettings.Font.Size := 11;

  FGeometry := TLabel.Create(Self);
  FGeometry.Parent := FBackground;
  FGeometry.Align := TAlignLayout.Client;
  FGeometry.Margins.Rect := TRectF.Create(20, 12, 12, 12);
  FGeometry.StyledSettings := [];
  FGeometry.TextSettings.Font.Family := 'Consolas';
  FGeometry.TextSettings.Font.Size := 13;
  FGeometry.TextSettings.VertAlign := TTextAlign.Leading;
  FGeometry.TextSettings.WordWrap := False;
end;

procedure TNCProofForm.ApplyCommandLine;
var
  I: Integer;
  S, Value: string;
begin
  for I := 1 to ParamCount do
  begin
    S := ParamStr(I).ToLower;
    if S.StartsWith('/mode=') or S.StartsWith('-mode=') then
    begin
      Value := S.Substring(6);
      if Value = 'dwm' then
        Frame.Mode := TFmrFrameMode.Dwm
      else if Value = 'ncstrip' then
        Frame.Mode := TFmrFrameMode.NCStrip
      else
        Frame.Mode := TFmrFrameMode.FullNC;
    end
    else if (S = '/dark') or (S = '-dark') then
      Frame.DarkMode := True
    else if S.StartsWith('/backdrop=') or S.StartsWith('-backdrop=') then
    begin
      Value := S.Substring(10);
      if Value = 'mica' then
        Frame.Backdrop := TFmrFrameBackdrop.Mica
      else if Value = 'acrylic' then
        Frame.Backdrop := TFmrFrameBackdrop.Acrylic
      else if Value = 'tabbed' then
        Frame.Backdrop := TFmrFrameBackdrop.Tabbed;
    end
    else if (S = '/notabs') or (S = '-notabs') then
      FTabRowCheck.IsChecked := False
    else if (S = '/maximized') or (S = '-maximized') then
      WindowState := TWindowState.wsMaximized
    else if (S = '/topmost') or (S = '-topmost') then
      FormStyle := TFormStyle.StayOnTop
    else if S.StartsWith('/pos=') or S.StartsWith('-pos=') then
    begin
      // Window position in dp (screenshots: keep the window away from other programs).
      Value := S.Substring(5);
      Position := TFormPosition.Designed;
      Left := StrToIntDef(Value.Split([','])[0], Left);
      Top := StrToIntDef(Value.Split([','])[1], Top);
    end
{$IFDEF MSWINDOWS}
    else if S = '/animtest' then
      // Magenta client area: tools can find the window's pixels on the screen (animation measurements).
      FAnimTest := True
    else if S = '/simdpi' then
      // Simulates a DPI change shortly after the start (screenshots).
      TThread.ForceQueue(nil,
        procedure
        begin
          SimulateDpiChange;
        end, 1500)
    else if S = '/fixed' then
      BorderStyle := TFmxFormBorderStyle.Single
    else if S = '/noframe' then
      Frame.Enabled := False
{$ENDIF}
      ;
  end;
end;

procedure TNCProofForm.ApplyTheme;
var
  Dark: Boolean;
  Text, Accent: TAlphaColor;
  Mode: TFmrFrameMode;
  I: Integer;
begin
  FUpdatingUI := True;
  try
    Dark := Frame.DarkMode;
    if Dark then
    begin
      Text := DarkText;
      Accent := DarkAccent;
    end
    else
    begin
      Text := LightText;
      Accent := LightAccent;
    end;
    FDarkCheck.IsChecked := Dark;
    for Mode := Low(TFmrFrameMode) to High(TFmrFrameMode) do
    begin
      FModeRadios[Mode].IsChecked := Frame.Mode = Mode;
      FModeRadios[Mode].TextSettings.FontColor := Text;
    end;
    FBackdropCombo.ItemIndex := Ord(Frame.Backdrop);
    FTabRow.Dark := Dark;
    FAppIcon.Accent := Accent;
    FAppIcon.Repaint;
    FTitle.TextSettings.FontColor := Text;
    for I := 0 to 2 do
      FQatPaths[I].Stroke.Color := Text;
    // The client area keeps a solid background; with a backdrop only the caption shows the material.
    if FAnimTest then
    begin
      FBackground.Fill.Color := $FFFF00FF;
      FSidePanel.Fill.Color := $FFFF00FF;
    end
    else if Dark then
    begin
      FBackground.Fill.Color := DarkClient;
      FSidePanel.Fill.Color := DarkPanel;
    end
    else
    begin
      FBackground.Fill.Color := LightClient;
      FSidePanel.Fill.Color := LightPanel;
    end;
    FModeLabel.TextSettings.FontColor := Text;
    FBackdropLabel.TextSettings.FontColor := Text;
    FClientLabel.TextSettings.FontColor := Text;
    FDarkCheck.TextSettings.FontColor := Text;
    FTabRowCheck.TextSettings.FontColor := Text;
    FExplain.TextSettings.FontColor := Text;
    FGeometry.TextSettings.FontColor := Text;
  finally
    FUpdatingUI := False;
  end;
end;

procedure TNCProofForm.ModeRadioChange(Sender: TObject);
begin
  if FUpdatingUI or not TRadioButton(Sender).IsChecked then
    Exit;
  Frame.Mode := TFmrFrameMode(TRadioButton(Sender).Tag);
  FLastAction := 'mode -> ' + ModeNames[Frame.Mode];
  ApplyTheme;
end;

procedure TNCProofForm.DarkCheckChange(Sender: TObject);
begin
  if FUpdatingUI then
    Exit;
  Frame.DarkMode := FDarkCheck.IsChecked;
  ApplyTheme;
end;

procedure TNCProofForm.TabRowCheckChange(Sender: TObject);
begin
  if FUpdatingUI then
    Exit;
  FTabRow.Visible := FTabRowCheck.IsChecked;
  if FTabRowCheck.IsChecked then
    Frame.CaptionHeight := 64
  else
    Frame.CaptionHeight := 32;
  FLastAction := Format('CaptionHeight -> %.0f', [Frame.CaptionHeight]);
end;

procedure TNCProofForm.BackdropChange(Sender: TObject);
begin
  if FUpdatingUI or (FBackdropCombo.ItemIndex < 0) then
    Exit;
  Frame.Backdrop := TFmrFrameBackdrop(FBackdropCombo.ItemIndex);
  ApplyTheme;
end;

procedure TNCProofForm.MaxToggleClick(Sender: TObject);
begin
  Frame.ToggleMaximize;
end;

procedure TNCProofForm.AddImeInfo(const ALines: TStrings);
{$IFDEF MSWINDOWS}
var
  TextInput: ITextInput;
  Ctrl: TControl;
  Wnd: HWND;
  Scale: Single;
  P, TL, BR: TPoint;
  Clause, SelTL, SelBR: TPointF;
  SelRect: TRectF;
  IMC: HIMC;
  Cand: TCandidateForm;
begin
  if (Focused = nil) or not Supports(Focused, ITextInput, TextInput) or not (Focused.GetObject is TControl) then
    Exit;
  Ctrl := TControl(Focused.GetObject);
  Wnd := FormToHWND(Self);
  Scale := Handle.Scale;
  // What FMX's IME manager computes (TImmManager.UpdateIMEWindowPosition): the target clause point of the focused
  // text input in form client coordinates, passed to ImmSetCandidateWindow.
  Clause := TextInput.GetTargetClausePointF;
  P := TPoint.Create(Round(Clause.X * Scale), Round(Clause.Y * Scale));
  Winapi.Windows.ClientToScreen(Wnd, P);
  TL := DpToPx(Ctrl.LocalToScreen(TPointF.Zero));
  BR := DpToPx(Ctrl.LocalToScreen(TPointF.Create(Ctrl.Width, Ctrl.Height)));
  ALines.Add(Format('IME clause pt   : (%d,%d) screen px; focused control (%d,%d)-(%d,%d)', [P.X, P.Y, TL.X, TL.Y,
    BR.X, BR.Y]));
  // The CFS_EXCLUDE rectangle as FMX computes it: Form.ScreenToClient(Focused.LocalToScreen(selection)).
  SelRect := TextInput.GetSelectionRect;
  SelTL := ScreenToClient(Ctrl.LocalToScreen(SelRect.TopLeft));
  SelBR := ScreenToClient(Ctrl.LocalToScreen(SelRect.BottomRight));
  TL := TPoint.Create(Round(SelTL.X * Scale), Round(SelTL.Y * Scale));
  BR := TPoint.Create(Round(SelBR.X * Scale), Round(SelBR.Y * Scale));
  Winapi.Windows.ClientToScreen(Wnd, TL);
  Winapi.Windows.ClientToScreen(Wnd, BR);
  ALines.Add(Format('IME exclude     : (%d,%d)-(%d,%d) screen px (selection rect of the edit)', [TL.X, TL.Y, BR.X,
    BR.Y]));
  // What FMX really passed to the input context (only while composing: TImmManager.UpdateIMEWindowPosition).
  IMC := ImmGetContext(Wnd);
  if IMC = 0 then
    ALines.Add('IME candidate   : no input context')
  else
  try
    FillChar(Cand, SizeOf(Cand), 0);
    if ImmGetCandidateWindow(IMC, 0, @Cand) then
    begin
      P := Cand.ptCurrentPos;
      Winapi.Windows.ClientToScreen(Wnd, P);
      TL := Cand.rcArea.TopLeft;
      BR := Cand.rcArea.BottomRight;
      Winapi.Windows.ClientToScreen(Wnd, TL);
      Winapi.Windows.ClientToScreen(Wnd, BR);
      ALines.Add(Format('IME candidate   : style $%x pos (%d,%d) exclude (%d,%d)-(%d,%d) screen px',
        [Cand.dwStyle, P.X, P.Y, TL.X, TL.Y, BR.X, BR.Y]));
    end
    else
      ALines.Add('IME candidate   : not set');
  finally
    ImmReleaseContext(Wnd, IMC);
  end;
end;
{$ELSE}
begin
end;
{$ENDIF}

procedure TNCProofForm.DpiButtonClick(Sender: TObject);
begin
  SimulateDpiChange;
end;

procedure TNCProofForm.SimulateDpiChange;
{$IFDEF MSWINDOWS}
var
  Wnd: HWND;
  R: TRect;
  NewDpi, RealDpi: Cardinal;
begin
  Wnd := FormToHWND(Self);
  RealDpi := GetDpiForWindow(Wnd);
  if FSimDpi = 0 then
    FSimDpi := RealDpi;
  if FSimDpi = RealDpi then
    NewDpi := 120
  else
    NewDpi := RealDpi;
  // The suggested rectangle scales the window like Windows does when it moves to a monitor with another DPI.
  GetWindowRect(Wnd, R);
  R.Right := R.Left + MulDiv(R.Width, NewDpi, FSimDpi);
  R.Bottom := R.Top + MulDiv(R.Height, NewDpi, FSimDpi);
  FSimDpi := NewDpi;
  SendMessage(Wnd, WM_DPICHANGED, MakeWParam(NewDpi, NewDpi), LPARAM(@R));
  FLastAction := Format('WM_DPICHANGED %d dpi simulated', [NewDpi]);
  if NewDpi = RealDpi then
    FDpiButton.Text := 'Simulate WM_DPICHANGED (120 dpi)'
  else
    FDpiButton.Text := Format('Simulate WM_DPICHANGED back (%d dpi)', [RealDpi]);
end;
{$ELSE}
begin
end;
{$ENDIF}

procedure TNCProofForm.QatClick(Sender: TObject);
const
  Names: array [0..2] of string = ('Save', 'Undo', 'Redo');
begin
  FLastAction := 'QAT ' + Names[TComponent(Sender).Tag] + ' clicked';
end;

procedure TNCProofForm.TabChange(Sender: TObject);
begin
  FLastAction := 'tab -> ' + FTabRow.Tabs[FTabRow.Selected];
end;

procedure TNCProofForm.ComboChange(Sender: TObject);
begin
  if FCombo.Selected <> nil then
    FLastAction := 'combo -> ' + FCombo.Selected.Text;
end;

procedure TNCProofForm.ComboPopup(Sender: TObject);
begin
  FLastAction := 'combo popup opened';
end;

procedure TNCProofForm.ComboClosePopup(Sender: TObject);
begin
  FLastAction := 'combo popup closed';
end;

procedure TNCProofForm.AppException(Sender: TObject; E: Exception);
begin
  FLastAction := 'EXCEPTION ' + E.ClassName + ': ' + E.Message;
end;

procedure TNCProofForm.SearchChangeTracking(Sender: TObject);
begin
  FLastAction := 'search text: "' + FSearch.Text + '"';
end;

procedure TNCProofForm.FrameStateChanged(Sender: TObject);
var
  OwnButtons: Boolean;
begin
  if Frame.State.Hooked <> FLastHooked then
  begin
    FLastHooked := Frame.State.Hooked;
    FHookLog := FHookLog + Format('; %s (%s)', [IfThen(FLastHooked, 'hooked', 'unhooked'),
      IfThen(Visible, 'visible', 'not shown yet')]);
  end;
  // NCStrip keeps the system title bar with its own buttons.
  OwnButtons := Frame.Mode <> TFmrFrameMode.NCStrip;
  if (FButtonsBox <> nil) and (FButtonsBox.Visible <> OwnButtons) then
  begin
    FButtonsBox.Visible := OwnButtons;
    if OwnButtons then
      FRightBox.Width := 256 + 3 * FmrCaptionButtonWidth
    else
      FRightBox.Width := 256;
  end;
  // The title is an ordinary TLabel: dim it for an inactive window as the caption buttons do.
  if FTitle <> nil then
  begin
    if Frame.State.Active and Frame.DarkMode then
      FTitle.TextSettings.FontColor := DarkText
    else if Frame.State.Active then
      FTitle.TextSettings.FontColor := LightText
    else
      FTitle.TextSettings.FontColor := $FF8A8A8A;
  end;
  if FGeometry <> nil then
    UpdateGeometry(nil);
end;

procedure TNCProofForm.UpdateGeometry(Sender: TObject);
var
  Lines: TStringList;
  FocusedName, InHost: string;
  Focused: IControl;
  FocusedHost: TFmrFrameHost;
{$IFDEF MSWINDOWS}
  Wnd: HWND;
  WR, CR: TRect;
  Origin, Cursor: TPoint;
  Code: LRESULT;
  Dpi: UINT;
  NCRendering: BOOL;
{$ENDIF}
begin
  if FGeometry = nil then
    Exit;
  Lines := TStringList.Create;
  try
    Lines.Add('NCProof geometry (live)');
    Lines.Add('=======================');
    Lines.Add(Format('mode            : %s%s', [ModeNames[Frame.Mode], IfThen(Frame.Hooked, '', '  (not hooked)')]));
    Lines.Add(Format('caption height  : %.0f dp', [Frame.CaptionHeight]));
    Lines.Add(Format('canvas          : %s', [TCanvasManager.DefaultCanvas.ClassName]));
    Lines.Add(Format('state           : active=%s maximized=%s dark=%s backdrop=%d',
      [BoolToStr(Frame.State.Active, True), BoolToStr(Frame.State.Maximized, True),
       BoolToStr(Frame.DarkMode, True), Ord(Frame.Backdrop)]));
{$IFDEF MSWINDOWS}
    if IsHandleAllocated then
    begin
      Wnd := FormToHWND(Self);
      GetWindowRect(Wnd, WR);
      Winapi.Windows.GetClientRect(Wnd, CR);
      Origin := TPoint.Zero;
      Winapi.Windows.ClientToScreen(Wnd, Origin);
      Dpi := GetDpiForWindow(Wnd);
      GetCursorPos(Cursor);
      Code := SendMessage(Wnd, WM_NCHITTEST, 0, MakeLParam(Word(SmallInt(Cursor.X)), Word(SmallInt(Cursor.Y))));
      Lines.Add(Format('window rect     : (%d,%d)-(%d,%d)  %dx%d', [WR.Left, WR.Top, WR.Right, WR.Bottom, WR.Width,
        WR.Height]));
      Lines.Add(Format('client (screen) : (%d,%d)-(%d,%d)  %dx%d', [Origin.X, Origin.Y, Origin.X + CR.Right,
        Origin.Y + CR.Bottom, CR.Right, CR.Bottom]));
      Lines.Add(Format('non-client      : left %d, top %d, right %d, bottom %d', [Origin.X - WR.Left,
        Origin.Y - WR.Top, WR.Right - Origin.X - CR.Right, WR.Bottom - Origin.Y - CR.Bottom]));
      Lines.Add(Format('dpi / scale     : %d / %.2f', [Dpi, Handle.Scale]));
      Lines.Add(Format('FMX client size : %d x %d dp', [ClientWidth, ClientHeight]));
      if Failed(DwmGetWindowAttribute(Wnd, DWMWA_NCRENDERING_ENABLED, @NCRendering, SizeOf(NCRendering))) then
        NCRendering := False;
      Lines.Add(Format('style           : $%.8x  DWM NC rendering: %s', [GetWindowLong(Wnd, GWL_STYLE),
        BoolToStr(NCRendering, True)]));
      Lines.Add(Format('cursor          : (%d,%d) screen px, shape %s', [Cursor.X, Cursor.Y, CursorShapeName]));
      Lines.Add(Format('hit-test        : %s', [FmrHitTestName(Code)]));
    end;
{$ENDIF}
    Lines.Add(Format('host bounds     : (%.1f, %.1f) %.1f x %.1f dp, own scene=%s', [Frame.Host.Position.X,
      Frame.Host.Position.Y, Frame.Host.Width, Frame.Host.Height, BoolToStr(Frame.Host.OwnScene, True)]));
    Focused := Self.Focused;
    if Focused <> nil then
    begin
      FocusedName := Focused.GetObject.ClassName;
      if Focused.GetObject = FSearch then
        FocusedName := FocusedName + ' (caption Search)'
      else if Focused.GetObject = FCombo then
        FocusedName := FocusedName + ' (caption combo)'
      else if Focused.GetObject = FClientEdit then
        FocusedName := FocusedName + ' (client edit)';
      FocusedHost := FmrFindFrameHost(Focused.GetObject);
      if (FocusedHost <> nil) and FocusedHost.OwnScene then
        InHost := 'YES - inside the non-client host'
      else if FocusedHost <> nil then
        InHost := 'in the host (client area, Dwm mode)'
      else
        InHost := 'no (client area)';
    end
    else
    begin
      FocusedName := '(none)';
      InHost := '-';
    end;
    Lines.Add(Format('focused control : %s', [FocusedName]));
    Lines.Add(Format('focus in NC     : %s', [InHost]));
{$IFDEF MSWINDOWS}
    AddImeInfo(Lines);
{$ENDIF}
    Lines.Add(Format('hook log        : %s; state messages: %d', [FHookLog, FStateMessages]));
    Lines.Add(Format('search text     : "%s"', [FSearch.Text]));
    Lines.Add(Format('selected tab    : %s', [FTabRow.Tabs[FTabRow.Selected]]));
    Lines.Add(Format('combo dropped   : %s', [BoolToStr(FCombo.DroppedDown, True)]));
    Lines.Add(Format('last action     : %s', [FLastAction]));
    FGeometry.Text := Lines.Text;
  finally
    Lines.Free;
  end;
end;

end.
