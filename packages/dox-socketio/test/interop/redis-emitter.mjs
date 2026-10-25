// Sends events to the Dart server with the official @socket.io/redis-emitter
// (msgpack, the default).
// Usage: node redis-emitter.mjs <redisUrl>
// Room r1 gets: 'all', {bin: Buffer[1,2,3]}, 'joined', then a disconnect.
// Room r2 gets only 'all'.
import { Emitter } from '@socket.io/redis-emitter';
import { createClient } from 'redis';

const [redisUrl] = process.argv.slice(2);
const client = createClient({ url: redisUrl });
await client.connect();

const emitter = new Emitter(client);
emitter.emit('news', 'all');
emitter.to('r1').emit('news', { bin: Buffer.from([1, 2, 3]) });
emitter.to('r1').socketsJoin('joined');
emitter.to('joined').emit('news', 'joined');
emitter.to('joined').disconnectSockets();
await client.quit();
console.log('SENT');
