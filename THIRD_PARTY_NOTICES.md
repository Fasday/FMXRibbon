# Third-party notices

FMR Ribbon is MIT-licensed (see [LICENSE](LICENSE)). It includes the following third-party material.

## Fluent UI System Icons

`Assets/Fonts/FmrFluentIcons.ttf` ("FMR Fluent Icons") is a subset of `fonts/FluentSystemIcons-Resizable.ttf` of
Microsoft's Fluent UI System Icons (https://github.com/microsoft/fluentui-system-icons, commit
`a347af95478f989038cccbf085978865264c048a`): the icons named in `tools/IconFont/segoe-fluent-map.txt`, at their
original code points, with the font renamed. Made by `tools/IconFont/make-icon-font.ps1`. It replaces the icons of
the Windows fonts Segoe Fluent Icons / Segoe MDL2 Assets where those are not installed (Linux); no outline of the
Segoe fonts is included in this repository.

```
MIT License

Copyright (c) 2020 Microsoft Corporation

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

## Not included

- Programs built for Linux64 use FMXWayland (a separate MIT project) and a `FMUX.Api.pas` that its tools generate
  from the local Delphi installation into `dcu\Linux64\gen` (Embarcadero's interface section; never committed).
- `libsk4d.so` / `sk4d.dll` (Skia4Delphi, part of RAD Studio's redistributables) are copied from the local Delphi
  installation next to the built programs.
