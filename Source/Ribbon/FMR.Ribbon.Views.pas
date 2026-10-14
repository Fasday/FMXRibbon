{*******************************************************}
{                                                       }
{  FMR Ribbon for FireMonkey                            }
{  Lightweight view objects of the ribbon               }
{                                                       }
{  MIT License. Copyright (c) 2026 Fasday               }
{                                                       }
{*******************************************************}

unit FMR.Ribbon.Views;

/// Elements are the lightweight objects the ribbon paints and hit-tests itself (no TControl per button). An element
/// has bounds in the local coordinates of its host control (the ribbon body, the caption or tab bar, a popup), a hot
/// and a pressed part, and paints itself with the painter of its host. TFmrItemView is the element of one item link;
/// the view class of an item is found in a registry (FmrRegisterItemView), so other units add views for their items
/// (editors: FMR.Ribbon.Editors; galleries: a later unit). TFmrElementTracker implements the mouse protocol shared by
/// every host: hot tracking, pressed state with capture, drop-down parts that open on mouse down.

interface

{$SCOPEDENUMS ON}

uses
  System.SysUtils, System.Classes, System.Types, System.UITypes, System.Generics.Collections, System.Math,
  FMX.Types, FMX.Graphics, FMX.Controls, FMX.ImgList, FMR.Ribbon.Types, FMR.Bars.Images, FMR.Bars, FMR.Bars.Items,
  FMR.Ribbon.Layout, FMR.Ribbon.Theme, FMR.Ribbon.Painter;

type
  TFmrElement = class;
  TFmrItemView = class;

  /// <summary>Part of an element: split buttons have a main part and a drop-down part.</summary>
  TFmrElementPart = (None, Main, DropDown);

  /// <summary>Where an item view is shown; decides its sizes and look.</summary>
  TFmrViewPlace = (
    /// <summary>A group of the classic ribbon (levels Large, SmallWithText, Small).</summary>
    Group,
    /// <summary>The quick access toolbar: small glyph-only buttons.</summary>
    Toolbar,
    /// <summary>The single line of the simplified ribbon.</summary>
    Simplified);

  /// <summary>What a screen tip shows for an element.</summary>
  TFmrScreenTipInfo = record
    Header: string;
    Description: string;
    /// <summary>Footer text; empty with ShowFooter = "Press F1 for more help".</summary>
    Footer: string;
    ShowFooter: Boolean;
    Shortcut: string;
    Image: TFmrImageSource;
    Images: TCustomImageList;
    Width: Single;
    Disabled: Boolean;
    function IsEmpty: Boolean;
  end;

  /// <summary>Implemented by the controls that show elements (ribbon body, bars, popups).</summary>
  IFmrElementHost = interface
    ['{5B1E2F0A-61D4-4F1C-9C67-0C5B6E9D2A41}']
    function GetPainter: TFmrRibbonPainter;
    function GetImages: TCustomImageList;
    /// <summary>The control whose local coordinates the bounds of the elements use; parent of editor controls.
    /// </summary>
    function GetHostControl: TControl;
    procedure InvalidateElement(const AElement: TFmrElement);
    /// <summary>Opens the drop-down of AElement (menu, palette, gallery).</summary>
    procedure ElementDropDown(const AElement: TFmrElement; const AByKeyboard: Boolean);
    /// <summary>AElement ran its command (the host closes popups, leaves key tip mode...).</summary>
    procedure ElementExecuted(const AElement: TFmrElement);
    /// <summary>True while the drop-down of AElement is open (painted pressed).</summary>
    function IsElementDroppedDown(const AElement: TFmrElement): Boolean;
  end;

  /// <summary>Base of every painted, clickable part of the ribbon.</summary>
  TFmrElement = class
  private
    [Unsafe] FHost: IFmrElementHost;
    FBounds: TRectF;
    FVisible: Boolean;
    FHotPart: TFmrElementPart;
    FPressedPart: TFmrElementPart;
    FKeyTip: string;
    FFocused: Boolean;
    FTag: NativeInt;
    procedure SetFocused(const Value: Boolean);
  protected
    function Painter: TFmrRibbonPainter; inline;
    function Images: TCustomImageList; inline;
    function Metrics: TFmrThemeMetrics; inline;
    /// <summary>State of a part for painting (normal, hot, pressed, checked, disabled).</summary>
    function PartState(const APart: TFmrElementPart): TFmrPartState; virtual;
    procedure PaintFocus(const ACanvas: TCanvas); virtual;
    /// <summary>Writer of HotPart; elements with inner parts (galleries) learn here that the mouse left them.
    /// </summary>
    procedure SetHotPart(const Value: TFmrElementPart); virtual;
  public
    constructor Create(const AHost: IFmrElementHost); virtual;
    /// <summary>The mouse moved over the element (host coordinates); called by TFmrElementTracker after the hot
    /// part was set. Elements with inner parts (gallery cells, scroll buttons) track them here.</summary>
    procedure MouseMoveAt(const P: TPointF); virtual;
    procedure Invalidate;
    function IsEnabled: Boolean; virtual;
    function IsChecked: Boolean; virtual;
    /// <summary>Part under a point (local coordinates of the host); None outside.</summary>
    function PartAt(const P: TPointF): TFmrElementPart; virtual;
    /// <summary>True when pressing APart opens a drop-down at once (on mouse down, like Office).</summary>
    function OpensOnPress(const APart: TFmrElementPart): Boolean; virtual;
    /// <summary>Runs the command of APart (a click).</summary>
    procedure Execute(const APart: TFmrElementPart); virtual;
    procedure Paint(const ACanvas: TCanvas); virtual; abstract;
    function GetScreenTip(out AInfo: TFmrScreenTipInfo): Boolean; virtual;
    /// <summary>Caption a key tip is generated from.</summary>
    function KeyTipCaption: string; virtual;
    /// <summary>Key tip set by the developer (empty = generated).</summary>
    function ExplicitKeyTip: string; virtual;
    /// <summary>Center of the key tip badge (host coordinates).</summary>
    function KeyTipAnchor: TPointF; virtual;
    property Host: IFmrElementHost read FHost write FHost;
    property Bounds: TRectF read FBounds write FBounds;
    property Visible: Boolean read FVisible write FVisible;
    property HotPart: TFmrElementPart read FHotPart write SetHotPart;
    property PressedPart: TFmrElementPart read FPressedPart write FPressedPart;
    /// <summary>Key tip assigned for the current scope.</summary>
    property KeyTip: string read FKeyTip write FKeyTip;
    /// <summary>Keyboard focus (navigation with the arrow keys in key tip mode).</summary>
    property Focused: Boolean read FFocused write SetFocused;
    property Tag: NativeInt read FTag write FTag;
  end;

  TFmrElementClass = class of TFmrElement;

  /// <summary>Element of one item link.</summary>
  TFmrItemView = class(TFmrElement)
  private
    FLink: TFmrItemLink;
    FItem: TFmrBarItem;
    FPlace: TFmrViewPlace;
    FLevel: TFmrViewLevel;
    FSegment: TFmrLayoutSegment;
  protected
    function PartState(const APart: TFmrElementPart): TFmrPartState; override;
    function Caption: string; virtual;
  public
    constructor Create(const AHost: IFmrElementHost; const ALink: TFmrItemLink;
      const APlace: TFmrViewPlace); reintroduce; virtual;
    function IsEnabled: Boolean; override;
    function IsChecked: Boolean; override;
    /// <summary>Width at ALevel (Group place) or the button width (Toolbar place).</summary>
    function MeasureWidth(const ALevel: TFmrViewLevel): Single; virtual;
    /// <summary>Input of the layout calculator for this link.</summary>
    function LayoutLink: TFmrLayoutLink; virtual;
    /// <summary>Shows the view at ABounds (host coordinates).</summary>
    procedure Place(const ABounds: TRectF; const ALevel: TFmrViewLevel; const ASegment: TFmrLayoutSegment); virtual;
    /// <summary>The view is not shown (editor views hide their control).</summary>
    procedure Hide; virtual;
    /// <summary>The item changed (TFmrItemChange.Value: editors sync their control).</summary>
    procedure ItemChanged(const AChange: TFmrItemChange); virtual;
    /// <summary>Moves the view to another host (a collapsed group shown in a popup borrows the views of the
    /// group).</summary>
    procedure SetHost(const AHost: IFmrElementHost); virtual;
    /// <summary>True when the view still matches its link (same item, same view class).</summary>
    function IsValidFor(const ALink: TFmrItemLink): Boolean; virtual;
    /// <summary>Gives the keyboard focus to the view (editors focus their control); False when it cannot.</summary>
    function FocusControl: Boolean; virtual;
    function GetScreenTip(out AInfo: TFmrScreenTipInfo): Boolean; override;
    function KeyTipCaption: string; override;
    function ExplicitKeyTip: string; override;
    function KeyTipAnchor: TPointF; override;
    property Link: TFmrItemLink read FLink;
    property Item: TFmrBarItem read FItem;
    property ViewPlace: TFmrViewPlace read FPlace;
    property Level: TFmrViewLevel read FLevel;
    property Segment: TFmrLayoutSegment read FSegment;
  end;

  TFmrItemViewClass = class of TFmrItemView;

  /// <summary>View of button-like items: buttons (plain, check, drop-down, split), sub items, check items, color
  /// items, static items and galleries shown as drop-down buttons.</summary>
  TFmrButtonView = class(TFmrItemView)
  private
    FLine1, FLine2: string;
    FLinesFor: string;
    function HasArrow: Boolean;
    function IsSplit: Boolean;
    function IsWholeDropDown: Boolean;
    function IsCheckBox: Boolean;
    function IsStatic: Boolean;
    function ShowsText: Boolean;
    function Glyph(const ALarge: Boolean): TFmrImageSource;
    function HasGlyph: Boolean;
    procedure SplitCaption;
    function ArrowAreaWidth: Single;
    function MainRect: TRectF;
    function ArrowRect: TRectF;
    procedure PaintBackground(const ACanvas: TCanvas);
    procedure PaintSegmentFrame(const ACanvas: TCanvas);
    procedure PaintGlyph(const ACanvas: TCanvas; const R: TRectF; const AState: TFmrPartState);
  protected
    function PartState(const APart: TFmrElementPart): TFmrPartState; override;
  public
    function MeasureWidth(const ALevel: TFmrViewLevel): Single; override;
    function LayoutLink: TFmrLayoutLink; override;
    function PartAt(const P: TPointF): TFmrElementPart; override;
    function OpensOnPress(const APart: TFmrElementPart): Boolean; override;
    procedure Execute(const APart: TFmrElementPart); override;
    procedure Paint(const ACanvas: TCanvas); override;
    function KeyTipAnchor: TPointF; override;
  end;

  /// <summary>Separator links: drawn by the group from the layout result; a vertical line in toolbars.</summary>
  TFmrSeparatorView = class(TFmrItemView)
  public
    function MeasureWidth(const ALevel: TFmrViewLevel): Single; override;
    function LayoutLink: TFmrLayoutLink; override;
    function IsEnabled: Boolean; override;
    function PartAt(const P: TPointF): TFmrElementPart; override;
    procedure Paint(const ACanvas: TCanvas); override;
  end;

  /// <summary>Finds the element under a point of a host.</summary>
  TFmrElementFinder = reference to function(const P: TPointF): TFmrElement;

  /// <summary>Mouse protocol shared by the hosts: hot tracking, pressed state (the host control captures the mouse
  /// with AutoCapture), drop-down parts that open on mouse down. One repaint per state change of the element.
  /// </summary>
  TFmrElementTracker = class
  private
    [Unsafe] FHost: IFmrElementHost;
    FFinder: TFmrElementFinder;
    FHot: TFmrElement;
    FHotPart: TFmrElementPart;
    FPressed: TFmrElement;
    FPressedPart: TFmrElementPart;
    FSuppressUntilUp: Boolean;
    FOnHotChanged: TNotifyEvent;
    procedure SetHot(const AElement: TFmrElement; const APart: TFmrElementPart);
  public
    constructor Create(const AHost: IFmrElementHost; const AFinder: TFmrElementFinder);
    procedure MouseMove(const P: TPointF);
    /// <summary>Returns the element that was pressed (nil when none).</summary>
    function MouseDown(const AButton: TMouseButton; const P: TPointF): TFmrElement;
    procedure MouseUp(const AButton: TMouseButton; const P: TPointF);
    procedure MouseLeave;
    /// <summary>Forgets every element (the host rebuilt them).</summary>
    procedure Reset;
    /// <summary>The element is going away.</summary>
    procedure Forget(const AElement: TFmrElement);
    /// <summary>Ignores the mouse until the next button release (the click closed a popup).</summary>
    procedure SuppressUntilUp;
    property Hot: TFmrElement read FHot;
    property HotPart: TFmrElementPart read FHotPart;
    property Pressed: TFmrElement read FPressed;
    property OnHotChanged: TNotifyEvent read FOnHotChanged write FOnHotChanged;
  end;

/// <summary>Registers the view class used for items of AItemClass (and descendants without their own
/// registration).</summary>
procedure FmrRegisterItemView(const AItemClass: TFmrBarItemClass; const AViewClass: TFmrItemViewClass);
/// <summary>View class of an item (TFmrButtonView when nothing more specific is registered).</summary>
function FmrItemViewClass(const AItem: TFmrBarItem): TFmrItemViewClass;
function FmrCreateItemView(const AHost: IFmrElementHost; const ALink: TFmrItemLink;
  const APlace: TFmrViewPlace): TFmrItemView;

/// <summary>Caption without accelerator marks ('&amp;&amp;' becomes '&amp;').</summary>
function FmrStripAccel(const ACaption: string): string;
/// <summary>Latin letter or digit of the physical key that produced a key stroke, whatever the keyboard layout (key
/// tips typed with a Cyrillic layout); #0 when the key has no such letter.</summary>
function FmrLatinKeyChar(const AKey: Word; const AKeyChar: WideChar): Char;
/// <summary>TShortCut of a key and shift state.</summary>
function FmrShortCut(const AKey: Word; const AShift: TShiftState): TShortCut;
/// <summary>Text of a shortcut ("Ctrl+C").</summary>
function FmrShortCutText(const AShortCut: TShortCut): string;
/// <summary>Splits the caption of a large button into two lines (the second line holds the arrow of drop-down
/// buttons).</summary>
procedure FmrSplitLargeCaption(const APainter: TFmrRibbonPainter; const ACaption: string; const AArrowWidth: Single;
  out ALine1, ALine2: string);

implementation

uses
  {$IFDEF MSWINDOWS}Winapi.Windows, {$ENDIF}FMX.Platform, FMX.Menus, FMR.Ribbon.BiDi;

var
  GViewRegistry: TList<TPair<TFmrBarItemClass, TFmrItemViewClass>>;

procedure FmrRegisterItemView(const AItemClass: TFmrBarItemClass; const AViewClass: TFmrItemViewClass);
var
  I: Integer;
begin
  for I := 0 to GViewRegistry.Count - 1 do
    if GViewRegistry[I].Key = AItemClass then
    begin
      GViewRegistry[I] := TPair<TFmrBarItemClass, TFmrItemViewClass>.Create(AItemClass, AViewClass);
      Exit;
    end;
  GViewRegistry.Add(TPair<TFmrBarItemClass, TFmrItemViewClass>.Create(AItemClass, AViewClass));
end;

function FmrItemViewClass(const AItem: TFmrBarItem): TFmrItemViewClass;
var
  C: TClass;
  I: Integer;
begin
  Result := TFmrButtonView;
  if AItem = nil then
    Exit;
  C := AItem.ClassType;
  while (C <> nil) and C.InheritsFrom(TFmrBarItem) do
  begin
    for I := 0 to GViewRegistry.Count - 1 do
      if GViewRegistry[I].Key = C then
        Exit(GViewRegistry[I].Value);
    C := C.ClassParent;
  end;
end;

function FmrCreateItemView(const AHost: IFmrElementHost; const ALink: TFmrItemLink;
  const APlace: TFmrViewPlace): TFmrItemView;
begin
  Result := FmrItemViewClass(ALink.Item).Create(AHost, ALink, APlace);
end;

function FmrLatinKeyChar(const AKey: Word; const AKeyChar: WideChar): Char;

  function IsLatin(const ACode: Integer): Boolean;
  begin
    Result := ((ACode >= Ord('A')) and (ACode <= Ord('Z'))) or ((ACode >= Ord('0')) and (ACode <= Ord('9')));
  end;

{$IFDEF MSWINDOWS}
var
  V: SmallInt;
{$ENDIF}
begin
  if IsLatin(AKey) then
    Exit(Char(AKey));
  Result := #0;
  if AKeyChar = #0 then
    Exit;
  if IsLatin(Ord(UpCase(Char(AKeyChar)))) then
    Exit(UpCase(Char(AKeyChar)));
  {$IFDEF MSWINDOWS}
  V := VkKeyScanW(AKeyChar);
  if (V <> -1) and IsLatin(V and $FF) then
    Result := Char(V and $FF);
  {$ENDIF}
end;

function FmrStripAccel(const ACaption: string): string;
var
  I: Integer;
  SB: TStringBuilder;
begin
  if not ACaption.Contains('&') then
    Exit(ACaption);
  SB := TStringBuilder.Create;
  try
    I := 1;
    while I <= Length(ACaption) do
    begin
      if ACaption[I] = '&' then
      begin
        if (I < Length(ACaption)) and (ACaption[I + 1] = '&') then
        begin
          SB.Append('&');
          Inc(I);
        end;
      end
      else
        SB.Append(ACaption[I]);
      Inc(I);
    end;
    Result := SB.ToString;
  finally
    SB.Free;
  end;
end;

function FmrShortCut(const AKey: Word; const AShift: TShiftState): TShortCut;
begin
  Result := AKey;
  if ssShift in AShift then
    Inc(Result, scShift);
  if ssCtrl in AShift then
    Inc(Result, scCtrl);
  if ssAlt in AShift then
    Inc(Result, scAlt);
end;

function FmrShortCutText(const AShortCut: TShortCut): string;
var
  Svc: IFMXMenuService;
begin
  Result := '';
  if AShortCut = 0 then
    Exit;
  if TPlatformServices.Current.SupportsPlatformService(IFMXMenuService, Svc) then
    Result := Svc.ShortCutToText(AShortCut);
end;

procedure FmrSplitLargeCaption(const APainter: TFmrRibbonPainter; const ACaption: string; const AArrowWidth: Single;
  out ALine1, ALine2: string);
var
  Words: TArray<string>;
  I: Integer;
  Best, W: Single;
  L1, L2: string;
begin
  ALine1 := ACaption;
  ALine2 := '';
  Words := ACaption.Split([' '], TStringSplitOptions.ExcludeEmpty);
  if Length(Words) < 2 then
    Exit;
  Best := MaxSingle;
  for I := 1 to High(Words) do
  begin
    L1 := string.Join(' ', Words, 0, I);
    L2 := string.Join(' ', Words, I, Length(Words) - I);
    W := Max(APainter.TextWidth(L1), APainter.TextWidth(L2) + AArrowWidth);
    if W < Best then
    begin
      Best := W;
      ALine1 := L1;
      ALine2 := L2;
    end;
  end;
end;

{ TFmrScreenTipInfo }

function TFmrScreenTipInfo.IsEmpty: Boolean;
begin
  Result := (Header = '') and (Description = '') and (Footer = '');
end;

{ TFmrElement }

constructor TFmrElement.Create(const AHost: IFmrElementHost);
begin
  inherited Create;
  FHost := AHost;
  FVisible := True;
end;

function TFmrElement.Painter: TFmrRibbonPainter;
begin
  Result := FHost.GetPainter;
end;

function TFmrElement.Images: TCustomImageList;
begin
  Result := FHost.GetImages;
end;

function TFmrElement.Metrics: TFmrThemeMetrics;
begin
  Result := FHost.GetPainter.Theme.Metrics;
end;

procedure TFmrElement.Invalidate;
begin
  if FHost <> nil then
    FHost.InvalidateElement(Self);
end;

procedure TFmrElement.SetHotPart(const Value: TFmrElementPart);
begin
  FHotPart := Value;
end;

procedure TFmrElement.MouseMoveAt(const P: TPointF);
begin
end;

procedure TFmrElement.SetFocused(const Value: Boolean);
begin
  if FFocused <> Value then
  begin
    FFocused := Value;
    Invalidate;
  end;
end;

function TFmrElement.IsEnabled: Boolean;
begin
  Result := True;
end;

function TFmrElement.IsChecked: Boolean;
begin
  Result := False;
end;

function TFmrElement.PartAt(const P: TPointF): TFmrElementPart;
begin
  if FVisible and FBounds.Contains(P) then
    Result := TFmrElementPart.Main
  else
    Result := TFmrElementPart.None;
end;

function TFmrElement.OpensOnPress(const APart: TFmrElementPart): Boolean;
begin
  Result := False;
end;

procedure TFmrElement.Execute(const APart: TFmrElementPart);
begin
end;

function TFmrElement.PartState(const APart: TFmrElementPart): TFmrPartState;
var
  Dropped: Boolean;
begin
  if not IsEnabled then
    Exit(TFmrPartState.Disabled);
  Dropped := (FHost <> nil) and FHost.IsElementDroppedDown(Self);
  if Dropped or ((FPressedPart = APart) and (FHotPart = APart) and (APart <> TFmrElementPart.None)) then
    Result := TFmrPartState.Pressed
  else if IsChecked then
  begin
    if (FHotPart <> TFmrElementPart.None) or FFocused then
      Result := TFmrPartState.CheckedHot
    else
      Result := TFmrPartState.Checked;
  end
  else if (FHotPart = APart) and (APart <> TFmrElementPart.None) or FFocused then
    Result := TFmrPartState.Hot
  else
    Result := TFmrPartState.Normal;
end;

procedure TFmrElement.PaintFocus(const ACanvas: TCanvas);
var
  R: TRectF;
begin
  if not FFocused then
    Exit;
  R := FBounds;
  R.Inflate(-1, -1);
  Painter.Frame(ACanvas, R, TFmrToken.FocusBorder, Painter.Metrics.ButtonRadius, [], 1);
end;

function TFmrElement.GetScreenTip(out AInfo: TFmrScreenTipInfo): Boolean;
begin
  AInfo := Default(TFmrScreenTipInfo);
  Result := False;
end;

function TFmrElement.KeyTipCaption: string;
begin
  Result := '';
end;

function TFmrElement.ExplicitKeyTip: string;
begin
  Result := '';
end;

function TFmrElement.KeyTipAnchor: TPointF;
begin
  Result := PointF(FBounds.CenterPoint.X, FBounds.Bottom);
end;

{ TFmrItemView }

constructor TFmrItemView.Create(const AHost: IFmrElementHost; const ALink: TFmrItemLink; const APlace: TFmrViewPlace);
begin
  inherited Create(AHost);
  FLink := ALink;
  FItem := ALink.Item;
  FPlace := APlace;
  FLevel := TFmrViewLevel.SmallWithText;
  FVisible := False;
end;

function TFmrItemView.Caption: string;
begin
  Result := FmrStripAccel(FLink.Caption);
end;

function TFmrItemView.IsEnabled: Boolean;
begin
  Result := (FItem <> nil) and FItem.Enabled;
end;

function TFmrItemView.IsChecked: Boolean;
begin
  Result := (FItem <> nil) and FItem.IsChecked;
end;

function TFmrItemView.PartState(const APart: TFmrElementPart): TFmrPartState;
begin
  Result := inherited PartState(APart);
end;

function TFmrItemView.MeasureWidth(const ALevel: TFmrViewLevel): Single;
begin
  Result := Metrics.SmallButtonHeight;
end;

function TFmrItemView.LayoutLink: TFmrLayoutLink;
begin
  Result := TFmrLayoutLink.Button(MeasureWidth(TFmrViewLevel.Large), MeasureWidth(TFmrViewLevel.SmallWithText),
    MeasureWidth(TFmrViewLevel.Small), FLink.EffectiveViewLevels);
  Result.Hidden := not FLink.IsVisible;
  Result.BeginGroup := FLink.BeginGroup;
  Result.ButtonGroup := FLink.ButtonGroup;
  Result.SimplifiedVisibility := FLink.SimplifiedVisibility;
  if (TFmrViewLevel.Large in Result.Levels) and (TFmrViewLevel.SmallWithText in Result.Levels) then
    Result.SimplifiedWidth := Result.Widths[TFmrViewLevel.SmallWithText]
  else if TFmrViewLevel.Small in Result.Levels then
    Result.SimplifiedWidth := Result.Widths[TFmrViewLevel.Small]
  else
    Result.SimplifiedWidth := Result.Widths[TFmrViewLevel.SmallWithText];
end;

procedure TFmrItemView.Place(const ABounds: TRectF; const ALevel: TFmrViewLevel; const ASegment: TFmrLayoutSegment);
begin
  FBounds := ABounds;
  FLevel := ALevel;
  FSegment := ASegment;
  FVisible := True;
end;

procedure TFmrItemView.Hide;
begin
  FVisible := False;
  FHotPart := TFmrElementPart.None;
  FPressedPart := TFmrElementPart.None;
end;

procedure TFmrItemView.ItemChanged(const AChange: TFmrItemChange);
begin
end;

procedure TFmrItemView.SetHost(const AHost: IFmrElementHost);
begin
  FHost := AHost;
end;

function TFmrItemView.IsValidFor(const ALink: TFmrItemLink): Boolean;
begin
  Result := (ALink = FLink) and (ALink.Item = FItem) and (FmrItemViewClass(ALink.Item) = ClassType);
end;

function TFmrItemView.FocusControl: Boolean;
begin
  Result := False;
end;

function TFmrItemView.GetScreenTip(out AInfo: TFmrScreenTipInfo): Boolean;
var
  Tip: TFmrScreenTip;
begin
  AInfo := Default(TFmrScreenTipInfo);
  Result := False;
  if FItem = nil then
    Exit;
  Tip := FItem.ScreenTip;
  if Tip.Header <> '' then
    AInfo.Header := Tip.Header
  else
    AInfo.Header := Caption;
  AInfo.Description := Tip.Description;
  if AInfo.Description = '' then
    AInfo.Description := FItem.Hint;
  if AInfo.Description = '' then
    AInfo.Description := FItem.Description;
  if Tip.ShowShortcut then
    AInfo.Shortcut := FmrShortCutText(FItem.ShortCut);
  AInfo.Footer := Tip.Footer;
  AInfo.ShowFooter := Tip.ShowFooter or (Tip.Footer <> '');
  if not Tip.Image.IsEmpty(Images) then
  begin
    AInfo.Image := Tip.Image;
    AInfo.Images := Images;
  end;
  AInfo.Width := Tip.Width;
  AInfo.Disabled := not FItem.Enabled;
  // A tip is worth showing when it says more than the visible caption.
  Result := (AInfo.Description <> '') or (AInfo.Shortcut <> '') or (Tip.Header <> '') or Tip.ShowFooter or
    (FLevel = TFmrViewLevel.Small) or (FPlace = TFmrViewPlace.Toolbar);
end;

function TFmrItemView.KeyTipCaption: string;
begin
  Result := FLink.Caption;
end;

function TFmrItemView.ExplicitKeyTip: string;
begin
  Result := FLink.EffectiveKeyTip;
end;

function TFmrItemView.KeyTipAnchor: TPointF;
begin
  if (FPlace = TFmrViewPlace.Group) and (FLevel <> TFmrViewLevel.Large) then
    Result := PointF(FBounds.Left + 9, FBounds.Bottom - 2)
  else
    Result := PointF(FBounds.CenterPoint.X, FBounds.Bottom - 2);
end;

{ TFmrButtonView }

function TFmrButtonView.IsSplit: Boolean;
begin
  Result := (Item is TFmrButtonItem) and (TFmrButtonItem(Item).ButtonStyle = TFmrButtonStyle.Split);
end;

function TFmrButtonView.IsWholeDropDown: Boolean;
begin
  Result := ((Item is TFmrButtonItem) and (TFmrButtonItem(Item).ButtonStyle = TFmrButtonStyle.DropDown)) or
    (Item is TFmrSubItem) or (Item is TFmrGalleryItem);
end;

function TFmrButtonView.HasArrow: Boolean;
begin
  Result := IsSplit or IsWholeDropDown;
end;

function TFmrButtonView.IsCheckBox: Boolean;
begin
  Result := Item is TFmrCheckItem;
end;

function TFmrButtonView.IsStatic: Boolean;
begin
  Result := Item is TFmrStaticItem;
end;

function TFmrButtonView.ShowsText: Boolean;
begin
  case ViewPlace of
    TFmrViewPlace.Toolbar:
      Result := not HasGlyph and not IsCheckBox;
  else
    Result := (Level <> TFmrViewLevel.Small) or (not HasGlyph and not IsCheckBox);
  end;
end;

function TFmrButtonView.Glyph(const ALarge: Boolean): TFmrImageSource;
begin
  Result := nil;
  if Item = nil then
    Exit;
  if ALarge then
  begin
    if not Item.LargeGlyph.IsEmpty(Images) then
      Result := Item.LargeGlyph
    else if not Item.Glyph.IsEmpty(Images) then
      Result := Item.Glyph;
  end
  else
  begin
    if not Item.Glyph.IsEmpty(Images) then
      Result := Item.Glyph
    else if not Item.LargeGlyph.IsEmpty(Images) then
      Result := Item.LargeGlyph;
  end;
end;

function TFmrButtonView.HasGlyph: Boolean;
begin
  Result := Glyph(False) <> nil;
end;

function TFmrButtonView.ArrowAreaWidth: Single;
begin
  if IsSplit then
    Result := 14
  else if HasArrow then
    Result := 11
  else
    Result := 0;
end;

procedure TFmrButtonView.SplitCaption;
var
  C: string;
begin
  C := Caption;
  if C = FLinesFor then
    Exit;
  FLinesFor := C;
  if HasArrow then
    FmrSplitLargeCaption(Painter, C, Metrics.ArrowSize + 4, FLine1, FLine2)
  else
    FmrSplitLargeCaption(Painter, C, 0, FLine1, FLine2);
end;

function TFmrButtonView.MeasureWidth(const ALevel: TFmrViewLevel): Single;
var
  M: TFmrThemeMetrics;
  Pad, TextW: Single;
begin
  M := Metrics;
  Pad := M.ButtonPaddingH;
  if IsStatic then
  begin
    if TFmrStaticItem(Item).Width > 0 then
      Exit(TFmrStaticItem(Item).Width);
    Exit(Painter.TextWidth(Caption) + 2 * Pad);
  end;
  if ViewPlace = TFmrViewPlace.Toolbar then
  begin
    if ShowsText then
      Result := Painter.TextWidth(Caption) + 2 * Pad
    else
      Result := M.QATButtonSize;
    if HasArrow then
      Result := Result + 10;
    Exit;
  end;
  case ALevel of
    TFmrViewLevel.Large:
      begin
        FLinesFor := #0;
        SplitCaption;
        TextW := Painter.TextWidth(FLine1);
        if HasArrow then
          TextW := Max(TextW, Painter.TextWidth(FLine2) + IfThen(FLine2 <> '', 4, 0) + M.ArrowSize)
        else
          TextW := Max(TextW, Painter.TextWidth(FLine2));
        Result := Max(M.LargeButtonMinWidth, Max(M.LargeGlyphSize + 2 * Pad + 4, TextW + 2 * Pad + 4));
      end;
    TFmrViewLevel.SmallWithText:
      begin
        Result := Pad;
        if IsCheckBox then
          Result := Result + 13 + 5
        else if HasGlyph then
          Result := Result + M.SmallGlyphSize + 4;
        Result := Result + Painter.TextWidth(Caption) + Pad;
        Result := Result + ArrowAreaWidth;
      end;
  else
    begin
      if IsCheckBox then
        Result := 13 + 2 * Pad
      else if HasGlyph then
        Result := M.SmallGlyphSize + 2 * Pad + 2
      else
        Result := Painter.TextWidth(Caption) + 2 * Pad;
      Result := Result + ArrowAreaWidth;
    end;
  end;
  Result := Ceil(Result);
end;

function TFmrButtonView.LayoutLink: TFmrLayoutLink;
begin
  Result := inherited LayoutLink;
  if IsStatic then
    Result.Levels := [TFmrViewLevel.SmallWithText];
end;

function TFmrButtonView.MainRect: TRectF;
begin
  Result := Bounds;
  if not IsSplit then
    Exit;
  if (ViewPlace = TFmrViewPlace.Group) and (Level = TFmrViewLevel.Large) then
    Result.Bottom := Result.Top + 3 + Metrics.LargeGlyphSize + 3
  else
    Result.Right := Result.Right - ArrowAreaWidth;
end;

function TFmrButtonView.ArrowRect: TRectF;
var
  M: TRectF;
begin
  Result := Bounds;
  if not IsSplit then
    Exit;
  M := MainRect;
  if (ViewPlace = TFmrViewPlace.Group) and (Level = TFmrViewLevel.Large) then
    Result.Top := M.Bottom
  else
    Result.Left := M.Right;
end;

function TFmrButtonView.PartAt(const P: TPointF): TFmrElementPart;
begin
  if not Visible or not Bounds.Contains(P) then
    Exit(TFmrElementPart.None);
  if IsSplit and ArrowRect.Contains(P) then
    Result := TFmrElementPart.DropDown
  else if IsWholeDropDown then
    Result := TFmrElementPart.DropDown
  else
    Result := TFmrElementPart.Main;
end;

function TFmrButtonView.OpensOnPress(const APart: TFmrElementPart): Boolean;
begin
  Result := APart = TFmrElementPart.DropDown;
end;

procedure TFmrButtonView.Execute(const APart: TFmrElementPart);
var
  LItem: TFmrBarItem;
begin
  if not IsEnabled or IsStatic then
    Exit;
  if APart = TFmrElementPart.DropDown then
  begin
    Host.ElementDropDown(Self, False);
    Exit;
  end;
  LItem := Item;
  Host.ElementExecuted(Self);
  LItem.Click;
end;

function TFmrButtonView.PartState(const APart: TFmrElementPart): TFmrPartState;
begin
  if IsStatic then
  begin
    if IsEnabled then
      Result := TFmrPartState.Normal
    else
      Result := TFmrPartState.Disabled;
    Exit;
  end;
  Result := inherited PartState(APart);
  // The split part that is not under the mouse is drawn normal; the dropped-down part pressed.
  if IsSplit and (Result in [TFmrPartState.Hot, TFmrPartState.Pressed]) then
  begin
    if Host.IsElementDroppedDown(Self) then
    begin
      if APart = TFmrElementPart.Main then
        Result := TFmrPartState.Hot;
    end
    else if (HotPart <> APart) and not Focused then
      Result := TFmrPartState.Normal;
  end;
end;

procedure TFmrButtonView.PaintSegmentFrame(const ACanvas: TCanvas);
var
  Corners: TCorners;
  Rad: Single;
  R: TRectF;
begin
  if Segment = TFmrLayoutSegment.None then
    Exit;
  Rad := Metrics.ButtonRadius;
  case Segment of
    TFmrLayoutSegment.First: Corners := [TCorner.TopLeft, TCorner.BottomLeft];
    TFmrLayoutSegment.Last: Corners := [TCorner.TopRight, TCorner.BottomRight];
    TFmrLayoutSegment.Middle: Corners := [];
  else
    Corners := AllCorners;
  end;
  R := Bounds;
  if Corners = [] then
  begin
    Painter.Fill(ACanvas, R, TFmrToken.ButtonGroupFill);
    Painter.Line(ACanvas, PointF(R.Left, R.Top + 0.5), PointF(R.Right, R.Top + 0.5),
      Painter.Theme.Colors[TFmrToken.ButtonGroupBorder]);
    Painter.Line(ACanvas, PointF(R.Left, R.Bottom - 0.5), PointF(R.Right, R.Bottom - 0.5),
      Painter.Theme.Colors[TFmrToken.ButtonGroupBorder]);
  end
  else
  begin
    Painter.Fill(ACanvas, R, TFmrToken.ButtonGroupFill, Rad, Corners);
    if Segment = TFmrLayoutSegment.First then
      R.Right := R.Right + 1
    else if Segment = TFmrLayoutSegment.Last then
      R.Left := R.Left - 1;
    Painter.Frame(ACanvas, R, TFmrToken.ButtonGroupBorder, Rad, Corners);
  end;
  if Segment in [TFmrLayoutSegment.Middle, TFmrLayoutSegment.Last] then
    Painter.Line(ACanvas, PointF(Round(Bounds.Left) + 0.5, Bounds.Top + 3), PointF(Round(Bounds.Left) + 0.5,
      Bounds.Bottom - 3), Painter.Theme.Colors[TFmrToken.ButtonGroupBorder]);
end;

procedure TFmrButtonView.PaintBackground(const ACanvas: TCanvas);
var
  MainState, ArrowState, S: TFmrPartState;
  Corners: TCorners;
  F, B: TFmrToken;
  Rad: Single;
begin
  if IsStatic or IsCheckBox then
  begin
    // Check items show the hot state over the whole row, like buttons.
    if IsCheckBox then
    begin
      S := PartState(TFmrElementPart.Main);
      if S in [TFmrPartState.Hot, TFmrPartState.Pressed] then
        Painter.DrawButton(ACanvas, Bounds, S);
    end;
    Exit;
  end;
  PaintSegmentFrame(ACanvas);
  if IsSplit then
  begin
    MainState := PartState(TFmrElementPart.Main);
    ArrowState := PartState(TFmrElementPart.DropDown);
    Painter.DrawSplitButton(ACanvas, Bounds, MainRect, ArrowRect, MainState, ArrowState,
      (ViewPlace = TFmrViewPlace.Group) and (Level = TFmrViewLevel.Large));
    Exit;
  end;
  if IsWholeDropDown then
    S := PartState(TFmrElementPart.DropDown)
  else
    S := PartState(TFmrElementPart.Main);
  if S in [TFmrPartState.Normal, TFmrPartState.Disabled] then
    Exit;
  case Segment of
    TFmrLayoutSegment.First: Corners := [TCorner.TopLeft, TCorner.BottomLeft];
    TFmrLayoutSegment.Last: Corners := [TCorner.TopRight, TCorner.BottomRight];
    TFmrLayoutSegment.Middle:
      begin
        // No rounded corner at all: painted directly.
        F := Painter.ButtonFillToken(S, B);
        Painter.Fill(ACanvas, Bounds, F);
        Painter.Frame(ACanvas, Bounds, B);
        Exit;
      end;
  else
    Corners := [];
  end;
  Rad := Metrics.ButtonRadius;
  if Rad >= 0 then
    Painter.DrawButton(ACanvas, Bounds, S, Corners);
end;

procedure TFmrButtonView.PaintGlyph(const ACanvas: TCanvas; const R: TRectF; const AState: TFmrPartState);
var
  G: TFmrImageSource;
  Opacity: Single;
  Bar: TRectF;
begin
  G := Glyph(R.Width > Metrics.SmallGlyphSize + 1);
  if G = nil then
    Exit;
  if AState = TFmrPartState.Disabled then
    Opacity := 0.45
  else
    Opacity := 1;
  if (G.EffectiveKind in [TFmrImageKind.Glyph, TFmrImageKind.Path]) or G.Recolor then
    Opacity := 1;
  FmrDrawImage(ACanvas, G, R, Opacity, Painter.GlyphTint(AState), Images);
  if Item is TFmrColorItem then
  begin
    Bar := RectF(R.Left, R.Bottom - R.Height * 0.2, R.Right, R.Bottom + 1);
    if TFmrColorItem(Item).Color = TAlphaColors.Null then
      Painter.DrawColorBar(ACanvas, Bar, TFmrColorItem(Item).AutomaticColor)
    else
      Painter.DrawColorBar(ACanvas, Bar, TFmrColorItem(Item).Color);
  end;
end;

procedure TFmrButtonView.Paint(const ACanvas: TCanvas);
var
  M: TFmrThemeMetrics;
  S: TFmrPartState;
  R, GlyphR, TextR, CheckR: TRectF;
  TextColor, ArrowColor: TAlphaColor;
  Pad, X, LineH, Y, W2: Single;
  Align: TTextAlign;
begin
  if not Visible then
    Exit;
  M := Metrics;
  Pad := M.ButtonPaddingH;
  PaintBackground(ACanvas);
  if IsWholeDropDown then
    S := PartState(TFmrElementPart.DropDown)
  else
    S := PartState(TFmrElementPart.Main);
  if (S = TFmrPartState.Disabled) then
    TextColor := Painter.ButtonTextColor(S)
  else
    TextColor := Painter.ButtonTextColor(TFmrPartState.Normal);
  if S = TFmrPartState.Disabled then
    ArrowColor := Painter.Theme.Colors[TFmrToken.ButtonTextDisabled]
  else
    ArrowColor := Painter.Theme.Colors[TFmrToken.ButtonArrow];
  R := Bounds;

  if IsStatic then
  begin
    Align := TFmrStaticItem(Item).Alignment;
    Painter.TextEx(ACanvas, RectF(R.Left + Pad, R.Top, R.Right - Pad, R.Bottom), Caption, TextColor, Align,
      TTextAlign.Center, 0, False, False);
    Exit;
  end;

  if (ViewPlace = TFmrViewPlace.Group) and (Level = TFmrViewLevel.Large) then
  begin
    GlyphR := RectF(0, 0, M.LargeGlyphSize, M.LargeGlyphSize);
    GlyphR.Offset(Round(R.CenterPoint.X - M.LargeGlyphSize / 2), R.Top + 2);
    PaintGlyph(ACanvas, GlyphR, S);
    SplitCaption;
    // Two caption lines must fit below the glyph inside the content height.
    LineH := Min(Ceil(Painter.TextSize('Wg').Height), Floor((R.Height - M.LargeGlyphSize - 4) / 2));
    Y := GlyphR.Bottom + 2;
    Painter.TextEx(ACanvas, RectF(R.Left + 2, Y, R.Right - 2, Y + LineH), FLine1, TextColor, TTextAlign.Center,
      TTextAlign.Center, 0, False, False);
    Y := Y + LineH;
    if HasArrow then
    begin
      if FLine2 <> '' then
      begin
        W2 := Painter.TextWidth(FLine2) + 4 + M.ArrowSize;
        X := R.CenterPoint.X - W2 / 2;
        Painter.Text(ACanvas, RectF(X, Y, X + W2 - M.ArrowSize - 4, Y + LineH), FLine2, TextColor,
          TTextAlign.Leading, TTextAlign.Center);
        Painter.Arrow(ACanvas, PointF(X + W2 - M.ArrowSize / 2, Y + LineH / 2 + 1), TFmrArrowDirection.Down,
          ArrowColor);
      end
      else
        Painter.Arrow(ACanvas, PointF(R.CenterPoint.X, Y + LineH / 2 + 1), TFmrArrowDirection.Down, ArrowColor);
    end
    else if FLine2 <> '' then
      Painter.TextEx(ACanvas, RectF(R.Left + 2, Y, R.Right - 2, Y + LineH), FLine2, TextColor, TTextAlign.Center,
        TTextAlign.Center, 0, False, False);
  end
  else
  begin
    X := R.Left + Pad;
    if ViewPlace = TFmrViewPlace.Toolbar then
    begin
      if not ShowsText then
      begin
        GlyphR := RectF(0, 0, M.SmallGlyphSize, M.SmallGlyphSize);
        if HasArrow then
          GlyphR.Offset(Round(R.Left + (R.Width - 10 - M.SmallGlyphSize) / 2),
            Round(R.CenterPoint.Y - M.SmallGlyphSize / 2))
        else
          GlyphR.Offset(Round(R.CenterPoint.X - M.SmallGlyphSize / 2), Round(R.CenterPoint.Y - M.SmallGlyphSize / 2));
        PaintGlyph(ACanvas, GlyphR, S);
        X := GlyphR.Right;
      end;
    end
    else if IsCheckBox then
    begin
      CheckR := RectF(X, R.Top, X + 13, R.Bottom);
      Painter.DrawCheckBox(ACanvas, CheckR, IsChecked, TFmrCheckItem(Item).GroupIndex <> 0, S);
      X := CheckR.Right + 5;
    end
    else if HasGlyph then
    begin
      GlyphR := RectF(0, 0, M.SmallGlyphSize, M.SmallGlyphSize);
      GlyphR.Offset(Round(X), Round(R.CenterPoint.Y - M.SmallGlyphSize / 2));
      PaintGlyph(ACanvas, GlyphR, S);
      X := GlyphR.Right + 4;
    end;
    if ShowsText then
    begin
      TextR := RectF(X, R.Top, R.Right - ArrowAreaWidth - Pad + 2, R.Bottom);
      if ViewPlace = TFmrViewPlace.Toolbar then
        TextR.Right := R.Right - Pad;
      Painter.TextEx(ACanvas, TextR, Caption, TextColor, TTextAlign.Leading, TTextAlign.Center, 0, False, False);
    end;
    if HasArrow then
    begin
      if IsSplit then
        Painter.Arrow(ACanvas, PointF(ArrowRect.CenterPoint.X, R.CenterPoint.Y + 0.5), TFmrArrowDirection.Down,
          ArrowColor)
      else
        Painter.Arrow(ACanvas, PointF(R.Right - Pad - M.ArrowSize / 2, R.CenterPoint.Y + 0.5),
          TFmrArrowDirection.Down, ArrowColor);
    end;
  end;
  PaintFocus(ACanvas);
end;

function TFmrButtonView.KeyTipAnchor: TPointF;
begin
  Result := inherited KeyTipAnchor;
end;

{ TFmrSeparatorView }

function TFmrSeparatorView.MeasureWidth(const ALevel: TFmrViewLevel): Single;
begin
  Result := 7;
end;

function TFmrSeparatorView.LayoutLink: TFmrLayoutLink;
begin
  Result := TFmrLayoutLink.Separator;
  Result.Hidden := not Link.IsVisible;
  Result.SimplifiedVisibility := TFmrSimplifiedVisibility.Never;
end;

function TFmrSeparatorView.IsEnabled: Boolean;
begin
  Result := False;
end;

function TFmrSeparatorView.PartAt(const P: TPointF): TFmrElementPart;
begin
  Result := TFmrElementPart.None;
end;

procedure TFmrSeparatorView.Paint(const ACanvas: TCanvas);
begin
  if Visible and (ViewPlace = TFmrViewPlace.Toolbar) then
    Painter.DrawSeparator(ACanvas, RectF(Bounds.Left, Bounds.Top + 4, Bounds.Right, Bounds.Bottom - 4), True);
end;

{ TFmrElementTracker }

constructor TFmrElementTracker.Create(const AHost: IFmrElementHost; const AFinder: TFmrElementFinder);
begin
  inherited Create;
  FHost := AHost;
  FFinder := AFinder;
end;

procedure TFmrElementTracker.SetHot(const AElement: TFmrElement; const APart: TFmrElementPart);
var
  Old: TFmrElement;
  Changed: Boolean;
begin
  if (AElement = FHot) and (APart = FHotPart) then
    Exit;
  Old := FHot;
  Changed := AElement <> FHot;
  // A part change of the same element is one change (elements learn in SetHotPart when the mouse leaves them).
  if (Old <> nil) and (Old <> AElement) then
  begin
    Old.HotPart := TFmrElementPart.None;
    Old.Invalidate;
  end;
  FHot := AElement;
  FHotPart := APart;
  if FHot <> nil then
  begin
    FHot.HotPart := APart;
    FHot.Invalidate;
  end;
  if Changed and Assigned(FOnHotChanged) then
    FOnHotChanged(Self);
end;

procedure TFmrElementTracker.MouseMove(const P: TPointF);
var
  E: TFmrElement;
  Part: TFmrElementPart;
begin
  E := FFinder(P);
  if E <> nil then
    Part := E.PartAt(P)
  else
    Part := TFmrElementPart.None;
  if (E <> nil) and ((Part = TFmrElementPart.None) or not E.IsEnabled) then
  begin
    if Part = TFmrElementPart.None then
      E := nil
    else
      Part := TFmrElementPart.Main;
  end;
  // While a button is held, only the pressed element can be hot.
  if (FPressed <> nil) and (E <> FPressed) then
  begin
    E := nil;
    Part := TFmrElementPart.None;
  end;
  SetHot(E, Part);
  if E <> nil then
    E.MouseMoveAt(P);
end;

function TFmrElementTracker.MouseDown(const AButton: TMouseButton; const P: TPointF): TFmrElement;
var
  E: TFmrElement;
  Part: TFmrElementPart;
begin
  Result := nil;
  if FSuppressUntilUp or (AButton <> TMouseButton.mbLeft) then
    Exit;
  E := FFinder(P);
  if E = nil then
    Exit;
  Part := E.PartAt(P);
  if (Part = TFmrElementPart.None) or not E.IsEnabled then
    Exit;
  Result := E;
  SetHot(E, Part);
  E.MouseMoveAt(P);
  if E.OpensOnPress(Part) then
  begin
    FHost.ElementDropDown(E, False);
    Exit;
  end;
  FPressed := E;
  FPressedPart := Part;
  E.PressedPart := Part;
  E.Invalidate;
end;

procedure TFmrElementTracker.MouseUp(const AButton: TMouseButton; const P: TPointF);
var
  E: TFmrElement;
  Part: TFmrElementPart;
begin
  if AButton <> TMouseButton.mbLeft then
    Exit;
  if FSuppressUntilUp then
  begin
    FSuppressUntilUp := False;
    Exit;
  end;
  E := FPressed;
  Part := FPressedPart;
  FPressed := nil;
  FPressedPart := TFmrElementPart.None;
  if E = nil then
    Exit;
  E.PressedPart := TFmrElementPart.None;
  E.Invalidate;
  if (E.PartAt(P) = Part) and E.IsEnabled then
    E.Execute(Part);
end;

procedure TFmrElementTracker.MouseLeave;
begin
  if FPressed = nil then
    SetHot(nil, TFmrElementPart.None);
end;

procedure TFmrElementTracker.Reset;
begin
  FHot := nil;
  FHotPart := TFmrElementPart.None;
  FPressed := nil;
  FPressedPart := TFmrElementPart.None;
end;

procedure TFmrElementTracker.Forget(const AElement: TFmrElement);
begin
  if FHot = AElement then
  begin
    FHot := nil;
    FHotPart := TFmrElementPart.None;
  end;
  if FPressed = AElement then
  begin
    FPressed := nil;
    FPressedPart := TFmrElementPart.None;
  end;
end;

procedure TFmrElementTracker.SuppressUntilUp;
begin
  FSuppressUntilUp := True;
  if FPressed <> nil then
  begin
    FPressed.PressedPart := TFmrElementPart.None;
    FPressed.Invalidate;
    FPressed := nil;
  end;
end;

initialization
  GViewRegistry := TList<TPair<TFmrBarItemClass, TFmrItemViewClass>>.Create;
  FmrRegisterItemView(TFmrBarItem, TFmrButtonView);
  FmrRegisterItemView(TFmrSeparatorItem, TFmrSeparatorView);

finalization
  FreeAndNil(GViewRegistry);

end.
