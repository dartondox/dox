## Unreleased

- Needs Dart 3.13 or newer.
- All dependencies updated to their latest versions.
- `DoxRouteAdapter` reads `preMiddleware` and `body` from a route when it has them.
- A Dox catch-all param `{path*}` becomes `{path}` in the document.


## 3.0.0-alpha.1

- First release.
- Build an OpenAPI 3.1 document with `OpenApi` and `ApiDoc`.
- Add undocumented Dox routes with `DoxRouteAdapter`.
- Output as JSON and YAML, write files, serve `/openapi.json`, `/openapi.yaml` and `/docs`.
