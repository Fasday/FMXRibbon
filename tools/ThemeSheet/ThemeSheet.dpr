program ThemeSheet;

/// Renders a sheet of ribbon parts for every built-in theme into shots\themes\<Theme>.png (offscreen bitmaps, no
/// window), to check the painter and the theme colors without the ribbon control.

uses
  System.SysUtils, System.Classes, System.Types, System.UITypes, System.IOUtils, System.Math.Vectors, FMX.Types, FMX.Graphics, FMX.Forms,
  FMR.Ribbon.Theme, FMR.Ribbon.Themes.Builtin, FMR.Ribbon.Painter;

{$R WinApp.res}

procedure RenderTheme(const AName, AOutDir: string);
const
  W = 760;
  H = 300;
var
  Theme: TFmrTheme;
  P: TFmrRibbonPainter;
  Bmp: TBitmap;
  C: TCanvas;
  M: TFmrThemeMetrics;
  Y, X, TabW: Single;
  R, BodyR, G1, G2: TRectF;
  I: Integer;
  Tabs: array of string;
  St: TFmrPartState;
begin
  Theme := TFmrTheme.CreateTheme(AName);
  P := TFmrRibbonPainter.Create(Theme);
  Bmp := TBitmap.Create(W * 2, H * 2);
  try
    Bmp.BitmapScale := 2;
    M := Theme.Metrics;
    C := Bmp.Canvas;
    if C.BeginScene then
    try
      C.Clear(TAlphaColors.White);
      C.SetMatrix(TMatrix.CreateScaling(2 / C.Scale, 2 / C.Scale));
      // caption
      R := RectF(0, 0, W, M.CaptionHeight);
      P.DrawCaption(C, R, True);
      P.Text(C, R, Theme.DisplayName + ' - Document1', Theme.Colors[TFmrToken.CaptionText]);
      P.DrawCaptionButton(C, RectF(W - 138, 0, W - 92, M.CaptionHeight), TFmrCaptionGlyph.Minimize,
        TFmrPartState.Normal, True);
      P.DrawCaptionButton(C, RectF(W - 92, 0, W - 46, M.CaptionHeight), TFmrCaptionGlyph.Maximize,
        TFmrPartState.Hot, True);
      P.DrawCaptionButton(C, RectF(W - 46, 0, W, M.CaptionHeight), TFmrCaptionGlyph.Close, TFmrPartState.Hot, True);
      // QAT
      for I := 0 to 2 do
        P.DrawButton(C, RectF(8 + I * 26, 3, 32 + I * 26, M.CaptionHeight - 3), TFmrPartState(I));
      // tab row
      Y := M.CaptionHeight;
      R := RectF(0, Y, W, Y + M.TabRowHeight);
      P.DrawTabRow(C, R, True);
      P.DrawAppButton(C, RectF(4, Y, 54, Y + M.TabRowHeight), 'File', TFmrPartState.Normal);
      Tabs := ['Home', 'Insert', 'Design', 'Layout', 'View'];
      X := 60;
      for I := 0 to High(Tabs) do
      begin
        TabW := P.TextWidth(Tabs[I]) + M.TabPaddingH * 2;
        P.DrawTab(C, RectF(X, Y, X + TabW, Y + M.TabRowHeight), Tabs[I], I = 2, I = 0, True, False);
        X := X + TabW + M.TabSpacing;
      end;
      TabW := P.TextWidth('Table Design') + M.TabPaddingH * 2;
      P.DrawTab(C, RectF(X + 10, Y, X + 10 + TabW, Y + M.TabRowHeight), 'Table Design', False, False, True, False,
        $FFE8A33D);
      // body
      Y := Y + M.TabRowHeight;
      BodyR := RectF(M.BodyMargin, Y, W - M.BodyMargin, Y + M.BodyHeight);
      if Theme.Style.FloatingBody then
        BodyR.Bottom := BodyR.Bottom - 2;
      P.DrawBody(C, BodyR);
      G1 := RectF(BodyR.Left + 3, BodyR.Top + M.BodyPaddingV, BodyR.Left + 230, BodyR.Bottom - M.BodyPaddingV);
      P.DrawGroup(C, G1, 'Clipboard', False, M.GroupCaptionHeight, False);
      G2 := RectF(G1.Right + M.GroupSpacing, G1.Top, G1.Right + M.GroupSpacing + 260, G1.Bottom);
      P.DrawGroup(C, G2, 'Font', True, M.GroupCaptionHeight, False);
      P.DrawGroupLauncher(C, RectF(G2.Right - 16, G2.Bottom - 16, G2.Right - 3, G2.Bottom - 3), TFmrPartState.Normal);
      // large buttons in each state
      for St := TFmrPartState.Normal to TFmrPartState.CheckedHot do
      begin
        R := RectF(G1.Left + 4 + Ord(St) * 44, G1.Top + M.GroupPaddingTop, G1.Left + 46 + Ord(St) * 44,
          G1.Top + M.GroupPaddingTop + M.ContentHeight);
        P.DrawButton(C, R, St);
        P.Fill(C, RectF(R.CenterPoint.X - 16, R.Top + 4, R.CenterPoint.X + 16, R.Top + 36),
          TFmrFill.Solid(Theme.Accent), 3);
        P.Text(C, RectF(R.Left, R.Top + 38, R.Right, R.Bottom - 12), 'Paste', P.ButtonTextColor(St));
        P.Arrow(C, PointF(R.CenterPoint.X, R.Bottom - 7), TFmrArrowDirection.Down, Theme.Colors[TFmrToken.ButtonArrow]);
      end;
      // small buttons, split button, edit frame
      R := RectF(G2.Left + 6, G2.Top + M.GroupPaddingTop, G2.Left + 126, G2.Top + M.GroupPaddingTop + M.SmallButtonHeight);
      P.DrawEditFrame(C, R, False, True);
      P.Text(C, RectF(R.Left + 4, R.Top, R.Right, R.Bottom), 'Calibri', Theme.Colors[TFmrToken.EditText], TTextAlign.Leading);
      R.Offset(0, M.SmallButtonHeight);
      P.DrawSplitButton(C, RectF(R.Left, R.Top, R.Left + 40, R.Bottom), RectF(R.Left, R.Top, R.Left + 26, R.Bottom),
        RectF(R.Left + 26, R.Top, R.Left + 40, R.Bottom), TFmrPartState.Hot, TFmrPartState.Normal, False);
      P.Text(C, RectF(R.Left, R.Top, R.Left + 26, R.Bottom), 'B', Theme.Colors[TFmrToken.ButtonText], TTextAlign.Center,
        TTextAlign.Center, 0, True);
      P.Arrow(C, PointF(R.Left + 33, R.CenterPoint.Y), TFmrArrowDirection.Down, Theme.Colors[TFmrToken.ButtonArrow]);
      P.DrawButton(C, RectF(R.Left + 44, R.Top, R.Left + 66, R.Bottom), TFmrPartState.Checked);
      P.Text(C, RectF(R.Left + 44, R.Top, R.Left + 66, R.Bottom), 'I', Theme.Colors[TFmrToken.ButtonText]);
      // gallery
      R := RectF(G2.Left + 134, G2.Top + M.GroupPaddingTop, G2.Right - 22, G2.Top + M.GroupPaddingTop + M.ContentHeight);
      P.DrawGalleryFrame(C, R, False);
      for I := 0 to 2 do
        P.DrawGalleryItem(C, RectF(R.Left + 3 + I * 34, R.Top + 3, R.Left + 35 + I * 34, R.Bottom - 3), I = 1, I = 0);
      P.DrawGalleryScroll(C, RectF(R.Right - 14, R.Top, R.Right, R.Top + R.Height / 3), TFmrArrowDirection.Up,
        TFmrPartState.Normal, False);
      P.DrawGalleryScroll(C, RectF(R.Right - 14, R.Top + R.Height * 2 / 3, R.Right, R.Bottom), TFmrArrowDirection.Down,
        TFmrPartState.Hot, True);
      // collapsed group
      R := RectF(G2.Right + 6, G1.Top, G2.Right + 66, G1.Bottom);
      P.DrawCollapsedGroup(C, R, TFmrPartState.Hot);
      P.Text(C, RectF(R.Left, R.Bottom - 30, R.Right, R.Bottom - 10), 'Styles', Theme.Colors[TFmrToken.ButtonText]);
      // menu + key tip + screen tip under the ribbon
      Y := BodyR.Bottom + 8;
      R := RectF(10, Y, 200, Y + 4 * M.MenuItemHeight + 9);
      P.DrawMenuBackground(C, R, M.MenuGutterWidth);
      P.DrawMenuItem(C, RectF(R.Left + 1, R.Top + 4, R.Right - 1, R.Top + 4 + M.MenuItemHeight), TFmrPartState.Hot);
      P.Text(C, RectF(R.Left + M.MenuGutterWidth + 6, R.Top + 4, R.Right, R.Top + 4 + M.MenuItemHeight), 'Cut',
        Theme.Colors[TFmrToken.MenuItemText], TTextAlign.Leading);
      P.DrawCheckMark(C, RectF(R.Left, R.Top + 4 + M.MenuItemHeight, R.Left + M.MenuGutterWidth,
        R.Top + 4 + 2 * M.MenuItemHeight), Theme.Colors[TFmrToken.MenuItemText]);
      P.Text(C, RectF(R.Left + M.MenuGutterWidth + 6, R.Top + 4 + M.MenuItemHeight, R.Right,
        R.Top + 4 + 2 * M.MenuItemHeight), 'Ruler', Theme.Colors[TFmrToken.MenuItemText], TTextAlign.Leading);
      P.DrawMenuSeparator(C, RectF(R.Left, R.Top + 4 + 2 * M.MenuItemHeight, R.Right, R.Top + 9 + 2 * M.MenuItemHeight),
        M.MenuGutterWidth);
      P.DrawKeyTip(C, RectF(220, Y + 4, 240, Y + 22), 'H', True);
      P.DrawKeyTip(C, RectF(248, Y + 4, 274, Y + 22), 'FN', False);
      R := RectF(300, Y, 560, Y + 70);
      P.DrawScreenTipBackground(C, R);
      P.Text(C, RectF(R.Left + 8, R.Top + 6, R.Right - 8, R.Top + 24), 'Paste (Ctrl+V)',
        Theme.Colors[TFmrToken.ScreenTipTitleText], TTextAlign.Leading, TTextAlign.Center, 0, True);
      P.Text(C, RectF(R.Left + 8, R.Top + 26, R.Right - 8, R.Bottom - 4),
        'Add content from the Clipboard to your document.', Theme.Colors[TFmrToken.ScreenTipText], TTextAlign.Leading,
        TTextAlign.Leading, 0, False, True);
      R := RectF(580, Y, 750, Y + 26);
      P.DrawSearchBox(C, R, False);
      P.Text(C, RectF(R.Left + 8, R.Top, R.Right, R.Bottom), 'Search', Theme.Colors[TFmrToken.SearchBoxPrompt],
        TTextAlign.Leading);
      P.DrawStatusBar(C, RectF(0, H - M.StatusBarHeight, W, H));
      P.Text(C, RectF(8, H - M.StatusBarHeight, 300, H), 'Page 1 of 1   12 words',
        Theme.Colors[TFmrToken.StatusBarText], TTextAlign.Leading);
    finally
      C.EndScene;
    end;
    Bmp.SaveToFile(TPath.Combine(AOutDir, AName + '.png'));
  finally
    Bmp.Free;
    P.Free;
    Theme.Free;
  end;
end;

procedure WriteTokenTable(const AFileName: string);
var
  L: TStringList;
  T: TFmrToken;
  Light, Dark: TFmrTheme;

  function Desc(const F: TFmrFill): string;
  var
    S: TFmrGradientStop;
  begin
    if F.Kind = TFmrFillKind.Solid then
    begin
      if TAlphaColorRec(F.Color).A = 0 then
        Exit('none');
      Exit('#' + IntToHex(F.Color, 8));
    end;
    Result := 'gradient';
    for S in F.Stops do
      Result := Result + ' #' + IntToHex(S.Color, 8);
  end;

begin
  Light := TFmrTheme.CreateTheme('Office365White');
  Dark := TFmrTheme.CreateTheme('Office365Black');
  L := TStringList.Create;
  try
    L.Add('| Token (StyleName) | Office 365 White | Office 365 Black |');
    L.Add('|---|---|---|');
    for T := Low(TFmrToken) to High(TFmrToken) do
      L.Add(Format('| `%s` | %s | %s |', [TFmrTheme.TokenStyleName(T), Desc(Light.Fills[T]), Desc(Dark.Fills[T])]));
    L.SaveToFile(AFileName, TEncoding.UTF8);
  finally
    L.Free;
    Light.Free;
    Dark.Free;
  end;
end;

var
  OutDir, N: string;
begin
  Application.Initialize;
  if (ParamCount = 2) and SameText(ParamStr(1), '/tokens') then
  begin
    WriteTokenTable(ParamStr(2));
    Exit;
  end;
  OutDir := TPath.Combine(TPath.GetDirectoryName(TPath.GetDirectoryName(TPath.GetDirectoryName(
    TPath.GetDirectoryName(ParamStr(0))))), 'shots\themes');
  if ParamCount > 0 then
    OutDir := ParamStr(1);
  TDirectory.CreateDirectory(OutDir);
  for N in TFmrTheme.ThemeNames do
    RenderTheme(N, OutDir);
end.
