const http = require('node:http');

function createServer() {
  return http.createServer((req, res) => {
    const routes = {
      '/': { message: 'Hello from the Jenkins EC2 classroom!', version: process.env.APP_VERSION || 'local' },
      '/health': { status: 'ok' }
    };
    const body = Object.hasOwn(routes, req.url) ? routes[req.url] : undefined;
    res.writeHead(body ? 200 : 404, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify(body || { error: 'Not found' }));
  });
}

if (require.main === module) {
  const server = createServer();
  server.listen(Number(process.env.PORT || 3000), '0.0.0.0', () => console.log('Application listening'));
  for (const signal of ['SIGTERM', 'SIGINT']) {
    process.on(signal, () => server.close(() => process.exit(0)));
  }
}

module.exports = { createServer };
