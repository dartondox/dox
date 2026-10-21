// GENERATED CODE - DO NOT MODIFY BY HAND
// Made by dox_builder. Run `dart run build_runner build`.
// ignore_for_file: type=lint

import 'package:dox_core/dox_core.dart';

/// OpenAPI docs found in the code.
/// Use it in `OpenApiConfig(registry: openApiRegistry)`.
const OpenApiRegistry openApiRegistry = OpenApiRegistry(
  operations: <OpenApiOperation>[
    OpenApiOperation(
      controller: 'ApiController',
      method: 'pong',
      argumentTypes: <String>['DoxRequest'],
      summary: 'Ping',
      tags: <String>['Health'],
      responses: <int, ResponseDoc>{
        200: ResponseDoc(
          description: 'Successful response',
          schema: <String, dynamic>{'type': 'string'},
        ),
      },
    ),
    OpenApiOperation(
      controller: 'BlogController',
      method: 'index',
      argumentTypes: <String>['DoxRequest'],
      summary: 'List blogs',
      description: 'One page of blogs, oldest first.',
      tags: <String>['Blog'],
      schema: <String, dynamic>{'\$ref': '#/components/schemas/ListBlogs'},
      requestIn: 'query',
      responses: <int, ResponseDoc>{
        200: ResponseDoc(
          description: 'Successful response',
          schema: <String, dynamic>{'\$ref': '#/components/schemas/Pagination'},
        ),
      },
    ),
    OpenApiOperation(
      controller: 'BlogController',
      method: 'store',
      argumentTypes: <String>['BlogRequest'],
      summary: 'Create a blog',
      tags: <String>['Blog'],
      formRequest: 'BlogRequest',
      responses: <int, ResponseDoc>{
        200: ResponseDoc(
          description: 'Successful response',
          schema: <String, dynamic>{'\$ref': '#/components/schemas/Blog'},
        ),
      },
    ),
    OpenApiOperation(
      controller: 'BlogController',
      method: 'show',
      argumentTypes: <String>['DoxRequest', 'String'],
      summary: 'Get one blog',
      tags: <String>['Blog'],
      params: <Map<String, dynamic>>[
        <String, dynamic>{'type': 'string'},
      ],
      responses: <int, ResponseDoc>{
        200: ResponseDoc(
          description: 'Successful response',
          schema: <String, dynamic>{'\$ref': '#/components/schemas/Blog'},
        ),
      },
    ),
    OpenApiOperation(
      controller: 'BlogController',
      method: 'update',
      argumentTypes: <String>['BlogRequest', 'String'],
      summary: 'Update a blog',
      tags: <String>['Blog'],
      params: <Map<String, dynamic>>[
        <String, dynamic>{'type': 'string'},
      ],
      formRequest: 'BlogRequest',
      responses: <int, ResponseDoc>{
        200: ResponseDoc(
          description: 'Successful response',
          schema: <String, dynamic>{'\$ref': '#/components/schemas/Blog'},
        ),
      },
    ),
    OpenApiOperation(
      controller: 'BlogController',
      method: 'destroy',
      argumentTypes: <String>['DoxRequest', 'String'],
      summary: 'Delete a blog',
      tags: <String>['Blog'],
      params: <Map<String, dynamic>>[
        <String, dynamic>{'type': 'string'},
      ],
      responses: <int, ResponseDoc>{
        200: ResponseDoc(
          description: 'Successful response',
          schema: <String, dynamic>{
            'type': 'object',
            'additionalProperties': <String, dynamic>{'type': 'string'},
          },
        ),
      },
    ),
    OpenApiOperation(
      controller: 'AuthController',
      method: 'login',
      argumentTypes: <String>['DoxRequest'],
      summary: 'Log in',
      description: 'Gives a bearer token for the `Authorization` header.',
      tags: <String>['Auth'],
      schema: <String, dynamic>{'\$ref': '#/components/schemas/LoginUser'},
      responses: <int, ResponseDoc>{
        200: ResponseDoc(
          description: 'Successful response',
          schema: <String, dynamic>{
            '\$ref': '#/components/schemas/LoginResult',
          },
        ),
      },
    ),
    OpenApiOperation(
      controller: 'AuthController',
      method: 'register',
      argumentTypes: <String>['DoxRequest'],
      summary: 'Make an account',
      tags: <String>['Auth'],
      schema: <String, dynamic>{'\$ref': '#/components/schemas/RegisterUser'},
      responses: <int, ResponseDoc>{
        200: ResponseDoc(
          description: 'Successful response',
          schema: <String, dynamic>{'\$ref': '#/components/schemas/User'},
        ),
      },
    ),
    OpenApiOperation(
      controller: 'AuthController',
      method: 'user',
      argumentTypes: <String>['DoxRequest'],
      summary: 'The logged in user',
      tags: <String>['Auth'],
      responses: <int, ResponseDoc>{
        200: ResponseDoc(
          description: 'Successful response',
          schema: <String, dynamic>{'\$ref': '#/components/schemas/User'},
        ),
      },
    ),
    OpenApiOperation(
      controller: 'WebController',
      method: 'pong',
      argumentTypes: <String>['DoxRequest'],
      tags: <String>['Web'],
      responses: <int, ResponseDoc>{
        200: ResponseDoc(
          description: 'Successful response',
          schema: <String, dynamic>{'type': 'string'},
        ),
      },
    ),
    OpenApiOperation(
      controller: 'WebController',
      method: 'testRedis',
      argumentTypes: <String>[],
      ignore: true,
    ),
  ],
  routes: <OpenApiRouteBinding>[
    OpenApiRouteBinding('GET', 'ping', 'ApiController.pong'),
    OpenApiRouteBinding('GET', 'blogs', 'BlogController.index'),
    OpenApiRouteBinding('POST', 'blogs', 'BlogController.store'),
    OpenApiRouteBinding('GET', 'blogs/{id}', 'BlogController.show'),
    OpenApiRouteBinding('PUT', 'blogs/{id}', 'BlogController.update'),
    OpenApiRouteBinding('PATCH', 'blogs/{id}', 'BlogController.update'),
    OpenApiRouteBinding('DELETE', 'blogs/{id}', 'BlogController.destroy'),
    OpenApiRouteBinding('POST', '/auth/login', 'AuthController.login'),
    OpenApiRouteBinding('POST', '/auth/register', 'AuthController.register'),
    OpenApiRouteBinding('GET', '/auth/user', 'AuthController.user'),
    OpenApiRouteBinding('GET', '/redis', 'WebController.testRedis'),
  ],
  schemas: <String, Map<String, dynamic>>{
    'ListBlogs': <String, dynamic>{
      'type': 'object',
      'properties': <String, dynamic>{
        'page': <String, dynamic>{
          'type': 'integer',
          'minimum': 1,
          'description': 'Page number, from 1.',
          'default': 1,
        },
        'limit': <String, dynamic>{
          'type': 'integer',
          'minimum': 1,
          'maximum': 100,
          'description': 'Blogs per page.',
          'default': 20,
        },
      },
    },
    'Pagination': <String, dynamic>{
      'type': 'object',
      'properties': <String, dynamic>{
        'total': <String, dynamic>{'type': 'integer'},
        'per_page': <String, dynamic>{'type': 'integer'},
        'last_page': <String, dynamic>{'type': 'integer'},
        'current_page': <String, dynamic>{'type': 'integer'},
        'data': <String, dynamic>{
          'type': 'array',
          'items': <String, dynamic>{},
        },
      },
    },
    'Blog': <String, dynamic>{
      'type': 'object',
      'properties': <String, dynamic>{
        'id': <String, dynamic>{'type': 'integer'},
        'user_id': <String, dynamic>{
          'type': <dynamic>['integer', 'null'],
        },
        'title': <String, dynamic>{
          'type': <dynamic>['string', 'null'],
        },
        'slug': <String, dynamic>{
          'type': <dynamic>['string', 'null'],
        },
        'description': <String, dynamic>{
          'type': <dynamic>['string', 'null'],
        },
        'user': <String, dynamic>{
          'anyOf': <dynamic>[
            <String, dynamic>{'\$ref': '#/components/schemas/User'},
            <String, dynamic>{'type': 'null'},
          ],
        },
        'categories': <String, dynamic>{
          'type': 'array',
          'items': <String, dynamic>{'\$ref': '#/components/schemas/Category'},
        },
        'created_at': <String, dynamic>{
          'type': <dynamic>['string', 'null'],
          'format': 'date-time',
        },
        'updated_at': <String, dynamic>{
          'type': <dynamic>['string', 'null'],
          'format': 'date-time',
        },
      },
    },
    'User': <String, dynamic>{
      'type': 'object',
      'properties': <String, dynamic>{
        'id': <String, dynamic>{'type': 'integer'},
        'name': <String, dynamic>{
          'type': <dynamic>['string', 'null'],
        },
        'email': <String, dynamic>{
          'type': <dynamic>['string', 'null'],
        },
        'created_at': <String, dynamic>{
          'type': <dynamic>['string', 'null'],
          'format': 'date-time',
        },
        'updated_at': <String, dynamic>{
          'type': <dynamic>['string', 'null'],
          'format': 'date-time',
        },
      },
    },
    'Category': <String, dynamic>{
      'type': 'object',
      'properties': <String, dynamic>{
        'id': <String, dynamic>{'type': 'integer'},
        'name': <String, dynamic>{
          'type': <dynamic>['string', 'null'],
        },
        'blogs': <String, dynamic>{
          'type': 'array',
          'items': <String, dynamic>{'\$ref': '#/components/schemas/Blog'},
        },
        'created_at': <String, dynamic>{
          'type': <dynamic>['string', 'null'],
          'format': 'date-time',
        },
        'updated_at': <String, dynamic>{
          'type': <dynamic>['string', 'null'],
          'format': 'date-time',
        },
      },
    },
    'LoginUser': <String, dynamic>{
      'type': 'object',
      'properties': <String, dynamic>{
        'email': <String, dynamic>{'type': 'string', 'format': 'email'},
        'password': <String, dynamic>{'type': 'string'},
      },
      'required': <dynamic>['email', 'password'],
    },
    'LoginResult': <String, dynamic>{
      'type': 'object',
      'properties': <String, dynamic>{
        'success': <String, dynamic>{'type': 'boolean'},
        'token': <String, dynamic>{
          'type': 'string',
          'description': 'Bearer token for the `Authorization` header.',
        },
        'user': <String, dynamic>{'\$ref': '#/components/schemas/User'},
      },
      'required': <dynamic>['success', 'token', 'user'],
    },
    'RegisterUser': <String, dynamic>{
      'type': 'object',
      'properties': <String, dynamic>{
        'name': <String, dynamic>{
          'type': 'string',
          'minLength': 2,
          'maxLength': 100,
        },
        'email': <String, dynamic>{'type': 'string', 'format': 'email'},
        'password': <String, dynamic>{'type': 'string', 'minLength': 8},
      },
      'required': <dynamic>['name', 'email', 'password'],
    },
  },
);
