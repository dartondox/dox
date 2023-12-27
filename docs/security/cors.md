# CORS

CORS, or Cross-Origin Resource Sharing, is a security feature implemented in web browsers to control and regulate requests made between web pages from different origins (domains). It ensures that web applications running at one domain are allowed or restricted from making requests to resources (such as data or services) hosted on a different domain. CORS helps prevent potentially harmful cross-site request forgery (CSRF) and cross-site scripting (XSS) attacks while enabling safe data sharing and interaction between web applications on separate domains when configured appropriately.

CORS configuration can be found in `lib/config/cors.dart`

=== "cors.dart"

    ```dart
    CORSConfig cors = CORSConfig(
        /// Enabled
        /// -------------------------------
        /// A boolean to enable or disable CORS integration.
        /// Setting to true will enable the CORS for all HTTP request.
        enabled: true,

        /// Origin
        /// -------------------------------
        /// Set a list of origins to be allowed for `Access-Control-Allow-Origin`.
        /// The value can be one of the following:
        /// Array       : An array of allowed origins.
        /// String      : Comma separated list of allowed origins.
        /// String (*)  : A wildcard (*) to allow all request origins.
        origin: '*',

        /// Methods
        /// -------------------------------
        /// Set a list of origins to be allowed for `Access-Control-Request-Method`.
        /// The value can be one of the following:
        /// Array       : An array of request methods.
        /// String      : Comma separated list of request methods.
        /// String (*)  : A wildcard (*) to allow all request methods.
        methods: '*',

        /// Headers
        /// -------------------------------
        /// Set a list of origins to be allowed for `Access-Control-Allow-Headers`.
        /// The value can be one of the following:
        /// Array       : An array of allowed headers.
        /// String      : Comma separated list of allowed headers.
        /// String (*)  : A wildcard (*) to allow all request headers.
        headers: '*',

        /// Expose Headers
        /// -------------------------------
        /// Set a list of origins to be allowed for `Access-Control-Expose-Headers`.
        /// The value can be one of the following:
        /// Array       : An array of expose headers.
        /// String      : Comma separated list of expose headers.
        exposeHeaders: <String>[
            'cache-control',
            'content-language',
            'content-type',
            'expires',
            'last-modified',
            'pragma',
        ],

        /// Credentials
        /// -------------------------------
        /// Toggle `Access-Control-Allow-Credentials` header.
        credentials: true,

        /// MaxAge
        /// -------------------------------
        /// Define `Access-Control-Max-Age` header in seconds.
        maxAge: 90,
    );

    ```
