{*******************************************************}
{                                                       }
{  FMR Ribbon for FireMonkey                            }
{  FMR Write demo: Russian texts of the form            }
{                                                       }
{  MIT License. Copyright (c) 2026 Fasday               }
{                                                       }
{*******************************************************}

unit WordLikeLang;

/// Russian captions of the components of the main form, by component name ('Name#d' = screen tip description or
/// tile description). The library translates its own strings (FmrSetLanguage); the English texts are the designed
/// ones of the .fmx, captured at start.

interface

function WriteRussianText(const AKey: string; out AText: string): Boolean;

implementation

uses
  System.SysUtils, System.Generics.Collections;

const
  Texts: array [0..219] of array [0..1] of string = (
    // tabs, groups
    ('tabHome', 'Главная'), ('tabInsert', 'Вставка'), ('tabLayout', 'Макет'), ('tabView', 'Вид'),
    ('tabSelection', 'Текст'), ('tabSelLines', 'Строки'), ('ctxSelection', 'Выделение'),
    ('grpSelLines', 'Строки'), ('grpSelLists', 'Списки'),
    ('grpClipboard', 'Буфер обмена'), ('grpFont', 'Шрифт'), ('grpParagraph', 'Абзац'), ('grpStyles', 'Стили'),
    ('grpEditing', 'Редактирование'), ('grpPages', 'Страницы'), ('grpTables', 'Таблицы'),
    ('grpIllustrations', 'Иллюстрации'), ('grpText', 'Текст'), ('grpLinks', 'Ссылки'), ('grpSymbols', 'Символы'),
    ('grpPageSetup', 'Параметры страницы'), ('grpPageBackground', 'Фон страницы'), ('grpIndent', 'Абзац'),
    ('grpViews', 'Режимы'), ('grpShow', 'Показать'), ('grpZoom', 'Масштаб'), ('grpThemes', 'Темы'),
    ('grpRibbon', 'Лента'), ('grpSelCase', 'Регистр'), ('grpSelEdit', 'Правка'), ('grpSelText', 'Текст'),
    ('grpSelInfo', 'Выделение'),
    // file and quick access toolbar
    ('btnSave', 'Сохранить'), ('btnSave#d', 'Сохранить документ. Новый документ открывает страницу «Сохранить как».'),
    ('btnUndo', 'Отменить'), ('btnRedo', 'Вернуть'), ('btnNew', 'Создать'), ('btnOpen', 'Открыть'),
    ('btnPrint', 'Печать'),
    // Home
    ('btnPaste', 'Вставить'), ('btnPaste#d', 'Вставить содержимое буфера обмена в документ.'),
    ('btnPasteKeep', 'Сохранить исходное форматирование'), ('btnPasteText', 'Сохранить только текст'),
    ('btnCut', 'Вырезать'), ('btnCut#d', 'Удалить выделенный фрагмент и поместить его в буфер обмена.'),
    ('btnCopy', 'Копировать'), ('btnCopy#d', 'Поместить копию выделенного фрагмента в буфер обмена.'),
    ('btnSelectAll', 'Выделить все'), ('cbFontName', 'Шрифт'), ('cbFontName#d', 'Выбор шрифта документа.'),
    ('cbFontSize', 'Размер шрифта'), ('cbFontSize#d', 'Изменение размера текста.'),
    ('btnGrowFont', 'Увеличить размер'), ('btnGrowFont#d', 'Немного увеличить текст.'),
    ('btnShrinkFont', 'Уменьшить размер'), ('btnShrinkFont#d', 'Немного уменьшить текст.'),
    ('btnChangeCase', 'Регистр'),
    ('btnChangeCase#d', 'Сделать выделенный текст прописным, строчным или изменить регистр иначе.'),
    ('btnCaseSentence', 'Как в предложениях.'), ('btnCaseLower', 'все строчные'),
    ('btnCaseUpper', 'ВСЕ ПРОПИСНЫЕ'), ('btnCaseTitle', 'Начинать С Прописных'),
    ('btnCaseToggle', 'иЗМЕНИТЬ рЕГИСТР'),
    ('btnBold', 'Полужирный'), ('btnBold#d', 'Сделать текст полужирным.'),
    ('btnItalic', 'Курсив'), ('btnItalic#d', 'Выделить текст курсивом.'),
    ('btnUnderline', 'Подчёркнутый'), ('btnUnderline#d', 'Подчеркнуть текст.'),
    ('btnStrike', 'Зачёркнутый'), ('btnStrike#d', 'Зачеркнуть текст линией.'),
    ('clrFontColor', 'Цвет текста'), ('clrFontColor#d', 'Изменить цвет текста. Наведите указатель на цвет, ' +
      'чтобы увидеть результат.'),
    ('btnClearFormatting', 'Очистить формат'), ('btnClearFormatting#d', 'Убрать форматирование: стиль «Обычный».'),
    ('btnBullets', 'Маркеры'), ('btnBullets#d', 'Маркированный список (или удалить маркеры выделенных строк).'),
    ('btnNumbering', 'Нумерация'), ('btnNumbering#d', 'Нумерованный список (или удалить номера выделенных строк).'),
    ('btnIndentDec', 'Уменьшить отступ'), ('btnIndentInc', 'Увеличить отступ'), ('btnSort', 'Сортировка'),
    ('btnSort#d', 'Упорядочить выделенные строки по алфавиту.'),
    ('btnAlignLeft', 'По левому краю'), ('btnAlignCenter', 'По центру'), ('btnAlignRight', 'По правому краю'),
    ('btnJustify', 'По ширине'), ('galStyles', 'Стили'),
    ('galStyles#d', 'Выберите стиль документа. Наведите указатель на стиль, чтобы увидеть результат.'),
    ('btnFind', 'Найти'), ('btnFind#d', 'Найти текст в документе.'), ('btnReplace', 'Заменить'),
    ('btnReplace#d', 'Найти текст и заменить его.'),
    // Insert
    ('btnBlankPage', 'Пустая страница'), ('btnBlankPage#d', 'Вставить пустые строки в позицию курсора.'),
    ('btnPageBreak', 'Разрыв страницы'), ('btnPageBreak#d', 'Вставить линию разрыва страницы.'),
    ('galTable', 'Таблица'), ('galTable#d', 'Вставить текстовую таблицу: выберите число столбцов и строк.'),
    ('btnInsertTable', 'Вставить таблицу...'), ('btnShapes', 'Фигуры'),
    ('btnShapes#d', 'Вставить символ-фигуру (квадрат, круг, стрелку, звезду...) в позицию курсора.'),
    ('galShapes', 'Фигуры'), ('btnHorizontalLine', 'Горизонтальная линия'), ('btnTextBox', 'Надпись'),
    ('btnDateTime', 'Дата и время'), ('btnSignature', 'Строка подписи'), ('btnComment', 'Примечание'),
    ('btnLink', 'Ссылка'), ('galSymbols', 'Символ'), ('galSymbols#d', 'Вставить символ в позицию курсора.'),
    // Layout
    ('btnMargins', 'Поля'), ('btnMargins#d', 'Задать поля страницы.'), ('btnMarginsNormal', 'Обычные'),
    ('btnMarginsNarrow', 'Узкие'), ('btnMarginsModerate', 'Средние'), ('btnMarginsWide', 'Широкие'),
    ('btnOrientation', 'Ориентация'), ('btnPortrait', 'Книжная'), ('btnLandscape', 'Альбомная'),
    ('btnSize', 'Размер'), ('btnWatermark', 'Подложка'),
    ('btnWatermark#d', 'Добавить бледный текст поверх содержимого страницы.'), ('btnWmNone', 'Без подложки'),
    ('clrPageColor', 'Цвет страницы'), ('clrPageColor#d', 'Изменить цвет страницы.'),
    ('btnPageBorders', 'Границы страниц'), ('spIndentLeft', 'Отступ слева'), ('spIndentRight', 'Отступ справа'),
    // View
    ('btnReadMode', 'Режим чтения'), ('btnPrintLayout', 'Разметка страницы'), ('btnWebLayout', 'Веб-документ'),
    ('chkStatusBar', 'Строка состояния'), ('chkWordWrap', 'Перенос по словам'), ('chkFindPane', 'Панель поиска'),
    ('btnZoom', 'Масштаб'), ('btnZoomIn', 'Увеличить'), ('btnZoomOut', 'Уменьшить'),
    ('btnPageWidth', 'По ширине страницы'), ('galThemes', 'Темы'),
    ('galThemes#d', 'Сменить тему всего окна: ленты, представления Backstage, строки состояния и всплывающих окон.'),
    ('galAccent', 'Акцент'), ('galAccent#d', 'Цвет цветного заголовка, активной вкладки, вкладки «Файл» и выделения.'),
    ('chkSimplified', 'Упрощённая лента'), ('chkTouch', 'Сенсорный режим'), ('btnLanguage', 'Язык'),
    ('btnLanguage#d', 'Переключить интерфейс между английским и русским языками.'),
    ('btnCustomize', 'Настроить ленту...'),
    ('btnCustomize#d', 'Добавлять, удалять, переименовывать и переставлять вкладки, группы и команды.'),
    ('btnResetRibbon', 'Сбросить ленту'),
    ('btnResetRibbon#d', 'Вернуть исходный вид ленты (отменяет все настройки).'),
    // Selection Tools
    ('btnDeleteSel', 'Удалить'), ('btnQuote', 'В кавычки'), ('btnTrim', 'Убрать пробелы'),
    ('btnReverse', 'Обратный порядок'),
    // backstage
    ('bsInfo', 'Сведения'), ('bsNew', 'Создать'), ('bsOpen', 'Открыть'), ('bbSave', 'Сохранить'),
    ('bsSaveAs', 'Сохранить как'), ('bsPrint', 'Печать'), ('bbClose', 'Закрыть'), ('bsAbout', 'О программе'),
    ('bsOptions', 'Параметры'), ('hdrInfo', 'Сведения'), ('lblInfoProperties', 'Свойства'),
    ('lblInfoRelated', 'Связанные пользователи'), ('lblInfoAuthor', 'Автор: пользователь FMR Write'),
    ('lblInfoStreamed', 'Всё на этой странице загружено из WordLikeMain.fmx.'),
    ('tileProtect', 'Защита документа'), ('tileInspect', 'Поиск проблем'), ('tileHistory', 'Журнал версий'),
    ('lblInfoTitle0', 'Защита документа'), ('lblInfoTitle1', 'Инспектор документов'),
    ('lblInfoTitle2', 'Журнал версий'), ('hdrNew', 'Создать'),
    ('lblNewHint', 'Выберите шаблон. Картинки страниц взяты из TImageList, сохранённого в форме.'),
    ('hdrOpen', 'Открыть'), ('tileOpenRecent', 'Последние'), ('tileOpenBrowse', 'Обзор'),
    ('hdrSaveAs', 'Сохранить как'), ('tileSavePC', 'Этот компьютер'), ('tileSavePC#d', 'Документы\FMR Write'),
    ('tileSaveBrowse', 'Обзор'), ('lblSaveTitle', 'Документы'), ('edSaveName', 'Имя файла'),
    ('btnSaveAsGo', 'Сохранить'), ('hdrPrint', 'Печать'), ('tilePrint', 'Печать'), ('lblCopies', 'Копии'),
    ('lblPrinterTitle', 'Принтер'), ('lblPrintSettings', 'Настройка'),
    ('lblPrintNote', 'Печать имитируется: на принтер ничего не отправляется.'),
    ('hdrOptions', 'Параметры'), ('lblOptGeneral', 'Общие'), ('lblOptTheme', 'Тема Office'),
    ('lblOptAccent', 'Цвет акцента'), ('lblOptFrame', 'Рамка окна'),
    ('lblOptBackdrop', 'Фон (рамка Dwm, Windows 11)'), ('lblOptLanguage', 'Язык'), ('lblOptRibbon', 'Лента'),
    ('chkOptSimplified', 'Упрощённая лента (одна строка команд)'),
    ('chkOptTouch', 'Сенсорный режим (крупные команды)'),
    ('chkOptQATBelow', 'Показывать панель быстрого доступа под лентой'),
    ('chkOptSearch', 'Поле поиска («Что вы хотите сделать?»)'),
    ('chkOptScreenTips', 'Показывать всплывающие подсказки'), ('btnOptCustomize', 'Настроить ленту...'),
    ('btnOptReset', 'Сбросить настройки'),
    ('lblOptNote', 'Тема, акцент, рамка, язык, масштаб и раскладка ленты (layout.json) сохраняются в ' +
      '%APPDATA%\FMRWrite при закрытии окна.'),
    ('hdrAbout', 'О программе'),
    ('lblAboutText', 'Демонстрационное приложение FMR Ribbon - открытой (MIT) ленты в стиле Microsoft Office для ' +
      'Delphi FireMonkey: менеджер команд с элементами и ссылками, лента с коллекциями, контекстными вкладками и ' +
      'панелью быстрого доступа, рамка окна со строкой вкладок в неклиентской области, представление Backstage и ' +
      'строка состояния.'),
    ('lblAboutForm', 'Всё окно загружается из WordLikeMain.fmx: файл записан программой ' +
      'Demos\WordLike\tools\GenForm, его можно открыть в дизайнере форм IDE.'),
    // find panel
    ('lblFind', 'Найти'), ('edFind', 'Поиск в документе'), ('btnFindPrev', 'Назад'), ('btnFindNext', 'Далее'),
    ('lblReplace', 'Заменить на'), ('edReplace', 'Новый текст'), ('btnReplaceOne', 'Заменить'),
    ('btnReplaceAll', 'Заменить все'));

  /// Components of the Word 2024 layout (caption row, tab row, the 2024 Home tab, status bar).
  Texts2024: array [0..45] of array [0..1] of string = (
    ('chkAutoSave', 'Автосохранение'), ('btnUndoAll', 'Отменить все изменения'),
    ('btnAccount', 'Учетная запись'), ('btnAccountName', 'Пользователь FMR Write'),
    ('btnAccountSwitch', 'Сменить учетную запись'), ('btnShare', 'Общий доступ'),
    ('btnShare#d', 'Пригласить других к совместной работе над документом.'), ('btnShareLink', 'Копировать ссылку'),
    ('btnShareCopy', 'Отправить копию'), ('btnComments', 'Примечания'),
    ('btnFormatPainter', 'Формат по образцу'),
    ('btnFormatPainter#d', 'Скопировать форматирование выделенного фрагмента и применить его к другому.'),
    ('btnSubscript#d', 'Подстрочный знак: очень маленькие буквы ниже строки.'),
    ('btnSuperscript#d', 'Надстрочный знак: очень маленькие буквы над строкой.'),
    ('btnTextEffects', 'Текстовые эффекты и оформление'), ('clrHighlight', 'Цвет выделения текста'),
    ('btnMultilevel', 'Многоуровневый список'), ('btnShowMarks', 'Отобразить все знаки'),
    ('btnLineSpacing', 'Интервал между строками и абзацами'), ('btnSpacing10', '1,0'), ('btnSpacing115', '1,15'),
    ('btnSpacing15', '1,5'), ('btnSpacing20', '2,0'), ('clrShading', 'Заливка'), ('btnBorders', 'Границы'),
    ('btnSelect', 'Выделить'), ('btnSelectSimilar', 'Выделить текст с похожим форматированием'),
    ('btnAdvancedFind', 'Расширенный поиск...'), ('btnGoTo', 'Перейти...'),
    ('grpAddins', 'Надстройки'), ('btnAddins', 'Надстройки'),
    ('btnAddins#d', 'Найти надстройки для Word и управлять ими.'),
    ('btnOfficeTheme', 'Тема Office'), ('btnThemeLight', 'Светлая'), ('btnThemeDarkGray', 'Темно-серая'),
    ('btnThemeDark', 'Черная'), ('btnThemeSystem', 'Использовать системный параметр'),
    ('spAccessibility', 'Специальные возможности: все в порядке'), ('spDisplay', 'Параметры отображения'),
    ('spFocus', 'Фокусировка'), ('btnAlignLeft', 'Выровнять по левому краю'), ('btnAlignCenter', 'По центру'),
    ('btnAlignRight', 'Выровнять по правому краю'), ('btnJustify', 'По ширине'), ('btnBullets', 'Маркеры'),
    ('btnNumbering', 'Нумерация'));

var
  Table: TDictionary<string, string>;

function WriteRussianText(const AKey: string; out AText: string): Boolean;
var
  I: Integer;
begin
  if Table = nil then
  begin
    Table := TDictionary<string, string>.Create;
    for I := 0 to High(Texts) do
      Table.AddOrSetValue(Texts[I][0].ToLower, Texts[I][1]);
    for I := 0 to High(Texts2024) do
      Table.AddOrSetValue(Texts2024[I][0].ToLower, Texts2024[I][1]);
  end;
  Result := Table.TryGetValue(AKey.ToLower, AText);
end;

initialization

finalization
  Table.Free;

end.
