---
icon: lucide/file-text
---

# pdfme

Make PDF files from [pdfme](https://pdfme.com) templates in Dart with `dox_pdf_me`, and send them from a Dox controller.

You design the template in the pdfme designer, then fill it with data on the server. The package reads the same template JSON as pdfme, and the PDF looks the same. It is built on [PDF Library](pdf-lib.md).

## Setup

```bash
dart pub add dox_pdf_me
```

It uses the native library of `dox_pdf_lib`, so it runs in Dart programs on macOS, Linux and Windows, not on the web, iOS or Android. On Linux, the ready-built library needs glibc 2.35 or newer. For older Linux or Alpine, see [PDF Library setup](pdf-lib.md#setup).

## Filling a template

Read the template JSON with `Template.fromJson`, and give one map of inputs for each copy of the template. Return a `DownloadableFile`, or a `StreamFile` to show the PDF in the browser tab. See [Response](../the-basic/response.md):

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

## Generating a PDF

`generate` takes a template, the inputs, the options and the plugins, and gives the bytes of the file:

```dart
Uint8List pdf = await generate(
  template: template,
  inputs: inputs,
  options: GenerateOptions(lang: 'en', title: 'Invoice'),
  plugins: builtInPlugins,
);
```

With no plugins, only `text` schemas work. Pass `builtInPlugins` for all field types.

### Inputs

Each input map makes one copy of the template. The keys are the schema names, and every value is a string:

| Schema type | Input value |
| --- | --- |
| text, select, date, time | The text, like `'Jane'` or `'2026-11-23'`. |
| table | A JSON string of rows, from `jsonEncode(rows)`. |
| multiVariableText | A JSON string of values, like `'{"name": "Ann"}'`. |
| checkbox, radioGroup, circleMark | `'true'` to turn it on. |
| image, signature | A PNG or JPEG data URL or base64. |
| svg | The SVG text. |
| barcodes | The data of the code. |

A schema with `required: true` and no value makes `generate` throw.

### Options

| Option | What it sets |
| --- | --- |
| `font` | The fonts, by name. See [Using other fonts](#using-other-fonts). |
| `colorType` | `ColorType.rgb` (default) or `ColorType.cmyk`. |
| `lang` | The PDF language and the default date locale, like `en`. |
| `title`, `author`, `subject`, `keywords`, `creator`, `producer` | The PDF metadata. |
| `creationDate`, `modificationDate` | The PDF dates. |

Read the pdfme options JSON with `GenerateOptions.fromJson`:

```dart
GenerateOptions options =
    GenerateOptions.fromJson(<String, Object?>{'lang': 'en'});
```

## Building a template

A `Template` has a base PDF and a list of schemas for each page. Sizes and positions are in millimetres, from the top left corner:

```dart
Template template = Template(
  basePdf: const BlankPdf(),
  schemas: <List<Schema>>[
    <Schema>[
      const TextSchema(
        name: 'title',
        position: Position(20, 20),
        width: 170,
        height: 15,
        fontSize: 24,
      ),
    ],
  ],
);
```

### Reading and writing JSON

`Template.fromJson` reads both pdfme formats. Each schema becomes its typed class, and a type with no plugin becomes an `UnknownSchema`. `toJson` gives the JSON back, with the keys this package does not know:

```dart
Template template = Template.fromJson(json);
Map<String, Object?> back = template.toJson();
```

Every schema, `Position` and `Sides` also has `fromJson` and `toJson`.

### Blank pages

`BlankPdf` makes blank pages. The default is A4, 210 by 297 mm, with a padding of 10 mm:

```dart
const BlankPdf(width: 148, height: 210, padding: Sides.all(5));
```

### Static schemas

Static schemas are drawn on every page of a blank base PDF, like a header. Read-only text can use `{currentPage}` and `{totalPages}`:

```dart
BlankPdf(
  staticSchema: <Schema>[
    const TextSchema(
      name: 'footer',
      position: Position(10, 285),
      readOnly: true,
      content: '{currentPage}/{totalPages}',
    ),
  ],
);
```

Read-only text also takes input names and dotted paths, like `{order.id}`, and `{date}` and `{dateTime}`.

### A PDF file as the base

With `PdfFile`, each page of the file is one page of the template. The schemas are drawn on top:

```dart
Template template = Template(
  basePdf: PdfFile(File('form.pdf').readAsBytesSync()),
  schemas: schemas,
);
```

## Common schema options

Every schema has these options:

| Option | What it is |
| --- | --- |
| `name` | The input key. |
| `position` | The top left corner, like `Position(20, 40)`. |
| `width`, `height` | The size in mm. |
| `rotate` | Degrees, clockwise. |
| `opacity` | 0 (clear) to 1 (solid). |
| `readOnly` | Shows `content` and takes no input. |
| `required` | `generate` throws when the input has no value. |
| `content` | The value of a read-only schema. |

Colors are hex strings, like `#ff0000`, `#f00` or `#ff000080` with alpha. An empty string means no color, and a bad hex value makes `generate` throw. `Sides(top: 1, right: 2, bottom: 1, left: 2)` and `Sides.all(1)` give a size for each side of a box.

## Adding text

`TextSchema` draws text in a box. Long text wraps, and Thai, Lao, Khmer and Myanmar text breaks between words:

```dart
const TextSchema(
  name: 'note',
  position: Position(20, 60),
  width: 170,
  height: 30,
  fontSize: 11,
  alignment: Alignment.justify,
  verticalAlignment: VerticalAlignment.middle,
  fontColor: '#333333',
  padding: Sides.all(2),
);
```

| Option | Default |
| --- | --- |
| `fontName` | The fallback font. |
| `fontSize` | 13 points. |
| `alignment` | `Alignment.left`. Also `center`, `right` and `justify`. |
| `verticalAlignment` | `VerticalAlignment.top`. Also `middle` and `bottom`. |
| `lineHeight` | 1, a factor of the font size. |
| `characterSpacing` | 0 points. |
| `fontColor` | `#000000`. |
| `backgroundColor` | none. |
| `borderColor`, `borderWidth` | `#000000`, no width. |
| `padding` | none. |
| `underline`, `strikethrough` | false. |
| `dynamicFontSize` | none. See below. |

`TextSchema` also has `textFormat`, `overflow`, `fontVariants` and `fontVariantFallback`. They are kept in the JSON. Inline markdown is drawn as plain text, and `TextOverflow.expand` is drawn like `visible`.

### Fitting text to the box

`DynamicFontSize` changes the font size between `min` and `max`, so the text fits:

```dart
const TextSchema(
  name: 'title',
  position: Position(20, 20),
  dynamicFontSize: DynamicFontSize(
    min: 8,
    max: 40,
    fit: DynamicFontSizeFit.horizontal,
  ),
);
```

The defaults are 4, 72 and `DynamicFontSizeFit.vertical`.

### Text with variables

`MultiVariableTextSchema` has a text with `{name}` variables. The input is a JSON string with a value for each variable:

```dart
const MultiVariableTextSchema(
  name: 'greeting',
  position: Position(20, 20),
  width: 170,
  height: 10,
  text: 'Hello {name}, welcome to {city}!',
  variables: <String>['name', 'city'],
);
// input: {'greeting': '{"name": "Ann", "city": "Paris"}'}
```

It takes all text options. When a variable is missing, nothing is drawn. For a read-only schema, `content` is a JSON string of values. With `contentSnapshot: true`, `content` is the text to draw.

### Select

`SelectSchema` is a text field with a list of `options`. It takes all text options:

```dart
const SelectSchema(
  name: 'size',
  position: Position(20, 80),
  options: <String>['Small', 'Large'],
);
```

## Adding dates and times

`DateSchema`, `TimeSchema` and `DateTimeSchema` format the input with date-fns tokens:

```dart
const DateSchema(
  name: 'date',
  position: Position(10, 150),
  format: 'MM/dd/yyyy',
);
```

They also take `locale`, `fontName`, `alignment`, `fontSize`, `characterSpacing`, `fontColor` and `backgroundColor`. Month and day names are English for every locale, and weeks start on Sunday.

## Adding images and SVG

### Images

`ImageSchema` draws a PNG or JPEG. `objectFit` is `ObjectFit.contain` (default) or `cover`:

```dart
const ImageSchema(
  name: 'photo',
  position: Position(70, 10),
  objectFit: ObjectFit.cover,
  objectPosition: ObjectPosition.centerTop,
);
```

`ObjectPosition` has `leftTop`, `centerTop`, `rightTop`, `leftCenter`, `centerCenter` (default), `rightCenter`, `leftBottom`, `centerBottom` and `rightBottom`.

### Signatures

`SignatureSchema` is drawn like an image. Its default size is 62.5 by 37.5 mm:

```dart
const SignatureSchema(name: 'sign', position: Position(20, 250));
```

### SVG

`SvgSchema` draws the SVG text of the input:

```dart
const SvgSchema(name: 'logo', position: Position(10, 10));
```

## Drawing shapes

`LineSchema`, `RectangleSchema` and `EllipseSchema` are read-only by default:

```dart
const LineSchema(
  name: 'rule',
  position: Position(10, 40),
  width: 190,
  color: '#cccccc',
);
const RectangleSchema(
  name: 'box',
  position: Position(40, 70),
  color: '#b3e5fc',
  borderColor: '#0288d1',
  borderWidth: 1,
  radius: 5,
);
const EllipseSchema(name: 'dot', position: Position(10, 70));
```

A rectangle and an ellipse take `color`, `borderColor` and `borderWidth`. A rectangle also takes `radius`.

### Circle marks

`CircleMarkSchema` draws a circle line around the box when the input is `'true'`. `borderWidth` is the line width in mm:

```dart
const CircleMarkSchema(
  name: 'yes',
  position: Position(30, 100),
  color: '#ff0000',
  borderWidth: 0.5,
);
```

## Check boxes and radio groups

Both are on when the input is `'true'`. The radio buttons of one `group` work together in the designer:

```dart
const CheckboxSchema(name: 'agree', position: Position(25, 115));
const RadioGroupSchema(
  name: 'small',
  position: Position(25, 125),
  group: 'size',
);
```

Both take `color`.

## Adding barcodes

`BarcodeSchema` draws a barcode or a QR code as vector shapes. Pick the type with `barcodeType`:

```dart
BarcodeSchema(
  name: 'link',
  barcodeType: BarcodeType.qrcode,
  position: const Position(20, 40),
  barColor: '#000000',
);
```

| Option | Default |
| --- | --- |
| `width`, `height` | The size of the type, like 30 by 30 mm for a QR code. |
| `backgroundColor` | `#ffffff`. |
| `barColor`, `textColor` | `#000000`. |
| `includetext` | true. The text under the bars. |

The types of `BarcodeType` are `qrcode`, `japanpost`, `ean13`, `ean8`, `code39`, `code128`, `nw7`, `itf14`, `upca`, `upce`, `gs1datamatrix` and `pdf417`. Each has its default `width` and `height`, and `is2D` is true for QR code, Data Matrix and PDF417. `barcodeTypes` is the list of the type names.

A value that the barcode check refuses, like a bad EAN-13 check digit, draws nothing. A value that passes the check but can not be encoded makes `generate` throw a `BarcodeInputException` with a `message`.

## Adding tables

`TableSchema` draws a table. The input is a JSON string of rows:

```dart
const TableSchema(
  name: 'items',
  position: Position(10, 170),
  head: <String>['Item', 'Qty', 'Price'],
  headWidthPercentages: <double>[50, 20, 30],
  columnStyles: ColumnStyles(
    alignment: <int, Alignment>{1: Alignment.right, 2: Alignment.right},
  ),
);
// input: {'items': jsonEncode([['Pen', '2', '3.00']])}
```

| Option | What it does |
| --- | --- |
| `head` | The head text of each column. |
| `headWidthPercentages` | The width of each column, in percent. By default, each column gets the same width (30, 30, 40 for the default head). |
| `showHead` | Shows the head (true). |
| `repeatHead` | Shows the head again on each new page (false). |
| `tableStyles` | The outer border: `TableStyles(borderColor:, borderWidth:)`. |
| `headStyles`, `bodyStyles` | The cell styles: `CellStyle.head()` and `CellStyle.body()`. |
| `columnStyles` | Styles by column index, from 0. |

On a blank base PDF, a table that is taller than its box goes on over new pages. The schemas below it move down. A row with fewer cells than the head throws.

### Cell styles

`CellStyle.head()` and `CellStyle.body()` take the text options `fontName`, `alignment`, `verticalAlignment`, `fontSize`, `lineHeight`, `characterSpacing`, `fontColor` and `backgroundColor`. They also take `borderColor`, `borderWidth` and `padding`. A body style has `alternateBackgroundColor` for every second row:

```dart
const CellStyle.body(
  fontSize: 10,
  alternateBackgroundColor: '#f5f5f5',
);
```

### Image columns

A column of `TableCellType.image` shows PNG and JPEG data URLs. `ImageHeightMode.fixed` makes the image `imageHeight` mm high, 20 by default. `ImageHeightMode.auto` follows the image ratio:

```dart
const ColumnStyles(
  cellType: <int, TableCellType>{0: TableCellType.image},
  imageHeightMode: <int, ImageHeightMode>{0: ImageHeightMode.fixed},
  imageHeight: <int, double>{0: 15},
);
```

`ColumnStyles` also has `verticalAlignment`.

## Using other fonts

Text uses Roboto by default. For other languages, give your fonts in `GenerateOptions`:

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

Thai, Myanmar, Khmer, Lao, Arabic, Hebrew and Hindi text is laid out correctly. A schema picks a font with `fontName`. Letters that are not in the font show as empty boxes.

### Font options

One font has `fallback: true`, and schemas with no `fontName` use it. `subset` is true by default, so only the used letters go into the file:

```dart
FontSource(noto, fallback: true, subset: false);
```

In the options JSON, the font data can also be a base64 string or a data URI. Font URLs throw an `ArgumentError`.

## Plugins

Each schema type is a plugin. `builtInPlugins` has all types, and `defaultPlugins` has only `text`. Pick only the plugins you need:

```dart
await generate(
  template: template,
  inputs: inputs,
  plugins: <String, SchemaPlugin<Schema>>{
    'Text': const TextPlugin(),
    'QR Code': const BarcodePlugin(BarcodeType.qrcode),
  },
);
```

| Plugin | Schema type |
| --- | --- |
| `TextPlugin`, `MultiVariableTextPlugin`, `SelectPlugin` | `text`, `multiVariableText`, `select` |
| `DatePlugin`, `TimePlugin`, `DateTimePlugin` | `date`, `time`, `dateTime` |
| `ImagePlugin`, `SignaturePlugin`, `SvgPlugin` | `image`, `signature`, `svg` |
| `LinePlugin`, `RectanglePlugin`, `EllipsePlugin`, `CircleMarkPlugin` | `line`, `rectangle`, `ellipse`, `circleMark` |
| `CheckboxPlugin`, `RadioGroupPlugin` | `checkbox`, `radioGroup` |
| `BarcodePlugin(type)` | the barcode types |
| `TablePlugin` | `table` |

`findPlugin(plugins, 'qrcode')` gives the plugin for a type, or null.

### Your own schema type

A schema extends `Schema`, and its `fromJson` constructor calls `Schema.fromJson`. A plugin extends `SchemaPlugin`, reads its schema from JSON and draws it in `pdf`:

```dart
class StampSchema extends Schema {
  const StampSchema({
    required super.name,
    required super.position,
    super.width = 30,
    super.height = 10,
    this.label = 'PAID',
  });

  StampSchema.fromJson(super.json)
    : label = json['label'] is String ? json['label']! as String : 'PAID',
      super.fromJson();

  final String label;

  @override
  String get type => 'stamp';

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    ...super.toJson(),
    'label': label,
  };
}

class StampPlugin extends SchemaPlugin<StampSchema> {
  const StampPlugin();

  @override
  String get type => 'stamp';

  @override
  StampSchema fromJson(Map<String, Object?> json) =>
      StampSchema.fromJson(json);

  @override
  Future<void> pdf(RenderProps<StampSchema> props) async {
    PdfLayout box = PdfLayout.of(props.schema, props.page.getHeight());
    props.page.drawRectangle(
      x: box.x,
      y: box.y,
      width: box.width,
      height: box.height,
      color: rgb(1, 0, 0),
    );
  }
}
```

Give the plugin to `Template.fromJson` and to `generate`:

```dart
Map<String, SchemaPlugin<Schema>> plugins = <String, SchemaPlugin<Schema>>{
  ...builtInPlugins,
  'Stamp': const StampPlugin(),
};
Template template = Template.fromJson(json, plugins: plugins);
await generate(template: template, inputs: inputs, plugins: plugins);
```

The package exports the [PDF Library](pdf-lib.md) API, so you can use all its drawing methods on the page.

### Render props

`RenderProps` has the input `value`, the typed `schema`, the `basePdf`, the `page`, the document `doc`, the `options`, the `fonts` and a `cache`. Draw with a built-in plugin on a changed schema with `withSchema` or `copyWith`:

```dart
await const TextPlugin().pdf(
  props.withSchema(
    TextSchema(
      name: props.schema.name,
      position: props.schema.position,
      fontColor: '#ffffff',
    ),
    value: props.schema.label,
  ),
);
```

### Fonts and cache in a plugin

`fonts.resolve` gives the font name, or the fallback name for null. `fonts.embed` gives the `PDFFont`. The `cache` keeps values for the whole document:

```dart
String name = props.fonts.resolve(null);
PDFFont font = await props.fonts.embed(name);

PDFImage? logo = props.cache.get<PDFImage>('logo');
props.cache.set<PDFImage>('logo', image);
```

`fonts.sources` has all fonts, and `fonts.fallbackName` is the name of the fallback font.

### Layout in a plugin

`PdfLayout.of` turns the box of a schema into PDF points, with the origin at the bottom left. It has `x`, `y`, `width`, `height`, `rotate` and `opacity`. `rotatePoint` turns a `Point` around another one:

```dart
PdfLayout box = PdfLayout.of(props.schema, props.page.getHeight());
Point corner = rotatePoint(
    (x: box.x, y: box.y), (x: 100, y: 100), 90);
```

## Without Dox

The same code works in any Dart program. Write the bytes to a file:

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
          const TextSchema(
              name: 'title',
              position: Position(20, 20),
              width: 170,
              height: 15),
          BarcodeSchema(
              name: 'link',
              barcodeType: BarcodeType.qrcode,
              position: const Position(20, 40)),
        ],
      ],
    ),
    inputs: <Map<String, String>>[
      <String, String>{
        'title': 'Hello, PDF!',
        'link': 'https://dartondox.dev',
      },
    ],
    plugins: builtInPlugins,
  );
  File('hello.pdf').writeAsBytesSync(pdf);
}
```

## Next steps

- [PDF Library](pdf-lib.md): draw and edit PDF files.
- [Response](../the-basic/response.md): send files from a controller.
- [`dox_pdf_me` on pub.dev](https://pub.dev/packages/dox_pdf_me): the package.
- [Source on GitHub](https://github.com/dartondox/dox-pdf-lib): the code of the package.
