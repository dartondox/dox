---
icon: material/robot-outline
---

# AI agents

Give your AI coding agent the real Dox API with skills, `AGENTS.md` and the llms files.

Without the real API, an agent guesses class and method names, and the code does not compile. Dox gives two sources:

- **Skills**: short guides that each package ships. The agent reads them while it writes code in your app.
- **llms files**: these docs as plain text, for a chat or a tool with no skills.

## Skills

A skill is a `SKILL.md` file with the real API of one package and the steps for the usual tasks. The agent reads a skill only when your task matches it. A skill comes with the package, so it always agrees with the package version of your app.

These packages ship a skill:

| Package | Skill | Use it for |
| --- | --- | --- |
| `dox_core` | `dox-core-guide` | routes, controllers, DTOs, serializers, middleware, providers, env config, CLI commands, HTTP tests |
| `dox_orm` | `dox-orm-guide` | models, queries, relations, pagination, transactions, factories, the switch to Postgres or MySQL |
| `dox_migration` | `dox-migration-guide` | migrations, table changes, seeders |
| `dox_validation` | `dox-validation-guide` | DTO rules, custom rules and messages, fluent schemas, database rules |
| `dox_auth` | `dox-auth-guide` | login and logout, JWT, session and access token guards, gates and policies |
| `dox_openapi` | `dox-openapi-guide` | the API docs at `/docs`, annotations for the OpenAPI document |
| `dox_cache` | `dox-cache-guide` | cache stores, `remember`, tags, cache locks, the cache in tests |
| `dox_queue` | `dox-queue-guide` | queue jobs, the worker, the Redis and database drivers, failed jobs, chains and batches |
| `dox_scheduler` | `dox-scheduler-guide` | scheduled tasks, cron frequencies, no double runs on many servers |
| `dox_storage` | `dox-storage-guide` | files and uploads, local, S3, Azure and memory disks, signed URLs |
| `dox_mailer` | `dox-mailer-guide` | mail config, mailables, Markdown mail, queued mail, transports, mail in tests |
| `dox_socketio` | `dox-socketio-guide` | realtime events, rooms, socket login, the Redis adapter, broadcasts |
| `dox_view` | `dox-view-guide` | HTML pages with `.dox.html` templates, layouts, components, forms with CSRF |
| `dox_inertia` | `dox-inertia-guide` | Inertia.js pages with React, Vue or Svelte, shared props, Vite and SSR |
| `dox_mcp` | `dox-mcp-guide` | an MCP server: tools, a route with auth, sessions, OAuth sign-in |
| `dox_grpc` | `dox-grpc-guide` | gRPC services: the `.proto` file, the service class, status codes, deadlines |
| `dox_graphql` | `dox-graphql-guide` | a GraphQL API from annotations and ORM models, auth and limits |
| `ioredis` | `ioredis-guide` | Redis connections, commands, pipelines, transactions, pub/sub |

## Install the skills

The [skills](https://pub.dev/packages/skills) tool copies the skills from your packages into the skills folder of your agent. Run it in the root folder of your app, after `dart pub get`:

```bash
dart run skills@ get
```

It asks which skills to install. Add `--all` to install all of them:

```bash
dart run skills@ get --all
```

### Select your agent

The tool finds your agent from the folders in your project, like `.claude/`. If it finds none, it asks you. To set the agent, use `--agent`:

```bash
dart run skills@ get --all --agent claude
```

| Agent | `--agent` | Skills folder |
| --- | --- | --- |
| Claude Code | `claude` | `.claude/skills/` |
| Codex | `codex` | `.agents/skills/` |
| Cursor | `cursor` | `.cursor/skills/` |
| GitHub Copilot | `copilot` | `.github/skills/` |
| Cline | `cline` | `.cline/skills/` |
| OpenCode | `opencode` | `.opencode/skills/` |
| Antigravity | `antigravity` | `.agents/skills/` |
| Other agents | `generic` | `.agents/skills/` |

The tool does not find GitHub Copilot, so for Copilot always add `--agent copilot`.

### Run it again after a package change

The installed skills are copies. Run the tool again after you add or update a package:

```bash
dart run skills@ get
```

With `--all`, it also removes the skills of packages that you do not use now.

### Packages that come in through another package

The tool reads only the packages in your `pubspec.yaml`. For example, the cache uses ioredis. To get its skill, add it to your app:

```bash
dart pub add ioredis
dart run skills@ get
```

### Make sure that it worked

List the installed skills:

```bash
dart run skills@ list
```

For Claude Code, the core skill is `.claude/skills/dox-core-guide/SKILL.md`. If your tool has no skills, give the `SKILL.md` file to the agent.

## AGENTS.md

The `AGENTS.md` file in the root folder of your app tells the agent how your project is organized. Most coding agents read it before they change code.

The starter project has one. It holds:

- what the project is, and the links to the llms files
- the command that installs the skills, and the list of skills
- the folder layout and the file names
- the `dox` commands that make files
- when to run the code generator, and which files are generated
- the conventions for routes, input, models, migrations, jobs, config and errors
- how to switch the database
- the checks to run before a change is done: `dart format .`, `dart analyze` and `dart test`
- a list of things that the agent must not do

The file is yours. Edit it when your app gets its own rules.

## llms.txt and llms-full.txt

For a chat or a tool with no skills, the docs site has two plain text files in the [llms.txt](https://llmstxt.org) format:

| File | What it holds |
| --- | --- |
| [llms.txt](https://dartondox.dev/llms.txt) | A short description of Dox, then one line for each page with its title and its link. |
| [llms-full.txt](https://dartondox.dev/llms-full.txt) | All the docs as one Markdown file, in the order of the menu. |

The docs build makes them again at each change, so they agree with this site.

### Use them

Give the files to an agent in one of these ways:

1. Paste the link `https://dartondox.dev/llms-full.txt` in a chat agent that can open links.
2. Add the link as a docs source in your editor.
3. Download the file, then attach it to the chat:

    ```bash
    curl -o dox-docs.md https://dartondox.dev/llms-full.txt
    ```

If your agent cannot hold the large file, give it `llms.txt`. The agent then opens only the pages that it needs.

## Skills or llms-full.txt

| | Skills | `llms-full.txt` |
| --- | --- | --- |
| Use it for | code changes in your app | questions in a chat, or a tool with no skills |
| Size | small, one skill for each package | large, all the docs |
| Version | the package version of your app | the latest Dox version |
| How the agent gets it | automatically, when the task matches | you give it the link or the file |

## Next steps

- [Installation](installation.md): create a project.
- [MCP server](../packages/mcp.md): give AI clients tools from your own app.
