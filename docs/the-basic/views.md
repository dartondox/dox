---
icon: lucide/layout-template
---

# Views

Views are HTML templates.

Dox fills them with your data and sends them as the response.

The `dox_view` package has a template engine like Edge.js. Templates are `.dox.html` files in `resources/views`.

## Install

```bash
dart pub add dox_view
```

Add the provider in `lib/`, so every isolate sets up the engine:

```dart title="lib/providers/view_provider.dart"
import 'package:dox_view/dox_view.dart';

class AppViewProvider extends ViewProvider {
  AppViewProvider() : super(const ViewConfig());
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

### Stay safe

`{{ }}` escapes HTML. It does not make every place in a page safe.

- **Always quote attributes.** Write `href="{{ url }}"`, not `href={{ url }}`.
  Without quotes, a space in the value starts a new attribute, like `onclick=...`.
- **Check URLs from users.** `href="{{ url }}"` does not block a `javascript:` URL.
  A click on `javascript:alert(1)` runs the code.
  Allow only `http://` and `https://` URLs (or your own paths) before you print them.
- **`<script>` and `<style>` are not safe.** Inside them, `{{ }}` only escapes HTML.
  It does not make a value safe for JavaScript or CSS.
  Do not print user data there. Put it in a quoted `data-` attribute, and read it in your script.

```html
<a href="{{ profile.website }}">Website</a>  {{-- only after you check it is http or https --}}

<div id="app" data-user-name="{{ user.name }}"></div>
<script>
  const name = document.getElementById('app').dataset.userName;
</script>
```

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

## More tags

Close a block tag with `@end`. `@else` works in all of them, but not in `@once` and `@verbatim`.

Put `@auth`, `@guest`, `@production`, `@once` and `@verbatim` alone on their line. In the middle of text, like `@once upon a time`, they stay text.

With a space before the `(`, in the middle of a line, a tag is used only when its args are a valid expression. A tag with a body, like `@isset`, `@empty`, `@env`, `@section` and `@push`, also needs an `@end` after it. So text like `@empty (none)` or `@class (see docs)` stays text. With no space, like `@empty(items)`, a tag is always a tag. Alone on its line, a tag is also always a tag, with one exception: `@extends`, `@section`, `@yield`, `@stack`, `@push`, `@prepend` and `@method`. With a space before the `(`, these seven are tags only when the first argument is text in quotes, like `@yield ('title')`. This holds on any line. So text like `git @push (force)` or `the @yield (curve)` stays text.

| Tag | What it does |
| --- | --- |
| `@isset(user.phone) ... @end` | shows when the value is not `null`. A field of `null` is not an error here. |
| `@empty(items) ... @end` | shows when the value is false: `null`, `false`, `0`, `''`, an empty list or map |
| `@auth ... @end` | shows when the user is logged in (`req.auth`) |
| `@guest ... @end` | shows when the user is not logged in |
| `@env('local') ... @end` | shows when `APP_ENV` is this value. A list works too: `@env(['local', 'staging'])`. Case does not matter. |
| `@production ... @end` | shows when `APP_ENV` is `production` |
| `@once ... @end` | shows only the first time in one render, for example a `<script>` in a component |
| `@verbatim ... @end` | prints the text as it is: no `{{ }}` and no tags run inside it |
| `@extends('layouts/app')` | the layout of the page. See [Layouts with sections](#layouts-with-sections). |
| `@section('name') ... @end` | fills a section. Short form: `@section('title', 'Home')`. |
| `@yield('name')` | prints a section. `@yield('title', 'My app')` has a default. |
| `@stack('scripts')` | prints every push of the stack. See [Stacks](#stacks). |
| `@push('scripts') ... @end` | adds to the end of a stack |
| `@prepend('scripts') ... @end` | adds to the start of a stack |
| `@csrf` | the hidden `_token` field. See [Forms](#forms). |
| `@method('PUT')` | the hidden `_method` field |
| `@datetime(...)` | a tag of your app. See [Your own tags](#your-own-tags). |

```html
@auth
  <a href="/logout">Log out</a>
@else
  <a href="/login">Log in</a>
@end
```

`@auth` and `@guest` use the `req.auth` that `view()` gets. In `View.render` there is no request, so `@guest` shows.

`@verbatim` ends at the first `@end`, so the text inside can not have `@end`. Use it for code of a JavaScript framework that also uses `{{ }}`:

```html
@verbatim
  <div id="app">{{ message }}</div>
@end
```

These tags print an HTML attribute:

```html
<a @class(['link', { active: isActive, muted: !isActive }])>Home</a>
<input type="checkbox" name="news" @checked(user.news)>
<option value="en" @selected(lang == 'en')>English</option>
<button @disabled(saving)>Save</button>
```

- `@class` takes text, a map of class name to a condition, or a list of these. It prints `class="..."` with the names whose condition is true. The names are escaped.
- `@checked`, `@selected` and `@disabled` print the attribute name when the value is true.

A tag can not come right after a letter or a digit. Write `on @else off`, not `on@else off`.

When `resources/views/components/` has a template with the same name, like `class.dox.html`, the component wins.

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
- `$slot` is the same as `$slots.main`. Both are always there. They are empty when the component has no body.
- A component only sees its props, `$props`, `$slots`, `$slot`, `$attributes`, the globals and the request helpers of `view()` (see [Forms](#forms)). It does not see the variables of the page.

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

### Attributes

`$attributes` has the props as HTML attributes. `{{ $attributes }}` prints them, like `id="save" title="Save"`. The values are escaped.

`$attributes.merge({ ... })` adds default attributes. A prop wins over a default, but `class` is joined:

```html
<button {{ $attributes.merge({ class: 'btn', type: 'button' }) }}>{{ $slot }}</button>
```

```html
@button({ class: 'btn-big', type: 'submit' })
  Save
@end
```

This prints `<button class="btn btn-big" type="submit">`.

Only text, numbers and `true` are attributes. `true` prints the name alone, like `hidden`. `null`, `false`, lists, maps and objects are left out. You can still read any prop, like `$attributes.type`.

`$attributes` keeps any attribute name, like `onclick`. So do not pass a map from the user as the props of a component.

## Layouts with sections

A page can also name its layout with `@extends`. The page fills sections. The layout prints them with `@yield`.

```html title="resources/views/layouts/app.dox.html"
<!DOCTYPE html>
<html>
  <head>
    <title>@yield('title', 'My app')</title>
  </head>
  <body>
    <main>@yield('content')</main>
  </body>
</html>
```

```html title="resources/views/home.dox.html"
@extends('layouts/app')

@section('title', 'Home')

@section('content')
  <p>Hello {{ user.name }}</p>
@end
```

- `@extends` must be the first thing in the template. A template can have only one.
- `@section('name') ... @end` fills a section. The short form `@section('title', 'Home')` takes a value. The value is escaped, like `{{ }}`.
- `@yield('name')` prints a section. With a second argument, like `@yield('title', 'My app')`, it prints that value when the page has no such section. The value is escaped too.
- In a page with `@extends`, only the sections reach the layout. Text outside a section is not printed. `@let` and `@push` outside a section still work.
- A section sees the variables of the page. The layout sees them too.
- A layout can extend another layout. When a page and its layout fill the same section, the page wins.
- The names of sections and stacks must be plain text in quotes, like `'title'`.
- The first `@section` with a name wins. So a `@section` inside `@each` keeps only the first round.
- A `@yield('s')` that comes before the `@section('s')` in the same file prints nothing.
- An `@include` or a component with its own `@extends` prints its layout in place. It shares the section names with the page.
- A tag right after a letter or a digit, like `L@yield('s')`, stays text.

Use `@extends` for the page layout. Use a component when you need props or more than one copy on a page.

## Stacks

A stack collects HTML from many templates and prints it in one place. Use it for scripts and styles.

```html
<head>
  @stack('styles')
</head>
<body>
  @yield('content')
  @stack('scripts')
</body>
```

```html
@push('scripts')
  <script src="/js/chart.js"></script>
@end
```

- `@push('name') ... @end` adds to the end of the stack. `@prepend('name') ... @end` adds to the start.
- A push works from the page, its layout, an `@include` and a component.
- `@stack` can come before the `@push` in the page. It still prints every push.
- The pushes are printed in the order they run. A page with `@extends` runs before its layout.
- Put `@once` inside `@push` in a component, so the script is added one time only.

`@extends`, `@section`, `@yield`, `@stack`, `@push`, `@prepend` and `@method` need `( )`. With no `( )`, like `@section` in a sentence, they stay text. For a space before the `(`, see the rule in [More tags](#more-tags).

## Forms

With `SessionMiddleware`, `view()` adds these to every template:

| Name | What it is |
| --- | --- |
| `csrfField()` | the hidden `_token` field for `CsrfMiddleware`. `@csrf` prints the same. |
| `csrfToken()` | the CSRF token |
| `errors` | the flashed validation errors, like `errors.email` |
| `old('email')` | the input of the request before |
| `session('key')` | a value from the session |

If your app has a global named `errors`, the global shows when the request has no validation errors. When there are validation errors, they win over the global.

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

`@csrf` prints the same hidden field as `csrfField()`. Put it alone on its line. With no session, `@csrf` throws a `ViewException`.

A browser form can only send GET and POST. For a PUT, PATCH or DELETE route, send a POST and add `@method`. It prints the hidden `_method` field that the `MethodOverride` middleware reads:

```html
<form method="POST" action="/posts/{{ post.id }}">
  @csrf
  @method('PUT')
  <input name="title" value="{{ post.title }}">
  <button>Save</button>
</form>
```

This prints `<input type="hidden" name="_token" value="...">` and `<input type="hidden" name="_method" value="PUT">`.

Every template from `view()` also has `request.path`, `request.method` and `request.query`.

Components and layouts see all of these too, so a layout can use `request.path` and a form component can use `csrfField()`.

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

You can add globals before or after `View.configure()`. The engine keeps them. When a name is in both, the value in `ViewConfig.globals` wins.

Each isolate has its own engine. So add globals in your provider, after `super.setup()`. Then every isolate gets them:

```dart title="lib/providers/view_provider.dart"
class AppViewProvider extends ViewProvider {
  AppViewProvider() : super(const ViewConfig());

  @override
  void setup() {
    super.setup();
    View.global('year', DateTime.now().year);
  }
}
```

A value of type `SafeString` is printed with no escape:

```dart
View.global('logo', const SafeString('<img src="/logo.svg" alt="Logo">'));
```

## Your own tags

A directive is a tag that your app adds. Write a class with a `render` method. It gets the values between `(` and `)`, and gives the text to print.

```dart
class DateTimeDirective implements ViewDirective {
  @override
  Object? render(List<Object?> args, Scope scope) {
    Object? value = args[0];
    DateTime time = value is DateTime ? value : DateTime.parse('$value');
    return '${time.day}/${time.month}/${time.year}';
  }
}

View.directive('datetime', DateTimeDirective());
```

```html
<time>@datetime(post.createdAt)</time>
```

- The text is escaped, like `{{ }}`. Give a `SafeString` to print HTML as it is. `null` prints nothing.
- `scope.lookup('name')` reads a variable of the template.
- A directive has no body and no `@end`.
- The tag needs `( )`. With no `( )`, like `@datetime` in a sentence, it stays text.
- The name can have letters, digits and `_`. The name of a built-in tag, like `if` or `section`, throws a `ViewException`.
- When `resources/views/components/` has a template with the same name, the component wins.
- You can also give them in the config: `ViewConfig(directives: <String, ViewDirective>{'datetime': DateTimeDirective()})`.

Each isolate has its own engine. So add directives in your provider, after `super.setup()`, like globals.

## Config

| Option | Default | What it does |
| --- | --- | --- |
| `path` | `resources/views` | the folder of the templates |
| `extension` | `.dox.html` | the file extension |
| `cache` | on, but off when `APP_ENV` is `development` or `local` | keep parsed templates in memory |
| `globals` | `{}` | variables for every template |
| `directives` | `{}` | your own tags, by name |

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
