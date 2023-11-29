# Installation

```py
dart pub global activate dox
```

## Create a new project

```py
dox create new_blog
cd new_blog
dart pub get
cp .env.example .env (and modify .env variables)
dox serve or dox s to start http server
```
!!! warning "Export bin path"
    Please make sure you have included `bin` path to your profile. If you did not added path to your profile yet, open `~/.bashrc` or `~/.zshrc` and paste below line.
    
    ```bash
    export PATH="$PATH":"~/.pub-cache/bin"
    ```