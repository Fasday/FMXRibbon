{*******************************************************}
{                                                       }
{  FMR Ribbon for FireMonkey                            }
{  Caption buttons and title of the form frame          }
{                                                       }
{  MIT License. Copyright (c) 2026 Fasday               }
{                                                       }
{*******************************************************}

unit FMR.Frame.Buttons;

interface

uses
  System.Types, System.UITypes, System.Classes, FMX.Types, FMX.Controls, FMX.Graphics, FMR.Frame.Types;

const
  /// <summary>Width (dp) of a caption button, as in Windows 11.</summary>
  FmrCaptionButtonWidth = 46;

type
  /// <summary>Kind of a caption button.</summary>
  TFmrCaptionButtonKind = (Minimize, Maximize, Close, Help);

  /// <summary>Windows 11-like caption button (minimize, maximize/restore, close, help) for a frame host. The glyph is
  /// drawn with lines; maximize shows the restore glyph when the window is maximized; close turns red when hot.</summary>
  /// <remarks>When the frame is hooked (Windows) the window manager keeps the mouse messages over the button
  /// (HTMINBUTTON, HTMAXBUTTON, HTCLOSE: Snap Layouts on Windows 11) and the frame drives its hot/pressed state
  /// (<c>IFmrFrameButton</c>); otherwise the button reacts to FMX mouse events itself.</remarks>
  TFmrCaptionButton = class(TControl, IFmrFrameButton, IFmrFrameHitTest, IFmrFrameStateAware)
  private
    FKind: TFmrCaptionButtonKind;
    FHot: Boolean;
    FDown: Boolean;
    FFrameDriven: Boolean;
    FActive: Boolean;
    FMaximized: Boolean;
    FDarkMode: Boolean;
    FGlyphColor: TAlphaColor;
    FHotColor: TAlphaColor;
    FPressedColor: TAlphaColor;
    FInactiveGlyphColor: TAlphaColor;
    FOnExecute: TNotifyEvent;
    procedure SetKind(const Value: TFmrCaptionButtonKind);
    procedure SetGlyphColor(const Value: TAlphaColor);
    procedure SetHotColor(const Value: TAlphaColor);
    procedure SetPressedColor(const Value: TAlphaColor);
    procedure SetInactiveGlyphColor(const Value: TAlphaColor);
    function CurrentBackground: TAlphaColor;
    function CurrentGlyphColor: TAlphaColor;
    procedure DrawGlyph(const ACenter: TPointF; const AColor: TAlphaColor);
  protected
    { IFmrFrameButton }
    function GetFrameButtonKind: TFmrHitArea;
    procedure SetFrameButtonState(const AHot, APressed: Boolean);
    { IFmrFrameHitTest }
    function FrameHitTest(const ALocalPoint: TPointF): TFmrHitArea;
    { IFmrFrameStateAware }
    procedure FrameStateChanged(const AState: TFmrFrameState);
    { TControl }
    procedure Paint; override;
    procedure DoMouseEnter; override;
    procedure DoMouseLeave; override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Single); override;
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Single); override;
    procedure Click; override;
    function GetDefaultSize: TSizeF; override;
  public
    constructor Create(AOwner: TComponent); override;
    /// <summary>Runs the button's window command (also called by a click when the frame is not hooked).</summary>
    procedure Execute;
    property Hot: Boolean read FHot;
    property Down: Boolean read FDown;
  published
    property Kind: TFmrCaptionButtonKind read FKind write SetKind default TFmrCaptionButtonKind.Close;
    /// <summary>Glyph color (TAlphaColors.Null: default of the light/dark frame).</summary>
    property GlyphColor: TAlphaColor read FGlyphColor write SetGlyphColor default TAlphaColors.Null;
    /// <summary>Glyph color of an inactive window (TAlphaColors.Null: default).</summary>
    property InactiveGlyphColor: TAlphaColor read FInactiveGlyphColor write SetInactiveGlyphColor
      default TAlphaColors.Null;
    /// <summary>Background when hot (TAlphaColors.Null: default; red for Close).</summary>
    property HotColor: TAlphaColor read FHotColor write SetHotColor default TAlphaColors.Null;
    /// <summary>Background when pressed (TAlphaColors.Null: default).</summary>
    property PressedColor: TAlphaColor read FPressedColor write SetPressedColor default TAlphaColors.Null;
    /// <summary>Replaces the window command of the button.</summary>
    property OnExecute: TNotifyEvent read FOnExecute write FOnExecute;
    property Align;
    property Anchors;
    property Height;
    property Margins;
    property Position;
    property Size;
    property Visible;
    property Width;
  end;

  /// <summary>Title of a frame: text that dims when the window is inactive. HitTest is False, so the title drags the
  /// window (it is caption area).</summary>
  TFmrCaptionTitle = class(TControl, IFmrFrameStateAware)
  private
    FText: string;
    FFont: TFont;
    FTextColor: TAlphaColor;
    FInactiveTextColor: TAlphaColor;
    FHorzAlign: TTextAlign;
    FActive: Boolean;
    FDarkMode: Boolean;
    procedure SetText(const Value: string);
    procedure SetTextColor(const Value: TAlphaColor);
    procedure SetInactiveTextColor(const Value: TAlphaColor);
    procedure SetHorzAlign(const Value: TTextAlign);
    procedure FontChanged(Sender: TObject);
    procedure SetFont(const Value: TFont);
  protected
    procedure FrameStateChanged(const AState: TFmrFrameState);
    procedure Paint; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
  published
    property Text: string read FText write SetText;
    property Font: TFont read FFont write SetFont;
    /// <summary>Text color (TAlphaColors.Null: default of the light/dark frame).</summary>
    property TextColor: TAlphaColor read FTextColor write SetTextColor default TAlphaColors.Null;
    property InactiveTextColor: TAlphaColor read FInactiveTextColor write SetInactiveTextColor
      default TAlphaColors.Null;
    property HorzAlign: TTextAlign read FHorzAlign write SetHorzAlign default TTextAlign.Leading;
    property Align;
    property Margins;
    property Position;
    property Size;
    property Visible;
  end;

implementation

uses
  System.SysUtils, System.Math, FMX.Forms, FMR.Frame.Host;

const
  CloseHotColor = $FFC42B1C;
  ClosePressedColor = $E6C42B1C;
  LightGlyph = $FF1A1A1A;
  DarkGlyph = $FFFFFFFF;
  LightInactiveGlyph = $FF8A8A8A;
  DarkInactiveGlyph = $FF7A7A7A;
  LightHot = $0F000000;
  LightPressed = $1A000000;
  DarkHot = $14FFFFFF;
  DarkPressed = $0CFFFFFF;

{ TFmrCaptionButton }

constructor TFmrCaptionButton.Create(AOwner: TComponent);
begin
  inherited;
  FKind := TFmrCaptionButtonKind.Close;
  FActive := True;
  FGlyphColor := TAlphaColors.Null;
  FHotColor := TAlphaColors.Null;
  FPressedColor := TAlphaColors.Null;
  FInactiveGlyphColor := TAlphaColors.Null;
  HitTest := True;
  CanFocus := False;
  AutoCapture := True;
end;

function TFmrCaptionButton.GetDefaultSize: TSizeF;
begin
  Result := TSizeF.Create(FmrCaptionButtonWidth, 32);
end;

procedure TFmrCaptionButton.SetKind(const Value: TFmrCaptionButtonKind);
begin
  if FKind <> Value then
  begin
    FKind := Value;
    Repaint;
  end;
end;

procedure TFmrCaptionButton.SetGlyphColor(const Value: TAlphaColor);
begin
  if FGlyphColor <> Value then
  begin
    FGlyphColor := Value;
    Repaint;
  end;
end;

procedure TFmrCaptionButton.SetHotColor(const Value: TAlphaColor);
begin
  if FHotColor <> Value then
  begin
    FHotColor := Value;
    Repaint;
  end;
end;

procedure TFmrCaptionButton.SetPressedColor(const Value: TAlphaColor);
begin
  if FPressedColor <> Value then
  begin
    FPressedColor := Value;
    Repaint;
  end;
end;

procedure TFmrCaptionButton.SetInactiveGlyphColor(const Value: TAlphaColor);
begin
  if FInactiveGlyphColor <> Value then
  begin
    FInactiveGlyphColor := Value;
    Repaint;
  end;
end;

function TFmrCaptionButton.GetFrameButtonKind: TFmrHitArea;
begin
  case FKind of
    TFmrCaptionButtonKind.Minimize: Result := TFmrHitArea.MinButton;
    TFmrCaptionButtonKind.Maximize: Result := TFmrHitArea.MaxButton;
    TFmrCaptionButtonKind.Help: Result := TFmrHitArea.HelpButton;
  else
    Result := TFmrHitArea.CloseButton;
  end;
end;

procedure TFmrCaptionButton.SetFrameButtonState(const AHot, APressed: Boolean);
begin
  FFrameDriven := True;
  if (FHot <> AHot) or (FDown <> APressed) then
  begin
    FHot := AHot;
    FDown := APressed;
    Repaint;
  end;
end;

function TFmrCaptionButton.FrameHitTest(const ALocalPoint: TPointF): TFmrHitArea;
begin
  Result := GetFrameButtonKind;
end;

procedure TFmrCaptionButton.FrameStateChanged(const AState: TFmrFrameState);
begin
  if (FActive <> AState.Active) or (FMaximized <> AState.Maximized) or (FDarkMode <> AState.DarkMode) then
  begin
    FActive := AState.Active;
    FMaximized := AState.Maximized;
    FDarkMode := AState.DarkMode;
    if AState.Minimized then
    begin
      FHot := False;
      FDown := False;
    end;
    Repaint;
  end;
end;

procedure TFmrCaptionButton.DoMouseEnter;
begin
  inherited;
  if not FFrameDriven then
  begin
    FHot := True;
    Repaint;
  end;
end;

procedure TFmrCaptionButton.DoMouseLeave;
begin
  inherited;
  if not FFrameDriven then
  begin
    FHot := False;
    FDown := False;
    Repaint;
  end;
end;

procedure TFmrCaptionButton.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Single);
begin
  inherited;
  if (Button = TMouseButton.mbLeft) and not FFrameDriven then
  begin
    FDown := True;
    Repaint;
  end;
end;

procedure TFmrCaptionButton.MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Single);
begin
  inherited;
  if not FFrameDriven then
  begin
    FDown := False;
    Repaint;
  end;
end;

procedure TFmrCaptionButton.Click;
begin
  inherited;
  Execute;
end;

procedure TFmrCaptionButton.Execute;
var
  Host: TFmrFrameHost;
  Form: TCommonCustomForm;
begin
  if Assigned(FOnExecute) then
  begin
    FOnExecute(Self);
    Exit;
  end;
  Host := FmrFindFrameHost(Self);
  if (Host <> nil) and (Host.Commands <> nil) then
  begin
    case FKind of
      TFmrCaptionButtonKind.Minimize: Host.Commands.Minimize;
      TFmrCaptionButtonKind.Maximize: Host.Commands.ToggleMaximize;
      TFmrCaptionButtonKind.Close: Host.Commands.CloseForm;
      TFmrCaptionButtonKind.Help: Host.Commands.ShowHelp;
    end;
    Exit;
  end;
  if Root = nil then
    Exit;
  if Root.GetObject is TCommonCustomForm then
  begin
    Form := TCommonCustomForm(Root.GetObject);
    case FKind of
      TFmrCaptionButtonKind.Minimize: Form.WindowState := TWindowState.wsMinimized;
      TFmrCaptionButtonKind.Maximize:
        if Form.WindowState = TWindowState.wsMaximized then
          Form.WindowState := TWindowState.wsNormal
        else
          Form.WindowState := TWindowState.wsMaximized;
      TFmrCaptionButtonKind.Close: Form.Close;
    end;
  end;
end;

function TFmrCaptionButton.CurrentBackground: TAlphaColor;
begin
  Result := TAlphaColors.Null;
  if FDown then
  begin
    Result := FPressedColor;
    if Result = TAlphaColors.Null then
    begin
      if FKind = TFmrCaptionButtonKind.Close then
        Result := ClosePressedColor
      else if FDarkMode then
        Result := DarkPressed
      else
        Result := LightPressed;
    end;
  end
  else if FHot then
  begin
    Result := FHotColor;
    if Result = TAlphaColors.Null then
    begin
      if FKind = TFmrCaptionButtonKind.Close then
        Result := CloseHotColor
      else if FDarkMode then
        Result := DarkHot
      else
        Result := LightHot;
    end;
  end;
end;

function TFmrCaptionButton.CurrentGlyphColor: TAlphaColor;
begin
  if (FKind = TFmrCaptionButtonKind.Close) and (FHot or FDown) then
    Exit(TAlphaColors.White);
  if not FActive and not FHot then
  begin
    Result := FInactiveGlyphColor;
    if Result = TAlphaColors.Null then
    begin
      if FDarkMode then
        Result := DarkInactiveGlyph
      else
        Result := LightInactiveGlyph;
    end;
  end
  else
  begin
    Result := FGlyphColor;
    if Result = TAlphaColors.Null then
    begin
      if FDarkMode then
        Result := DarkGlyph
      else
        Result := LightGlyph;
    end;
  end;
end;

procedure TFmrCaptionButton.DrawGlyph(const ACenter: TPointF; const AColor: TAlphaColor);
const
  G = 10; // glyph box, dp
var
  Scale, Px, Half: Single;
  C: TPointF;
  R, Back: TRectF;

  function Snap(const AValue: Single): Single;
  begin
    // Centers 1 px lines on device pixels.
    Result := (Round(AValue * Scale - 0.5) + 0.5) / Scale;
  end;

begin
  if Scene <> nil then
    Scale := Scene.GetSceneScale
  else
    Scale := 1;
  Px := 1 / Scale;
  Half := G / 2;
  C := TPointF.Create(Snap(ACenter.X), Snap(ACenter.Y));
  Canvas.Stroke.Kind := TBrushKind.Solid;
  Canvas.Stroke.Color := AColor;
  Canvas.Stroke.Thickness := Max(1, Round(Scale)) * Px;
  Canvas.Stroke.Cap := TStrokeCap.Flat;
  Canvas.Stroke.Join := TStrokeJoin.Miter;
  Canvas.Stroke.Dash := TStrokeDash.Solid;
  case FKind of
    TFmrCaptionButtonKind.Minimize:
      Canvas.DrawLine(TPointF.Create(C.X - Half, C.Y), TPointF.Create(C.X + Half, C.Y), AbsoluteOpacity);
    TFmrCaptionButtonKind.Maximize:
      if FMaximized then
      begin
        // Restore: a front square and the corner of the square behind it.
        R := TRectF.Create(C.X - Half, C.Y - Half + 2, C.X + Half - 2, C.Y + Half);
        Canvas.DrawRect(R, 1, 1, AllCorners, AbsoluteOpacity);
        Back := TRectF.Create(C.X - Half + 2, C.Y - Half, C.X + Half, C.Y + Half - 2);
        Canvas.DrawLine(TPointF.Create(Back.Left, Back.Top + 1), TPointF.Create(Back.Left, R.Top), AbsoluteOpacity);
        Canvas.DrawLine(TPointF.Create(Back.Left, Back.Top), TPointF.Create(Back.Right - 1, Back.Top),
          AbsoluteOpacity);
        Canvas.DrawLine(TPointF.Create(Back.Right, Back.Top + 1), TPointF.Create(Back.Right, Back.Bottom - 1),
          AbsoluteOpacity);
        Canvas.DrawLine(TPointF.Create(Back.Right, Back.Bottom), TPointF.Create(R.Right, Back.Bottom),
          AbsoluteOpacity);
      end
      else
      begin
        R := TRectF.Create(C.X - Half, C.Y - Half, C.X + Half, C.Y + Half);
        Canvas.DrawRect(R, 1.5, 1.5, AllCorners, AbsoluteOpacity);
      end;
    TFmrCaptionButtonKind.Close:
      begin
        Canvas.DrawLine(TPointF.Create(C.X - Half, C.Y - Half), TPointF.Create(C.X + Half, C.Y + Half),
          AbsoluteOpacity);
        Canvas.DrawLine(TPointF.Create(C.X + Half, C.Y - Half), TPointF.Create(C.X - Half, C.Y + Half),
          AbsoluteOpacity);
      end;
    TFmrCaptionButtonKind.Help:
      begin
        Canvas.Fill.Kind := TBrushKind.Solid;
        Canvas.Fill.Color := AColor;
        Canvas.Font.Size := 13;
        Canvas.FillText(TRectF.Create(C.X - 8, C.Y - 9, C.X + 8, C.Y + 9), '?', False, AbsoluteOpacity, [],
          TTextAlign.Center, TTextAlign.Center);
      end;
  end;
end;

procedure TFmrCaptionButton.Paint;
var
  Back: TAlphaColor;
begin
  Back := CurrentBackground;
  if (Back and $FF000000) <> 0 then
  begin
    Canvas.Fill.Kind := TBrushKind.Solid;
    Canvas.Fill.Color := Back;
    Canvas.FillRect(LocalRect, 0, 0, [], AbsoluteOpacity);
  end;
  DrawGlyph(TPointF.Create(Width / 2, Height / 2), CurrentGlyphColor);
end;

{ TFmrCaptionTitle }

constructor TFmrCaptionTitle.Create(AOwner: TComponent);
begin
  inherited;
  FFont := TFont.Create;
  FFont.Size := 12;
  FFont.OnChanged := FontChanged;
  FTextColor := TAlphaColors.Null;
  FInactiveTextColor := TAlphaColors.Null;
  FHorzAlign := TTextAlign.Leading;
  FActive := True;
  HitTest := False;
end;

destructor TFmrCaptionTitle.Destroy;
begin
  FreeAndNil(FFont);
  inherited;
end;

procedure TFmrCaptionTitle.FontChanged(Sender: TObject);
begin
  Repaint;
end;

procedure TFmrCaptionTitle.SetFont(const Value: TFont);
begin
  FFont.Assign(Value);
end;

procedure TFmrCaptionTitle.SetText(const Value: string);
begin
  if FText <> Value then
  begin
    FText := Value;
    Repaint;
  end;
end;

procedure TFmrCaptionTitle.SetTextColor(const Value: TAlphaColor);
begin
  if FTextColor <> Value then
  begin
    FTextColor := Value;
    Repaint;
  end;
end;

procedure TFmrCaptionTitle.SetInactiveTextColor(const Value: TAlphaColor);
begin
  if FInactiveTextColor <> Value then
  begin
    FInactiveTextColor := Value;
    Repaint;
  end;
end;

procedure TFmrCaptionTitle.SetHorzAlign(const Value: TTextAlign);
begin
  if FHorzAlign <> Value then
  begin
    FHorzAlign := Value;
    Repaint;
  end;
end;

procedure TFmrCaptionTitle.FrameStateChanged(const AState: TFmrFrameState);
begin
  if (FActive <> AState.Active) or (FDarkMode <> AState.DarkMode) then
  begin
    FActive := AState.Active;
    FDarkMode := AState.DarkMode;
    Repaint;
  end;
end;

procedure TFmrCaptionTitle.Paint;
var
  Color: TAlphaColor;
begin
  if FActive then
  begin
    Color := FTextColor;
    if Color = TAlphaColors.Null then
    begin
      if FDarkMode then
        Color := DarkGlyph
      else
        Color := LightGlyph;
    end;
  end
  else
  begin
    Color := FInactiveTextColor;
    if Color = TAlphaColors.Null then
    begin
      if FDarkMode then
        Color := DarkInactiveGlyph
      else
        Color := LightInactiveGlyph;
    end;
  end;
  Canvas.Font.Assign(FFont);
  Canvas.Fill.Kind := TBrushKind.Solid;
  Canvas.Fill.Color := Color;
  Canvas.FillText(LocalRect, FText, False, AbsoluteOpacity, [], FHorzAlign, TTextAlign.Center);
end;

end.
