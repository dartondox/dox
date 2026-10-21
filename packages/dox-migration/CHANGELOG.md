## 3.0.0

- Support MySQL. Set `DB_CONNECTION=mysql` in `.env` (default is `postgres`)
- Run each statement of a `.sql` migration one by one, inside a transaction
- Rollback undoes only the last batch, newest first. Add `step`, `reset()` and `refresh()`
- Stop at the first failed migration
- Fix `.sql` parsing: a `-` in the sql no longer cuts the `up` or `down` part
- Fix statement split: `;` inside quotes, comments or `$$` bodies does not split

## 2.0.0

- Release stable version v2.0

## 2.0.0-alpha.2

- Remove .dart option

## 1.0.4

- Improve loading .env

## 1.0.3

- Bug fixed on sql rollback

## 1.0.2

- Fixed rollback issues

## 1.0.1

- Close connection when running from cli

## 1.0.0

- Initial version.
