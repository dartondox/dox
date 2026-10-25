## 3.0.0-alpha.14

- Version bump only, to match the other packages.

## 3.0.0-alpha.13

- Version bump only, to match the other packages.

## 3.0.0-alpha.12

- Version bump only, to match the other packages.

## 3.0.0-alpha.11

- Version bump only, to match the other packages.

## 3.0.0-alpha.10

- Version bump only, to match the other packages.

## 3.0.0-alpha.9

- Version bump only, to match the other packages.

## 3.0.0-alpha.8

- Fix: `FileTypes.sniff` read any data that starts with `BM` as `bmp`, like the text "BMW...". Now it also checks the BMP header size at byte 14 (12, 40, 52, 56, 64, 108 or 124).

## 3.0.0-alpha.7

- Perf: object, list, map and union schemas work out `isAsync` once and keep the answer. Before, the whole schema tree was walked on every `validateSchema` call.
- `url()` now allows only `http` and `https` links. Pass `schemes` to allow others.
- File type checks now also need the file name extension to fit the bytes. A `.html` file with GIF bytes no longer passes `@Image`. Only another known type (like `.png` with GIF bytes) or a type the browser runs (`html`, `htm`, `xhtml`, `svg`, `xml`, `js`, `mjs`) is refused. A file with no or an unknown extension (like a canvas upload named `blob`) passes when the bytes match.

## 3.0.0-alpha.6

- Version bump only, to match the other packages.

## 3.0.0-alpha.5

- Version bump only, to match the other packages.

## 3.0.0-alpha.4

- Version bump only, to match the other packages.

## 3.0.0-alpha.3

- Version bump only, to match the other packages.

## 3.0.0-alpha.2

- A JSON body that is not an object now says `The request body must be a JSON object.` (key `_root`). Change it with the message key `_root.object`.
- Needs Dart 3.13 or newer.
- All dependencies updated to their latest versions.
- New: DTOs. A class with `@Dto()` and rule annotations (`@Length`, `@Email`, `@Min`, `@Regex`, `@MaxSize`, ...). `dox_builder` writes a `const DtoSchema<T>` with the checks, a converter and the JSON Schema. See the Validation guide.
- New: `DtoSchema<T>` with `validateMap`, `safeValidateMap`, `fromMap`, `toMap` and `toJsonSchema`. It is also a `Schema<T>`.
- New: `Maybe<T>` knows a missing key from `null`. `DtoErrors` for checks across fields in `validate()`.
- New: `FileTypes` finds the real type of a file from its first bytes. `@Image()` and `v.file().image()` do not allow `svg`.
- New: `MessageRequest.locale`, `ParseState.params`. A message set on a rule is used as it is; the resolver only fills its placeholders.
- `Rule` has a `const` constructor and a `final` `message`, so a rule class works as an annotation. `AsyncRule.failedItems()` checks a list in one call.
- `FileInput` has `length` and `head` (the first bytes).
- `Schema` has a `const` constructor. The fluent schemas extend `BaseSchema`.
- Text length messages say "characters".
- Breaking: removed `v.fromRules()`, `v.registerRule()`, `RuleRegistry`, `RuleDefinition`, `CallbackRule` and all rule strings. Use a DTO, or a `Rule<T>` class.


## 3.0.0-alpha.1

- First release of `dox_validation`.
- Fluent schema builder: string, int, num, bool, date, enum, literal, list, object, map, union, any, file.
- `optional`, `nullable`, `nullish`, `defaultTo`, `transform`, `refine`, `superRefine`, async refinements.
- Coercion with `v.coerce` for query strings and form data.
- `parse`, `safeParse`, `parseAsync`, `safeParseAsync` with issue paths.
- Standard Schema interface (`StandardSchema`).
- JSON Schema (draft 2020-12 / OpenAPI 3.1) export with `toJsonSchema()`.
- Custom `Rule` classes and a global `MessageResolver`.
- Laravel style string rules with `v.fromRules()`.
