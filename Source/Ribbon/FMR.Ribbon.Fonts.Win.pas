{*******************************************************}
{                                                       }
{  FMR Ribbon for FireMonkey                            }
{  Font families of Windows for TFmrFontNameItem        }
{                                                       }
{  MIT License. Copyright (c) 2026 Fasday               }
{                                                       }
{*******************************************************}

unit FMR.Ribbon.Fonts.Win;

/// Sets TFmrFontNameItem.FontListProvider to the font families of Windows (EnumFontFamiliesEx, every character set,
/// vertical '@' fonts skipped). Neither FMX nor Skia enumerates font families, so the ribbon needs a platform unit.
/// The unit compiles to nothing on other platforms.

interface

implementation

{$IFDEF MSWINDOWS}
uses
  System.SysUtils, System.Classes, Winapi.Windows, FMR.Bars.Items;

function EnumFamilyProc(const LogFont: TLogFont; const TextMetric: TTextMetric; FontType: DWORD;
  Data: LPARAM): Integer; stdcall;
var
  Name: string;
begin
  Name := LogFont.lfFaceName;
  if (Name <> '') and (Name[1] <> '@') then
    TStrings(Data).Add(Name);
  Result := 1;
end;

procedure WindowsFontList(AList: TStrings);
var
  DC: HDC;
  LF: TLogFont;
begin
  DC := GetDC(0);
  try
    FillChar(LF, SizeOf(LF), 0);
    LF.lfCharSet := DEFAULT_CHARSET;
    EnumFontFamiliesEx(DC, LF, @EnumFamilyProc, LPARAM(AList), 0);
  finally
    ReleaseDC(0, DC);
  end;
end;

initialization
  if not Assigned(TFmrFontNameItem.FontListProvider) then
    TFmrFontNameItem.FontListProvider :=
      procedure(AList: TStrings)
      begin
        WindowsFontList(AList);
      end;
{$ENDIF}

end.
