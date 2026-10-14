{*******************************************************}
{                                                       }
{  FMR Ribbon for FireMonkey                            }
{  Showcase: one page per feature                       }
{                                                       }
{  MIT License. Copyright (c) 2026 Fasday               }
{                                                       }
{*******************************************************}

unit ShowcaseMain;

/// Feature gallery of FMR Ribbon, built in code. The main ribbon (Word template + a "Showcase" tab) lives in the
/// window frame; the left navigation list (a themed TFmrBackstageGalleryList) selects a page; every page explains
/// one feature and has live controls (themed TFmrBackstageTile buttons) that change the main ribbon, or a ribbon
/// of its own (adaptive layout, merging). All companion controls follow the theme of the main ribbon.
///
/// Command line: /page=N /theme=<name> /accent=RRGGBB /frame=fullnc|dwm|ncstrip /lang=ru /width=N /height=N
///   /auto  runs the demo action of the page about a second after start (for screenshots)

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Generics.Collections, System.Messaging,
  System.Math, System.Diagnostics, FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.Objects, FMX.Layouts,
  FMX.StdCtrls, FMX.Memo, FMX.Memo.Types, FMX.ScrollBox, FMX.Controls.Presentation, FMR.Ribbon.Types,
  FMR.Bars.Images, FMR.Bars, FMR.Bars.Items, FMR.Ribbon.Structure, FMR.Ribbon.Theme, FMR.Ribbon.Painter, FMR.Ribbon,
  FMR.Ribbon.Views, FMR.Ribbon.Popup, FMR.Ribbon.Gallery, FMR.Ribbon.ColorGallery, FMR.Ribbon.AppMenu,
  FMR.Ribbon.MiniToolbar, FMR.Ribbon.RadialMenu, FMR.Ribbon.Backstage, FMR.Ribbon.Backstage.Controls,
  FMR.Ribbon.StatusBar, FMR.Ribbon.Templates, FMR.Ribbon.Strings, FMR.Frame.Types, FMR.Frame;

type
  /// <summary>Background of the pages and theme provider of the helper controls placed on it: it forwards the
  /// theme of the main ribbon and announces its changes as its own (TFmrThemeLink listens to the provider in use).
  /// </summary>
  TShowcasePanel = class(TControl, IFmrThemeProvider)
  private
    FRibbon: TFmrRibbon;
    FToken: TFmrToken;
    FMessageId: TMessageSubscriptionId;
    procedure ThemeChanged(const Sender: TObject; const M: TMessage);
    function GetFmrTheme: TFmrTheme;
  protected
    procedure Paint; override;
  public
    constructor CreatePanel(const AOwner: TComponent; const ARibbon: TFmrRibbon; const AToken: TFmrToken);
    destructor Destroy; override;
  end;

  TPageBuilder = procedure of object;

  TShowcaseForm = class(TForm)
  private
    FFrame: TFmrFormFrame;
    FManager: TFmrBarManager;
    FRibbon: TFmrRibbon;
    FStatusBar: TFmrStatusBar;
    FPagePanel: TFmrStatusBarPanel;
    FMessagePanel: TFmrStatusBarPanel;
    FBackground: TShowcasePanel;
    FNavPanel: TShowcasePanel;
    FNav: TFmrBackstageGalleryList;
    FBox: TVertScrollBox;
    FPageIndex: Integer;
    FOrder: Integer;
    FActions: TDictionary<TObject, TProc>;
    FAutoActions: TDictionary<Integer, TProc>;
    FThemes: TObjectDictionary<string, TFmrTheme>;
    FThemeNames: TArray<string>;
    FAccent: TAlphaColor;
    FAuto: Boolean;
    { companions }
    FBackstage: TFmrRibbonBackstageView;
    FAppMenu07: TFmrRibbonApplicationMenu;
    FFileMenu: TFmrPopupMenu;
    FContextMenu: TFmrPopupMenu;
    FMini: TFmrRibbonMiniToolbar;
    FRadial: TFmrRibbonRadialMenu;
    FThemeGallery: TFmrRibbonGalleryItem;
    FShapesButton: TFmrButtonItem;
    { page state }
    FInfo: TFmrBackstageLabel;
    FTiles: TList<TFmrBackstageTile>;
    FEmbedded: TFmrRibbon;
    FEmbeddedManager: TFmrBarManager;
    FEmbeddedFrame: TFmrFormFrame;
    FEmbeddedHost: TLayout;
    FWidthTrack: TTrackBar;
    FChild: TFmrRibbon;
    FChildManager: TFmrBarManager;
    FChildFrame: TFmrFormFrame;
    FLayoutMemo: TMemo;
    FDemoStatus: TFmrStatusBar;
    FPerfTab: TFmrRibbonTab;
    FPerfItems: TList<TFmrBarItem>;
    FPerfMemo: TMemo;
    { ribbon }
    procedure BuildRibbon;
    procedure BuildShowcaseTab;
    procedure BuildCompanions;
    procedure BuildStatusBar;
    procedure BuildNavigation;
    procedure ApplyCommandLine;
    procedure CommandClick(Sender: TObject);
    procedure NavItemClick(Sender: TObject; const AItem: TFmrBackstageGalleryItem);
    procedure ThemeDrawItem(Sender: TObject; const ACanvas: TCanvas; const AEntry: TFmrGalleryEntry;
      const ARect: TRectF; const AState: TFmrGalleryDrawStates; const APainter: TFmrRibbonPainter;
      var AHandled: Boolean);
    procedure ThemeItemClick(Sender: TObject; const AEntry: TFmrGalleryEntry);
    procedure PageButtonClick(Sender: TObject);
    procedure TileClick(Sender: TObject);
    procedure TrackChange(Sender: TObject);
    procedure SetMessage(const AText: string);
    function ThemeFor(const AName: string): TFmrTheme;
    procedure ApplyTheme(const AName: string; const AAccent: TAlphaColor);
    procedure OpenDropDown(const AItem: TFmrBarItem);
    function ItemScreenRect(const AItem: TFmrBarItem; out ARect: TRectF): TFmrItemView;
    function Item(const AName: string): TFmrBarItem;
    function NewEmbeddedRibbon(const AParent: TFmxObject; out AManager: TFmrBarManager;
      out AFrame: TFmrFormFrame): TFmrRibbon;
    { pages }
    procedure ShowPage(const AIndex: Integer);
    function PageAction(const AIndex: Integer): TProc;
    procedure ClearPage;
    procedure RunAuto;
    function NextPos: Single;
    function AddTitle(const AText: string): TFmrBackstageHeader;
    function AddText(const AText: string;
      const AStyle: TFmrBackstageTextStyle = TFmrBackstageTextStyle.Normal): TFmrBackstageLabel;
    function AddSection(const AText: string): TFmrBackstageLabel;
    function AddFlow(const AItemWidth, AItemHeight: Single): TFlowLayout;
    function AddButton(const AParent: TFmxObject; const ACaption: string; const AGlyph: Cardinal;
      const AAction: TProc; const AWidth: Single = 230; const AHeight: Single = 46): TFmrBackstageTile;
    function AddInfo: TFmrBackstageLabel;
    procedure FlowResize(Sender: TObject);
    procedure SelectTile(const ATile: TFmrBackstageTile; const AGroup: Integer);
    procedure PageOverview;
    procedure PageThemes;
    procedure PageFrame;
    procedure PageAdaptive;
    procedure PageGalleries;
    procedure PageMenus;
    procedure PageKeyTips;
    procedure PageScreenTips;
    procedure PageContext;
    procedure PageQAT;
    procedure PageModes;
    procedure PageRTL;
    procedure PageMiniToolbar;
    procedure PageRadial;
    procedure PageAppMenu;
    procedure PageStatusBar;
    procedure PageMerge;
    procedure PagePersistence;
    procedure PageCustomize;
    procedure PageLocalization;
    procedure PageCanvas;
    procedure PagePerformance;
    procedure UpdateFrameInfo;
    procedure ShowRibbonCustomization;
    procedure ShowQATCustomization;
    procedure ShowItemTip(const AItem: TFmrBarItem);
    procedure ChooseAppMenu(const AMenu: TFmxObject; const AIndex: Integer);
    procedure UpdateMergeInfo;
    procedure RunPerformance;
    procedure RemovePerformanceTab;
  protected
    procedure DoClose(var CloseAction: TCloseAction); override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
  end;

var
  ShowcaseForm: TShowcaseForm;

implementation

uses
  System.StrUtils;

type
  TPageInfo = record
    Group: string;
    Title: string;
    Glyph: Cardinal;
    Description: string;
  end;

const
  Pages: array [0..21] of TPageInfo = (
    (Group: 'Start'; Title: 'Overview'; Glyph: $E80F; Description: 'What FMR Ribbon is made of'),
    (Group: 'Appearance'; Title: 'Themes and accents'; Glyph: $E790; Description: '18 themes x accent colors'),
    (Group: 'Appearance'; Title: 'Window frame'; Glyph: $E737; Description: 'FullNC, Dwm, NCStrip, Mica'),
    (Group: 'Layout'; Title: 'Adaptive layout'; Glyph: $E740; Description: 'Reduction steps, templates'),
    (Group: 'Commands'; Title: 'Galleries'; Glyph: $E8B9; Description: 'In-ribbon and drop-down'),
    (Group: 'Commands'; Title: 'Menus and popups'; Glyph: $E700; Description: 'Split buttons, context menus'),
    (Group: 'Commands'; Title: 'Key tips'; Glyph: $E765; Description: 'Alt, letters, numbers'),
    (Group: 'Commands'; Title: 'Screen tips'; Glyph: $E946; Description: 'Rich tooltips'),
    (Group: 'Ribbon'; Title: 'Contextual tabs'; Glyph: $E8EF; Description: 'Colored tab groups'),
    (Group: 'Ribbon'; Title: 'Quick Access Toolbar'; Glyph: $E74E; Description: 'Above or below'),
    (Group: 'Ribbon'; Title: 'Display modes'; Glyph: $E8A0; Description: 'Minimized, auto-hide, simplified, touch'),
    (Group: 'Ribbon'; Title: 'Right to left'; Glyph: $E8AB; Description: 'Mirrored groups'),
    (Group: 'Popups'; Title: 'Mini toolbar'; Glyph: $E8D2; Description: 'Floating formatting toolbar'),
    (Group: 'Popups'; Title: 'Radial menu'; Glyph: $E7F4; Description: 'OneNote style'),
    (Group: 'Popups'; Title: 'Application menu or backstage'; Glyph: $E8A5; Description: 'File tab, Office 2007 orb'),
    (Group: 'Companions'; Title: 'Status bar'; Glyph: $E81E; Description: 'Panels, zoom slider, views'),
    (Group: 'Data'; Title: 'Merging'; Glyph: $E8A7; Description: 'A child ribbon merged in'),
    (Group: 'Data'; Title: 'Persistence'; Glyph: $E78C; Description: 'Layout as JSON'),
    (Group: 'Data'; Title: 'Customization'; Glyph: $E713; Description: 'Customize the Ribbon form'),
    (Group: 'Data'; Title: 'Localization'; Glyph: $E774; Description: 'English and Russian'),
    (Group: 'Engine'; Title: 'Canvas'; Glyph: $E7F4; Description: 'Direct2D or FastCanvas'),
    (Group: 'Engine'; Title: 'Performance'; Glyph: $E916; Description: 'A tab with 500 commands'));

  PathCircle = 'M12,3 A9,9 0 1 1 11.99,3 Z';
  PathShapeRect = 'M3,5 L21,5 L21,19 L3,19 Z M5,7 L5,17 L19,17 L19,7 Z';
  PathShapeOval = 'M12,4 A8,8 0 1 1 11.99,4 Z M12,6 A6,6 0 1 0 12.01,6 Z';
  PathShapeTriangle = 'M12,3 L22,20 L2,20 Z M12,7 L5.5,18 L18.5,18 Z';
  PathShapeStar = 'M12,2 L14.9,8.6 L22,9.3 L16.6,14 L18.2,21 L12,17.3 L5.8,21 L7.4,14 L2,9.3 L9.1,8.6 Z';
  PathShapeArrow = 'M2,8 L13,8 L13,3 L22,12 L13,21 L13,16 L2,16 Z';
  PathShapeHeart = 'M12,21 L4,13 Q1,9.5 4,6 Q8,3 12,7.5 Q16,3 20,6 Q23,9.5 20,13 Z';
  PathShapes = 'M3,12 L11,12 L11,20 L3,20 Z M17,3 L22,12 L12,12 Z M14,15 L21,15 L21,21 L14,21 Z';
  PathPalette = 'M12,3 A9,9 0 1 0 12,21 Q14,21 14,19 Q14,18 13,17 Q12,16 13,15 L16,15 A5,5 0 0 0 21,10 ' +
    'Q21,3 12,3 Z M7,9 A1.5,1.5 0 1 1 7,12 A1.5,1.5 0 1 1 7,9 Z M10,5.5 A1.5,1.5 0 1 1 10,8.5 A1.5,1.5 0 1 1 ' +
    '10,5.5 Z M15,6 A1.5,1.5 0 1 1 15,9 A1.5,1.5 0 1 1 15,6 Z';

  Accents: array [0..7] of TAlphaColor = (0, $FF2B579A, $FF217346, $FFB7472A, $FF0072C6, $FF80397B, $FFA4373A,
    $FF0067C0);
  AccentNames: array [0..7] of string = ('Theme default', 'Word', 'Excel', 'PowerPoint', 'Outlook', 'OneNote',
    'Access', 'Fluent');

{ TShowcasePanel }

constructor TShowcasePanel.CreatePanel(const AOwner: TComponent; const ARibbon: TFmrRibbon;
  const AToken: TFmrToken);
begin
  inherited Create(AOwner);
  FRibbon := ARibbon;
  FToken := AToken;
  HitTest := False;
  FMessageId := TMessageManager.DefaultManager.SubscribeToMessage(TFmrThemeChangedMessage, ThemeChanged);
end;

destructor TShowcasePanel.Destroy;
begin
  TMessageManager.DefaultManager.Unsubscribe(TFmrThemeChangedMessage, FMessageId);
  inherited;
end;

function TShowcasePanel.GetFmrTheme: TFmrTheme;
begin
  if (FRibbon <> nil) and not (csDestroying in FRibbon.ComponentState) then
    Result := FRibbon.ThemeObject
  else
    Result := nil;
end;

procedure TShowcasePanel.ThemeChanged(const Sender: TObject; const M: TMessage);
begin
  if (TFmrThemeChangedMessage(M).Provider = FRibbon) and not (csDestroying in ComponentState) then
  begin
    TMessageManager.DefaultManager.SendMessage(Self, TFmrThemeChangedMessage.Create(Self));
    Repaint;
  end;
end;

procedure TShowcasePanel.Paint;
var
  T: TFmrTheme;
begin
  T := GetFmrTheme;
  if T = nil then
    Exit;
  T.Fills[FToken].ApplyTo(Canvas.Fill);
  Canvas.FillRect(LocalRect, 0, 0, [], AbsoluteOpacity);
  if FToken <> TFmrToken.BackstageFill then
  begin
    Canvas.Stroke.Kind := TBrushKind.Solid;
    Canvas.Stroke.Color := T.Colors[TFmrToken.MenuSeparator];
    Canvas.Stroke.Thickness := 1;
    Canvas.DrawLine(PointF(Width - 0.5, 0), PointF(Width - 0.5, Height), AbsoluteOpacity);
  end;
end;

{ TShowcaseForm }

constructor TShowcaseForm.Create(AOwner: TComponent);
var
  Mode: string;
  I: Integer;
begin
  inherited CreateNew(AOwner);
  Caption := 'FMR Ribbon Showcase';
  Width := 1360;
  Height := 860;
  Position := TFormPosition.ScreenCenter;
  FActions := TDictionary<TObject, TProc>.Create;
  FAutoActions := TDictionary<Integer, TProc>.Create;
  FThemes := TObjectDictionary<string, TFmrTheme>.Create([doOwnsValues]);
  FTiles := TList<TFmrBackstageTile>.Create;
  FPerfItems := TList<TFmrBarItem>.Create;
  FPageIndex := -1;
  Mode := '';
  for I := 1 to ParamCount do
    if ParamStr(I).ToLower.StartsWith('/frame=') then
      Mode := ParamStr(I).Substring(7).ToLower
    else if SameText(ParamStr(I), '/lang=ru') then
      FmrSetLanguage('ru');
  // the frame first: the ribbon moves its caption row and tab row into the frame's host
  FFrame := TFmrFormFrame.Create(Self);
  if Mode = 'dwm' then
    FFrame.Mode := TFmrFrameMode.Dwm
  else if Mode = 'ncstrip' then
    FFrame.Mode := TFmrFrameMode.NCStrip;

  FManager := TFmrBarManager.Create(Self);
  FManager.Parent := Self;
  BuildStatusBar;
  BuildRibbon;
  FStatusBar.ThemeProvider := FRibbon;
  BuildCompanions;
  BuildNavigation;
  ApplyCommandLine;
end;

destructor TShowcaseForm.Destroy;
begin
  ClearPage;
  FPerfItems.Free;
  FTiles.Free;
  FThemes.Free;
  FAutoActions.Free;
  FActions.Free;
  inherited;
end;

procedure TShowcaseForm.DoClose(var CloseAction: TCloseAction);
begin
  // the page ribbons (adaptive layout, merging) and their stand-alone frames go first
  ClearPage;
  inherited;
end;

function TShowcaseForm.Item(const AName: string): TFmrBarItem;
begin
  Result := FManager.FindItem(AName);
end;

procedure TShowcaseForm.SetMessage(const AText: string);
begin
  FMessagePanel.Text := AText;
end;

procedure TShowcaseForm.CommandClick(Sender: TObject);
begin
  SetMessage('Command: ' + FmrStripAccel(TFmrBarItem(Sender).Caption));
end;

procedure TShowcaseForm.BuildRibbon;
var
  I: Integer;
begin
  FRibbon := TFmrRibbon.Create(Self);
  FRibbon.Parent := Self;
  FRibbon.BarManager := FManager;
  FRibbon.Frame := FFrame;
  FRibbon.ShowSearchBox := True;
  FRibbon.ShowDisplayOptionsButton := True;
  FRibbon.ShowDisplayModeButton := True;
  FRibbon.BeginStructureUpdate;
  try
    // a complete Word-like structure from the run-time template builder, then a tab of our own
    FmrApplyRibbonTemplate(FRibbon, TFmrRibbonTemplate.Word, FManager);
    BuildShowcaseTab;
  finally
    FRibbon.EndStructureUpdate;
  end;
  for I := 0 to FManager.ItemCount - 1 do
    if not Assigned(FManager.Items[I].OnClick) then
      FManager.Items[I].OnClick := CommandClick;
  FRibbon.ActiveTab := FRibbon.Tabs(0);
end;

procedure TShowcaseForm.BuildShowcaseTab;
const
  ShapeNames: array [0..6] of string = ('Rectangle', 'Oval', 'Triangle', 'Star', 'Arrow', 'Heart', 'Circle');
  ShapePaths: array [0..6] of string = (PathShapeRect, PathShapeOval, PathShapeTriangle, PathShapeStar,
    PathShapeArrow, PathShapeHeart, PathCircle);
var
  Tab: TFmrRibbonTab;
  G: TFmrRibbonGroup;
  B: TFmrButtonItem;
  Shapes: TFmrGalleryItem;
  GG: TFmrGalleryGroup;
  E: TFmrGalleryEntry;
  I: Integer;

  function Btn(const AName, ACaption: string; const AGlyph: Cardinal; const ALevels: TFmrViewLevels): TFmrButtonItem;
  begin
    Result := TFmrButtonItem(FManager.CreateItem(TFmrButtonItem, AName));
    Result.Caption := ACaption;
    Result.Glyph.GlyphCode := AGlyph;
    Result.LargeGlyph.GlyphCode := AGlyph;
    Result.Category := 'Showcase';
    G.ItemLinks.AddItem(Result).ViewLevels := ALevels;
  end;

begin
  Tab := FRibbon.AddTab('Showcase', 'tabShowcase');
  Tab.KeyTip := 'S';
  G := Tab.AddGroup('Pages');
  G.Name := 'grpSCPages';
  B := Btn('btnSCPrev', 'Previous Page', $E76B, [TFmrViewLevel.Large]);
  B.Tag := -1;
  B.OnClick := PageButtonClick;
  B := Btn('btnSCNext', 'Next Page', $E76C, [TFmrViewLevel.Large]);
  B.Tag := 1;
  B.OnClick := PageButtonClick;

  G := Tab.AddGroup('Themes');
  G.Name := 'grpSCThemes';
  G.ReductionPriority := -1;
  FThemeGallery := TFmrRibbonGalleryItem(FManager.CreateItem(TFmrRibbonGalleryItem, 'galSCThemes'));
  FThemeGallery.Caption := 'Themes';
  FThemeGallery.Glyph.PathData := PathPalette;
  FThemeGallery.Glyph.PathViewBox := 24;
  FThemeGallery.LargeGlyph.Assign(FThemeGallery.Glyph);
  FThemeGallery.ItemWidth := 76;
  FThemeGallery.ItemHeight := 58;
  FThemeGallery.MinColumns := 2;
  FThemeGallery.MaxColumns := 6;
  FThemeGallery.DropDownColumns := 6;
  FThemeGallery.ShowGroupHeaders := False;
  FThemeGallery.ScreenTip.Description := 'Every registered theme with a preview; a click switches it live.';
  FThemeNames := TFmrTheme.ThemeNames;
  GG := FThemeGallery.Groups.Add('Themes');
  for I := 0 to High(FThemeNames) do
  begin
    E := GG.Items.Add(TFmrTheme.ThemeDisplayName(FThemeNames[I]));
    E.Hint := FThemeNames[I];
    E.Tag := I;
  end;
  FThemeGallery.OnDrawItem := ThemeDrawItem;
  FThemeGallery.OnItemClick := ThemeItemClick;
  G.ItemLinks.AddItem(FThemeGallery);

  G := Tab.AddGroup('Popups');
  G.Name := 'grpSCPopups';
  B := Btn('btnSCMini', 'Mini Toolbar', $E8D2, [TFmrViewLevel.Large, TFmrViewLevel.SmallWithText]);
  B.OnClick := TileClick;
  FActions.AddOrSetValue(B,
    procedure
    begin
      FMini.Popup(Screen.MousePos, True);
    end);
  B := Btn('btnSCRadial', 'Radial Menu', $E7F4, [TFmrViewLevel.Large, TFmrViewLevel.SmallWithText]);
  B.OnClick := TileClick;
  FActions.AddOrSetValue(B,
    procedure
    begin
      FRadial.Popup(Screen.MousePos);
    end);
  FShapesButton := Btn('btnSCShapes', 'Shapes', 0, [TFmrViewLevel.Large, TFmrViewLevel.SmallWithText]);
  FShapesButton.ButtonStyle := TFmrButtonStyle.DropDown;
  FShapesButton.Glyph.PathData := PathShapes;
  FShapesButton.Glyph.PathViewBox := 24;
  FShapesButton.LargeGlyph.Assign(FShapesButton.Glyph);
  Shapes := TFmrGalleryItem(FManager.CreateItem(TFmrGalleryItem, 'galSCShapes'));
  Shapes.Caption := 'Shapes';
  Shapes.ShowInRibbon := False;
  Shapes.ItemWidth := 30;
  Shapes.ItemHeight := 30;
  Shapes.DropDownColumns := 7;
  Shapes.SelectionMode := TFmrGallerySelectionMode.None;
  GG := Shapes.Groups.Add('Basic Shapes');
  for I := 0 to High(ShapeNames) do
  begin
    E := GG.Items.Add(ShapeNames[I]);
    E.Glyph.PathData := ShapePaths[I];
    E.Glyph.PathViewBox := 24;
  end;
  FShapesButton.DropDownLinks.AddItem(Shapes);
  B := TFmrButtonItem(FManager.CreateItem(TFmrButtonItem, 'btnSCCanvas'));
  B.Caption := 'New Drawing Canvas';
  B.Glyph.GlyphCode := $E70F;
  FShapesButton.DropDownLinks.AddItem(B, True);
end;

procedure TShowcaseForm.BuildCompanions;
var
  Tab: TFmrBackstageTab;
  H: TFmrBackstageHeader;
  L: TFmrBackstageLabel;
  B: TFmrButtonItem;
  Sub: TFmrSubItem;
  S: string;

  function Get(const AName: string): TFmrBarItem;
  begin
    Result := Item(AName);
  end;

  procedure AddLink(const ALinks: TFmrItemLinks; const AName: string; const ABeginGroup: Boolean = False);
  begin
    if Get(AName) <> nil then
      ALinks.AddItem(Get(AName), ABeginGroup);
  end;

begin
  // backstage view (the default application menu)
  FBackstage := TFmrRibbonBackstageView.Create(Self);
  FBackstage.Parent := Self;
  FBackstage.BarManager := FManager;
  Tab := FBackstage.AddTab('Info');
  Tab.Glyph.GlyphCode := $E946;
  H := TFmrBackstageHeader.Create(Self);
  H.Text := 'Info';
  H.Parent := Tab;
  L := TFmrBackstageLabel.Create(Self);
  L.Text := 'The backstage view of FMR.Ribbon.Backstage, opened by the File tab. Esc or the back arrow closes it.';
  L.Align := TAlignLayout.Top;
  L.Position.Y := 1000;
  L.Parent := Tab;
  FBackstage.AddTab('New').Glyph.GlyphCode := $E7C3;
  FBackstage.AddTab('Open').Glyph.GlyphCode := $E838;
  FBackstage.AddButton('Save').Glyph.GlyphCode := $E74E;
  FBackstage.AddButton('Close').Glyph.GlyphCode := $E711;
  FBackstage.ActiveTab := Tab;
  FBackstage.ThemeProvider := FRibbon;
  FRibbon.ApplicationMenu := FBackstage;

  // Office 2007 application menu
  FAppMenu07 := TFmrRibbonApplicationMenu.Create(Self);
  FAppMenu07.Parent := Self;
  FAppMenu07.BarManager := FManager;
  for S in ['New', 'Open', 'Save As', 'Print', 'Close'] do
  begin
    B := TFmrButtonItem(FManager.CreateItem(TFmrButtonItem, ''));
    B.Caption := S;
    B.OnClick := CommandClick;
    case IndexText(S, ['New', 'Open', 'Save As', 'Print', 'Close']) of
      0: B.Glyph.GlyphCode := $E8A5;
      1: B.Glyph.GlyphCode := $E8E5;
      2: B.Glyph.GlyphCode := $E792;
      3: B.Glyph.GlyphCode := $E749;
    else
      B.Glyph.GlyphCode := $E8BB;
    end;
    B.LargeGlyph.Assign(B.Glyph);
    FAppMenu07.ItemLinks.AddItem(B, S = 'Close');
  end;
  FAppMenu07.RecentDocuments.Add('Showcase notes.docx', 'C:\Documents\Showcase notes.docx', True);
  FAppMenu07.RecentDocuments.Add('Ribbon design.docx', 'C:\Documents\Ribbon design.docx');
  FAppMenu07.RecentDocuments.Add('Release plan.docx', 'C:\Documents\Release plan.docx');

  // a plain popup menu as the File menu
  FFileMenu := TFmrPopupMenu.Create(Self);
  FFileMenu.Parent := Self;
  FFileMenu.BarManager := FManager;
  FFileMenu.ThemeSource := FRibbon;
  for S in ['New', 'Open', 'Save As', 'Print', 'Close'] do
    FFileMenu.ItemLinks.AddItem(FAppMenu07.ItemLinks[IndexText(S, ['New', 'Open', 'Save As', 'Print', 'Close'])].Item,
      S = 'Close');

  // context menu + mini toolbar
  FContextMenu := TFmrPopupMenu.Create(Self);
  FContextMenu.Parent := Self;
  FContextMenu.BarManager := FManager;
  FContextMenu.ThemeSource := FRibbon;
  AddLink(FContextMenu.ItemLinks, 'btnCut');
  AddLink(FContextMenu.ItemLinks, 'btnCopy');
  AddLink(FContextMenu.ItemLinks, 'btnPaste');
  AddLink(FContextMenu.ItemLinks, 'btnChangeCase', True);
  AddLink(FContextMenu.ItemLinks, 'btnFind', True);
  FMini := TFmrRibbonMiniToolbar.Create(Self);
  FMini.Parent := Self;
  FMini.BarManager := FManager;
  FMini.ThemeSource := FRibbon;
  FMini.PopupMenu := FContextMenu;
  AddLink(FMini.ItemLinks, 'cmbFontName');
  AddLink(FMini.ItemLinks, 'cmbFontSize');
  AddLink(FMini.ItemLinks, 'btnGrowFont');
  AddLink(FMini.ItemLinks, 'btnShrinkFont');
  FMini.ItemLinks.AddItem(FManager.CreateItem(TFmrSeparatorItem, 'sepSCMini'));
  AddLink(FMini.ItemLinks, 'btnBold');
  AddLink(FMini.ItemLinks, 'btnItalic');
  AddLink(FMini.ItemLinks, 'btnUnderline');
  AddLink(FMini.ItemLinks, 'clrFontColor');
  AddLink(FMini.ItemLinks, 'btnBullets', True);
  AddLink(FMini.ItemLinks, 'btnNumbering');

  // radial menu with a nested ring
  FRadial := TFmrRibbonRadialMenu.Create(Self);
  FRadial.Parent := Self;
  FRadial.BarManager := FManager;
  FRadial.ThemeSource := FRibbon;
  AddLink(FRadial.ItemLinks, 'btnUndo');
  AddLink(FRadial.ItemLinks, 'btnBold');
  AddLink(FRadial.ItemLinks, 'btnItalic');
  AddLink(FRadial.ItemLinks, 'btnUnderline');
  AddLink(FRadial.ItemLinks, 'clrFontColor');
  AddLink(FRadial.ItemLinks, 'btnBullets');
  Sub := TFmrSubItem(FManager.CreateItem(TFmrSubItem, 'subSCAlign'));
  Sub.Caption := 'Align';
  Sub.Glyph.GlyphCode := FmrGlyphAlignCenter;
  AddLink(Sub.ItemLinks, 'btnAlignLeft');
  AddLink(Sub.ItemLinks, 'btnAlignCenter');
  AddLink(Sub.ItemLinks, 'btnAlignRight');
  AddLink(Sub.ItemLinks, 'btnJustify');
  FRadial.ItemLinks.AddItem(Sub);
  AddLink(FRadial.ItemLinks, 'btnRedo');
end;

procedure TShowcaseForm.BuildStatusBar;
var
  P: TFmrStatusBarPanel;
begin
  FStatusBar := TFmrStatusBar.Create(Self);
  FStatusBar.Parent := Self;
  FStatusBar.BarManager := FManager;
  FPagePanel := FStatusBar.AddPanel(TFmrStatusPanelKind.Text, 'Overview');
  FPagePanel.Glyph.GlyphCode := $E8A5;
  FMessagePanel := FStatusBar.AddPanel(TFmrStatusPanelKind.Text, 'Ready');
  FMessagePanel.Stretch := True;
  P := FStatusBar.AddPanel(TFmrStatusPanelKind.ViewButtons, '', TFmrStatusPanelSide.Right);
  P.Hint := 'View buttons';
  FStatusBar.AddPanel(TFmrStatusPanelKind.ZoomSlider, '', TFmrStatusPanelSide.Right);
end;

procedure TShowcaseForm.BuildNavigation;
var
  I: Integer;
  Group: string;
begin
  FBackground := TShowcasePanel.CreatePanel(Self, FRibbon, TFmrToken.BackstageFill);
  FBackground.Align := TAlignLayout.Client;
  FBackground.Parent := Self;
  FNavPanel := TShowcasePanel.CreatePanel(Self, FRibbon, TFmrToken.MenuHeaderFill);
  FNavPanel.Align := TAlignLayout.Left;
  FNavPanel.Width := 268;
  FNavPanel.Padding.Rect := RectF(8, 10, 8, 10);
  FNavPanel.Parent := FBackground;
  FNav := TFmrBackstageGalleryList.Create(Self);
  FNav.Align := TAlignLayout.Client;
  FNav.ItemHeight := 48;
  FNav.Parent := FNavPanel;
  FNav.Items.BeginUpdate;
  try
    Group := '';
    for I := 0 to High(Pages) do
    begin
      if Pages[I].Group <> Group then
      begin
        Group := Pages[I].Group;
        FNav.Items.AddHeader(Group);
      end;
      FNav.Items.AddItem(Pages[I].Title, Pages[I].Description, Pages[I].Glyph).Tag := I;
    end;
  finally
    FNav.Items.EndUpdate;
  end;
  FNav.OnItemClick := NavItemClick;
end;

procedure TShowcaseForm.ApplyCommandLine;
var
  I, Page: Integer;
  S, V: string;
begin
  Page := 0;
  for I := 1 to ParamCount do
  begin
    S := ParamStr(I);
    V := '';
    if S.Contains('=') then
    begin
      V := S.Substring(S.IndexOf('=') + 1);
      S := S.Substring(0, S.IndexOf('='));
    end;
    S := S.ToLower;
    if S = '/theme' then
      ApplyTheme(V, FAccent)
    else if S = '/accent' then
      ApplyTheme(FRibbon.Theme, TAlphaColor($FF000000 or Cardinal(StrToIntDef('$' + V, 0))))
    else if S = '/page' then
      Page := EnsureRange(StrToIntDef(V, 0), 0, High(Pages))
    else if S = '/auto' then
      FAuto := True
    else if S = '/width' then
      Width := StrToIntDef(V, Width)
    else if S = '/height' then
      Height := StrToIntDef(V, Height);
  end;
  ShowPage(Page);
  if FAuto then
    TThread.ForceQueue(nil, RunAuto, 1000);
end;

procedure TShowcaseForm.RunAuto;
var
  P: TProc;
begin
  if FAutoActions.TryGetValue(FPageIndex, P) then
    P();
end;

procedure TShowcaseForm.NavItemClick(Sender: TObject; const AItem: TFmrBackstageGalleryItem);
begin
  if AItem.Tag <> FPageIndex then
    TThread.ForceQueue(nil,
      procedure
      begin
        ShowPage(AItem.Tag);
      end);
end;

procedure TShowcaseForm.PageButtonClick(Sender: TObject);
begin
  ShowPage(EnsureRange(FPageIndex + TComponent(Sender).Tag, 0, High(Pages)));
end;

procedure TShowcaseForm.TileClick(Sender: TObject);
var
  P: TProc;
begin
  if FActions.TryGetValue(Sender, P) then
    P();
end;

function TShowcaseForm.ThemeFor(const AName: string): TFmrTheme;
begin
  if not FThemes.TryGetValue(AName, Result) then
  begin
    Result := TFmrTheme.CreateTheme(AName);
    FThemes.Add(AName, Result);
  end;
end;

procedure TShowcaseForm.ApplyTheme(const AName: string; const AAccent: TAlphaColor);
var
  I: Integer;
begin
  if not TFmrTheme.ThemeExists(AName) then
    Exit;
  FAccent := AAccent;
  FRibbon.BeginStructureUpdate;
  try
    FRibbon.AccentColor := AAccent;
    FRibbon.Theme := AName;
  finally
    FRibbon.EndStructureUpdate;
  end;
  for I := 0 to FThemeGallery.EntryCount - 1 do
    if SameText(FThemeGallery.Entries[I].Hint, AName) then
      FThemeGallery.SelectedEntry := FThemeGallery.Entries[I];
  // the ribbons of the pages follow the main ribbon
  if FEmbedded <> nil then
  begin
    FEmbedded.AccentColor := AAccent;
    FEmbedded.Theme := AName;
  end;
  if FChild <> nil then
  begin
    FChild.AccentColor := AAccent;
    FChild.Theme := AName;
  end;
  SetMessage('Theme: ' + TFmrTheme.ThemeDisplayName(AName));
end;

procedure TShowcaseForm.ThemeDrawItem(Sender: TObject; const ACanvas: TCanvas; const AEntry: TFmrGalleryEntry;
  const ARect: TRectF; const AState: TFmrGalleryDrawStates; const APainter: TFmrRibbonPainter;
  var AHandled: Boolean);
var
  T: TFmrTheme;
  Box, R: TRectF;
  TextColor: TAlphaColor;
begin
  T := ThemeFor(AEntry.Hint);
  Box := RectF(ARect.Left + 4, ARect.Top + 3, ARect.Right - 4, ARect.Bottom - 17);
  R := RectF(Box.Left, Box.Top, Box.Right, Box.Top + Round(Box.Height * 0.3));
  T.Fills[TFmrToken.CaptionFill].ApplyTo(ACanvas.Fill);
  ACanvas.FillRect(R, 0, 0, [], 1);
  R := RectF(Box.Left, R.Bottom, Box.Right, R.Bottom + Round(Box.Height * 0.22));
  T.Fills[TFmrToken.TabRowFill].ApplyTo(ACanvas.Fill);
  ACanvas.FillRect(R, 0, 0, [], 1);
  ACanvas.Fill.Kind := TBrushKind.Solid;
  ACanvas.Fill.Color := T.Colors[TFmrToken.TabActiveIndicator];
  ACanvas.FillRect(RectF(Box.Left + 16, R.Bottom - 2, Box.Left + 32, R.Bottom), 0, 0, [], 1);
  ACanvas.Fill.Color := T.Colors[TFmrToken.Accent];
  ACanvas.FillRect(RectF(Box.Left + 3, R.Top + 3, Box.Left + 11, R.Bottom - 3), 0, 0, [], 1);
  R := RectF(Box.Left, R.Bottom, Box.Right, Box.Bottom);
  T.Fills[TFmrToken.BodyFill].ApplyTo(ACanvas.Fill);
  ACanvas.FillRect(R, 0, 0, [], 1);
  ACanvas.Fill.Kind := TBrushKind.Solid;
  ACanvas.Fill.Color := T.Colors[TFmrToken.GlyphTint];
  ACanvas.FillRect(RectF(R.Left + 5, R.Top + 4, R.Left + 13, R.Bottom - 4), 1, 1, AllCorners, 1);
  ACanvas.FillRect(RectF(R.Left + 17, R.Top + 4, R.Right - 8, R.Top + 7), 1, 1, AllCorners, 1);
  ACanvas.FillRect(RectF(R.Left + 17, R.Top + 10, R.Right - 16, R.Top + 13), 1, 1, AllCorners, 1);
  ACanvas.Stroke.Kind := TBrushKind.Solid;
  ACanvas.Stroke.Color := FmrWithAlpha(APainter.Theme.Colors[TFmrToken.ButtonText], 0.25);
  ACanvas.Stroke.Thickness := 1;
  ACanvas.DrawRect(RectF(Box.Left + 0.5, Box.Top + 0.5, Box.Right - 0.5, Box.Bottom - 0.5), 0, 0, [], 1);
  if TFmrGalleryDrawState.InRibbon in AState then
    TextColor := APainter.ButtonTextColor(TFmrPartState.Normal)
  else
    TextColor := APainter.Theme.Colors[TFmrToken.MenuItemText];
  APainter.TextEx(ACanvas, RectF(ARect.Left + 1, ARect.Bottom - 17, ARect.Right - 1, ARect.Bottom - 1),
    AEntry.Caption.Replace('Office ', '').Replace('Windows 11 ', 'Win11 '), TextColor, TTextAlign.Center,
    TTextAlign.Center, APainter.Metrics.FontSize - 1.5, False, False);
  AHandled := True;
end;

procedure TShowcaseForm.ThemeItemClick(Sender: TObject; const AEntry: TFmrGalleryEntry);
begin
  ApplyTheme(AEntry.Hint, FAccent);
end;

function TShowcaseForm.ItemScreenRect(const AItem: TFmrBarItem; out ARect: TRectF): TFmrItemView;
var
  I: Integer;
  V: TFmrItemView;
  C: TControl;
begin
  Result := nil;
  if AItem = nil then
    Exit;
  FRibbon.UpdateLayout;
  for I := 0 to AItem.LinkCount - 1 do
    if AItem.Links[I].ViewObject is TFmrItemView then
    begin
      V := TFmrItemView(AItem.Links[I].ViewObject);
      if (V.Host <> nil) and (V.Host.GetHostControl <> nil) then
      begin
        C := V.Host.GetHostControl;
        ARect := TRectF.Create(C.LocalToScreen(V.Bounds.TopLeft), C.LocalToScreen(V.Bounds.BottomRight));
        Exit(V);
      end;
    end;
end;

procedure TShowcaseForm.OpenDropDown(const AItem: TFmrBarItem);
var
  I: Integer;
  V: TFmrItemView;
  R: TRectF;
begin
  if AItem = nil then
    Exit;
  // show the tab of the item first, then open the drop-down of its view like a mouse press
  for I := 0 to AItem.LinkCount - 1 do
    if AItem.Links[I].LinksOwner is TFmrRibbonGroup then
    begin
      FRibbon.ActiveTab := TFmrRibbonGroup(AItem.Links[I].LinksOwner).Tab;
      Break;
    end;
  V := ItemScreenRect(AItem, R);
  if V <> nil then
    V.Host.ElementDropDown(V, False);
end;

function TShowcaseForm.NewEmbeddedRibbon(const AParent: TFmxObject; out AManager: TFmrBarManager;
  out AFrame: TFmrFormFrame): TFmrRibbon;
begin
  // A ribbon inside a panel. Without Frame, a ribbon attaches to the TFmrFormFrame of its form; a frame that
  // belongs to no form (no host) keeps the caption row and the tab row inside the ribbon.
  AManager := TFmrBarManager.Create(Self);
  AManager.Parent := Self;
  AFrame := TFmrFormFrame.Create(nil);
  Result := TFmrRibbon.Create(Self);
  Result.Frame := AFrame;
  Result.BarManager := AManager;
  Result.Theme := FRibbon.Theme;
  Result.AccentColor := FRibbon.AccentColor;
  Result.ShowCaption := False;
  Result.QuickAccessToolbar.Visible := False;
  Result.Align := TAlignLayout.None;
  Result.Parent := AParent;
end;

{ TShowcaseForm: pages }

procedure TShowcaseForm.ClearPage;
var
  T: TFmrBackstageTile;
begin
  for T in FTiles do
    FActions.Remove(T);
  FTiles.Clear;
  FAutoActions.Clear;
  // a destroyed merge source is unmerged by the main ribbon
  FreeAndNil(FChild);
  FreeAndNil(FChildFrame);
  FreeAndNil(FChildManager);
  FreeAndNil(FEmbedded);
  FreeAndNil(FEmbeddedFrame);
  FreeAndNil(FEmbeddedManager);
  FInfo := nil;
  FLayoutMemo := nil;
  FWidthTrack := nil;
  FEmbeddedHost := nil;
  FPerfMemo := nil;
  FDemoStatus := nil;
  FreeAndNil(FBox);
end;

procedure TShowcaseForm.ShowPage(const AIndex: Integer);
var
  I: Integer;
begin
  ClearPage;
  FPageIndex := AIndex;
  FOrder := 0;
  FBox := TVertScrollBox.Create(Self);
  FBox.Align := TAlignLayout.Client;
  FBox.Padding.Rect := RectF(36, 18, 36, 24);
  FBox.Parent := FBackground;
  AddTitle(Pages[AIndex].Title);
  case AIndex of
    0: PageOverview;
    1: PageThemes;
    2: PageFrame;
    3: PageAdaptive;
    4: PageGalleries;
    5: PageMenus;
    6: PageKeyTips;
    7: PageScreenTips;
    8: PageContext;
    9: PageQAT;
    10: PageModes;
    11: PageRTL;
    12: PageMiniToolbar;
    13: PageRadial;
    14: PageAppMenu;
    15: PageStatusBar;
    16: PageMerge;
    17: PagePersistence;
    18: PageCustomize;
    19: PageLocalization;
    20: PageCanvas;
    21: PagePerformance;
  end;
  for I := 0 to FNav.Items.Count - 1 do
    if not FNav.Items[I].Header and (FNav.Items[I].Tag = AIndex) then
      FNav.ItemIndex := I;
  FPagePanel.Text := Format('%d/%d  %s', [AIndex + 1, Length(Pages), Pages[AIndex].Title]);
end;

function TShowcaseForm.NextPos: Single;
begin
  // FMX stacks Top aligned controls by position: growing values keep the creation order
  Inc(FOrder);
  Result := FOrder * 1000;
end;

function TShowcaseForm.AddTitle(const AText: string): TFmrBackstageHeader;
begin
  Result := TFmrBackstageHeader.Create(FBox);
  Result.Text := AText;
  Result.Position.Y := NextPos;
  Result.Parent := FBox;
end;

function TShowcaseForm.AddText(const AText: string; const AStyle: TFmrBackstageTextStyle): TFmrBackstageLabel;
begin
  Result := TFmrBackstageLabel.Create(FBox);
  Result.TextStyle := AStyle;
  Result.Text := AText;
  Result.Align := TAlignLayout.Top;
  Result.Margins.Bottom := 8;
  Result.Position.Y := NextPos;
  Result.Parent := FBox;
end;

function TShowcaseForm.AddSection(const AText: string): TFmrBackstageLabel;
begin
  Result := AddText(AText, TFmrBackstageTextStyle.Subtitle);
  Result.Margins.Top := 12;
end;

function TShowcaseForm.AddInfo: TFmrBackstageLabel;
begin
  FInfo := AddText('', TFmrBackstageTextStyle.Secondary);
  FInfo.Margins.Top := 6;
  Result := FInfo;
end;

function TShowcaseForm.AddFlow(const AItemWidth, AItemHeight: Single): TFlowLayout;
begin
  Result := TFlowLayout.Create(FBox);
  Result.Align := TAlignLayout.Top;
  Result.HorizontalGap := 10;
  Result.VerticalGap := 10;
  Result.Height := AItemHeight + 10;
  Result.Tag := Round(AItemWidth);
  Result.TagFloat := AItemHeight;
  Result.Margins.Bottom := 6;
  Result.Position.Y := NextPos;
  Result.OnResize := FlowResize;
  Result.Parent := FBox;
end;

procedure TShowcaseForm.FlowResize(Sender: TObject);
var
  F: TFlowLayout;
  PerRow, Rows: Integer;
  H: Single;
begin
  // a flow layout does not size itself: rows x item height
  F := TFlowLayout(Sender);
  PerRow := Max(1, Trunc((F.Width + F.HorizontalGap) / (F.Tag + F.HorizontalGap)));
  Rows := Max(1, (F.ChildrenCount + PerRow - 1) div PerRow);
  H := Rows * (F.TagFloat + F.VerticalGap);
  if not SameValue(H, F.Height, 0.5) then
    F.Height := H;
end;

function TShowcaseForm.AddButton(const AParent: TFmxObject; const ACaption: string; const AGlyph: Cardinal;
  const AAction: TProc; const AWidth, AHeight: Single): TFmrBackstageTile;
begin
  Result := TFmrBackstageTile.Create(FBox);
  Result.Caption := ACaption;
  if AGlyph <> 0 then
    Result.Glyph.GlyphCode := AGlyph;
  Result.GlyphSize := 20;
  Result.Layout := TFmrBackstageTileLayout.Horizontal;
  Result.Width := AWidth;
  Result.Height := AHeight;
  Result.OnClick := TileClick;
  Result.Parent := AParent;
  FActions.AddOrSetValue(Result, AAction);
  FTiles.Add(Result);
  if AParent is TFlowLayout then
    FlowResize(AParent);
end;

procedure TShowcaseForm.SelectTile(const ATile: TFmrBackstageTile; const AGroup: Integer);
var
  T: TFmrBackstageTile;
begin
  for T in FTiles do
    if T.Tag = AGroup then
      T.Selected := T = ATile;
end;

procedure TShowcaseForm.TrackChange(Sender: TObject);
begin
  if (FEmbedded = nil) or (FWidthTrack = nil) then
    Exit;
  FEmbedded.Width := Round(FWidthTrack.Value);
  FEmbedded.UpdateLayout;
  if FEmbeddedHost <> nil then
    FEmbeddedHost.Height := FEmbedded.Height + 4;
  if FInfo <> nil then
    FInfo.Text := Format('Ribbon width: %d dp. Narrower: galleries lose columns, large buttons become small ' +
      'ones, groups collapse into drop-down buttons, finally the groups scroll.', [Round(FWidthTrack.Value)]);
end;

procedure TShowcaseForm.PageOverview;
var
  Flow: TFlowLayout;
  I: Integer;
begin
  AddText('FMR Ribbon is an open-source (MIT) Microsoft Office style ribbon for Delphi FireMonkey. A bar manager ' +
    'holds the commands (items); the ribbon, the quick access toolbar, menus, the mini toolbar, the radial menu and ' +
    'the status bar show links to them. Everything is painted by a theme painter: no styled control per button, so ' +
    'hundreds of commands cost a few objects each.');
  AddText('The window above is a TFmrFormFrame (FullNC mode: the caption row and the tab row are in the real ' +
    'non-client area) with a TFmrRibbon built by FmrApplyRibbonTemplate (Word template) plus the "Showcase" tab, a ' +
    'TFmrStatusBar at the bottom and this page area, whose labels, tiles and the navigation list are the themed ' +
    'helper controls of the backstage view.');
  AddSection('Pages');
  Flow := AddFlow(250, 46);
  for I := 1 to High(Pages) do
    AddButton(Flow, Pages[I].Title, Pages[I].Glyph, PageAction(I), 250, 46);
  AddInfo.Text := 'Command line: /page=N /theme=<name> /frame=fullnc|dwm|ncstrip /lang=ru /auto';
end;

function TShowcaseForm.PageAction(const AIndex: Integer): TProc;
begin
  // queued: the page (and the tile that was clicked) is destroyed by ShowPage
  Result :=
    procedure
    begin
      TThread.ForceQueue(nil,
        procedure
        begin
          ShowPage(AIndex);
        end);
    end;
end;

procedure TShowcaseForm.PageThemes;
var
  Flow: TFlowLayout;
  I: Integer;
  T: TFmrBackstageTile;

  function ThemeAction(const AName: string): TProc;
  begin
    Result :=
      procedure
      var
        Tile: TFmrBackstageTile;
      begin
        ApplyTheme(AName, FAccent);
        for Tile in FTiles do
          if Tile.Tag = 1 then
            Tile.Selected := SameText(Tile.TagString, AName);
      end;
  end;

  function AccentAction(const AIndex: Integer): TProc;
  begin
    Result :=
      procedure
      var
        Tile: TFmrBackstageTile;
      begin
        ApplyTheme(FRibbon.Theme, Accents[AIndex]);
        for Tile in FTiles do
          if Tile.Tag = 2 then
            Tile.Selected := Tile.TagString = IntToStr(AIndex);
      end;
  end;

begin
  AddText('A theme is a table of color/fill tokens, metrics and drawing switches (tab shape, application button, ' +
    'group frames). TFmrRibbon.Theme selects one of the built-in themes; AccentColor recolors Colorful captions, ' +
    'active tab indicators, the File tab and selections. The backstage view, the status bar, every popup and the ' +
    'helper controls of this page follow the ribbon (IFmrThemeProvider + TFmrThemeChangedMessage). A StyleBook can ' +
    'override any token (see Docs\STYLES.md).');
  AddSection('Themes');
  Flow := AddFlow(222, 44);
  for I := 0 to High(FThemeNames) do
  begin
    T := AddButton(Flow, TFmrTheme.ThemeDisplayName(FThemeNames[I]), 0, ThemeAction(FThemeNames[I]), 222, 44);
    T.Glyph.PathData := PathPalette;
    T.Glyph.PathViewBox := 24;
    T.Glyph.Color := ThemeFor(FThemeNames[I]).Fills[TFmrToken.CaptionFill].MainColor;
    if (FmrLuminance(T.Glyph.Color) > 0.6) or (FmrLuminance(T.Glyph.Color) < 0.12) then
      T.Glyph.Color := ThemeFor(FThemeNames[I]).Colors[TFmrToken.Accent];
    T.Tag := 1;
    T.TagString := FThemeNames[I];
    T.Selected := SameText(FThemeNames[I], FRibbon.Theme);
  end;
  AddSection('Accent colors');
  Flow := AddFlow(170, 44);
  for I := 0 to High(Accents) do
  begin
    T := AddButton(Flow, AccentNames[I], 0, AccentAction(I), 170, 44);
    T.Glyph.PathData := PathCircle;
    T.Glyph.PathViewBox := 24;
    if Accents[I] = 0 then
      T.Glyph.Color := TFmrTheme.DefaultAccent(FRibbon.Theme)
    else
      T.Glyph.Color := Accents[I];
    T.Tag := 2;
    T.TagString := IntToStr(I);
    T.Selected := Accents[I] = FAccent;
  end;
  AddInfo.Text := 'The "Themes" gallery of the Showcase tab shows the same themes with a preview of their colors.';
end;

procedure TShowcaseForm.UpdateFrameInfo;
const
  ModeNames: array [TFmrFrameMode] of string = ('Dwm', 'FullNC', 'NCStrip');
  BackdropNames: array [TFmrFrameBackdrop] of string = ('None', 'Mica', 'Acrylic', 'Tabbed');
begin
  if FInfo <> nil then
    FInfo.Text := Format('Mode: %s, backdrop: %s, hooked: %s, caption height: %.0f dp',
      [ModeNames[FFrame.Mode], BackdropNames[FFrame.Backdrop], BoolToStr(FFrame.Hooked, True),
      FFrame.CaptionHeight]);
end;

procedure TShowcaseForm.PageFrame;
var
  Flow: TFlowLayout;
  M: TFmrFrameMode;
  B: TFmrFrameBackdrop;
  T: TFmrBackstageTile;
const
  ModeCaptions: array [TFmrFrameMode] of string = ('Dwm - caption in the client area', 'FullNC - real non-client',
    'NCStrip - below the system caption');
  BackdropCaptions: array [TFmrFrameBackdrop] of string = ('No backdrop', 'Mica', 'Acrylic', 'Mica Alt (Tabbed)');

  function ModeAction(const AMode: TFmrFrameMode): TProc;
  begin
    Result :=
      procedure
      var
        Tile: TFmrBackstageTile;
      begin
        if AMode <> TFmrFrameMode.Dwm then
          FFrame.Backdrop := TFmrFrameBackdrop.None;
        FFrame.Mode := AMode;
        for Tile in FTiles do
          if Tile.Tag = 1 then
            Tile.Selected := Tile.TagString = IntToStr(Ord(AMode));
        UpdateFrameInfo;
      end;
  end;

  function BackdropAction(const ABackdrop: TFmrFrameBackdrop): TProc;
  begin
    Result :=
      procedure
      var
        Tile: TFmrBackstageTile;
      begin
        if ABackdrop <> TFmrFrameBackdrop.None then
          FFrame.Mode := TFmrFrameMode.Dwm;
        FFrame.Backdrop := ABackdrop;
        for Tile in FTiles do
          if Tile.Tag = 1 then
            Tile.Selected := Tile.TagString = IntToStr(Ord(FFrame.Mode))
          else if Tile.Tag = 2 then
            Tile.Selected := Tile.TagString = IntToStr(Ord(ABackdrop));
        UpdateFrameInfo;
      end;
  end;

begin
  AddText('TFmrFormFrame puts FMX controls into the title bar area of a form; the ribbon moves its caption row ' +
    '(quick access toolbar, title, search, window buttons) and its tab row into the frame''s host. FullNC (the ' +
    'default) paints both rows in the real non-client area and keeps the Windows 11 shadow, rounded corners and ' +
    'Snap Layouts; Dwm keeps the host in the client area (needed for the Mica and Acrylic backdrops of Windows 11); ' +
    'NCStrip keeps the system title bar and puts the tab row below it. Switch live:');
  AddSection('Mode');
  Flow := AddFlow(300, 44);
  for M in [TFmrFrameMode.FullNC, TFmrFrameMode.Dwm, TFmrFrameMode.NCStrip] do
  begin
    T := AddButton(Flow, ModeCaptions[M], $E737, ModeAction(M), 300, 44);
    T.Tag := 1;
    T.TagString := IntToStr(Ord(M));
    T.Selected := FFrame.Mode = M;
  end;
  AddSection('Backdrop (Dwm mode, Windows 11 22H2 or newer)');
  Flow := AddFlow(220, 44);
  for B := Low(TFmrFrameBackdrop) to High(TFmrFrameBackdrop) do
  begin
    T := AddButton(Flow, BackdropCaptions[B], $E790, BackdropAction(B), 220, 44);
    T.Tag := 2;
    T.TagString := IntToStr(Ord(B));
    T.Selected := FFrame.Backdrop = B;
  end;
  AddText('Tip: the Fluent themes (Windows 11 Light / Dark) have a transparent caption over a backdrop.',
    TFmrBackstageTextStyle.Secondary);
  AddInfo;
  UpdateFrameInfo;
  FAutoActions.AddOrSetValue(2,
    procedure
    begin
      ApplyTheme('FluentLight', 0);
      FFrame.Mode := TFmrFrameMode.Dwm;
      FFrame.Backdrop := TFmrFrameBackdrop.Mica;
      UpdateFrameInfo;
    end);
end;

procedure TShowcaseForm.PageAdaptive;
var
  Flow: TFlowLayout;
  T: TFmrBackstageTile;
  Tpl: TFmrRibbonTemplate;
  Row: TLayout;

  function TemplateAction(const ATemplate: TFmrRibbonTemplate): TProc;
  begin
    Result :=
      procedure
      var
        Tile: TFmrBackstageTile;
      begin
        FmrApplyRibbonTemplate(FEmbedded, ATemplate, FEmbeddedManager, True);
        FEmbedded.ActiveTab := FEmbedded.Tabs(0);
        TrackChange(nil);
        for Tile in FTiles do
          if Tile.Tag = 1 then
            Tile.Selected := Tile.TagString = IntToStr(Ord(ATemplate));
      end;
  end;

begin
  AddText('The layout calculator reduces a tab in fixed steps when the ribbon gets narrower, right to left and ' +
    'by group priority: galleries lose columns, large buttons become small buttons with text, then icons only, ' +
    'galleries turn into drop-down buttons, groups collapse into one button whose popup shows the whole group, and ' +
    'finally the groups scroll. Widening is the exact reverse. Drag the slider: the ribbon below is a second ' +
    'TFmrRibbon in a panel, filled by the run-time template builder.');
  Row := TLayout.Create(FBox);
  Row.Align := TAlignLayout.Top;
  Row.Height := 32;
  Row.Position.Y := NextPos;
  Row.Parent := FBox;
  FWidthTrack := TTrackBar.Create(FBox);
  FWidthTrack.Align := TAlignLayout.Left;
  FWidthTrack.Width := 420;
  FWidthTrack.Min := 240;
  FWidthTrack.Max := 1500;
  FWidthTrack.Value := 1000;
  FWidthTrack.Parent := Row;
  FWidthTrack.OnChange := TrackChange;
  FEmbeddedHost := TLayout.Create(FBox);
  FEmbeddedHost.Align := TAlignLayout.Top;
  FEmbeddedHost.Height := 140;
  FEmbeddedHost.ClipChildren := True;
  FEmbeddedHost.Margins.Top := 8;
  FEmbeddedHost.Position.Y := NextPos;
  FEmbeddedHost.Parent := FBox;
  FEmbedded := NewEmbeddedRibbon(FEmbeddedHost, FEmbeddedManager, FEmbeddedFrame);
  FEmbedded.Position.Point := PointF(0, 0);
  FmrApplyRibbonTemplate(FEmbedded, TFmrRibbonTemplate.Word, FEmbeddedManager);
  FEmbedded.ActiveTab := FEmbedded.Tabs(0);
  AddInfo;
  AddSection('Templates (TFmrRibbonTemplateBuilder, FmrApplyRibbonTemplate)');
  Flow := AddFlow(200, 44);
  for Tpl := Low(TFmrRibbonTemplate) to High(TFmrRibbonTemplate) do
  begin
    T := AddButton(Flow, TFmrRibbonTemplateBuilder.TemplateCaption(Tpl), $E8A5, TemplateAction(Tpl), 200, 44);
    T.Tag := 1;
    T.TagString := IntToStr(Ord(Tpl));
    T.Selected := Tpl = TFmrRibbonTemplate.Word;
  end;
  TrackChange(nil);
  FAutoActions.AddOrSetValue(3,
    procedure
    begin
      FWidthTrack.Value := 640;
    end);
end;

procedure TShowcaseForm.PageGalleries;
var
  Flow: TFlowLayout;
begin
  AddText('Galleries are bar items (TFmrGalleryItem / TFmrRibbonGalleryItem): groups of entries with captions, ' +
    'glyphs, descriptions and owner drawing. In the ribbon they show as many columns as fit (the layout removes ' +
    'columns when space is short) with scroll buttons and a drop-down button; the drop-down has group headers, a ' +
    'filter band, a resize grip and commands below the entries. Hot tracking gives live preview. Menus whose links ' +
    'contain a gallery show it inline (Shapes). Every color item gets the color gallery with theme colors, tints ' +
    'and shades, standard and recent colors and "More Colors...".');
  Flow := AddFlow(300, 46);
  AddButton(Flow, 'Styles gallery (Home)', $E8D2,
    procedure
    begin
      OpenDropDown(Item('galStyles'));
    end, 300, 46);
  AddButton(Flow, 'Themes gallery (Showcase tab)', $E790,
    procedure
    begin
      OpenDropDown(FThemeGallery);
    end, 300, 46);
  AddButton(Flow, 'Color gallery (Font Color)', FmrGlyphFontColor,
    procedure
    begin
      OpenDropDown(Item('clrFontColor'));
    end, 300, 46);
  AddButton(Flow, 'Menu with an inline gallery (Shapes)', $E879,
    procedure
    begin
      OpenDropDown(FShapesButton);
    end, 300, 46);
  AddButton(Flow, 'Highlight palette', FmrGlyphHighlight,
    procedure
    begin
      OpenDropDown(Item('clrHighlight'));
    end, 300, 46);
  FAutoActions.AddOrSetValue(4,
    procedure
    begin
      OpenDropDown(FThemeGallery);
    end);
end;

procedure TShowcaseForm.PageMenus;
var
  Flow: TFlowLayout;
begin
  AddText('Buttons can be plain, check (toggle, radio with GroupIndex), drop-down or split; their menus are the ' +
    'links of DropDownLinks or of a TFmrSubItem: large rows with descriptions, check marks, submenus, accelerators, ' +
    'key tips and screen tips. TFmrPopupMenu is the same menu as a component (context menus, application menus). ' +
    'Right-clicking any command offers "Add to Quick Access Toolbar". The search box ("Tell me") searches captions, ' +
    'descriptions, hints and keywords of every item.');
  Flow := AddFlow(300, 46);
  AddButton(Flow, 'Split button menu (Paste)', FmrGlyphPaste,
    procedure
    begin
      OpenDropDown(Item('btnPaste'));
    end, 300, 46);
  AddButton(Flow, 'Context menu (TFmrPopupMenu)', $E8C8,
    procedure
    var
      P: TPointF;
    begin
      P := FBox.LocalToScreen(PointF(360, 300));
      FContextMenu.Popup(P.X, P.Y);
    end, 300, 46);
  AddButton(Flow, 'Drop-down menu (Change Case)', FmrGlyphChangeCase,
    procedure
    begin
      OpenDropDown(Item('btnChangeCase'));
    end, 300, 46);
  AddButton(Flow, 'Search "bold" in the search box', $E721,
    procedure
    begin
      FRibbon.SearchText := 'bold';
    end, 300, 46);
  FAutoActions.AddOrSetValue(5,
    procedure
    begin
      OpenDropDown(Item('btnPaste'));
    end);
end;

procedure TShowcaseForm.PageKeyTips;
var
  Flow: TFlowLayout;
begin
  AddText('Press and release Alt (or F10): the tabs, the File button and the quick access toolbar show key tips ' +
    '(letters for tabs, numbers for the toolbar). Typing a tip opens the tab and shows the tips of its commands; ' +
    'drop-downs, galleries, collapsed groups and editors are reached the same way; Esc goes back one level. Tips ' +
    'come from the KeyTip properties or are generated from the captions, always prefix-free. With a Cyrillic ' +
    'keyboard layout the Latin letter of the physical key is used.');
  Flow := AddFlow(300, 46);
  AddButton(Flow, 'Show key tips (like Alt)', $E765,
    procedure
    begin
      FRibbon.ShowKeyTipsNow;
    end, 300, 46);
  AddButton(Flow, 'Key tips on / off (ShowKeyTips)', $E765,
    procedure
    begin
      FRibbon.ShowKeyTips := not FRibbon.ShowKeyTips;
      FInfo.Text := 'ShowKeyTips = ' + BoolToStr(FRibbon.ShowKeyTips, True);
    end, 300, 46);
  AddInfo.Text := 'ShowKeyTips = ' + BoolToStr(FRibbon.ShowKeyTips, True);
  FAutoActions.AddOrSetValue(6,
    procedure
    begin
      FRibbon.ShowKeyTipsNow;
    end);
end;

procedure TShowcaseForm.ShowItemTip(const AItem: TFmrBarItem);
var
  V: TFmrItemView;
  R: TRectF;
begin
  FRibbon.ActiveTab := FRibbon.Tabs(0);
  V := ItemScreenRect(AItem, R);
  if V <> nil then
    FRibbon.ScreenTips.Hover(V, R, FRibbon.Painter, Self);
end;

procedure TShowcaseForm.PageScreenTips;
var
  Flow: TFlowLayout;
begin
  AddText('Screen tips are rich tooltips: a header (with the shortcut), a description, an optional image and a ' +
    'footer ("Press F1 for more help"), shown below the command after a short delay and switched quickly between ' +
    'neighbours. Items without a ScreenTip show their Hint. Menu rows and gallery entries have screen tips too. ' +
    'Hover a command of the ribbon, or:');
  Flow := AddFlow(300, 46);
  AddButton(Flow, 'Show the screen tip of Paste', FmrGlyphPaste,
    procedure
    begin
      ShowItemTip(Item('btnPaste'));
    end, 300, 46);
  AddButton(Flow, 'Screen tips on / off', $E946,
    procedure
    begin
      FRibbon.ShowScreenTips := not FRibbon.ShowScreenTips;
      FInfo.Text := 'ShowScreenTips = ' + BoolToStr(FRibbon.ShowScreenTips, True);
    end, 300, 46);
  AddInfo.Text := 'ShowScreenTips = ' + BoolToStr(FRibbon.ShowScreenTips, True);
  Item('btnPaste').ScreenTip.Header := 'Paste';
  Item('btnPaste').ScreenTip.Description := 'Add content from the clipboard to the document.';
  Item('btnPaste').ScreenTip.ShowFooter := True;
  FAutoActions.AddOrSetValue(7,
    procedure
    begin
      ShowItemTip(Item('btnPaste'));
    end);
end;

procedure TShowcaseForm.PageContext;
var
  Flow: TFlowLayout;
  Ctx: TFmrRibbonContextGroup;
begin
  AddText('Contextual tabs belong to a TFmrRibbonContextGroup: hidden until the application shows them (a table ' +
    'or a picture is selected), drawn with the color of the group and a header in the caption row. Activate shows ' +
    'the group and selects its first tab; hiding the group while one of its tabs is active selects another tab.');
  Ctx := TFmrRibbonContextGroup(FindComponent('ctxTableTools'));
  Flow := AddFlow(260, 46);
  AddButton(Flow, 'Show Table Tools', FmrGlyphTable,
    procedure
    begin
      Ctx.Visible := True;
    end, 260, 46);
  AddButton(Flow, 'Activate Table Tools', FmrGlyphTable,
    procedure
    begin
      Ctx.Activate;
    end, 260, 46);
  AddButton(Flow, 'Hide Table Tools', $E711,
    procedure
    begin
      Ctx.Visible := False;
    end, 260, 46);
  AddButton(Flow, 'Add a Picture Tools group', FmrGlyphPictures,
    procedure
    var
      G: TFmrRibbonContextGroup;
      T: TFmrRibbonTab;
      Grp: TFmrRibbonGroup;
      B: TFmrButtonItem;
    begin
      G := TFmrRibbonContextGroup(FindComponent('ctxSCPicture'));
      if G = nil then
      begin
        FRibbon.BeginStructureUpdate;
        try
          G := FRibbon.AddContextGroup('Picture Tools', TAlphaColor($FF7A4EB0), 'ctxSCPicture');
          T := FRibbon.AddTab('Picture Format', 'tabSCPicture');
          T.ContextGroup := G;
          Grp := T.AddGroup('Adjust');
          B := TFmrButtonItem(FManager.CreateItem(TFmrButtonItem, 'btnSCCrop'));
          B.Caption := 'Crop';
          B.Glyph.GlyphCode := $E7A8;
          B.LargeGlyph.GlyphCode := $E7A8;
          B.OnClick := CommandClick;
          Grp.ItemLinks.AddItem(B);
          B := TFmrButtonItem(FManager.CreateItem(TFmrButtonItem, 'btnSCRotate'));
          B.Caption := 'Rotate';
          B.Glyph.GlyphCode := $E7AD;
          B.LargeGlyph.GlyphCode := $E7AD;
          B.OnClick := CommandClick;
          Grp.ItemLinks.AddItem(B);
        finally
          FRibbon.EndStructureUpdate;
        end;
      end;
      G.Activate;
    end, 260, 46);
  FAutoActions.AddOrSetValue(8,
    procedure
    begin
      Ctx.Activate;
    end);
end;

procedure TShowcaseForm.PageQAT;
var
  Flow: TFlowLayout;
  T: TFmrBackstageTile;
begin
  AddText('The quick access toolbar (TFmrRibbon.QuickAccessToolbar) holds links like a group: above the ribbon in ' +
    'the caption row or below the ribbon in its own bar. Its customize button opens a menu with the commands, ' +
    '"Show below/above the ribbon" and "More Commands"; any command can be added with a right click.');
  Flow := AddFlow(260, 46);
  T := AddButton(Flow, 'Above the ribbon', $E70E,
    procedure
    begin
      FRibbon.QuickAccessToolbar.Position := TFmrQATPosition.AboveRibbon;
      SelectTile(FTiles[0], 1);
    end, 260, 46);
  T.Tag := 1;
  T.Selected := FRibbon.QuickAccessToolbar.Position = TFmrQATPosition.AboveRibbon;
  T := AddButton(Flow, 'Below the ribbon', $E70D,
    procedure
    begin
      FRibbon.QuickAccessToolbar.Position := TFmrQATPosition.BelowRibbon;
      SelectTile(FTiles[1], 1);
    end, 260, 46);
  T.Tag := 1;
  T.Selected := FRibbon.QuickAccessToolbar.Position = TFmrQATPosition.BelowRibbon;
  Flow := AddFlow(260, 46);
  AddButton(Flow, 'Add Bold / Italic', FmrGlyphBold,
    procedure
    begin
      FRibbon.QuickAccessToolbar.AddItem(Item('btnBold'));
      FRibbon.QuickAccessToolbar.AddItem(Item('btnItalic'));
    end, 260, 46);
  AddButton(Flow, 'Remove Bold / Italic', $E738,
    procedure
    begin
      FRibbon.QuickAccessToolbar.RemoveItem(Item('btnBold'));
      FRibbon.QuickAccessToolbar.RemoveItem(Item('btnItalic'));
    end, 260, 46);
  AddButton(Flow, 'Show / hide the toolbar', $E7B3,
    procedure
    begin
      FRibbon.QuickAccessToolbar.Visible := not FRibbon.QuickAccessToolbar.Visible;
    end, 260, 46);
  AddButton(Flow, 'Customize button on / off', $E70D,
    procedure
    begin
      FRibbon.QuickAccessToolbar.ShowCustomizeButton := not FRibbon.QuickAccessToolbar.ShowCustomizeButton;
    end, 260, 46);
  FAutoActions.AddOrSetValue(9,
    procedure
    begin
      FRibbon.QuickAccessToolbar.AddItem(Item('btnBold'));
      FRibbon.QuickAccessToolbar.AddItem(Item('btnItalic'));
      FRibbon.QuickAccessToolbar.Position := TFmrQATPosition.BelowRibbon;
    end);
end;

procedure TShowcaseForm.PageModes;
var
  Flow: TFlowLayout;
begin
  AddText('Minimized (Ctrl+F1, double click on a tab) shows only the tabs, a click on a tab shows its commands ' +
    'over the document. ShowMode = AutoHide hides the whole ribbon until the caption row is clicked (Office "Auto-' +
    'hide Ribbon", also in the Ribbon Display Options caption button). DisplayMode = Simplified is the single-line ' +
    'ribbon of Office 365 with an overflow menu (also the chevron at the right end). TouchMode enlarges every ' +
    'interactive size.');
  Flow := AddFlow(280, 46);
  AddButton(Flow, 'Minimized on / off', $E70E,
    procedure
    begin
      FRibbon.Minimized := not FRibbon.Minimized;
    end, 280, 46);
  AddButton(Flow, 'Show tabs and commands', $E8A0,
    procedure
    begin
      FRibbon.ShowMode := TFmrRibbonShowMode.TabsAndCommands;
    end, 280, 46);
  AddButton(Flow, 'Show tabs only', $E8A0,
    procedure
    begin
      FRibbon.ShowMode := TFmrRibbonShowMode.TabsOnly;
    end, 280, 46);
  AddButton(Flow, 'Auto-hide the ribbon', $E8A0,
    procedure
    begin
      FRibbon.ShowMode := TFmrRibbonShowMode.AutoHide;
    end, 280, 46);
  AddButton(Flow, 'Classic / simplified', $E8FD,
    procedure
    begin
      if FRibbon.DisplayMode = TFmrRibbonDisplayMode.Classic then
        FRibbon.DisplayMode := TFmrRibbonDisplayMode.Simplified
      else
        FRibbon.DisplayMode := TFmrRibbonDisplayMode.Classic;
    end, 280, 46);
  AddButton(Flow, 'Touch mode on / off', $E815,
    procedure
    begin
      FRibbon.TouchMode := not FRibbon.TouchMode;
    end, 280, 46);
  AddButton(Flow, 'Display options button on / off', $E8A0,
    procedure
    begin
      FRibbon.ShowDisplayOptionsButton := not FRibbon.ShowDisplayOptionsButton;
    end, 280, 46);
  AddButton(Flow, 'Collapse button on / off', $E70E,
    procedure
    begin
      FRibbon.ShowCollapseButton := not FRibbon.ShowCollapseButton;
    end, 280, 46);
  FAutoActions.AddOrSetValue(10,
    procedure
    begin
      FRibbon.DisplayMode := TFmrRibbonDisplayMode.Simplified;
    end);
end;

procedure TShowcaseForm.PageRTL;
var
  Flow: TFlowLayout;
begin
  AddText('RightToLeft (or BiDiMode = bdRightToLeft on the form) mirrors the ribbon for right-to-left languages: ' +
    'the order of the groups and of the commands inside them, the tab row and the popups.');
  Flow := AddFlow(280, 46);
  AddButton(Flow, 'Right to left on / off', $E8AB,
    procedure
    begin
      FRibbon.RightToLeft := not FRibbon.RightToLeft;
      FInfo.Text := 'RightToLeft = ' + BoolToStr(FRibbon.RightToLeft, True);
    end, 280, 46);
  AddInfo.Text := 'RightToLeft = ' + BoolToStr(FRibbon.RightToLeft, True);
  FAutoActions.AddOrSetValue(11,
    procedure
    begin
      FRibbon.RightToLeft := True;
      FInfo.Text := 'RightToLeft = True';
    end);
end;

procedure TShowcaseForm.PageMiniToolbar;
var
  Flow: TFlowLayout;
begin
  AddText('TFmrRibbonMiniToolbar is the floating formatting toolbar of Office: it reuses the items of the ribbon ' +
    '(font name and size editors, buttons, color galleries), appears half transparent near the mouse after a text ' +
    'selection and fades out as the mouse goes away; with a context menu it appears above the menu and stays ' +
    'opaque while the menu is open.');
  Flow := AddFlow(320, 46);
  AddButton(Flow, 'Mini toolbar with the context menu', $E8D2,
    procedure
    begin
      FMini.Popup(FBox.LocalToScreen(PointF(420, 330)), True);
    end, 320, 46);
  AddButton(Flow, 'Fading mini toolbar', $E8D2,
    procedure
    begin
      FMini.Popup(FBox.LocalToScreen(PointF(420, 330)), False);
    end, 320, 46);
  FAutoActions.AddOrSetValue(12,
    procedure
    begin
      FMini.Popup(FBox.LocalToScreen(PointF(420, 330)), True);
    end);
end;

procedure TShowcaseForm.PageRadial;
var
  Flow: TFlowLayout;
begin
  AddText('TFmrRibbonRadialMenu is the round menu of OneNote for touch: up to eight commands around the center, ' +
    'sub items open a nested ring (Align), the center button goes back or closes. It uses the same items as the ' +
    'ribbon, so check states and colors are shared. Arrow keys rotate the focus.');
  Flow := AddFlow(300, 46);
  AddButton(Flow, 'Show the radial menu', $E7F4,
    procedure
    begin
      FRadial.Popup(FBox.LocalToScreen(PointF(FBox.Width / 2, 360)));
    end, 300, 46);
  FAutoActions.AddOrSetValue(13,
    procedure
    begin
      FRadial.Popup(FBox.LocalToScreen(PointF(FBox.Width / 2, 360)));
    end);
end;

procedure TShowcaseForm.ChooseAppMenu(const AMenu: TFmxObject; const AIndex: Integer);
var
  Tile: TFmrBackstageTile;
begin
  FRibbon.ApplicationMenu := AMenu;
  for Tile in FTiles do
    if Tile.Tag = 1 then
      Tile.Selected := Tile.TagString = IntToStr(AIndex);
end;

procedure TShowcaseForm.PageAppMenu;
var
  Flow: TFlowLayout;
  T: TFmrBackstageTile;
begin
  AddText('The File tab (or the Office 2007 orb) opens TFmrRibbon.ApplicationMenu: a TFmrRibbonBackstageView ' +
    '(Office 2010 and newer: covers the window, the tab row hides, the caption stays), a ' +
    'TFmrRibbonApplicationMenu (Office 2007: large rows, submenus in the right pane, recent documents with pins) or ' +
    'a plain TFmrPopupMenu. With an Office 2007 theme the application button is the orb.');
  Flow := AddFlow(300, 46);
  T := AddButton(Flow, 'Backstage view', $E8A5,
    procedure
    begin
      ChooseAppMenu(FBackstage, 0);
    end, 300, 46);
  T.Tag := 1;
  T.TagString := '0';
  T.Selected := FRibbon.ApplicationMenu = FBackstage;
  T := AddButton(Flow, 'Office 2007 application menu', $E8A5,
    procedure
    begin
      ChooseAppMenu(FAppMenu07, 1);
    end, 300, 46);
  T.Tag := 1;
  T.TagString := '1';
  T.Selected := FRibbon.ApplicationMenu = FAppMenu07;
  T := AddButton(Flow, 'Popup menu', $E8A5,
    procedure
    begin
      ChooseAppMenu(FFileMenu, 2);
    end, 300, 46);
  T.Tag := 1;
  T.TagString := '2';
  T.Selected := FRibbon.ApplicationMenu = FFileMenu;
  Flow := AddFlow(300, 46);
  AddButton(Flow, 'Open it now', $E8E5,
    procedure
    begin
      if FRibbon.ApplicationMenu = FBackstage then
        FBackstage.ShowApplicationMenu(FRibbon, FRibbon.ApplicationButtonScreenRect, False)
      else if FRibbon.ApplicationMenu = FAppMenu07 then
        FAppMenu07.ShowApplicationMenu(FRibbon, FRibbon.ApplicationButtonScreenRect, False)
      else
        FFileMenu.PopupBelow(FRibbon.ApplicationButtonScreenRect);
    end, 300, 46);
  AddButton(Flow, 'Office 2007 Blue with the orb', $E790,
    procedure
    begin
      ApplyTheme('Office2007Blue', 0);
      ChooseAppMenu(FAppMenu07, 1);
    end, 300, 46);
  FAutoActions.AddOrSetValue(14,
    procedure
    begin
      ApplyTheme('Office2007Blue', 0);
      ChooseAppMenu(FAppMenu07, 1);
      FAppMenu07.ShowApplicationMenu(FRibbon, FRibbon.ApplicationButtonScreenRect, False);
    end);
end;

procedure TShowcaseForm.PageStatusBar;
var
  Host: TLayout;
  P: TFmrStatusBarPanel;
  Bar: TProgressBar;
  Links: TFmrStatusBarPanel;
begin
  AddText('TFmrStatusBar is the Office status bar: text panels with glyphs and click events, container panels for ' +
    'any control, item link panels (small buttons for bar items), the Read / Print / Web view buttons and the Word ' +
    'zoom slider with the 100 % tick in the middle. Panels are placed from the left and from the right; when the ' +
    'bar is too narrow, stretched panels shrink, then panels are hidden from the end. The bar at the bottom of the ' +
    'window is one; here is another with every kind of panel:');
  Host := TLayout.Create(FBox);
  Host.Align := TAlignLayout.Top;
  Host.Height := 34;
  Host.Margins.Rect := RectF(0, 8, 0, 8);
  Host.Position.Y := NextPos;
  Host.Parent := FBox;
  FDemoStatus := TFmrStatusBar.Create(FBox);
  FDemoStatus.Align := TAlignLayout.Client;
  FDemoStatus.BarManager := FManager;
  FDemoStatus.ThemeProvider := FRibbon;
  FDemoStatus.Parent := Host;
  FDemoStatus.AddPanel(TFmrStatusPanelKind.Text, 'Page 2 of 7').Glyph.GlyphCode := $E8A5;
  FDemoStatus.AddPanel(TFmrStatusPanelKind.Text, '1,234 words');
  P := FDemoStatus.AddPanel(TFmrStatusPanelKind.Container);
  P.PanelWidth := 110;
  P.Padding.Rect := RectF(6, 8, 6, 8);
  Bar := TProgressBar.Create(FBox);
  Bar.Align := TAlignLayout.Client;
  Bar.Value := 65;
  Bar.Parent := P;
  Links := FDemoStatus.AddPanel(TFmrStatusPanelKind.ItemLinks, '', TFmrStatusPanelSide.Right);
  if Item('btnFind') <> nil then
    Links.ItemLinks.AddItem(Item('btnFind'));
  if Item('btnNewComment') <> nil then
    Links.ItemLinks.AddItem(Item('btnNewComment'));
  FDemoStatus.AddPanel(TFmrStatusPanelKind.ViewButtons, '', TFmrStatusPanelSide.Right);
  FDemoStatus.AddPanel(TFmrStatusPanelKind.ZoomSlider, '', TFmrStatusPanelSide.Right).Zoom := 140;
  AddText('Theme: the bars follow the ribbon through ThemeProvider (or use their own Theme / AccentColor).',
    TFmrBackstageTextStyle.Secondary);
end;

procedure TShowcaseForm.UpdateMergeInfo;
begin
  if FInfo = nil then
    Exit;
  if (FChild <> nil) and not FChild.Visible then
    FInfo.Text := 'Merged: the main ribbon shows the "Review" tab and the "Document" group of Home from the child ' +
      'ribbon (the child is hidden, like the ribbon of an MDI child window).'
  else
    FInfo.Text := 'Not merged: the child ribbon shows its own tabs.';
end;

procedure TShowcaseForm.PageMerge;
var
  Host: TLayout;
  T: TFmrRibbonTab;
  G: TFmrRibbonGroup;

  procedure AddCmd(const AGroup: TFmrRibbonGroup; const AName, ACaption: string; const AGlyph: Cardinal);
  var
    B: TFmrButtonItem;
  begin
    B := TFmrButtonItem(FChildManager.CreateItem(TFmrButtonItem, AName));
    B.Caption := ACaption;
    B.Glyph.GlyphCode := AGlyph;
    B.LargeGlyph.GlyphCode := AGlyph;
    B.OnClick := CommandClick;
    AGroup.ItemLinks.AddItem(B);
  end;

begin
  AddText('Merging puts the tabs and groups of another ribbon (a child form, a plug-in) into the main ribbon, the ' +
    'way Office merges the ribbon of an embedded document: TFmrRibbon.Merge(Source) adds copies that link the same ' +
    'items; Unmerge removes them and restores what was hidden. Per tab or group, MergeKind says what to do: Merge ' +
    'into the target with the same name or caption, Add, Replace or Remove. Below is a "document" ribbon:');
  Host := TLayout.Create(FBox);
  Host.Align := TAlignLayout.Top;
  Host.Height := 132;
  Host.Margins.Top := 6;
  Host.ClipChildren := True;
  Host.Position.Y := NextPos;
  Host.Parent := FBox;
  FChild := NewEmbeddedRibbon(Host, FChildManager, FChildFrame);
  FChild.Align := TAlignLayout.Top;
  FChild.BeginStructureUpdate;
  try
    T := FChild.AddTab('Home', 'tabDocHome');
    T.MergeKind := TFmrMergeKind.Merge;
    G := T.AddGroup('Document');
    G.Name := 'grpDocDocument';
    AddCmd(G, 'btnDocProperties', 'Properties', $E946);
    AddCmd(G, 'btnDocProtect', 'Protect', $E72E);
    T := FChild.AddTab('Review', 'tabDocReview');
    T.MergeKind := TFmrMergeKind.Add;
    T.MergeOrder := 5;
    T.KeyTip := 'R';
    G := T.AddGroup('Proofing');
    G.Name := 'grpDocProofing';
    AddCmd(G, 'btnDocSpelling', 'Spelling', $E8FD);
    AddCmd(G, 'btnDocThesaurus', 'Thesaurus', $E82D);
    G := T.AddGroup('Comments');
    G.Name := 'grpDocComments';
    AddCmd(G, 'btnDocComment', 'New Comment', $E90A);
    AddCmd(G, 'btnDocTrack', 'Track Changes', $E70F);
  finally
    FChild.EndStructureUpdate;
  end;
  FChild.ActiveTab := FChild.Tabs(1);
  AddButton(AddFlow(240, 46), 'Merge into the main ribbon', $E8A7,
    procedure
    begin
      if FRibbon.Merge(FChild) then
      begin
        FChild.Visible := False;
        FRibbon.ActiveTab := TFmrRibbonStructure.FindTab(FRibbon, 'Review');
      end;
      UpdateMergeInfo;
    end, 240, 46);
  AddButton(TFlowLayout(FTiles.Last.Parent), 'Unmerge', $E8A7,
    procedure
    begin
      FRibbon.Unmerge(FChild);
      FChild.Visible := True;
      UpdateMergeInfo;
    end, 240, 46);
  AddInfo;
  UpdateMergeInfo;
  FAutoActions.AddOrSetValue(16,
    procedure
    begin
      FActions[FTiles[0]]();
    end);
end;

procedure TShowcaseForm.PagePersistence;
var
  Flow: TFlowLayout;
begin
  AddText('The user''s layout (quick access toolbar, order, visibility and names of tabs and groups, custom tabs ' +
    'and groups, minimized / simplified state) is saved as JSON with SaveLayoutToFile / SaveLayoutToString and ' +
    'loaded with LoadLayoutFrom*. Designed captions and the links of designed groups are not saved, so a new ' +
    'version of the application can add commands. ResetLayout goes back to the designed layout.');
  Flow := AddFlow(250, 46);
  AddButton(Flow, 'Save the layout to the memo', $E74E,
    procedure
    begin
      FLayoutMemo.Text := FRibbon.SaveLayoutToString;
    end, 250, 46);
  AddButton(Flow, 'Load the memo', $E8E5,
    procedure
    begin
      try
        FRibbon.LoadLayoutFromString(FLayoutMemo.Text);
        FInfo.Text := 'Layout loaded.';
      except
        on E: Exception do
          FInfo.Text := E.Message;
      end;
    end, 250, 46);
  AddButton(Flow, 'Hide the View tab', $E890,
    procedure
    var
      T: TFmrRibbonTab;
    begin
      T := TFmrRibbonStructure.FindTab(FRibbon, 'tabView');
      if T <> nil then
        T.Visible := not T.Visible;
    end, 250, 46);
  AddButton(Flow, 'Reset (designed layout)', $E72C,
    procedure
    begin
      FRibbon.ResetLayout;
      FInfo.Text := 'Designed layout restored.';
    end, 250, 46);
  FLayoutMemo := TMemo.Create(FBox);
  FLayoutMemo.Align := TAlignLayout.Top;
  FLayoutMemo.Height := 340;
  FLayoutMemo.Margins.Top := 8;
  FLayoutMemo.TextSettings.Font.Family := 'Consolas';
  FLayoutMemo.StyledSettings := FLayoutMemo.StyledSettings - [TStyledSetting.Family];
  FLayoutMemo.Position.Y := NextPos;
  FLayoutMemo.Parent := FBox;
  AddInfo;
  FAutoActions.AddOrSetValue(17,
    procedure
    begin
      FRibbon.QuickAccessToolbar.AddItem(Item('btnBold'));
      FLayoutMemo.Text := FRibbon.SaveLayoutToString;
    end);
end;

procedure TShowcaseForm.ShowRibbonCustomization;
begin
  FRibbon.ShowCustomizationForm(TFmrCustomizationPage.Ribbon);
end;

procedure TShowcaseForm.ShowQATCustomization;
begin
  FRibbon.ShowCustomizationForm(TFmrCustomizationPage.QuickAccessToolbar);
end;

procedure TShowcaseForm.PageCustomize;
var
  Flow: TFlowLayout;
begin
  AddText('ShowCustomizationForm opens the "Customize the Ribbon" form of Office: commands by category or tab, ' +
    'search, new tabs and groups, rename, move up and down, hide, reset, import and export, and the "Quick Access ' +
    'Toolbar" page. The result is the same layout that persistence saves. The right click menu of the ribbon and ' +
    '"More Commands" of the quick access toolbar menu open it too.');
  Flow := AddFlow(280, 46);
  AddButton(Flow, 'Customize the Ribbon...', $E713,
    procedure
    begin
      TThread.ForceQueue(nil, ShowRibbonCustomization);
    end, 280, 46);
  AddButton(Flow, 'Quick Access Toolbar...', $E713,
    procedure
    begin
      TThread.ForceQueue(nil, ShowQATCustomization);
    end, 280, 46);
  FAutoActions.AddOrSetValue(18,
    procedure
    begin
      FRibbon.ShowCustomizationForm(TFmrCustomizationPage.Ribbon);
    end);
end;

procedure TShowcaseForm.PageLocalization;
var
  Flow: TFlowLayout;
begin
  AddText('Every string of the library (File, the search prompt, the quick access toolbar menu, the display ' +
    'options, the customization form, color names, screen tip footers...) comes from FMR.Ribbon.Strings: ' +
    'FmrSetLanguage(''ru'') switches to Russian, FmrRegisterLanguage adds a table, FmrSetString overrides one ' +
    'string. The ribbon updates itself on TFmrLanguageChangedMessage; the captions of your own items are yours ' +
    '(Demos\WordLike switches them too).');
  Flow := AddFlow(220, 46);
  AddButton(Flow, 'English', $E774,
    procedure
    begin
      FmrSetLanguage('en');
      FInfo.Text := 'Language: ' + FmrLanguage;
    end, 220, 46);
  AddButton(Flow, 'Русский', $E774,
    procedure
    begin
      FmrSetLanguage('ru');
      FInfo.Text := 'Language: ' + FmrLanguage;
    end, 220, 46);
  AddInfo.Text := 'Language: ' + FmrLanguage;
  FAutoActions.AddOrSetValue(19,
    procedure
    begin
      FmrSetLanguage('ru');
      FInfo.Text := 'Language: ' + FmrLanguage;
    end);
end;

procedure TShowcaseForm.PageCanvas;
var
  Fast: Boolean;
begin
  Fast := ContainsText(TCanvasManager.DefaultCanvas.ClassName, 'Fast');
  AddText('The ribbon paints with canvas primitives only, so it works with every FMX canvas: Direct2D (the ' +
    'default on Windows), GDI+, and FastCanvas (an optional GPU canvas, github: FmxFastCanvas). The frame paints the ' +
    'non-client strip from an FMX bitmap, which works with both.');
  AddSection('This program');
  AddText(Format('Canvas class: %s', [TCanvasManager.DefaultCanvas.ClassName]));
  {$IFDEF FMR_FASTCANVAS}
  AddText('Built with FMR_FASTCANVAS: InstallFastCanvas runs before Application.Initialize.');
  {$ELSE}
  AddText('Built without FMR_FASTCANVAS.');
  {$ENDIF}
  AddText(Format('%d-bit, %s', [SizeOf(Pointer) * 8, IfThen(Fast, 'GPU canvas', 'stock canvas')]));
  AddSection('Building with FastCanvas');
  AddText('.\build.ps1 -Project Demos\Showcase\Showcase.dpr -Define FMR_FASTCANVAS -SearchPath ' +
    'f:\Projects\FmxFastCanvas_GitHub\src\Canvas,f:\Projects\FmxFastCanvas_GitHub\third_party\delphidx12\src',
    TFmrBackstageTextStyle.Secondary);
end;

procedure TShowcaseForm.RemovePerformanceTab;
var
  I: Integer;
begin
  if FPerfTab = nil then
    Exit;
  FRibbon.BeginStructureUpdate;
  try
    if FRibbon.ActiveTab = FPerfTab then
      FRibbon.ActiveTab := FRibbon.Tabs(0);
    FreeAndNil(FPerfTab);
    FManager.BeginUpdate;
    try
      for I := FPerfItems.Count - 1 downto 0 do
        FPerfItems[I].Free;
      FPerfItems.Clear;
    finally
      FManager.EndUpdate;
    end;
  finally
    FRibbon.EndStructureUpdate;
  end;
end;

procedure TShowcaseForm.RunPerformance;
const
  GroupCount = 50;
  ItemsPerGroup = 10;
  Glyphs: array [0..9] of Cardinal = ($E8C6, $E8C8, $E77F, $E8DD, $E8DB, $E8DC, $E721, $E749, $E74E, $E70F);
var
  SW: TStopwatch;
  TBuild, TLayout, TPaint, TSwitch: Double;
  G: TFmrRibbonGroup;
  B: TFmrButtonItem;
  I, J, K: Integer;
  Bmp: TBitmap;
  Log: TStringList;
begin
  RemovePerformanceTab;
  Log := TStringList.Create;
  try
    SW := TStopwatch.StartNew;
    FRibbon.BeginStructureUpdate;
    FManager.BeginUpdate;
    try
      FPerfTab := FRibbon.AddTab('Performance', 'tabSCPerf');
      for I := 1 to GroupCount do
      begin
        G := FPerfTab.AddGroup('Group ' + IntToStr(I));
        for J := 1 to ItemsPerGroup do
        begin
          B := TFmrButtonItem(FManager.CreateItem(TFmrButtonItem, ''));
          B.Caption := Format('Cmd %d.%d', [I, J]);
          B.Glyph.GlyphCode := Glyphs[J mod 10];
          if J <= 2 then
            B.LargeGlyph.GlyphCode := Glyphs[J mod 10];
          B.OnClick := CommandClick;
          FPerfItems.Add(B);
          G.ItemLinks.AddItem(B);
        end;
      end;
    finally
      FManager.EndUpdate;
      FRibbon.EndStructureUpdate;
    end;
    TBuild := SW.Elapsed.TotalMilliseconds;

    SW := TStopwatch.StartNew;
    FRibbon.ActiveTab := FPerfTab;
    FRibbon.UpdateLayout;
    TLayout := SW.Elapsed.TotalMilliseconds;

    Bmp := TBitmap.Create(Round(FRibbon.Width), Round(FRibbon.Body.Height));
    try
      SW := TStopwatch.StartNew;
      for K := 1 to 10 do
        if Bmp.Canvas.BeginScene then
        try
          FRibbon.Body.PaintTo(Bmp.Canvas, RectF(0, 0, Bmp.Width, Bmp.Height));
        finally
          Bmp.Canvas.EndScene;
        end;
      TPaint := SW.Elapsed.TotalMilliseconds / 10;
    finally
      Bmp.Free;
    end;

    SW := TStopwatch.StartNew;
    for K := 1 to 5 do
    begin
      FRibbon.ActiveTab := FRibbon.Tabs(0);
      FRibbon.UpdateLayout;
      FRibbon.ActiveTab := FPerfTab;
      FRibbon.UpdateLayout;
    end;
    TSwitch := SW.Elapsed.TotalMilliseconds / 10;

    Log.Add(Format('Tab with %d groups x %d commands = %d items (+%d links)', [GroupCount, ItemsPerGroup,
      GroupCount * ItemsPerGroup, GroupCount * ItemsPerGroup]));
    Log.Add(Format('Create items, groups and links: %.1f ms', [TBuild]));
    Log.Add(Format('Activate the tab + first layout (views, measuring, reduction): %.1f ms', [TLayout]));
    Log.Add(Format('Paint the body into a bitmap: %.1f ms per paint (average of 10)', [TPaint]));
    Log.Add(Format('Switch tabs + layout: %.1f ms per switch (average of 10)', [TSwitch]));
    Log.Add(Format('Canvas: %s', [TCanvasManager.DefaultCanvas.ClassName]));
    if FPerfMemo <> nil then
      FPerfMemo.Text := Log.Text;
    SetMessage(Format('Performance: layout %.1f ms, paint %.1f ms', [TLayout, TPaint]));
  finally
    Log.Free;
  end;
end;

procedure TShowcaseForm.PagePerformance;
var
  Flow: TFlowLayout;
begin
  AddText('Items and links are plain objects and the ribbon creates views only for the active tab, so a large ' +
    'command set stays cheap. Layout runs on idle (changes only mark the structure, the layout or the arrangement ' +
    'invalid) and the layout calculator prepares the reduction steps once per tab, then finds the step for a width ' +
    'with a binary search.');
  Flow := AddFlow(280, 46);
  AddButton(Flow, 'Create a tab with 500 commands', $E916,
    procedure
    begin
      RunPerformance;
    end, 280, 46);
  AddButton(Flow, 'Remove it', $E74D,
    procedure
    begin
      RemovePerformanceTab;
      FPerfMemo.Text := '';
    end, 280, 46);
  FPerfMemo := TMemo.Create(FBox);
  FPerfMemo.Align := TAlignLayout.Top;
  FPerfMemo.Height := 180;
  FPerfMemo.Margins.Top := 8;
  FPerfMemo.ReadOnly := True;
  FPerfMemo.Position.Y := NextPos;
  FPerfMemo.Parent := FBox;
  FAutoActions.AddOrSetValue(21, RunPerformance);
end;

end.
