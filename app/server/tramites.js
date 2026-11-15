/**
 * Simula el "sistema de tramites" del ministerio.
 */

export const ID_TRAMITE_REGEX = /^TR-\d{6}$/;

const TRAMITES = {
  'TR-000123': { estado: 'RECIBIDO', etapa: 'Recepción de documentos', actualizado: '2026-11-10' },
  'TR-000456': { estado: 'EN_REVISION', etapa: 'Revisión técnica', actualizado: '2026-11-12' },
  'TR-000789': { estado: 'APROBADO', etapa: 'Listo para retirar', actualizado: '2026-11-13' },
  'TR-000999': { estado: 'RECHAZADO', etapa: 'Documentación incompleta', actualizado: '2026-11-11' },
};

/**
 * @param {string} id      Número de trámite ya validado (TR-XXXXXX).
 * @param {string} apiKey  Credencial para el sistema de trámites.
 * @returns {Promise<object|null>}
 */
export async function consultarTramite(id, apiKey) {
  if (!apiKey) {
    throw new Error('API_KEY no configurada');
  }
  const tramite = TRAMITES[id];
  return tramite ? { id, ...tramite } : null;
}
