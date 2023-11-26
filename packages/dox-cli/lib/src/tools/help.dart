help() {
  print("Usage: dox <command> [arguments] \n");
  print('Available commands: \n');
  print("""
  serve or s                    Run server
  build                         Build for production
  create:model <name>           Create a model
  create:model <name> -m        Create a model with migration
  create:controller <name>      Create a controller
  create:controller <name> -r   Create a resource controller
  create:controller <name> -ws  Create a websocket controller
  create:middleware <name>      Create a middleware
  create:request <name>         Create a form request
  create:migration <name>       Create a form request
  migrate                       Run migrations
  migrate:rollback              Rollback migrations
  key:generate                  Generate app key
  update                        Update dox-cli to latest version""");
}
