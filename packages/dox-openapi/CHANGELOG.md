## Unreleased

- Needs Dart 3.13 or newer.
- All dependencies updated to their latest versions.
- `DoxRouteAdapter` reads `preMiddleware` and `body` from a route when it has them.
- A Dox catch-all param `{path*}` becomes `{path}` in the document.
- New `OpenApiRegistry`, `OpenApiOperation` and `OpenApiRouteBinding`: the docs that `dox_builder` finds in the code. `OpenApiRegistry.find()` matches them to a live route.
- `RouteDoc` and `ApiDoc.route()` take `deprecated`.
- `OpenApiServer` builds and encodes the document once, on the first call, and keeps it. Make a new `OpenApiServer` after you change the `OpenApi`.
- `OpenApi.yamlEmitter` is now a public field.
- `/docs` uses Scalar (`@scalar/api-reference` 1.75.1) by default. `OpenApiServer(ui: DocsUi.swagger)` gives Swagger UI. `ScalarOptions` sets the theme, dark mode, download button and proxy (off by default). The title and the config are escaped.
- Swagger UI updated to 5.34.0.

## 3.0.0-alpha.1

- First release.
- Build an OpenAPI 3.1 document with `OpenApi` and `ApiDoc`.
- Add undocumented Dox routes with `DoxRouteAdapter`.
- Output as JSON and YAML, write files, serve `/openapi.json`, `/openapi.yaml` and `/docs`.
