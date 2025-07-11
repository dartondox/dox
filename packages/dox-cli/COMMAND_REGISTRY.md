# Command Registry System

The Dox CLI has been refactored to use a command registry system that makes it easy to add new commands.

## How to Add a New Command

### 1. Define the Command

```dart
CommandRegistry.addCommand(
  CommandDefinition(
    command: 'my:command',
    helpInfo: 'my:command <arg1> [arg2]',
    description: 'Description of what this command does',
    minArgs: 1,        // Minimum number of arguments required
    maxArgs: 3,        // Maximum number of arguments allowed (-1 for unlimited)
    aliases: ['mc', 'my'], // Optional aliases for the command
    function: (args) async {
      // Your command implementation here
      final arg1 = args[0];
      final arg2 = args.length > 1 ? args[1] : null;
      
      // Execute your command logic
      print('Executing my command with: $arg1, $arg2');
    },
  ),
);
```

### 2. Command Definition Properties

- **command**: The main command name (e.g., 'create:controller')
- **helpInfo**: Usage information shown in help (e.g., 'create:controller <name> [-r]')
- **description**: Help text for the command
- **minArgs**: Minimum number of arguments required
- **maxArgs**: Maximum number of arguments allowed (-1 for unlimited)
- **aliases**: Optional list of alternative command names
- **function**: The actual function that executes the command

### 3. Example Commands

Here are some examples of how commands are defined in the registry:

```dart
// Simple command with no arguments
CommandDefinition(
  command: 'help',
  helpInfo: 'help [command]',
  description: 'Show help information',
  minArgs: 0,
  maxArgs: 1,
  function: (args) async {
    if (args.isNotEmpty) {
      helpCommand(args[0]);
    } else {
      help();
    }
  },
),

// Command with required arguments
CommandDefinition(
  command: 'create:model',
  helpInfo: 'create:model <model_name>',
  description: 'Create a new model',
  minArgs: 1,
  maxArgs: 1,
  function: (args) async {
    createModel(args[0]);
  },
),

// Command with optional arguments
CommandDefinition(
  command: 'create:controller',
  helpInfo: 'create:controller <controller_name> [-r] [-ws]',
  description: 'Create a new controller',
  minArgs: 1,
  maxArgs: 2,
  function: (args) async {
    final controllerName = args[0];
    final isResource = args.length >= 2 && args[1] == '-r';
    createController(controllerName, isResource);
  },
),

// Command with aliases
CommandDefinition(
  command: 'serve',
  helpInfo: 'serve or s [--ignore-build-runner]',
  description: 'Start the development server',
  aliases: ['server', 's'],
  minArgs: 0,
  maxArgs: 1,
  function: (args) async {
    if (args.isNotEmpty && args[0] == '--ignore-build-runner') {
      serverServe();
    } else {
      watchBuilder();
      serverServe();
    }
  },
),
```

### 4. Help System

The new help system automatically generates help information from the CommandDefinition:

#### General Help
```bash
dox help
```
Shows all commands organized by category:
- **Development**: serve, build, build_runner commands
- **Generation**: create:* commands
- **Database**: migration commands
- **System**: version, help, update, key:generate

#### Command-Specific Help
```bash
dox help <command>
```
Shows detailed information about a specific command including:
- Usage syntax
- Description
- Aliases (if any)
- Argument requirements

Example:
```bash
dox help create:controller
```

Output:
```
Command: create:controller
Usage: dox create:controller <controller_name> [-r] [-ws]
Description: Create a new controller
Arguments: 1 to 2 arguments
```

### 5. Benefits of This System

1. **Easy to Add**: Just define a CommandDefinition and add it to the registry
2. **Type Safe**: All commands are strongly typed
3. **Argument Validation**: Built-in argument count validation
4. **Aliases Support**: Multiple ways to call the same command
5. **Centralized**: All commands are defined in one place
6. **Maintainable**: Clear structure makes it easy to understand and modify
7. **Auto-Generated Help**: Help information is automatically generated from command definitions
8. **Categorized**: Commands are organized by category for better UX

### 6. Adding Commands at Runtime

You can also add commands dynamically:

```dart
// In your application startup
CommandRegistry.addCommand(
  CommandDefinition(
    command: 'custom:command',
    helpInfo: 'custom:command <arg>',
    description: 'A custom command',
    minArgs: 1,
    maxArgs: 1,
    function: (args) async {
      // Custom implementation
    },
  ),
);
```

This system makes the CLI much more maintainable and extensible! 