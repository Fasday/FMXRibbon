{*******************************************************}
{                                                       }
{  FMR Ribbon for FireMonkey                            }
{  Form with a built-in frame                           }
{                                                       }
{  MIT License. Copyright (c) 2026 Fasday               }
{                                                       }
{*******************************************************}

unit FMR.Frame.Form;

interface

uses
  System.Classes, FMX.Forms, FMR.Frame;

type
  /// <summary>A form with a built-in <c>TFmrFormFrame</c> (published as <see cref="Frame"/>, streamed with the
  /// form).</summary>
  TFmrForm = class(TForm)
  private
    FFrame: TFmrFormFrame;
    procedure SetFrame(const Value: TFmrFormFrame);
  public
    procedure InitializeNewForm; override;
  published
    /// <summary>The frame of the form: mode, caption height, host of the caption content.</summary>
    property Frame: TFmrFormFrame read FFrame write SetFrame;
  end;

implementation

{ TFmrForm }

procedure TFmrForm.InitializeNewForm;
begin
  inherited;
  // Created before the form's resource is read, so the streamed Frame.* properties find it.
  FFrame := TFmrFormFrame.Create(Self);
  FFrame.SetSubComponent(True);
end;

procedure TFmrForm.SetFrame(const Value: TFmrFormFrame);
begin
  FFrame.Assign(Value);
end;

end.
