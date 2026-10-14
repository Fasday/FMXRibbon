{*******************************************************}
{                                                       }
{  FMR Ribbon for FireMonkey                            }
{  Screen tips (rich tooltips)                          }
{                                                       }
{  MIT License. Copyright (c) 2026 Fasday               }
{                                                       }
{*******************************************************}

unit FMR.Ribbon.ScreenTips;

/// Screen tips: a bold header (with the shortcut), the description wrapped to the tip width with an optional image,
/// "This command is currently disabled" for disabled commands and an optional footer below a separator ("Press F1 for
/// more help"). TFmrScreenTipController shows the tip of the element under the mouse after a delay, below an anchor
/// rectangle (Office shows ribbon tips below the ribbon); moving to another element while a tip is visible shows
/// the next tip at once. The tip window is a non-activating popup outside the popup chain, so menus stay open.

interface

{$SCOPEDENUMS ON}

uses
  System.SysUtils, System.Classes, System.Types, System.UITypes, System.Math, FMX.Types, FMX.Graphics, FMX.Controls,
  FMX.Forms, FMR.Ribbon.Theme, FMR.Ribbon.Painter, FMR.Ribbon.Views, FMR.Ribbon.Popup, FMR.Ribbon.Strings;

type
  /// <summary>Content of a screen tip window.</summary>
  TFmrScreenTipContent = class(TControl, IFmrPopupContent)
  private
    FPainter: TFmrRibbonPainter;
    FInfo: TFmrScreenTipInfo;
    FSize: TSizeF;
    FHeader: string;
    FHeaderH, FDescH, FFooterH, FTextW, FImageW: Single;
    procedure Measure;
  protected
    function GetPopupSize: TSizeF;
    function PopupKeyDown(var Key: Word; var KeyChar: WideChar; const Shift: TShiftState): Boolean;
    procedure PopupShown(const AByKeyboard: Boolean);
    procedure PopupClosed;
    function PaintsOwnBackground: Boolean;
    procedure Paint; override;
  public
    constructor CreateTip(const APainter: TFmrRibbonPainter; const AInfo: TFmrScreenTipInfo);
  end;

  /// <summary>Shows screen tips after a delay.</summary>
  TFmrScreenTipController = class
  private
    FTimer: TTimer;
    FPainter: TFmrRibbonPainter;
    FOwnerForm: TCommonCustomForm;
    [Unsafe] FElement: TFmrElement;
    FAnchor: TRectF;
    FWindow: TFmrPopupForm;
    FEnabled: Boolean;
    FInitialDelay: Integer;
    procedure TimerProc(Sender: TObject);
    procedure ShowNow;
    procedure CloseWindow;
  public
    constructor Create;
    destructor Destroy; override;
    /// <summary>The mouse is over AElement (nil: over nothing). AAnchor: screen rectangle below which the tip goes.
    /// </summary>
    procedure Hover(const AElement: TFmrElement; const AAnchor: TRectF; const APainter: TFmrRibbonPainter;
      const AOwnerForm: TCommonCustomForm);
    /// <summary>Hides the tip and forgets the element (click, key, element rebuilt).</summary>
    procedure Cancel;
    function IsShowing: Boolean;
    property Enabled: Boolean read FEnabled write FEnabled;
    property InitialDelay: Integer read FInitialDelay write FInitialDelay;
  end;

implementation

const
  TipPad = 9;
  MaxTipWidth = 318;

{ TFmrScreenTipContent }

constructor TFmrScreenTipContent.CreateTip(const APainter: TFmrRibbonPainter; const AInfo: TFmrScreenTipInfo);
begin
  inherited Create(nil);
  FPainter := APainter;
  FInfo := AInfo;
  HitTest := False;
  Measure;
end;

procedure TFmrScreenTipContent.Measure;
var
  W, MaxW, TextW: Single;
  Desc: string;
begin
  FHeader := FInfo.Header;
  if FInfo.Shortcut <> '' then
    FHeader := FHeader + ' ' + FmrFmt(TFmrStringId.ScreenTipShortcut, [FInfo.Shortcut]);
  Desc := FInfo.Description;
  if FInfo.Disabled then
  begin
    if Desc <> '' then
      Desc := Desc + sLineBreak + sLineBreak;
    Desc := Desc + FmrStr(TFmrStringId.ScreenTipDisabled);
  end;
  FInfo.Description := Desc;
  if FInfo.Width > 0 then
    MaxW := FInfo.Width
  else if Desc = '' then
    MaxW := MaxTipWidth
  else
    MaxW := Max(190, Min(MaxTipWidth, FPainter.TextWidth(Desc) / 2.2 + 2 * TipPad));
  FImageW := 0;
  if FInfo.Image <> nil then
    FImageW := 64 + 8;
  W := FPainter.TextWidth(FHeader, 0, True) + 2 * TipPad;
  FHeaderH := FPainter.TextSize(FHeader, 0, True, MaxW - 2 * TipPad, True).Height;
  if FInfo.Width <= 0 then
    W := Min(W, MaxTipWidth)
  else
    W := MaxW;
  if Desc <> '' then
  begin
    TextW := MaxW - 2 * TipPad - FImageW;
    FDescH := FPainter.TextSize(Desc, 0, False, TextW, True).Height;
    if FImageW > 0 then
      FDescH := Max(FDescH, 64);
    W := Max(W, Min(MaxW, FPainter.TextWidth(Desc) + 2 * TipPad + FImageW));
    W := Max(W, MaxW);
  end
  else
    FDescH := 0;
  if FInfo.ShowFooter then
    FFooterH := FPainter.TextSize('Wg').Height + 12
  else
    FFooterH := 0;
  FTextW := W - 2 * TipPad;
  if Desc <> '' then
    FDescH := FPainter.TextSize(Desc, 0, False, FTextW - FImageW, True).Height;
  if FImageW > 0 then
    FDescH := Max(FDescH, 64);
  FSize := TSizeF.Create(Ceil(W), Ceil(TipPad + FHeaderH + IfThen(FDescH > 0, 6 + FDescH, 0) + FFooterH + TipPad));
end;

function TFmrScreenTipContent.GetPopupSize: TSizeF;
begin
  Result := FSize;
end;

function TFmrScreenTipContent.PaintsOwnBackground: Boolean;
begin
  Result := True;
end;

procedure TFmrScreenTipContent.PopupClosed;
begin
end;

function TFmrScreenTipContent.PopupKeyDown(var Key: Word; var KeyChar: WideChar; const Shift: TShiftState): Boolean;
begin
  Result := False;
end;

procedure TFmrScreenTipContent.PopupShown(const AByKeyboard: Boolean);
begin
end;

procedure TFmrScreenTipContent.Paint;
var
  R, ImgR: TRectF;
  Y, X: Single;
  Footer: string;
  TextColor, TitleColor: TAlphaColor;
begin
  R := LocalRect;
  FPainter.DrawScreenTipBackground(Canvas, R);
  TitleColor := FPainter.Theme.Colors[TFmrToken.ScreenTipTitleText];
  TextColor := FPainter.Theme.Colors[TFmrToken.ScreenTipText];
  Y := TipPad;
  FPainter.TextEx(Canvas, RectF(TipPad, Y, R.Right - TipPad, Y + FHeaderH), FHeader, TitleColor, TTextAlign.Leading,
    TTextAlign.Leading, 0, True, True);
  Y := Y + FHeaderH;
  if FDescH > 0 then
  begin
    Y := Y + 6;
    X := TipPad;
    if FInfo.Image <> nil then
    begin
      ImgR := RectF(TipPad, Y, TipPad + 64, Y + 64);
      FInfo.Image.Draw(Canvas, ImgR, 1, FPainter.GlyphTint(TFmrPartState.Normal), FInfo.Images);
      X := X + FImageW;
    end;
    FPainter.TextEx(Canvas, RectF(X, Y, R.Right - TipPad, Y + FDescH + 2), FInfo.Description, TextColor,
      TTextAlign.Leading, TTextAlign.Leading, 0, False, True);
    Y := Y + FDescH;
  end;
  if FFooterH > 0 then
  begin
    Y := Y + 6;
    FPainter.DrawScreenTipSeparator(Canvas, TipPad - 2, R.Right - TipPad + 2, Y);
    Footer := FInfo.Footer;
    if Footer = '' then
      Footer := FmrStr(TFmrStringId.ScreenTipHelp);
    FPainter.Text(Canvas, RectF(TipPad, Y + 3, TipPad + 14, R.Bottom - TipPad + 2), '?', TitleColor,
      TTextAlign.Leading, TTextAlign.Center, 0, True);
    FPainter.TextEx(Canvas, RectF(TipPad + 14, Y + 3, R.Right - TipPad, R.Bottom - TipPad + 2), Footer, TitleColor,
      TTextAlign.Leading, TTextAlign.Center, 0, True, False);
  end;
end;

{ TFmrScreenTipController }

constructor TFmrScreenTipController.Create;
begin
  inherited Create;
  FEnabled := True;
  FInitialDelay := 600;
  FTimer := TTimer.Create(nil);
  FTimer.Enabled := False;
  FTimer.OnTimer := TimerProc;
end;

destructor TFmrScreenTipController.Destroy;
begin
  FTimer.Enabled := False;
  CloseWindow;
  FreeAndNil(FTimer);
  inherited;
end;

function TFmrScreenTipController.IsShowing: Boolean;
begin
  Result := FWindow <> nil;
end;

procedure TFmrScreenTipController.CloseWindow;
var
  W: TFmrPopupForm;
begin
  W := FWindow;
  FWindow := nil;
  if W <> nil then
  begin
    W.OnClosed := nil;
    FmrPopups.Close(W);
  end;
end;

procedure TFmrScreenTipController.Hover(const AElement: TFmrElement; const AAnchor: TRectF;
  const APainter: TFmrRibbonPainter; const AOwnerForm: TCommonCustomForm);
var
  WasShowing: Boolean;
begin
  if AElement = FElement then
    Exit;
  WasShowing := FWindow <> nil;
  CloseWindow;
  FTimer.Enabled := False;
  FElement := AElement;
  FAnchor := AAnchor;
  FPainter := APainter;
  FOwnerForm := AOwnerForm;
  if (AElement = nil) or not FEnabled then
    Exit;
  if WasShowing then
    FTimer.Interval := 60
  else
    FTimer.Interval := FInitialDelay;
  FTimer.Enabled := True;
end;

procedure TFmrScreenTipController.Cancel;
begin
  FTimer.Enabled := False;
  FElement := nil;
  CloseWindow;
end;

procedure TFmrScreenTipController.TimerProc(Sender: TObject);
begin
  FTimer.Enabled := False;
  ShowNow;
end;

procedure TFmrScreenTipController.ShowNow;
var
  Info: TFmrScreenTipInfo;
  Content: TFmrScreenTipContent;
  W: TFmrPopupForm;
  Ctx: IFmrPopupContext;
  R: TRectF;
  Size: TSizeF;
begin
  if (FElement = nil) or (FPainter = nil) or not FElement.GetScreenTip(Info) or Info.IsEmpty then
    Exit;
  Content := TFmrScreenTipContent.CreateTip(FPainter, Info);
  Ctx := TFmrPopupContext.Create(FPainter, nil, FOwnerForm);
  W := TFmrPopupForm.CreatePopup(Ctx, Content);
  W.CaptureKeyboard := False;
  W.ShadowSize := 6;
  if FOwnerForm <> nil then
    W.Parent := FOwnerForm;
  Size := Content.GetPopupSize;
  R := TFmrPopupManager.PlaceRect(RectF(FAnchor.Left, FAnchor.Bottom + 2, FAnchor.Left, FAnchor.Bottom + 2), Size,
    TFmrPopupPlacement.Below);
  Content.SetBounds(W.ShadowSize, W.ShadowSize, R.Width, R.Height);
  Content.Align := TAlignLayout.None;
  W.SetBoundsF(R.Left - W.ShadowSize, R.Top - W.ShadowSize, R.Width + 2 * W.ShadowSize,
    R.Height + 2 * W.ShadowSize + 2);
  FWindow := W;
  W.OnClosed :=
    procedure
    begin
      if FWindow = W then
        FWindow := nil;
    end;
  W.Show;
end;

{ menu screen tips }

var
  GMenuTips: TFmrScreenTipController;
  [Unsafe] GMenuTipMenu: TFmrMenuControl;

/// Shows the screen tip of the hot row of a menu to the right of the menu, aligned with the row (installed as
/// FmrMenuHotRowHook; rows without a screen tip or hint show nothing).
procedure MenuHotRowChanged(const AMenu: TFmrMenuControl; const ARow: TFmrMenuRow);
var
  TL: TPointF;
begin
  if (ARow = nil) or (ARow.Kind <> TFmrMenuRowKind.Item) or (AMenu.Context = nil) or
    (csDestroying in AMenu.ComponentState) then
  begin
    if (GMenuTips <> nil) and ((GMenuTipMenu = nil) or (GMenuTipMenu = AMenu)) then
    begin
      GMenuTips.Cancel;
      GMenuTipMenu := nil;
    end;
    Exit;
  end;
  if GMenuTips = nil then
    GMenuTips := TFmrScreenTipController.Create;
  GMenuTipMenu := AMenu;
  TL := AMenu.LocalToScreen(PointF(AMenu.Width + 6, ARow.Bounds.Top - 2));
  GMenuTips.Hover(ARow, RectF(TL.X, TL.Y, TL.X, TL.Y), AMenu.Context.Painter, AMenu.Context.OwnerForm);
end;

initialization
  FmrMenuHotRowHook := MenuHotRowChanged;

finalization
  FmrMenuHotRowHook := nil;
  GMenuTipMenu := nil;
  FreeAndNil(GMenuTips);

end.
