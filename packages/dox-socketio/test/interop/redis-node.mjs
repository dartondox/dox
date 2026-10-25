// A Node.js Socket.IO server with @socket.io/redis-adapter, plus one client
// connected to it. Used to check that the Dart RedisAdapter talks the same
// format.
// Usage: node redis-node.mjs <redisUrl> [msgpack|json]
// Sends `from-node` to all and `from-node-room` to room r1, then prints READY.
// After it gets `from-dart`, it checks the requests the Dart server answers
// (fetchSockets, allRooms, emitWithAck), then exits 0.
import { createServer } from 'node:http';
import { Server } from 'socket.io';
import { io as connect } from 'socket.io-client';
import { createAdapter } from '@socket.io/redis-adapter';
import { createClient } from 'redis';

const [redisUrl, format = 'msgpack'] = process.argv.slice(2);
const timer = setTimeout(() => { console.error('FAIL timed out'); process.exit(1); }, 15000);

const pub = createClient({ url: redisUrl });
const sub = pub.duplicate();
await Promise.all([pub.connect(), sub.connect()]);

// msgpack is the default parser of the adapter.
const parser = format === 'json'
  ? { encode: (value) => JSON.stringify(value), decode: (value) => JSON.parse(value) }
  : undefined;
const http = createServer();
const io = new Server(http, { adapter: createAdapter(pub, sub, { parser }) });
io.on('connection', (socket) => socket.join('r1'));
await new Promise((resolve) => http.listen(0, '127.0.0.1', resolve));

const client = connect(`http://127.0.0.1:${http.address().port}`, { transports: ['websocket'] });
const fail = (text) => { console.error('FAIL ' + text); process.exit(1); };
client.on('ack-me', (callback) => callback('node'));
client.on('from-dart', async (data) => {
  if (data.x !== 1) fail('bad data ' + JSON.stringify(data));
  console.log('GOT from-dart');
  // The Dart server is in the cluster, so these wait for its answers.
  const sockets = await io.fetchSockets();
  if (sockets.length !== 2) fail('fetchSockets gave ' + sockets.length);
  const rooms = await io.of('/').adapter.allRooms();
  if (!rooms.has('r1') || rooms.size < 3) fail('allRooms gave ' + [...rooms]);
  const acks = await io.to('r1').timeout(2000).emitWithAck('ack-me');
  if (JSON.stringify(acks) !== '["node"]') fail('acks ' + JSON.stringify(acks));
  clearTimeout(timer);
  client.close();
  io.close();
  pub.quit().catch(() => {});
  sub.quit().catch(() => {});
  setTimeout(() => process.exit(0), 100);
});
client.on('connect', () => {
  // Give the adapter a moment to subscribe, then tell Dart we are ready.
  setTimeout(() => {
    // No room: this goes on the main channel.
    io.emit('from-node', 'hi dart');
    // Exactly one room: Node.js uses the room channel for this.
    io.to('r1').emit('from-node-room', 'hi room');
    console.log('READY');
  }, 300);
});
