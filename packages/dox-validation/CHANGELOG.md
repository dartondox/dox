# version 3.0.0

- First release of `dox_validation`.
- Fluent schema builder: string, int, num, bool, date, enum, literal, list, object, map, union, any, file.
- `optional`, `nullable`, `nullish`, `defaultTo`, `transform`, `refine`, `superRefine`, async refinements.
- Coercion with `v.coerce` for query strings and form data.
- `parse`, `safeParse`, `parseAsync`, `safeParseAsync` with issue paths.
- Standard Schema interface (`StandardSchema`).
- JSON Schema (draft 2020-12 / OpenAPI 3.1) export with `toJsonSchema()`.
- Custom `Rule` classes and a global `MessageResolver`.
- Laravel style string rules with `v.fromRules()`.
