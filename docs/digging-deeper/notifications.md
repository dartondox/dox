---
icon: lucide/radio-tower
---

# Notifications

Notifications are in the `dox_mailer` package.

Set up [mail](mail.md) first.

A notification tells a user about something, like "your invoice is paid". It can go out on more than one channel: email, a database table, SMS. Each notification is a class. `via()` picks the channels.

```dart
class InvoicePaid extends Notification {
  InvoicePaid(this.invoiceId);

  final int invoiceId;

  @override
  List<NotificationChannel> via(Object notifiable) {
    return <NotificationChannel>[const MailChannel()];
  }

  @override
  Mailable toMail(Object notifiable) {
    return MailMessage(subject: 'Invoice paid')
      ..line('We got your payment.')
      ..action('View invoice', 'https://example.com/invoices/$invoiceId');
  }
}
```

`toMail()` can return any mailable, so a `WelcomeMail` with a template works too.

## Who gets it

Add the `Notifiable` mixin to the class that gets notifications, usually the user model. `routeNotificationFor('mail')` gives the email address:

```dart
class User extends Model<User> with Notifiable {
  @override
  Object? routeNotificationFor(String channel) {
    return channel == 'mail' ? Address(email!, name) : null;
  }
}
```

The route can be an `Address`, an email text like `Ann <ann@example.com>`, or a list of these.

Then send:

```dart
await user.notify(InvoicePaid(1));

// many users
await Notification.send(users, InvoicePaid(1));

// an address with no user
await Notification.send(<Object>[Address('ann@example.com')], InvoicePaid(1));
```

When the mailable has its own `to` address, that address is used and the route is not.

When a channel throws, the other channels and the other notifiables still get the notification. At the end, `Notification.send()` throws a `NotificationException`. Its `errors` list says which notifiable and channel failed, and why. When `via()` throws, the channel is null. The error text has one line per failure: the place and the type of the notifiable, the channel, and the error type. It has no email addresses and no error text, so it is safe for logs. For the details, read `errors`.

With one notifiable and one error, like `user.notify()`, the error is thrown as it is. So `on MailException catch (e)` still works there.

## Queue it

Override `shouldQueue`. The mail channel then puts the email on the job queue, like `Mail.queue()`. This needs [a queue](queue.md).

```dart
@override
bool get shouldQueue => true;
```

The email is rendered at once. The worker sends the finished email.

These getters set the queue options. They work like the options of `Mail.queue()`:

| Getter | Default | What it does |
| --- | --- | --- |
| `queue` | null (`default`) | the queue name |
| `delay` | null | the worker sends the email after this wait |
| `encrypt` | `false` | save the job data encrypted with the app key |

When `shouldQueue` is false, the email is sent at once and these options do nothing. `shouldQueue` and these options only change the mail channel. Your own channels still run at once. To queue them, dispatch a job in the channel.

## Your own channel

Write a class that implements `NotificationChannel`. `toArray()` of the notification gives its data. For example, a channel that saves notifications in a table:

```dart
import 'dart:convert';

class DatabaseChannel implements NotificationChannel {
  @override
  Future<void> send(Object notifiable, Notification notification) async {
    // only a user has a row. An Address or an email text has none.
    if (notifiable is! User) return;
    AppNotification row = AppNotification()
      ..userId = notifiable.id
      ..data = jsonEncode(notification.toArray(notifiable));
    await row.save();
  }
}
```

```dart
class InvoicePaid extends Notification {
  @override
  List<NotificationChannel> via(Object notifiable) {
    return <NotificationChannel>[const MailChannel(), DatabaseChannel()];
  }

  @override
  Map<String, Object?> toArray(Object notifiable) {
    return <String, Object?>{'type': 'invoice_paid', 'invoice_id': invoiceId};
  }

  // ...
}
```

dox_mailer has no database channel of its own, so it does not need the ORM.

## Test it

`Mail.fake()` catches the emails of the mail channel too:

```dart
ArrayTransport mail = Mail.fake();
await user.notify(InvoicePaid(1));
expect(mail.messages.single.subject, 'Invoice paid');
```

With `shouldQueue`, the email goes to `mail.queued`, not to `mail.messages`. It does not reach the job queue. Check it with `mail.assertQueued()`. See [Mail](mail.md#testing).
