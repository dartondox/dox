---
icon: lucide/radio-tower
---

# Notifications

Notifications are in the `dox_mailer` package. Set up [mail](mail.md) first.

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

The route can be an `Address`, an email text like `Ann <ann@example.com>`, or a `List<Address>`.

Then send:

```dart
await user.notify(InvoicePaid(1));

// many users
await Notification.send(users, InvoicePaid(1));

// an address with no user
await Notification.send(<Object>[Address('ann@example.com')], InvoicePaid(1));
```

When the mailable has its own `to` address, that address is used and the route is not.

## Queue it

Override `shouldQueue`. The mail channel then puts the email on the job queue, like `Mail.queue()`. This needs [a queue](queue.md).

```dart
@override
bool get shouldQueue => true;
```

The email is rendered at once. The worker sends the finished email.

## Your own channel

Write a class that implements `NotificationChannel`. `toArray()` of the notification gives its data. For example, a channel that saves notifications in a table:

```dart
class DatabaseChannel implements NotificationChannel {
  @override
  Future<void> send(Object notifiable, Notification notification) async {
    AppNotification row = AppNotification()
      ..userId = (notifiable as User).id
      ..type = notification.runtimeType.toString()
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
    return <String, Object?>{'invoice_id': invoiceId};
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
