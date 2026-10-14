{*******************************************************}
{                                                       }
{  FMR Ribbon for FireMonkey                            }
{  Extras demo: backstage view and status bar           }
{                                                       }
{  MIT License. Copyright (c) 2026 Fasday               }
{                                                       }
{*******************************************************}

unit ExtrasDemoMain;

/// The form is built in code. A small top bar with a "File" button (painted with the ribbon painter) opens the
/// backstage view; a status bar shows text panels, an item links panel, a container panel, the view buttons and the
/// zoom slider. Themes come from a stub theme provider (TDemoThemeProvider) that stands in for TFmrRibbon, or, with
/// /standalone, from the Theme property of every control.
/// Command line: /theme=<name> /accent=RRGGBB /backstage (start with the view open) /tab=N (0-based tab index)
///               /standalone /noanim /keytips (open the view as with the keyboard)
///               /frame[=fullnc|dwm|ncstrip] (TFmrFormFrame: caption row + tab row in the window frame; the tab row
///               is hidden while the backstage view is open, as the ribbon will do)
///               /pos=X,Y (window position in dp) /topmost (stay on top while tools\drive.ps1 captures it)

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Messaging, System.Math, FMX.Types,
  FMX.Controls, FMX.Forms, FMX.Graphics, FMX.StdCtrls, FMX.Edit, FMX.ListBox, FMX.Layouts, FMX.Objects,
  FMX.SpinBox, FMX.EditBox, FMX.Controls.Presentation, FMR.Ribbon.Types, FMR.Bars.Images, FMR.Bars,
  FMR.Bars.Items, FMR.Ribbon.Theme, FMR.Ribbon.Themes.Builtin, FMR.Ribbon.Painter, FMR.Ribbon.ThemeLink,
  FMR.Ribbon.Backstage, FMR.Ribbon.Backstage.Controls, FMR.Ribbon.StatusBar, FMR.Frame.Types, FMR.Frame.Host,
  FMR.Frame, FMR.Frame.Buttons;

type
  /// <summary>Stand-in for TFmrRibbon: owns a theme and announces its changes.</summary>
  TDemoThemeProvider = class(TFmxObject, IFmrThemeProvider)
  private
    FTheme: TFmrTheme;
    FThemeName: string;
    FAccent: TAlphaColor;
    function GetFmrTheme: TFmrTheme;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure SetTheme(const AName: string; const AAccent: TAlphaColor);
    property ThemeName: string read FThemeName;
  end;

  /// <summary>A minimal tab row: the "File" button and a few inactive tab captions. In the frame's non-client host
  /// the File button is Client, the rest Caption (drag).</summary>
  TDemoTopBar = class(TControl, IFmrFrameHitTest)
  private
    FThemeLink: TFmrThemeLink;
    FFileHot: Boolean;
    FFilePressed: Boolean;
    FOnFileClick: TNotifyEvent;
    function FileRect: TRectF;
    procedure ThemeChanged(Sender: TObject);
    function FrameHitTest(const ALocalPoint: TPointF): TFmrHitArea;
  protected
    procedure Paint; override;
    procedure MouseMove(Shift: TShiftState; X, Y: Single); override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Single); override;
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Single); override;
    procedure DoMouseLeave; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    property ThemeLink: TFmrThemeLink read FThemeLink;
    property OnFileClick: TNotifyEvent read FOnFileClick write FOnFileClick;
  end;

  TExtrasDemoForm = class(TForm)
  private
    FProvider: TDemoThemeProvider;
    FStandalone: Boolean;
    FThemeName: string;
    FAccent: TAlphaColor;
    FThemeMsgId: TMessageSubscriptionId;
    FUpdatingCombos: Boolean;
    FOrder: Integer;
    // optional window frame (/frame=fullnc|dwm|ncstrip)
    FFrame: TFmrFormFrame;
    FCaptionRow: TLayout;
    FCaptionTitle: TFmrCaptionTitle;
    FCaptionButtons: array [0..2] of TFmrCaptionButton;
    // main area
    FTopBar: TDemoTopBar;
    FThemeCombo: TComboBox;
    FDocArea: TRectangle;
    FPage: TRectangle;
    FPageLines: array [0..13] of TRectangle;
    FActionText: TText;
    // status bar
    FBarManager: TFmrBarManager;
    FFocusItem: TFmrButtonItem;
    FCommentsItem: TFmrButtonItem;
    FStatusBar: TFmrStatusBar;
    FPagePanel: TFmrStatusBarPanel;
    FWordsPanel: TFmrStatusBarPanel;
    FLanguagePanel: TFmrStatusBarPanel;
    FProgressPanel: TFmrStatusBarPanel;
    FLinksPanel: TFmrStatusBarPanel;
    FViewPanel: TFmrStatusBarPanel;
    FZoomPanel: TFmrStatusBarPanel;
    // backstage
    FBackstage: TFmrRibbonBackstageView;
    FTabInfo, FTabNew, FTabOpen, FTabSaveAs, FTabPrint, FTabAccount: TFmrBackstageTab;
    FTemplates: TFlowLayout;
    FRecent: TFmrBackstageGalleryList;
    FAccountThemeCombo: TComboBox;
    FPreview: TImage;
    procedure BuildMain;
    procedure BuildFrame(const AMode: TFmrFrameMode);
    procedure BuildStatusBar;
    procedure BuildBackstage;
    procedure BuildInfoTab;
    procedure BuildNewTab;
    procedure BuildOpenTab;
    procedure BuildSaveAsTab;
    procedure BuildPrintTab;
    procedure BuildAccountTab;
    procedure ApplyCommandLine;
    procedure ApplyTheme(const AName: string);
    procedure ApplyDemoColors;
    function CurrentTheme: TFmrTheme;
    procedure ThemeChangedHandler(const Sender: TObject; const M: TMessage);
    procedure LayoutPage;
    procedure SetAction(const AText: string);
    function NextY: Single;
    function AddHeader(const AParent: TFmxObject; const AText: string): TFmrBackstageHeader;
    function AddLabel(const AParent: TFmxObject; const AText: string; const AStyle: TFmrBackstageTextStyle;
      const AAlign: TAlignLayout = TAlignLayout.Top; const ATopMargin: Single = 0): TFmrBackstageLabel;
    function AddTile(const AParent: TFmxObject; const ACaption, ADescription: string; const AGlyph: Cardinal;
      const ALayout: TFmrBackstageTileLayout; const AAlign: TAlignLayout; const AW, AH: Single): TFmrBackstageTile;
    function MakePreviewBitmap: TBitmap;
    procedure FillThemeCombo(const ACombo: TComboBox);
    // events
    procedure FileClick(Sender: TObject);
    procedure ThemeComboChange(Sender: TObject);
    procedure DocAreaResize(Sender: TObject);
    procedure AccountResize(Sender: TObject);
    procedure ZoomChange(Sender: TObject);
    procedure ZoomClick(Sender: TObject);
    procedure ViewChange(Sender: TObject);
    procedure PanelClick(Sender: TObject);
    procedure FocusItemClick(Sender: TObject);
    procedure CommentsItemClick(Sender: TObject);
    procedure BackstageShow(Sender: TObject);
    procedure BackstageHide(Sender: TObject);
    procedure BackstageTabChanged(Sender: TObject);
    procedure BackstageButtonClick(Sender: TObject; const AButton: TFmrBackstageButton);
    procedure SaveClick(Sender: TObject);
    procedure CloseClick(Sender: TObject);
    procedure OptionsClick(Sender: TObject);
    procedure TileClick(Sender: TObject);
    procedure LocationTileClick(Sender: TObject);
    procedure RecentItemClick(Sender: TObject; const AItem: TFmrBackstageGalleryItem);
    procedure TemplateMouseEnter(Sender: TObject);
    procedure TemplateMouseLeave(Sender: TObject);
    procedure TemplateClick(Sender: TObject);
    procedure AppException(Sender: TObject; E: Exception);
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
  end;

var
  ExtrasDemoForm: TExtrasDemoForm;

implementation

const
  // Segoe Fluent Icons / Segoe MDL2 Assets code points
  GlyphInfo = $E946;
  GlyphNew = $E7C3;
  GlyphOpen = $E838;
  GlyphSave = $E74E;
  GlyphSaveAs = $E792;
  GlyphPrint = $E749;
  GlyphClose = $E711;
  GlyphAccount = $E77B;
  GlyphOptions = $E713;
  GlyphLock = $E72E;
  GlyphSearch = $E721;
  GlyphHistory = $E81C;
  GlyphRecent = $E823;
  GlyphCloud = $E753;
  GlyphPC = $E7F4;
  GlyphAdd = $E710;
  GlyphCheck = $E73E;
  GlyphView = $E890;
  GlyphComment = $E8BD;
  GlyphDocument = $E8A5;

{ TDemoThemeProvider }

constructor TDemoThemeProvider.Create(AOwner: TComponent);
begin
  inherited;
  FThemeName := FmrDefaultThemeName;
  FTheme := TFmrTheme.CreateTheme(FThemeName);
end;

destructor TDemoThemeProvider.Destroy;
begin
  FTheme.Free;
  inherited;
end;

function TDemoThemeProvider.GetFmrTheme: TFmrTheme;
begin
  Result := FTheme;
end;

procedure TDemoThemeProvider.SetTheme(const AName: string; const AAccent: TAlphaColor);
var
  Old: TFmrTheme;
begin
  Old := FTheme;
  FTheme := TFmrTheme.CreateTheme(AName, AAccent);
  FThemeName := FTheme.Name;
  FAccent := AAccent;
  TMessageManager.DefaultManager.SendMessage(Self, TFmrThemeChangedMessage.Create(Self));
  Old.Free;
end;

{ TDemoTopBar }

constructor TDemoTopBar.Create(AOwner: TComponent);
begin
  inherited;
  FThemeLink := TFmrThemeLink.Create(Self, ThemeChanged);
  HitTest := True;
end;

destructor TDemoTopBar.Destroy;
begin
  FThemeLink.Free;
  inherited;
end;

procedure TDemoTopBar.ThemeChanged(Sender: TObject);
begin
  Repaint;
end;

function TDemoTopBar.FileRect: TRectF;
begin
  Result := RectF(4, 4, 64, Height);
end;

function TDemoTopBar.FrameHitTest(const ALocalPoint: TPointF): TFmrHitArea;
begin
  if FileRect.Contains(ALocalPoint) then
    Result := TFmrHitArea.Client
  else
    Result := TFmrHitArea.Caption;
end;

procedure TDemoTopBar.Paint;
const
  Tabs: array [0..5] of string = ('Home', 'Insert', 'Design', 'Layout', 'References', 'Review');
var
  P: TFmrRibbonPainter;
  T: TFmrTheme;
  R: TRectF;
  X, W: Single;
  I: Integer;
  State: TFmrPartState;
begin
  P := FThemeLink.Painter;
  T := FThemeLink.Theme;
  R := LocalRect;
  P.DrawTabRow(Canvas, R, True);
  if FFilePressed then
    State := TFmrPartState.Pressed
  else if FFileHot then
    State := TFmrPartState.Hot
  else
    State := TFmrPartState.Normal;
  P.DrawAppButton(Canvas, FileRect, 'File', State);
  X := FileRect.Right + 6;
  for I := 0 to High(Tabs) do
  begin
    W := P.TextWidth(Tabs[I]) + T.Metrics.TabPaddingH * 2;
    P.DrawTab(Canvas, RectF(X, 4, X + W, R.Bottom), Tabs[I], False, I = 0, True, False);
    X := X + W + T.Metrics.TabSpacing;
  end;
end;

procedure TDemoTopBar.MouseMove(Shift: TShiftState; X, Y: Single);
var
  Hot: Boolean;
begin
  inherited;
  Hot := FileRect.Contains(PointF(X, Y));
  if Hot <> FFileHot then
  begin
    FFileHot := Hot;
    Repaint;
  end;
end;

procedure TDemoTopBar.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Single);
begin
  inherited;
  if (Button = TMouseButton.mbLeft) and FileRect.Contains(PointF(X, Y)) then
  begin
    FFilePressed := True;
    Repaint;
  end;
end;

procedure TDemoTopBar.MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Single);
begin
  inherited;
  if FFilePressed then
  begin
    FFilePressed := False;
    Repaint;
    if FileRect.Contains(PointF(X, Y)) and Assigned(FOnFileClick) then
      FOnFileClick(Self);
  end;
end;

procedure TDemoTopBar.DoMouseLeave;
begin
  inherited;
  FFileHot := False;
  FFilePressed := False;
  Repaint;
end;

{ TExtrasDemoForm }

constructor TExtrasDemoForm.Create(AOwner: TComponent);
begin
  inherited CreateNew(AOwner);
  Application.OnException := AppException;
  Caption := 'FMR Ribbon - backstage view and status bar';
  ClientWidth := 1180;
  ClientHeight := 760;
  Position := TFormPosition.ScreenCenter;
  FThemeName := FmrDefaultThemeName;
  FProvider := TDemoThemeProvider.Create(Self);
  FThemeMsgId := TMessageManager.DefaultManager.SubscribeToMessage(TFmrThemeChangedMessage, ThemeChangedHandler);
  BuildMain;
  BuildStatusBar;
  BuildBackstage;
  ApplyCommandLine;
end;

destructor TExtrasDemoForm.Destroy;
begin
  TMessageManager.DefaultManager.Unsubscribe(TFmrThemeChangedMessage, FThemeMsgId);
  inherited;
end;

procedure TExtrasDemoForm.AppException(Sender: TObject; E: Exception);
begin
  SetAction('Exception: ' + E.ClassName + ': ' + E.Message);
end;

function TExtrasDemoForm.CurrentTheme: TFmrTheme;
begin
  if FStandalone then
    Result := FStatusBar.CurrentTheme
  else
    Result := FProvider.GetFmrTheme;
end;

procedure TExtrasDemoForm.SetAction(const AText: string);
begin
  if FActionText <> nil then
    FActionText.Text := 'Last action: ' + AText;
end;

procedure TExtrasDemoForm.FillThemeCombo(const ACombo: TComboBox);
var
  N: string;
begin
  ACombo.BeginUpdate;
  try
    ACombo.Items.Clear;
    for N in TFmrTheme.ThemeNames do
      ACombo.Items.Add(N);
  finally
    ACombo.EndUpdate;
  end;
end;

{ main area }

procedure TExtrasDemoForm.BuildMain;
var
  I: Integer;
begin
  FTopBar := TDemoTopBar.Create(Self);
  FTopBar.Align := TAlignLayout.Top;
  FTopBar.Height := 34;
  FTopBar.Parent := Self;
  FTopBar.OnFileClick := FileClick;
  FTopBar.ThemeLink.Provider := FProvider;

  FThemeCombo := TComboBox.Create(Self);
  FThemeCombo.Parent := FTopBar;
  FThemeCombo.Align := TAlignLayout.Right;
  FThemeCombo.Width := 190;
  FThemeCombo.Margins.Rect := RectF(0, 6, 8, 4);
  FillThemeCombo(FThemeCombo);
  FThemeCombo.OnChange := ThemeComboChange;

  FDocArea := TRectangle.Create(Self);
  FDocArea.Align := TAlignLayout.Client;
  FDocArea.Stroke.Kind := TBrushKind.None;
  FDocArea.ClipChildren := True;
  FDocArea.Parent := Self;
  FDocArea.OnResize := DocAreaResize;

  FPage := TRectangle.Create(Self);
  FPage.Parent := FDocArea;
  FPage.Fill.Color := TAlphaColors.White;
  FPage.Stroke.Color := $FFD0D0D0;
  FPage.HitTest := False;
  for I := 0 to High(FPageLines) do
  begin
    FPageLines[I] := TRectangle.Create(Self);
    FPageLines[I].Parent := FPage;
    FPageLines[I].Stroke.Kind := TBrushKind.None;
    FPageLines[I].Fill.Color := $FFDADADA;
    FPageLines[I].HitTest := False;
  end;
  FPageLines[0].Fill.Color := $FF9A9A9A;

  FActionText := TText.Create(Self);
  FActionText.Parent := FDocArea;
  FActionText.Align := TAlignLayout.Bottom;
  FActionText.Height := 24;
  FActionText.Margins.Rect := RectF(12, 0, 12, 4);
  FActionText.TextSettings.HorzAlign := TTextAlign.Leading;
  FActionText.TextSettings.Font.Size := 12;
  FActionText.HitTest := False;
  SetAction('none');
end;

procedure TExtrasDemoForm.LayoutPage;
var
  Zoom: Integer;
  W, H, X, Y, LineH, Gap: Single;
  I: Integer;
  View: TFmrStatusView;
  Area: TRectF;
begin
  if (FPage = nil) or (FDocArea = nil) then
    Exit;
  if FZoomPanel <> nil then
  begin
    Zoom := FZoomPanel.Zoom;
    View := FViewPanel.ActiveView;
  end
  else
  begin
    Zoom := 100;
    View := TFmrStatusView.Print;
  end;
  Area := RectF(0, 0, FDocArea.Width, FDocArea.Height - 28);
  W := 400 * Zoom / 100;
  H := 520 * Zoom / 100;
  if View = TFmrStatusView.Web then
    W := Max(200, Area.Width - 40);
  X := (Area.Width - W) / 2;
  Y := 24;
  FPage.SetBounds(X, Y, W, H);
  if View = TFmrStatusView.Read then
    FPage.Fill.Color := $FFF8F1E3
  else
    FPage.Fill.Color := TAlphaColors.White;
  LineH := Max(2, 6 * Zoom / 100);
  Gap := Max(4, 18 * Zoom / 100);
  for I := 0 to High(FPageLines) do
  begin
    if I = 0 then
      FPageLines[I].SetBounds(W * 0.12, H * 0.08, W * 0.5, LineH * 2)
    else
      FPageLines[I].SetBounds(W * 0.12, H * 0.08 + LineH * 2 + Gap + (I - 1) * (LineH + Gap),
        W * IfThen(I mod 5 = 0, 0.45, 0.76), LineH);
  end;
end;

procedure TExtrasDemoForm.BuildFrame(const AMode: TFmrFrameMode);
const
  Kinds: array [0..2] of TFmrCaptionButtonKind = (TFmrCaptionButtonKind.Minimize, TFmrCaptionButtonKind.Maximize,
    TFmrCaptionButtonKind.Close);
var
  I: Integer;
  Box: TLayout;
begin
  // Stand-in for the ribbon's caption row and tab row in the window frame: the caption row stays visible while the
  // backstage view is open, the tab row (FTopBar) is hidden (see BackstageShow / BackstageHide)
  FFrame := TFmrFormFrame.Create(Self);
  FFrame.Mode := AMode;
  FCaptionRow := TLayout.Create(Self);
  FCaptionRow.Align := TAlignLayout.Top;
  FCaptionRow.Height := 32;
  FCaptionRow.Parent := FFrame.Host;
  Box := TLayout.Create(Self);
  Box.Align := TAlignLayout.Right;
  Box.Width := 3 * FmrCaptionButtonWidth;
  Box.Parent := FCaptionRow;
  Box.Visible := AMode <> TFmrFrameMode.NCStrip;
  for I := 0 to 2 do
  begin
    // Left alignment keeps the creation order with a growing X
    FCaptionButtons[I] := TFmrCaptionButton.Create(Self);
    FCaptionButtons[I].Kind := Kinds[I];
    FCaptionButtons[I].Position.X := 1000 + I * 1000;
    FCaptionButtons[I].Align := TAlignLayout.Left;
    FCaptionButtons[I].Parent := Box;
  end;
  FCaptionTitle := TFmrCaptionTitle.Create(Self);
  FCaptionTitle.Align := TAlignLayout.Client;
  FCaptionTitle.Margins.Left := 12;
  FCaptionTitle.HitTest := False;
  FCaptionTitle.Text := Caption;
  FCaptionTitle.Parent := FCaptionRow;
  FTopBar.Parent := FFrame.Host;
  FTopBar.Position.Y := 100;
  FFrame.CaptionHeight := FCaptionRow.Height + FTopBar.Height;
end;

procedure TExtrasDemoForm.DocAreaResize(Sender: TObject);
begin
  LayoutPage;
end;

procedure TExtrasDemoForm.FileClick(Sender: TObject);
begin
  FBackstage.Show;
end;

{ status bar }

procedure TExtrasDemoForm.BuildStatusBar;
var
  Bar: TProgressBar;
begin
  FBarManager := TFmrBarManager.Create(Self);
  FBarManager.Parent := Self;
  FFocusItem := TFmrButtonItem(FBarManager.CreateItem(TFmrButtonItem, 'btnFocus'));
  FFocusItem.Caption := 'Focus';
  FFocusItem.Hint := 'Focus mode';
  FFocusItem.ButtonStyle := TFmrButtonStyle.Check;
  FFocusItem.Glyph.GlyphCode := GlyphView;
  FFocusItem.OnClick := FocusItemClick;
  FCommentsItem := TFmrButtonItem(FBarManager.CreateItem(TFmrButtonItem, 'btnComments'));
  FCommentsItem.Caption := 'Comments';
  FCommentsItem.Hint := 'Show comments';
  FCommentsItem.Glyph.GlyphCode := GlyphComment;
  FCommentsItem.OnClick := CommentsItemClick;

  FStatusBar := TFmrStatusBar.Create(Self);
  FStatusBar.Parent := Self;
  FStatusBar.BarManager := FBarManager;

  FPagePanel := FStatusBar.AddPanel(TFmrStatusPanelKind.Text, 'Page 1 of 3');
  FPagePanel.Hint := 'Page number in document. Click to open the Go To dialog.';
  FPagePanel.OnClick := PanelClick;
  FWordsPanel := FStatusBar.AddPanel(TFmrStatusPanelKind.Text, '245 words');
  FWordsPanel.Hint := 'Word count. Click to open the Word Count dialog.';
  FWordsPanel.OnClick := PanelClick;
  FLanguagePanel := FStatusBar.AddPanel(TFmrStatusPanelKind.Text, 'English (United States)');
  FLanguagePanel.Glyph.GlyphCode := GlyphCheck;
  FLanguagePanel.Hint := 'Language and proofing';
  FLanguagePanel.OnClick := PanelClick;
  FProgressPanel := FStatusBar.AddPanel(TFmrStatusPanelKind.Container);
  FProgressPanel.PanelWidth := 96;
  FProgressPanel.Padding.Rect := RectF(6, 6, 6, 6);
  FProgressPanel.Hint := 'Container panel with a TProgressBar';
  Bar := TProgressBar.Create(Self);
  Bar.Parent := FProgressPanel;
  Bar.Align := TAlignLayout.Client;
  Bar.Value := 60;

  FLinksPanel := FStatusBar.AddPanel(TFmrStatusPanelKind.ItemLinks, '', TFmrStatusPanelSide.Right);
  FLinksPanel.ItemLinks.AddItem(FFocusItem);
  FLinksPanel.ItemLinks.AddItem(FCommentsItem);
  FViewPanel := FStatusBar.AddPanel(TFmrStatusPanelKind.ViewButtons, '', TFmrStatusPanelSide.Right);
  FViewPanel.OnViewChange := ViewChange;
  FZoomPanel := FStatusBar.AddPanel(TFmrStatusPanelKind.ZoomSlider, '', TFmrStatusPanelSide.Right);
  FZoomPanel.OnZoomChange := ZoomChange;
  FZoomPanel.OnZoomClick := ZoomClick;
  FStatusBar.ThemeProvider := FProvider;
end;

procedure TExtrasDemoForm.ZoomChange(Sender: TObject);
begin
  LayoutPage;
  SetAction(Format('zoom %d%%', [FZoomPanel.Zoom]));
end;

procedure TExtrasDemoForm.ZoomClick(Sender: TObject);
begin
  FZoomPanel.Zoom := 100;
  SetAction('zoom percentage clicked (reset to 100%)');
end;

procedure TExtrasDemoForm.ViewChange(Sender: TObject);
const
  Names: array [TFmrStatusView] of string = ('Read Mode', 'Print Layout', 'Web Layout');
begin
  LayoutPage;
  SetAction('view ' + Names[FViewPanel.ActiveView]);
end;

procedure TExtrasDemoForm.PanelClick(Sender: TObject);
begin
  SetAction('status panel "' + TFmrStatusBarPanel(Sender).Text + '" clicked');
end;

procedure TExtrasDemoForm.FocusItemClick(Sender: TObject);
begin
  SetAction('Focus ' + BoolToStr(FFocusItem.Down, True));
end;

procedure TExtrasDemoForm.CommentsItemClick(Sender: TObject);
begin
  SetAction('Comments clicked');
end;

{ backstage }

function TExtrasDemoForm.NextY: Single;
begin
  // FMX stacks Top aligned controls by Position.Y: a growing Y keeps the creation order
  Inc(FOrder);
  Result := FOrder * 1000;
end;

function TExtrasDemoForm.AddHeader(const AParent: TFmxObject; const AText: string): TFmrBackstageHeader;
begin
  Result := TFmrBackstageHeader.Create(Self);
  Result.Text := AText;
  Result.Position.Y := NextY;
  Result.Parent := AParent;
end;

function TExtrasDemoForm.AddLabel(const AParent: TFmxObject; const AText: string;
  const AStyle: TFmrBackstageTextStyle; const AAlign: TAlignLayout; const ATopMargin: Single): TFmrBackstageLabel;
begin
  Result := TFmrBackstageLabel.Create(Self);
  Result.TextStyle := AStyle;
  Result.Text := AText;
  Result.Align := AAlign;
  Result.Margins.Top := ATopMargin;
  Result.Position.Y := NextY;
  Result.Parent := AParent;
end;

function TExtrasDemoForm.AddTile(const AParent: TFmxObject; const ACaption, ADescription: string;
  const AGlyph: Cardinal; const ALayout: TFmrBackstageTileLayout; const AAlign: TAlignLayout;
  const AW, AH: Single): TFmrBackstageTile;
begin
  Result := TFmrBackstageTile.Create(Self);
  Result.Caption := ACaption;
  Result.Description := ADescription;
  Result.Glyph.GlyphCode := AGlyph;
  Result.Layout := ALayout;
  Result.Align := AAlign;
  Result.Width := AW;
  Result.Height := AH;
  Result.Position.Y := NextY;
  Result.Parent := AParent;
end;

procedure TExtrasDemoForm.BuildBackstage;
var
  B: TFmrBackstageButton;
begin
  FBackstage := TFmrRibbonBackstageView.Create(Self);
  FBackstage.Parent := Self;
  FBackstage.BarManager := FBarManager;
  FBackstage.OnShow := BackstageShow;
  FBackstage.OnHide := BackstageHide;
  FBackstage.OnTabChanged := BackstageTabChanged;
  FBackstage.OnButtonClick := BackstageButtonClick;

  FTabInfo := FBackstage.AddTab('Info');
  FTabInfo.Glyph.GlyphCode := GlyphInfo;
  FTabNew := FBackstage.AddTab('New');
  FTabNew.Glyph.GlyphCode := GlyphNew;
  FTabOpen := FBackstage.AddTab('Open');
  FTabOpen.Glyph.GlyphCode := GlyphOpen;
  B := FBackstage.AddButton('Save', SaveClick);
  B.Glyph.GlyphCode := GlyphSave;
  B.BeginGroup := True;
  B.Hint := 'Save the document (Ctrl+S)';
  FTabSaveAs := FBackstage.AddTab('Save As');
  FTabSaveAs.Glyph.GlyphCode := GlyphSaveAs;
  FTabPrint := FBackstage.AddTab('Print');
  FTabPrint.Glyph.GlyphCode := GlyphPrint;
  B := FBackstage.AddButton('Close', CloseClick);
  B.Glyph.GlyphCode := GlyphClose;
  B.BeginGroup := True;
  FTabAccount := FBackstage.AddTab('Account');
  FTabAccount.Glyph.GlyphCode := GlyphAccount;
  FTabAccount.NavAlign := TFmrBackstageNavAlign.Bottom;
  B := FBackstage.AddButton('Options', OptionsClick);
  B.Glyph.GlyphCode := GlyphOptions;
  B.NavAlign := TFmrBackstageNavAlign.Bottom;
  B.KeepOpen := True;

  BuildInfoTab;
  BuildNewTab;
  BuildOpenTab;
  BuildSaveAsTab;
  BuildPrintTab;
  BuildAccountTab;
  FBackstage.ActiveTab := FTabInfo;
  FBackstage.ThemeProvider := FProvider;
end;

procedure TExtrasDemoForm.BuildInfoTab;
const
  Sections: array [0..2] of record
    Caption, Title, Text: string;
    Glyph: Cardinal;
  end = (
    (Caption: 'Protect Document'; Title: 'Protect Document';
     Text: 'Control what types of changes people can make to this document.'; Glyph: GlyphLock),
    (Caption: 'Check for Issues'; Title: 'Inspect Document';
     Text: 'Before publishing this file, be aware that it contains document properties and the author''s name.';
     Glyph: GlyphSearch),
    (Caption: 'Version History'; Title: 'Version History';
     Text: 'View and restore previous versions.'; Glyph: GlyphHistory));
var
  Props, Left, Row, TextBox: TLayout;
  Tile: TFmrBackstageTile;
  I: Integer;
begin
  AddHeader(FTabInfo, 'Info');
  AddLabel(FTabInfo, 'Document1', TFmrBackstageTextStyle.Title);
  AddLabel(FTabInfo, 'Documents » Projects » FMR Ribbon', TFmrBackstageTextStyle.Secondary).Margins.Bottom := 16;

  Props := TLayout.Create(Self);
  Props.Parent := FTabInfo;
  Props.Align := TAlignLayout.Right;
  Props.Width := 260;
  Props.Margins.Left := 24;
  AddLabel(Props, 'Properties', TFmrBackstageTextStyle.Subtitle);
  AddLabel(Props, 'Size: 24.6 KB', TFmrBackstageTextStyle.Secondary, TAlignLayout.Top, 8);
  AddLabel(Props, 'Pages: 3', TFmrBackstageTextStyle.Secondary, TAlignLayout.Top, 4);
  AddLabel(Props, 'Words: 245', TFmrBackstageTextStyle.Secondary, TAlignLayout.Top, 4);
  AddLabel(Props, 'Total editing time: 42 minutes', TFmrBackstageTextStyle.Secondary, TAlignLayout.Top, 4);
  AddLabel(Props, 'Related Dates', TFmrBackstageTextStyle.Subtitle, TAlignLayout.Top, 20);
  AddLabel(Props, 'Last Modified: Today, 09:41', TFmrBackstageTextStyle.Secondary, TAlignLayout.Top, 8);
  AddLabel(Props, 'Created: Yesterday, 18:02', TFmrBackstageTextStyle.Secondary, TAlignLayout.Top, 4);
  AddLabel(Props, 'Related People', TFmrBackstageTextStyle.Subtitle, TAlignLayout.Top, 20);
  AddLabel(Props, 'Author: Jane Doe', TFmrBackstageTextStyle.Secondary, TAlignLayout.Top, 8);

  Left := TLayout.Create(Self);
  Left.Parent := FTabInfo;
  Left.Align := TAlignLayout.Client;
  for I := 0 to High(Sections) do
  begin
    Row := TLayout.Create(Self);
    Row.Parent := Left;
    Row.Align := TAlignLayout.Top;
    Row.Height := 104;
    Row.Margins.Bottom := 12;
    Row.Position.Y := NextY;
    Tile := AddTile(Row, Sections[I].Caption, '', Sections[I].Glyph, TFmrBackstageTileLayout.Vertical,
      TAlignLayout.Left, 100, 100);
    Tile.Margins.Bottom := 4;
    Tile.OnClick := TileClick;
    TextBox := TLayout.Create(Self);
    TextBox.Parent := Row;
    TextBox.Align := TAlignLayout.Client;
    TextBox.Margins.Left := 18;
    AddLabel(TextBox, Sections[I].Title, TFmrBackstageTextStyle.Subtitle, TAlignLayout.Top, 6);
    AddLabel(TextBox, Sections[I].Text, TFmrBackstageTextStyle.Secondary, TAlignLayout.Top, 6);
  end;
end;

procedure TExtrasDemoForm.BuildNewTab;
const
  Names: array [0..7] of string = ('Blank document', 'Welcome tour', 'Single spaced (blank)', 'Resume',
    'Cover letter', 'Report', 'Newsletter', 'Brochure');
var
  I, J: Integer;
  Card, Preview, Line: TRectangle;
  Txt: TText;
begin
  AddHeader(FTabNew, 'New');
  AddLabel(FTabNew, 'Templates made of standard FMX controls (TFlowLayout, TRectangle, TText):',
    TFmrBackstageTextStyle.Secondary).Margins.Bottom := 12;
  FTemplates := TFlowLayout.Create(Self);
  FTemplates.Parent := FTabNew;
  FTemplates.Align := TAlignLayout.Client;
  FTemplates.HorizontalGap := 18;
  FTemplates.VerticalGap := 18;
  for I := 0 to High(Names) do
  begin
    Card := TRectangle.Create(Self);
    Card.Parent := FTemplates;
    Card.Width := 150;
    Card.Height := 200;
    Card.Fill.Kind := TBrushKind.None;
    Card.Stroke.Kind := TBrushKind.Solid;
    Card.XRadius := 3;
    Card.YRadius := 3;
    Card.Tag := I;
    Card.Cursor := crHandPoint;
    Card.OnMouseEnter := TemplateMouseEnter;
    Card.OnMouseLeave := TemplateMouseLeave;
    Card.OnClick := TemplateClick;
    Preview := TRectangle.Create(Self);
    Preview.Parent := Card;
    Preview.Align := TAlignLayout.Top;
    Preview.Height := 150;
    Preview.Margins.Rect := RectF(8, 8, 8, 0);
    Preview.Fill.Color := TAlphaColors.White;
    Preview.Stroke.Color := $FFD6D6D6;
    Preview.HitTest := False;
    if I > 0 then
      for J := 0 to 6 do
      begin
        Line := TRectangle.Create(Self);
        Line.Parent := Preview;
        Line.Stroke.Kind := TBrushKind.None;
        if J = 0 then
          Line.Fill.Color := $FF2B579A
        else
          Line.Fill.Color := $FFDDDDDD;
        Line.SetBounds(14, 18 + J * 16, IfThen(J = 0, 70, 100 - (J mod 3) * 14), IfThen(J = 0, 8, 5));
        Line.HitTest := False;
      end;
    Txt := TText.Create(Self);
    Txt.Parent := Card;
    Txt.Align := TAlignLayout.Client;
    Txt.Margins.Rect := RectF(6, 4, 6, 4);
    Txt.Text := Names[I];
    Txt.TextSettings.Font.Size := 12;
    Txt.TextSettings.WordWrap := True;
    Txt.HitTest := False;
  end;
end;

procedure TExtrasDemoForm.BuildOpenTab;
var
  Left: TLayout;
  T: TFmrBackstageTile;
begin
  AddHeader(FTabOpen, 'Open');
  Left := TLayout.Create(Self);
  Left.Parent := FTabOpen;
  Left.Align := TAlignLayout.Left;
  Left.Width := 250;
  Left.Margins.Right := 24;
  T := AddTile(Left, 'Recent', '', GlyphRecent, TFmrBackstageTileLayout.Horizontal, TAlignLayout.Top, 250, 52);
  T.Selected := True;
  T.ShowFrame := False;
  T.OnClick := LocationTileClick;
  T := AddTile(Left, 'Cloud - Personal', '', GlyphCloud, TFmrBackstageTileLayout.Horizontal, TAlignLayout.Top,
    250, 52);
  T.ShowFrame := False;
  T.OnClick := LocationTileClick;
  T := AddTile(Left, 'This PC', '', GlyphPC, TFmrBackstageTileLayout.Horizontal, TAlignLayout.Top, 250, 52);
  T.ShowFrame := False;
  T.OnClick := LocationTileClick;
  T := AddTile(Left, 'Browse', '', GlyphOpen, TFmrBackstageTileLayout.Horizontal, TAlignLayout.Top, 250, 52);
  T.ShowFrame := False;
  T.OnClick := LocationTileClick;

  FRecent := TFmrBackstageGalleryList.Create(Self);
  FRecent.Parent := FTabOpen;
  FRecent.Align := TAlignLayout.Client;
  FRecent.Items.AddHeader('Today');
  FRecent.Items.AddItem('Quarterly report.docx', 'Documents » Reports');
  FRecent.Items.AddItem('Ribbon design notes.docx', 'Documents » Projects » FMR Ribbon');
  FRecent.Items.AddHeader('Yesterday');
  FRecent.Items.AddItem('Meeting minutes.docx', 'Cloud » Team » Minutes');
  FRecent.Items.AddItem('Letter to customers.docx', 'Documents » Letters');
  FRecent.Items.AddHeader('Older');
  FRecent.Items.AddItem('Product brochure.docx', 'Desktop', GlyphDocument);
  FRecent.Items.AddItem('Thesis draft.docx', 'Documents » University');
  FRecent.Items.AddItem('Recipes.docx', 'Cloud » Personal');
  FRecent.Items.AddItem('Travel plan.docx', 'Documents » Travel');
  FRecent.OnItemClick := RecentItemClick;
end;

procedure TExtrasDemoForm.BuildSaveAsTab;
var
  Left, Right, Row: TLayout;
  T: TFmrBackstageTile;
  Edit: TEdit;
  Combo: TComboBox;
  Btn: TButton;
begin
  AddHeader(FTabSaveAs, 'Save As');
  Left := TLayout.Create(Self);
  Left.Parent := FTabSaveAs;
  Left.Align := TAlignLayout.Left;
  Left.Width := 260;
  Left.Margins.Right := 28;
  T := AddTile(Left, 'Cloud - Personal', 'jane@example.com', GlyphCloud, TFmrBackstageTileLayout.Horizontal,
    TAlignLayout.Top, 260, 60);
  T.OnClick := LocationTileClick;
  T.ShowFrame := False;
  T := AddTile(Left, 'This PC', '', GlyphPC, TFmrBackstageTileLayout.Horizontal, TAlignLayout.Top, 260, 60);
  T.Selected := True;
  T.ShowFrame := False;
  T.OnClick := LocationTileClick;
  T := AddTile(Left, 'Add a Place', '', GlyphAdd, TFmrBackstageTileLayout.Horizontal, TAlignLayout.Top, 260, 60);
  T.ShowFrame := False;
  T.OnClick := LocationTileClick;
  T := AddTile(Left, 'Browse', '', GlyphOpen, TFmrBackstageTileLayout.Horizontal, TAlignLayout.Top, 260, 60);
  T.ShowFrame := False;
  T.OnClick := LocationTileClick;

  Right := TLayout.Create(Self);
  Right.Parent := FTabSaveAs;
  Right.Align := TAlignLayout.Client;
  AddLabel(Right, 'Documents', TFmrBackstageTextStyle.Title);
  AddLabel(Right, 'C:\Users\Jane\Documents', TFmrBackstageTextStyle.Secondary, TAlignLayout.Top, 2);
  Edit := TEdit.Create(Self);
  Edit.Align := TAlignLayout.Top;
  Edit.Margins.Rect := RectF(0, 18, 120, 0);
  Edit.Position.Y := NextY;
  Edit.Parent := Right;
  Edit.Text := 'Document1';
  Combo := TComboBox.Create(Self);
  Combo.Align := TAlignLayout.Top;
  Combo.Margins.Rect := RectF(0, 10, 120, 0);
  Combo.Position.Y := NextY;
  Combo.Parent := Right;
  Combo.Items.Add('Document (*.docx)');
  Combo.Items.Add('PDF (*.pdf)');
  Combo.Items.Add('Plain Text (*.txt)');
  Combo.ItemIndex := 0;
  Row := TLayout.Create(Self);
  Row.Align := TAlignLayout.Top;
  Row.Height := 46;
  Row.Position.Y := NextY;
  Row.Parent := Right;
  Btn := TButton.Create(Self);
  Btn.Parent := Row;
  Btn.Align := TAlignLayout.Left;
  Btn.Margins.Rect := RectF(0, 14, 0, 0);
  Btn.Width := 100;
  Btn.Text := 'Save';
  Btn.OnClick := SaveClick;
end;

function TExtrasDemoForm.MakePreviewBitmap: TBitmap;
var
  C: TCanvas;
  I: Integer;
  W, H: Integer;
begin
  W := 420;
  H := 560;
  Result := TBitmap.Create(W, H);
  C := Result.Canvas;
  if C.BeginScene then
  try
    C.Clear(TAlphaColors.White);
    C.Stroke.Kind := TBrushKind.Solid;
    C.Stroke.Color := $FFC8C8C8;
    C.DrawRect(RectF(0.5, 0.5, W - 0.5, H - 0.5), 0, 0, [], 1);
    C.Fill.Kind := TBrushKind.Solid;
    C.Fill.Color := $FF2B579A;
    C.FillRect(RectF(48, 48, 260, 64), 0, 0, [], 1);
    C.Fill.Color := $FFD8D8D8;
    for I := 0 to 22 do
      C.FillRect(RectF(48, 88 + I * 19, W - 48 - (I mod 4) * 30, 96 + I * 19), 0, 0, [], 1);
  finally
    C.EndScene;
  end;
end;

procedure TExtrasDemoForm.BuildPrintTab;
var
  Left, Row: TLayout;
  T: TFmrBackstageTile;
  Spin: TSpinBox;
  Combo: TComboBox;
  Bmp: TBitmap;
begin
  AddHeader(FTabPrint, 'Print');
  Left := TLayout.Create(Self);
  Left.Parent := FTabPrint;
  Left.Align := TAlignLayout.Left;
  Left.Width := 300;
  Left.Margins.Right := 32;
  Row := TLayout.Create(Self);
  Row.Parent := Left;
  Row.Align := TAlignLayout.Top;
  Row.Height := 100;
  T := AddTile(Row, 'Print', '', GlyphPrint, TFmrBackstageTileLayout.Vertical, TAlignLayout.Left, 96, 96);
  T.OnClick := TileClick;
  Spin := TSpinBox.Create(Self);
  Spin.Parent := Row;
  Spin.Align := TAlignLayout.None;
  Spin.SetBounds(116, 30, 110, 30);
  Spin.Min := 1;
  Spin.Max := 99;
  Spin.Value := 1;
  AddLabel(Row, 'Copies', TFmrBackstageTextStyle.Secondary, TAlignLayout.None).SetBounds(116, 6, 120, 20);
  AddLabel(Left, 'Printer', TFmrBackstageTextStyle.Subtitle, TAlignLayout.Top, 18);
  Combo := TComboBox.Create(Self);
  Combo.Align := TAlignLayout.Top;
  Combo.Margins.Top := 8;
  Combo.Position.Y := NextY;
  Combo.Parent := Left;
  Combo.Items.Add('Print to PDF');
  Combo.Items.Add('Laser printer (2nd floor)');
  Combo.ItemIndex := 0;
  AddLabel(Left, 'Settings', TFmrBackstageTextStyle.Subtitle, TAlignLayout.Top, 18);
  AddLabel(Left, 'Print All Pages', TFmrBackstageTextStyle.Normal, TAlignLayout.Top, 8);
  AddLabel(Left, 'Print One Sided', TFmrBackstageTextStyle.Normal, TAlignLayout.Top, 6);
  AddLabel(Left, 'Portrait Orientation, A4 21 cm x 29.7 cm', TFmrBackstageTextStyle.Normal, TAlignLayout.Top,
    6);
  AddLabel(Left, 'Normal Margins', TFmrBackstageTextStyle.Normal, TAlignLayout.Top, 6);

  FPreview := TImage.Create(Self);
  FPreview.Parent := FTabPrint;
  FPreview.Align := TAlignLayout.Client;
  FPreview.WrapMode := TImageWrapMode.Fit;
  FPreview.HitTest := False;
  Bmp := MakePreviewBitmap;
  try
    FPreview.Bitmap.Assign(Bmp);
  finally
    Bmp.Free;
  end;
end;

procedure TExtrasDemoForm.BuildAccountTab;
begin
  AddHeader(FTabAccount, 'Account');
  AddLabel(FTabAccount, 'User Information', TFmrBackstageTextStyle.Title);
  AddLabel(FTabAccount, 'Jane Doe', TFmrBackstageTextStyle.Normal, TAlignLayout.Top, 8);
  AddLabel(FTabAccount, 'jane@example.com', TFmrBackstageTextStyle.Secondary, TAlignLayout.Top, 2);
  AddLabel(FTabAccount, 'Theme', TFmrBackstageTextStyle.Subtitle, TAlignLayout.Top, 24);
  FAccountThemeCombo := TComboBox.Create(Self);
  FAccountThemeCombo.Align := TAlignLayout.Top;
  FAccountThemeCombo.Margins.Rect := RectF(0, 8, 0, 0);
  FAccountThemeCombo.Position.Y := NextY;
  FAccountThemeCombo.Parent := FTabAccount;
  // a Top aligned control takes the whole width; the right margin keeps the combo box narrow
  FAccountThemeCombo.Margins.Right := Max(0, FTabAccount.Width - FTabAccount.Padding.Left - FTabAccount.Padding.Right -
    260);
  FAccountThemeCombo.Height := 28;
  FillThemeCombo(FAccountThemeCombo);
  FAccountThemeCombo.OnChange := ThemeComboChange;
  FTabAccount.OnResize := AccountResize;
  AddLabel(FTabAccount, 'Product Information', TFmrBackstageTextStyle.Title, TAlignLayout.Top, 28);
  AddLabel(FTabAccount, 'FMR Ribbon for FireMonkey. MIT License.', TFmrBackstageTextStyle.Secondary,
    TAlignLayout.Top, 4);
end;

procedure TExtrasDemoForm.AccountResize(Sender: TObject);
begin
  FAccountThemeCombo.Margins.Right := Max(0, FTabAccount.Width - FTabAccount.Padding.Left -
    FTabAccount.Padding.Right - 260);
end;

procedure TExtrasDemoForm.BackstageShow(Sender: TObject);
begin
  // What the ribbon does when its backstage opens: the title bar stays, the tab row goes away
  if (FFrame <> nil) and not FindCmdLineSwitch('keeprow') then
  begin
    FTopBar.Visible := False;
    FFrame.CaptionHeight := FCaptionRow.Height;
  end;
  SetAction('backstage shown');
end;

procedure TExtrasDemoForm.BackstageHide(Sender: TObject);
begin
  if (FFrame <> nil) and not FTopBar.Visible then
  begin
    FTopBar.Visible := True;
    FFrame.CaptionHeight := FCaptionRow.Height + FTopBar.Height;
  end;
  SetAction('backstage hidden');
end;

procedure TExtrasDemoForm.BackstageTabChanged(Sender: TObject);
begin
  if FBackstage.ActiveTab <> nil then
    SetAction('backstage tab ' + FBackstage.ActiveTab.Caption);
end;

procedure TExtrasDemoForm.BackstageButtonClick(Sender: TObject; const AButton: TFmrBackstageButton);
begin
  if AButton.Caption = 'Options' then
    Exit;
  SetAction('backstage button ' + AButton.Caption);
end;

procedure TExtrasDemoForm.SaveClick(Sender: TObject);
begin
  FPagePanel.Text := 'Page 1 of 3 - saved';
  if FBackstage.IsOpen then
    FBackstage.Hide;
end;

procedure TExtrasDemoForm.CloseClick(Sender: TObject);
begin
  FPagePanel.Text := 'Page 1 of 3';
end;

procedure TExtrasDemoForm.OptionsClick(Sender: TObject);
begin
  SetAction('Options clicked (KeepOpen: the view stays open)');
end;

procedure TExtrasDemoForm.TileClick(Sender: TObject);
begin
  SetAction('tile "' + TFmrBackstageTile(Sender).Caption + '" clicked');
end;

procedure TExtrasDemoForm.LocationTileClick(Sender: TObject);
var
  I: Integer;
  P: TFmxObject;
begin
  P := TFmrBackstageTile(Sender).Parent;
  for I := 0 to P.ChildrenCount - 1 do
    if P.Children[I] is TFmrBackstageTile then
      TFmrBackstageTile(P.Children[I]).Selected := P.Children[I] = Sender;
  SetAction('location "' + TFmrBackstageTile(Sender).Caption + '"');
end;

procedure TExtrasDemoForm.RecentItemClick(Sender: TObject; const AItem: TFmrBackstageGalleryItem);
begin
  FBackstage.Hide;
  Caption := AItem.Caption + ' - FMR Ribbon';
  SetAction('opened ' + AItem.Caption);
end;

procedure TExtrasDemoForm.TemplateMouseEnter(Sender: TObject);
begin
  TRectangle(Sender).Fill.Kind := TBrushKind.Solid;
end;

procedure TExtrasDemoForm.TemplateMouseLeave(Sender: TObject);
begin
  TRectangle(Sender).Fill.Kind := TBrushKind.None;
end;

procedure TExtrasDemoForm.TemplateClick(Sender: TObject);
begin
  FBackstage.Hide;
  SetAction('new document from template #' + IntToStr(TRectangle(Sender).Tag));
end;

{ themes }

procedure TExtrasDemoForm.ThemeChangedHandler(const Sender: TObject; const M: TMessage);
begin
  if TFmrThemeChangedMessage(M).Provider = FProvider then
    ApplyDemoColors;
end;

procedure TExtrasDemoForm.ApplyTheme(const AName: string);
begin
  FThemeName := AName;
  if FStandalone then
  begin
    FStatusBar.AccentColor := FAccent;
    FStatusBar.Theme := AName;
    FBackstage.AccentColor := FAccent;
    FBackstage.Theme := AName;
    FTopBar.ThemeLink.AccentColor := FAccent;
    FTopBar.ThemeLink.ThemeName := AName;
    ApplyDemoColors;
  end
  else
    FProvider.SetTheme(AName, FAccent);
  FUpdatingCombos := True;
  try
    FThemeCombo.ItemIndex := FThemeCombo.Items.IndexOf(CurrentTheme.Name);
    FAccountThemeCombo.ItemIndex := FAccountThemeCombo.Items.IndexOf(CurrentTheme.Name);
  finally
    FUpdatingCombos := False;
  end;
end;

procedure TExtrasDemoForm.ApplyDemoColors;
var
  T: TFmrTheme;
  I: Integer;
  Card: TRectangle;
  Txt: TFmxObject;
  Dark: Boolean;
begin
  T := CurrentTheme;
  Dark := T.Style.Dark or (FmrLuminance(T.Colors[TFmrToken.BodyFill]) < 0.3);
  if Dark then
    FDocArea.Fill.Color := FmrDarken(T.Colors[TFmrToken.BodyFill], 0.25)
  else
    FDocArea.Fill.Color := $FFE9E9E9;
  if Dark then
    FActionText.TextSettings.FontColor := $FFE0E0E0
  else
    FActionText.TextSettings.FontColor := $FF404040;
  if FTemplates <> nil then
    for I := 0 to FTemplates.ChildrenCount - 1 do
      if FTemplates.Children[I] is TRectangle then
      begin
        Card := TRectangle(FTemplates.Children[I]);
        Card.Stroke.Color := T.Colors[TFmrToken.GalleryBorder];
        Card.Fill.Color := T.Colors[TFmrToken.ButtonHotFill];
        for Txt in Card.Children do
          if Txt is TText then
            TText(Txt).TextSettings.FontColor := T.Colors[TFmrToken.BackstageHeaderText];
      end;
  if FFrame <> nil then
  begin
    FFrame.DarkMode := T.Style.Dark;
    FFrame.CaptionColor := T.Colors[TFmrToken.CaptionFill];
    FFrame.CaptionInactiveColor := T.Colors[TFmrToken.CaptionFillInactive];
    FCaptionTitle.TextColor := T.Colors[TFmrToken.CaptionText];
    FCaptionTitle.InactiveTextColor := T.Colors[TFmrToken.CaptionTextInactive];
    for I := 0 to High(FCaptionButtons) do
    begin
      FCaptionButtons[I].GlyphColor := T.Colors[TFmrToken.CaptionButtonGlyph];
      if FCaptionButtons[I].Kind <> TFmrCaptionButtonKind.Close then
      begin
        FCaptionButtons[I].HotColor := T.Colors[TFmrToken.CaptionButtonHotFill];
        FCaptionButtons[I].PressedColor := T.Colors[TFmrToken.CaptionButtonPressedFill];
      end;
    end;
  end;
  FTopBar.Repaint;
end;

procedure TExtrasDemoForm.ThemeComboChange(Sender: TObject);
var
  Combo: TComboBox;
begin
  if FUpdatingCombos then
    Exit;
  Combo := TComboBox(Sender);
  if Combo.ItemIndex >= 0 then
  begin
    ApplyTheme(Combo.Items[Combo.ItemIndex]);
    SetAction('theme ' + Combo.Items[Combo.ItemIndex]);
  end;
end;

procedure TExtrasDemoForm.ApplyCommandLine;
var
  I, TabIndex: Integer;
  S, Theme: string;
  OpenView, ByKeyboard, NoAnim: Boolean;
begin
  Theme := FmrDefaultThemeName;
  TabIndex := -1;
  OpenView := False;
  ByKeyboard := False;
  NoAnim := False;
  for I := 1 to ParamCount do
  begin
    S := ParamStr(I);
    if S.StartsWith('/theme=', True) then
      Theme := S.Substring(7)
    else if S.StartsWith('/accent=', True) then
      FAccent := TAlphaColor($FF000000 or Cardinal(StrToIntDef('$' + S.Substring(8), 0)))
    else if S.StartsWith('/tab=', True) then
      TabIndex := StrToIntDef(S.Substring(5), -1)
    else if SameText(S, '/backstage') then
      OpenView := True
    else if SameText(S, '/keytips') then
    begin
      OpenView := True;
      ByKeyboard := True;
    end
    else if SameText(S, '/standalone') then
      FStandalone := True
    else if SameText(S, '/noanim') then
      NoAnim := True
    else if SameText(S, '/frame=fullnc') or SameText(S, '/frame') then
      BuildFrame(TFmrFrameMode.FullNC)
    else if SameText(S, '/frame=dwm') then
      BuildFrame(TFmrFrameMode.Dwm)
    else if SameText(S, '/frame=ncstrip') then
      BuildFrame(TFmrFrameMode.NCStrip)
    else if S.StartsWith('/pos=', True) and S.Contains(',') then
    begin
      // window position in dp (screenshots of a window placed mostly outside the visible desktop)
      Position := TFormPosition.Designed;
      Left := StrToIntDef(S.Substring(5).Split([','])[0], Left);
      Top := StrToIntDef(S.Substring(5).Split([','])[1], Top);
    end
    else if SameText(S, '/topmost') then
      FormStyle := TFormStyle.StayOnTop;
  end;
  if FStandalone then
  begin
    FStatusBar.ThemeProvider := nil;
    FBackstage.ThemeProvider := nil;
    FTopBar.ThemeLink.Provider := nil;
  end;
  ApplyTheme(Theme);
  if NoAnim then
    FBackstage.Animation := TFmrBackstageAnimation.None;
  if (TabIndex >= 0) and (TabIndex < FBackstage.TabCount) then
    FBackstage.ActiveTab := FBackstage.Tabs[TabIndex];
  if OpenView then
    TThread.ForceQueue(nil,
      procedure
      begin
        FBackstage.Show(ByKeyboard);
      end);
end;

end.
