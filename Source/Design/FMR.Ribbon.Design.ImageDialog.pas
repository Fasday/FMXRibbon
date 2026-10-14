{*******************************************************}
{                                                       }
{  FMR Ribbon for FireMonkey                            }
{  Design time: image source dialog                     }
{                                                       }
{  MIT License. Copyright (c) 2026 Fasday               }
{                                                       }
{*******************************************************}

unit FMR.Ribbon.Design.ImageDialog;

/// Modal VCL dialog that edits a TFmrImageSource: kind, color, recolor and one page per source: image list (grid of
/// the images of the bar manager), icon font (font family, searchable glyph grid with code points and names), SVG
/// (paste or load a file) and path data (paste, view box). The preview is drawn by TFmrImageSource.Draw itself on
/// an FMX bitmap canvas (so it shows exactly what the ribbon paints), at four sizes on a light and a dark background.

interface

uses
  System.SysUtils, System.Classes, FMX.ImgList, FMR.Bars.Images;

/// <summary>Edits AImage in a modal dialog; AImages: the image list of the bar manager (may be nil); APage: the page
/// to open (Auto: the page of the current kind). True when the user pressed OK (AImage changed).</summary>
function FmrEditImageSource(const AImage: TFmrImageSource; const AImages: TCustomImageList;
  const ACaption: string = ''; const APage: TFmrImageKind = TFmrImageKind.Auto): Boolean;

implementation

uses
  Winapi.Windows, Winapi.Messages, System.Types, System.UITypes, System.Math, System.Generics.Collections,
  Vcl.Controls, Vcl.Forms, Vcl.Graphics, Vcl.StdCtrls, Vcl.ExtCtrls, Vcl.ComCtrls, Vcl.Grids, Vcl.Dialogs,
  FMR.Ribbon.Design.Bridge, FMR.Ribbon.Design.Graphics;

type
  TImageSourceDialog = class(TForm)
  private
    FWork: TFmrImageSource;
    FImages: TCustomImageList;
    FUpdating: Boolean;
    FKind: TComboBox;
    FColorCheck: TCheckBox;
    FColorButton: TButton;
    FColorShape: TShape;
    FRecolor: TCheckBox;
    FPages: TPageControl;
    FPageImages, FPageGlyph, FPageSvg, FPagePath: TTabSheet;
    FImageGrid: TDrawGrid;
    FImageCache: TObjectDictionary<Integer, Vcl.Graphics.TBitmap>;
    FFontCombo: TComboBox;
    FSearch: TEdit;
    FGlyphGrid: TDrawGrid;
    FGlyphInfo: TLabel;
    FCodeEdit: TEdit;
    FAllGlyphs: TArray<Cardinal>;
    FGlyphs: TArray<Cardinal>;
    FSvgMemo: TMemo;
    FPathMemo: TMemo;
    FViewBox: TEdit;
    FPreview: TPaintBox;
    FPreviewCache: TObjectList<Vcl.Graphics.TBitmap>;
    FCellSize: Integer;
    procedure BuildControls;
    procedure LoadFromWork;
    procedure KindChange(Sender: TObject);
    procedure ColorClick(Sender: TObject);
    procedure ColorCheckClick(Sender: TObject);
    procedure RecolorClick(Sender: TObject);
    procedure ImageGridDraw(Sender: TObject; ACol, ARow: Integer; Rect: TRect; State: TGridDrawState);
    procedure ImageGridSelect(Sender: TObject; ACol, ARow: Integer; var CanSelect: Boolean);
    procedure FontChange(Sender: TObject);
    procedure SearchChange(Sender: TObject);
    procedure FillGlyphs;
    procedure GlyphGridDraw(Sender: TObject; ACol, ARow: Integer; Rect: TRect; State: TGridDrawState);
    procedure GlyphGridSelect(Sender: TObject; ACol, ARow: Integer; var CanSelect: Boolean);
    procedure GlyphGridResize(Sender: TObject);
    procedure CodeEditChange(Sender: TObject);
    procedure SvgChange(Sender: TObject);
    procedure SvgLoadClick(Sender: TObject);
    procedure PathChange(Sender: TObject);
    procedure ClearClick(Sender: TObject);
    procedure PreviewPaint(Sender: TObject);
    procedure WorkChanged;
    procedure UpdateGlyphInfo;
    procedure SelectGlyphCell;
    function GlyphFamily: string;
  public
    constructor CreateDialog(const AImage: TFmrImageSource; const AImages: TCustomImageList; const ACaption: string;
      const APage: TFmrImageKind);
    destructor Destroy; override;
    property Work: TFmrImageSource read FWork;
  end;

function FmrEditImageSource(const AImage: TFmrImageSource; const AImages: TCustomImageList; const ACaption: string;
  const APage: TFmrImageKind): Boolean;
var
  D: TImageSourceDialog;
begin
  D := TImageSourceDialog.CreateDialog(AImage, AImages, ACaption, APage);
  try
    Result := D.ShowModal = mrOk;
    if Result then
      AImage.Assign(D.Work);
  finally
    D.Free;
  end;
end;

const
  KindNames: array[TFmrImageKind] of string = ('Auto (SVG, glyph, path, image list)', 'None', 'Image list',
    'SVG', 'Icon font glyph', 'Path');

{ TImageSourceDialog }

constructor TImageSourceDialog.CreateDialog(const AImage: TFmrImageSource; const AImages: TCustomImageList;
  const ACaption: string; const APage: TFmrImageKind);
var
  Page: TFmrImageKind;
begin
  inherited CreateNew(Application);
  FWork := TFmrImageSource.Create(nil);
  FWork.Assign(AImage);
  FImages := AImages;
  FImageCache := TObjectDictionary<Integer, Vcl.Graphics.TBitmap>.Create([doOwnsValues]);
  FPreviewCache := TObjectList<Vcl.Graphics.TBitmap>.Create;
  if ACaption <> '' then
    Caption := ACaption
  else
    Caption := 'Image';
  Position := poScreenCenter;
  BorderIcons := [biSystemMenu, biMaximize];
  Font.Name := 'Segoe UI';
  Font.Height := -12;
  ClientWidth := 760;
  ClientHeight := 520;
  FCellSize := 52;
  BuildControls;
  FAllGlyphs := FmrIconFontGlyphs(GlyphFamily);
  FillGlyphs;
  LoadFromWork;
  Page := APage;
  if Page = TFmrImageKind.Auto then
    Page := FWork.EffectiveKind;
  case Page of
    TFmrImageKind.ImageList:
      FPages.ActivePage := FPageImages;
    TFmrImageKind.Svg:
      FPages.ActivePage := FPageSvg;
    TFmrImageKind.Path:
      FPages.ActivePage := FPagePath;
  else
    FPages.ActivePage := FPageGlyph;
  end;
  FCellSize := MulDiv(52, FmrDesignMonitorPPI, 96);
  FmrDesignFinishForm(Self);
  GlyphGridResize(nil);
  SelectGlyphCell;
end;

destructor TImageSourceDialog.Destroy;
begin
  FPreviewCache.Free;
  FImageCache.Free;
  FWork.Free;
  inherited;
end;

function TImageSourceDialog.GlyphFamily: string;
begin
  if (FFontCombo <> nil) and (FFontCombo.Text <> '') then
    Result := FFontCombo.Text
  else if FWork.GlyphFontFamily <> '' then
    Result := FWork.GlyphFontFamily
  else
    Result := FmrIconFontFamily;
end;

procedure TImageSourceDialog.BuildControls;
var
  Top, Bottom, Right, P: TPanel;
  Lbl: TLabel;
  B: TButton;
  K: TFmrImageKind;
  S: string;
begin
  Top := TPanel.Create(Self);
  Top.Parent := Self;
  Top.Align := alTop;
  Top.Height := 38;
  Top.BevelOuter := bvNone;
  Lbl := TLabel.Create(Self);
  Lbl.Parent := Top;
  Lbl.Caption := 'Kind:';
  Lbl.SetBounds(10, 11, 34, 16);
  FKind := TComboBox.Create(Self);
  FKind.Parent := Top;
  FKind.Style := csDropDownList;
  FKind.SetBounds(46, 7, 230, 22);
  for K := Low(TFmrImageKind) to High(TFmrImageKind) do
    FKind.Items.Add(KindNames[K]);
  FKind.OnChange := KindChange;
  FColorCheck := TCheckBox.Create(Self);
  FColorCheck.Parent := Top;
  FColorCheck.Caption := 'Fixed color';
  FColorCheck.SetBounds(294, 9, 86, 20);
  FColorCheck.OnClick := ColorCheckClick;
  FColorShape := TShape.Create(Self);
  FColorShape.Parent := Top;
  FColorShape.SetBounds(382, 9, 20, 20);
  FColorButton := TButton.Create(Self);
  FColorButton.Parent := Top;
  FColorButton.Caption := 'Color...';
  FColorButton.SetBounds(408, 6, 70, 26);
  FColorButton.OnClick := ColorClick;
  FRecolor := TCheckBox.Create(Self);
  FRecolor.Parent := Top;
  FRecolor.Caption := 'Recolor images';
  FRecolor.Hint := 'SVG and image list images are drawn as one-color masks (Color or the theme''s glyph color)';
  FRecolor.ShowHint := True;
  FRecolor.SetBounds(490, 9, 200, 20);
  FRecolor.OnClick := RecolorClick;

  Bottom := TPanel.Create(Self);
  Bottom.Parent := Self;
  Bottom.Align := alBottom;
  Bottom.Height := 44;
  Bottom.BevelOuter := bvNone;
  B := TButton.Create(Self);
  B.Parent := Bottom;
  B.Caption := 'Cancel';
  B.Cancel := True;
  B.ModalResult := mrCancel;
  B.SetBounds(ClientWidth - 92, 9, 80, 26);
  B.Anchors := [akRight, akTop];
  B := TButton.Create(Self);
  B.Parent := Bottom;
  B.Caption := 'OK';
  B.Default := True;
  B.ModalResult := mrOk;
  B.SetBounds(ClientWidth - 180, 9, 80, 26);
  B.Anchors := [akRight, akTop];
  B := TButton.Create(Self);
  B.Parent := Bottom;
  B.Caption := 'Clear Image';
  B.SetBounds(10, 9, 100, 26);
  B.OnClick := ClearClick;

  Right := TPanel.Create(Self);
  Right.Parent := Self;
  Right.Align := alRight;
  Right.Width := 200;
  Right.BevelOuter := bvNone;
  Lbl := TLabel.Create(Self);
  Lbl.Parent := Right;
  Lbl.Align := alTop;
  Lbl.AlignWithMargins := True;
  Lbl.Caption := 'Preview (16, 24, 32, 48 dp)';
  FPreview := TPaintBox.Create(Self);
  FPreview.Parent := Right;
  FPreview.Align := alClient;
  FPreview.AlignWithMargins := True;
  FPreview.OnPaint := PreviewPaint;

  FPages := TPageControl.Create(Self);
  FPages.Parent := Self;
  FPages.Align := alClient;
  FPages.AlignWithMargins := True;

  { image list }
  FPageImages := TTabSheet.Create(Self);
  FPageImages.PageControl := FPages;
  FPageImages.Caption := 'Image list';
  FImageGrid := TDrawGrid.Create(Self);
  FImageGrid.Parent := FPageImages;
  FImageGrid.Align := alClient;
  FImageGrid.FixedCols := 0;
  FImageGrid.FixedRows := 0;
  FImageGrid.DefaultColWidth := 56;
  FImageGrid.DefaultRowHeight := 56;
  FImageGrid.ColCount := 8;
  FImageGrid.Options := [goDrawFocusSelected, goThumbTracking];
  FImageGrid.OnDrawCell := ImageGridDraw;
  FImageGrid.OnSelectCell := ImageGridSelect;
  if (FImages = nil) or (FImages.Count = 0) then
  begin
    FImageGrid.RowCount := 1;
    Lbl := TLabel.Create(Self);
    Lbl.Parent := FPageImages;
    Lbl.Align := alTop;
    Lbl.AlignWithMargins := True;
    if FImages = nil then
      Lbl.Caption := 'The bar manager has no image list (TFmrBarManager.Images).'
    else
      Lbl.Caption := 'The image list is empty.';
  end
  else
    FImageGrid.RowCount := Max(1, (FImages.Count + FImageGrid.ColCount - 1) div FImageGrid.ColCount);

  { icon font }
  FPageGlyph := TTabSheet.Create(Self);
  FPageGlyph.PageControl := FPages;
  FPageGlyph.Caption := 'Icon font';
  P := TPanel.Create(Self);
  P.Parent := FPageGlyph;
  P.Align := alTop;
  P.Height := 34;
  P.BevelOuter := bvNone;
  Lbl := TLabel.Create(Self);
  Lbl.Parent := P;
  Lbl.Caption := 'Font:';
  Lbl.SetBounds(6, 9, 32, 16);
  FFontCombo := TComboBox.Create(Self);
  FFontCombo.Parent := P;
  FFontCombo.SetBounds(40, 5, 170, 22);
  FFontCombo.Items.Add('');
  for S in FmrInstalledIconFonts do
    FFontCombo.Items.Add(S);
  FFontCombo.OnChange := FontChange;
  FFontCombo.Hint := 'Empty: the default icon font (Segoe Fluent Icons on Windows 11, Segoe MDL2 Assets on ' +
    'Windows 10)';
  FFontCombo.ShowHint := True;
  FSearch := TEdit.Create(Self);
  FSearch.Parent := P;
  FSearch.SetBounds(220, 5, 160, 22);
  FSearch.TextHint := 'Search: name or code';
  FSearch.OnChange := SearchChange;
  Lbl := TLabel.Create(Self);
  Lbl.Parent := P;
  Lbl.Caption := 'Code:';
  Lbl.SetBounds(390, 9, 34, 16);
  FCodeEdit := TEdit.Create(Self);
  FCodeEdit.Parent := P;
  FCodeEdit.SetBounds(426, 5, 64, 22);
  FCodeEdit.CharCase := ecUpperCase;
  FCodeEdit.OnChange := CodeEditChange;
  FGlyphInfo := TLabel.Create(Self);
  FGlyphInfo.Parent := FPageGlyph;
  FGlyphInfo.Align := alBottom;
  FGlyphInfo.AlignWithMargins := True;
  FGlyphInfo.Caption := ' ';
  FGlyphGrid := TDrawGrid.Create(Self);
  FGlyphGrid.Parent := FPageGlyph;
  FGlyphGrid.Align := alClient;
  FGlyphGrid.FixedCols := 0;
  FGlyphGrid.FixedRows := 0;
  FGlyphGrid.DefaultColWidth := 52;
  FGlyphGrid.DefaultRowHeight := 52;
  FGlyphGrid.Options := [goDrawFocusSelected, goThumbTracking];
  FGlyphGrid.OnDrawCell := GlyphGridDraw;
  FGlyphGrid.OnSelectCell := GlyphGridSelect;
  OnResize := GlyphGridResize;

  { SVG }
  FPageSvg := TTabSheet.Create(Self);
  FPageSvg.PageControl := FPages;
  FPageSvg.Caption := 'SVG';
  P := TPanel.Create(Self);
  P.Parent := FPageSvg;
  P.Align := alTop;
  P.Height := 34;
  P.BevelOuter := bvNone;
  B := TButton.Create(Self);
  B.Parent := P;
  B.Caption := 'Load file...';
  B.SetBounds(6, 4, 90, 26);
  B.OnClick := SvgLoadClick;
  Lbl := TLabel.Create(Self);
  Lbl.Parent := P;
  Lbl.Caption := 'Paste the SVG document below (rendered with Skia).';
  Lbl.SetBounds(106, 9, 300, 16);
  FSvgMemo := TMemo.Create(Self);
  FSvgMemo.Parent := FPageSvg;
  FSvgMemo.Align := alClient;
  FSvgMemo.ScrollBars := ssBoth;
  FSvgMemo.WordWrap := False;
  FSvgMemo.Font.Name := 'Consolas';
  FSvgMemo.OnChange := SvgChange;

  { path }
  FPagePath := TTabSheet.Create(Self);
  FPagePath.PageControl := FPages;
  FPagePath.Caption := 'Path';
  P := TPanel.Create(Self);
  P.Parent := FPagePath;
  P.Align := alTop;
  P.Height := 34;
  P.BevelOuter := bvNone;
  Lbl := TLabel.Create(Self);
  Lbl.Parent := P;
  Lbl.Caption := 'View box (0 = fit the bounds of the path):';
  Lbl.SetBounds(6, 9, 230, 16);
  FViewBox := TEdit.Create(Self);
  FViewBox.Parent := P;
  FViewBox.SetBounds(240, 5, 60, 22);
  FViewBox.OnChange := PathChange;
  FPathMemo := TMemo.Create(Self);
  FPathMemo.Parent := FPagePath;
  FPathMemo.Align := alClient;
  FPathMemo.ScrollBars := ssVertical;
  FPathMemo.Font.Name := 'Consolas';
  FPathMemo.OnChange := PathChange;
end;

procedure TImageSourceDialog.LoadFromWork;
begin
  FUpdating := True;
  try
    FKind.ItemIndex := Ord(FWork.Kind);
    FColorCheck.Checked := FWork.Color <> TAlphaColors.Null;
    FColorShape.Brush.Color := FmrAlphaColorToColor(FWork.Color);
    FColorShape.Visible := FColorCheck.Checked;
    FColorButton.Enabled := FColorCheck.Checked;
    FRecolor.Checked := FWork.Recolor;
    FFontCombo.Text := FWork.GlyphFontFamily;
    if FWork.GlyphCode <> 0 then
      FCodeEdit.Text := IntToHex(FWork.GlyphCode, 4)
    else
      FCodeEdit.Text := '';
    FSvgMemo.Text := FWork.SvgSource;
    FPathMemo.Text := FWork.PathData;
    FViewBox.Text := FloatToStr(FWork.PathViewBox);
  finally
    FUpdating := False;
  end;
  UpdateGlyphInfo;
  WorkChanged;
end;

procedure TImageSourceDialog.WorkChanged;
begin
  FPreviewCache.Clear;
  FPreview.Invalidate;
  FKind.Hint := 'Drawn: ' + KindNames[FWork.EffectiveKind];
  FKind.ShowHint := True;
end;

procedure TImageSourceDialog.KindChange(Sender: TObject);
begin
  if FUpdating then
    Exit;
  FWork.Kind := TFmrImageKind(FKind.ItemIndex);
  WorkChanged;
end;

procedure TImageSourceDialog.ColorCheckClick(Sender: TObject);
begin
  if FUpdating then
    Exit;
  if FColorCheck.Checked then
  begin
    if FWork.Color = TAlphaColors.Null then
      FWork.Color := TAlphaColors.Black;
  end
  else
    FWork.Color := TAlphaColors.Null;
  FColorShape.Brush.Color := FmrAlphaColorToColor(FWork.Color);
  FColorShape.Visible := FColorCheck.Checked;
  FColorButton.Enabled := FColorCheck.Checked;
  WorkChanged;
end;

procedure TImageSourceDialog.ColorClick(Sender: TObject);
var
  D: TColorDialog;
begin
  D := TColorDialog.Create(Self);
  try
    D.Color := FmrAlphaColorToColor(FWork.Color);
    D.Options := [cdFullOpen, cdAnyColor];
    if D.Execute(Handle) then
    begin
      FWork.Color := FmrColorToAlphaColor(D.Color);
      FColorShape.Brush.Color := D.Color;
      WorkChanged;
    end;
  finally
    D.Free;
  end;
end;

procedure TImageSourceDialog.RecolorClick(Sender: TObject);
begin
  if FUpdating then
    Exit;
  FWork.Recolor := FRecolor.Checked;
  WorkChanged;
end;

procedure TImageSourceDialog.ClearClick(Sender: TObject);
var
  Empty: TFmrImageSource;
begin
  Empty := TFmrImageSource.Create(nil);
  try
    FWork.Assign(Empty);
  finally
    Empty.Free;
  end;
  LoadFromWork;
end;

{ image list page }

procedure TImageSourceDialog.ImageGridDraw(Sender: TObject; ACol, ARow: Integer; Rect: TRect;
  State: TGridDrawState);
var
  Index, S: Integer;
  B: Vcl.Graphics.TBitmap;
  C: Vcl.Graphics.TCanvas;
  R: TRect;
begin
  C := FImageGrid.Canvas;
  Index := ARow * FImageGrid.ColCount + ACol;
  if (FImages <> nil) and (Index = FWork.ImageIndex) then
    C.Brush.Color := clHighlight
  else
    C.Brush.Color := clWindow;
  C.FillRect(Rect);
  if (FImages = nil) or (Index >= FImages.Count) then
    Exit;
  if not FImageCache.TryGetValue(Index, B) then
  begin
    B := FmrRenderImageListEntry(FImages, Index, FImageGrid.DefaultRowHeight - 22);
    FImageCache.Add(Index, B);
  end;
  if B <> nil then
  begin
    S := B.Width;
    R := System.Types.Rect(Rect.Left + (Rect.Width - S) div 2, Rect.Top + 3, 0, 0);
    C.Draw(R.Left, R.Top, B);
  end;
  C.Font.Height := -10;
  if Index = FWork.ImageIndex then
    C.Font.Color := clHighlightText
  else
    C.Font.Color := clGrayText;
  C.Brush.Style := bsClear;
  R := Rect;
  R.Top := R.Bottom - 16;
  DrawText(C.Handle, PChar(IntToStr(Index)), -1, R, DT_CENTER or DT_SINGLELINE);
  C.Brush.Style := bsSolid;
end;

procedure TImageSourceDialog.ImageGridSelect(Sender: TObject; ACol, ARow: Integer; var CanSelect: Boolean);
var
  Index: Integer;
begin
  if (FImages = nil) or FUpdating then
    Exit;
  Index := ARow * FImageGrid.ColCount + ACol;
  if Index < FImages.Count then
  begin
    FWork.ImageIndex := Index;
    if FWork.Kind <> TFmrImageKind.Auto then
    begin
      FWork.Kind := TFmrImageKind.ImageList;
      FKind.ItemIndex := Ord(FWork.Kind);
    end;
    FImageGrid.Invalidate;
    WorkChanged;
  end;
end;

{ glyph page }

procedure TImageSourceDialog.FontChange(Sender: TObject);
begin
  if FUpdating then
    Exit;
  FWork.GlyphFontFamily := FFontCombo.Text;
  FAllGlyphs := FmrIconFontGlyphs(GlyphFamily);
  FillGlyphs;
  WorkChanged;
end;

procedure TImageSourceDialog.SearchChange(Sender: TObject);
begin
  FillGlyphs;
end;

procedure TImageSourceDialog.FillGlyphs;
var
  F: string;
  L: TList<Cardinal>;
  C: Cardinal;
  Hex, Name: string;
begin
  F := LowerCase(Trim(FSearch.Text));
  L := TList<Cardinal>.Create;
  try
    for C in FAllGlyphs do
    begin
      if F <> '' then
      begin
        Hex := IntToHex(C, 4).ToLower;
        Name := FmrGlyphName(C).ToLower;
        if not (Hex.Contains(F) or Name.Contains(F)) then
          Continue;
      end;
      L.Add(C);
    end;
    FGlyphs := L.ToArray;
  finally
    L.Free;
  end;
  GlyphGridResize(nil);
  FGlyphGrid.Invalidate;
  SelectGlyphCell;
end;

procedure TImageSourceDialog.GlyphGridResize(Sender: TObject);
var
  Cols: Integer;
begin
  if FGlyphGrid = nil then
    Exit;
  FGlyphGrid.DefaultColWidth := FCellSize;
  FGlyphGrid.DefaultRowHeight := FCellSize;
  Cols := Max(1, (FGlyphGrid.ClientWidth - 2) div (FCellSize + FGlyphGrid.GridLineWidth));
  if FGlyphGrid.ColCount <> Cols then
    FGlyphGrid.ColCount := Cols;
  FGlyphGrid.RowCount := Max(1, (Length(FGlyphs) + Cols - 1) div Cols);
end;

procedure TImageSourceDialog.GlyphGridDraw(Sender: TObject; ACol, ARow: Integer; Rect: TRect;
  State: TGridDrawState);
var
  Index: Integer;
  C: Vcl.Graphics.TCanvas;
  Code: Cardinal;
  R: TRect;
  Sel: Boolean;
begin
  C := FGlyphGrid.Canvas;
  Index := ARow * FGlyphGrid.ColCount + ACol;
  Code := 0;
  if Index < Length(FGlyphs) then
    Code := FGlyphs[Index];
  Sel := (Code <> 0) and (Code = FWork.GlyphCode);
  if Sel then
    C.Brush.Color := clHighlight
  else
    C.Brush.Color := clWindow;
  C.FillRect(Rect);
  if Code = 0 then
    Exit;
  R := Rect;
  R.Bottom := R.Bottom - Rect.Height div 4;
  if Sel then
    FmrDrawGlyphText(C, R, Code, GlyphFamily, clHighlightText, Rect.Height * 2 div 5)
  else
    FmrDrawGlyphText(C, R, Code, GlyphFamily, clWindowText, Rect.Height * 2 div 5);
  C.Font.Name := Font.Name;
  C.Font.Height := -Max(9, Rect.Height div 5);
  if Sel then
    C.Font.Color := clHighlightText
  else
    C.Font.Color := clGrayText;
  R := Rect;
  R.Top := R.Bottom - Rect.Height div 3;
  DrawText(C.Handle, PChar(IntToHex(Code, 4)), -1, R, DT_CENTER or DT_SINGLELINE or DT_VCENTER);
  C.Brush.Style := bsSolid;
end;

procedure TImageSourceDialog.SelectGlyphCell;
var
  I, Cols: Integer;
begin
  Cols := FGlyphGrid.ColCount;
  for I := 0 to High(FGlyphs) do
    if FGlyphs[I] = FWork.GlyphCode then
    begin
      FUpdating := True;
      try
        FGlyphGrid.Row := I div Cols;
        FGlyphGrid.Col := I mod Cols;
      finally
        FUpdating := False;
      end;
      Exit;
    end;
end;

procedure TImageSourceDialog.GlyphGridSelect(Sender: TObject; ACol, ARow: Integer; var CanSelect: Boolean);
var
  Index: Integer;
begin
  if FUpdating then
    Exit;
  Index := ARow * FGlyphGrid.ColCount + ACol;
  if Index >= Length(FGlyphs) then
  begin
    CanSelect := False;
    Exit;
  end;
  FWork.GlyphCode := FGlyphs[Index];
  if FWork.Kind <> TFmrImageKind.Auto then
  begin
    FWork.Kind := TFmrImageKind.Glyph;
    FKind.ItemIndex := Ord(FWork.Kind);
  end;
  FUpdating := True;
  try
    FCodeEdit.Text := IntToHex(FWork.GlyphCode, 4);
  finally
    FUpdating := False;
  end;
  FGlyphGrid.Invalidate;
  UpdateGlyphInfo;
  WorkChanged;
end;

procedure TImageSourceDialog.CodeEditChange(Sender: TObject);
var
  V: Integer;
begin
  if FUpdating then
    Exit;
  if TryStrToInt('$' + Trim(FCodeEdit.Text), V) and (V >= 0) and (V <= $10FFFF) then
  begin
    FWork.GlyphCode := Cardinal(V);
    FGlyphGrid.Invalidate;
    SelectGlyphCell;
    UpdateGlyphInfo;
    WorkChanged;
  end;
end;

procedure TImageSourceDialog.UpdateGlyphInfo;
var
  Name: string;
begin
  if FWork.GlyphCode = 0 then
    FGlyphInfo.Caption := Format('%d glyphs. Click a glyph to use it.', [Length(FGlyphs)])
  else
  begin
    Name := FmrGlyphName(FWork.GlyphCode);
    if Name <> '' then
      Name := ' - ' + Name;
    FGlyphInfo.Caption := Format('Glyph $%s%s (%d glyphs shown)', [IntToHex(FWork.GlyphCode, 4), Name,
      Length(FGlyphs)]);
  end;
end;

{ SVG and path pages }

procedure TImageSourceDialog.SvgChange(Sender: TObject);
begin
  if FUpdating then
    Exit;
  FWork.SvgSource := FSvgMemo.Text;
  WorkChanged;
end;

procedure TImageSourceDialog.SvgLoadClick(Sender: TObject);
var
  D: TOpenDialog;
begin
  D := TOpenDialog.Create(Self);
  try
    D.Filter := 'SVG files (*.svg)|*.svg|All files (*.*)|*.*';
    D.Options := [ofFileMustExist, ofEnableSizing];
    if D.Execute(Handle) then
      FSvgMemo.Lines.LoadFromFile(D.FileName, TEncoding.UTF8);
  finally
    D.Free;
  end;
end;

procedure TImageSourceDialog.PathChange(Sender: TObject);
var
  V: Double;
begin
  if FUpdating then
    Exit;
  FWork.PathData := Trim(FPathMemo.Text);
  if TryStrToFloat(FViewBox.Text, V) and (V >= 0) then
    FWork.PathViewBox := V;
  WorkChanged;
end;

{ preview }

procedure TImageSourceDialog.PreviewPaint(Sender: TObject);
const
  Sizes: array[0..3] of Integer = (16, 24, 32, 48);
var
  C: Vcl.Graphics.TCanvas;
  Scale: Double;
  I, Y, S, Half: Integer;
  B: Vcl.Graphics.TBitmap;
  Back: TColor;
  Dark: Boolean;
  Tint: TAlphaColor;
begin
  C := FPreview.Canvas;
  Scale := CurrentPPI / 96;
  Half := FPreview.Width div 2;
  C.Brush.Color := $00F3F3F3;
  C.FillRect(Rect(0, 0, Half, FPreview.Height));
  C.Brush.Color := $00292929;
  C.FillRect(Rect(Half, 0, FPreview.Width, FPreview.Height));
  if FPreviewCache.Count = 0 then
    for Dark := False to True do
      for I := 0 to High(Sizes) do
      begin
        if Dark then
          Tint := $FFF0F0F0
        else
          Tint := $FF262626;
        FPreviewCache.Add(FmrRenderImageSource(FWork, FImages, Round(Sizes[I] * Scale), Tint));
      end;
  for Dark := False to True do
  begin
    Y := Round(8 * Scale);
    if Dark then
      Back := $00292929
    else
      Back := $00F3F3F3;
    for I := 0 to High(Sizes) do
    begin
      S := Round(Sizes[I] * Scale);
      B := FPreviewCache[Ord(Dark) * Length(Sizes) + I];
      if B <> nil then
        C.Draw(Ord(Dark) * Half + (Half - S) div 2, Y, B)
      else if I = 0 then
      begin
        C.Brush.Color := Back;
        C.Font.Color := clGrayText;
        C.TextOut(Ord(Dark) * Half + 8, Y, '(nothing)');
      end;
      Inc(Y, S + Round(14 * Scale));
    end;
  end;
end;

end.
