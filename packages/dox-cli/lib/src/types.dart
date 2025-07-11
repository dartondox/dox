enum CommandCategory {
  project('Project', 0),
  development('Development', 1),
  build('Build', 2),
  buildRunner('Build Runner', 3),
  generation('Generation', 4),
  database('Database', 5),
  system('System', 6);

  final String displayName;
  final int order;
  const CommandCategory(this.displayName, this.order);
}

typedef CommandFunction = Future<void> Function(List<String> args);

class CommandDefinition {
  final String command;
  final String helpInfo;
  final String description;
  final CommandCategory category;
  final int minArgs;
  final int maxArgs;
  final CommandFunction function;
  final List<String> aliases;

  const CommandDefinition({
    required this.command,
    required this.helpInfo,
    required this.description,
    required this.category,
    required this.function,
    this.minArgs = 0,
    this.maxArgs = -1, // -1 means unlimited
    this.aliases = const [],
  });

  bool matches(String inputCommand) {
    return command == inputCommand || aliases.contains(inputCommand);
  }

  bool validateArgs(List<String> args) {
    if (args.length < minArgs) return false;
    if (maxArgs != -1 && args.length > maxArgs) return false;
    return true;
  }
}
