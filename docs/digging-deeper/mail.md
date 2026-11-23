---
icon: lucide/mail
---

# Mail

The `dox_mailer` package sends email from your app with SMTP, Amazon SES, Azure, Resend, Mailgun, Postmark or sendmail.

You make a `Message` and call `Mail.send()`, and a **transport** sends it. The config picks the transport, so you can change providers with no code change.

## Setup

### Install

Add the package. Add `--transport=smtp` (or `resend`, `mailgun`, `postmark`, `ses`) to pick a transport. The default is `log`:

```bash
dox add mailer
```

It writes the mail config and the provider, and adds `MAIL_MAILER`, `MAIL_FROM` and the transport keys to `.env`. It never overwrites a file.

### Configuration

A **mailer** is a name and a transport. `Mail.send()` uses the `defaultMailer`:

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

`Mail.config` gives this config in your code.

### The mail provider

The provider sets up the mailers in every isolate. Put it in `lib/providers/`:

```dart title="lib/providers/mail_provider.dart"
import 'package:dox_mailer/dox_mailer.dart';

import '../config/mail.dart';

class AppMailProvider extends MailProvider {
  AppMailProvider() : super(mailConfig);
}
```

When the server stops, the provider closes the SMTP connections and HTTP clients.

## Sending mail

Make a `Message` and give it to `Mail.send()`:

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

A message needs a from address, a recipient, and a text or HTML body. When the send fails, `send()` throws a `MailException` with the `statusCode` and the `body` of the server answer. It gives a `SentMessage` with the `messageId`.

### Using another mailer

Send with a mailer that is not the default:

```dart
await Mail.mailer('ses').send(message);
```

### Short ways to send

For a short plain text email, use `Mail.raw()`:

```dart
await Mail.raw('Your code is 1234',
    to: 'ann@example.com', subject: 'Your code');
```

`Mail.to()` starts an email for a [mailable](#mailables). `to()`, `cc()` and `bcc()` take an `Address`, an email text, or a list of these:

```dart
await Mail.to('ann@example.com')
    .cc('Bob Lee <bob@example.com>')
    .bcc(<String>['audit@example.com'])
    .send(WelcomeMail(user));
```

`queue()` and `later()` also work here, like `Mail.to(email).queue(WelcomeMail(user))`.

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
| `headers` | more headers, like `{'X-Campaign': 'fall'}` |
| `tags` | tags for the reports of the provider. See [Tags and metadata](#tags-and-metadata) |
| `metadata` | key and value data for the provider, like `{'user_id': '42'}` |

A subject or header with a line break is an error, so user input cannot add headers.

An `Address` is an email and an optional name. `Address.parse` reads one from text, and `Address.list` reads many:

```dart
Address('ann@example.com', 'Ann');
Address.parse('Ann <ann@example.com>');
Address.list(<String>['ann@example.com', 'bob@example.com']);
```

### Attachments

Add files with `attachments`. The content type comes from the file extension, or from `contentType`:

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

To attach a file from a storage disk, read its bytes first:

```dart
Uint8List? pdf = await Storage().disk('s3').get('invoices/42.pdf');
Attachment(pdf!, 'invoice.pdf');
```

### Inline images

Give the file a `cid`, and use it in the HTML with `cid:`:

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

Mailgun uses the file name as the cid, so use a cid with the extension, like `logo.png`.

### HTML from a view

Render a [view](../the-basic/views.md) template to HTML:

```dart
String html =
    View.render('emails/welcome', <String, dynamic>{'name': 'Ann'});
await Mail.send(Message(to: to, subject: 'Welcome', html: html));
```

## Mailables

A **mailable** is one kind of email in its own class, like the welcome email. Make one with the CLI. Add `--no-view` for a plain text body. See [`dox make:mail`](../reference/cli.md#dox-makemail):

```bash
dox make:mail Welcome
```

It writes `lib/app/mail/welcome_mail.dart` and `resources/views/emails/welcome.dox.html`. Override the getters you need:

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
| `markdown` | a dox_view template with Markdown. See [Markdown mail](#markdown-mail) |
| `data` | the variables of the templates |
| `attachments` | the files |
| `mailer` | the mailer name, like `ses`. Null: the default mailer |

### Sending a mailable

Call `send()`, or put the mailable on the queue with `queue()` or `later()`:

```dart
await WelcomeMail(user).send();
await WelcomeMail(user).queue();
await WelcomeMail(user).later(Duration(minutes: 10));
```

`queue()` and `later()` render the templates at once. They take the options of [`Mail.queue()`](#queue-an-email).

### Changing the message

`toMessage()` gives the email as a `Message`. Override it to set more, like headers or tags:

```dart
@override
Message toMessage() {
  return super.toMessage().copyWith(tags: <String>['welcome']);
}
```

### Markdown mail

Write the email in Markdown. One template gives an HTML email with a layout and a plain text part:

```markdown title="resources/views/emails/welcome.dox.html"
# Hi {{ name }}

Thanks for joining. Here is what you can do next:

- Fill in your profile
- Invite your team

[Open your profile]({{ profileUrl }})

<a href="https://example.com/dashboard" class="button">Open the app</a>
```

Then set the `markdown` getter:

```dart
@override
String? get markdown => 'emails/welcome';
```

`<a class="button">` shows as a button. Do not indent the Markdown in `@if` or `@each`, because 4 spaces make a code block.

`{{ }}` escapes HTML and Markdown, and a link with an unsafe URL, like `javascript:`, loses its URL. Raw HTML in the template, like `<a href="{{ url }}">`, is not checked, so write links as `[text]({{ url }})`. To put Markdown from a value in the email, give a `SafeString`.

### Custom layout

Override `layout()` to use your own look. It gets the HTML of the Markdown and gives the full page:

```dart
import 'package:dox_mailer/dox_mailer.dart';
import 'package:dox_view/dox_view.dart'; // View, SafeString

abstract class AppMail extends Mailable {
  @override
  String layout(String body) {
    return View.render('emails/layout',
        <String, Object?>{'body': SafeString(body)});
  }
}
```

### A simple email with no template

`MailMessage` is a mailable for a few lines and a button. It uses the Markdown layout:

```dart
await (MailMessage(
        subject: 'Invoice paid',
        to: <Address>[Address('ann@example.com')])
      ..line('We got your payment.')
      ..action('View invoice', 'https://example.com/invoices/1')
      ..line('Thank you!'))
    .send();
```

- `cc:` in the constructor adds cc addresses.
- `attach(Attachment(...))` adds a file.
- `error()` makes the buttons red.
- `greeting` (default `Hello!`) starts the email, and `salutation` (default none) ends it.

Lines can use Markdown, like `**bold**`. `action()` throws an ArgumentError for an unsafe URL. To send one email on more channels, see [Notifications](notifications.md).

## Queue an email

A queue worker sends the email later, so the request does not wait:

```dart
await Mail.queue(message);
```

To send it after a time, use `Mail.later()`. Both give the job id:

```dart
await Mail.later(Duration(minutes: 10), message);
```

To pick another mailer and another queue:

```dart
await Mail.mailer('ses').queue(message, queue: 'emails');
```

This uses [dox_queue](queue.md), so you need its `QueueProvider` and a worker. The worker must also run your `MailProvider`, or the job fails with "Mail is not set up". The message is checked at once, so a bad message fails in the request.

| Option | Default | What it does |
| --- | --- | --- |
| `queue` | `default` | the queue name |
| `encrypt` | false | encrypt the job data with the app key. The worker needs the same key |

The full email, with its attachments, is saved in Redis or in the `jobs` table. So keep attachments small. An email has personal data, so use `encrypt: true` if other people can read the queue.

With `encrypt: true`, the send error of a failed job is encrypted too. Read it with `RedactedMailError.decrypt(job.error)`. To use a queue other than dox_queue, call `Mail.useQueue(queue)`.

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
| `encryption` | `starttls` | `none`, `starttls` (TLS after connect) or `tls` (TLS from the start) |
| `allowInsecure` | false | accept a self-signed TLS certificate. Only for test servers |
| `auth` | PLAIN, or LOGIN when the server has no PLAIN | `SmtpAuth.plain`, `SmtpAuth.login` or `SmtpAuth.xoauth2` |
| `localDomain` | `localhost` | the name of this machine, for `EHLO` |
| `timeout` | 30 seconds | the time to connect, and to wait for each reply |
| `keepAlive` | false | keep the connection open for the next message |

With `starttls`, the send fails when the server has no STARTTLS, so your password never goes in plain text. For Gmail or Outlook with OAuth 2, use `SmtpAuth.xoauth2` with the access token as the `password`.

For local work, [Mailpit](https://mailpit.axllent.org) catches all emails:

```dart
'mailpit': SmtpTransport(
  host: 'localhost',
  port: 1025,
  encryption: SmtpEncryption.none,
),
```

### Amazon SES

`SesTransport` uses SES API v1, and `SesV2Transport` uses SES API v2. Both send attachments and inline images:

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
| `sessionToken` | none | for temporary keys, like from a role |
| `region` | `us-east-1` | the AWS region of SES |
| `configurationSet` | none | the SES configuration set, to track events |
| `endpoint` | `https://email.<region>.amazonaws.com/` | another API address |

### Azure Communication Services

```dart
'azure': AzureTransport(
  endpoint: 'https://my-app.europe.communication.azure.com',
  accessKey: Env.get('AZURE_EMAIL_KEY'),
),
```

Or use the connection string from the Azure portal:

```dart
'azure': AzureTransport.fromConnectionString(
  Env.get('AZURE_EMAIL_CONNECTION_STRING'),
),
```

| Option | Default | What it does |
| --- | --- | --- |
| `endpoint` | required | the address of your resource |
| `accessKey` | required | the access key of the resource |
| `apiVersion` | `2023-03-31` | the API version. Inline images need a newer version |
| `disableTracking` | false | turn off open and click tracking |

### Resend

```dart
'resend': ResendTransport(apiKey: Env.get('RESEND_API_KEY')),
```

### Mailgun

Use the region of your Mailgun domain: `MailgunRegion.us` (the default) or `MailgunRegion.eu`:

```dart
'mailgun': MailgunTransport(
  apiKey: Env.get('MAILGUN_API_KEY'),
  domain: 'mg.example.com',
  region: MailgunRegion.eu,
),
```

### Postmark

`messageStream` is optional. Without it, Postmark uses the default stream:

```dart
'postmark': PostmarkTransport(
  serverToken: Env.get('POSTMARK_TOKEN'),
  messageStream: 'outbound',
),
```

### sendmail

Send with the `sendmail` program of the server (Postfix, Exim, msmtp and others):

```dart
'sendmail': SendmailTransport(
  path: '/usr/sbin/sendmail',
  mode: SendmailMode.smtp,
),
```

| Mode | Command | How it works |
| --- | --- | --- |
| `SendmailMode.smtp` (default) | `sendmail -bs` | speaks SMTP on stdin and stdout |
| `SendmailMode.pipe` | `sendmail -t -i` | sends the message in. sendmail reads the recipients from the headers |

### Log

Print each email and send nothing. `output` sets where it prints, and `bothBodies: true` also shows the HTML body:

```dart
'log': LogTransport(bothBodies: true, output: stderr.writeln),
```

### Array

Keep each email in a list and send nothing. See [Testing](#testing):

```dart
'array': ArrayTransport(),
```

### Failover

`FailoverTransport` tries each transport in order, until one sends the email. If all fail, it throws the error of the last one:

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

Give `onError` to get the error of each transport that fails.

## Tags and metadata

Each transport uses `tags` and `metadata` in its own way:

| Transport | `tags` | `metadata` |
| --- | --- | --- |
| SES | not used | message tags |
| Resend | tags with the value true | tags |
| Mailgun | `o:tag` | variables (`v:name`) |
| Postmark | the first tag | metadata |
| Azure, SMTP, sendmail | not used | not used |

For SMTP and sendmail, use `headers`.

## Hooks

Run code before or after each email, for example to log it. Each isolate has its own hooks, so add them in `setup()` of your mail provider:

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

Hooks run for every mailer, for queued emails and with `Mail.fake()`. When an `onSending` hook throws, the email is not sent. When an `onSent` hook throws, the error is only logged.

## Sending all mail to one address

On a staging server, send every email to your own inbox with `Mail.alwaysTo()`. Call it in `setup()` of your mail provider:

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

The `to` of each email becomes that address, and `cc` and `bcc` are removed. `Mail.alwaysTo(null)` turns it off.

## Custom transports

Extend `Transport` and add it to `mailers`:

```dart
class MyApiTransport extends Transport {
  @override
  Future<SentMessage> send(Message message) async {
    // call your API here
    return SentMessage(message, messageId: 'id from the API');
  }
}
```

The message already has a from address. For a provider that takes raw MIME, `MimeBuilder().build(message)` gives the MIME text.

## Testing

`Mail.fake()` sends all mailers to one `ArrayTransport`, so nothing goes out:

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

### Testing queued mail

Queued emails go to `mail.queued`, not to the job queue, so you need no queue setup:

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
| `assertSentCount(count, [test])` | `count` emails were sent. With `test`, `count` emails pass it |
| `assertNotSent(test)` | no sent email passes `test` |
| `assertNothingSent()` | no email was sent |
| `assertQueued([test])` | an email was queued. With `test`, one of them passes it |
| `assertNotQueued(test)` | no queued email passes `test` |
| `assertNothingQueued()` | no email was queued |

`test` is a `bool Function(Message)`. A failed check throws a StateError. `mail.clear()` removes the sent and the queued emails.

## Without Dox

`dox_mailer` also works on its own. Call `Mail.configure()` at the start, and `Mail.close()` at the end:

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

## Next steps

- [Notifications](notifications.md): send one message on many channels.
- [Queue](queue.md): send mail in the background.
- [Views](../the-basic/views.md): write the mail templates.
