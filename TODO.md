# Dox todo

How to read this file:

- `[ ]` = not done. A done item is removed from this file.
- An item says only what is left to do.
- The first line of an item is the task. The lines under it are details.
- `(HIGH)` = fix first. `(MED)` = fix soon. `(LOW)` = nice to have.
- `BREAKING` = it changes released behavior, so it waits for the next major release. No `BREAKING` tag = safe for a patch release.
- `[OPT IN]` = a `BREAKING` item that can ship before the next major release as an opt-in: the new behavior sits behind a setting or a new name, and the old behavior stays the default. New apps turn it on in the template. The next major release makes it the default.
- Paths start at the folder that holds all the Dox repos. So `dox/...` is this repo and `dox-orm/...` is the dox-orm repo.


## 1. Next major release

- [ ] Make every opt-in flag the default, then remove the flags
  - Each flag has a marker comment in the code. Run `rg "NEXT MAJOR"` in every Dox repo and do what each comment says.
- [ ] WebSocket: add permessage-deflate

### 2. Minor Release

- [] `dox s` is slow on development
- [] openapi for production
- [] update openapi documentation