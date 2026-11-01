---
icon: lucide/mail
---

# Mail

The `dox_mailer` package sends email from your app with SMTP, Amazon SES, Azure, Resend, Mailgun, Postmark or sendmail.

You write a `Message` and call `Mail.send()`. A transport sends it. You pick the transport in a config file, so you can change providers with no code change.

The package has its own SMTP client, AWS signer and MIME builder. Next to `dox_core`, it only needs `http` and `crypto`.

Send slow emails from a [queue job](queue.md), so the request does not wait.

## Install

```bash
dart pub add dox_mailer
```

## Set up

### 1. Config

A mailer is a name and a transport. `defaultMailer` is the one that `Mail.send()` uses.

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

### 2. Provider

The provider sets up the mailers in every isolate. Put it in `lib/providers/`, so the generated container finds it.

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

## Without Dox

`dox_mailer` also works on its own. Call `Mail.configure()` once at start, and `Mail.close()` at the end:

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

The rest of this page works the same way.

## Send an email

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

Send with another mailer:

```dart
await Mail.mailer('ses').send(message);
```

`send()` gives a `SentMessage`. Its `messageId` is the id of the provider (or the `Message-ID` header for SMTP and sendmail).

When the message can not be sent, `send()` throws a `MailException`. It has the `statusCode` and the `body` of the answer of the server.

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

An `Address` is an email and an optional name: `Address('ann@example.com', 'Ann')`. `Address.parse('Ann <ann@example.com>')` reads one from text.

A message needs a from address, at least one recipient, and a text or HTML body. A subject or header with a line break is an error, so user input can not add headers.

### Attachments

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

The content type comes from the file extension. Pass `contentType` to set it.

### Inline images

Give the file a `cid`. Use it in the HTML with `cid:`.

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

Mailgun uses the file name as the cid. So for Mailgun, use a cid like `logo.png`, with the file extension.

### HTML from a view

With [views](../the-basic/views.md), render a template to HTML:

```dart
String html = View.render('emails/welcome', <String, dynamic>{'name': 'Ann'});
await Mail.send(Message(to: to, subject: 'Welcome', html: html));
```

## Mailables

A mailable is one kind of email in its own class, for example the welcome email. It keeps the address, the subject, the template and the data in one place. Override the getters you need:

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

Then send it, or put it on the queue:

```dart
await WelcomeMail(user).send();
await WelcomeMail(user).queue();
await WelcomeMail(user).later(Duration(minutes: 10));
```

`queue()` and `later()` render the templates at once. The worker sends the finished email, so it needs no templates and no data. They take the same `queue` and `encrypt` options as `Mail.queue()`.

| Getter | What it is |
| --- | --- |
| `to`, `cc`, `bcc`, `replyTo` | the addresses |
| `from` | the sender. Null: the `from` of the mail config |
| `subject` | the subject |
| `html`, `text` | the body as text, when there is no template |
| `view` | a [views](../the-basic/views.md) template for the HTML body |
| `textView` | a dox_view template for the plain text body |
| `markdown` | a dox_view template with Markdown, see below |
| `data` | the variables of the templates |
| `attachments` | the files |
| `mailer` | the mailer name, eg. `ses`. Null: the default mailer |

`toMessage()` gives the email as a `Message`. To set more, like headers or tags, override it:

```dart
@override
Message toMessage() {
  return super.toMessage().copyWith(tags: <String>['welcome']);
}
```

`{{ }}` in a template escapes HTML. For the plain text body of `textView` and `markdown`, the escape is undone, so `Tom & Jerry` stays `Tom & Jerry`.

### Markdown mail

Write the email in Markdown. You get a simple HTML email with a layout, and a plain text part, from one template.

`resources/views/emails/welcome.dox.html`:

```markdown
# Hi {{ name }}

Thanks for joining. Here is what you can do next:

- Fill in your profile
- Invite your team

<a href="{{ url }}" class="button">Open the app</a>
```

```dart
@override
String? get markdown => 'emails/welcome';
```

- The HTML body is the Markdown as HTML, inside a white card on a grey page.
- `<a class="button">` shows as a button. In the text body it stays an `<a>` tag, so the link is still there.

!!! warning "User data in Markdown"
    `{{ }}` escapes HTML, but not Markdown. So a user's name like `[click](https://evil.example)` or `![x](https://evil.example/p.png)` becomes a normal link or image. Laravel works the same way.
    Links and images with an unsafe URL, like `javascript:`, `vbscript:` or `data:`, lose their URL. Only `http`, `https`, `mailto`, `tel`, `cid` and relative URLs are kept.
    The same goes for the lines of `MailMessage`.

!!! warning "Indent"
    Markdown makes a line that starts with 4 spaces into a code block. So do not indent the Markdown inside `@if` or `@each`. Keep it at the start of the line.
- The text body is the Markdown itself.

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

`MailMessage` is a mailable made of lines and a button. It needs no template. It uses the Markdown layout.

```dart
await (MailMessage(subject: 'Invoice paid', to: <Address>[Address('ann@example.com')])
      ..line('We got your payment.')
      ..action('View invoice', 'https://example.com/invoices/1')
      ..line('Thank you!'))
    .send();
```

The email starts with `greeting` (default `Hello!`) and ends with `salutation` (default none). Set them to null to leave them out. Lines can use Markdown, like `**bold**`. HTML in a line is escaped. See "User data in Markdown" above.

To send one email on more than one channel, see [Notifications](notifications.md).

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

With `starttls`, the send fails when the server does not offer STARTTLS. Your password is never sent in plain text by mistake.

For Gmail or Outlook with OAuth 2, use `auth: SmtpAuth.xoauth2`. The `username` is the email and the `password` is the access token.

`keepAlive: true` is good when you send many emails. One connection sends them one by one. When the server closed it, the next send opens a new one.

For local work, [Mailpit](https://mailpit.axllent.org) catches all emails:

```dart
'mailpit': SmtpTransport(
  host: 'localhost',
  port: 1025,
  encryption: SmtpEncryption.none,
),
```

### Amazon SES

There are two classes. Both send the same MIME message, with attachments and inline images.

- `SesTransport`: SES API v1, `SendRawEmail`.
- `SesV2Transport`: SES API v2, `SendEmail` with raw content.

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

The requests are signed with AWS Signature Version 4. No AWS SDK is needed.

### Azure Communication Services

```dart
'azure': AzureTransport(
  endpoint: 'https://my-app.europe.communication.azure.com',
  accessKey: Env.get('AZURE_EMAIL_KEY'),
),
```

Or with the connection string of the Azure portal:

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

Requests are signed with the access key (HMAC-SHA256). Inline images need a newer `apiVersion` that supports them.

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

Sends with the `sendmail` program of the server (Postfix, Exim, msmtp and others).

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

Prints each email and sends nothing. Good for local work.

```dart
'log': LogTransport(),
```

Pass `output` to print somewhere else, eg. `LogTransport(output: stderr.writeln)` (from `dart:io`).

### Array

Keeps each email in a list and sends nothing. See [Testing](#testing).

```dart
'array': ArrayTransport(),
```

### Failover

Tries each transport in order, until one sends the email.

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

## Testing

`Mail.fake()` sends every mailer to one `ArrayTransport`. Nothing goes out. Then check what was sent.

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

`Mail.fake()` works with or without a config. The fake stays on when `MailProvider` sets up the config again.

`mail.clear()` forgets the sent emails.

## Your own transport

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

The message is checked, and has a from address, when it gets to `send()`.

For a provider that takes raw MIME, `MimeBuilder().build(message)` gives the MIME text.
