{*******************************************************}
{                                                       }
{  FMR Ribbon for FireMonkey                            }
{  Design time: IDE editors (needs designide)           }
{                                                       }
{  MIT License. Copyright (c) 2026 Fasday               }
{                                                       }
{*******************************************************}

unit FMR.Ribbon.Design.Editors;

/// The IDE part of the design package: the designer bridge around DesignIntf.IDesigner, the design notifier that
/// feeds TFmrDesignHub and synchronizes the ribbons with the selection, property editors (theme name, accent color,
/// image source and its glyph code / font / SVG / path, link item, category, key tip, frame mode), component editors
/// (bar manager, ribbon, tab, group, context group, items, backstage view, status bar) and selection editors that
/// add the units needed by event handlers. Registered by FMR.Ribbon.Reg.

interface

uses
  System.SysUtils, System.Classes, System.Types, System.UITypes, System.TypInfo, System.Generics.Collections,
  FMX.Types, DesignIntf, DesignEditors, DesignMenus, VCLEditors, Vcl.Graphics, FMR.Ribbon.Design.Bridge;

type
  /// <summary>IFmrDesignBridge around an IDE designer.</summary>
  TFmrIdeBridge = class(TInterfacedObject, IFmrDesignBridge)
  private
    FDesigner: IDesigner;
  public
    constructor Create(const ADesigner: IDesigner);
    function Root: TComponent;
    function UniqueName(const ABaseName: string): string;
    function CreateComponent(const AClass: TComponentClass; const AParent: FMX.Types.TFmxObject): TComponent;
    procedure Modified;
    procedure SelectObjects(const AObjects: TArray<TPersistent>);
    function SelectedObjects: TArray<TPersistent>;
    procedure ShowEvent(const AInstance: TPersistent; const AEventName: string);
    property Designer: IDesigner read FDesigner;
  end;

  { property editors }

  /// <summary>Theme of a ribbon, backstage view, status bar or popup menu: list of the registered themes.
  /// </summary>
  TFmrThemeNameProperty = class(TStringProperty)
  public
    function GetAttributes: TPropertyAttributes; override;
    procedure GetValues(Proc: TGetStrProc); override;
  end;

  /// <summary>Accent color: names of the accent constants (FmrAccentBlue...), '#AARRGGBB', a color dialog and swatches.</summary>
  TFmrAccentColorProperty = class(TOrdinalProperty, ICustomPropertyDrawing, ICustomPropertyDrawing80,
    ICustomPropertyListDrawing)
  public
    function GetAttributes: TPropertyAttributes; override;
    function GetValue: string; override;
    procedure SetValue(const Value: string); override;
    procedure GetValues(Proc: TGetStrProc); override;
    procedure Edit; override;
    { ICustomPropertyDrawing }
    procedure PropDrawName(ACanvas: TCanvas; const ARect: TRect; ASelected: Boolean);
    procedure PropDrawValue(ACanvas: TCanvas; const ARect: TRect; ASelected: Boolean);
    { ICustomPropertyDrawing80 }
    function PropDrawNameRect(const ARect: TRect): TRect;
    function PropDrawValueRect(const ARect: TRect): TRect;
    { ICustomPropertyListDrawing }
    procedure ListMeasureWidth(const Value: string; ACanvas: TCanvas; var AWidth: Integer);
    procedure ListMeasureHeight(const Value: string; ACanvas: TCanvas; var AHeight: Integer);
    procedure ListDrawValue(const Value: string; ACanvas: TCanvas; const ARect: TRect; ASelected: Boolean);
  end;

  /// <summary>TFmrImageSource: summary text, sub-properties and the image dialog.</summary>
  TFmrImageSourceProperty = class(TClassProperty)
  public
    function GetAttributes: TPropertyAttributes; override;
    function GetValue: string; override;
    procedure Edit; override;
  end;

  /// <summary>TFmrImageSource.GlyphCode: hexadecimal with the glyph name; the dialog opens on the icon font page.
  /// </summary>
  TFmrGlyphCodeProperty = class(TOrdinalProperty)
  public
    function GetAttributes: TPropertyAttributes; override;
    function GetValue: string; override;
    procedure SetValue(const Value: string); override;
    procedure Edit; override;
  end;

  /// <summary>TFmrImageSource.GlyphFontFamily: installed icon fonts.</summary>
  TFmrGlyphFontProperty = class(TStringProperty)
  public
    function GetAttributes: TPropertyAttributes; override;
    procedure GetValues(Proc: TGetStrProc); override;
  end;

  /// <summary>TFmrImageSource.SvgSource / PathData: short summary, the dialog on the SVG / path page.</summary>
  TFmrImageTextProperty = class(TStringProperty)
  public
    function GetAttributes: TPropertyAttributes; override;
    function GetValue: string; override;
    procedure Edit; override;
  end;

  /// <summary>TFmrItemLink.Item: the items of the bar manager of the link's owner.</summary>
  TFmrLinkItemProperty = class(TComponentProperty)
  public
    procedure GetValues(Proc: TGetStrProc); override;
  end;

  /// <summary>TFmrBarItem.Category: the categories of the bar manager (a new name is added to them).</summary>
  TFmrCategoryProperty = class(TStringProperty)
  public
    function GetAttributes: TPropertyAttributes; override;
    procedure GetValues(Proc: TGetStrProc); override;
    procedure SetValue(const Value: string); override;
  end;

  /// <summary>Key tips: 1 to 3 letters or digits, upper case.</summary>
  TFmrKeyTipProperty = class(TStringProperty)
  public
    procedure SetValue(const Value: string); override;
  end;

  /// <summary>TFmrFormFrame.Mode: the values and a dialog that explains them.</summary>
  TFmrFrameModeProperty = class(TEnumProperty)
  public
    function GetAttributes: TPropertyAttributes; override;
    procedure Edit; override;
  end;

  { component editors }

  /// <summary>Base of the component editors: the designer bridge and the theme submenu.</summary>
  TFmrComponentEditor = class(TDefaultEditor)
  protected
    function Bridge: IFmrDesignBridge;
    procedure AddThemeItems(const AItem: IMenuItem);
    procedure ThemeItemClick(Sender: TObject);
  end;

  TFmrBarManagerEditor = class(TFmrComponentEditor)
  private
    procedure NewItemClick(Sender: TObject);
  public
    procedure Edit; override;
    procedure ExecuteVerb(Index: Integer); override;
    function GetVerb(Index: Integer): string; override;
    function GetVerbCount: Integer; override;
    procedure PrepareItem(Index: Integer; const AItem: IMenuItem); override;
  end;

  TFmrRibbonEditor = class(TFmrComponentEditor)
  public
    procedure Edit; override;
    procedure ExecuteVerb(Index: Integer); override;
    function GetVerb(Index: Integer): string; override;
    function GetVerbCount: Integer; override;
    procedure PrepareItem(Index: Integer; const AItem: IMenuItem); override;
  end;

  TFmrRibbonTabEditor = class(TFmrComponentEditor)
  public
    procedure Edit; override;
    procedure ExecuteVerb(Index: Integer); override;
    function GetVerb(Index: Integer): string; override;
    function GetVerbCount: Integer; override;
  end;

  TFmrRibbonGroupEditor = class(TFmrComponentEditor)
  private
    procedure NewItemClick(Sender: TObject);
  public
    procedure Edit; override;
    procedure ExecuteVerb(Index: Integer); override;
    function GetVerb(Index: Integer): string; override;
    function GetVerbCount: Integer; override;
    procedure PrepareItem(Index: Integer; const AItem: IMenuItem); override;
  end;

  TFmrContextGroupEditor = class(TFmrComponentEditor)
  public
    procedure ExecuteVerb(Index: Integer); override;
    function GetVerb(Index: Integer): string; override;
    function GetVerbCount: Integer; override;
  end;

  /// <summary>Bar items: double click opens OnClick; quick access toolbar, items editor.</summary>
  TFmrBarItemEditor = class(TFmrComponentEditor)
  public
    procedure ExecuteVerb(Index: Integer); override;
    function GetVerb(Index: Integer): string; override;
    function GetVerbCount: Integer; override;
  end;

  TFmrBackstageViewEditor = class(TFmrComponentEditor)
  public
    procedure ExecuteVerb(Index: Integer); override;
    function GetVerb(Index: Integer): string; override;
    function GetVerbCount: Integer; override;
    procedure PrepareItem(Index: Integer; const AItem: IMenuItem); override;
  end;

  TFmrStatusBarEditor = class(TFmrComponentEditor)
  public
    procedure ExecuteVerb(Index: Integer); override;
    function GetVerb(Index: Integer): string; override;
    function GetVerbCount: Integer; override;
    procedure PrepareItem(Index: Integer; const AItem: IMenuItem); override;
  end;

  { selection editors: units needed by the event handlers of the components }

  TFmrRibbonSelectionEditor = class(TSelectionEditor)
  public
    procedure RequiresUnits(Proc: TGetStrProc); override;
  end;

  TFmrBarsSelectionEditor = class(TSelectionEditor)
  public
    procedure RequiresUnits(Proc: TGetStrProc); override;
  end;

/// <summary>Registers the property, component and selection editors and the design notifier.</summary>
procedure FmrRegisterDesignEditors;
/// <summary>The bridge of the designer of AComponent's root (nil when not designed).</summary>
function FmrIdeBridgeFor(const AComponent: TComponent): IFmrDesignBridge;

implementation

uses
  // FMX first: the VCL names declared later win (TForm, TCustomForm...); FMX names are qualified.
  Winapi.Windows, System.Character, FMX.Forms, FMX.ImgList, FMR.Ribbon.Types, FMR.Bars, FMR.Bars.Images, FMR.Bars.Items,
  FMR.Ribbon.Structure, FMR.Ribbon.Theme, FMR.Frame.Types, FMR.Frame, FMR.Ribbon, FMR.Ribbon.Popup,
  FMR.Ribbon.Backstage, FMR.Ribbon.StatusBar, FMR.Ribbon.Design.Graphics, FMR.Ribbon.Design.ImageDialog,
  FMR.Ribbon.Design.ItemsEditor, FMR.Ribbon.Design.StructureEditor, FMR.Ribbon.Design.Templates,
  FMR.Ribbon.Design.Interactive, ToolsAPI, Vcl.Forms, Vcl.Controls, Vcl.Dialogs, Vcl.StdCtrls, Vcl.ExtCtrls,
  Vcl.Menus;

type
  TFmrImageSourceAccess = class(TFmrImageSource);

type
  /// <summary>Feeds TFmrDesignHub from the IDE and keeps the designers of the roots.</summary>
  TFmrDesignNotifier = class(TInterfacedObject, IDesignNotification)
  private
    FDesigners: TDictionary<TComponent, IDesigner>;
  public
    constructor Create;
    destructor Destroy; override;
    function DesignerOf(const ARoot: TComponent): IDesigner;
    procedure ItemDeleted(const ADesigner: IDesigner; AItem: TPersistent);
    procedure ItemInserted(const ADesigner: IDesigner; AItem: TPersistent);
    procedure ItemsModified(const ADesigner: IDesigner);
    procedure SelectionChanged(const ADesigner: IDesigner; const ASelection: IDesignerSelections);
    procedure DesignerOpened(const ADesigner: IDesigner; AResurrecting: Boolean);
    procedure DesignerClosed(const ADesigner: IDesigner; AGoingDormant: Boolean);
  end;

var
  GNotifier: TFmrDesignNotifier;
  GNotifierIntf: IDesignNotification;

{ helpers }

function RootOf(const ADesigner: IDesigner): TComponent;
begin
  if ADesigner <> nil then
    Result := ADesigner.Root
  else
    Result := nil;
end;

function FmrIdeBridgeFor(const AComponent: TComponent): IFmrDesignBridge;
var
  Root: TComponent;
  D: IDesigner;
  Hook: FMX.Forms.IDesignerHook;
begin
  Result := nil;
  if AComponent = nil then
    Exit;
  Root := AComponent;
  while Root.Owner <> nil do
  begin
    if (GNotifier <> nil) and (GNotifier.DesignerOf(Root) <> nil) then
      Break;
    Root := Root.Owner;
  end;
  if GNotifier <> nil then
    D := GNotifier.DesignerOf(Root);
  if (D = nil) and (Root is TCommonCustomForm) then
  begin
    Hook := TCommonCustomForm(Root).Designer;
    if Hook <> nil then
      Supports(Hook, IDesigner, D);
  end;
  if D <> nil then
    Result := TFmrIdeBridge.Create(D);
end;

function ImagesOf(const AObject: TPersistent): FMX.ImgList.TCustomImageList; forward;

function ManagerOf(const AObject: TPersistent): TFmrBarManager;
var
  P: TPersistent;
  O: IFmrRibbonStructureOwner;
  Obj: TObject;
begin
  Result := nil;
  P := AObject;
  while P <> nil do
  begin
    if P is TFmrBarManager then
      Exit(TFmrBarManager(P));
    if P is TFmrBarItem then
      Exit(TFmrBarItem(P).Manager);
    if (P is TFmrRibbonStructureObject) then
    begin
      O := TFmrRibbonStructureObject(P).StructureOwner;
      if O <> nil then
        Exit(O.GetBarManager);
    end;
    if Supports(P, IFmrRibbonStructureOwner, O) then
      Exit(O.GetBarManager);
    if IsPublishedProp(P, 'BarManager') then
    begin
      Obj := GetObjectProp(P, 'BarManager');
      if Obj is TFmrBarManager then
        Exit(TFmrBarManager(Obj));
    end;
    if P is TFmrItemLink then
      P := TFmrItemLink(P).LinksOwner
    else if P is TFmrRibbonQuickAccessToolbar then
      P := TFmrRibbonQuickAccessToolbar(P).Owner
    else if P is TFmxObject then
      P := TFmxObject(P).Parent
    else if P is TCollectionItem then
      P := TCollectionItem(P).Collection.Owner
    else if P is TCollection then
      P := TCollection(P).Owner
    else if P is TFmrImageSource then
      P := TFmrImageSourceAccess(P).GetOwner
    else
      Break;
  end;
end;

function ImagesOf(const AObject: TPersistent): FMX.ImgList.TCustomImageList;
var
  M: TFmrBarManager;
begin
  M := ManagerOf(AObject);
  if M <> nil then
    Result := M.Images
  else
    Result := nil;
end;

{ TFmrIdeBridge }

constructor TFmrIdeBridge.Create(const ADesigner: IDesigner);
begin
  inherited Create;
  FDesigner := ADesigner;
end;

function TFmrIdeBridge.Root: TComponent;
begin
  Result := FDesigner.Root;
end;

function TFmrIdeBridge.UniqueName(const ABaseName: string): string;
begin
  if IsValidIdent(ABaseName) and (FDesigner.Root.FindComponent(ABaseName) = nil) and
    not SameText(ABaseName, FDesigner.Root.Name) then
    Result := ABaseName
  else
    Result := FDesigner.UniqueName(ABaseName);
end;

function TFmrIdeBridge.CreateComponent(const AClass: TComponentClass; const AParent: FMX.Types.TFmxObject): TComponent;
begin
  if AParent <> nil then
    Result := FDesigner.CreateChild(AClass, AParent)
  else
    Result := FDesigner.CreateComponent(AClass, FDesigner.Root, 0, 0, 0, 0);
end;

procedure TFmrIdeBridge.Modified;
begin
  FDesigner.Modified;
end;

procedure TFmrIdeBridge.SelectObjects(const AObjects: TArray<TPersistent>);
var
  Sel: IDesignerSelections;
  P: TPersistent;
begin
  if Length(AObjects) = 1 then
    FDesigner.SelectComponent(AObjects[0])
  else if Length(AObjects) > 1 then
  begin
    Sel := CreateSelectionList;
    for P in AObjects do
      Sel.Add(P);
    FDesigner.SetSelections(Sel);
  end;
end;

function TFmrIdeBridge.SelectedObjects: TArray<TPersistent>;
var
  Sel: IDesignerSelections;
  I: Integer;
begin
  Sel := CreateSelectionList;
  FDesigner.GetSelections(Sel);
  Result := nil;
  for I := 0 to Sel.Count - 1 do
    Result := Result + [Sel[I]];
end;

procedure TFmrIdeBridge.ShowEvent(const AInstance: TPersistent; const AEventName: string);
var
  Info: PPropInfo;
  Method: TMethod;
  Name, Base: string;
begin
  Info := GetPropInfo(AInstance, AEventName);
  if (Info = nil) or (Info.PropType^.Kind <> tkMethod) then
    Exit;
  Method := GetMethodProp(AInstance, Info);
  if Method.Code <> nil then
    Name := FDesigner.GetMethodName(Method)
  else
  begin
    if AInstance is TComponent then
      Base := TComponent(AInstance).Name
    else
      Base := FDesigner.GetObjectName(AInstance);
    Name := Base + Copy(AEventName, 3, MaxInt);
    Method := FDesigner.CreateMethod(Name, GetTypeData(Info.PropType^));
    SetMethodProp(AInstance, Info, Method);
    FDesigner.Modified;
  end;
  FDesigner.ShowMethod(Name);
end;

{ TFmrDesignNotifier }

constructor TFmrDesignNotifier.Create;
begin
  inherited Create;
  FDesigners := TDictionary<TComponent, IDesigner>.Create;
end;

destructor TFmrDesignNotifier.Destroy;
begin
  FDesigners.Free;
  inherited;
end;

function TFmrDesignNotifier.DesignerOf(const ARoot: TComponent): IDesigner;
begin
  if (ARoot = nil) or not FDesigners.TryGetValue(ARoot, Result) then
    Result := nil;
end;

procedure TFmrDesignNotifier.DesignerOpened(const ADesigner: IDesigner; AResurrecting: Boolean);
begin
  if RootOf(ADesigner) <> nil then
    FDesigners.AddOrSetValue(ADesigner.Root, ADesigner);
end;

procedure TFmrDesignNotifier.DesignerClosed(const ADesigner: IDesigner; AGoingDormant: Boolean);
var
  Root: TComponent;
begin
  Root := RootOf(ADesigner);
  if Root <> nil then
  begin
    TFmrDesignHub.RootClosing(Root);
    FDesigners.Remove(Root);
  end;
end;

procedure TFmrDesignNotifier.ItemDeleted(const ADesigner: IDesigner; AItem: TPersistent);
begin
  if RootOf(ADesigner) <> nil then
  begin
    FDesigners.AddOrSetValue(ADesigner.Root, ADesigner);
    TFmrDesignHub.ItemDeleted(ADesigner.Root, AItem);
  end;
end;

procedure TFmrDesignNotifier.ItemInserted(const ADesigner: IDesigner; AItem: TPersistent);
begin
  if RootOf(ADesigner) <> nil then
  begin
    FDesigners.AddOrSetValue(ADesigner.Root, ADesigner);
    TFmrDesignHub.ItemInserted(ADesigner.Root, AItem);
  end;
end;

procedure TFmrDesignNotifier.ItemsModified(const ADesigner: IDesigner);
begin
  if RootOf(ADesigner) <> nil then
  begin
    FDesigners.AddOrSetValue(ADesigner.Root, ADesigner);
    TFmrDesignHub.ItemsModified(ADesigner.Root);
  end;
end;

procedure TFmrDesignNotifier.SelectionChanged(const ADesigner: IDesigner; const ASelection: IDesignerSelections);
var
  Objs: TArray<TPersistent>;
  I: Integer;
begin
  if RootOf(ADesigner) = nil then
    Exit;
  FDesigners.AddOrSetValue(ADesigner.Root, ADesigner);
  Objs := nil;
  if ASelection <> nil then
    for I := 0 to ASelection.Count - 1 do
      Objs := Objs + [ASelection[I]];
  TFmrDesignHub.SelectionChanged(ADesigner.Root, Objs);
  FmrDesignSyncSelection(ADesigner.Root, Objs);
end;

{ TFmrThemeNameProperty }

function TFmrThemeNameProperty.GetAttributes: TPropertyAttributes;
begin
  Result := [paValueList, paSortList, paMultiSelect, paRevertable];
end;

procedure TFmrThemeNameProperty.GetValues(Proc: TGetStrProc);
var
  S: string;
begin
  for S in TFmrTheme.ThemeNames do
    Proc(S);
end;

{ TFmrAccentColorProperty }

type
  TAccentName = record
    Name: string;
    Color: TAlphaColor;
  end;

const
  AccentNames: array[0..8] of TAccentName = (
    (Name: '(theme default)'; Color: 0),
    (Name: 'Blue'; Color: FmrAccentBlue),
    (Name: 'Cobalt'; Color: FmrAccentCobalt),
    (Name: 'Green'; Color: FmrAccentGreen),
    (Name: 'Orange'; Color: FmrAccentOrange),
    (Name: 'Azure'; Color: FmrAccentAzure),
    (Name: 'Purple'; Color: FmrAccentPurple),
    (Name: 'Crimson'; Color: FmrAccentCrimson),
    (Name: 'Sky'; Color: FmrAccentSky));

function AccentText(const AColor: TAlphaColor): string;
var
  A: TAccentName;
begin
  for A in AccentNames do
    if A.Color = AColor then
      Exit(A.Name);
  Result := FmrAlphaColorText(AColor);
end;

function AccentFromText(const AText: string; out AColor: TAlphaColor): Boolean;
var
  A: TAccentName;
  S: string;
  V: Int64;
begin
  S := AText.Trim;
  for A in AccentNames do
    if SameText(A.Name, S) or (SameText(S, 'default') and (A.Color = 0)) then
    begin
      AColor := A.Color;
      Exit(True);
    end;
  if S.StartsWith('#') then
    S := '$' + S.Substring(1)
  else if S.StartsWith('0x', True) then
    S := '$' + S.Substring(2);
  Result := TryStrToInt64(S, V) and (V >= 0) and (V <= $FFFFFFFF);
  if Result then
  begin
    AColor := TAlphaColor(V);
    // '#RRGGBB' without alpha: opaque.
    if (Length(AText.Trim) = 7) and AText.Trim.StartsWith('#') then
      AColor := AColor or $FF000000;
  end;
end;

function TFmrAccentColorProperty.GetAttributes: TPropertyAttributes;
begin
  Result := [paValueList, paDialog, paMultiSelect, paRevertable];
end;

function TFmrAccentColorProperty.GetValue: string;
begin
  Result := AccentText(TAlphaColor(GetOrdValue));
end;

procedure TFmrAccentColorProperty.SetValue(const Value: string);
var
  C: TAlphaColor;
begin
  if not AccentFromText(Value, C) then
    raise EPropertyError.CreateFmt('"%s" is not an accent color: use a name of the list or #AARRGGBB', [Value]);
  SetOrdValue(Integer(C));
end;

procedure TFmrAccentColorProperty.GetValues(Proc: TGetStrProc);
var
  A: TAccentName;
begin
  for A in AccentNames do
    Proc(A.Name);
end;

procedure TFmrAccentColorProperty.Edit;
var
  D: TColorDialog;
  C: TAlphaColor;
begin
  D := TColorDialog.Create(nil);
  try
    C := TAlphaColor(GetOrdValue);
    if C = 0 then
      C := FmrAccentBlue;
    D.Color := FmrAlphaColorToColor(C);
    D.Options := [cdFullOpen, cdAnyColor];
    if D.Execute then
      SetOrdValue(Integer(FmrColorToAlphaColor(D.Color)));
  finally
    D.Free;
  end;
end;

procedure DrawSwatch(const ACanvas: TCanvas; const ARect: TRect; const AColor: TAlphaColor);
var
  R: TRect;
  OldBrush, OldPen: TColor;
begin
  OldBrush := ACanvas.Brush.Color;
  OldPen := ACanvas.Pen.Color;
  R := ARect;
  InflateRect(R, -2, -2);
  R.Right := R.Left + R.Height;
  if AColor = 0 then
  begin
    ACanvas.Brush.Color := clWindow;
    ACanvas.Pen.Color := clGrayText;
    ACanvas.Rectangle(R);
    ACanvas.MoveTo(R.Left, R.Bottom - 1);
    ACanvas.LineTo(R.Right, R.Top - 1);
  end
  else
  begin
    ACanvas.Brush.Color := FmrAlphaColorToColor(AColor);
    ACanvas.Pen.Color := clBlack;
    ACanvas.Rectangle(R);
  end;
  ACanvas.Brush.Color := OldBrush;
  ACanvas.Pen.Color := OldPen;
end;

procedure TFmrAccentColorProperty.PropDrawName(ACanvas: TCanvas; const ARect: TRect; ASelected: Boolean);
begin
  DefaultPropertyDrawName(Self, ACanvas, ARect);
end;

procedure TFmrAccentColorProperty.PropDrawValue(ACanvas: TCanvas; const ARect: TRect; ASelected: Boolean);
var
  R: TRect;
begin
  DrawSwatch(ACanvas, ARect, TAlphaColor(GetOrdValue));
  R := ARect;
  R.Left := R.Left + R.Height + 2;
  DefaultPropertyDrawValue(Self, ACanvas, R);
end;

function TFmrAccentColorProperty.PropDrawNameRect(const ARect: TRect): TRect;
begin
  Result := ARect;
end;

function TFmrAccentColorProperty.PropDrawValueRect(const ARect: TRect): TRect;
begin
  Result := Rect(ARect.Left, ARect.Top, ARect.Left + ARect.Height, ARect.Bottom);
end;

procedure TFmrAccentColorProperty.ListMeasureWidth(const Value: string; ACanvas: TCanvas; var AWidth: Integer);
begin
  AWidth := AWidth + ACanvas.TextHeight('Wg') + 4;
end;

procedure TFmrAccentColorProperty.ListMeasureHeight(const Value: string; ACanvas: TCanvas; var AHeight: Integer);
begin
end;

procedure TFmrAccentColorProperty.ListDrawValue(const Value: string; ACanvas: TCanvas; const ARect: TRect;
  ASelected: Boolean);
var
  C: TAlphaColor;
  R: TRect;
begin
  ACanvas.FillRect(ARect);
  if AccentFromText(Value, C) then
    DrawSwatch(ACanvas, ARect, C);
  R := ARect;
  R.Left := R.Left + R.Height + 4;
  ACanvas.TextRect(R, R.Left, R.Top + (R.Height - ACanvas.TextHeight(Value)) div 2, Value);
end;

{ TFmrImageSourceProperty }

function ImageSummary(const AImage: TFmrImageSource): string;
var
  Name: string;
begin
  if AImage = nil then
    Exit('');
  case AImage.EffectiveKind of
    TFmrImageKind.ImageList:
      Result := Format('(Image %d)', [AImage.ImageIndex]);
    TFmrImageKind.Svg:
      Result := '(SVG)';
    TFmrImageKind.Glyph:
      begin
        Name := FmrGlyphName(AImage.GlyphCode);
        if Name <> '' then
          Name := ' ' + Name.Split([' '])[0];
        Result := Format('(Glyph $%s%s)', [IntToHex(AImage.GlyphCode, 4), Name]);
      end;
    TFmrImageKind.Path:
      Result := '(Path)';
  else
    Result := '(None)';
  end;
end;

function TFmrImageSourceProperty.GetAttributes: TPropertyAttributes;
begin
  Result := [paSubProperties, paDialog, paReadOnly, paMultiSelect];
end;

function TFmrImageSourceProperty.GetValue: string;
begin
  Result := ImageSummary(TFmrImageSource(GetOrdValue));
end;

procedure TFmrImageSourceProperty.Edit;
var
  Img: TFmrImageSource;
  I: Integer;
begin
  Img := TFmrImageSource(GetOrdValue);
  if Img = nil then
    Exit;
  if FmrEditImageSource(Img, ImagesOf(GetComponent(0)), GetComponent(0).ClassName + '.' + GetName) then
  begin
    for I := 1 to PropCount - 1 do
      TFmrImageSource(GetOrdValueAt(I)).Assign(Img);
    Modified;
  end;
end;

{ TFmrGlyphCodeProperty }

function TFmrGlyphCodeProperty.GetAttributes: TPropertyAttributes;
begin
  Result := [paDialog, paMultiSelect, paRevertable];
end;

function TFmrGlyphCodeProperty.GetValue: string;
var
  C: Cardinal;
  Name: string;
begin
  C := Cardinal(GetOrdValue);
  if C = 0 then
    Exit('0');
  Result := '$' + IntToHex(C, 4);
  Name := FmrGlyphName(C);
  if Name <> '' then
    Result := Result + ' ' + Name.Split([' '])[0];
end;

procedure TFmrGlyphCodeProperty.SetValue(const Value: string);
var
  S: string;
  V: Integer;
begin
  S := Value.Trim;
  if Pos(' ', S) > 0 then
    S := Copy(S, 1, Pos(' ', S) - 1);
  if S.StartsWith('U+', True) or S.StartsWith('0x', True) then
    S := '$' + S.Substring(2)
  else if S.StartsWith('#') then
    S := '$' + S.Substring(1)
  else if (S <> '') and not S.StartsWith('$') and (Length(S) >= 4) then
    S := '$' + S;
  if not TryStrToInt(S, V) or (V < 0) or (V > $10FFFF) then
    raise EPropertyError.CreateFmt('"%s" is not a code point (hexadecimal, e.g. E8C8)', [Value]);
  SetOrdValue(V);
end;

procedure TFmrGlyphCodeProperty.Edit;
var
  Img: TFmrImageSource;
begin
  if not (GetComponent(0) is TFmrImageSource) then
    Exit;
  Img := TFmrImageSource(GetComponent(0));
  if FmrEditImageSource(Img, ImagesOf(Img), 'Glyph', TFmrImageKind.Glyph) then
    Modified;
end;

{ TFmrGlyphFontProperty }

function TFmrGlyphFontProperty.GetAttributes: TPropertyAttributes;
begin
  Result := [paValueList, paMultiSelect, paRevertable];
end;

procedure TFmrGlyphFontProperty.GetValues(Proc: TGetStrProc);
var
  S: string;
begin
  for S in FmrInstalledIconFonts do
    Proc(S);
end;

{ TFmrImageTextProperty }

function TFmrImageTextProperty.GetAttributes: TPropertyAttributes;
begin
  Result := [paDialog, paMultiSelect, paRevertable];
end;

function TFmrImageTextProperty.GetValue: string;
var
  S: string;
begin
  S := GetStrValue;
  if S = '' then
    Result := ''
  else
    Result := Format('(%d characters)', [Length(S)]);
end;

procedure TFmrImageTextProperty.Edit;
var
  Img: TFmrImageSource;
  Page: TFmrImageKind;
begin
  if not (GetComponent(0) is TFmrImageSource) then
    Exit;
  Img := TFmrImageSource(GetComponent(0));
  if SameText(GetName, 'SvgSource') then
    Page := TFmrImageKind.Svg
  else
    Page := TFmrImageKind.Path;
  if FmrEditImageSource(Img, ImagesOf(Img), GetName, Page) then
    Modified;
end;

{ TFmrLinkItemProperty }

procedure TFmrLinkItemProperty.GetValues(Proc: TGetStrProc);
var
  M: TFmrBarManager;
  I: Integer;
  Link: TFmrItemLink;
begin
  M := ManagerOf(GetComponent(0));
  if M = nil then
  begin
    inherited;
    Exit;
  end;
  Link := nil;
  if GetComponent(0) is TFmrItemLink then
    Link := TFmrItemLink(GetComponent(0));
  for I := 0 to M.ItemCount - 1 do
    if (M.Items[I].Name <> '') and ((Link = nil) or (Link.Links = nil) or M.Items[I].CanLinkInto(Link.Links)) then
      Proc(M.Items[I].Name);
end;

{ TFmrCategoryProperty }

function TFmrCategoryProperty.GetAttributes: TPropertyAttributes;
begin
  Result := [paValueList, paSortList, paMultiSelect, paRevertable];
end;

procedure TFmrCategoryProperty.GetValues(Proc: TGetStrProc);
var
  M: TFmrBarManager;
  I: Integer;
begin
  M := ManagerOf(GetComponent(0));
  if M <> nil then
    for I := 0 to M.Categories.Count - 1 do
      Proc(M.Categories[I]);
end;

procedure TFmrCategoryProperty.SetValue(const Value: string);
var
  M: TFmrBarManager;
begin
  inherited SetValue(Value.Trim);
  M := ManagerOf(GetComponent(0));
  if (M <> nil) and (Value.Trim <> '') and (M.Categories.IndexOf(Value.Trim) < 0) then
    M.Categories.Add(Value.Trim);
end;

{ TFmrKeyTipProperty }

procedure TFmrKeyTipProperty.SetValue(const Value: string);
var
  S: string;
  C: Char;
begin
  S := Value.Trim.ToUpper;
  if Length(S) > 3 then
    raise EPropertyError.Create('A key tip has at most 3 characters');
  for C in S do
    if not CharInSet(C, ['A'..'Z', '0'..'9']) and not C.IsLetter then
      raise EPropertyError.CreateFmt('Key tips are made of letters and digits ("%s")', [Value]);
  inherited SetValue(S);
end;

{ TFmrFrameModeProperty }

function TFmrFrameModeProperty.GetAttributes: TPropertyAttributes;
begin
  Result := inherited GetAttributes + [paDialog];
end;

procedure TFmrFrameModeProperty.Edit;
const
  Texts: array[TFmrFrameMode] of string = (
    'Dwm - the top non-client area is removed; the caption content is an ordinary control at the top of the ' +
      'client area over the DWM frame (optional Mica/Acrylic backdrop).',
    'FullNC (default) - the caption row and the tab row are the real non-client area: painted in WM_NCPAINT, ' +
      'Snap Layouts on the maximize button, Windows 11 shadow and rounded corners.',
    'NCStrip - the system title bar stays; the caption content is a real non-client strip below it.');
var
  F: TForm;
  Radios: array[TFmrFrameMode] of TRadioButton;
  M: TFmrFrameMode;
  Y: Integer;
  B: TButton;
  L: TLabel;
begin
  F := TForm.CreateNew(nil);
  try
    F.Caption := 'Frame Mode';
    F.BorderStyle := bsDialog;
    F.Position := poScreenCenter;
    F.Font.Name := 'Segoe UI';
    F.Font.Height := -12;
    F.ClientWidth := 460;
    Y := 12;
    for M := Low(TFmrFrameMode) to High(TFmrFrameMode) do
    begin
      Radios[M] := TRadioButton.Create(F);
      Radios[M].Parent := F;
      Radios[M].Caption := GetEnumName(TypeInfo(TFmrFrameMode), Ord(M));
      Radios[M].SetBounds(12, Y, 200, 20);
      Radios[M].Checked := GetOrdValue = Ord(M);
      L := TLabel.Create(F);
      L.Parent := F;
      L.WordWrap := True;
      L.AutoSize := False;
      L.SetBounds(32, Y + 20, 416, 34);
      L.Caption := Texts[M];
      Inc(Y, 62);
    end;
    B := TButton.Create(F);
    B.Parent := F;
    B.Caption := 'OK';
    B.Default := True;
    B.ModalResult := mrOk;
    B.SetBounds(F.ClientWidth - 176, Y, 80, 26);
    B := TButton.Create(F);
    B.Parent := F;
    B.Caption := 'Cancel';
    B.Cancel := True;
    B.ModalResult := mrCancel;
    B.SetBounds(F.ClientWidth - 90, Y, 80, 26);
    F.ClientHeight := Y + 38;
    if Assigned(FmrDesignApplyTheme) then
      FmrDesignApplyTheme(F);
    if F.ShowModal = mrOk then
      for M := Low(TFmrFrameMode) to High(TFmrFrameMode) do
        if Radios[M].Checked then
          SetOrdValue(Ord(M));
  finally
    F.Free;
  end;
end;

{ TFmrComponentEditor }

function TFmrComponentEditor.Bridge: IFmrDesignBridge;
begin
  Result := TFmrIdeBridge.Create(Designer);
end;

procedure TFmrComponentEditor.AddThemeItems(const AItem: IMenuItem);
var
  S, Current: string;
  Sub: IMenuItem;
begin
  Current := '';
  if IsPublishedProp(Component, 'Theme') then
    Current := GetStrProp(Component, 'Theme');
  for S in TFmrTheme.ThemeNames do
  begin
    Sub := AItem.AddItem(S, 0, SameText(S, TFmrTheme.ResolveThemeName(Current)), True, ThemeItemClick);
    Sub := nil;
  end;
end;

procedure TFmrComponentEditor.ThemeItemClick(Sender: TObject);
var
  S: string;
begin
  if Sender is Vcl.Menus.TMenuItem then
    S := StripHotkey(Vcl.Menus.TMenuItem(Sender).Caption)
  else
    Exit;
  if IsPublishedProp(Component, 'Theme') then
  begin
    SetStrProp(Component, 'Theme', S);
    Designer.Modified;
  end;
end;

{ TFmrBarManagerEditor }

procedure TFmrBarManagerEditor.Edit;
begin
  FmrShowItemsEditor(Bridge, TFmrBarManager(Component));
end;

function TFmrBarManagerEditor.GetVerbCount: Integer;
begin
  Result := 3;
end;

function TFmrBarManagerEditor.GetVerb(Index: Integer): string;
begin
  case Index of
    0:
      Result := 'Items Editor...';
    1:
      Result := 'New Button';
    2:
      Result := 'New Item';
  else
    Result := '';
  end;
end;

procedure TFmrBarManagerEditor.ExecuteVerb(Index: Integer);
var
  Item: TFmrBarItem;
begin
  case Index of
    0:
      Edit;
    1:
      begin
        Item := FmrDesignNewItem(Bridge, TFmrBarManager(Component), TFmrButtonItem);
        Designer.Modified;
        Designer.SelectComponent(Item);
      end;
  end;
end;

procedure TFmrBarManagerEditor.PrepareItem(Index: Integer; const AItem: IMenuItem);
var
  Info: TFmrItemClassInfo;
  Sub: IMenuItem;
begin
  inherited;
  if Index = 2 then
    for Info in FmrDesignItemClasses do
    begin
      Sub := AItem.AddItem(Info.Caption, 0, False, True, NewItemClick);
      Sub.Tag := NativeInt(Info.ItemClass);
    end;
end;

procedure TFmrBarManagerEditor.NewItemClick(Sender: TObject);
var
  Item: TFmrBarItem;
begin
  if not (Sender is Vcl.Menus.TMenuItem) then
    Exit;
  Item := FmrDesignNewItem(Bridge, TFmrBarManager(Component), TFmrBarItemClass(Vcl.Menus.TMenuItem(Sender).Tag));
  Designer.Modified;
  Designer.SelectComponent(Item);
end;

{ TFmrRibbonEditor }

procedure TFmrRibbonEditor.Edit;
begin
  FmrShowStructureEditor(Bridge, TFmxObject(Component));
end;

function TFmrRibbonEditor.GetVerbCount: Integer;
begin
  Result := 9;
end;

function TFmrRibbonEditor.GetVerb(Index: Integer): string;
begin
  case Index of
    0:
      Result := 'Structure Editor...';
    1:
      Result := 'Items Editor...';
    2:
      Result := 'Add Tab';
    3:
      Result := 'Add Contextual Tab Group';
    4:
      Result := 'Apply Template...';
    5:
      Result := 'Theme';
    6:
      Result := 'Previous Tab';
    7:
      Result := 'Next Tab';
    8:
      Result := 'Create Bar Manager';
  else
    Result := '';
  end;
end;

procedure TFmrRibbonEditor.PrepareItem(Index: Integer; const AItem: IMenuItem);
var
  R: TFmrRibbon;
  T: TFmrRibbonTab;
begin
  inherited;
  R := TFmrRibbon(Component);
  case Index of
    1:
      AItem.Enabled := R.BarManager <> nil;
    5:
      AddThemeItems(AItem);
    6, 7:
      begin
        T := R.ActiveTab;
        if Index = 6 then
          AItem.Enabled := (T <> nil) and (T.TabIndex > 0)
        else
          AItem.Enabled := R.TabCount > 0;
      end;
    8:
      AItem.Visible := R.BarManager = nil;
  end;
end;

procedure TFmrRibbonEditor.ExecuteVerb(Index: Integer);
var
  R: TFmrRibbon;
  T: TFmrRibbonTab;
  C: TFmrRibbonContextGroup;
  I: Integer;
begin
  R := TFmrRibbon(Component);
  case Index of
    0:
      Edit;
    1:
      if R.BarManager <> nil then
        FmrShowItemsEditor(Bridge, R.BarManager);
    2:
      begin
        T := FmrDesignNewTab(Bridge, R);
        R.ActiveTab := T;
        Designer.Modified;
        Designer.SelectComponent(T);
      end;
    3:
      begin
        C := FmrDesignNewContextGroup(Bridge, R);
        C.Visible := True;
        T := FmrDesignNewTab(Bridge, R, C);
        R.ActiveTab := T;
        Designer.Modified;
        Designer.SelectComponent(C);
      end;
    4:
      FmrDesignRunTemplateWizard(Bridge, R);
    6, 7:
      begin
        T := R.ActiveTab;
        if T = nil then
          I := 0
        else if Index = 6 then
          I := T.TabIndex - 1
        else
          I := T.TabIndex + 1;
        if R.TabCount > 0 then
        begin
          if I >= R.TabCount then
            I := 0;
          if I < 0 then
            I := R.TabCount - 1;
          R.ActiveTab := R.Tabs(I);
          Designer.SelectComponent(R.ActiveTab);
          Designer.Modified;
        end;
      end;
    8:
      begin
        FmrDesignEnsureManager(Bridge, R);
        Designer.SelectComponent(R.BarManager);
      end;
  end;
end;

{ TFmrRibbonTabEditor }

procedure TFmrRibbonTabEditor.Edit;
var
  Owner: IFmrRibbonStructureOwner;
begin
  Owner := TFmrRibbonTab(Component).StructureOwner;
  if Owner <> nil then
    Owner.SetActiveTab(TFmrRibbonTab(Component));
end;

function TFmrRibbonTabEditor.GetVerbCount: Integer;
begin
  Result := 5;
end;

function TFmrRibbonTabEditor.GetVerb(Index: Integer): string;
begin
  case Index of
    0:
      Result := 'Add Group';
    1:
      Result := 'Show This Tab';
    2:
      Result := 'Move Left';
    3:
      Result := 'Move Right';
    4:
      Result := 'Structure Editor...';
  else
    Result := '';
  end;
end;

procedure TFmrRibbonTabEditor.ExecuteVerb(Index: Integer);
var
  T: TFmrRibbonTab;
  G: TFmrRibbonGroup;
  Owner: IFmrRibbonStructureOwner;
begin
  T := TFmrRibbonTab(Component);
  Owner := T.StructureOwner;
  case Index of
    0:
      begin
        G := FmrDesignNewGroup(Bridge, T);
        Edit;
        Designer.Modified;
        Designer.SelectComponent(G);
      end;
    1:
      Edit;
    2:
      if T.TabIndex > 0 then
      begin
        TFmrRibbonStructure.MoveTab(T, T.TabIndex - 1);
        Designer.Modified;
      end;
    3:
      begin
        TFmrRibbonStructure.MoveTab(T, T.TabIndex + 1);
        Designer.Modified;
      end;
    4:
      if Owner <> nil then
        FmrShowStructureEditor(Bridge, Owner.GetStructureObject);
  end;
end;

{ TFmrRibbonGroupEditor }

procedure TFmrRibbonGroupEditor.Edit;
var
  G: TFmrRibbonGroup;
  Owner: IFmrRibbonStructureOwner;
begin
  G := TFmrRibbonGroup(Component);
  Owner := G.StructureOwner;
  if (Owner <> nil) and (G.Tab <> nil) then
    Owner.SetActiveTab(G.Tab);
end;

function TFmrRibbonGroupEditor.GetVerbCount: Integer;
begin
  Result := 6;
end;

function TFmrRibbonGroupEditor.GetVerb(Index: Integer): string;
begin
  case Index of
    0:
      Result := 'New Button';
    1:
      Result := 'New Item';
    2:
      Result := 'Add Links to Existing Items...';
    3:
      Result := 'Move Left';
    4:
      Result := 'Move Right';
    5:
      Result := 'Structure Editor...';
  else
    Result := '';
  end;
end;

procedure TFmrRibbonGroupEditor.PrepareItem(Index: Integer; const AItem: IMenuItem);
var
  Info: TFmrItemClassInfo;
  Sub: IMenuItem;
begin
  inherited;
  if Index = 1 then
    for Info in FmrDesignItemClasses do
    begin
      Sub := AItem.AddItem(Info.Caption, 0, False, True, NewItemClick);
      Sub.Tag := NativeInt(Info.ItemClass);
    end;
end;

procedure TFmrRibbonGroupEditor.NewItemClick(Sender: TObject);
var
  G: TFmrRibbonGroup;
  M: TFmrBarManager;
  Item: TFmrBarItem;
  Owner: IFmrRibbonStructureOwner;
begin
  if not (Sender is Vcl.Menus.TMenuItem) then
    Exit;
  G := TFmrRibbonGroup(Component);
  Owner := G.StructureOwner;
  if Owner = nil then
    Exit;
  M := FmrDesignEnsureManager(Bridge, Owner.GetStructureObject);
  Item := FmrDesignNewItem(Bridge, M, TFmrBarItemClass(Vcl.Menus.TMenuItem(Sender).Tag),
    FmrDesignStripAccel(G.Tab.Caption));
  G.ItemLinks.AddItem(Item);
  Designer.Modified;
  Designer.SelectComponent(Item);
end;

procedure TFmrRibbonGroupEditor.ExecuteVerb(Index: Integer);
var
  G: TFmrRibbonGroup;
  Owner: IFmrRibbonStructureOwner;
  M: TFmrBarManager;
  Items: TArray<TFmrBarItem>;
  Item: TFmrBarItem;
begin
  G := TFmrRibbonGroup(Component);
  Owner := G.StructureOwner;
  case Index of
    0:
      if Owner <> nil then
      begin
        M := FmrDesignEnsureManager(Bridge, Owner.GetStructureObject);
        Item := FmrDesignNewItem(Bridge, M, TFmrButtonItem, FmrDesignStripAccel(G.Tab.Caption));
        G.ItemLinks.AddItem(Item);
        Edit;
        Designer.Modified;
        Designer.SelectComponent(Item);
      end;
    2:
      if (Owner <> nil) and (Owner.GetBarManager <> nil) and FmrPickItems(Owner.GetBarManager, Items) then
      begin
        for Item in Items do
          if Item.CanLinkInto(G.ItemLinks) then
            G.ItemLinks.AddItem(Item);
        Designer.Modified;
      end;
    3:
      if (G.Tab <> nil) and (G.GroupIndex > 0) then
      begin
        TFmrRibbonStructure.MoveGroup(G, G.Tab, G.GroupIndex - 1);
        Designer.Modified;
      end;
    4:
      if (G.Tab <> nil) and (G.GroupIndex < G.Tab.GroupCount - 1) then
      begin
        TFmrRibbonStructure.MoveGroup(G, G.Tab, G.GroupIndex + 1);
        Designer.Modified;
      end;
    5:
      if Owner <> nil then
        FmrShowStructureEditor(Bridge, Owner.GetStructureObject);
  end;
end;

{ TFmrContextGroupEditor }

function TFmrContextGroupEditor.GetVerbCount: Integer;
begin
  Result := 2;
end;

function TFmrContextGroupEditor.GetVerb(Index: Integer): string;
begin
  case Index of
    0:
      Result := 'Add Tab';
    1:
      Result := 'Show the First Tab';
  else
    Result := '';
  end;
end;

procedure TFmrContextGroupEditor.ExecuteVerb(Index: Integer);
var
  C: TFmrRibbonContextGroup;
  Owner: IFmrRibbonStructureOwner;
  T: TFmrRibbonTab;
  Tabs: TArray<TFmrRibbonTab>;
begin
  C := TFmrRibbonContextGroup(Component);
  Owner := C.StructureOwner;
  if Owner = nil then
    Exit;
  case Index of
    0:
      begin
        T := FmrDesignNewTab(Bridge, Owner.GetStructureObject, C);
        Designer.Modified;
        Designer.SelectComponent(T);
      end;
    1:
      begin
        Tabs := C.Tabs;
        if Tabs <> nil then
          Owner.SetActiveTab(Tabs[0]);
      end;
  end;
end;

{ TFmrBarItemEditor }

function TFmrBarItemEditor.GetVerbCount: Integer;
begin
  Result := 3;
end;

function TFmrBarItemEditor.GetVerb(Index: Integer): string;
begin
  case Index of
    0:
      Result := 'Edit OnClick';
    1:
      Result := 'Add to Quick Access Toolbar';
    2:
      Result := 'Items Editor...';
  else
    Result := '';
  end;
end;

procedure TFmrBarItemEditor.ExecuteVerb(Index: Integer);
var
  Item: TFmrBarItem;
  I: Integer;
  Root: TComponent;
begin
  Item := TFmrBarItem(Component);
  case Index of
    0:
      Bridge.ShowEvent(Item, 'OnClick');
    1:
      begin
        Root := Designer.Root;
        for I := 0 to Root.ComponentCount - 1 do
          if (Root.Components[I] is TFmrRibbon) and (TFmrRibbon(Root.Components[I]).BarManager = Item.Manager) then
          begin
            TFmrRibbon(Root.Components[I]).QuickAccessToolbar.AddItem(Item);
            Designer.Modified;
            Break;
          end;
      end;
    2:
      if Item.Manager <> nil then
        FmrShowItemsEditor(Bridge, Item.Manager);
  end;
end;

{ TFmrBackstageViewEditor }

function TFmrBackstageViewEditor.GetVerbCount: Integer;
begin
  Result := 5;
end;

function TFmrBackstageViewEditor.GetVerb(Index: Integer): string;
begin
  case Index of
    0:
      Result := 'Add Tab';
    1:
      Result := 'Add Button';
    2:
      Result := 'Previous Tab';
    3:
      Result := 'Next Tab';
    4:
      Result := 'Theme';
  else
    Result := '';
  end;
end;

procedure TFmrBackstageViewEditor.PrepareItem(Index: Integer; const AItem: IMenuItem);
begin
  inherited;
  if Index = 4 then
    AddThemeItems(AItem);
end;

procedure TFmrBackstageViewEditor.ExecuteVerb(Index: Integer);
var
  V: TFmrRibbonBackstageView;
  T: TFmrBackstageTab;
  B: TFmrBackstageButton;
  I: Integer;
begin
  V := TFmrRibbonBackstageView(Component);
  case Index of
    0:
      begin
        T := TFmrBackstageTab(Bridge.CreateComponent(TFmrBackstageTab, V));
        T.Caption := 'Tab ' + IntToStr(V.TabCount);
        V.ActiveTab := T;
        Designer.Modified;
        Designer.SelectComponent(T);
      end;
    1:
      begin
        B := TFmrBackstageButton(Bridge.CreateComponent(TFmrBackstageButton, V));
        B.Caption := 'Command';
        Designer.Modified;
        Designer.SelectComponent(B);
      end;
    2, 3:
      if V.TabCount > 0 then
      begin
        I := 0;
        while (I < V.TabCount) and (V.Tabs[I] <> V.ActiveTab) do
          Inc(I);
        if Index = 2 then
          Dec(I)
        else
          Inc(I);
        if I < 0 then
          I := V.TabCount - 1;
        if I >= V.TabCount then
          I := 0;
        V.ActiveTab := V.Tabs[I];
        Designer.SelectComponent(V.ActiveTab);
        Designer.Modified;
      end;
  end;
end;

{ TFmrStatusBarEditor }

function TFmrStatusBarEditor.GetVerbCount: Integer;
begin
  Result := 6;
end;

function TFmrStatusBarEditor.GetVerb(Index: Integer): string;
begin
  case Index of
    0:
      Result := 'Add Text Panel';
    1:
      Result := 'Add Container Panel';
    2:
      Result := 'Add Item Links Panel';
    3:
      Result := 'Add View Buttons';
    4:
      Result := 'Add Zoom Slider';
    5:
      Result := 'Theme';
  else
    Result := '';
  end;
end;

procedure TFmrStatusBarEditor.PrepareItem(Index: Integer; const AItem: IMenuItem);
begin
  inherited;
  if Index = 5 then
    AddThemeItems(AItem);
end;

procedure TFmrStatusBarEditor.ExecuteVerb(Index: Integer);
var
  P: TFmrStatusBarPanel;
begin
  if Index > 4 then
    Exit;
  P := TFmrStatusBarPanel(Bridge.CreateComponent(TFmrStatusBarPanel, TFmrStatusBar(Component)));
  case Index of
    0:
      begin
        P.Kind := TFmrStatusPanelKind.Text;
        P.Text := 'Ready';
      end;
    1:
      P.Kind := TFmrStatusPanelKind.Container;
    2:
      begin
        P.Kind := TFmrStatusPanelKind.ItemLinks;
        P.Side := TFmrStatusPanelSide.Right;
      end;
    3:
      begin
        P.Kind := TFmrStatusPanelKind.ViewButtons;
        P.Side := TFmrStatusPanelSide.Right;
      end;
    4:
      begin
        P.Kind := TFmrStatusPanelKind.ZoomSlider;
        P.Side := TFmrStatusPanelSide.Right;
      end;
  end;
  Designer.Modified;
  Designer.SelectComponent(P);
end;

{ selection editors }

procedure TFmrRibbonSelectionEditor.RequiresUnits(Proc: TGetStrProc);
begin
  inherited;
  Proc('FMR.Ribbon.Types');
  Proc('FMR.Bars');
  Proc('FMR.Ribbon.Structure');
end;

procedure TFmrBarsSelectionEditor.RequiresUnits(Proc: TGetStrProc);
begin
  inherited;
  Proc('FMR.Ribbon.Types');
  Proc('FMR.Bars');
  Proc('FMR.Bars.Items');
end;

{ registration }

var
  GThemedClasses: TList<TClass>;

procedure ApplyIdeTheme(const AForm: TCustomForm);
var
  Theming: IOTAIDEThemingServices;
begin
  if Supports(BorlandIDEServices, IOTAIDEThemingServices, Theming) and Theming.IDEThemingEnabled then
  begin
    if GThemedClasses = nil then
      GThemedClasses := TList<TClass>.Create;
    if not GThemedClasses.Contains(AForm.ClassType) then
    begin
      GThemedClasses.Add(AForm.ClassType);
      Theming.RegisterFormClass(TCustomFormClass(AForm.ClassType));
    end;
    Theming.ApplyTheme(AForm);
  end;
end;

procedure FmrRegisterDesignEditors;
begin
  { property editors }
  RegisterPropertyEditor(TypeInfo(string), TFmrRibbon, 'Theme', TFmrThemeNameProperty);
  RegisterPropertyEditor(TypeInfo(string), TFmrRibbonBackstageView, 'Theme', TFmrThemeNameProperty);
  RegisterPropertyEditor(TypeInfo(string), TFmrStatusBar, 'Theme', TFmrThemeNameProperty);
  RegisterPropertyEditor(TypeInfo(string), TFmrPopupMenu, 'Theme', TFmrThemeNameProperty);
  RegisterPropertyEditor(TypeInfo(TAlphaColor), TFmrRibbon, 'AccentColor', TFmrAccentColorProperty);
  RegisterPropertyEditor(TypeInfo(TAlphaColor), TFmrRibbonBackstageView, 'AccentColor', TFmrAccentColorProperty);
  RegisterPropertyEditor(TypeInfo(TAlphaColor), TFmrStatusBar, 'AccentColor', TFmrAccentColorProperty);
  RegisterPropertyEditor(TypeInfo(TFmrImageSource), nil, '', TFmrImageSourceProperty);
  RegisterPropertyEditor(TypeInfo(Cardinal), TFmrImageSource, 'GlyphCode', TFmrGlyphCodeProperty);
  RegisterPropertyEditor(TypeInfo(string), TFmrImageSource, 'GlyphFontFamily', TFmrGlyphFontProperty);
  RegisterPropertyEditor(TypeInfo(string), TFmrImageSource, 'SvgSource', TFmrImageTextProperty);
  RegisterPropertyEditor(TypeInfo(string), TFmrImageSource, 'PathData', TFmrImageTextProperty);
  RegisterPropertyEditor(TypeInfo(TFmrBarItem), TFmrItemLink, 'Item', TFmrLinkItemProperty);
  RegisterPropertyEditor(TypeInfo(string), TFmrBarItem, 'Category', TFmrCategoryProperty);
  RegisterPropertyEditor(TypeInfo(string), TFmrBarItem, 'KeyTip', TFmrKeyTipProperty);
  RegisterPropertyEditor(TypeInfo(string), TFmrItemLink, 'KeyTip', TFmrKeyTipProperty);
  RegisterPropertyEditor(TypeInfo(string), TFmrRibbonStructureObject, 'KeyTip', TFmrKeyTipProperty);
  RegisterPropertyEditor(TypeInfo(string), TFmrRibbonGroup, 'DialogLauncherKeyTip', TFmrKeyTipProperty);
  RegisterPropertyEditor(TypeInfo(string), TFmrRibbonApplicationButton, 'KeyTip', TFmrKeyTipProperty);
  RegisterPropertyEditor(TypeInfo(string), TFmrBackstageTab, 'KeyTip', TFmrKeyTipProperty);
  RegisterPropertyEditor(TypeInfo(string), TFmrBackstageButton, 'KeyTip', TFmrKeyTipProperty);
  RegisterPropertyEditor(TypeInfo(TFmrFrameMode), TFmrFormFrame, 'Mode', TFmrFrameModeProperty);

  { component editors }
  RegisterComponentEditor(TFmrBarManager, TFmrBarManagerEditor);
  RegisterComponentEditor(TFmrRibbon, TFmrRibbonEditor);
  RegisterComponentEditor(TFmrRibbonTab, TFmrRibbonTabEditor);
  RegisterComponentEditor(TFmrRibbonGroup, TFmrRibbonGroupEditor);
  RegisterComponentEditor(TFmrRibbonContextGroup, TFmrContextGroupEditor);
  RegisterComponentEditor(TFmrBarItem, TFmrBarItemEditor);
  RegisterComponentEditor(TFmrRibbonBackstageView, TFmrBackstageViewEditor);
  RegisterComponentEditor(TFmrStatusBar, TFmrStatusBarEditor);

  { selection editors }
  RegisterSelectionEditor(TFmrRibbon, TFmrRibbonSelectionEditor);
  RegisterSelectionEditor(TFmrRibbonGroup, TFmrRibbonSelectionEditor);
  RegisterSelectionEditor(TFmrBarItem, TFmrBarsSelectionEditor);
  RegisterSelectionEditor(TFmrStatusBar, TFmrBarsSelectionEditor);
  RegisterSelectionEditor(TFmrPopupMenu, TFmrBarsSelectionEditor);

  { designer notifications, bridge, theme, in-form design hooks }
  if GNotifier = nil then
  begin
    GNotifier := TFmrDesignNotifier.Create;
    GNotifierIntf := GNotifier;
    RegisterDesignNotification(GNotifierIntf);
  end;
  FmrDesignApplyTheme := ApplyIdeTheme;
  FmrDesignBridgeFor := FmrIdeBridgeFor;
  FmrInstallDesignHooks;
end;

initialization

finalization
  FmrRemoveDesignHooks;
  FmrDesignBridgeFor := nil;
  FmrDesignApplyTheme := nil;
  FreeAndNil(GThemedClasses);
  if GNotifierIntf <> nil then
  begin
    UnregisterDesignNotification(GNotifierIntf);
    GNotifierIntf := nil;
    GNotifier := nil;
  end;

end.
