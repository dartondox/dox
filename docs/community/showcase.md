---
icon: lucide/app-window
description: Real open source apps built with Dox that you can read, run and copy from.
---

# Showcase

This page lists real open source apps built with Dox that you can read, run and copy from.

## Monthly Expense

[Monthly Expense](https://github.com/necessarylion/monthly-expense) is an expense tracker for you and the people you share money with. You log expenses, track wallets in many currencies and keep a shopping list. An AI assistant like Claude can add expenses and read summaries for you over MCP.

| Part | What it uses |
| --- | --- |
| API | Dox, with SQLite or Postgres |
| Web app | React, Vite, Tailwind and shadcn/ui |
| Sign-in | Firebase (Google), checked on every API request |
| AI | An MCP server with OAuth sign-in, 44 tools |
| Deploy | One Docker image with the web app and a native API binary |

What you can learn from it:

- **ORM and migrations.** Groups, members, categories, expenses, wallets and budgets as models. The app runs the migrations when it starts. See [Model](../database/model/index.md) and [Migration](../database/migration.md).
- **Token auth from another service.** The API checks a Firebase ID token in middleware. It makes the user on the first sign-in. See [Middleware](../the-basic/middleware.md).
- **MCP for AI clients.** Each HTTP route has a matching MCP tool with the same input. See [MCP](../packages/mcp.md).
- **Scheduled jobs.** See [Scheduler](../digging-deeper/scheduler.md).
- **One container in production.** The API serves the built web app and compiles to a native binary. CI runs the tests on SQLite and Postgres, then pushes the image. See [Docker](../guides/docker.md).

Run it on your machine:

```bash
git clone https://github.com/necessarylion/monthly-expense.git
cd monthly-expense
./dev.sh
```

The [README](https://github.com/necessarylion/monthly-expense#readme) lists the Firebase settings and env vars you need first.

## Add your app

Built something with Dox? Open a pull request that adds it to this page. Your app must be open source, so readers can see the code.
