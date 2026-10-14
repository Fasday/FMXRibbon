{*******************************************************}
{                                                       }
{  FMR Ribbon for FireMonkey                            }
{  FMR Notes demo: shared data                          }
{                                                       }
{  MIT License. Copyright (c) 2026 Fasday               }
{                                                       }
{*******************************************************}

unit NotesData;

/// Data shared by the form generator (tools\GenForm) and the demo: text styles, shapes, symbols, table sizes,
/// note templates and accent colors. Gallery entries keep an index into these tables in their Tag.

interface

uses
  System.Types, System.UITypes;

type
  TNoteStyle = record
    Name: string;
    NameRu: string;
    Family: string;
    Size: Single;
    Style: TFontStyles;
    Color: TAlphaColor;
    /// <summary>A paragraph style (the gallery shows a pilcrow before its name).</summary>
    Para: Boolean;
  end;
  TNoteShape = record
    Name: string;
    Path: string;
    Text: string;
  end;

  TNoteTemplate = record
    Name: string;
    NameRu: string;
    Description: string;
    Text: string;
  end;

  TNoteAccent = record
    Name: string;
    NameRu: string;
    Color: TAlphaColor;
  end;

const
  /// <summary>The quick styles of the notes editor, in the order of the Styles gallery.</summary>
  NoteStyles: array [0..15] of TNoteStyle = (
    (Name: 'Normal'; NameRu: 'Обычный'; Family: 'Segoe UI'; Size: 12; Style: []; Color: 0; Para: True),
    (Name: 'Compact'; NameRu: 'Компактный'; Family: 'Segoe UI'; Size: 11; Style: []; Color: 0; Para: True),
    (Name: 'Heading 1'; NameRu: 'Заголовок 1'; Family: 'Segoe UI Semibold'; Size: 20; Style: []; Color: $FF1D4E89;
      Para: False),
    (Name: 'Heading 2'; NameRu: 'Заголовок 2'; Family: 'Segoe UI Semibold'; Size: 16; Style: []; Color: $FF1D4E89;
      Para: False),
    (Name: 'Title'; NameRu: 'Название'; Family: 'Segoe UI Light'; Size: 28; Style: []; Color: 0; Para: False),
    (Name: 'Subtitle'; NameRu: 'Подзаголовок'; Family: 'Segoe UI'; Size: 14; Style: []; Color: $FF5C5C5C; Para: False),
    (Name: 'Aside'; NameRu: 'Ремарка'; Family: 'Segoe UI'; Size: 12; Style: [TFontStyle.fsItalic]; Color: $FF4A4A4A;
      Para: False),
    (Name: 'Emphasis'; NameRu: 'Выделение'; Family: 'Segoe UI'; Size: 12; Style: [TFontStyle.fsItalic]; Color: 0;
      Para: False),
    (Name: 'Key Point'; NameRu: 'Главное'; Family: 'Segoe UI Semibold'; Size: 12; Style: []; Color: $FF1D4E89;
      Para: False),
    (Name: 'Strong'; NameRu: 'Жирный'; Family: 'Segoe UI'; Size: 12; Style: [TFontStyle.fsBold]; Color: 0;
      Para: False),
    (Name: 'Quote'; NameRu: 'Цитата'; Family: 'Georgia'; Size: 12; Style: [TFontStyle.fsItalic]; Color: $FF4A4A4A;
      Para: False),
    (Name: 'Callout'; NameRu: 'Выноска'; Family: 'Segoe UI Semibold'; Size: 13; Style: []; Color: $FF8A4B08;
      Para: False),
    (Name: 'Note'; NameRu: 'Примечание'; Family: 'Segoe UI'; Size: 10; Style: []; Color: $FF666666; Para: False),
    (Name: 'Code'; NameRu: 'Код'; Family: 'Consolas'; Size: 11; Style: []; Color: $FF2E2E2E; Para: False),
    (Name: 'Caption'; NameRu: 'Подпись'; Family: 'Segoe UI'; Size: 10;
      Style: [TFontStyle.fsBold, TFontStyle.fsItalic]; Color: 0; Para: False),
    (Name: 'List'; NameRu: 'Список'; Family: 'Segoe UI'; Size: 12; Style: []; Color: 0; Para: True));
  NoteShapes: array [0..14] of TNoteShape = (
    (Name: 'Square'; Path: 'M4,4 L20,4 L20,20 L4,20 Z'; Text: '■'),
    (Name: 'Hollow Square'; Path: 'M4,4 L20,4 L20,20 L4,20 Z M6,6 L6,18 L18,18 L18,6 Z'; Text: '□'),
    (Name: 'Circle'; Path: 'M12,4 A8,8 0 1 1 11.99,4 Z'; Text: '●'),
    (Name: 'Hollow Circle'; Path: 'M12,4 A8,8 0 1 1 11.99,4 Z M12,6 A6,6 0 1 0 12.01,6 Z'; Text: '○'),
    (Name: 'Triangle'; Path: 'M12,3 L22,20 L2,20 Z'; Text: '▲'),
    (Name: 'Diamond'; Path: 'M12,2 L22,12 L12,22 L2,12 Z'; Text: '◆'),
    (Name: 'Star'; Path: 'M12,2 L14.9,8.6 L22,9.3 L16.6,14 L18.2,21 L12,17.3 L5.8,21 L7.4,14 L2,9.3 L9.1,8.6 Z';
      Text: '★'),
    (Name: 'Heart'; Path: 'M12,21 L4,13 Q1,9.5 4,6 Q8,3 12,7.5 Q16,3 20,6 Q23,9.5 20,13 Z'; Text: '♥'),
    (Name: 'Right Arrow'; Path: 'M2,8 L13,8 L13,3 L22,12 L13,21 L13,16 L2,16 Z'; Text: '→'),
    (Name: 'Left Arrow'; Path: 'M22,8 L11,8 L11,3 L2,12 L11,21 L11,16 L22,16 Z'; Text: '←'),
    (Name: 'Up Arrow'; Path: 'M8,22 L8,11 L3,11 L12,2 L21,11 L16,11 L16,22 Z'; Text: '↑'),
    (Name: 'Down Arrow'; Path: 'M8,2 L8,13 L3,13 L12,22 L21,13 L16,13 L16,2 Z'; Text: '↓'),
    (Name: 'Double Arrow'; Path: 'M2,9 L15,9 L15,4 L22,12 L15,20 L15,15 L2,15 Z M5,11 L5,13 L17,13 L17,11 Z';
      Text: '⇒'),
    (Name: 'Check Mark'; Path: 'M3,13 L6,10 L10,14 L19,4 L22,7 L10,20 Z'; Text: '✓'),
    (Name: 'Cross'; Path: 'M5,3 L12,10 L19,3 L21,5 L14,12 L21,19 L19,21 L12,14 L5,21 L3,19 L10,12 L3,5 Z';
      Text: '✗'));

  NoteSymbols: array [0..23] of string = ('©', '®', '™', '€', '£', '¥', '§', '¶', '±', '×', '÷', '≠', '≤', '≥', '∞',
    '°', 'µ', 'α', 'β', 'π', 'Ω', '∑', '√', '…');

  /// <summary>Quick tables: columns × rows.</summary>
  NoteTables: array [0..8] of TPoint = ((X: 2; Y: 2), (X: 3; Y: 2), (X: 3; Y: 3), (X: 4; Y: 2), (X: 4; Y: 3),
    (X: 4; Y: 4), (X: 5; Y: 3), (X: 5; Y: 5), (X: 6; Y: 4));

  NoteTemplates: array [0..5] of TNoteTemplate = (
    (Name: 'Blank note'; NameRu: 'Пустая заметка'; Description: 'Start from an empty page'; Text: ''),
    (Name: 'To-do list'; NameRu: 'Список дел'; Description: 'Tasks with check boxes';
      Text: 'To do' + #13#10#13#10 + '☐ Answer the mail' + #13#10 + '☐ Book the meeting room' + #13#10 +
        '☐ Review the release notes' + #13#10 + '☑ Try FMR Notes' + #13#10#13#10 +
        'Created from the To-do list template of the New page of the backstage view.'),
    (Name: 'Report'; NameRu: 'Отчёт'; Description: 'Quarterly report with sections';
      Text: 'Quarterly Report' + #13#10#13#10 + '1. Summary' + #13#10 +
        'Sales grew by 12% compared with the previous quarter.' + #13#10#13#10 + '2. Highlights' + #13#10 +
        '• New ribbon user interface' + #13#10 + '• Faster start-up' + #13#10 + '• Dark themes' + #13#10#13#10 +
        '3. Next steps' + #13#10 + 'Ship the release candidate.'),
    (Name: 'Journal'; NameRu: 'Дневник'; Description: 'A page for the day';
      Text: 'Journal' + #13#10 + 'Date: ' + #13#10#13#10 + 'Today' + #13#10 + '• ' + #13#10#13#10 +
        'Ideas' + #13#10 + '• ' + #13#10#13#10 + 'Tomorrow' + #13#10 + '☐ '),
    (Name: 'Meeting notes'; NameRu: 'Протокол встречи'; Description: 'Agenda, notes and action items';
      Text: 'Meeting Notes' + #13#10 + 'Date: ' + #13#10 + 'Attendees: ' + #13#10#13#10 + 'Agenda' + #13#10 +
        '1. ' + #13#10 + '2. ' + #13#10#13#10 + 'Action items' + #13#10 + '☐ ' + #13#10 + '☐ '),
    (Name: 'Release notes'; NameRu: 'Заметки о выпуске'; Description: 'What is new in this version';
      Text: 'FMR Ribbon - release notes' + #13#10#13#10 + 'New' + #13#10 + '• Backstage view and status bar' +
        #13#10 + '• Customization form' + #13#10 + '• 21 themes' + #13#10#13#10 + 'Fixed' + #13#10 +
        '• Key tips with a Cyrillic keyboard layout'));

  NoteAccents: array [0..7] of TNoteAccent = (
    (Name: 'Theme default'; NameRu: 'По умолчанию'; Color: 0),
    (Name: 'Blue'; NameRu: 'Синий'; Color: $FF2B579A),
    (Name: 'Green'; NameRu: 'Зелёный'; Color: $FF107C41),
    (Name: 'Orange'; NameRu: 'Оранжевый'; Color: $FFC43E1C),
    (Name: 'Azure'; NameRu: 'Лазурный'; Color: $FF0072C6),
    (Name: 'Purple'; NameRu: 'Фиолетовый'; Color: $FF80397B),
    (Name: 'Crimson'; NameRu: 'Малиновый'; Color: $FFA4373A),
    (Name: 'Sky'; NameRu: 'Голубой'; Color: $FF0067C0));

  /// <summary>Icon of the caption row: an amber notepad with a binding strip and ruled lines.</summary>
  SvgAppIcon = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 32 32">' +
    '<rect x="5" y="4" width="22" height="25" rx="3" fill="#F6C343"/>' +
    '<path d="M5 7a3 3 0 0 1 3-3h16a3 3 0 0 1 3 3v4H5z" fill="#D4911A"/>' +
    '<circle cx="11" cy="7.5" r="1.3" fill="#FFF3D6"/><circle cx="16" cy="7.5" r="1.3" fill="#FFF3D6"/>' +
    '<circle cx="21" cy="7.5" r="1.3" fill="#FFF3D6"/>' +
    '<path d="M9.5 16h13M9.5 20h13M9.5 24h8" stroke="#8A5A00" stroke-width="1.6" stroke-linecap="round"/></svg>';
  /// <summary>Paste: an amber clipboard under a page; Format arguments: the line color of the page and of the
  /// clip, the fill of the page (the body of the theme).</summary>
  SvgPasteFmt = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 32 32">' +
    '<path d="M8.5 6.5H5.5v21h9" fill="none" stroke="#D4911A" stroke-width="1.6"/>' +
    '<path d="M17.5 6.5h3v5" fill="none" stroke="#D4911A" stroke-width="1.6"/>' +
    '<rect x="9" y="3.8" width="8" height="4.4" rx="1" fill="none" stroke="%0:s" stroke-width="1.3"/>' +
    '<rect x="14.6" y="12.6" width="13" height="16" fill="%1:s" stroke="%0:s" stroke-width="1.3"/></svg>';
  /// <summary>Add-ins: a frame with four squares.</summary>
  SvgAddins = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 32 32"><g fill="none" stroke="#3E7CB1" ' +
    'stroke-width="1.6"><rect x="3.8" y="3.8" width="24.4" height="24.4"/><rect x="7.8" y="7.8" width="7.4" ' +
    'height="7.4"/><rect x="16.8" y="7.8" width="7.4" height="7.4"/><rect x="7.8" y="16.8" width="7.4" ' +
    'height="7.4"/><rect x="16.8" y="16.8" width="7.4" height="7.4"/></g></svg>';

  PathTable = 'M3,4 L8,4 L8,8 L3,8 Z M9.5,4 L14.5,4 L14.5,8 L9.5,8 Z M16,4 L21,4 L21,8 L16,8 Z ' +
    'M3,10 L8,10 L8,14 L3,14 Z M9.5,10 L14.5,10 L14.5,14 L9.5,14 Z M16,10 L21,10 L21,14 L16,14 Z ' +
    'M3,16 L8,16 L8,20 L3,20 Z M9.5,16 L14.5,16 L14.5,20 L9.5,20 Z M16,16 L21,16 L21,20 L16,20 Z';
  PathShapes = 'M3,12 L11,12 L11,20 L3,20 Z M17,3 L22,12 L12,12 Z M14,15 L21,15 L21,21 L14,21 Z';
  PathStyle = 'M3,19 L8,5 L10,5 L15,19 L12.8,19 L11.6,15.5 L6.4,15.5 L5.2,19 Z M7.1,13.5 L10.9,13.5 L9,8 Z ' +
    'M16,13 L21,13 L21,14.5 L16,14.5 Z M16,17 L21,17 L21,18.5 L16,18.5 Z';
  PathWatermark = 'M4,3 L20,3 L20,21 L4,21 Z M6,5 L6,19 L18,19 L18,5 Z M7.5,15 L15,7.5 L16.5,9 L9,16.5 Z';
  PathPalette = 'M12,3 A9,9 0 1 0 12,21 Q14,21 14,19 Q14,18 13,17 Q12,16 13,15 L16,15 A5,5 0 0 0 21,10 ' +
    'Q21,3 12,3 Z M7,9 A1.5,1.5 0 1 1 7,12 A1.5,1.5 0 1 1 7,9 Z M10,5.5 A1.5,1.5 0 1 1 10,8.5 A1.5,1.5 0 1 1 ' +
    '10,5.5 Z M15,6 A1.5,1.5 0 1 1 15,9 A1.5,1.5 0 1 1 15,6 Z';

implementation

end.
