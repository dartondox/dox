---
icon: lucide/file-text
---

# pdfme

Make PDF files from [pdfme](https://pdfme.com) templates in Dart with `dox_pdf_me`, and send them from a Dox controller.

You design the template in the pdfme designer, then fill it with data on the server. `dox_pdf_me` reads the same template JSON as pdfme, and the PDF looks the same.

The package is standalone. It does not need Dox, and Dox does not need it. It is built on [PDF Library](pdf-lib.md).

## Setup

```bash
dart pub add dox_pdf_me
```

## Filling a template

Design the template in the pdfme designer and save its JSON. Read it with `Template.fromJson`. The inputs are one map of strings for each copy of the template.

A controller can return a `DownloadableFile`. Dox streams the bytes and sets `Content-Type` and `Content-Disposition`. The browser saves the file. See [Response](../the-basic/response.md).

Use `StreamFile` instead to show the PDF in the browser tab.

```dart title="lib/app/http/controllers/invoice.controller.dart"
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dox_core/dox_core.dart';
import 'package:dox_pdf_me/dox_pdf_me.dart';

@Inject()
class InvoiceController {
  Future<DownloadableFile> show(DoxRequest req) async {
    Map<String, Object?> json =
        jsonDecode(File('storage/invoice.template.json').readAsStringSync())
            as Map<String, Object?>;

    Uint8List bytes = await generate(
      template: Template.fromJson(json),
      inputs: <Map<String, String>>[
        <String, String>{'customer': 'Jane Doe', 'total': '120.00'},
      ],
      plugins: builtInPlugins,
    );
    return DownloadableFile(
      ContentType('application', 'pdf'),
      Stream<List<int>>.value(bytes),
      'invoice.pdf',
      length: bytes.length,
    );
  }
}
```

```dart title="lib/routes/api.dart"
Route.get('/invoice.pdf', (InvoiceController c) => c.show);
```

`dox_pdf_me` supports text, image, svg, shapes, barcodes and QR codes, date and time, checkbox, radio group, select, table, multi variable text, signature and circle mark. Pass `builtInPlugins` to use all of them.

## Using other fonts

Text uses Roboto by default. For other languages, pass your fonts in `GenerateOptions`:

```dart
Uint8List noto = File('NotoSansJP-Regular.otf').readAsBytesSync();
Uint8List pdf = await generate(
  template: template,
  inputs: inputs,
  plugins: builtInPlugins,
  options: GenerateOptions(
    font: <String, FontSource>{
      'Roboto': FontStore.defaultFont,
      'NotoSansJP': FontSource(noto),
    },
  ),
);
```

Thai, Myanmar, Khmer, Lao, Arabic, Hebrew and Hindi text is laid out correctly. Line breaks in Myanmar, Thai, Khmer and Lao go between words.

## Platforms

`dox_pdf_me` uses `dox_pdf_lib`, which has a small native library. It runs in Dart programs on macOS, Linux and Windows.

It does not run on the web, iOS or Android.

A ready-built native library is downloaded for you, so you do not need Rust.

On Linux, the ready-built library needs glibc 2.35 or newer, for example Ubuntu 22.04 or Debian 12. On older Linux, or on Alpine, build the library yourself. The [dox_pdf_lib README](https://pub.dev/packages/dox_pdf_lib) shows how.

## Without Dox

The same code works in any Dart program. Call `generate(...)`, then write the bytes to a file:

```dart
import 'dart:io';
import 'dart:typed_data';

import 'package:dox_pdf_me/dox_pdf_me.dart';

Future<void> main() async {
  Uint8List pdf = await generate(
    template: Template(
      basePdf: const BlankPdf(),
      schemas: <List<Schema>>[
        <Schema>[
          const TextSchema(name: 'title', position: Position(20, 20), width: 170, height: 15),
          BarcodeSchema(name: 'link', barcodeType: BarcodeType.qrcode, position: const Position(20, 40)),
        ],
      ],
    ),
    inputs: <Map<String, String>>[
      <String, String>{'title': 'Hello, PDF!', 'link': 'https://dartondox.dev'},
    ],
    plugins: builtInPlugins,
  );
  File('hello.pdf').writeAsBytesSync(pdf);
}
```

## See also

- [`dox_pdf_me` on pub.dev](https://pub.dev/packages/dox_pdf_me): schema types, tables, plugins, fonts and options, and how to build a template in Dart.
- [Source on GitHub](https://github.com/dartondox/dox-pdf-lib)
