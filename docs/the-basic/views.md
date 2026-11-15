---
icon: lucide/layout-template
---

# Views

Views are HTML templates that Dox fills with your data and sends as the response.

Writing HTML in a controller gets messy fast. A view keeps the HTML in its own file, so the controller only gives the data. The `dox_view` package has the template engine. Templates are `.dox.html` files in `resources/views`.

## Install

Add the package with the CLI:

```bash
dox add view
```

It adds the package, the provider, the `resources/views` folder and a sample view. It never overwrites a file, so it is safe to run twice.

### Set it up by hand

If you do not use `dox add`, add the package yourself:

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

To make a view file, run `dox make:view emails/welcome`. It writes `resources/views/emails/welcome.dox.html`. See [`dox make:view`](../reference/cli.md#dox-makeview).

## Rendering views

`view()` renders a template and sends it as HTML. Leave out the `.dox.html` extension:

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

If you need the HTML as a string, for example for an email, use `View.render()`:

```dart
String html = View.render('emails/welcome', <String, dynamic>{'name': 'Ann'});
```

## Displaying data

`{{ }}` prints a value. It escapes HTML, so a user can not add a `<script>` tag to your page:

```html
<p>Hello {{ user.name }}</p>
```

`{{{ }}}` prints a value with no escape. Use it only for HTML you trust:

```html
<article>{{{ post.html }}}</article>
```

`null` prints nothing, and a variable that does not exist prints nothing too. `true` prints `true`, `false` prints `false`, and `10.0` prints `10.0`. The `bladeOutput` and `strictVariables` options change this. See [Strict options](#strict-options).

### Comments

A comment is not in the output:

```html
{{-- only you see this --}}
```

To print `{{` or a tag as text, put `@` before it: `@{{ name }}` prints `{{ name }}`, and `@@if` prints `@if`.

### Stay safe

`{{ }}` escapes HTML, but it does not make every place in a page safe. Follow these three rules:

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

Inside `{{ }}` and tags, you can use these expressions:

| What | Example |
| --- | --- |
| Values | `'text'`, `"text"`, `42`, `1.5`, `true`, `false`, `null` |
| Lists and maps | `[1, 2]`, `{ name: 'Ann', 'full name': 'Ann Lee' }` |
| Fields | `user.name`, `user?.name`, `items[0]`, `map['key']` |
| Math | `+`, `-`, `*`, `/`, `%`, `~/` |
| Compare | `==`, `!=`, `<`, `<=`, `>`, `>=` (`===` and `!==` work too) |
| Logic | `&&`, `\|\|`, `!`, `a ?? b`, `a ? b : c` |
| Functions | `route('users.show', { id: 5 })`, `name.toUpperCase()` |

`+` joins text: `{{ 'Hi ' + name }}`. Fields work on maps, and on objects with a `toJson()` method, like Dox models.

Some methods work too:

- Lists, maps and text have `length`, `isEmpty` and `isNotEmpty`.
- Lists also have `first`, `last`, `contains()`, `join()` and `indexOf()`.
- Text has `toUpperCase()`, `toLowerCase()`, `trim()`, `contains()`, `startsWith()`, `endsWith()`, `split()`, `replaceAll()`, `substring()` and `indexOf()`.
- Numbers have `toStringAsFixed()`, `round()`, `floor()`, `ceil()` and `abs()`.

In `@if` and `?:`, these values are false: `null`, `false`, `0`, `''`, an empty list and an empty map. With the `stringZeroIsFalse` option, the text `'0'` is false too. See [Strict options](#strict-options).

## Conditions

Use `@if`, `@elseif` and `@else` to show a part only in some cases. Close it with `@end`:

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

A tag can not come right after a letter or a digit, so `me@mail.com` stays text. Put a space before the tag, or use `{{ on ? 'active' : '' }}`.

## Loops

Use `@each` to print a list. The `@else` part shows when the list is empty:

```html
<ul>
  @each(user in users)
    <li>{{ user.name }}</li>
  @else
    <li>No users yet</li>
  @end
</ul>
```

If you need the index too, or the key of a map, use two names:

```html
@each((user, index) in users)
  {{ index + 1 }}. {{ user.name }}
@end

@each((value, key) in settings)
  {{ key }}: {{ value }}
@end
```

### The loop variable

`$loop` tells you where the loop is. For example, to put a comma after every item but the last:

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

In a loop inside a loop, `$loop.parent` reads the outer loop:

```html
@each(row in rows)
  @each(cell in row)
    <td class="{{ $loop.parent.odd ? 'light' : 'dark' }}">{{ cell }}</td>
  @end
@end
```

## Variables

`@let` makes a variable, and `@assign` changes it:

```html
@let(total = 0)
@each(item in cart)
  @assign(total = total + item.price)
@end
Total: {{ total }}
```

## Partials

Some parts are the same on many pages, like a nav bar. `@include` puts another template in this one, and it sees the same variables:

```html
@include('partials/nav')
```

To give it more variables, pass a map as the second argument:

```html
@include('partials/card', { title: 'Profile', user: post.author })
```

On the same name, the map wins. The map is only for this include, so the page does not see it after the include.

To include a template only when a condition is true, use `@includeIf` or `@includeWhen`. The two tags do the same. The condition is the first argument, the template name is the second, and the map is the third:

```html
@includeIf(user, 'partials/account')
@includeWhen(user.isAdmin, 'partials/admin', { level: 2 })
```

## More tags

Dox has more tags for common cases. Close a block tag with `@end`. `@else` works in all of them, but not in `@once` and `@verbatim`.

| Tag | What it does |
| --- | --- |
| `@isset(user.phone) ... @end` | shows when the value is not `null`. A field of `null` is not an error here. |
| `@empty(items) ... @end` | shows when the value is false: `null`, `false`, `0`, `''`, an empty list or map. With `stringZeroIsFalse`, `'0'` too. |
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

Put `@auth`, `@guest`, `@production`, `@once` and `@verbatim` alone on their line. In the middle of text, like `@once upon a time`, they stay text.

### Auth

`@auth` shows its body when the user is logged in, and `@guest` when not:

```html
@auth
  <a href="/logout">Log out</a>
@else
  <a href="/login">Log in</a>
@end
```

They use the `req.auth` that `view()` gets. In `View.render` there is no request, so `@guest` shows.

### Verbatim

Some JavaScript frameworks also use `{{ }}`. `@verbatim` prints its text as it is, so Dox does not run it. It ends at the first `@end`, so the text inside can not have `@end`:

```html
@verbatim
  <div id="app">{{ message }}</div>
@end
```

### Attributes from conditions

These tags print an HTML attribute when a condition is true:

```html
<a @class(['link', { active: isActive, muted: !isActive }])>Home</a>
<input type="checkbox" name="news" @checked(user.news)>
<option value="en" @selected(lang == 'en')>English</option>
<button @disabled(saving)>Save</button>
```

`@class` takes text, a map of class name to a condition, or a list of these. It prints `class="..."` with the names whose condition is true. `@checked`, `@selected` and `@disabled` print the attribute name when the value is true.

## Layouts and components

A component is a template with its own props and slots. You can use one for the page layout, so every page has the same head and header:

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

A page then puts its content in the component:

```html title="resources/views/home.dox.html"
@component('layouts/main', { title: 'Home' })
  @slot('header')
    <h1>Welcome</h1>
  @end

  <p>Hello {{ user.name }}</p>
@end
```

- The second argument is the props. In the component they are variables (`title`), and also `$props.title`.
- `@slot('name') ... @end` fills a named slot. Everything else goes into `$slots.main`. `$slot` is the same as `$slots.main`.
- A slot is HTML, so `{{ }}` does not escape it again.
- A component does not see the variables of the page. It only sees its props, `$props`, `$slots`, `$slot`, `$attributes`, the globals and the request helpers of `view()` (see [Forms](#forms)).

`@!component(...)` is a component with no body and no `@end`.

### Components as tags

A template in `resources/views/components/` is also a tag with its name. A `.` in the tag is a folder:

```html title="resources/views/components/button.dox.html"
<button class="btn btn-{{ type ?? 'primary' }}">{{ $slots.main }}</button>
```

Then use the tag:

```html
@button({ type: 'danger' })
  Delete
@end

@!form.input({ name: 'email' })   {{-- components/form/input.dox.html --}}
```

### Attributes

Often a component should pass its props on as HTML attributes, like `id` or `type`. `$attributes` has the props as HTML attributes, and `{{ $attributes }}` prints them, like `id="save" title="Save"`. The values are escaped.

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

A page can also name its layout with `@extends`. The page fills sections, and the layout prints them with `@yield`:

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
- `@section('name') ... @end` fills a section. The short form `@section('title', 'Home')` takes a value, which is escaped like `{{ }}`.
- `@yield('title', 'My app')` prints the second value when the page has no such section.
- Only the sections reach the layout. Text outside a section is not printed.
- A section and the layout both see the variables of the page.
- A layout can extend another layout. When a page and its layout fill the same section, the page wins.

Use `@extends` for the page layout. Use a component when you need props or more than one copy on a page.

## Stacks

Sometimes a page or a component needs its own script or style in the layout's `<head>`. A stack collects HTML from many templates and prints it in one place. The layout prints the stack with `@stack`:

```html
<head>
  @stack('styles')
</head>
<body>
  @yield('content')
  @stack('scripts')
</body>
```

A page or a component adds to it with `@push`:

```html
@push('scripts')
  <script src="/js/chart.js"></script>
@end
```

`@push` adds to the end of the stack, and `@prepend` adds to the start. A push works from the page, its layout, an `@include` and a component. `@stack` can come before the `@push`, and it still prints every push.

Put `@once` inside `@push` in a component, so the script is added one time only.

## Forms

Forms need a CSRF token, the old input and the validation errors. With `SessionMiddleware`, `view()` adds these to every template:

| Name | What it is |
| --- | --- |
| `csrfField()` | the hidden `_token` field for `CsrfMiddleware`. `@csrf` prints the same. |
| `csrfToken()` | the CSRF token |
| `errors` | the flashed validation errors, like `errors.email` |
| `old('email')` | the input of the request before |
| `session('key')` | a value from the session |

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

### Validation errors

`@error('field') ... @end` shows its body when `errors` has a message for the field. Inside the body, `message` is that message. With no error for the field, the `@else` part is printed instead, if there is one.

A name with dots, like `@error('user.email')`, works for nested fields. The name can also be a variable, like `@error(name)` in an input component.

### CSRF and method fields

`@csrf` prints the same hidden field as `csrfField()`. Put it alone on its line.

A browser form can only send GET and POST. For a PUT, PATCH or DELETE route, send a POST and add `@method`. It prints the hidden `_method` field that the [`MethodOverride`](routing.md#forms-with-put-patch-and-delete) middleware reads:

```html
<form method="POST" action="/posts/{{ post.id }}">
  @csrf
  @method('PUT')
  <input name="title" value="{{ post.title }}">
  <button>Save</button>
</form>
```

This prints `<input type="hidden" name="_token" value="...">` and `<input type="hidden" name="_method" value="PUT">`.

Every template from `view()` also has `request.path`, `request.method` and `request.query`. Components and layouts see all of these too, so a layout can use `request.path` and a form component can use `csrfField()`.

## Globals

Some values are needed in every template, like the app name. Globals are variables and functions that every template can use. `route()` is there by default:

```dart
const ViewConfig(globals: <String, Object?>{'appName': 'My app'});

View.global('year', DateTime.now().year);
View.global('money', (num cents) => (cents / 100).toStringAsFixed(2));
```

Then use them in any template:

```html
<footer>{{ appName }} {{ year }}</footer>
<a href="{{ route('users.show', { id: user.id }) }}">Profile</a>
<p>{{ money(order.total) }}</p>
```

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

If a global holds HTML, make it a `SafeString`. It is printed with no escape:

```dart
View.global('logo', const SafeString('<img src="/logo.svg" alt="Logo">'));
```

## JSON for JavaScript

Sometimes your JavaScript needs data from the server. `@json(value)` prints a value as JSON:

```html
<script>
  const user = @json(user);
</script>

<div data-tags='@json(tags)'></div>
```

Maps, lists, text, numbers, `true`, `false` and `null` work. An object with a `toJson()` method works too, like a Dox model.

The output is safe in two places: inside a `<script>` block, and inside an attribute in single quotes. Do not put it in an attribute in double quotes, because JSON has `"` in it, and that ends the attribute.

`json(value)` does the same as a function. Use it where you need an expression:

```html
@!chart({ points: json(points) })
```

In Dart, `SafeString.json(value)` gives the same text.

## Your own tags

If you print the same thing in many places, like a date format, you can add your own tag. A directive is a tag that your app adds. Write a class with a `render` method. It gets the values between `(` and `)`, and gives the text to print:

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

Then use it in a template:

```html
<time>@datetime(post.createdAt)</time>
```

The text is escaped, like `{{ }}`. Give a `SafeString` to print HTML as it is. `scope.lookup('name')` reads a variable of the template. A directive has no body and no `@end`.

Each isolate has its own engine. So add directives in your provider, after `super.setup()`, like globals. You can also give them in the config: `ViewConfig(directives: <String, ViewDirective>{'datetime': DateTimeDirective()})`.

## Config

Set the options in `ViewConfig`:

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
| `bladeWarnings` | `true` | warn about tag names from other template engines that are not Dox tags. See [Unknown tag warnings](#unknown-tag-warnings). |

With the cache off, a changed template shows on the next request, with no restart.

## Strict options

These three options are off by default. Turn each one on in `ViewConfig`:

```dart
const ViewConfig(
  strictVariables: true,
  stringZeroIsFalse: true,
  bladeOutput: true,
);
```

**`strictVariables`**: a variable that does not exist throws a `ViewException`. The message has the name of the variable, the template and the line. So a typo like `{{ titel }}` shows as an error, not as an empty spot on the page. When it is off, a variable that does not exist prints nothing.

A variable that is there with the value `null` is fine. These ways to read a variable that may not exist never throw:

| Code | What it gives when `user` does not exist |
| --- | --- |
| `@isset(user) ... @end` | the body is not printed |
| `@empty(user) ... @end` | the body is printed |
| `{{ user ?? 'Guest' }}` | `Guest` |
| `{{ user?.name }}` | nothing |

The rule covers the variable on the left of `??` and `?.`. In `{{ a ?? b ?? 'x' }}`, both `a` and `b` can be missing. `{{ user.name ?? 'Guest' }}` still throws when `user` does not exist: write `{{ user?.name ?? 'Guest' }}`.

**`stringZeroIsFalse`**: the text `'0'` is false in `@if`, `@unless`, `@empty`, `?:`, `&&`, `||`, `!`, `@class`, `@checked`, `@selected`, `@disabled`, `@includeIf` and `@includeWhen`. Other text, like `'0.0'` or `'00'`, is still true. When it is off, `'0'` is true, like any text that is not empty.

**`bladeOutput`**: `{{ }}` and `{{{ }}}` print `true` as `1`, `false` as nothing, and a number with no fraction, like `10.0`, as `10`. The values of `@yield`, `@section` and `@method`, and the numbers in `$attributes`, are printed the same way. Joining text with `+` does not change: `{{ 'a' + true }}` is still `atrue`. When it is off, `true` prints `true`, `false` prints `false`, and `10.0` prints `10.0`.

## Unknown tag warnings

Some tag names from other template engines, like `@foreach`, are not Dox tags. Dox prints them as plain text. To help you find them, Dox writes a warning to `stderr` when it reads a template that has one:

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

The output of the template does not change. The warning is only a hint, and each one is written one time. `ViewConfig(bladeWarnings: false)` turns the warnings off.

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

## Details

This section is for special cases. Most apps do not need it.

### When a tag is text

- A tag can not come right after a letter or a digit. Write `on @else off`, not `on@else off`. `L@yield('s')` also stays text.
- `@extends`, `@section`, `@yield`, `@stack`, `@push`, `@prepend`, `@method`, `@error`, `@json`, `@includeWhen` and your own directives need `( )`. With no `( )`, like `@section` in a sentence, they stay text.
- With no space before the `(`, like `@empty(items)` or `@json(user)`, a tag is always a tag.
- With a space before the `(`, in the middle of a line, it is a tag only when its args are one valid expression (one or two for `@section` and `@yield`). So `see @class (see docs)` stays text.
- With a space, alone on its line, it is a tag even when its args are not valid, unless a rule below says it stays text. Then the args give an error.
- A tag with a body, like `@isset`, `@empty`, `@env`, `@section` and `@push`, also needs its own `@end` after it. The `@end` of a block around it does not count. So `@empty (none)` stays text, also alone on its line.
- `@extends`, `@section`, `@yield`, `@stack`, `@push`, `@prepend`, `@method` and `@error` with a space also need text in quotes as the first argument. So `git @push (force)` stays text, but `@yield ('title')` is a tag. If such a tag stays text, its `@end` gives the error "@end has no matching tag before it".
- `@json` and `@includeWhen` are never tags with a space. So `the @json (format)` stays text.
- When `resources/views/components/` has a template with the same name as a tag or a directive, like `class.dox.html`, the component wins.

### Partials, loops and components

- `@include` with a second argument that is not a map throws a `ViewException`.
- A loop in an `@include` counts the loop around the `@include` as its parent. A loop in a component starts at depth 1.
- `$slot` and `$slots.main` are always there. They are empty when the component has no body.
- In `$attributes`, a number prints like `{{ }}`: `1.0` is `title="1.0"`, or `title="1"` with `bladeOutput`.

### Sections and stacks

- In a page with `@extends`, `@let` and `@push` outside a section still work. The `@yield` default value is escaped too.
- The names of sections and stacks must be plain text in quotes, like `'title'`.
- The first `@section` with a name wins. So a `@section` inside `@each` keeps only the first round.
- A `@yield('s')` that comes before the `@section('s')` in the same file prints nothing.
- An `@include` or a component with its own `@extends` prints its layout in place. It shares the section names with the page.
- The pushes are printed in the order they run. A page with `@extends` runs before its layout.

### Forms

- If your app has a global named `errors`, the global shows when the request has no validation errors. When there are validation errors, they win over the global.
- When the value in `errors` is a list, `message` is its first item.
- With no session, and in `View.render`, there are no errors, so the `@error` body is not printed. It does not throw. With no session, `@csrf` throws a `ViewException`.
- `@error('user.email')` reads the key `'user.email'` of `errors` first. That is how the validator names a nested field. When there is no such key, it reads `email` inside `user`.
- `message` is only there inside the `@error` body. After `@end`, a `message` variable of your page has its own value again.

### Globals, JSON and directives

- You can add globals before or after `View.configure()`. The engine keeps them. When a name is in both, the value in `ViewConfig.globals` wins.
- `@json` writes `<`, `>`, `&`, `'` and the line separators U+2028 and U+2029 as `\uXXXX`, so a value can not close the `<script>` block or the attribute. A value that can not be JSON, like a `DateTime` or an object with no `toJson()`, throws a `ViewException`. `{{ json(value) }}` does not escape the text again.
- A directive that returns `null` prints nothing. Its name can have letters, digits and `_`. The name of a built-in tag, like `if`, `section` or `json`, throws a `ViewException`.

### Which names warn

- `@end...` names warn anywhere in a line. The other names warn only with the `(` right after the name, like `@foreach(...)`, or alone on their line. So a sentence like `the @foreach loop` does not warn.
- Text in a `{{-- --}}` comment, in `@verbatim`, and a name with `@@` before it, do not warn. A name in an HTML comment, like `<!-- @endif -->`, does warn.
