import { useState } from 'react';

const ETIQUETAS = {
  RECIBIDO: 'Recibido',
  EN_REVISION: 'En revisión',
  APROBADO: 'Aprobado',
  RECHAZADO: 'Rechazado',
};

export default function App() {
  const [numero, setNumero] = useState('');
  const [tramite, setTramite] = useState(null);
  const [error, setError] = useState('');
  const [cargando, setCargando] = useState(false);

  async function consultar(e) {
    e.preventDefault();
    setError('');
    setTramite(null);
    setCargando(true);
    try {
      const res = await fetch(`/api/tramites/${encodeURIComponent(numero.trim())}`);
      const data = await res.json();
      if (!res.ok) throw new Error(data.error || 'Error al consultar');
      setTramite(data);
    } catch (err) {
      setError(err.message);
    } finally {
      setCargando(false);
    }
  }

  return (
    <main className="contenedor">
      <h1>Consulta de estado de trámite</h1>
      <p className="subtitulo">Ministerio de Trámites Ciudadanos</p>

      <form onSubmit={consultar}>
        <label htmlFor="numero">Número de trámite</label>
        <div className="fila">
          <input
            id="numero"
            value={numero}
            onChange={(e) => setNumero(e.target.value)}
            placeholder="TR-000123"
            required
          />
          <button type="submit" disabled={cargando}>
            {cargando ? 'Consultando…' : 'Consultar'}
          </button>
        </div>
      </form>

      {error && <p className="error">{error}</p>}

      {tramite && (
        <section className={`resultado estado-${tramite.estado.toLowerCase()}`}>
          <h2>{tramite.id}</h2>
          <p><strong>Estado:</strong> {ETIQUETAS[tramite.estado] ?? tramite.estado}</p>
          <p><strong>Etapa:</strong> {tramite.etapa}</p>
          <p><strong>Última actualización:</strong> {tramite.actualizado}</p>
        </section>
      )}
    </main>
  );
}
