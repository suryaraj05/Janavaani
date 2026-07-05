import { loadEnv } from '@pp/schema';
loadEnv();
import type { Server } from 'node:http';
import { initFirebase } from './firebase.js';
import { createApp } from './app.js';
import { getEnrichWorkerUrl } from './config.js';

initFirebase();

const app = createApp();
const port = Number(process.env.INTAKE_PORT ?? process.env.PORT) || 8080;

let server: Server | undefined;

function start(): void {
  server = app.listen(port, () => {
    console.log(`intake-api listening on port ${port}`);
    console.log(`enrich-worker URL: ${getEnrichWorkerUrl()}`);
  });
  server.on('error', (err: NodeJS.ErrnoException) => {
    if (err.code === 'EADDRINUSE') {
      console.error(`Port ${port} already in use — intake-api not restarted`);
      return;
    }
    throw err;
  });
}

function shutdown(): void {
  server?.close(() => process.exit(0));
}

process.on('SIGTERM', shutdown);
process.on('SIGINT', shutdown);

start();

export default app;
