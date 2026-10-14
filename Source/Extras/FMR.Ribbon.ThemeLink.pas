{*******************************************************}
{                                                       }
{  FMR Ribbon for FireMonkey                            }
{  Theme link of companion controls                     }
{                                                       }
{  MIT License. Copyright (c) 2026 Fasday               }
{                                                       }
{*******************************************************}

unit FMR.Ribbon.ThemeLink;

/// TFmrThemeLink gives a companion control (backstage view, status bar, their helper controls) the theme it paints
/// with. Lookup order:
///   1. the explicit provider (property ThemeProvider of the control: any TFmxObject that supports
///      IFmrThemeProvider, normally the TFmrRibbon of the form);
///   2. the nearest parent that supports IFmrThemeProvider (helper controls inside a backstage view paint with the
///      theme of the view);
///   3. an own theme built from the control's Theme name and AccentColor, with the tokens of the form's StyleBook
///      applied (TFmrTheme.ApplyStyleOverrides).
/// The link listens to TFmrThemeChangedMessage (from the provider in use) and TStyleChangedMessage (own theme) and
/// calls OnChange, so the control can re-layout and repaint.

interface

uses
  System.SysUtils, System.Classes, System.UITypes, System.Messaging, FMX.Types, FMX.Controls,
  FMR.Ribbon.Theme, FMR.Ribbon.Themes.Builtin, FMR.Ribbon.Painter;

type
  /// <summary>Theme source of a companion control; see the unit description.</summary>
  TFmrThemeLink = class
  private
    [Weak] FControl: TControl;
    FThemeName: string;
    FAccentColor: TAlphaColor;
    FProvider: TFmxObject;
    FInheritFromParent: Boolean;
    FOwnTheme: TFmrTheme;
    FOwnStyleBook: TObject;
    FPainter: TFmrRibbonPainter;
    FThemeMessageId: TMessageSubscriptionId;
    FStyleMessageId: TMessageSubscriptionId;
    FChanging: Boolean;
    FOnChange: TNotifyEvent;
    procedure ThemeChangedHandler(const Sender: TObject; const M: TMessage);
    procedure StyleChangedHandler(const Sender: TObject; const M: TMessage);
    procedure SetThemeName(const Value: string);
    procedure SetAccentColor(const Value: TAlphaColor);
    procedure SetProvider(const Value: TFmxObject);
    function CurrentStyleBook: TObject;
  public
    /// <summary>AControl: the control that paints with the theme (its Scene gives the StyleBook, its parents are
    /// searched for a provider). AOnChange is called after the theme in use changed.</summary>
    constructor Create(const AControl: TControl; const AOnChange: TNotifyEvent);
    destructor Destroy; override;
    /// <summary>The object whose theme is used (explicit provider, providing parent) or nil for the own theme.
    /// </summary>
    function ProviderObject: TFmxObject;
    /// <summary>The theme to paint with; valid until the next change notification.</summary>
    function Theme: TFmrTheme;
    /// <summary>A painter bound to Theme.</summary>
    function Painter: TFmrRibbonPainter;
    /// <summary>Drops the own theme (rebuilt on the next use) and calls OnChange.</summary>
    procedure Changed;
    /// <summary>True when Supports(AObject, IFmrThemeProvider).</summary>
    class function IsProvider(const AObject: TObject): Boolean; static;
    /// <summary>Name of the built-in theme used without a provider.</summary>
    property ThemeName: string read FThemeName write SetThemeName;
    /// <summary>Accent of the own theme; 0 = the theme's default accent.</summary>
    property AccentColor: TAlphaColor read FAccentColor write SetAccentColor;
    /// <summary>Explicit provider. The owner of the link keeps a free notification on it and sets nil when it is
    /// freed.</summary>
    property Provider: TFmxObject read FProvider write SetProvider;
    /// <summary>Search the parents for a provider when Provider is nil (default True).</summary>
    property InheritFromParent: Boolean read FInheritFromParent write FInheritFromParent;
    property OnChange: TNotifyEvent read FOnChange write FOnChange;
  end;

resourcestring
  SFmrNotThemeProvider = '%s does not implement IFmrThemeProvider';

implementation

{ TFmrThemeLink }

constructor TFmrThemeLink.Create(const AControl: TControl; const AOnChange: TNotifyEvent);
begin
  inherited Create;
  FControl := AControl;
  FOnChange := AOnChange;
  FThemeName := FmrDefaultThemeName;
  FInheritFromParent := True;
  FThemeMessageId := TMessageManager.DefaultManager.SubscribeToMessage(TFmrThemeChangedMessage, ThemeChangedHandler);
  FStyleMessageId := TMessageManager.DefaultManager.SubscribeToMessage(TStyleChangedMessage, StyleChangedHandler);
end;

destructor TFmrThemeLink.Destroy;
begin
  TMessageManager.DefaultManager.Unsubscribe(TFmrThemeChangedMessage, FThemeMessageId);
  TMessageManager.DefaultManager.Unsubscribe(TStyleChangedMessage, FStyleMessageId);
  FPainter.Free;
  FOwnTheme.Free;
  inherited;
end;

class function TFmrThemeLink.IsProvider(const AObject: TObject): Boolean;
begin
  Result := (AObject <> nil) and Supports(AObject, IFmrThemeProvider);
end;

function TFmrThemeLink.ProviderObject: TFmxObject;
var
  P: TFmxObject;
begin
  if (FProvider <> nil) and IsProvider(FProvider) and not (csDestroying in FProvider.ComponentState) then
    Exit(FProvider);
  Result := nil;
  if FInheritFromParent and (FControl <> nil) then
  begin
    P := FControl.Parent;
    while P <> nil do
    begin
      if IsProvider(P) and not (csDestroying in P.ComponentState) then
        Exit(P);
      P := P.Parent;
    end;
  end;
end;

function TFmrThemeLink.CurrentStyleBook: TObject;
var
  Owner: IStyleBookOwner;
begin
  Result := nil;
  if (FControl <> nil) and (FControl.Scene <> nil) and Supports(FControl.Scene.GetObject, IStyleBookOwner, Owner) then
    Result := Owner.GetStyleBook;
end;

function TFmrThemeLink.Theme: TFmrTheme;
var
  P: TFmxObject;
  Provider: IFmrThemeProvider;
  Book: TObject;
begin
  P := ProviderObject;
  if (P <> nil) and Supports(P, IFmrThemeProvider, Provider) then
  begin
    Result := Provider.GetFmrTheme;
    if Result <> nil then
      Exit;
  end;
  Book := CurrentStyleBook;
  if (FOwnTheme <> nil) and (Book <> FOwnStyleBook) then
    FreeAndNil(FOwnTheme);
  if FOwnTheme = nil then
  begin
    FOwnTheme := TFmrTheme.CreateTheme(FThemeName, FAccentColor);
    FOwnStyleBook := Book;
    if (Book is TStyleBook) and (TStyleBook(Book).Style <> nil) then
      FOwnTheme.ApplyStyleOverrides(TStyleBook(Book).Style);
  end;
  Result := FOwnTheme;
end;

function TFmrThemeLink.Painter: TFmrRibbonPainter;
var
  T: TFmrTheme;
begin
  T := Theme;
  if FPainter = nil then
    FPainter := TFmrRibbonPainter.Create(T)
  else if FPainter.Theme <> T then
    FPainter.Theme := T;
  Result := FPainter;
end;

procedure TFmrThemeLink.Changed;
begin
  if FChanging then
    Exit;
  FChanging := True;
  try
    FreeAndNil(FOwnTheme);
    if FPainter <> nil then
      FPainter.Theme := nil;
    if Assigned(FOnChange) then
      FOnChange(Self);
  finally
    FChanging := False;
  end;
end;

procedure TFmrThemeLink.ThemeChangedHandler(const Sender: TObject; const M: TMessage);
var
  Source: TObject;
begin
  if (FControl = nil) or (csDestroying in FControl.ComponentState) then
    Exit;
  Source := TFmrThemeChangedMessage(M).Provider;
  if (Source <> nil) and (Source <> FControl) and (Source = ProviderObject) then
    Changed;
end;

procedure TFmrThemeLink.StyleChangedHandler(const Sender: TObject; const M: TMessage);
var
  Msg: TStyleChangedMessage;
begin
  if (FControl = nil) or (csDestroying in FControl.ComponentState) then
    Exit;
  Msg := TStyleChangedMessage(M);
  if (Msg.Scene = nil) or (Msg.Scene = FControl.Scene) then
    if (FOwnTheme <> nil) and (ProviderObject = nil) then
      Changed;
end;

procedure TFmrThemeLink.SetThemeName(const Value: string);
var
  S: string;
begin
  S := TFmrTheme.ResolveThemeName(Value.Trim);
  if S = '' then
    S := FmrDefaultThemeName;
  if S <> FThemeName then
  begin
    FThemeName := S;
    if ProviderObject = nil then
      Changed
    else
      FreeAndNil(FOwnTheme);
  end;
end;

procedure TFmrThemeLink.SetAccentColor(const Value: TAlphaColor);
begin
  if FAccentColor <> Value then
  begin
    FAccentColor := Value;
    if ProviderObject = nil then
      Changed
    else
      FreeAndNil(FOwnTheme);
  end;
end;

procedure TFmrThemeLink.SetProvider(const Value: TFmxObject);
begin
  if FProvider <> Value then
  begin
    if (Value <> nil) and not IsProvider(Value) then
      raise EArgumentException.CreateFmt(SFmrNotThemeProvider, [Value.Name]);
    FProvider := Value;
    Changed;
  end;
end;

end.
