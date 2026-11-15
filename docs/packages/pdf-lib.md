---
icon: lucide/file-text
---

# PDF Library

Create, load and edit PDF files in Dart with `dox_pdf_lib`, and send them from a Dox controller.

`dox_pdf_lib` draws text, shapes, SVG paths, JPEG and PNG images. It also does forms, attachments, metadata, custom fonts, and PDF/A and PDF/X. It has the API of the pdf-lib JavaScript library.

The package is standalone. It does not need Dox, and Dox does not need it. To fill pdfme templates, see [pdfme](pdfme.md).

## Install

```bash
dart pub add dox_pdf_lib
```

## Sending a PDF from a controller

A controller can return a `DownloadableFile`. Dox streams the bytes and sets `Content-Type` and `Content-Disposition`. The browser saves the file. See [Response](../the-basic/response.md).

Use `StreamFile` instead to show the PDF in the browser tab.

```dart title="lib/app/http/controllers/report.controller.dart"
import 'dart:io';
import 'dart:typed_data';

import 'package:dox_core/dox_core.dart';
import 'package:dox_pdf_lib/dox_pdf_lib.dart';

@Inject()
class ReportController {
  Future<DownloadableFile> show(DoxRequest req) async {
    PDFDocument doc = await PDFDocument.create();
    PDFFont font = await doc.embedFont(StandardFonts.helvetica);
    PDFPage page = doc.addPage(PageSizes.A4);
    page.drawText('Monthly report', x: 50, y: 750, font: font, size: 24);

    Uint8List bytes = await doc.save();
    return DownloadableFile(
      ContentType('application', 'pdf'),
      Stream<List<int>>.value(bytes),
      'report.pdf',
      length: bytes.length,
    );
  }
}
```

```dart title="lib/routes/api.dart"
Route.get('/report.pdf', (ReportController c) => c.show);
```

## Using other fonts

The 14 standard PDF fonts, like Helvetica, are built in. They only have Latin letters. For other languages, embed your own TrueType or OpenType font. Use `subset: true` to put only the letters you use into the file.

```dart
Uint8List bytes = File('NotoSansThai-Regular.ttf').readAsBytesSync();
PDFFont thai = await doc.embedFont(bytes, subset: true);
page.drawText('สวัสดีครับ', x: 50, y: 700, font: thai, size: 20);
```

Thai, Myanmar, Khmer, Lao, Arabic, Hebrew and Hindi text is laid out correctly. Line breaks in Myanmar, Thai, Khmer and Lao go between words.

## PDF/A and PDF/X

PDF/A is for long-term archives. PDF/X is for print. One call, `setConformance`, sets up a document for the standard you pick.

You bring the ICC profile. The package ships none.

```dart
Uint8List srgb = File('sRGB2014.icc').readAsBytesSync();

PDFDocument doc = await PDFDocument.create();
doc.setTitle('Annual report');
doc.setConformance(
  PDFStandard.pdfA2b,
  iccProfile: srgb,
  outputConditionIdentifier: 'sRGB IEC61966-2.1',
);

// PDF/A needs fonts from a font file. Standard fonts do not work.
PDFFont font = await doc.embedFont(
  File('NotoSans-Regular.ttf').readAsBytesSync(),
  subset: true,
);
doc.addPage().drawText('Kept for a long time', x: 50, y: 750, font: font);

for (ConformanceIssue issue in doc.checkConformance(PDFStandard.pdfA2b)) {
  print(issue);
}
```

`checkConformance` lists what is still wrong. For PDF/X, use `PDFStandard.pdfX1a`, `pdfX3` or `pdfX4`, and give each page a trim box. The [dox_pdf_lib README](https://pub.dev/packages/dox_pdf_lib) has the full list of rules.

## Platforms

`dox_pdf_lib` uses `dart:ffi` and a small native library. It runs in Dart programs on macOS, Linux and Windows.

It does not run on the web, iOS or Android.

A ready-built native library is downloaded for you, so you do not need Rust.

On Linux, the ready-built library needs glibc 2.35 or newer, for example Ubuntu 22.04 or Debian 12. On older Linux, or on Alpine, build the library yourself. The [dox_pdf_lib README](https://pub.dev/packages/dox_pdf_lib) shows how.

## Without Dox

The same code works in any Dart program. Call `PDFDocument.create()`, then write the bytes to a file:

```dart
import 'dart:io';

import 'package:dox_pdf_lib/dox_pdf_lib.dart';

Future<void> main() async {
  PDFDocument doc = await PDFDocument.create();
  PDFFont font = await doc.embedFont(StandardFonts.helvetica);
  PDFPage page = doc.addPage(PageSizes.A4);
  page.drawText('Hello, PDF!', x: 50, y: 750, font: font, size: 30);
  File('hello.pdf').writeAsBytesSync(await doc.save());
}
```

## Learn more

- [`dox_pdf_lib` on pub.dev](https://pub.dev/packages/dox_pdf_lib): pages, forms, attachments, images, metadata and the full API.
- [Source on GitHub](https://github.com/dartondox/dox-pdf-lib)
