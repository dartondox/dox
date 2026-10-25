# Views

Views are HTML templates. Dox fills them with your data and sends them as the response.

The `dox_view` package has a template engine like Edge.js. Templates are `.dox.html` files in `resources/views`.

## Install

```bash
dart pub add dox_view
```

Add the service in `lib/`, so every isolate sets up the engine:

```dart title="lib/services/view_service.dart"
import 'package:dox_view/dox_view.dart';

class AppViewService extends ViewService {
  AppViewService() : super(const ViewConfig());
}
```

## Render a view

`view()` renders a template and sends it as HTML. Leave out the `.dox.html` extension.

```dart
DoxResponse show(DoxRequest req) {
  return view(req, 'users/show', <String, dynamic>{
    'user': user,
    'posts': posts,
  });
}
```

This renders `resources/views/users/show.dox.html`:

```html
<h1>{{ user.name }}</h1>
```

`View.render()` gives the HTML as a string, for example for an email:

```dart
String html = View.render('emails/welcome', <String, dynamic>{'name': 'Ann'});
```

## Output

`{{ }}` prints a value. It escapes HTML, so a user can not add a `<script>` tag to your page.

```html
<p>Hello {{ user.name }}</p>
```

`{{{ }}}` prints a value with no escape. Use it only for HTML you trust.

```html
<article>{{{ post.html }}}</article>
```

`null`, and a variable that does not exist, print nothing.

A comment is not in the output:

```html
{{-- only you see this --}}
```

To print `{{` or a tag as text, put `@` before it: `@{{ name }}` prints `{{ name }}`, and `@@if` prints `@if`.

## Expressions

Inside `{{ }}` and tags, you can use:

| What | Example |
| --- | --- |
| Values | `'text'`, `"text"`, `42`, `1.5`, `true`, `false`, `null` |
| Lists and maps | `[1, 2]`, `{ name: 'Ann', 'full name': 'Ann Lee' }` |
| Fields | `user.name`, `user?.name`, `items[0]`, `map['key']` |
| Math | `+`, `-`, `*`, `/`, `%`, `~/` |
| Compare | `==`, `!=`, `<`, `<=`, `>`, `>=` (`===` and `!==` work too) |
| Logic | `&&`, `\|\|`, `!`, `a ?? b`, `a ? b : c` |
| Functions | `route('users.show', { id: 5 })`, `name.toUpperCase()` |

`+` joins text: `{{ 'Hi ' + name }}`.

Fields work on maps, and on objects with a `toJson()` method, like Dox models.

Lists, maps and text have `length`, `isEmpty` and `isNotEmpty`. Lists also have `first`, `last`, `contains()`, `join()` and `indexOf()`.
Text has `toUpperCase()`, `toLowerCase()`, `trim()`, `contains()`, `startsWith()`, `endsWith()`, `split()`, `replaceAll()`, `substring()` and `indexOf()`.
Numbers have `toStringAsFixed()`, `round()`, `floor()`, `ceil()` and `abs()`.

In `@if` and `?:`, these values are false: `null`, `false`, `0`, `''`, an empty list and an empty map.

## Conditions

```html
@if(user.isAdmin)
  <a href="/admin">Admin</a>
@elseif(user.isEditor)
  <a href="/posts">Posts</a>
@else
  <p>Welcome</p>
@end
```

`@unless(x)` is `@if(!x)`.

A tag alone on its line leaves no empty line in the output.

A tag can not come right after a letter or a digit, so `me@mail.com` stays text. Put a space before the tag, or use `{{ on ? 'active' : '' }}`.

## Loops

```html
<ul>
  @each(user in users)
    <li>{{ user.name }}</li>
  @else
    <li>No users yet</li>
  @end
</ul>
```

The `@else` part shows when the list is empty.

Get the index too, or the key of a map:

```html
@each((user, index) in users)
  {{ index + 1 }}. {{ user.name }}
@end

@each((value, key) in settings)
  {{ key }}: {{ value }}
@end
```

`$loop` has `index`, `first`, `last` and `length`:

```html
@each(tag in tags)
  {{ tag }}{{ $loop.last ? '' : ', ' }}
@end
```

## Variables

`@let` makes a variable. `@assign` changes it.

```html
@let(total = 0)
@each(item in cart)
  @assign(total = total + item.price)
@end
Total: {{ total }}
```

## Partials

`@include` puts another template in this one. It sees the same variables.

```html
@include('partials/nav')
@includeIf(user, 'partials/account')
```

## Layouts and components

A component is a template with its own props and slots. Use one for the page layout.

```html title="resources/views/layouts/main.dox.html"
<!DOCTYPE html>
<html>
  <head>
    <title>{{ title ?? 'My app' }}</title>
  </head>
  <body>
    <header>{{ $slots.header }}</header>
    <main>{{ $slots.main }}</main>
  </body>
</html>
```

```html title="resources/views/home.dox.html"
@component('layouts/main', { title: 'Home' })
  @slot('header')
    <h1>Welcome</h1>
  @end

  <p>Hello {{ user.name }}</p>
@end
```

- The second argument is the props. In the component they are variables (`title`), and also `$props.title`.
- `@slot('name') ... @end` fills a named slot. Everything else goes into `$slots.main`.
- A slot is HTML, so `{{ }}` does not escape it again.
- A component only sees its props, `$props`, `$slots` and the globals. It does not see the variables of the page.

`@!component(...)` is a component with no body and no `@end`.

### Components as tags

A template in `resources/views/components/` is also a tag with its name. A `.` in the tag is a folder.

```html title="resources/views/components/button.dox.html"
<button class="btn btn-{{ type ?? 'primary' }}">{{ $slots.main }}</button>
```

```html
@button({ type: 'danger' })
  Delete
@end

@!form.input({ name: 'email' })   {{-- components/form/input.dox.html --}}
```

## Forms

With `SessionMiddleware`, `view()` adds these to every template:

| Name | What it is |
| --- | --- |
| `csrfField()` | the hidden `_token` field for `CsrfMiddleware` |
| `csrfToken()` | the CSRF token |
| `errors` | the flashed validation errors, like `errors.email` |
| `old('email')` | the input of the request before |
| `session('key')` | a value from the session |

```html
<form method="POST" action="/register">
  {{ csrfField() }}
  <input name="email" value="{{ old('email') }}">
  @if(errors.email)
    <p class="error">{{ errors.email }}</p>
  @end
  <button>Register</button>
</form>
```

Every template from `view()` also has `request.path`, `request.method` and `request.query`.

## Globals

Globals are variables and functions that every template can use. `route()` is there by default.

```dart
const ViewConfig(globals: <String, Object?>{'appName': 'My app'});

View.global('year', DateTime.now().year);
View.global('money', (num cents) => (cents / 100).toStringAsFixed(2));
```

```html
<footer>{{ appName }} {{ year }}</footer>
<a href="{{ route('users.show', { id: user.id }) }}">Profile</a>
<p>{{ money(order.total) }}</p>
```

A value of type `SafeString` is printed with no escape:

```dart
View.global('logo', const SafeString('<img src="/logo.svg" alt="Logo">'));
```

## Config

| Option | Default | What it does |
| --- | --- | --- |
| `path` | `resources/views` | the folder of the templates |
| `extension` | `.dox.html` | the file extension |
| `cache` | on, but off when `APP_ENV` is `development` or `local` | keep parsed templates in memory |
| `globals` | `{}` | variables for every template |

With the cache off, a changed template shows on the next request, with no restart.

## Errors

A syntax error, or an error in an expression, throws a `ViewException`. The message has the template name and the line:

```
ViewException: expected ")" but found the end (in "users/show", line 12)
```

## Prettier

Prettier formats `.html` files, and it does not know the `@` tags. Add this line to `.prettierignore`:

```
*.dox.html
```
