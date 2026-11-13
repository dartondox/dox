---
icon: material/package-variant-plus
---

# Add a package

`dox add` adds a Dox package to your app and sets it up.

```bash
dox add orm
```

## What it does

1. Runs `dart pub add dox_orm`. `orm` is short for `dox_orm`. The full name works too.
2. Runs `dart pub get`.
3. Runs the setup command of the package, `dox orm:install`.

The setup command writes the config files, adds the keys to `.env` and `.env.example`, and runs `build_runner`.
At the end it prints what it did and the next steps.

A package with no setup command is only added. `dox add` then says so.

## Options

Words after the name go to the setup command:

```bash
dox add orm --driver=postgres
```

`--dev` adds the package as a dev dependency.

## Safe to run twice

The setup command never overwrites a file and never changes a `.env` key that is already there.
So you can run `dox add` again. It only adds what is missing.

## Packages with a setup command

| Command | What it sets up |
| --- | --- |
| `dox add orm [--driver=sqlite\|postgres\|mysql]` | The ORM and migrations. See [Database](../database/index.md). |

To add a setup command to your own package, see [Package commands](../digging-deeper/package-commands.md#ship-an-install-command).
