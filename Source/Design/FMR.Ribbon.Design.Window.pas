{*******************************************************}
{                                                       }
{  FMR Ribbon for FireMonkey                            }
{  Design time: base of the non-modal editor windows    }
{                                                       }
{  MIT License. Copyright (c) 2026 Fasday               }
{                                                       }
{*******************************************************}

unit FMR.Ribbon.Design.Window;

/// Base class of the non-modal editor windows (items editor, structure editor): a VCL form built in code that
/// listens to the designer (TFmrDesignHub) for its root, closes itself when the root or its key object goes away,
/// is reused for the same key object, scales to the monitor DPI and takes the IDE theme.

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Classes, System.Types, Vcl.Controls, Vcl.Forms,
  Vcl.Graphics, Vcl.ComCtrls, Vcl.ToolWin, Vcl.ImgList, Vcl.Menus, FMR.Ribbon.Design.Bridge;

type
  /// <summary>Non-modal editor window of one key object (a bar manager, a ribbon).</summary>
  TFmrDesignWindow = class(TForm, IFmrDesignListener)
  private
    FBridge: IFmrDesignBridge;
    FRoot: TComponent;
    FKey: TComponent;
    FClosing: Boolean;
  protected
    procedure DoClose(var Action: TCloseAction); override;
    procedure Notification(AComponent: TComponent; Operation: TOperation); override;
    { IFmrDesignListener }
    procedure DesignItemDeleted(const ARoot: TComponent; const AItem: TPersistent); virtual;
    procedure DesignItemInserted(const ARoot: TComponent; const AItem: TPersistent); virtual;
    procedure DesignItemsModified(const ARoot: TComponent); virtual;
    procedure DesignSelectionChanged(const ARoot: TComponent; const AObjects: TArray<TPersistent>); virtual;
    procedure DesignRootClosing(const ARoot: TComponent); virtual;
    /// <summary>Called after the controls were created at 96 dpi: scales the window to the monitor and applies the
    /// IDE theme.</summary>
    procedure FinishLayout;
    /// <summary>A toolbar (list style, captions right of the glyphs) on top of the window.</summary>
    function NewToolBar(const AParent: TWinControl; const AImages: TCustomImageList): TToolBar;
    function NewToolButton(const AToolBar: TToolBar; const ACaption, AHint: string; const AImageIndex: Integer;
      const AOnClick: TNotifyEvent; const AStyle: TToolButtonStyle = tbsButton): TToolButton;
    function NewSeparator(const AToolBar: TToolBar): TToolButton;
    /// <summary>Closes the window without touching the designer (the key object is gone).</summary>
    procedure CloseWindow;
    function IsMyRoot(const ARoot: TComponent): Boolean; inline;
  public
    constructor CreateWindow(const ABridge: IFmrDesignBridge; const AKey: TComponent); virtual;
    destructor Destroy; override;
    /// <summary>The open window of AClass for AKey, nil when none.</summary>
    class function FindWindow(const AClass: TClass; const AKey: TComponent): TFmrDesignWindow; static;
    property Bridge: IFmrDesignBridge read FBridge;
    property Root: TComponent read FRoot;
    property Key: TComponent read FKey;
  end;

implementation

{ TFmrDesignWindow }

constructor TFmrDesignWindow.CreateWindow(const ABridge: IFmrDesignBridge; const AKey: TComponent);
begin
  inherited CreateNew(Application);
  FBridge := ABridge;
  FRoot := ABridge.Root;
  FKey := AKey;
  if FKey <> nil then
    FKey.FreeNotification(Self);
  Font.Name := 'Segoe UI';
  Font.Height := -12;
  BorderIcons := [biSystemMenu, biMaximize];
  Position := poScreenCenter;
  ShowHint := True;
  KeyPreview := True;
  TFmrDesignHub.AddListener(Self);
end;

destructor TFmrDesignWindow.Destroy;
begin
  TFmrDesignHub.RemoveListener(Self);
  if FKey <> nil then
    FKey.RemoveFreeNotification(Self);
  FBridge := nil;
  inherited;
end;

class function TFmrDesignWindow.FindWindow(const AClass: TClass; const AKey: TComponent): TFmrDesignWindow;
var
  I: Integer;
begin
  for I := 0 to Screen.FormCount - 1 do
    if (Screen.Forms[I] is AClass) and (Screen.Forms[I] is TFmrDesignWindow) and
      (TFmrDesignWindow(Screen.Forms[I]).FKey = AKey) and not TFmrDesignWindow(Screen.Forms[I]).FClosing then
      Exit(TFmrDesignWindow(Screen.Forms[I]));
  Result := nil;
end;

procedure TFmrDesignWindow.DoClose(var Action: TCloseAction);
begin
  inherited;
  Action := caFree;
  FClosing := True;
end;

procedure TFmrDesignWindow.Notification(AComponent: TComponent; Operation: TOperation);
begin
  inherited;
  if (Operation = opRemove) and (AComponent = FKey) and (FKey <> nil) then
  begin
    FKey := nil;
    CloseWindow;
  end;
end;

procedure TFmrDesignWindow.CloseWindow;
begin
  if FClosing then
    Exit;
  FClosing := True;
  TFmrDesignHub.RemoveListener(Self);
  Hide;
  Release;
end;

function TFmrDesignWindow.IsMyRoot(const ARoot: TComponent): Boolean;
begin
  Result := not FClosing and (ARoot = FRoot);
end;

procedure TFmrDesignWindow.DesignItemDeleted(const ARoot: TComponent; const AItem: TPersistent);
begin
  if IsMyRoot(ARoot) and (AItem = FKey) and (FKey <> nil) then
  begin
    FKey := nil;
    CloseWindow;
  end;
end;

procedure TFmrDesignWindow.DesignItemInserted(const ARoot: TComponent; const AItem: TPersistent);
begin
end;

procedure TFmrDesignWindow.DesignItemsModified(const ARoot: TComponent);
begin
end;

procedure TFmrDesignWindow.DesignSelectionChanged(const ARoot: TComponent; const AObjects: TArray<TPersistent>);
begin
end;

procedure TFmrDesignWindow.DesignRootClosing(const ARoot: TComponent);
begin
  if ARoot = FRoot then
    CloseWindow;
end;

procedure TFmrDesignWindow.FinishLayout;
var
  I: Integer;
begin
  FmrDesignFinishForm(Self);
  // Rows of wrapping toolbars were computed at 96 dpi: compute them again for the scaled buttons.
  for I := 0 to ComponentCount - 1 do
    if (Components[I] is TToolBar) and TToolBar(Components[I]).Wrapable then
    begin
      TToolBar(Components[I]).Wrapable := False;
      TToolBar(Components[I]).Wrapable := True;
    end;
end;

function TFmrDesignWindow.NewToolBar(const AParent: TWinControl; const AImages: TCustomImageList): TToolBar;
begin
  Result := TToolBar.Create(Self);
  Result.Parent := AParent;
  Result.Align := alTop;
  Result.Images := AImages;
  Result.List := True;
  // AllowTextButtons (mixed buttons) would show the captions of text buttons only.
  Result.ShowCaptions := True;
  Result.AutoSize := True;
  Result.Wrapable := True;
  Result.EdgeBorders := [ebBottom];
  Result.Transparent := False;
  Result.ShowHint := True;
end;

function TFmrDesignWindow.NewToolButton(const AToolBar: TToolBar; const ACaption, AHint: string;
  const AImageIndex: Integer; const AOnClick: TNotifyEvent; const AStyle: TToolButtonStyle): TToolButton;
begin
  Result := TToolButton.Create(Self);
  Result.AutoSize := True;
  Result.Caption := ACaption;
  Result.Hint := AHint;
  Result.ImageIndex := AImageIndex;
  Result.Style := AStyle;
  Result.OnClick := AOnClick;
  // A toolbar orders its buttons by position (row, then Left): a position after every button appends the new one,
  // also when the toolbar already wrapped into several rows.
  Result.Left := 100000;
  Result.Top := 100000;
  Result.Parent := AToolBar;
end;

function TFmrDesignWindow.NewSeparator(const AToolBar: TToolBar): TToolButton;
begin
  Result := NewToolButton(AToolBar, '', '', -1, nil, tbsSeparator);
  Result.Width := 8;
end;

procedure CloseAllWindows;
var
  I: Integer;
begin
  // The design package is unloaded: its windows must not outlive their code.
  if Screen = nil then
    Exit;
  for I := Screen.FormCount - 1 downto 0 do
    if Screen.Forms[I] is TFmrDesignWindow then
      Screen.Forms[I].Free;
end;

initialization

finalization
  CloseAllWindows;

end.
