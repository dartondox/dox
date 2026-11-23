---
icon: lucide/radio-tower
---

# Notifications

A notification tells a user about something, like "your invoice is paid", by email or by a channel you write.

Each notification is a class that holds the text and the channels. Notifications are in the `dox_mailer` package, so set up [mail](mail.md) first.

## Creating notifications

A notification extends `Notification`. The `via` method gives the channels, and `toMail` makes the email:

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

`toMail()` can return any mailable, like a `WelcomeMail` with a template.

## Sending notifications

### Making a model notifiable

Add the `Notifiable` mixin to the class that gets notifications. Its `routeNotificationFor` method gives each channel the destination:

```dart
class User extends Model<User> with Notifiable {
  @override
  Object? routeNotificationFor(String channel) {
    return channel == 'mail' ? Address(email!, name) : null;
  }
}
```

The mail route can be an `Address`, an email text like `Ann <ann@example.com>`, or a list of these. A `to` address on the mailable wins over the route.

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

For a guest with no user row, give an `Address`:

```dart
await Notification.send(<Object>[Address('ann@example.com')],
    InvoicePaid(1));
```

## Handling errors

When one channel throws, the other channels and notifiables still get the notification. At the end, `Notification.send()` throws a `NotificationException`. Its `errors` list gives the notifiable, the channel and the error of each failure:

```dart
try {
  await Notification.send(users, InvoicePaid(1));
} on NotificationException catch (e) {
  for (NotificationError error in e.errors) {
    print('${error.channel}: ${error.error}'); // null channel: via()
  }
}
```

The error text has no email addresses, so it is safe for logs. With one notifiable and one error, like in `user.notify()`, you get the initial error, like a `MailException`.

## Queueing notifications

Override `shouldQueue` to send the email in the background. The mail channel then puts the email on [the queue](queue.md), like `Mail.queue()`:

```dart
@override
bool get shouldQueue => true;
```

The email is rendered at once, and the worker sends it. These getters set the queue options:

| Getter | Default | What it does |
| --- | --- | --- |
| `queue` | null (`default`) | the queue name |
| `delay` | null | the worker sends the email after this wait |
| `encrypt` | false | encrypt the job data with the app key |

These options change only the mail channel. To queue your own channel, dispatch a job in it.

## Custom channels

To send a notification another way, like to a database table, write a channel. A channel implements `NotificationChannel` and gets the data from `toArray()`:

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
    return <String, Object?>{
      'type': 'invoice_paid',
      'invoice_id': invoiceId,
    };
  }

  // ...
}
```

## Testing

`Mail.fake()` also catches the emails of the mail channel:

```dart
ArrayTransport mail = Mail.fake();
await user.notify(InvoicePaid(1));
expect(mail.messages.single.subject, 'Invoice paid');
```

With `shouldQueue`, the email goes to `mail.queued`. Check it with `mail.assertQueued()`. See [Mail](mail.md#testing).

## Next steps

- [Mail](mail.md): mailables, templates and transports.
- [Queue](queue.md): run the workers that send queued email.
