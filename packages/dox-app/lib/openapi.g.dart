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
      argumentTypes: <String>['ListBlogs'],
      summary: 'List blogs',
      description: 'One page of blogs, oldest first.',
      tags: <String>['Blog'],
      schema: <String, dynamic>{'\$ref': '#/components/schemas/ListBlogs'},
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
      argumentTypes: <String>['SaveBlog'],
      summary: 'Create a blog',
      tags: <String>['Blog'],
      schema: <String, dynamic>{'\$ref': '#/components/schemas/SaveBlog'},
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
      argumentTypes: <String>['int'],
      summary: 'Get one blog',
      tags: <String>['Blog'],
      params: <Map<String, dynamic>>[
        <String, dynamic>{'type': 'integer'},
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
      argumentTypes: <String>['int', 'SaveBlog'],
      summary: 'Update a blog',
      tags: <String>['Blog'],
      params: <Map<String, dynamic>>[
        <String, dynamic>{'type': 'integer'},
      ],
      schema: <String, dynamic>{'\$ref': '#/components/schemas/SaveBlog'},
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
      argumentTypes: <String>['int'],
      summary: 'Delete a blog',
      tags: <String>['Blog'],
      params: <Map<String, dynamic>>[
        <String, dynamic>{'type': 'integer'},
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
      argumentTypes: <String>['LoginUser'],
      summary: 'Log in',
      description: 'Gives a bearer token for the `Authorization` header.',
      tags: <String>['Auth'],
      schema: <String, dynamic>{'\$ref': '#/components/schemas/LoginUser'},
      responses: <int, ResponseDoc>{
        200: ResponseDoc(description: 'Successful response'),
      },
    ),
    OpenApiOperation(
      controller: 'AuthController',
      method: 'register',
      argumentTypes: <String>['RegisterUser'],
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
      argumentTypes: <String>['DoxRequest'],
      ignore: true,
    ),
  ],
  routes: <OpenApiRouteBinding>[
    OpenApiRouteBinding('GET', 'api/ping', 'ApiController.pong'),
    OpenApiRouteBinding('GET', 'api/blogs', 'BlogController.index'),
    OpenApiRouteBinding('POST', 'api/blogs', 'BlogController.store'),
    OpenApiRouteBinding('GET', 'api/blogs/{id}', 'BlogController.show'),
    OpenApiRouteBinding('PUT', 'api/blogs/{id}', 'BlogController.update'),
    OpenApiRouteBinding('PATCH', 'api/blogs/{id}', 'BlogController.update'),
    OpenApiRouteBinding('DELETE', 'api/blogs/{id}', 'BlogController.destroy'),
    OpenApiRouteBinding('POST', 'api/auth/login', 'AuthController.login'),
    OpenApiRouteBinding('POST', 'api/auth/register', 'AuthController.register'),
    OpenApiRouteBinding('GET', 'api/auth/user', 'AuthController.user'),
    OpenApiRouteBinding('GET', '/redis', 'WebController.testRedis'),
  ],
  schemas: <String, Map<String, dynamic>>{
    'ListBlogs': <String, dynamic>{
      'type': 'object',
      'title': 'ListBlogs',
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
        'with_trashed': <String, dynamic>{
          'type': 'boolean',
          'description': 'Also list deleted blogs.',
          'default': false,
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
    'SaveBlog': <String, dynamic>{
      'type': 'object',
      'title': 'SaveBlog',
      'properties': <String, dynamic>{
        'title': <String, dynamic>{'type': 'string', 'maxLength': 255},
        'description': <String, dynamic>{'type': 'string'},
      },
      'required': <dynamic>['title', 'description'],
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
      'title': 'LoginUser',
      'properties': <String, dynamic>{
        'email': <String, dynamic>{'type': 'string', 'format': 'email'},
        'password': <String, dynamic>{'type': 'string'},
      },
      'required': <dynamic>['email', 'password'],
    },
    'RegisterUser': <String, dynamic>{
      'type': 'object',
      'title': 'RegisterUser',
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
