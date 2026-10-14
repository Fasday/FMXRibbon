unit FMR.Tests.KeyTips;

interface

uses
  System.SysUtils, System.Generics.Collections, System.Messaging, DUnitX.TestFramework, FMR.Ribbon.Types,
  FMR.Ribbon.KeyTips, FMR.Ribbon.Strings;

type
  [TestFixture]
  TKeyTipTests = class
  private
    function Assign(const ACaptions: array of string; const AExplicit: array of string;
      const AStyle: TFmrKeyTipStyle = TFmrKeyTipStyle.Letters): TArray<string>;
    procedure CheckScope(const ATips: TArray<string>);
  public
    [Test] procedure DocumentEditorTabs;
    [Test] procedure ExplicitTipsAreKept;
    [Test] procedure AcceleratorWins;
    [Test] procedure NumbersStyle;
    [Test] procedure ReservedTipsAreAvoided;
    [Test] procedure ManyEntriesStayUniqueAndPrefixFree;
    [Test] procedure CyrillicCaptions;
    [Test] procedure EmptyCaptionsGetTips;
    [Test] procedure MatcherSequence;
    [Test] procedure MatcherBackspace;
  end;

  [TestFixture]
  TStringsTests = class
  private
    FMessages: Integer;
    procedure LanguageChanged(const Sender: TObject; const M: TMessage);
  public
    [TearDown] procedure TearDown;
    [Test] procedure EnglishByDefault;
    [Test] procedure SwitchToRussian;
    [Test] procedure UnknownLanguageFallsBack;
    [Test] procedure OverridesWin;
    [Test] procedure TablesAreComplete;
    [Test] procedure ChangeIsBroadcast;
  end;

implementation

{ TKeyTipTests }

function TKeyTipTests.Assign(const ACaptions: array of string; const AExplicit: array of string;
  const AStyle: TFmrKeyTipStyle): TArray<string>;
var
  E: TArray<TFmrKeyTipEntry>;
  I: Integer;
  X: string;
begin
  SetLength(E, Length(ACaptions));
  for I := 0 to High(ACaptions) do
  begin
    if I <= High(AExplicit) then
      X := AExplicit[I]
    else
      X := '';
    E[I] := TFmrKeyTipEntry.Create(ACaptions[I], X, I);
  end;
  TFmrKeyTipAssigner.Assign(E, AStyle);
  SetLength(Result, Length(E));
  for I := 0 to High(E) do
  begin
    Assert.AreEqual(NativeInt(I), E[I].Data);
    Result[I] := E[I].KeyTip;
  end;
end;

procedure TKeyTipTests.CheckScope(const ATips: TArray<string>);
var
  T: string;
begin
  for T in ATips do
  begin
    Assert.IsTrue(T <> '', 'every entry gets a key tip');
    Assert.IsTrue(T.Length <= 2, 'one or two characters: ' + T);
  end;
  Assert.IsTrue(TFmrKeyTipAssigner.IsPrefixFree(ATips), 'unique and prefix-free: ' + string.Join(' ', ATips));
end;

procedure TKeyTipTests.DocumentEditorTabs;
var
  Tips: TArray<string>;
begin
  Tips := Assign(['File', 'Home', 'Insert', 'Design', 'Layout', 'References', 'Mailings', 'Review', 'View', 'Help'], []);
  CheckScope(Tips);
  Assert.AreEqual('F', Tips[0]);
  Assert.AreEqual('HO', Tips[1], 'Home and Help share H: both get two letters');
  Assert.AreEqual('I', Tips[2]);
  Assert.AreEqual('D', Tips[3]);
  Assert.AreEqual('L', Tips[4]);
  Assert.AreEqual('RE', Tips[5]);
  Assert.AreEqual('M', Tips[6]);
  Assert.AreEqual('RV', Tips[7]);
  Assert.AreEqual('V', Tips[8]);
  Assert.AreEqual('HE', Tips[9]);
end;

procedure TKeyTipTests.ExplicitTipsAreKept;
var
  Tips: TArray<string>;
begin
  Tips := Assign(['Home', 'Help', 'Insert'], ['h', '', 'N']);
  CheckScope(Tips);
  Assert.AreEqual('H', Tips[0], 'explicit, upper-cased');
  Assert.AreEqual('N', Tips[2]);
  Assert.IsFalse(Tips[1].StartsWith('H'), 'Help avoids the explicit H');
end;

procedure TKeyTipTests.AcceleratorWins;
var
  Tips: TArray<string>;
begin
  Tips := Assign(['&Save', 'Save &As', 'Sa&ve All', 'Print'], []);
  CheckScope(Tips);
  Assert.AreEqual('S', Tips[0]);
  Assert.AreEqual('A', Tips[1]);
  Assert.AreEqual('V', Tips[2]);
  Assert.AreEqual('P', Tips[3]);
end;

procedure TKeyTipTests.NumbersStyle;
var
  Captions: TArray<string>;
  Tips: TArray<string>;
  I: Integer;
begin
  SetLength(Captions, 20);
  for I := 0 to High(Captions) do
    Captions[I] := 'Command ' + I.ToString;
  Tips := Assign(Captions, [], TFmrKeyTipStyle.Numbers);
  CheckScope(Tips);
  Assert.AreEqual('1', Tips[0]);
  Assert.AreEqual('9', Tips[8]);
  Assert.AreEqual('09', Tips[9]);
  Assert.AreEqual('01', Tips[17]);
  Assert.AreEqual('0A', Tips[18]);
end;

procedure TKeyTipTests.ReservedTipsAreAvoided;
var
  E: TArray<TFmrKeyTipEntry>;
begin
  E := [TFmrKeyTipEntry.Create('Find'), TFmrKeyTipEntry.Create('Replace')];
  TFmrKeyTipAssigner.Assign(E, TFmrKeyTipStyle.Letters, ['F', 'R']);
  Assert.IsFalse(E[0].KeyTip.StartsWith('F'));
  Assert.IsFalse(E[1].KeyTip.StartsWith('R'));
  Assert.IsTrue(TFmrKeyTipAssigner.IsPrefixFree([E[0].KeyTip, E[1].KeyTip, 'F', 'R']));
end;

procedure TKeyTipTests.ManyEntriesStayUniqueAndPrefixFree;
const
  Words: array[0..11] of string = ('Paste', 'Cut', 'Copy', 'Format', 'Painter', 'Bold', 'Italic', 'Underline',
    'Font', 'Color', 'Size', 'Style');
var
  Captions: TArray<string>;
  I: Integer;
begin
  SetLength(Captions, 80);
  for I := 0 to High(Captions) do
    Captions[I] := Words[I mod 12] + ' ' + Words[(I * 7) mod 12];
  CheckScope(Assign(Captions, []));
end;

procedure TKeyTipTests.CyrillicCaptions;
var
  Tips: TArray<string>;
begin
  Tips := Assign(['Главная', 'Вставка', 'Вид', 'Рецензирование'], []);
  CheckScope(Tips);
  Assert.AreEqual('Г', Tips[0]);
  Assert.AreEqual('ВС', Tips[1]);
  Assert.AreEqual('ВИ', Tips[2]);
  Assert.AreEqual('Р', Tips[3]);
end;

procedure TKeyTipTests.EmptyCaptionsGetTips;
begin
  CheckScope(Assign(['', '', '...', 'A'], []));
end;

procedure TKeyTipTests.MatcherSequence;
var
  M: TFmrKeyTipMatcher;
begin
  M := TFmrKeyTipMatcher.Create(['H', 're', 'RV', '1']);
  try
    Assert.AreEqual(4, M.CandidateCount);
    Assert.AreEqual(TFmrKeyTipMatch.Partial, M.Press('r'));
    Assert.AreEqual('R', M.Typed);
    Assert.IsFalse(M.IsCandidate(0));
    Assert.IsTrue(M.IsCandidate(1));
    Assert.AreEqual(2, M.CandidateCount);
    Assert.AreEqual(TFmrKeyTipMatch.None, M.Press('x'));
    Assert.AreEqual('R', M.Typed, 'an unmatched character is not kept');
    Assert.AreEqual(TFmrKeyTipMatch.Complete, M.Press('V'));
    Assert.AreEqual(2, M.MatchedIndex);
    M.Reset;
    Assert.AreEqual(TFmrKeyTipMatch.Complete, M.Press('1'));
    Assert.AreEqual(3, M.MatchedIndex);
  finally
    M.Free;
  end;
end;

procedure TKeyTipTests.MatcherBackspace;
var
  M: TFmrKeyTipMatcher;
begin
  M := TFmrKeyTipMatcher.Create(['AB', 'AC']);
  try
    Assert.IsFalse(M.Backspace, 'nothing typed: go back to the parent scope');
    M.Press('a');
    Assert.IsTrue(M.Backspace);
    Assert.AreEqual('', M.Typed);
    Assert.AreEqual(2, M.CandidateCount);
  finally
    M.Free;
  end;
end;

{ TStringsTests }

procedure TStringsTests.TearDown;
begin
  FmrResetStrings;
  FmrSetLanguage('en');
end;

procedure TStringsTests.EnglishByDefault;
begin
  Assert.AreEqual('en', FmrLanguage);
  Assert.AreEqual('Collapse the Ribbon', FmrStr(TFmrStringId.RibbonCollapse));
  Assert.AreEqual('Press F1 for more help.', FmrStr(TFmrStringId.ScreenTipHelp));
end;

procedure TStringsTests.SwitchToRussian;
begin
  Assert.IsTrue(FmrSetLanguage('ru-RU'));
  Assert.AreEqual('ru', FmrLanguage);
  Assert.AreEqual('Свернуть ленту', FmrStr(TFmrStringId.RibbonCollapse));
  Assert.AreEqual('Разместить под лентой', FmrStr(TFmrStringId.QATShowBelow));
  Assert.AreEqual('(Ctrl+C)', FmrFmt(TFmrStringId.ScreenTipShortcut, ['Ctrl+C']));
end;

procedure TStringsTests.UnknownLanguageFallsBack;
begin
  Assert.IsFalse(FmrSetLanguage('xx'));
  Assert.AreEqual('en', FmrLanguage);
  Assert.AreEqual('More Commands...', FmrStr(TFmrStringId.QATMoreCommands));
end;

procedure TStringsTests.OverridesWin;
var
  T: TFmrStringTable;
begin
  FmrSetString(TFmrStringId.SearchPrompt, 'Find a command');
  Assert.AreEqual('Find a command', FmrStr(TFmrStringId.SearchPrompt));
  FmrSetLanguage('ru');
  Assert.AreEqual('Find a command', FmrStr(TFmrStringId.SearchPrompt), 'overrides apply to every language');
  FmrResetStrings;
  Assert.AreEqual('Поиск', FmrStr(TFmrStringId.SearchPrompt));
  T := Default(TFmrStringTable);
  T[TFmrStringId.CommonOK] := 'Gut';
  FmrRegisterLanguage('de', T);
  Assert.IsTrue(FmrSetLanguage('de'));
  Assert.AreEqual('Gut', FmrStr(TFmrStringId.CommonOK));
  Assert.AreEqual('Cancel', FmrStr(TFmrStringId.CommonCancel), 'missing translations fall back to English');
end;

procedure TStringsTests.TablesAreComplete;
var
  Id: TFmrStringId;
begin
  for Id := Low(TFmrStringId) to High(TFmrStringId) do
  begin
    Assert.IsTrue(FmrStringsEN[Id] <> '', 'EN ' + Ord(Id).ToString);
    Assert.IsTrue(FmrStringsRU[Id] <> '', 'RU ' + Ord(Id).ToString);
  end;
end;

procedure TStringsTests.LanguageChanged(const Sender: TObject; const M: TMessage);
begin
  Inc(FMessages);
end;

procedure TStringsTests.ChangeIsBroadcast;
var
  Id: Integer;
begin
  FMessages := 0;
  Id := TMessageManager.DefaultManager.SubscribeToMessage(TFmrLanguageChangedMessage, LanguageChanged);
  try
    FmrSetLanguage('ru');
    Assert.AreEqual(1, FMessages);
  finally
    TMessageManager.DefaultManager.Unsubscribe(TFmrLanguageChangedMessage, Id);
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TKeyTipTests);
  TDUnitX.RegisterTestFixture(TStringsTests);

end.
