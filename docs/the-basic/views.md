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

`null`, and a variable that does not exist, print nothing. `true` prints `true`, `false` prints `false`, and `10.0` prints `10.0`. You can change this with the `strictVariables` and `bladeOutput` options. See [Strict options](#strict-options).

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
- **`<script>` and `<style>` are not safe for `{{ }}`.** Inside them, `{{ }}` only escapes HTML.
  It does not make a value safe for JavaScript or CSS.
  Do not print user data there with `{{ }}`. In a `<script>`, use `@json`. See [JSON for JavaScript](#json-for-javascript).
  Or put the value in a quoted `data-` attribute, and read it in your script.

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

In `@if` and `?:`, these values are false: `null`, `false`, `0`, `''`, an empty list and an empty map. The text `'0'` is true. The `stringZeroIsFalse` option makes it false. See [Strict options](#strict-options).

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
| `$loop.even` | true when `iteration` is even: the 2nd, 4th, ... round |
| `$loop.odd` | true when `iteration` is odd: the 1st, 3rd, ... round |
| `$loop.depth` | 1 for a loop, 2 for a loop inside a loop |
| `$loop.parent` | the `$loop` of the loop around this one. `null` when there is none. |

```html
@each(row in rows)
  @each(cell in row)
    <td class="{{ $loop.parent.odd ? 'light' : 'dark' }}">{{ cell }}</td>
  @end
@end
```

A loop in an `@include` counts the loop around the `@include` as its parent. A loop in a component starts at depth 1.

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
```

A map as the second argument gives more variables to the template:

```html
@include('partials/card', { title: 'Profile', user: post.author })
```

- The template sees the variables of the page and the map. On the same name, the map wins.
- The map is only for this include. The page does not see it after the include.
- A second argument that is not a map throws a `ViewException`.

`@includeIf` and `@includeWhen` include the template only when the condition is true. The two tags do the same. The condition is the first argument, the template name is the second, and the map is the third:

```html
@includeIf(user, 'partials/account')
@includeWhen(user.isAdmin, 'partials/admin', { level: 2 })
```

## More tags

Close a block tag with `@end`. `@else` works in all of them, but not in `@once` and `@verbatim`.

Put `@auth`, `@guest`, `@production`, `@once` and `@verbatim` alone on their line. In the middle of text, like `@once upon a time`, they stay text.

With a space before the `(`, in the middle of a line, a tag is used only when its args are a valid expression. A tag with a body, like `@isset`, `@empty`, `@env`, `@section` and `@push`, also needs an `@end` after it. So text like `@empty (none)` or `@class (see docs)` stays text. With no space, like `@empty(items)`, a tag is always a tag. Alone on its line, a tag is also always a tag, with two exceptions:

- `@extends`, `@section`, `@yield`, `@stack`, `@push`, `@prepend`, `@method` and `@error`. With a space before the `(`, these eight are tags only when the first argument is text in quotes, like `@yield ('title')`. This holds on any line. So text like `git @push (force)` or `an @error (see log)` stays text.
- `@json` and `@includeWhen`. They are tags only with the `(` right after the name, like `@json(user)`. With a space, like `the @json (format)`, they stay text.

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
| `@error('email') ... @end` | shows when the field has a validation error. See [Forms](#forms). |
| `@json(value)` | the value as JSON. See [JSON for JavaScript](#json-for-javascript). |
| `@includeWhen(condition, 'name')` | includes a template when the condition is true. See [Partials](#partials). |
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

`@extends`, `@section`, `@yield`, `@stack`, `@push`, `@prepend`, `@method`, `@error`, `@json` and `@includeWhen` need `( )`. With no `( )`, like `@section` in a sentence, they stay text. For a space before the `(`, see the rule in [More tags](#more-tags).

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
  @error('email')
    <p class="error">{{ message }}</p>
  @end
  <button>Register</button>
</form>
```

`@error('field') ... @end` shows its body when `errors` has a message for the field. Inside the body, `message` is that message.

- When the value in `errors` is a list, `message` is its first item.
- With no error for the field, the body is not printed. An `@else` part is printed instead, when there is one.
- With no session, and in `View.render`, there are no errors, so the body is not printed. It does not throw.
- A name with dots, like `@error('user.email')`, reads the key `'user.email'` of `errors` first. That is how the validator names a nested field. When there is no such key, it reads `email` inside `user`.
- The name can be a variable, like `@error(name)` in an input component.
- `message` is only there inside the body. After `@end`, a `message` variable of your page has its own value again.

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

## JSON for JavaScript

`@json(value)` prints a value as JSON. Use it to give data to JavaScript:

```html
<script>
  const user = @json(user);
</script>

<div data-tags='@json(tags)'></div>
```

- Maps, lists, text, numbers, `true`, `false` and `null` work. An object with a `toJson()` method works too, like a Dox model.
- `<`, `>`, `&`, `'` and the line separators U+2028 and U+2029 are written as `\uXXXX`. So a value can not close the `<script>` block or the attribute.
- The output is safe in two places: inside a `<script>` block, and inside an attribute in single quotes. Do not put it in an attribute in double quotes: JSON has `"` in it, and that ends the attribute.
- A value that can not be JSON, like a `DateTime` or an object with no `toJson()`, throws a `ViewException`.

`json(value)` is the same as a function. `{{ json(value) }}` prints the same text, and does not escape it again. Use it where you need an expression:

```html
@!chart({ points: json(points) })
```

In Dart, `SafeString.json(value)` gives the same text.

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
- The name can have letters, digits and `_`. The name of a built-in tag, like `if`, `section` or `json`, throws a `ViewException`.
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
| `strictVariables` | `false` | a variable that does not exist throws a `ViewException`. See [Strict options](#strict-options). |
| `stringZeroIsFalse` | `false` | the text `'0'` is false in a condition |
| `bladeOutput` | `false` | print `true` as `1`, `false` as nothing and `10.0` as `10` |
| `bladeWarnings` | `true` | warn about Blade names that are not Dox tags. See [Coming from Blade](#coming-from-blade). |

With the cache off, a changed template shows on the next request, with no restart.

## Strict options

These three options are off by default. Turn them on in `ViewConfig`:

```dart
const ViewConfig(
  strictVariables: true,
  stringZeroIsFalse: true,
  bladeOutput: true,
);
```

**`strictVariables`**: a variable that does not exist throws a `ViewException`. The message has the name of the variable, the template and the line. So a typo like `{{ usr.name }}` shows as an error, not as an empty page.

A variable that is there with the value `null` is fine. These ways to read a variable that may not exist never throw:

| Code | What it gives when `user` does not exist |
| --- | --- |
| `@isset(user) ... @end` | the body is not printed |
| `@empty(user) ... @end` | the body is printed |
| `{{ user ?? 'Guest' }}` | `Guest` |
| `{{ user?.name }}` | nothing |

The rule covers the variable on the left of `??` and `?.`. In `{{ a ?? b ?? 'x' }}`, both `a` and `b` can be missing. `{{ user.name ?? 'Guest' }}` still throws when `user` does not exist: write `{{ user?.name ?? 'Guest' }}`.

**`stringZeroIsFalse`**: the text `'0'` is false in `@if`, `@unless`, `@empty`, `?:`, `&&`, `||`, `!`, `@class`, `@checked`, `@selected`, `@disabled`, `@includeIf` and `@includeWhen`. Other text, like `'0.0'` or `'00'`, is still true.

**`bladeOutput`**: `{{ }}` and `{{{ }}}` print `true` as `1`, `false` as nothing, and a number with no fraction, like `10.0`, as `10`. The values of `@yield`, `@section` and `@method` are printed the same way. Joining text with `+` does not change: `{{ 'a' + true }}` is still `atrue`.

## Coming from Blade

Some Blade names are not Dox tags. Dox prints them as plain text. To help you find them, Dox writes a warning to `stderr` when it reads a template that has one:

```
dox_view: warning: posts/index:12 "@foreach" is not a Dox tag. Use "@each(item in items) ... @end".
```

| Blade | Dox |
| --- | --- |
| `{!! html !!}` | `{{{ html }}}` |
| `@foreach`, `@forelse`, `@for` | `@each(item in items) ... @else ... @end` |
| `@endif`, `@endforeach`, `@endsection` and the other `@end...` names, `@stop` | `@end` |
| `@switch` | `@if ... @elseif ... @else ... @end` |
| `@php`, `@endphp` | `@let(name = value)` |
| `@show` | `@end`, then `@yield('name')` |
| `@parent` | not there. Use `@stack` and `@push` to add content. |

- The output of the template does not change. The warning is only a hint.
- Each warning is written one time.
- `@end...` names warn anywhere in a line. The other names warn only with the `(` right after the name, like `@foreach(...)`, or alone on their line. So a sentence like `the @foreach loop` does not warn.
- Text in a `{{-- --}}` comment, in `@verbatim`, and a name with `@@` before it, do not warn. A name in an HTML comment, like `<!-- @endif -->`, does warn.
- `ViewConfig(bladeWarnings: false)` turns the warnings off.

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
