import express from 'express';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { consultarTramite, ID_TRAMITE_REGEX } from './tramites.js';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const WEB_DIST = path.join(__dirname, '..', 'dist');

/**
 * Crea la aplicación Express.
 * Se separa de index.js para poder probarla sin abrir un puerto fijo.
 *
 * @param {object} config
 * @param {string} config.apiKey   Valor sensible leído desde Secret Manager (nunca se expone).
 * @param {string} config.version  Versión de la imagen desplegada (SemVer o SHA).
 */
export function createApp({ apiKey, version }) {
  const app = express();

  app.disable('x-powered-by');

  // Cabeceras de seguridad básicas (sin dependencias extra).
  app.use((req, res, next) => {
    res.set({
      'X-Content-Type-Options': 'nosniff',
      'X-Frame-Options': 'DENY',
      'Referrer-Policy': 'no-referrer',
    });
    next();
  });

  // Log estructurado en JSON: Cloud Logging interpreta "severity" y "httpRequest".
  app.use((req, res, next) => {
    const inicio = process.hrtime.bigint();
    res.on('finish', () => {
      const ms = Number(process.hrtime.bigint() - inicio) / 1e6;
      console.log(JSON.stringify({
        severity: res.statusCode >= 500 ? 'ERROR' : 'INFO',
        message: `${req.method} ${req.path} ${res.statusCode}`,
        httpRequest: {
          requestMethod: req.method,
          requestUrl: req.originalUrl,
          status: res.statusCode,
          latency: `${(ms / 1000).toFixed(3)}s`,
          userAgent: req.get('user-agent'),
        },
        version,
      }));
    });
    next();
  });

  // Health check: confirma que el secreto se cargó, sin revelar su valor.
  app.get('/health', (req, res) => {
    res.json({ status: 'ok', version, secretConfigured: Boolean(apiKey) });
  });

  // Consulta de estado de trámite.
  app.get('/api/tramites/:id', async (req, res) => {
    const id = req.params.id.toUpperCase();
    if (!ID_TRAMITE_REGEX.test(id)) {
      return res.status(400).json({ error: 'Formato inválido. Ejemplo: TR-000123' });
    }
    const tramite = await consultarTramite(id, apiKey);
    if (!tramite) {
      return res.status(404).json({ error: `No se encontró el trámite ${id}` });
    }
    return res.json(tramite);
  });

  // Frontend React compilado (solo existe dentro de la imagen o tras `npm run build`).
  app.use(express.static(WEB_DIST, { maxAge: '1h', index: 'index.html' }));

  return app;
}
