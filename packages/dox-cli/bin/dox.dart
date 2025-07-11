import 'package:dox/src/command_registry.dart';

void main(List<String> args) async {
  if (args.isEmpty) {
    print('Could not find a command. Run `dox help` for more information.');
    return;
  }

  final command = args[0];
  final commandArgs = args.skip(1).toList();

  try {
    await _executeCommand(command, commandArgs);
  } catch (e) {
    print(e);
  }
}

Future<void> _executeCommand(String command, List<String> args) async {
  final commandDefinition = CommandRegistry.findCommand(command);

  if (commandDefinition == null) {
    print(
        'Could not find a command named "$command". Run `dox help` for more information.');
    return;
  }

  if (!commandDefinition.validateArgs(args)) {
    print('Invalid number of arguments for command "$command".');
    print(
        'Expected: ${commandDefinition.minArgs}${commandDefinition.maxArgs != -1 ? ' to ${commandDefinition.maxArgs}' : '+'} arguments');
    print('Received: ${args.length} arguments');
    return;
  }

  try {
    await commandDefinition.function(args);
  } catch (e) {
    print(e);
  }
}
