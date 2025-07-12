import '../command_registry.dart';
import '../types.dart';

help() {
  print("Usage: dox <command> [arguments] \n");
  print('Available commands: \n');

  final commands = CommandRegistry.getAllCommands();

  // Group commands by category
  final Map<CommandCategory, List<CommandDefinition>> categories = {};
  for (final command in commands) {
    final category = command.category;
    categories.putIfAbsent(category, () => []).add(command);
  }

  // Sort categories by their order property
  final sortedCategories = categories.keys.toList()
    ..sort((a, b) => a.order.compareTo(b.order));

  for (final category in sortedCategories) {
    final displayName = category.displayName;
    print('\x1B[1m$displayName:\x1B[0m');

    // Sort commands alphabetically within each category
    final sortedCommands = categories[category]!
      ..sort((a, b) => a.command.compareTo(b.command));
    for (final command in sortedCommands) {
      final padding = ' ' * (30 - command.helpInfo.length);
      print('  ${command.helpInfo}$padding ${command.description}');
    }
    print('');
  }
}

helpCommand(String commandName) {
  final command = CommandRegistry.findCommand(commandName);

  if (command == null) {
    print('Command "$commandName" not found.');
    print('Run "dox help" to see all available commands.');
    return;
  }

  print('\x1B[1mCommand:\x1B[0m ${command.command}');
  print('\x1B[1mUsage:\x1B[0m dox ${command.helpInfo}');
  print('\x1B[1mDescription:\x1B[0m ${command.description}');
  print('\x1B[1mCategory:\x1B[0m ${command.category.displayName}');

  if (command.aliases.isNotEmpty) {
    print('\x1B[1mAliases:\x1B[0m ${command.aliases.join(', ')}');
  }

  if (command.minArgs > 0 || command.maxArgs != -1) {
    String argsInfo = '';
    if (command.minArgs == command.maxArgs) {
      argsInfo =
          '${command.minArgs} argument${command.minArgs == 1 ? '' : 's'}';
    } else if (command.maxArgs == -1) {
      argsInfo =
          'at least ${command.minArgs} argument${command.minArgs == 1 ? '' : 's'}';
    } else {
      argsInfo = '${command.minArgs} to ${command.maxArgs} arguments';
    }
    print('\x1B[1mArguments:\x1B[0m $argsInfo');
  }

  print('');
}
