/// Socket.IO packet types. The index is the wire value.
enum SocketPacketType {
  connect,
  disconnect,
  event,
  ack,
  connectError,
  binaryEvent,
  binaryAck,
}

/// Name of the default namespace.
const String defaultNamespace = '/';

/// Key used to mark a binary attachment inside JSON.
const String placeholderKey = '_placeholder';

/// Event names a client is not allowed to emit.
const Set<String> reservedEvents = <String>{
  'connect',
  'connect_error',
  'disconnect',
  'disconnecting',
  'newListener',
  'removeListener',
};

/// Server-side event names.
const String connectionEvent = 'connection';
const String disconnectEvent = 'disconnect';
const String disconnectingEvent = 'disconnecting';

/// Message sent when a client asks for a namespace that does not exist.
const String invalidNamespaceMessage = 'Invalid namespace';

/// Default prefix of the Redis channels. Same as @socket.io/redis-adapter.
const String defaultRedisKey = 'socket.io';
