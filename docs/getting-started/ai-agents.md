---
icon: material/robot-outline
---

# AI agents

An AI coding agent must know the real Dox API. If it does not, it guesses class names and method names, and the code does not compile.

Dox gives the agent two sources:

- **Skills**: short guides that each package ships. The agent reads them while it writes code in your app.
- **`llms.txt` and `llms-full.txt`**: these docs as plain text files, for a chat or for a tool that has no skills.

## Skills

A skill is a `SKILL.md` file with the real API of one package and the steps for the usual tasks. Each Dox package ships its skill in its `skills/<name>/` folder.

The agent does not read all skills at the start. It reads a skill only when your task matches it. Thus the skills use little space in the memory of the agent.

A skill comes with the package. Thus it always agrees with the package version that your app uses.

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
| `dox_storage` | `dox-storage-guide` | files and uploads, local, S3 and memory disks, signed URLs |
| `dox_mailer` | `dox-mailer-guide` | mail config, mailables, Markdown mail, queued mail, transports, mail in tests |
| `dox_socketio` | `dox-socketio-guide` | realtime events, rooms, socket login, the Redis adapter, broadcasts |
| `dox_view` | `dox-view-guide` | HTML pages with `.dox.html` templates, layouts, components, forms with CSRF |
| `dox_inertia` | `dox-inertia-guide` | Inertia.js pages with React, Vue or Svelte, shared props, Vite and SSR |
| `dox_mcp` | `dox-mcp-guide` | an MCP server: tools, a route with auth, sessions, OAuth sign-in |
| `dox_grpc` | `dox-grpc-guide` | gRPC services: the `.proto` file, the service class, status codes, deadlines |
| `dox_graphql` | `dox-graphql-guide` | a GraphQL API from annotations and ORM models, auth and limits |
| `ioredis` | `ioredis-guide` | Redis connections, commands, pipelines, transactions, pub/sub |

## Install the skills

The skills are not in your project until you install them. The [skills](https://pub.dev/packages/skills) tool copies them from your packages into the skills folder of your agent.

Run it in the root folder of your app, after `dart pub get`:

```bash
dart run skills@ get
```

The tool finds the skills of your packages. Then it asks which skills to install. To install all of them with no question, add `--all`:

```bash
dart run skills@ get --all
```

### Select your agent

The tool finds your agent from the folders in your project, for example `.claude/` or `.cursor/`. If it finds more than one agent, it installs the skills for each of them. If it finds none, it asks you.

To set the agent yourself, use `--agent`:

```bash
dart run skills@ get --all --agent claude
```

Each agent has its own skills folder:

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

The tool does not find GitHub Copilot automatically. For Copilot, always use `--agent copilot`.

### Run it again after a package change

The installed skills are copies. They do not change when a package changes.

Run `dart run skills@ get` again after you add a package or update a package. The tool then installs the new skills. It also removes the skills of packages that your app does not use now.

### Packages that come in through another package

The tool only reads the packages in your own `pubspec.yaml`. It does not see a package that comes in through a different package.

For example, `dox_cache` uses `ioredis`. If you use `ioredis` directly in your code, add it to your `pubspec.yaml`:

```bash
dart pub add ioredis
dart run skills@ get
```

### Make sure that it worked

List the installed skills:

```bash
dart run skills@ list
```

You can also look in the skills folder of your agent. For Claude Code, the `dox_core` skill is the file `.claude/skills/dox-core-guide/SKILL.md`.

If your tool has no support for skills, open the `SKILL.md` file as a normal file, or give it to the agent.

## AGENTS.md

A skill tells the agent how a package works. It does not tell the agent how your project is organized. The `AGENTS.md` file in the root folder of your app does that. Most coding agents read this file before they change code.

The starter project that `dox create` makes has an `AGENTS.md` file. It holds:

- what the project is, and the links to the llms files
- the command that installs the skills, and the list of skills
- the folder layout and the file names
- the `dox` commands that make files
- when to run the code generator, and which files are generated
- the conventions for routes, input, models, migrations, jobs, config and errors
- how to switch the database
- the checks to run before a change is done: `dart format .`, `dart analyze` and `dart test`
- a list of things that the agent must not do

This file is yours. Edit it when your app gets its own rules, for example a new folder or a rule for tests.

## llms.txt and llms-full.txt

Not every tool can read skills, and a chat does not see your project. For these, the docs site has two plain text files. They obey the [llms.txt](https://llmstxt.org) convention.

| File | What it holds |
| --- | --- |
| [llms.txt](https://dartondox.dev/llms.txt) | The page list: a short description of Dox, then one line for each page with its title and its link. |
| [llms-full.txt](https://dartondox.dev/llms-full.txt) | All the docs as one Markdown file. |

### What is in the files

The docs build makes the two files again each time the docs change. Thus they always agree with this site.

- They hold the docs of the latest Dox version. The links in them go to `https://dartondox.dev/latest/`.
- They hold each page of the menu of this site, in the same sequence.
- In `llms-full.txt`, each page starts with its title and its link. Then comes the Markdown source of the page, with all its code examples.
- The blog and the docs of older Dox versions are not in the files.

### Use them

There are three ways to give the files to an agent:

1. **Paste the link.** In a chat agent that can open links, paste `https://dartondox.dev/llms-full.txt` and ask your question.
2. **Add a docs source.** Some editors let you add documentation by its link. In Cursor, add the link as a new doc, then use `@Docs` in the chat.
3. **Download the file.** Save it, then point the agent at the file or attach it to the chat:

    ```bash
    curl -o dox-docs.md https://dartondox.dev/llms-full.txt
    ```

`llms-full.txt` is a large file. If your agent cannot hold it, give it `llms.txt`. The agent then opens only the pages that it needs.

## Skills or llms-full.txt

| | Skills | `llms-full.txt` |
| --- | --- | --- |
| Use it for | code changes in your app | questions in a chat, or a tool with no skills |
| Size | small, one skill for each package | large, all the docs |
| Version | the package version of your app | the latest Dox version |
| How the agent gets it | automatically, when the task matches | you give it the link or the file |

For daily work in your app, install the skills and keep `AGENTS.md`. Use `llms-full.txt` when you ask about Dox out of your project, or when your tool cannot read skills.
