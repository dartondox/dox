<div align="center">
<img src="https://raw.githubusercontent.com/dartondox/assets/main/dox-logo.png" width="70" />
</br></br>

![CodeRabbit Pull Request Reviews](https://img.shields.io/coderabbit/prs/github/dartondox/dox?utm_source=oss&utm_medium=github&utm_campaign=dartondox%2Fdox&labelColor=171717&color=FF570A&link=https%3A%2F%2Fcoderabbit.ai&label=CodeRabbit+Reviews)

<div style="display:inliine-block">
<img src="https://img.shields.io/badge/Dart-0175C2?style=for-the-badge&logo=dart&logoColor=white" height="20"/> <img src="https://github.com/dartondox/dox/actions/workflows/test.yaml/badge.svg?branch=v1.x" height="20"/> <img src="https://img.shields.io/github/stars/dartondox/dox.svg" height="20"/> <img src="https://img.shields.io/github/forks/dartondox/dox.svg" height="20"/> <img src="https://img.shields.io/github/license/dartondox/dox.svg" height="20"/>
</div>

**Write in Dart. Serve with Rust.**
</div>

## About Dox

Dox is a powerful framework specifically developed for web application backend development with Dart. It provides a comprehensive set of tools and features to streamline the development process.

## Features

- **MultiThread HTTP Server**: Dox support multi-threaded HTTP server using isolates that can handle 10x concurrency requests with high speed.
- **Modular Architecture**: Dox follows a modular architecture, making it easy to extend and customize functionalities based on project requirements.
- **Scalability**: The framework is designed to handle high traffic and scale effortlessly as your web application grows.
- **Developer-Friendly**: With its intuitive APIs and clear documentation, Dox makes it easier for developers to create and maintain web applications.
- **Simple, fast routing**: Dox offers a simple and efficient routing system, allowing developers to define and handle routes easily for building robust web applications. 
- **Fast**: Request bodies are streamed, the server uses all CPU cores, and the router is fast.
- **ORM and Query Builder** (`dox_orm`): Models, relations and a query builder for PostgreSQL, MySQL, MariaDB and SQLite. MySQL uses a real connection pool.
- **Validation of Request Data**: Dox includes built-in validation capabilities, allowing developers to validate incoming request data easily and ensure data integrity.
- **Database Migration**: The framework offers database migration support, allowing developers to manage and apply database schema changes seamlessly.
- **Real time**: a Socket.IO server that works with the official Socket.IO clients.
- **Socket.IO** (`dox_socketio`): A Socket.IO v4 server, with a Redis adapter.
- **Cache** (`dox_cache`): Memory, file and Redis drivers, with locks and tags.
- **Storage** (`dox_storage`): One API for local disk, AWS S3 and S3-compatible services.
- **Schema validation** (`dox_validation`): Zod-like schemas with typed results.
- **OpenAPI** (`dox_openapi`): OpenAPI 3.1 docs as JSON and YAML, with a docs page.
- **CORS**: Dox includes Cross-Origin Resource Sharing (CORS) support, allowing developers to control and manage cross-origin requests for enhanced security.
- **CLI (Command-Line Interface)**: Dox provides a command-line interface with useful commands to streamline development tasks, such as creating migrations, generating models, and more.

## Repos

This repo holds `dox_core`, `dox_auth`, `dox_cli` and the other core packages.
Some packages live in their own repos:

| Package | Repo |
| --- | --- |
| `dox_orm`, `dox_migration`, `dox_query_builder` | [dartondox/dox-orm](https://github.com/dartondox/dox-orm) |
| `dox_socketio` | [dartondox/dox-socketio](https://github.com/dartondox/dox-socketio) |
| `dox_storage` | [dartondox/dox-storage](https://github.com/dartondox/dox-storage) |
| `dox_queue` | [dartondox/dox-queue](https://github.com/dartondox/dox-queue) |
| `dox_scheduler` | [dartondox/dox-scheduler](https://github.com/dartondox/dox-scheduler) |
| `dox_inertia` | [dartondox/dox-inertia](https://github.com/dartondox/dox-inertia) |
| `dox_http_native` | [dartondox/dox-http-native](https://github.com/dartondox/dox-http-native) |
| `dox_postgres_native` | [dartondox/dox-postgres-native](https://github.com/dartondox/dox-postgres-native) |
| `dox_mysql_native` | [dartondox/dox-mysql-native](https://github.com/dartondox/dox-mysql-native) |

## Documentation

For detailed information about the framework and its functionalities, refer to the [Dox Documentation](https://dartondox.dev).

## Security Vulnerabilities

Dox take the security of our framework seriously. If you identify any security vulnerabilities in our application, please notify us immediately by sending an email to support@dartondox.dev. We appreciate your responsible disclosure and will respond promptly to address and resolve any identified security issues. Your cooperation helps us maintain the integrity and safety of our software for all users.

## Contributing

We welcome contributions from the community! If you'd like to contribute to the Dox framework, please fork the repo and PR to us. Please visit [contribution guide](/docs/community/contribute.md) for more information.

## License

This project is licensed under the [MIT License](LICENSE).
