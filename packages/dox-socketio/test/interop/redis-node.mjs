// A Node.js Socket.IO server with @socket.io/redis-adapter (JSON parser),
// plus one client connected to it. Used to check that the Dart RedisAdapter
// talks the same format.
// Usage: node redis-node.mjs <redisUrl>
// Sends `from-node` to all and `from-node-room` to room r1, then prints READY. Exits 0 after it gets `from-dart`.
import { createServer } from 'node:http';
import { Server } from 'socket.io';
import { io as connect } from 'socket.io-client';
import { createAdapter } from '@socket.io/redis-adapter';
import { createClient } from 'redis';

const [redisUrl] = process.argv.slice(2);
const timer = setTimeout(() => { console.error('FAIL timed out'); process.exit(1); }, 15000);

const pub = createClient({ url: redisUrl });
const sub = pub.duplicate();
await Promise.all([pub.connect(), sub.connect()]);

const parser = { encode: (value) => JSON.stringify(value), decode: (value) => JSON.parse(value) };
const http = createServer();
const io = new Server(http, { adapter: createAdapter(pub, sub, { parser }) });
io.on('connection', (socket) => socket.join('r1'));
await new Promise((resolve) => http.listen(0, '127.0.0.1', resolve));

const client = connect(`http://127.0.0.1:${http.address().port}`, { transports: ['websocket'] });
client.on('from-dart', (data) => {
  if (data.x !== 1) { console.error('FAIL bad data ' + JSON.stringify(data)); process.exit(1); }
  clearTimeout(timer);
  console.log('GOT from-dart');
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
