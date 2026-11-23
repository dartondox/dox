---
icon: lucide/file-text
---

# PDF Library

Create, load and edit PDF files in Dart with `dox_pdf_lib`, and send them from a Dox controller.

The package draws text, shapes, SVG paths and images, and it does forms, attachments, metadata, custom fonts, and PDF/A and PDF/X. It has the API of the pdf-lib JavaScript library. To fill pdfme templates, see [pdfme](pdfme.md).

## Setup

```bash
dart pub add dox_pdf_lib
```

The package uses `dart:ffi` and a small native library. It runs in Dart programs on macOS, Linux and Windows, not on the web, iOS or Android. The package downloads a ready-built library, so you do not need Rust.

On Linux, the ready-built library needs glibc 2.35 or newer, like Ubuntu 22.04 or Debian 12. On older Linux or on Alpine, build the library with cargo and set its path in your `pubspec.yaml`:

```yaml title="pubspec.yaml"
hooks:
  user_defines:
    dox_pdf_lib:
      lib_path: /path/to/libdox_pdf_lib.so
```

## Sending a PDF from a controller

Return a `DownloadableFile`, and the browser saves the file. Use `StreamFile` to show the PDF in the browser tab. See [Response](../the-basic/response.md):

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

## Creating and loading a document

Make an empty document with `create`, or read a file with `load`:

```dart
PDFDocument doc = await PDFDocument.create();

PDFDocument old = await PDFDocument.load(
    File('in.pdf').readAsBytesSync());
```

A broken file throws `PDFParsingError`. An encrypted file throws `EncryptedPDFError`.

### Loading an encrypted file

Load it with `ignoreEncryption: true`. A file with only an owner password is decrypted, and `save` writes it with no encryption. A file with a user password throws `PDFParsingError`:

```dart
PDFDocument doc = await PDFDocument.load(bytes, ignoreEncryption: true);
print(doc.isEncrypted); // true
```

### Keeping the metadata

`create` and `load` set the producer and the modification date. They also add a creator and a creation date when the file has none. To keep the metadata as it is, pass `updateMetadata: false`:

```dart
PDFDocument doc = await PDFDocument.load(bytes, updateMetadata: false);
```

### Freeing a document

A document is freed when Dart removes the object. To free it now, call `dispose`:

```dart
doc.dispose();
```

## Saving a document

`save` gives the bytes of the file:

```dart
Uint8List bytes = await doc.save();
```

It has three options, all true by default:

| Option | What it does |
| --- | --- |
| `useObjectStreams` | Packs objects into object streams, for a smaller file. |
| `addDefaultPage` | Adds one page when the document has none. |
| `updateFieldAppearances` | Draws the form fields again when the form was used. |

### Saving as base64

Get a base64 string, or a data URI with `dataUri: true`:

```dart
String text = await doc.saveAsBase64(dataUri: true);
```

## Working with pages

### Adding pages

`addPage` adds a page at the end. Give a size from `PageSizes`, a width and height in points, or nothing for A4:

```dart
PDFPage page = doc.addPage(PageSizes.Letter);
doc.addPage(<double>[400, 600]);
doc.insertPage(0, PageSizes.A5);
doc.removePage(1);
```

`removePage` on a document with no pages throws `RemovePageFromEmptyDocumentError`.

### Reading pages

```dart
List<PDFPage> pages = doc.getPages();
PDFPage first = doc.getPage(0);
int count = doc.getPageCount();
List<int> indices = doc.getPageIndices(); // [0, 1, 2]
```

### Page sizes

`PageSizes` has the sizes in points, as `[width, height]`:

| Group | Names |
| --- | --- |
| A | `$4A0`, `$2A0`, `A0` to `A10` |
| B | `B0` to `B10` |
| C | `C0` to `C10` |
| RA and SRA | `RA0` to `RA4`, `SRA0` to `SRA4` |
| US and other | `Executive`, `Folio`, `Legal`, `Letter`, `Tabloid` |

### Changing the page size

```dart
print(page.getSize()); // (height: 841.89, width: 595.28)
page.setSize(420, 600);
page.setWidth(500);
page.setHeight(700);
```

`getWidth` and `getHeight` read one side. Boxes that had the size of the media box follow the new size.

### Page boxes

Each box has a get and a set method: media, crop, bleed, trim and art. A box is `(x, y, width, height)`:

```dart
page.setCropBox(10, 10, 400, 580);
PDFBox trim = page.getTrimBox();
```

The page methods are `getMediaBox`, `getCropBox`, `getBleedBox`, `getTrimBox` and `getArtBox`, and the same names with `set`. A missing crop box reads as the media box. A missing bleed, trim or art box reads as the crop box.

### Rotating a page

The angle must be a multiple of 90 degrees:

```dart
page.setRotation(degrees(90));
Degrees angle = page.getRotation();
```

| Function | Result |
| --- | --- |
| `degrees(90)`, `radians(1.57)` | A `Degrees` or `Radians` angle. |
| `toDegrees(angle)`, `toRadians(angle)` | The angle as a number. |
| `degreesToRadians(90)`, `radiansToDegrees(1.57)` | A number converted. |

### Moving and scaling the content

```dart
page.translateContent(10, 20); // moves what is on the page
page.scaleContent(0.5, 0.5);   // scales what is on the page
page.scaleAnnotations(0.5, 0.5);
page.scale(2, 2);              // page size, content and annotations
page.resetPosition();          // the text position goes back to 0, 0
```

## Copying and merging pages

`copyPages` copies pages of another document. Then add them with `addPage` or `insertPage`:

```dart
PDFDocument merged = await PDFDocument.create();
for (PDFDocument source in <PDFDocument>[a, b]) {
  List<PDFPage> pages =
      await merged.copyPages(source, source.getPageIndices());
  for (PDFPage page in pages) {
    merged.addPage(page);
  }
}
```

A page of another document that you did not copy throws `ForeignPageError`.

## Placing pages of another PDF

Use a page of another PDF as a background or a template. `embedPdf` takes bytes, a base64 string or a `PDFDocument`, and embeds the first page by default:

```dart
List<PDFEmbeddedPage> pages = await out.embedPdf(
    File('template.pdf').readAsBytesSync(), <int>[0, 1]);
PDFEmbeddedPage template = pages.first;

PDFPage page = out.addPage(<double>[template.width, template.height]);
page.drawPage(template);
page.drawText('Filled in on top', x: 50, y: 50);
```

`drawPage` takes `x`, `y`, `xScale`, `yScale`, `width`, `height`, `rotate`, `xSkew`, `ySkew`, `opacity` and `blendMode`. An embedded page has `width`, `height`, `size()` and `scale(factor)`.

### Embedding loaded pages

`embedPage` embeds one page. Give a bounding box to clip a part of it, and a matrix `[a, b, c, d, e, f]` to transform it:

```dart
PDFEmbeddedPage part = await out.embedPage(
  source.getPage(0),
  (left: 0, bottom: 400, right: 595, top: 842),
);
List<PDFEmbeddedPage> all = await out.embedPages(source.getPages());
```

All pages of `embedPages` must come from one document, or it throws `PageEmbeddingMismatchedContextError`.

## Adding text

`drawText` draws text at a point. A newline starts a new line:

```dart
page.drawText(
  'A long line of text that wraps inside 300 points.',
  x: 50,
  y: 700,
  font: bold,
  size: 14,
  color: rgb(0.1, 0.3, 0.8),
  maxWidth: 300,
  lineHeight: 18,
);
```

The options are `color`, `opacity`, `blendMode`, `font`, `size`, `rotate`, `xSkew`, `ySkew`, `x`, `y`, `lineHeight`, `maxWidth` and `wordBreaks`. With no font, the page uses Helvetica.

### Setting the text state

Set the font, size, color, line height and position one time. Then `drawText` uses them:

```dart
page.setFont(font);
page.setFontSize(12);    // default 24
page.setFontColor(grayscale(0.2));
page.setLineHeight(16);  // default 24
page.moveTo(50, 700);
page.drawText('First line');
page.moveDown(16);
page.drawText('Second line');
```

Also: `moveUp`, `moveLeft`, `moveRight`, `getPosition`, `getX` and `getY`. A font of another document throws an `ArgumentError`.

### Word breaks

With `maxWidth`, a line breaks at a space. Set other break characters for one call with `wordBreaks`, or for the document with `defaultWordBreaks`:

```dart
doc.defaultWordBreaks = <String>[' ', '-'];
page.drawText(text, maxWidth: 300, wordBreaks: <String>[' ', '/']);
```

### Word breaks in Thai, Lao, Khmer and Myanmar

These scripts have no spaces between words. `dictionaryWordBreaks` gives the index where each word starts:

```dart
List<int> breaks = dictionaryWordBreaks('ทุกสองสัปดาห์'); // [3, 6]
```

The indexes are UTF-16 indexes, like `String.substring`. The start and the end of the text are not in the list.

## Using fonts

### Standard fonts

The 14 standard PDF fonts need no font file. They have only Latin letters:

```dart
PDFFont font = await doc.embedFont(StandardFonts.timesRoman);
PDFFont same = doc.embedStandardFont(StandardFonts.timesRoman);
```

| Family | Values of `StandardFonts` |
| --- | --- |
| Courier | `courier`, `courierBold`, `courierOblique`, `courierBoldOblique` |
| Helvetica | `helvetica`, `helveticaBold`, `helveticaOblique`, `helveticaBoldOblique` |
| Times | `timesRoman`, `timesRomanBold`, `timesRomanItalic`, `timesRomanBoldItalic` |
| Symbols | `symbol`, `zapfDingbats` |

`fontName` gives the PostScript name, like `Times-Roman`. `embedFont` also takes that name as a string.

### Using other fonts

For other languages, embed a TrueType or OpenType font. `subset: true` puts only the letters you use into the file:

```dart
Uint8List bytes = File('NotoSansThai-Regular.ttf').readAsBytesSync();
PDFFont thai = await doc.embedFont(bytes, subset: true);
page.drawText('สวัสดีครับ', x: 50, y: 700, font: thai, size: 20);
```

Thai, Myanmar, Khmer, Lao, Arabic, Hebrew and Hindi text is laid out correctly. Use `subset: false` for a font in a form field that people edit, because a subset has only the letters known at save time.

`embedFont` also takes a base64 string or a data URI. Font collections (`.ttc`), WOFF files and CFF2 fonts do not work.

### Font options

`customName` replaces the font name in the file. `features` turns OpenType features on or off:

```dart
PDFFont font = await doc.embedFont(
  bytes,
  customName: 'BrandFont',
  features: <String, bool>{'liga': false},
);
```

### Measuring text

```dart
double width = font.widthOfTextAtSize('Hello', 12);
double height = font.heightAtSize(12);
double above = font.heightAtSize(12, descender: false);
double size = font.sizeAtHeight(20);
```

`getCharacterSet` gives the code points the font has. `encodeText` gives the text as a `PDFHexString` for raw operators. `name` is the PostScript name of the font.

## Colors

Each part is a number from 0 to 1:

```dart
Color red = rgb(1, 0, 0);
Color gray = grayscale(0.5);
Color black = cmyk(0, 0, 0, 1);
```

The functions give an `RGB`, `Grayscale` or `CMYK` object. A part out of range throws a `RangeError`.

## Drawing shapes

### Lines

```dart
page.drawLine(
  start: (x: 50, y: 650),
  end: (x: 350, y: 650),
  thickness: 2,
  color: grayscale(0.5),
  dashArray: <double>[4, 2],
);
```

A line also takes `opacity`, `lineCap`, `dashPhase` and `blendMode`.

### Rectangles and squares

A rectangle is 150 by 100 by default. With no color and no border color, it is filled black:

```dart
page.drawRectangle(
  x: 50,
  y: 500,
  width: 200,
  height: 100,
  color: rgb(1, 0.9, 0.9),
  borderColor: rgb(1, 0, 0),
  borderWidth: 2,
  opacity: 0.8,
);
page.drawSquare(x: 300, y: 500, size: 50);
```

### Ellipses and circles

`x` and `y` are the center. An ellipse has the radii `xScale` and `yScale`, and a circle has the radius `size`. Both are 100 by default:

```dart
page.drawEllipse(x: 200, y: 300, xScale: 80, yScale: 40);
page.drawCircle(x: 350, y: 550, size: 40, color: cmyk(0.5, 0, 0, 0));
```

### Shape options

| Option | What it does |
| --- | --- |
| `color`, `opacity` | The fill. |
| `borderColor`, `borderOpacity`, `borderWidth` | The border. |
| `borderDashArray`, `borderDashPhase` | A dashed border. |
| `borderLineCap` | `LineCapStyle.butt`, `round` or `projecting`. |
| `rotate`, `xSkew`, `ySkew` | An angle, like `degrees(30)`. Ellipses and circles take only `rotate`, and circles take none. |
| `blendMode` | One of `BlendMode`, see below. |

`BlendMode` has `normal`, `multiply`, `screen`, `overlay`, `darken`, `lighten`, `colorDodge`, `colorBurn`, `hardLight`, `softLight`, `difference` and `exclusion`.

## Drawing SVG paths

`drawSvgPath` draws the `d` attribute of an SVG path. Its y axis points down, as in SVG. With no color and no border color, the border is black:

```dart
page.drawSvgPath(
  'M 0,20 L 100,160 Q 130,200 150,120 Z',
  x: 50,
  y: 450,
  scale: 0.5,
  color: rgb(0, 0.5, 0),
);
```

It takes the shape options, without `xSkew` and `ySkew`.

## Adding images

Embed a PNG or a JPEG, then draw it. The default size is the size in pixels:

```dart
PDFImage png = await doc.embedPng(File('logo.png').readAsBytesSync());
PDFImage jpg = await doc.embedJpg(File('photo.jpg').readAsBytesSync());

page.drawImage(png, x: 50, y: 700, width: 100, height: 50);
```

`drawImage` also takes `rotate`, `xSkew`, `ySkew`, `opacity` and `blendMode`. The embed methods also take a base64 string or a data URI.

### Image sizes

```dart
({double width, double height}) fit = jpg.scaleToFit(200, 200);
({double width, double height}) half = jpg.scale(0.5);
({double width, double height}) full = jpg.size();
```

`width` and `height` of a `PDFImage` are the size in pixels.

## Raw operators

`pushOperators` adds PDF operators to the page content:

```dart
page.pushOperators(<PDFOperator>[
  pushGraphicsState(),
  setFillingRgbColor(0.9, 0.1, 0.1),
  rectangle(520, 40, 50, 30),
  fill(),
  popGraphicsState(),
]);
```

| Group | Functions |
| --- | --- |
| State | `pushGraphicsState`, `popGraphicsState`, `setGraphicsState`, `setLineWidth`, `setLineCap`, `setLineJoin`, `setDashPattern`, `restoreDashPattern` |
| Transform | `concatTransformationMatrix`, `translate`, `scale`, `rotateDegrees`, `rotateRadians`, `skewDegrees`, `skewRadians` |
| Path | `moveTo`, `lineTo`, `appendBezierCurve`, `appendQuadraticCurve`, `rectangle`, `square`, `closePath` |
| Paint | `stroke`, `fill`, `fillAndStroke`, `endPath`, `clip`, `clipEvenOdd` |
| Text | `beginText`, `endText`, `setFontAndSize`, `showText`, `moveText`, `nextLine`, `setCharacterSpacing`, `setWordSpacing`, `setCharacterSqueeze`, `setLineHeight`, `setTextRise`, `setTextRenderingMode`, `setTextMatrix`, `rotateAndSkewTextDegreesAndTranslate`, `rotateAndSkewTextRadiansAndTranslate` |
| Color | `setFillingColor`, `setStrokingColor`, and the gray, RGB and CMYK forms, like `setFillingGrayscaleColor` and `setStrokingCmykColor` |
| Other | `drawObject`, `beginMarkedContent`, `endMarkedContent` |

`LineJoinStyle` has `miter`, `round` and `bevel`. `TextRenderingMode` has `fill`, `outline`, `fillAndOutline`, `invisible`, `fillAndClip`, `outlineAndClip`, `fillAndOutlineAndClip` and `clip`. To make your own operator, use `PDFOperator(name, args)`.

## Filling a form

`getForm` gives the form of the document. Get a field by its full name, then set its value:

```dart
PDFDocument doc =
    await PDFDocument.load(File('form.pdf').readAsBytesSync());
PDFForm form = doc.getForm();
form.getTextField('person.name').setText('Jane Doe');
form.getCheckBox('agree').check();
form.getRadioGroup('color').select('green');
form.getDropdown('country').select('Myanmar');
File('filled.pdf').writeAsBytesSync(await doc.save());
```

`getForm` removes XFA data. `save` draws the changed fields again.

### Finding fields

```dart
List<PDFField> fields = form.getFields();
PDFField field = form.getField('person.name');
PDFField? maybe = form.getFieldMaybe('person.age');
```

The typed getters are `getTextField`, `getCheckBox`, `getRadioGroup`, `getDropdown`, `getOptionList`, `getButton` and `getSignature`. A missing name throws `NoSuchFieldError`, and a field of another type throws `UnexpectedFieldTypeError`.

### Field flags

Every field has these methods:

| Method | What it does |
| --- | --- |
| `getName()` | The full name, like `page1.address.city`. |
| `isReadOnly()`, `enableReadOnly()`, `disableReadOnly()` | Read-only flag. |
| `isRequired()`, `enableRequired()`, `disableRequired()` | Required flag. |
| `isExported()`, `enableExporting()`, `disableExporting()` | Export flag. |
| `needsAppearancesUpdate()` | True when the field must be drawn again. |
| `defaultUpdateAppearances(font)` | Draws the field again with a font. |

### Text fields

```dart
PDFTextField name = form.getTextField('name');
name.setText('Jane');
name.setAlignment(TextAlignment.center);
name.setMaxLength(40);
name.setFontSize(12);
```

| Method | What it does |
| --- | --- |
| `getText()`, `setText(text)` | The text. Null or an empty string removes it. |
| `getAlignment()`, `setAlignment(a)` | `TextAlignment.left`, `center` or `right`. |
| `getMaxLength()`, `setMaxLength(n)`, `removeMaxLength()` | A longer text throws `ExceededMaxLengthError`. |
| `setImage(image)` | Shows a `PDFImage` in the field. |
| `setFontSize(size)` | The font size. |
| `updateAppearances(font)` | Draws the field again with a font. |
| `isMultiline()`, `enableMultiline()`, `disableMultiline()` | Many lines. |
| `isPassword()`, `enablePassword()`, `disablePassword()` | Hidden text. |
| `isFileSelector()`, `enableFileSelection()`, `disableFileSelection()` | A file path. |
| `isSpellChecked()`, `enableSpellChecking()`, `disableSpellChecking()` | Spell check. |
| `isScrollable()`, `enableScrolling()`, `disableScrolling()` | Scrolling. |
| `isCombed()`, `enableCombing()`, `disableCombing()` | One cell for each letter. Needs a max length. |
| `isRichFormatted()`, `enableRichFormatting()`, `disableRichFormatting()` | Rich text flag. |

### Check boxes

```dart
PDFCheckBox agree = form.getCheckBox('agree');
agree.check();
agree.uncheck();
bool on = agree.isChecked();
```

### Radio groups

```dart
PDFRadioGroup color = form.getRadioGroup('color');
List<String> options = color.getOptions();
color.select('green');
String? picked = color.getSelected();
color.clear();
```

Also: `isOffToggleable`, `enableOffToggling`, `disableOffToggling`, `isMutuallyExclusive`, `enableMutualExclusion` and `disableMutualExclusion`.

### Dropdowns and option lists

A `PDFDropdown` and a `PDFOptionList` have the same methods. `select` takes one option or a list. With `merge` true, the old selection stays:

```dart
PDFOptionList country = form.getOptionList('country');
country.setOptions(<String>['Myanmar', 'Thailand']);
country.addOptions('Laos');
country.enableMultiselect();
country.select(<String>['Myanmar', 'Laos'], true);
List<String> picked = country.getSelected();
```

A list of many options on a field with no multiselect throws `MultiSelectValueError`.

| Method | What it does |
| --- | --- |
| `getOptions()`, `setOptions(list)`, `addOptions(o)` | The options. |
| `getSelected()`, `select(o, merge)`, `clear()` | The selection. |
| `setFontSize(size)`, `updateAppearances(font)` | The look. |
| `isSorted()`, `enableSorting()`, `disableSorting()` | Sorted options. |
| `isMultiselect()`, `enableMultiselect()`, `disableMultiselect()` | Many selected options. |
| `isSelectOnClick()`, `enableSelectOnClick()`, `disableSelectOnClick()` | Save the value on click. |

A dropdown also has `isEditable`, `enableEditing`, `disableEditing`, `isSpellChecked`, `enableSpellChecking` and `disableSpellChecking`.

### Buttons and signatures

A button can show an image. A signature field can only be read, flagged and removed:

```dart
PDFButton logo = form.getButton('logo');
logo.setImage(png, ImageAlignment.left);
logo.setFontSize(10);

PDFSignature sign = form.getSignature('signature');
```

### Flattening a form

`flatten` draws every field on its page and removes the fields:

```dart
form.flatten();
```

### Removing a field

```dart
form.removeField(form.getField('notes'));
```

### Drawing fields with your font

Fields use Helvetica by default (`getDefaultFont`). For other letters, draw the fields again with your font:

```dart
form.updateFieldAppearances(font);
```

### Marking fields as changed

`save` draws the changed fields again. Mark a field by its `ref`:

```dart
form.markFieldAsDirty(field.ref);
form.markFieldAsClean(field.ref);
bool dirty = form.fieldIsDirty(field.ref);
```

### XFA data

```dart
if (form.hasXFA()) {
  form.deleteXFA();
}
```

### Widgets of a field

Each field has widgets, the boxes on the pages. Read them through `acroField`:

```dart
for (PDFWidgetAnnotation w in field.acroField.getWidgets()) {
  PDFBox box = w.getRectangle();
  PDFPage? page = doc.findPageForAnnotationRef(w.ref);
}
```

A widget also has `P()` (the page ref), `getFlags()`, `getOnValue()` and `getAppearanceState()`. `acroField.getFullyQualifiedName()` gives the full name.

## Creating a form

Create a field by name, then add it to a page. A name can have parents, like `a.b.name`:

```dart
PDFForm form = doc.getForm();
PDFTextField name = form.createTextField('name');
name.setText('Jane');
name.addToPage(page, x: 50, y: 700, width: 200, height: 24);

PDFCheckBox agree = form.createCheckBox('agree');
agree.addToPage(page, x: 50, y: 650, width: 16, height: 16);
```

The create methods are `createTextField`, `createCheckBox`, `createRadioGroup`, `createDropdown`, `createOptionList` and `createButton`. A name that is already used throws `FieldAlreadyExistsError`.

### Adding widgets to a page

`addToPage` takes `x`, `y`, `width`, `height`, `textColor`, `backgroundColor`, `borderColor`, `borderWidth`, `rotate` and `hidden`. Text fields, dropdowns, option lists and buttons also take `font`. A radio group adds one button for each option, and a button takes its caption first:

```dart
PDFRadioGroup size = form.createRadioGroup('size');
size.addOptionToPage('small', page, x: 50, y: 600);
size.addOptionToPage('large', page, x: 110, y: 600);

form.createButton('send').addToPage('Send', page, x: 50, y: 500);
```

| Field | Default size |
| --- | --- |
| Text field, dropdown | 200 by 50 |
| Option list | 200 by 100 |
| Check box, radio button | 50 by 50 |
| Button | 100 by 50, gray, no border |

## Attaching files

`attach` adds a file to the document. It takes bytes, a base64 string or a data URI:

```dart
await doc.attach(
  File('data.csv').readAsBytesSync(),
  'data.csv',
  mimeType: 'text/csv',
  description: 'The raw data',
);
```

It also takes `creationDate`, `modificationDate` and `afRelationship`.

### Reading attachments

```dart
for (PDFAttachment file in doc.getAttachments()) {
  print('${file.name}: ${file.data.length} bytes');
}
```

An attachment also has `mimeType`, `description`, `creationDate`, `modificationDate` and `afRelationship`.

## Metadata

```dart
doc.setTitle('Invoice 42', showInWindowTitleBar: true);
doc.setAuthor('Jane Doe');
doc.setKeywords(<String>['invoice', 'paid']);
doc.setLanguage('en-US');
doc.setCreationDate(DateTime.now());
print(doc.getTitle());
```

| Value | Set | Get |
| --- | --- | --- |
| Title | `setTitle` | `getTitle` |
| Author | `setAuthor` | `getAuthor` |
| Subject | `setSubject` | `getSubject` |
| Keywords | `setKeywords` | `getKeywords` (one string) |
| Creator | `setCreator` | `getCreator` |
| Producer | `setProducer` | `getProducer` |
| Language | `setLanguage` | `getLanguage` |
| Creation date | `setCreationDate` | `getCreationDate` |
| Modification date | `setModificationDate` | `getModificationDate` |
| Trapped | `setTrapped(Trapped.yes)` | `getTrapped` |

`Trapped` has `yes`, `no` and `unknown`. `setTrapped(null)` removes the value.

### Custom metadata

Add your own keys to the document info. A standard key, like `Title`, throws an `ArgumentError`:

```dart
doc.setCustomMetadata('Client', 'Acme');
String? client = doc.getCustomMetadata('Client');
List<String> keys = doc.getCustomMetadataKeys();
doc.removeCustomMetadata('Client');
```

## PDF/A and PDF/X

**PDF/A** is for long-term archives, and **PDF/X** is for print. `setConformance` sets up a document for the standard you pick. You give the ICC profile:

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
```

`setConformance` also takes `outputCondition`, `registryName` and `info`. A bad profile, or one that does not fit the standard, throws a `PDFLibError`. After `load`, call `setConformance` again before you save.

| Standard | For | Transparency | Colors | Attachments |
| --- | --- | --- | --- | --- |
| `pdfX1a` | print | no | CMYK, gray and spot only | no |
| `pdfX3` | print | no | must match the profile | no |
| `pdfX4` | print | yes | must match the profile | no |
| `pdfA1b` | archive | no | must match the profile | no |
| `pdfA2b`, `pdfA2u` | archive | yes | must match the profile | PDF/A files only |
| `pdfA3b`, `pdfA3u` | archive | yes | must match the profile | any file, with `afRelationship` |

The "u" levels also need Unicode text, which fonts from a font file have. RGB colors need an RGB profile, and CMYK colors need a CMYK profile. `label` gives the name, like `PDF/X-4`, and `isPDFX` is true for the print standards.

### Printing with PDF/X

PDF/X needs a title and a trim box on each page. For PDF/X-1a, give a CMYK color to every draw call:

```dart
doc.setTitle('Flyer');
doc.setConformance(
  PDFStandard.pdfX1a,
  iccProfile: coated,
  outputConditionIdentifier: 'FOGRA39',
  registryName: 'http://www.color.org',
);
PDFPage page = doc.addPage(<double>[612, 792]);
page.setTrimBox(9, 9, 594, 774);
page.drawText('Printed in CMYK', x: 50, y: 700, font: font,
    color: cmyk(0, 0, 0, 1));
```

### Attaching files to PDF/A-3

Give a relationship and a MIME type:

```dart
await doc.attach(
  File('invoice.xml').readAsBytesSync(),
  'invoice.xml',
  mimeType: 'text/xml',
  afRelationship: AFRelationship.data,
);
```

`AFRelationship` has `source`, `data`, `alternative`, `supplement`, `encryptedPayload`, `formData`, `schema` and `unspecified`.

### Checking a document

`checkConformance` lists what is still wrong, with the page and a message. It is not a full validator:

```dart
for (ConformanceIssue issue in doc.checkConformance(PDFStandard.pdfA2b)) {
  print('${issue.kind.name}: $issue');
}
```

An issue has `kind`, `pageIndex` (null for the whole document) and `message`. The kinds of `ConformanceIssueKind` are `fontNotEmbedded`, `fontNoUnicode`, `transparency`, `color`, `pageBox`, `encryption`, `embeddedFile`, `action`, `fileId`, `metadata`, `version`, `outputIntent`, `info`, `annotation` and `other`.

### Your own XMP metadata

Save makes the XMP again from the document info, so extra XMP fields of a loaded file are lost. To keep them, start from `createXmpMetadata`, add your fields, and set the result:

```dart
String xmp = doc.createXmpMetadata(standard: PDFStandard.pdfA2b);
doc.setXmpMetadata(addMyFields(xmp));
String? current = doc.getXmpMetadata();
```

### Adding an output intent

`addOutputIntent` adds only the output intent, with none of the other steps of `setConformance`:

```dart
doc.addOutputIntent(
  subtype: OutputIntentSubtype.pdfX,
  iccProfile: coated,
  outputConditionIdentifier: 'FOGRA39',
);
```

## Errors

All errors of the package extend `PDFLibError`, which has a `message`. Wrong arguments throw an `ArgumentError` or a `RangeError`.

| Error | When |
| --- | --- |
| `PDFParsingError` | The file is not a PDF that can be read. |
| `EncryptedPDFError` | `load` got an encrypted file. |
| `RemovePageFromEmptyDocumentError` | `removePage` on a document with no pages. |
| `ForeignPageError` | `addPage` or `insertPage` got a page of another document. |
| `InvalidPDFDateStringError` | A date in the file is not valid. |
| `MissingPageContentsEmbeddingError` | An embedded page has no content. |
| `PageEmbeddingMismatchedContextError` | `embedPages` got pages of two documents. |
| `NoSuchFieldError`, `UnexpectedFieldTypeError` | A field name is missing, or the field is of another type. |
| `FieldAlreadyExistsError`, `InvalidFieldNamePartError` | A new field name is used or not valid. |
| `ExceededMaxLengthError`, `InvalidMaxLengthError` | A text or max length does not fit. |
| `RichTextFieldReadError`, `CombedTextLayoutError` | A rich text or combed field can not be read or drawn. |
| `MissingDAEntryError`, `MissingTfOperatorError` | A field has no font setting. |
| `InvalidAcroFieldValueError`, `MultiSelectValueError` | A field value is not valid. |

## Without Dox

The same code works in any Dart program. Write the bytes to a file:

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

## Next steps

- [pdfme](pdfme.md): fill pdfme templates.
- [Response](../the-basic/response.md): send files from a controller.
- [`dox_pdf_lib` on pub.dev](https://pub.dev/packages/dox_pdf_lib): the package.
- [Source on GitHub](https://github.com/dartondox/dox-pdf-lib): the code of the package.
