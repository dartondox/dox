// Runs one scenario with the official socket.io-client against the Dart server.
// Usage: node client.mjs <scenario> <url>
// Exit code 0 means the scenario passed. Errors are printed to stderr.
import { io } from 'socket.io-client';

const [scenario, url] = process.argv.slice(2);
const TIMEOUT_MS = 10000;

function fail(message) {
  console.error(`FAIL ${scenario}: ${message}`);
  process.exit(1);
}

function assert(condition, message) {
  if (!condition) fail(message);
}

function connect(path = '', options = {}) {
  return io(url + path, { reconnection: false, forceNew: true, ...options });
}

function once(emitter, event) {
  return new Promise((resolve) => emitter.once(event, (...args) => resolve(args)));
}

const scenarios = {
  // Connect over websocket only, then emit with ack.
  async 'websocket-only'() {
    const socket = connect('', { transports: ['websocket'] });
    await once(socket, 'connect');
    assert(socket.io.engine.transport.name === 'websocket', 'transport is not websocket');
    const reply = await socket.timeout(3000).emitWithAck('echo', { hello: 'world' });
    assert(reply.hello === 'world', 'bad echo ' + JSON.stringify(reply));
    socket.disconnect();
  },

  // Start with polling, then upgrade to websocket.
  async 'polling-upgrade'() {
    const socket = connect();
    // Read the first transport and wait for 'upgrade' now. On a fast
    // machine the upgrade can be done before 'connect' fires.
    const first = socket.io.engine.transport.name;
    const upgraded = once(socket.io.engine, 'upgrade');
    await once(socket, 'connect');
    assert(first === 'polling', 'first transport is not polling');
    await upgraded;
    assert(socket.io.engine.transport.name === 'websocket', 'upgrade failed');
    const reply = await socket.timeout(3000).emitWithAck('echo', 'after-upgrade');
    assert(reply === 'after-upgrade', 'bad echo after upgrade');
    socket.disconnect();
  },

  // Polling only. Messages, acks and server pings must still work.
  async 'polling-only'() {
    const socket = connect('', { transports: ['polling'] });
    await once(socket, 'connect');
    const replies = await Promise.all([
      socket.timeout(3000).emitWithAck('echo', 1),
      socket.timeout(3000).emitWithAck('echo', 2),
      socket.timeout(3000).emitWithAck('echo', 3),
    ]);
    assert(replies.join(',') === '1,2,3', 'bad replies ' + replies);
    // Wait more than one ping interval, the session must stay alive.
    await new Promise((r) => setTimeout(r, 700));
    assert(socket.connected, 'disconnected while polling');
    assert(socket.io.engine.transport.name === 'polling', 'transport changed');
    socket.disconnect();
  },

  // Server sends on connect, client sends, server answers with an event.
  async 'emit-receive'() {
    const socket = connect();
    const [welcome] = await once(socket, 'welcome');
    assert(welcome.id === socket.id, 'welcome has wrong id');
    socket.emit('message', 'hi', 42, { a: [1, 2] });
    const args = await once(socket, 'message-back');
    assert(JSON.stringify(args) === JSON.stringify(['hi', 42, { a: [1, 2] }]), 'bad args ' + JSON.stringify(args));
    socket.disconnect();
  },

  // Acks in both directions.
  async 'acks'() {
    const socket = connect();
    socket.on('question', (q, callback) => callback(q + '!', 'second'));
    await once(socket, 'connect');
    const sum = await socket.timeout(3000).emitWithAck('sum', [1, 2, 3]);
    assert(sum === 6, 'bad sum ' + sum);
    socket.emit('ask-me');
    const [answer] = await once(socket, 'answer-was');
    assert(JSON.stringify(answer) === JSON.stringify(['hello?!', 'second']), 'bad answer ' + JSON.stringify(answer));
    socket.disconnect();
  },

  // Rooms and broadcast between clients.
  async 'rooms'() {
    const a = connect('', { transports: ['websocket'] });
    const b = connect();
    const c = connect('', { transports: ['websocket'] });
    await Promise.all([once(a, 'connect'), once(b, 'connect'), once(c, 'connect')]);
    await a.emitWithAck('join', 'room1');
    await b.emitWithAck('join', 'room1');
    await c.emitWithAck('join', 'other');
    let aGotSaid = false;
    let cGotSaid = false;
    a.on('said', () => { aGotSaid = true; });
    c.on('said', () => { cGotSaid = true; });
    const bSaid = once(b, 'said');
    a.emit('say', { room: 'room1', text: 'hey' });
    const [said] = await bSaid;
    assert(said.text === 'hey', 'b got wrong text');

    // io.to(room).except(room): a and b are in room1, b is also in vip.
    await b.emitWithAck('join', 'vip');
    const aNews = once(a, 'news');
    let bGotNews = false;
    b.on('news', () => { bGotNews = true; });
    a.emit('news-to', { room: 'room1', except: 'vip' });
    await aNews;

    // Broadcast to all except the sender.
    const bAll = once(b, 'all');
    const cAll = once(c, 'all');
    let aGotAll = false;
    a.on('all', () => { aGotAll = true; });
    a.emit('broadcast-all');
    await Promise.all([bAll, cAll]);

    await new Promise((r) => setTimeout(r, 200));
    assert(!aGotSaid, 'sender got its own room message');
    assert(!cGotSaid, 'socket outside the room got the message');
    assert(!bGotNews, 'except room did not work');
    assert(!aGotAll, 'broadcast went to the sender');
    a.disconnect(); b.disconnect(); c.disconnect();
  },

  // Custom namespace with an auth middleware.
  async 'namespace-auth'() {
    const good = connect('/admin', { auth: { token: 'secret' } });
    await once(good, 'connect');
    const who = await good.timeout(3000).emitWithAck('whoami');
    assert(who.nsp === '/admin' && who.token === 'secret', 'bad whoami ' + JSON.stringify(who));

    const bad = connect('/admin', { auth: { token: 'wrong' } });
    const [error] = await once(bad, 'connect_error');
    assert(error.message === 'unauthorized', 'bad error message ' + error.message);
    assert(error.data && error.data.reason === 'bad token', 'bad error data ' + JSON.stringify(error.data));

    const missing = connect('/nope');
    const [missingError] = await once(missing, 'connect_error');
    assert(missingError.message === 'Invalid namespace', 'bad invalid namespace message');
    good.disconnect(); bad.close(); missing.close();
  },

  // Binary payloads in both directions. argv[4] picks the transport.
  async 'binary'() {
    const transport = process.argv[4] || 'websocket';
    const socket = connect('', { transports: [transport] });
    await once(socket, 'connect');
    const bytes = Buffer.from([0, 1, 2, 250, 255]);
    const reply = await socket.timeout(3000).emitWithAck('binary-echo', { name: 'file', bytes, list: [bytes, 'x'] });
    assert(Buffer.from(reply.bytes).equals(bytes), 'bad bytes back');
    assert(Buffer.from(reply.list[0]).equals(bytes) && reply.list[1] === 'x', 'bad nested bytes');
    socket.emit('send-binary');
    const [data] = await once(socket, 'binary');
    assert(Buffer.from(data).equals(Buffer.from([9, 8, 7])), 'bad server bytes');
    socket.disconnect();
  },

  // Server disconnects us, we reconnect by hand. Then the transport drops and
  // the client reconnects by itself.
  async 'reconnect'() {
    const socket = io(url, { transports: ['websocket'], forceNew: true, reconnectionDelay: 100 });
    await once(socket, 'connect');
    const firstId = socket.id;
    socket.emit('kick');
    const [reason] = await once(socket, 'disconnect');
    assert(reason === 'io server disconnect', 'bad reason ' + reason);
    socket.connect();
    await once(socket, 'connect');
    assert(socket.id !== firstId, 'id did not change');

    const dropped = once(socket, 'disconnect');
    const reconnected = once(socket.io, 'reconnect');
    socket.io.engine.close();
    const [reason2] = await dropped;
    assert(reason2 === 'transport close' || reason2 === 'forced close', 'bad reason ' + reason2);
    await reconnected;
    const reply = await socket.timeout(3000).emitWithAck('echo', 'back');
    assert(reply === 'back', 'echo after reconnect failed');
    socket.disconnect();
  },

  // The client stops answering pings. The server must drop the connection.
  async 'ping-timeout'() {
    const socket = connect('', { transports: ['websocket'] });
    await once(socket, 'connect');
    const engine = socket.io.engine;
    const send = engine._sendPacket.bind(engine);
    engine._sendPacket = (type, ...rest) => {
      if (type !== 'pong') send(type, ...rest);
    };
    const [reason] = await once(socket, 'disconnect');
    assert(reason === 'transport close' || reason === 'ping timeout', 'bad reason ' + reason);
  },

  // Stays connected over many heartbeats.
  async 'heartbeat'() {
    const socket = connect('', { transports: ['websocket'] });
    await once(socket, 'connect');
    await new Promise((r) => setTimeout(r, 1200));
    assert(socket.connected, 'lost connection during heartbeats');
    socket.disconnect();
  },
};

const run = scenarios[scenario];
if (!run) fail('unknown scenario');
const timer = setTimeout(() => fail('timed out'), TIMEOUT_MS);
run().then(() => {
  clearTimeout(timer);
  console.log(`OK ${scenario}`);
  process.exit(0);
}, (error) => fail(error && error.stack ? error.stack : String(error)));
