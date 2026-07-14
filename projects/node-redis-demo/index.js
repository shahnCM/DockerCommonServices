// node-redis-demo
// Run inside the workstation:  npm install && npm start
// mise (see .mise.toml) pins this project to Node 20 even if the
// workstation's global default is a different version.

import http from 'node:http';
import { createClient } from 'redis';

const REDIS_HOST = process.env.REDIS_HOST || 'redis-7';
const PORT = process.env.PORT || 3000;

const redis = createClient({ url: `redis://${REDIS_HOST}:6379` });
redis.on('error', (err) => console.error('Redis error:', err.message));
await redis.connect();

const server = http.createServer(async (req, res) => {
  // same counter key the PHP demo uses — proves both runtimes
  // are hitting the *same* redis-7 container over the `common` network
  const hits = await redis.incr('php-demo:hits');
  res.writeHead(200, { 'Content-Type': 'application/json' });
  res.end(JSON.stringify({
    message: 'hello from node',
    node_version: process.version,
    shared_hits_with_php_demo: hits,
  }, null, 2));
});

server.listen(PORT, '0.0.0.0', () => {
  console.log(`node-redis-demo listening on 0.0.0.0:${PORT} (redis: ${REDIS_HOST})`);
});
