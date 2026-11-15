---
icon: lucide/mail
---

# Mail

The `dox_mailer` package sends email from your app with SMTP, Amazon SES, Azure, Resend, Mailgun, Postmark or sendmail.

You write a `Message` and call `Mail.send()`, and a transport sends it. You pick the transport in a config file, so you can change providers with no code change. Slow emails can go through the [queue](queue.md), so the request does not wait.

## Install

Add the package with the `dox` CLI. Add `--transport=smtp` (or `resend`, `mailgun`, `postmark`, `ses`) to pick a transport. `log` is the default:

```bash
dox add mailer
```

It adds the package, writes the mail config and the provider, and adds `MAIL_MAILER`, `MAIL_FROM` and the keys of the transport to `.env`. If the app has `dox_view`, it also makes the `resources/views/emails` folder. It never overwrites a file, so it is safe to run twice.

If you want to set it up by hand, add the package and write the two files below yourself:

```bash
dart pub add dox_mailer
```

## Setup

### Configuration

A mailer is a name and a transport. `defaultMailer` is the one that `Mail.send()` uses:

```dart title="lib/config/mail.dart"
import 'package:dox_core/dox_core.dart';
import 'package:dox_mailer/dox_mailer.dart';

MailConfig mailConfig = MailConfig(
  /// the mailer of Mail.send()
  defaultMailer: Env.get('MAIL_MAILER', 'log'),

  /// for messages with no from address
  from: Address(Env.get('MAIL_FROM', 'hello@example.com'), 'My app'),

  mailers: <String, Transport>{
    'smtp': SmtpTransport(
      host: Env.get('MAIL_HOST', 'localhost'),
      port: Env.get<int>('MAIL_PORT', 587),
      username: Env.get<String?>('MAIL_USERNAME'),
      password: Env.get<String?>('MAIL_PASSWORD'),
    ),

    /// prints emails, sends nothing
    'log': LogTransport(),
  },
);
```

`Env.get()` reads the `.env` file and the real environment. You can also add the keys to the `AppEnv` class of your app and use `env.mailHost`.

```bash title=".env"
MAIL_MAILER=smtp
MAIL_FROM=hello@example.com
MAIL_HOST=smtp.example.com
MAIL_PORT=587
MAIL_USERNAME=me
MAIL_PASSWORD=secret
```

| Option | Default | What it does |
| --- | --- | --- |
| `defaultMailer` | `log` | the mailer of `Mail.send()` |
| `mailers` | a `log` mailer | each mailer name and its transport |
| `from` | none | the from address of a message that has none |
| `replyTo` | none | the reply-to addresses of a message that has none |

### The mail provider

The provider sets up the mailers in every isolate. Put it in `lib/providers/`, so the generated container finds it:

```dart title="lib/providers/mail_provider.dart"
import 'package:dox_mailer/dox_mailer.dart';

import '../config/mail.dart';

/// Sets up the mailers. Dox finds every DoxProvider class,
/// see lib/generated/container.g.dart.
class AppMailProvider extends MailProvider {
  AppMailProvider() : super(mailConfig);
}
```

When the server stops, the provider closes open SMTP connections and HTTP clients.

## Sending mail

Make a `Message` and pass it to `Mail.send()`:

```dart
import 'package:dox_mailer/dox_mailer.dart';

await Mail.send(
  Message(
    to: <Address>[Address('ann@example.com', 'Ann Lee')],
    subject: 'Welcome',
    text: 'Hello Ann, welcome!',
    html: '<p>Hello Ann, <b>welcome</b>!</p>',
  ),
);
```

A message needs a from address, at least one recipient, and a text or HTML body. If the message can not be sent, `send()` throws a `MailException`. It has the `statusCode` and the `body` of the server's answer.

### Using another mailer

If you want to send with a mailer that is not the default, use `Mail.mailer()`:

```dart
await Mail.mailer('ses').send(message);
```

### Short ways to send

For a quick plain text email, use `Mail.raw()`:

```dart
await Mail.raw('Your code is 1234', to: 'ann@example.com', subject: 'Your code');
```

`Mail.to()` starts an email with chained calls. `to()`, `cc()` and `bcc()` take an `Address`, an email text, or a list of these. `send()` takes a [mailable](#mailables), and the recipients are added to the ones of the mailable:

```dart
await Mail.to('ann@example.com')
    .cc('Bob Lee <bob@example.com>')
    .bcc(<String>['audit@example.com'])
    .send(WelcomeMail(user));
```

`queue()` and `later()` work here too, like `Mail.to(email).queue(WelcomeMail(user))`.

### The message

| Field | What it is |
| --- | --- |
| `from` | an `Address`. Null: `MailConfig.from` |
| `to`, `cc`, `bcc` | lists of `Address` |
| `replyTo` | a list of `Address` |
| `subject` | text |
| `text` | the plain text body |
| `html` | the HTML body |
| `attachments` | a list of `Attachment` |
| `headers` | extra headers, like `{'X-Campaign': 'fall'}` |
| `tags` | tags for the reports of the provider |
| `metadata` | key and value data for the provider, like `{'user_id': '42'}` |

An `Address` is an email and an optional name. You can also read one from text:

```dart
Address('ann@example.com', 'Ann');
Address.parse('Ann <ann@example.com>');
```

`Address.list()` reads many addresses. One text is one address, so pass a list for more:

```dart
Message(to: Address.list(<String>['ann@example.com', 'bob@example.com']), ...)
```

### Attachments

Add files with `attachments`. The content type comes from the file extension, or you can pass `contentType`:

```dart
Message(
  to: <Address>[Address('ann@example.com')],
  subject: 'Your invoice',
  text: 'The invoice is attached.',
  attachments: <Attachment>[
    Attachment(pdfBytes, 'invoice.pdf'),
    Attachment.fromFile('storage/terms.pdf'),
  ],
);
```

To attach a file from a storage disk, like S3, read its bytes first. This works with every disk:

```dart
Uint8List? pdf = await Storage().disk('s3').get('invoices/42.pdf');
Attachment(pdf!, 'invoice.pdf');
```

### Inline images

To show an image inside the HTML, give the file a `cid` and use it with `cid:`:

```dart
Message(
  to: <Address>[Address('ann@example.com')],
  subject: 'Hello',
  html: '<img src="cid:logo.png"> Hello!',
  attachments: <Attachment>[
    Attachment.fromFile('assets/logo.png', cid: 'logo.png'),
  ],
);
```

Mailgun uses the file name as the cid. So for Mailgun, use a cid with the file extension, like `logo.png`.

### HTML from a view

With [views](../the-basic/views.md), you can render a template to HTML:

```dart
String html = View.render('emails/welcome', <String, dynamic>{'name': 'Ann'});
await Mail.send(Message(to: to, subject: 'Welcome', html: html));
```

## Mailables

A mailable is one kind of email in its own class, for example the welcome email. It keeps the address, the subject, the template and the data in one place.

To make one, run `dox make:mail`. It writes `lib/app/mail/welcome_mail.dart` and the view `resources/views/emails/welcome.dox.html`. Add `--no-view` for a mail with a plain text body. See [`dox make:mail`](../reference/cli.md#dox-makemail).

```bash
dox make:mail Welcome
```

Override the getters you need:

```dart
class WelcomeMail extends Mailable {
  WelcomeMail(this.user);

  final User user;

  @override
  List<Address> get to => <Address>[Address(user.email, user.name)];

  @override
  String get subject => 'Welcome';

  @override
  String? get view => 'emails/welcome';

  @override
  Map<String, Object?> get data => <String, Object?>{'name': user.name};
}
```

| Getter | What it is |
| --- | --- |
| `to`, `cc`, `bcc`, `replyTo` | the addresses |
| `from` | the sender. Null: the `from` of the mail config |
| `subject` | the subject |
| `html`, `text` | the body as text, when there is no template |
| `view` | a [dox_view](../the-basic/views.md) template for the HTML body |
| `textView` | a dox_view template for the plain text body |
| `markdown` | a dox_view template with Markdown, see [Markdown mail](#markdown-mail) |
| `data` | the variables of the templates |
| `attachments` | the files |
| `mailer` | the mailer name, eg. `ses`. Null: the default mailer |

### Sending a mailable

Call `send()` on the mailable, or put it on the queue with `queue()` or `later()`:

```dart
await WelcomeMail(user).send();
await WelcomeMail(user).queue();
await WelcomeMail(user).later(Duration(minutes: 10));
```

`queue()` and `later()` render the templates at once, so the worker sends the finished email. They take the same options as [`Mail.queue()`](#queue-an-email).

### Changing the message

`toMessage()` gives the email as a `Message`. If you want to set more, like headers or tags, override it:

```dart
@override
Message toMessage() {
  return super.toMessage().copyWith(tags: <String>['welcome']);
}
```

### Markdown mail

You can write the email in Markdown. From one template you get a simple HTML email with a layout (a white card on a grey page) and a plain text part. The Markdown is CommonMark with tables.

```markdown title="resources/views/emails/welcome.dox.html"
# Hi {{ name }}

Thanks for joining. Here is what you can do next:

- Fill in your profile
- Invite your team

[Open your profile]({{ profileUrl }})

<a href="https://example.com/dashboard" class="button">Open the app</a>
```

Then point the `markdown` getter to it:

```dart
@override
String? get markdown => 'emails/welcome';
```

`<a class="button">` shows as a button. In the text body it stays an `<a>` tag, so the link is still there.

Do not indent the Markdown inside `@if` or `@each`, because Markdown makes a line that starts with 4 spaces into a code block.

`{{ }}` escapes HTML and Markdown, so a user's name like `[click](https://evil.example)` shows as text and does not become a link. Links with an unsafe URL, like `javascript:`, lose their URL. Raw HTML in the template, like `<a href="{{ url }}">`, is not checked, so only put full URLs that your app builds there. For links, write `[text]({{ url }})` instead. To put Markdown from a value into the email, pass a `SafeString`.

### Custom layout

To use your own look, override `layout()`. It gets the HTML of the Markdown and returns the full page. Put it in a base class to use it for all your mailables:

```dart
import 'package:dox_mailer/dox_mailer.dart';
import 'package:dox_view/dox_view.dart'; // View, SafeString

abstract class AppMail extends Mailable {
  @override
  String layout(String body) {
    return View.render('emails/layout', <String, Object?>{'body': SafeString(body)});
  }
}
```

### A simple email with no template

Sometimes you only need a few lines and a button. `MailMessage` is a mailable for this. It needs no template and uses the Markdown layout:

```dart
await (MailMessage(subject: 'Invoice paid', to: <Address>[Address('ann@example.com')])
      ..line('We got your payment.')
      ..action('View invoice', 'https://example.com/invoices/1')
      ..line('Thank you!'))
    .send();
```

- `cc:` in the constructor adds cc addresses.
- `attach(Attachment(...))` adds a file.
- `error()` makes the buttons red, for a message about a problem.
- The email starts with `greeting` (default `Hello!`) and ends with `salutation` (default none). Set them to null to leave them out.

Lines can use Markdown, like `**bold**`. HTML in a line shows as text. `action()` throws an `ArgumentError` for an unsafe URL.

To send one email on more than one channel, see [Notifications](notifications.md).

## Queue an email

Sending an email can take a second or more. With a queue, the request does not wait, because a queue worker sends the email later:

```dart
await Mail.queue(message);
```

To send it later, use `Mail.later()`. Both methods return the job id:

```dart
await Mail.later(Duration(minutes: 10), message);
```

You can pick another mailer and another queue:

```dart
await Mail.mailer('ses').queue(message, queue: 'emails');
```

This uses [dox_queue](queue.md), so you need its `QueueProvider` and a worker. The mail jobs come with dox_mailer, and `build_runner` adds them to `lib/generated/jobs.g.dart`. The worker (`bin/queue.dart`) must run your `MailProvider` too, because the job sends with your mail config. Without it, the job fails with "Mail is not set up".

The message is checked at once, so a bad message fails in the request and not in the worker. The worker sends with the same mailer you picked.

| Option | Default | What it does |
| --- | --- | --- |
| `queue` | `default` | the queue name |
| `encrypt` | `false` | save the job data encrypted with the app key. The worker needs the same key |

The whole email, with every attachment, is saved in Redis or in the `jobs` table. So keep attachments small, a few MB at most. For a big file, write your own job that saves the file path, and build the email in `handle()`.

An email has personal data. If other people can read Redis or the `jobs` table, use `encrypt: true`.

## Transports

### SMTP

```dart
'smtp': SmtpTransport(
  host: 'smtp.example.com',
  port: 587,
  username: Env.get('MAIL_USERNAME'),
  password: Env.get('MAIL_PASSWORD'),
  encryption: SmtpEncryption.starttls,
),
```

| Option | Default | What it does |
| --- | --- | --- |
| `host` | required | the server |
| `port` | 465 for `tls`, 587 for `starttls`, 25 for `none` | the port |
| `username`, `password` | none | the login. No username: no login |
| `encryption` | `starttls` | `none`, `starttls` (switch to TLS after connect) or `tls` (TLS from the start) |
| `allowInsecure` | `false` | accept a self-signed TLS certificate. Only for test servers |
| `auth` | PLAIN, or LOGIN when the server has no PLAIN | `SmtpAuth.plain`, `SmtpAuth.login` or `SmtpAuth.xoauth2` |
| `localDomain` | `localhost` | the name of this machine, for `EHLO` |
| `timeout` | 30 seconds | the time to connect, and to wait for each reply |
| `keepAlive` | `false` | keep the connection open for the next message |

With `starttls`, the send fails if the server does not offer STARTTLS, so your password is never sent in plain text by mistake.

For Gmail or Outlook with OAuth 2, use `auth: SmtpAuth.xoauth2`. The `username` is the email and the `password` is the access token.

If you send many emails, use `keepAlive: true`, so one connection sends them one by one.

For local work, [Mailpit](https://mailpit.axllent.org) catches all emails:

```dart
'mailpit': SmtpTransport(
  host: 'localhost',
  port: 1025,
  encryption: SmtpEncryption.none,
),
```

### Amazon SES

There are two classes, and both send the same MIME message with attachments and inline images. `SesTransport` uses SES API v1 (`SendRawEmail`), and `SesV2Transport` uses SES API v2 (`SendEmail` with raw content):

```dart
'ses': SesV2Transport(
  key: Env.get('AWS_ACCESS_KEY_ID'),
  secret: Env.get('AWS_SECRET_ACCESS_KEY'),
  region: Env.get('AWS_REGION', 'us-east-1'),
),
```

| Option | Default | What it does |
| --- | --- | --- |
| `key` | required | the AWS access key id |
| `secret` | required | the AWS secret access key |
| `sessionToken` | none | for temporary keys, eg. from a role |
| `region` | `us-east-1` | the AWS region of SES |
| `configurationSet` | none | the SES configuration set, to track events |
| `endpoint` | `https://email.<region>.amazonaws.com/` | another API address |

No AWS SDK is needed.

### Azure Communication Services

```dart
'azure': AzureTransport(
  endpoint: 'https://my-app.europe.communication.azure.com',
  accessKey: Env.get('AZURE_EMAIL_KEY'),
),
```

Or use the connection string of the Azure portal:

```dart
'azure': AzureTransport.fromConnectionString(
  Env.get('AZURE_EMAIL_CONNECTION_STRING'),
),
```

| Option | Default | What it does |
| --- | --- | --- |
| `endpoint` | required | the address of your resource |
| `accessKey` | required | the access key of the resource |
| `apiVersion` | `2023-03-31` | the API version |
| `disableTracking` | `false` | turn off open and click tracking |

Inline images need a newer `apiVersion` that supports them.

### Resend

```dart
'resend': ResendTransport(apiKey: Env.get('RESEND_API_KEY')),
```

### Mailgun

```dart
'mailgun': MailgunTransport(
  apiKey: Env.get('MAILGUN_API_KEY'),
  domain: 'mg.example.com',
  region: MailgunRegion.eu,
),
```

`region` is `MailgunRegion.us` (the default) or `MailgunRegion.eu`. Use the region of your Mailgun domain.

### Postmark

```dart
'postmark': PostmarkTransport(
  serverToken: Env.get('POSTMARK_TOKEN'),
  messageStream: 'outbound',
),
```

`messageStream` is optional. Without it, Postmark uses the default stream of the server.

### sendmail

This sends with the `sendmail` program of the server (Postfix, Exim, msmtp and others):

```dart
'sendmail': SendmailTransport(
  path: '/usr/sbin/sendmail',
  mode: SendmailMode.smtp,
),
```

| Mode | Command | How it works |
| --- | --- | --- |
| `SendmailMode.smtp` (default) | `sendmail -bs` | speaks SMTP on stdin and stdout |
| `SendmailMode.pipe` | `sendmail -t -i` | pipes the message in. sendmail reads the recipients from the headers |

### Log

The log transport prints each email and sends nothing, so it is good for local work:

```dart
'log': LogTransport(),
```

Pass `output` to print somewhere else, eg. `LogTransport(output: stderr.writeln)` (from `dart:io`). To show both the text and the HTML body, set `bothBodies: true`. When it is off, only the text body is shown:

```dart
'log': LogTransport(bothBodies: true),
```

### Array

The array transport keeps each email in a list and sends nothing. See [Testing](#testing).

```dart
'array': ArrayTransport(),
```

### Failover

If one provider is down, you may want to try another. `FailoverTransport` tries each transport in order, until one sends the email. If every transport fails, it throws the error of the last one:

```dart
SesV2Transport ses = SesV2Transport(key: '...', secret: '...');
SmtpTransport smtp = SmtpTransport(host: 'smtp.example.com');

MailConfig mailConfig = MailConfig(
  defaultMailer: 'main',
  mailers: <String, Transport>{
    'main': FailoverTransport(<Transport>[ses, smtp]),
  },
);
```

To see why the first ones failed, pass `onError`. It gets the error of each transport that fails.

## Tags and metadata

Each provider has its own way to group and mark emails. This is what each transport does with `tags` and `metadata`:

| Transport | `tags` | `metadata` |
| --- | --- | --- |
| SES | not used | message tags |
| Resend | tags with the value `true` | tags |
| Mailgun | `o:tag` | variables (`v:name`) |
| Postmark | the first tag | metadata |
| Azure, SMTP, sendmail | not used | not used |

For SMTP and sendmail, use `headers` instead.

## Hooks

Sometimes you want to run code before or after each email is sent, for example to log it. Use `Mail.onSending` and `Mail.onSent`.

Each isolate has its own hooks, also the queue worker. So add them in `setup()` of your mail provider, after `super.setup()`. A hook added in `main()` does not reach queued emails.

```dart
class AppMailProvider extends MailProvider {
  AppMailProvider() : super(mailConfig);

  @override
  void setup() {
    super.setup();
    Mail.clearHooks(); // a second setup() does not add each hook twice
    Mail.onSending((Message message) {
      print('sending "${message.subject}" to ${message.to}');
    });
    Mail.onSent((SentMessage sent) {
      print('sent ${sent.messageId}');
    });
  }
}
```

Hooks run for every mailer, for queued emails and with `Mail.fake()`. If an `onSending` hook throws, the email is not sent and `send()` throws that error. If an `onSent` hook throws, the error is only logged, because the email is already sent.

## Sending all mail to one address

On a staging server, you want every email to go to your own inbox, so real users get nothing. Use `Mail.alwaysTo()`. Like hooks, call it in `setup()` of your mail provider, so every isolate gets it:

```dart
class AppMailProvider extends MailProvider {
  AppMailProvider() : super(mailConfig);

  @override
  void setup() {
    super.setup();
    if (Env.get<String>('APP_ENV') == 'staging') {
      Mail.alwaysTo('qa@example.com');
    }
  }
}
```

The `to` of each email becomes that address, and `cc` and `bcc` are cleared. This counts for queued emails too. `Mail.alwaysTo(null)` turns it off.

## Custom transports

If your provider is not in the list, extend `Transport` and add it to `mailers`:

```dart
class MyApiTransport extends Transport {
  @override
  Future<SentMessage> send(Message message) async {
    // call your API here
    return SentMessage(message, messageId: 'id from the API');
  }
}
```

The message is already checked, and has a from address, when it gets to `send()`. For a provider that takes raw MIME, `MimeBuilder().build(message)` gives the MIME text.

## Without Dox

`dox_mailer` also works on its own. Call `Mail.configure()` once at start, and `Mail.close()` at the end. The rest of this page works the same way:

```dart
import 'dart:io';

import 'package:dox_mailer/dox_mailer.dart';

Future<void> main() async {
  Map<String, String> env = Platform.environment;

  Mail.configure(MailConfig(
    defaultMailer: 'smtp',
    from: Address('hello@example.com', 'My app'),
    mailers: <String, Transport>{
      'smtp': SmtpTransport(
        host: env['MAIL_HOST'] ?? 'localhost',
        username: env['MAIL_USERNAME'],
        password: env['MAIL_PASSWORD'],
      ),
    },
  ));

  await Mail.send(Message(
    to: <Address>[Address('ann@example.com')],
    subject: 'Hello',
    text: 'Hello Ann!',
  ));

  // closes open SMTP connections and HTTP clients
  await Mail.close();
}
```

## Testing

`Mail.fake()` sends every mailer to one `ArrayTransport`, so nothing goes out. Then you check what was sent:

```dart
import 'package:dox_mailer/dox_mailer.dart';
import 'package:test/test.dart';

void main() {
  late ArrayTransport mail;

  setUp(() {
    mail = Mail.fake();
  });

  tearDown(() {
    Mail.restore();
  });

  test('sign up sends a welcome email', () async {
    await signUp('ann@example.com');

    expect(mail.messages, hasLength(1));
    Message message = mail.messages.single;
    expect(message.to.single.email, 'ann@example.com');
    expect(message.subject, 'Welcome');
  });
}
```

The fake works with or without a config, and it stays on when `MailProvider` sets up the config again.

### Testing queued mail

The fake also catches queued emails: `Mail.queue()`, `Mail.later()`, the `queue()` and `later()` of a mailable, and notifications with `shouldQueue`. They go to `mail.queued`, not to the job queue, so you need no queue setup:

```dart
await Mail.queue(message);

mail.assertQueued((Message m) => m.subject == 'Welcome');
mail.assertNothingSent();
```

Each item in `mail.queued` is a `QueuedMessage` with `mailer`, `message`, `id`, `delay`, `queue` and `encrypt`.

### Assertions

| Method | Checks |
|---|---|
| `assertSent([test])` | an email was sent. With `test`, one of them passes it |
| `assertSentCount(count, [test])` | exactly `count` emails were sent. With `test`, `count` emails pass it |
| `assertNotSent(test)` | no sent email passes `test` |
| `assertNothingSent()` | no email was sent |
| `assertQueued([test])` | an email was queued. With `test`, one of them passes it |
| `assertNotQueued(test)` | no queued email passes `test` |
| `assertNothingQueued()` | no email was queued |

`test` is a `bool Function(Message)`. A failed check throws a `StateError`. `mail.clear()` forgets the sent and the queued emails, and `Mail.restore()` stops the fake.

## Details

This section is for special cases. Most apps do not need it.

### Sending

- `send()` gives a `SentMessage`. Its `messageId` is the id of the provider, or the `Message-ID` header for SMTP and sendmail.
- A subject or header with a line break is an error, so user input can not add headers. `FailoverTransport` throws this `MailException` at once, and no transport tries it.
- In `FailoverTransport`, an error thrown by `onError` is ignored and the next transport is still tried. An `async` `onError` is not awaited.
- `{{ }}` in a template escapes HTML. In the plain text body of `textView` and `markdown`, the escape is undone, so `Tom & Jerry` stays `Tom & Jerry`.
- With `keepAlive: true`, if the server closed the connection, the next send opens a new one.
- SES requests are signed with AWS Signature Version 4. Azure requests are signed with the access key (HMAC-SHA256).
- The package has its own SMTP client, AWS signer and MIME builder.

### Markdown safety

- The escaped characters are backslash, backtick, `*`, `[`, `]`, `#` and `|`. A `_` is not changed, so `_word_` can still be italic. In `@if`, a value with one of these characters is not equal to the same text written in the template.
- Escaping covers text values in `data`, in its maps, lists and sets, and in objects with `toJson()`. Values from `View.global()` and from functions are not changed.
- Only `http`, `https`, `mailto`, `tel`, `cid` and relative URLs are kept. The same check runs on the lines of `MailMessage`. Email apps can not open a relative link like `/dashboard`, so use full URLs.
- `[text]({{ url }})` and `<{{ url }}>` keep the URL as it is, with `&` and `%XX`. Entity text inside a URL is decoded, so `?q=&lt;b&gt;` reaches the browser as `?q=<b>`.
- A bare URL does not become a link, but most email apps make it a link anyway.

### Queue

- The default from and reply-to addresses are added when the email is queued.
- The worker flags `--tries` and `--timeout` work for queued emails, like for other jobs.
- With the `sync` queue driver, the email is sent at once, and `later()` does not wait.
- Attachments are saved as base64, so they take about 4/3 of their size. MySQL and MariaDB refuse a job bigger than `max_allowed_packet` (by default 64 MB in MySQL 8, 16 MB in MariaDB). Redis keeps every job in memory.
- With `encrypt: true`, a send error is encrypted too. The plain text of the error is only its type and code, like `RedactedMailError: MailException (code 550). Details are encrypted: ...`. The encrypted part holds at most the first 64K characters (UTF-16 code units). To read it, take a `FailedJob` from `Queue.driver.failed()` and call `RedactedMailError.decrypt(job.error)`. It works with the app key or any key in `AppConfig.previousKeys`.
- To use another queue than dox_queue, call `Mail.useQueue(queue)`. `null` goes back to the dox_queue queue.

### Hooks

- If an `onSent` hook throws, a queue worker does not try the job again, so the email is not sent twice. The other `onSent` hooks still run.
- `Mail.clearHooks()` removes all hooks. Call it first in `setup()`, and in tests.
