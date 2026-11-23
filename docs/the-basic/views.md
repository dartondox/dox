---
icon: lucide/layout-template
---

# Views

Views are HTML templates that Dox fills with your data and sends as the response.

The `dox_view` package has the template engine. Templates are `.dox.html` files in `resources/views`.

## Setup

Add the package with the CLI. It adds the package, the provider, the `resources/views` folder and a sample view:

```bash
dox add view
```

### Set it up by hand

Add the package:

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

To make a view file, run `dox make:view emails/welcome`. See [`dox make:view`](../reference/cli.md#dox-makeview).

### Config

Set the options in `ViewConfig`:

| Option | Default | What it does |
| --- | --- | --- |
| `path` | `resources/views` | the folder of the templates |
| `extension` | `.dox.html` | the file extension |
| `cache` | on, but off when `APP_ENV` is development or local | keep parsed templates in memory. With the cache off, a changed template shows on the next request. |
| `globals` | empty | variables for every template. See [Globals](#globals). |
| `directives` | empty | your own tags, by name. See [Your own tags](#your-own-tags). |
| `strictVariables` | false | a variable that does not exist throws. See [Strict options](#strict-options). |
| `stringZeroIsFalse` | false | the text '0' is false in a condition |
| `bladeOutput` | false | print true as 1, false as nothing and 10.0 as 10 |
| `bladeWarnings` | true | warn about tag names of other template engines. See [Unknown tag warnings](#unknown-tag-warnings). |

To set up the engine with no provider, call `View.configure(config)`.

## Rendering views

Render a template and send it as HTML. Leave out the `.dox.html` extension:

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

### Rendering to a string

Get the HTML as a string, for example for an email:

```dart
String html =
    View.render('emails/welcome', <String, dynamic>{'name': 'Ann'});
```

`View.engine.exists('emails/welcome')` tells if a template is there.

## Displaying data

`{{ }}` prints a value. It escapes HTML, so a user can not add a script tag to your page:

```html
<p>Hello {{ user.name }}</p>
```

`{{{ }}}` prints a value with no escape. Use it only for HTML you trust:

```html
<article>{{{ post.html }}}</article>
```

A null value and a variable that does not exist print nothing.

### Comments

A comment is not in the output:

```html
{{-- only you see this --}}
```

To print `{{` or a tag as text, put `@` before it: `@{{ name }}` prints `{{ name }}`, and `@@if` prints `@if`.

### Stay safe

`{{ }}` escapes HTML, but that does not make every place in a page safe:

- Always quote attributes. Write `href="{{ url }}"`, not `href={{ url }}`.
- Check URLs from users. `href="{{ url }}"` does not block a `javascript:` URL, so allow only http and https URLs.
- Do not print user data inside a script or style tag with `{{ }}`. Use [`@json`](#json-for-javascript), or a quoted `data-` attribute.

```html
<div id="app" data-user-name="{{ user.name }}"></div>
<script>
  const name = document.getElementById('app').dataset.userName;
</script>
```

## Expressions

Use these expressions inside `{{ }}` and tags:

| What | Example |
| --- | --- |
| Values | `'text'`, `"text"`, `42`, `1.5`, `true`, `false`, `null` |
| Lists and maps | `[1, 2]`, `{ name: 'Ann', 'full name': 'Ann Lee' }` |
| Fields | `user.name`, `user?.name`, `items[0]`, `map['key']` |
| Math | `+`, `-`, `*`, `/`, `%`, `~/` |
| Compare | `==`, `!=`, `<`, `<=`, `>`, `>=` (`===` and `!==` work too) |
| Logic | `&&`, `\|\|`, `!`, `a ?? b`, `a ? b : c` |
| Functions | `route('users.show', { id: 5 })`, `name.toUpperCase()` |

`+` joins text. Fields work on maps, and on objects with a `toJson()` method, like Dox models. These methods work too:

- Lists, maps and text: `length`, `isEmpty`, `isNotEmpty`.
- Lists: `first`, `last`, `contains()`, `join()`, `indexOf()`.
- Text: `toUpperCase()`, `toLowerCase()`, `trim()`, `contains()`, `startsWith()`, `endsWith()`, `split()`, `replaceAll()`, `substring()`, `indexOf()`.
- Numbers: `toStringAsFixed()`, `round()`, `floor()`, `ceil()`, `abs()`.

In a condition, these values are false: null, false, 0, an empty string, an empty list and an empty map.

## Conditions

Show a part only in some cases. Close it with `@end`:

```html
@if(user.isAdmin)
  <a href="/admin">Admin</a>
@elseif(user.isEditor)
  <a href="/posts">Posts</a>
@else
  <p>Welcome</p>
@end
```

`@unless(x)` is `@if(!x)`. A tag alone on its line leaves no empty line in the output.

A tag right after a letter or a digit stays text, so `me@mail.com` is safe. Put a space before the tag, or use `{{ on ? 'active' : '' }}`.

## Loops

Print a list. The `@else` part shows when the list is empty:

```html
<ul>
  @each(user in users)
    <li>{{ user.name }}</li>
  @else
    <li>No users yet</li>
  @end
</ul>
```

Use two names to get the index, or the key of a map:

```html
@each((user, index) in users)
  {{ index + 1 }}. {{ user.name }}
@end

@each((value, key) in settings)
  {{ key }}: {{ value }}
@end
```

### The loop variable

`$loop` tells you where the loop is:

```html
@each(tag in tags)
  {{ tag }}{{ $loop.last ? '' : ', ' }}
@end
```

| Field | What it is |
| --- | --- |
| `$loop.index` | the round, from 0 |
| `$loop.iteration` | the round, from 1 |
| `$loop.first` | true in the first round |
| `$loop.last` | true in the last round |
| `$loop.count` | the number of items. `$loop.length` is the same. |
| `$loop.remaining` | the rounds left after this one |
| `$loop.even` | true in the 2nd, 4th, ... round |
| `$loop.odd` | true in the 1st, 3rd, ... round |
| `$loop.depth` | 1 for a loop, 2 for a loop inside a loop |
| `$loop.parent` | the `$loop` of the outer loop, or null |

## Variables

Make a variable with `@let`, and change it with `@assign`:

```html
@let(total = 0)
@each(item in cart)
  @assign(total = total + item.price)
@end
Total: {{ total }}
```

## Partials

Put another template in this one. It sees the same variables:

```html
@include('partials/nav')
```

Pass a map to give it more variables, only for this include:

```html
@include('partials/card', { title: 'Profile', user: post.author })
```

Include a template only when a condition is true. `@includeIf` and `@includeWhen` are the same:

```html
@includeIf(user, 'partials/account')
@includeWhen(user.isAdmin, 'partials/admin', { level: 2 })
```

## More tags

Close a block tag with `@end`. `@else` works in all of them, but not in `@once` and `@verbatim`:

| Tag | What it does |
| --- | --- |
| `@isset(user.phone) ... @end` | shows when the value is not null |
| `@empty(items) ... @end` | shows when the value is false |
| `@auth ... @end` | shows when the user is logged in (`req.auth`) |
| `@guest ... @end` | shows when the user is not logged in |
| `@env('local') ... @end` | shows when `APP_ENV` is this value. A list works too: `@env(['local', 'staging'])`. |
| `@production ... @end` | shows when `APP_ENV` is production |
| `@once ... @end` | shows only the first time in one render, for example a script in a component |
| `@verbatim ... @end` | prints the text as it is, for JavaScript frameworks that also use `{{ }}`. The text can not have `@end`. |
| `@extends('layouts/app')` | the layout of the page. See [Layouts with sections](#layouts-with-sections). |
| `@section('name') ... @end` | fills a section. Short form: `@section('title', 'Home')`. |
| `@yield('name')` | prints a section. `@yield('title', 'My app')` has a default. |
| `@stack('scripts')` | prints every push of the stack. See [Stacks](#stacks). |
| `@push('scripts') ... @end` | adds to the end of a stack |
| `@prepend('scripts') ... @end` | adds to the start of a stack |
| `@csrf` | the hidden `_token` field. See [Forms](#forms). |
| `@method('PUT')` | the hidden `_method` field |
| `@error('email') ... @end` | shows when the field has a validation error |
| `@json(value)` | the value as JSON. See [JSON for JavaScript](#json-for-javascript). |

Put `@auth`, `@guest`, `@production`, `@once` and `@verbatim` alone on their line. In `View.render` there is no request, so `@guest` shows.

### Attributes from conditions

Print an HTML attribute when a condition is true:

```html
<a @class(['link', { active: isActive, muted: !isActive }])>Home</a>
<input type="checkbox" name="news" @checked(user.news)>
<option value="en" @selected(lang == 'en')>English</option>
<button @disabled(saving)>Save</button>
```

`@class` takes text, a map of class name to a condition, or a list of these.

## Layouts and components

A **component** is a template with its own props and slots. Use one for the page layout:

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

A page puts its content in the component:

```html title="resources/views/home.dox.html"
@component('layouts/main', { title: 'Home' })
  @slot('header')
    <h1>Welcome</h1>
  @end

  <p>Hello {{ user.name }}</p>
@end
```

- The second argument is the props. In the component they are variables, and also `$props.title`.
- `@slot('name') ... @end` fills a named slot. All other content goes into `$slots.main`, which is also `$slot`.
- A component does not see the variables of the page. It sees its props, the slots, `$attributes`, the globals and the [form helpers](#forms).

`@!component(...)` is a component with no body and no `@end`.

### Components as tags

A template in `resources/views/components/` is also a tag with its name. A `.` in the tag is a folder:

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

`{{ $attributes }}` prints the props as escaped HTML attributes, like `id="save" title="Save"`. `merge` adds defaults. A prop wins, but `class` is joined:

```html
<button {{ $attributes.merge({ class: 'btn', type: 'button' }) }}>
  {{ $slot }}
</button>
```

```html
@button({ class: 'btn-big', type: 'submit' })
  Save
@end
```

This prints `<button class="btn btn-big" type="submit">`.

Leave out props that are only for the logic of the component with `except`. It can go before `merge`:

```html
<button {{ $attributes.except(['variant']).merge({ class: 'btn' }) }}>
```

Only text, numbers and true are attributes, and true prints the name alone. `$attributes` keeps any attribute name, like `onclick`, so do not pass a map from the user as props.

## Layouts with sections

A page can name its layout with `@extends`. The page fills sections, and the layout prints them with `@yield`:

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

- `@extends` must be the first thing in the template.
- Only the sections reach the layout. Text outside a section is not printed.
- A layout can extend another layout. When both fill the same section, the page wins.

Use `@extends` for the page layout. Use a component when you need props or more than one copy on a page.

## Stacks

A **stack** collects HTML from many templates and prints it in one place, like scripts in the head. The layout prints it:

```html
<head>
  @stack('styles')
</head>
<body>
  @yield('content')
  @stack('scripts')
</body>
```

A page, an include or a component adds to it:

```html
@push('scripts')
  <script src="/js/chart.js"></script>
@end
```

`@prepend` adds to the start. Put `@once` inside `@push` in a component, so the script is added one time only.

## Forms

With `SessionMiddleware`, `view()` adds these to every template, also to components and layouts:

| Name | What it is |
| --- | --- |
| `csrfField()` | the hidden `_token` field for `CsrfMiddleware`. `@csrf` prints the same. |
| `csrfToken()` | the CSRF token |
| `errors` | the flashed validation errors, like `errors.email` |
| `old('email')` | the input of the request before |
| `session('key')` | a value from the session |
| `request.path`, `request.method`, `request.query` | the current request (also with no session) |

```html
<form method="POST" action="/register">
  @csrf
  <input name="email" value="{{ old('email') }}">
  @error('email')
    <p class="error">{{ message }}</p>
  @end
  <button>Register</button>
</form>
```

With no session, `@csrf` throws a `ViewException`.

### Validation errors

`@error('field')` shows its body when the field has an error. Inside it, `message` is the error. A dotted name, like `@error('user.email')`, works for nested fields, and the name can be a variable.

### Method fields

For a PUT, PATCH or DELETE route, send a POST with `@method`. The [`MethodOverride`](routing.md#forms-with-put-patch-and-delete) middleware reads it:

```html
<form method="POST" action="/posts/{{ post.id }}">
  @csrf
  @method('PUT')
  <input name="title" value="{{ post.title }}">
  <button>Save</button>
</form>
```

## Globals

A **global** is a variable or a function that every template can use. `route()` is there by default:

```dart
const ViewConfig(globals: <String, Object?>{'appName': 'My app'});

View.global('year', DateTime.now().year);
View.global('money', (num cents) => (cents / 100).toStringAsFixed(2));
```

```html
<footer>{{ appName }} {{ year }}</footer>
<p>{{ money(order.total) }}</p>
```

Each isolate has its own engine, so add globals in your provider, after `super.setup()`:

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

A global that holds HTML must be a `SafeString`, so it is printed with no escape:

```dart
View.global('logo', const SafeString('<img src="/logo.svg" alt="Logo">'));
```

To escape text yourself in Dart, use `escapeHtml(text)`.

## JSON for JavaScript

Print a value as JSON. The output is safe in a script block and in an attribute in single quotes:

```html
<script>
  const user = @json(user);
</script>

<div data-tags='@json(tags)'></div>
```

Do not use it in an attribute in double quotes, because the JSON has `"` in it. A value that can not be JSON, like a `DateTime`, throws a `ViewException`.

`json(value)` does the same in an expression, and `SafeString.json(value)` does it in Dart:

```html
@!chart({ points: json(points) })
```

## Your own tags

A **directive** is a tag that your app adds. Its `render` method gets the values between the brackets, and gives the text to print:

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

The text is escaped. Give a `SafeString` to print HTML. `scope.lookup('name')` reads a variable, and `scope.has('name')` tells if it is there. Add directives in your provider like globals, or in `ViewConfig(directives: ...)`.

## Strict options

These three options are off by default. Turn them on in `ViewConfig`:

```dart
const ViewConfig(
  strictVariables: true,
  stringZeroIsFalse: true,
  bladeOutput: true,
);
```

- `strictVariables`: a variable that does not exist throws a `ViewException` with the name, the template and the line. So a typo like `{{ titel }}` shows as an error.
- `stringZeroIsFalse`: the text '0' is false in a condition. Other text, like '00', is still true.
- `bladeOutput`: `{{ }}` prints true as 1, false as nothing, and 10.0 as 10.

With `strictVariables`, these ways to read a variable that may not exist never throw:

| Code | What it gives when `user` does not exist |
| --- | --- |
| `@isset(user) ... @end` | the body is not printed |
| `@empty(user) ... @end` | the body is printed |
| `{{ user ?? 'Guest' }}` | Guest |
| `{{ user?.name }}` | nothing |

`{{ user.name ?? 'Guest' }}` still throws when `user` does not exist. Write `{{ user?.name ?? 'Guest' }}`.

## Unknown tag warnings

Some tag names of other template engines, like `@foreach`, are not Dox tags. Dox prints them as text, and writes one warning to stderr:

```
dox_view: warning: posts/index:12 "@foreach" is not a Dox tag. Use "@each(item in items) ... @end".
```

| Other name | Dox |
| --- | --- |
| `{!! html !!}` | `{{{ html }}}` |
| `@foreach`, `@forelse`, `@for` | `@each(item in items) ... @else ... @end` |
| `@endif`, `@endforeach`, `@endsection` and the other `@end...` names, `@stop` | `@end` |
| `@switch` | `@if ... @elseif ... @else ... @end` |
| `@php`, `@endphp` | `@let(name = value)` |
| `@show` | `@end`, then `@yield('name')` |
| `@parent` | not there. Use `@stack` and `@push` to add content. |

`ViewConfig(bladeWarnings: false)` turns the warnings off.

## Errors

A syntax error, or an error in an expression, throws a `ViewException` with the template name and the line:

```
ViewException: expected ")" but found the end (in "users/show", line 12)
```

## Prettier

Prettier does not know the `@` tags. Add this line to `.prettierignore`:

```
*.dox.html
```

## Testing

Render templates from a map, with no files:

```dart
ViewEngine engine = ViewEngine(MemoryTemplateLoader(<String, String>{
  'hello': 'Hello {{ name }}',
}));

engine.render('hello', <String, Object?>{'name': 'Ann'}); // Hello Ann
```

## Next steps

- [Inertia](inertia.md): pages with React, Vue or Svelte.
- [Mail](../digging-deeper/mail.md): use a view as a mail template.
