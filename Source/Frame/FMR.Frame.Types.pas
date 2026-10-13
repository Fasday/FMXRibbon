{*******************************************************}
{                                                       }
{  FMR Ribbon for FireMonkey                            }
{  Shared types of the form frame (title bar area)      }
{                                                       }
{  MIT License. Copyright (c) 2026 Fasday               }
{                                                       }
{*******************************************************}

unit FMR.Frame.Types;

interface

uses
  System.Types, System.Classes, System.Messaging, FMX.Types;

type
  /// <summary>How the top of a form (title bar, ribbon tabs) is made.</summary>
  TFmrFrameMode = (
    /// <summary>The top non-client area is removed; the caption content is drawn by FMX in the client area over a
    /// DWM frame extended into it: Mica/Acrylic, system shadow and corners, GPU rendering. Office, DevExpress (Aero
    /// mode), Chrome and VS Code do this.</summary>
    Dwm,
    /// <summary>The caption content lives in the real non-client area (WM_NCCALCSIZE, WM_NCPAINT): GetClientRect
    /// starts below it. FMX controls in it are painted into a bitmap and copied to the window DC.</summary>
    FullNC,
    /// <summary>The system title bar drawn by DWM stays; below it a real non-client strip with the caption content
    /// (like the menu bar of a classic window).</summary>
    NCStrip);

  /// <summary>What a point of the caption area is for the window manager.</summary>
  TFmrHitArea = (
    /// <summary>Let the frame decide: an interactive control is Client, empty space is Caption.</summary>
    Default,
    /// <summary>Mouse messages go to FMX (buttons, edits, tabs).</summary>
    Client,
    /// <summary>Drags the window; double click maximizes; right click shows the system menu.</summary>
    Caption,
    SysMenu,
    MinButton,
    MaxButton,
    CloseButton,
    HelpButton,
    /// <summary>Transparent for the caption: the window manager sees what is under it (sizing border).</summary>
    Nowhere);

  /// <summary>Implemented by controls in a frame host that decide what the window manager does at a point. A tab row
  /// returns Client over a tab and Caption over the empty space between tabs; caption buttons return MinButton,
  /// MaxButton or CloseButton. The frame asks the deepest control under the cursor and then its parents up to the
  /// host; the first answer other than Default wins.</summary>
  IFmrFrameHitTest = interface
    ['{6F2B3C1E-6A41-4C7B-9D0E-2A9F5B3C7D11}']
    function FrameHitTest(const ALocalPoint: TPointF): TFmrHitArea;
  end;

  /// <summary>Implemented by caption buttons whose hot/pressed state the frame drives: over HTMINBUTTON, HTMAXBUTTON
  /// and HTCLOSE (needed for Windows 11 Snap Layouts) the window manager keeps the mouse messages instead of giving
  /// them to FMX.</summary>
  IFmrFrameButton = interface
    ['{0B7E5D2A-3C94-4E61-8F1A-7D2C9E4B5A22}']
    function GetFrameButtonKind: TFmrHitArea;
    procedure SetFrameButtonState(const AHot, APressed: Boolean);
  end;

  /// <summary>State of the window shown by the caption content.</summary>
  TFmrFrameState = record
    Active: Boolean;
    Maximized: Boolean;
    Minimized: Boolean;
    Mode: TFmrFrameMode;
    /// <summary>Extra top padding (dp) the caption content must leave when the window is maximized and part of it is
    /// outside the monitor (0 when the frame handles it itself).</summary>
    MaximizedTopOffset: Single;
    /// <summary>The frame uses dark colors (DWM dark mode of the window border, default colors of caption
    /// buttons).</summary>
    DarkMode: Boolean;
    /// <summary>The caption background is transparent: a system backdrop (Mica, Acrylic) shows through it.</summary>
    Transparent: Boolean;
  end;

  /// <summary>System backdrop material of the window (Windows 11 22H2 and later; ignored elsewhere).</summary>
  TFmrFrameBackdrop = (
    /// <summary>No system material: the caption is painted with its color.</summary>
    None,
    /// <summary>Mica: tinted with the desktop wallpaper (main windows).</summary>
    Mica,
    /// <summary>Acrylic: blurred see-through material (transient windows).</summary>
    Acrylic,
    /// <summary>Mica Alt ("tabbed"): stronger wallpaper tint, used behind tab rows.</summary>
    Tabbed);

  /// <summary>Window commands that caption content (caption buttons, an application icon) asks the frame for. Implemented
  /// by the frame component; the frame host passes it to its children.</summary>
  IFmrFrameCommands = interface
    ['{4D8E2A61-7C3B-4F05-9E1D-6B2A8C4F1E44}']
    procedure Minimize;
    procedure ToggleMaximize;
    procedure CloseForm;
    procedure ShowHelp;
    /// <summary>Shows the system (window) menu at a screen point (dp, FMX screen coordinates).</summary>
    procedure ShowSystemMenu(const AScreenPoint: TPointF);
  end;

  /// <summary>Sent (TMessageManager.DefaultManager) by a frame when the state of its window changes. Value: the
  /// frame host (TFmxObject) whose caption content should update.</summary>
  TFmrFrameStateMessage = class(TMessage)
  private
    FHost: TFmxObject;
    FState: TFmrFrameState;
  public
    constructor Create(const AHost: TFmxObject; const AState: TFmrFrameState);
    property Host: TFmxObject read FHost;
    property State: TFmrFrameState read FState;
  end;

  /// <summary>Optional interface of controls in a frame host that show the window state (caption buttons, title,
  /// ribbon caption). The frame calls it for every such control of its host.</summary>
  IFmrFrameStateAware = interface
    ['{9C1D4E7F-2B85-4A30-A6E9-5F8B1C3D7E33}']
    procedure FrameStateChanged(const AState: TFmrFrameState);
  end;

implementation

{ TFmrFrameStateMessage }

constructor TFmrFrameStateMessage.Create(const AHost: TFmxObject; const AState: TFmrFrameState);
begin
  inherited Create;
  FHost := AHost;
  FState := AState;
end;

end.
