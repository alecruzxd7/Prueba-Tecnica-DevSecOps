import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { createApp } from './app.js';

const API_KEY_FALSA = 'clave-de-prueba';
let server;
let baseUrl;

before(async () => {
  const app = createApp({ apiKey: API_KEY_FALSA, version: 'test' });
  await new Promise((resolve) => {
    server = app.listen(0, resolve); // puerto aleatorio libre
  });
  baseUrl = `http://127.0.0.1:${server.address().port}`;
});

after(() => server.close());

test('GET /health responde ok y no expone el secreto', async () => {
  const res = await fetch(`${baseUrl}/health`);
  const body = await res.json();
  assert.equal(res.status, 200);
  assert.deepEqual(body, { status: 'ok', version: 'test', secretConfigured: true });
  assert.ok(!JSON.stringify(body).includes(API_KEY_FALSA));
});

test('GET /api/tramites/:id devuelve un trámite existente', async () => {
  const res = await fetch(`${baseUrl}/api/tramites/TR-000456`);
  const body = await res.json();
  assert.equal(res.status, 200);
  assert.equal(body.id, 'TR-000456');
  assert.equal(body.estado, 'EN_REVISION');
});

test('GET /api/tramites/:id acepta minúsculas', async () => {
  const res = await fetch(`${baseUrl}/api/tramites/tr-000123`);
  assert.equal(res.status, 200);
});

test('GET /api/tramites/:id devuelve 404 si no existe', async () => {
  const res = await fetch(`${baseUrl}/api/tramites/TR-111111`);
  assert.equal(res.status, 404);
});

test('GET /api/tramites/:id devuelve 400 con formato inválido', async () => {
  const res = await fetch(`${baseUrl}/api/tramites/hola`);
  assert.equal(res.status, 400);
});

test('Cabeceras de seguridad presentes y sin X-Powered-By', async () => {
  const res = await fetch(`${baseUrl}/health`);
  assert.equal(res.headers.get('x-content-type-options'), 'nosniff');
  assert.equal(res.headers.get('x-powered-by'), null);
});
