import { createApp } from './app.js';

const PORT = Number(process.env.PORT) || 8080;
const VERSION = process.env.APP_VERSION || 'dev';
const API_KEY = process.env.API_KEY;

// Fail fast: si el secreto no llegó, la revisión de Cloud Run no debe recibir tráfico.
if (!API_KEY) {
  console.error(JSON.stringify({ severity: 'CRITICAL', message: 'API_KEY no está definida. Abortando.' }));
  process.exit(1);
}

const app = createApp({ apiKey: API_KEY, version: VERSION });

const server = app.listen(PORT, () => {
  console.log(JSON.stringify({ severity: 'INFO', message: `tramites-app ${VERSION} escuchando en :${PORT}` }));
});

// Cloud Run envía SIGTERM antes de apagar una instancia: cerramos conexiones limpiamente.
process.on('SIGTERM', () => {
  console.log(JSON.stringify({ severity: 'INFO', message: 'SIGTERM recibido, cerrando servidor' }));
  server.close(() => process.exit(0));
});
