{*******************************************************}
{                                                       }
{  FMR Ribbon for FireMonkey                            }
{  Right-to-left helpers shared by the ribbon units     }
{                                                       }
{  MIT License. Copyright (c) 2026 Fasday               }
{                                                       }
{*******************************************************}

unit FMR.Ribbon.BiDi;

/// Right-to-left works like WS_EX_LAYOUTRTL on Windows: the ribbon parts, group popups and menus keep their element
/// geometry left to right ("logical" coordinates) and flip their canvas horizontally while painting; mouse
/// coordinates are flipped the same way before hit testing. The painter draws text unmirrored inside its rectangle
/// and swaps leading and trailing alignment (TFmrRibbonPainter.IsMirrored). Real FMX controls placed by a mirrored
/// host (editors, the search box, caption buttons) get mirrored bounds. A host or popup context tells it is mirrored
/// through IFmrMirroredHost.

interface

uses
  System.Types, System.UITypes, System.Math.Vectors, FMX.Graphics, FMX.ImgList, FMR.Bars.Images;

type
  /// <summary>Implemented by element hosts and popup contexts that are laid out right to left.</summary>
  IFmrMirroredHost = interface
    ['{6F3C2A91-0B7E-4D58-9C21-7E4A5B8D3F60}']
    function IsMirrored: Boolean;
  end;

/// <summary>True when AObject implements IFmrMirroredHost and is mirrored.</summary>
function FmrIsMirrored(const AObject: IInterface): Boolean;
/// <summary>R mirrored inside a host of width AWidth (logical to physical and back).</summary>
function FmrMirrorRect(const R: TRectF; const AWidth: Single): TRectF; inline;
function FmrMirrorX(const X, AWidth: Single): Single; inline;
/// <summary>Flips the canvas of a host of width AWidth horizontally (call after SaveState).</summary>
procedure FmrMirrorCanvas(const ACanvas: TCanvas; const AWidth: Single);
/// <summary>TFmrImageSource.Draw that keeps the image unmirrored on a mirrored canvas (like NOMIRRORBITMAP):
/// command icons are mostly letters and pictures that must not be read backwards.</summary>
procedure FmrDrawImage(const ACanvas: TCanvas; const AImage: TFmrImageSource; const R: TRectF;
  const AOpacity: Single; const ATint: TAlphaColor; const AImages: TCustomImageList);

implementation

uses
  System.SysUtils;

function FmrIsMirrored(const AObject: IInterface): Boolean;
var
  M: IFmrMirroredHost;
begin
  Result := (AObject <> nil) and Supports(AObject, IFmrMirroredHost, M) and M.IsMirrored;
end;

function FmrMirrorRect(const R: TRectF; const AWidth: Single): TRectF;
begin
  Result := RectF(AWidth - R.Right, R.Top, AWidth - R.Left, R.Bottom);
end;

function FmrMirrorX(const X, AWidth: Single): Single;
begin
  Result := AWidth - X;
end;

procedure FmrMirrorCanvas(const ACanvas: TCanvas; const AWidth: Single);
begin
  ACanvas.MultiplyMatrix(TMatrix.CreateScaling(-1, 1) * TMatrix.CreateTranslation(AWidth, 0));
end;

procedure FmrDrawImage(const ACanvas: TCanvas; const AImage: TFmrImageSource; const R: TRectF;
  const AOpacity: Single; const ATint: TAlphaColor; const AImages: TCustomImageList);
var
  Saved: TMatrix;
begin
  if (AImage = nil) or (ACanvas = nil) then
    Exit;
  if ACanvas.Matrix.m11 >= 0 then
  begin
    AImage.Draw(ACanvas, R, AOpacity, ATint, AImages);
    Exit;
  end;
  Saved := ACanvas.Matrix;
  ACanvas.MultiplyMatrix(TMatrix.CreateScaling(-1, 1) * TMatrix.CreateTranslation(R.Left + R.Right, 0));
  try
    AImage.Draw(ACanvas, R, AOpacity, ATint, AImages);
  finally
    ACanvas.SetMatrix(Saved);
  end;
end;

end.
