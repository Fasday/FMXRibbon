{*******************************************************}
{                                                       }
{  FMR Ribbon for FireMonkey                            }
{  User interface strings (English, Russian)            }
{                                                       }
{  MIT License. Copyright (c) 2026 Fasday               }
{                                                       }
{*******************************************************}

unit FMR.Ribbon.Strings;

/// Every text the ribbon shows by itself. FmrStr(TFmrStringId.X) returns the text of the current language;
/// FmrSetLanguage('ru') switches the language (a TFmrLanguageChangedMessage is sent through
/// TMessageManager.DefaultManager so open UI can refresh); FmrSetString overrides one text;
/// FmrRegisterLanguage adds a translation table.

interface

{$SCOPEDENUMS ON}

uses
  System.SysUtils, System.Messaging;

type
  TFmrStringId = (
    { quick access toolbar }
    QATCustomize, QATCustomizeDots, QATShowBelow, QATShowAbove, QATShowBelowLong, QATShowAboveLong, QATAddItem,
    QATRemoveItem, QATAddGallery, QATMoreCommands, QATShowQAT, QATHideQAT,
    { ribbon }
    RibbonCollapse, RibbonExpand, RibbonPin, RibbonCustomize, RibbonDisplayOptions, RibbonShowTabsAndCommands,
    RibbonShowTabs, RibbonAutoHide, RibbonClassic, RibbonSimplified, RibbonMoreOptions, RibbonScrollLeft,
    RibbonScrollRight, RibbonDefaultTabCaption, RibbonDefaultGroupCaption, RibbonDialogLauncher,
    { search }
    SearchPrompt, SearchPromptLong, SearchNoResults, SearchCommands, SearchRecent,
    { screen tips }
    ScreenTipHelp, ScreenTipShortcut, ScreenTipDisabled,
    { application menu and backstage }
    AppMenuFile, AppMenuRecent, AppMenuOptions, AppMenuExit, BackstageBack,
    { customization form }
    CustRibbonCaption, CustQATCaption, CustChooseCommandsFrom, CustPopularCommands, CustAllCommands,
    CustCommandsNotInRibbon, CustMainTabs, CustToolTabs, CustAllTabs, CustCustomizeRibbonLabel, CustCustomizeQATLabel,
    CustAdd, CustRemove, CustNewTab, CustNewGroup, CustRename, CustReset, CustResetAll, CustResetTab,
    CustImportExport, CustImport, CustExport, CustMoveUp, CustMoveDown, CustNewTabCaption, CustNewGroupCaption,
    CustCustomSuffix, CustRenameCaption, CustDisplayName, CustSymbol, CustShowQATBelow, CustSeparator,
    CustResetConfirm, CustCustomize,
    { common buttons }
    CommonOK, CommonCancel, CommonClose, CommonHelp, CommonYes, CommonNo,
    { galleries }
    GalleryAll, GalleryMore, GalleryEmpty,
    { color and font items }
    ColorAutomatic, ColorNoColor, ColorMoreColors, ColorThemeColors, ColorStandardColors, ColorRecentColors,
    FontThemeFonts, FontAllFonts, FontRecentFonts,
    { caption buttons }
    CaptionMinimize, CaptionMaximize, CaptionRestore, CaptionClose, CaptionHelp,
    { customization form (additions) }
    CustAddRuleHint, CustSearchPrompt, CustTabsHeader, CustCategoriesHeader, CustResetQAT, CustImportError,
    CustFileFilter, CustDesignedHint, CustNoCommands,
    { ribbon display options, auto-hide, simplified switch }
    RibbonAutoHideDesc, RibbonShowTabsDesc, RibbonShowTabsAndCommandsDesc, RibbonShowRibbon,
    RibbonSwitchToSimplified, RibbonSwitchToClassic,
    { accessibility names }
    AccRibbon, AccRibbonTabs, AccLowerRibbon, AccQAT);

  TFmrStringTable = array[TFmrStringId] of string;

  /// <summary>Sent through TMessageManager.DefaultManager after FmrSetLanguage or FmrSetString.</summary>
  TFmrLanguageChangedMessage = class(TMessage<string>);

const
  FmrStringsEN: TFmrStringTable = (
    { quick access toolbar }
    'Customize Quick Access Toolbar',
    'Customize Quick Access Toolbar...',
    'Show Below the Ribbon',
    'Show Above the Ribbon',
    'Show Quick Access Toolbar Below the Ribbon',
    'Show Quick Access Toolbar Above the Ribbon',
    'Add to Quick Access Toolbar',
    'Remove from Quick Access Toolbar',
    'Add Gallery to Quick Access Toolbar',
    'More Commands...',
    'Show Quick Access Toolbar',
    'Hide Quick Access Toolbar',
    { ribbon }
    'Collapse the Ribbon',
    'Expand the Ribbon',
    'Pin the Ribbon',
    'Customize the Ribbon...',
    'Ribbon Display Options',
    'Show Tabs and Commands',
    'Show Tabs',
    'Auto-hide Ribbon',
    'Classic Ribbon',
    'Simplified Ribbon',
    'More Options',
    'Scroll Left',
    'Scroll Right',
    'Tab',
    'Group',
    'Show Dialog',
    { search }
    'Search',
    'Search commands',
    'No results found',
    'Commands',
    'Recently Used',
    { screen tips }
    'Press F1 for more help.',
    '(%s)',
    'This command is currently disabled.',
    { application menu and backstage }
    'File',
    'Recent Documents',
    'Options',
    'Exit',
    'Back',
    { customization form }
    'Customize the Ribbon',
    'Customize the Quick Access Toolbar',
    'Choose commands from:',
    'Popular Commands',
    'All Commands',
    'Commands Not in the Ribbon',
    'Main Tabs',
    'Tool Tabs',
    'All Tabs',
    'Customize the Ribbon:',
    'Customize Quick Access Toolbar:',
    'Add >>',
    '<< Remove',
    'New Tab',
    'New Group',
    'Rename...',
    'Reset',
    'Reset all customizations',
    'Reset only selected Ribbon tab',
    'Import/Export',
    'Import customization file',
    'Export all customizations',
    'Move Up',
    'Move Down',
    'New Tab (Custom)',
    'New Group (Custom)',
    ' (Custom)',
    'Rename',
    'Display name:',
    'Symbol:',
    'Show Quick Access Toolbar below the Ribbon',
    '<Separator>',
    'Delete all Ribbon and Quick Access Toolbar customizations for this program?',
    'Customize...',
    { common buttons }
    'OK',
    'Cancel',
    'Close',
    'Help',
    'Yes',
    'No',
    { galleries }
    'All',
    'More',
    'No items',
    { color and font items }
    'Automatic',
    'No Color',
    'More Colors...',
    'Theme Colors',
    'Standard Colors',
    'Recent Colors',
    'Theme Fonts',
    'All Fonts',
    'Recently Used Fonts',
    { caption buttons }
    'Minimize',
    'Maximize',
    'Restore Down',
    'Close',
    'Help',
    { customization form (additions) }
    'Commands can be added only to custom groups. Select a custom group or create one with New Group.',
    'Search commands',
    'Tabs',
    'Categories',
    'Reset only Quick Access Toolbar',
    'The file could not be imported: %s',
    'Customization files (*.json)|*.json|All files (*.*)|*.*',
    'Built-in groups keep their commands: hide a group with its check box or add a custom group.',
    'No commands',
    { ribbon display options, auto-hide, simplified switch }
    'Hide the Ribbon. Click at the top of the application to show it.',
    'Show Ribbon tabs only. Click a tab to show the commands.',
    'Show Ribbon tabs and commands all the time.',
    'Show the Ribbon',
    'Switch to Simplified Ribbon',
    'Switch to Classic Ribbon',
    { accessibility names }
    'Ribbon',
    'Ribbon Tabs',
    'Lower Ribbon',
    'Quick Access Toolbar');

  FmrStringsRU: TFmrStringTable = (
    { quick access toolbar }
    'Настроить панель быстрого доступа',
    'Настроить панель быстрого доступа...',
    'Разместить под лентой',
    'Разместить над лентой',
    'Разместить панель быстрого доступа под лентой',
    'Разместить панель быстрого доступа над лентой',
    'Добавить на панель быстрого доступа',
    'Удалить с панели быстрого доступа',
    'Добавить коллекцию на панель быстрого доступа',
    'Другие команды...',
    'Показать панель быстрого доступа',
    'Скрыть панель быстрого доступа',
    { ribbon }
    'Свернуть ленту',
    'Развернуть ленту',
    'Закрепить ленту',
    'Настроить ленту...',
    'Параметры отображения ленты',
    'Показывать вкладки и команды',
    'Показывать вкладки',
    'Автоматически скрывать ленту',
    'Классическая лента',
    'Упрощенная лента',
    'Другие параметры',
    'Прокрутить влево',
    'Прокрутить вправо',
    'Вкладка',
    'Группа',
    'Открыть диалоговое окно',
    { search }
    'Поиск',
    'Поиск команд',
    'Ничего не найдено',
    'Команды',
    'Недавно использованные',
    { screen tips }
    'Для получения дополнительных сведений нажмите клавишу F1.',
    '(%s)',
    'Эта команда сейчас недоступна.',
    { application menu and backstage }
    'Файл',
    'Последние документы',
    'Параметры',
    'Выход',
    'Назад',
    { customization form }
    'Настройка ленты',
    'Настройка панели быстрого доступа',
    'Выбрать команды из:',
    'Часто используемые команды',
    'Все команды',
    'Команды не на ленте',
    'Основные вкладки',
    'Вкладки инструментов',
    'Все вкладки',
    'Настройка ленты:',
    'Настройка панели быстрого доступа:',
    'Добавить >>',
    '<< Удалить',
    'Создать вкладку',
    'Создать группу',
    'Переименовать...',
    'Сброс',
    'Сброс всех настроек',
    'Сброс только выбранной вкладки ленты',
    'Импорт и экспорт',
    'Импортировать файл настройки',
    'Экспортировать все настройки',
    'Вверх',
    'Вниз',
    'Новая вкладка (настраиваемая)',
    'Новая группа (настраиваемая)',
    ' (настраиваемая)',
    'Переименование',
    'Отображаемое имя:',
    'Символ:',
    'Разместить панель быстрого доступа под лентой',
    '<Разделитель>',
    'Удалить все настройки ленты и панели быстрого доступа для этой программы?',
    'Настроить...',
    { common buttons }
    'ОК',
    'Отмена',
    'Закрыть',
    'Справка',
    'Да',
    'Нет',
    { galleries }
    'Все',
    'Дополнительно',
    'Нет элементов',
    { color and font items }
    'Авто',
    'Нет цвета',
    'Другие цвета...',
    'Цвета темы',
    'Стандартные цвета',
    'Последние цвета',
    'Шрифты темы',
    'Все шрифты',
    'Недавно использовавшиеся шрифты',
    { caption buttons }
    'Свернуть',
    'Развернуть',
    'Свернуть в окно',
    'Закрыть',
    'Справка',
    { customization form (additions) }
    'Команды можно добавлять только в настраиваемые группы. Выберите настраиваемую группу или создайте ее ' +
      'кнопкой «Создать группу».',
    'Поиск команд',
    'Вкладки',
    'Категории',
    'Сброс только панели быстрого доступа',
    'Не удалось импортировать файл: %s',
    'Файлы настройки (*.json)|*.json|Все файлы (*.*)|*.*',
    'Команды встроенных групп изменить нельзя: скройте группу флажком или добавьте настраиваемую группу.',
    'Нет команд',
    { ribbon display options, auto-hide, simplified switch }
    'Скрыть ленту. Чтобы показать ее, щелкните в верхней части приложения.',
    'Показывать только вкладки ленты. Чтобы показать команды, щелкните вкладку.',
    'Всегда показывать вкладки и команды ленты.',
    'Показать ленту',
    'Перейти к упрощенной ленте',
    'Перейти к классической ленте',
    { accessibility names }
    'Лента',
    'Вкладки ленты',
    'Нижняя лента',
    'Панель быстрого доступа');

/// <summary>Text of AId in the current language (an override set with FmrSetString wins).</summary>
function FmrStr(const AId: TFmrStringId): string;
/// <summary>Formats the text of AId with AArgs.</summary>
function FmrFmt(const AId: TFmrStringId; const AArgs: array of const): string;
/// <summary>Switches the language: 'en', 'ru' or any code registered with FmrRegisterLanguage ('ru-RU' is
/// accepted as 'ru'). Unknown codes fall back to English. Returns True when the code is known.</summary>
function FmrSetLanguage(const ACode: string): Boolean;
/// <summary>Code of the current language ('en' by default).</summary>
function FmrLanguage: string;
/// <summary>Two-letter code of the user interface language of the system ('en' when unknown).</summary>
function FmrSystemLanguage: string;
/// <summary>Adds or replaces a translation table. Empty strings of the table fall back to English.</summary>
procedure FmrRegisterLanguage(const ACode: string; const ATable: TFmrStringTable);
/// <summary>Overrides one text for every language; an empty AValue removes the override.</summary>
procedure FmrSetString(const AId: TFmrStringId; const AValue: string);
/// <summary>Removes every override set with FmrSetString.</summary>
procedure FmrResetStrings;

implementation

uses
  System.Generics.Collections, FMX.Platform;

var
  GLanguages: TDictionary<string, TFmrStringTable>;
  GCurrent: TFmrStringTable;
  GCurrentCode: string = 'en';
  GOverrides: TFmrStringTable;

function NormalizeCode(const ACode: string): string;
var
  P: Integer;
begin
  Result := ACode.Trim.ToLower;
  P := Result.IndexOfAny(['-', '_']);
  if P > 0 then
    Result := Result.Substring(0, P);
end;

procedure NotifyChanged;
begin
  TMessageManager.DefaultManager.SendMessage(nil, TFmrLanguageChangedMessage.Create(GCurrentCode));
end;

function FmrStr(const AId: TFmrStringId): string;
begin
  Result := GOverrides[AId];
  if Result = '' then
    Result := GCurrent[AId];
  if Result = '' then
    Result := FmrStringsEN[AId];
end;

function FmrFmt(const AId: TFmrStringId; const AArgs: array of const): string;
begin
  Result := Format(FmrStr(AId), AArgs);
end;

function FmrSetLanguage(const ACode: string): Boolean;
var
  Code: string;
  Table: TFmrStringTable;
begin
  Code := NormalizeCode(ACode);
  Result := GLanguages.TryGetValue(Code, Table);
  if not Result then
  begin
    Code := 'en';
    Table := FmrStringsEN;
  end;
  GCurrent := Table;
  GCurrentCode := Code;
  NotifyChanged;
end;

function FmrLanguage: string;
begin
  Result := GCurrentCode;
end;

function FmrSystemLanguage: string;
var
  Locale: IFMXLocaleService;
begin
  Result := '';
  if TPlatformServices.Current.SupportsPlatformService(IFMXLocaleService, Locale) then
    Result := NormalizeCode(Locale.GetCurrentLangID);
  if Result = '' then
    Result := 'en';
end;

procedure FmrRegisterLanguage(const ACode: string; const ATable: TFmrStringTable);
begin
  GLanguages.AddOrSetValue(NormalizeCode(ACode), ATable);
  if NormalizeCode(ACode) = GCurrentCode then
    FmrSetLanguage(GCurrentCode);
end;

procedure FmrSetString(const AId: TFmrStringId; const AValue: string);
begin
  GOverrides[AId] := AValue;
  NotifyChanged;
end;

procedure FmrResetStrings;
begin
  GOverrides := Default(TFmrStringTable);
  NotifyChanged;
end;

initialization
  GLanguages := TDictionary<string, TFmrStringTable>.Create;
  GLanguages.Add('en', FmrStringsEN);
  GLanguages.Add('ru', FmrStringsRU);
  GCurrent := FmrStringsEN;

finalization
  FreeAndNil(GLanguages);

end.
