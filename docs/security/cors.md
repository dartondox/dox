# CORS

CORS, or Cross-Origin Resource Sharing, is a security feature implemented in web browsers to control and regulate requests made between web pages from different origins (domains). It ensures that web applications running at one domain are allowed or restricted from making requests to resources (such as data or services) hosted on a different domain. CORS helps prevent potentially harmful cross-site request forgery (CSRF) and cross-site scripting (XSS) attacks while enabling safe data sharing and interaction between web applications on separate domains when configured appropriately.

CORS configuration can be found in `lib/config/app.dart`

=== "app.dart"

    ```dart
    class Config implements AppConfig {
        ...

        @override
        CORSConfig get cors => CORSConfig(
            allowOrigin: '*',
            allowMethods : ['GET', 'POST'],
            allowHeaders : '*'
            exposeHeaders : 'Authorization',
            allowCredentials: true,
            maxAge : Duration(hours: 1).inSeconds
        );

        ...
    }
    ```

## Options

#### `allowOrigin`

The Access-Control-Allow-Origin response header indicates whether the response can be shared with requesting code from the given origin.

#### `allowMethods`

The Access-Control-Allow-Methods response header specifies one or more methods allowed when accessing a resource in response to a preflight request.

#### `allowHeaders`

The Access-Control-Allow-Headers response header is used in response to a preflight request which includes the Access-Control-Request-Headers to indicate which HTTP headers can be used during the actual request.

#### `exposeHeaders`

The Access-Control-Expose-Headers response header allows a server to indicate which response headers should be made available to scripts running in the browser, in response to a cross-origin request.

#### `allowCredentials`

The Access-Control-Allow-Credentials response header tells browsers whether to expose the response to the frontend JavaScript code when the request's credentials mode (Request.credentials) is include.

#### `maxAge`

The Access-Control-Max-Age response header indicates how long the results of a preflight request (that is the information contained in the Access-Control-Allow-Methods and Access-Control-Allow-Headers headers) can be cached.