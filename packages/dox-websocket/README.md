<div align="center">
<img src="https://raw.githubusercontent.com/dartondox/assets/main/dox-logo.png" width="70" />
</br></br>
<div style="display:inliine-block">
<img src="https://img.shields.io/badge/Dart-0175C2?style=for-the-badge&logo=dart&logoColor=white" height="20"/> <img src="https://github.com/dartondox/dox-core/actions/workflows/test.yaml/badge.svg?branch=v1.x" height="20"/> <img src="https://img.shields.io/github/stars/dartondox/dox-core.svg" height="20"/> <img src="https://img.shields.io/github/forks/dartondox/dox-core.svg" height="20"/> <img src="https://img.shields.io/github/license/dartondox/dox-core.svg" height="20"/>
</div>
</div>

## Dox Websocket

Websocket library for dox framework.

## Features

- Support redis driver

## Usage

- Create a service

```dart
class WebsocketService implements DoxService {
  @override
  setup() {
    DoxWebsocket websocket = DoxWebsocket();

    Redis sub = Redis();
    Redis pub = sub.duplicate();

    websocket.adapter(
      WebsocketRedisAdapter(subscriber: sub, publisher: pub),
    );

    Dox().setWebsocket(websocket);
  }
}
```

- Register in dox

```dart
Dox().initialize(config);
Dox().addService(WebsocketService());
await Dox().startServer();
```

## Note

- If you are not using redis adapter, websocket do not support with multiple isolate. You will need to set to single isolate.

```dart
Dox().totalIsolate(1);
```
