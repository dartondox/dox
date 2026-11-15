---
icon: lucide/radio-tower
---

# Notifications

A notification tells a user about something, like "your invoice is paid", by email or by any channel you write.

One notification can go out on more than one channel, like email, a database table or SMS. Each notification is a class, so the text and the channels live in one place.

Notifications are in the `dox_mailer` package. Set up [mail](mail.md) first.

## Creating notifications

A notification extends `Notification`. The `via` method picks the channels, and `toMail` builds the email:

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

## Sending notifications

### Making a model notifiable

The class that gets notifications, usually the user model, needs the `Notifiable` mixin. Its `routeNotificationFor` method tells each channel where to send. For the `mail` channel, it returns the email address:

```dart
class User extends Model<User> with Notifiable {
  @override
  Object? routeNotificationFor(String channel) {
    return channel == 'mail' ? Address(email!, name) : null;
  }
}
```

The mail route can be an `Address`, an email text like `Ann <ann@example.com>`, or a list of these. If the mailable has its own `to` address, that address is used and the route is not.

### Sending to one user

Call `notify` on the model:

```dart
await user.notify(InvoicePaid(1));
```

### Sending to many users

Use `Notification.send` with a list:

```dart
await Notification.send(users, InvoicePaid(1));
```

### Sending to an address with no user

Sometimes the person has no user row, like a guest. Pass an `Address`:

```dart
await Notification.send(<Object>[Address('ann@example.com')], InvoicePaid(1));
```

## Handling errors

If one channel throws, the other channels and the other notifiables still get the notification. At the end, `Notification.send()` throws a `NotificationException`. Its `errors` list says which notifiable and channel failed, and why.

The error text of a `NotificationException` has no email addresses and no error messages, so it is safe for logs. Read `errors` for the details.

With one notifiable and one error, like in `user.notify()`, the error is thrown as it is. So `on MailException catch (e)` still works there.

## Queueing notifications

Sending an email can be slow, so you may want to send it in the background. Override `shouldQueue`. The mail channel then puts the email on the job queue, like `Mail.queue()`. This needs [a queue](queue.md):

```dart
@override
bool get shouldQueue => true;
```

The email is rendered at once, and the worker sends the finished email.

You can set the queue options with these getters. They work like the options of `Mail.queue()`:

| Getter | Default | What it does |
| --- | --- | --- |
| `queue` | null (`default`) | the queue name |
| `delay` | null | the worker sends the email after this wait |
| `encrypt` | `false` | save the job data encrypted with the app key |

`shouldQueue` and these options only change the mail channel. Your own channels still run at once. To queue them, dispatch a job in the channel.

## Custom channels

If you want to send a notification another way, like to a database table, write your own channel. A channel implements `NotificationChannel`. It gets the data of the notification from `toArray()`:

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

Then add the channel to `via()`, and give the data in `toArray()`:

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

`dox_mailer` has no database channel of its own, so it does not need the ORM.

## Testing

`Mail.fake()` also catches the emails of the mail channel:

```dart
ArrayTransport mail = Mail.fake();
await user.notify(InvoicePaid(1));
expect(mail.messages.single.subject, 'Invoice paid');
```

With `shouldQueue`, the email goes to `mail.queued`, not to `mail.messages`, and it does not reach the job queue. Check it with `mail.assertQueued()`. See [Mail](mail.md#testing).

## Details

- Each item of `NotificationException.errors` has the notifiable and the channel. When `via()` throws, the channel is null. The error text has one line per failure: the place and the type of the notifiable, the channel, and the error type.
- When `shouldQueue` is false, the queue options do nothing.
