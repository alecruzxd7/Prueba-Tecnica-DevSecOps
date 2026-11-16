# Parte C: Preguntas de Criterio — Ingeniero DevOps Senior

## 1. Golden Path para este servicio
1. **Qué incluye:** Un repositorio plantilla (*template*) para Go, Python y React con Dockerfile multistage *distroless* no-root, `.gitignore` y `.env.example`.
2. **Infraestructura estandarizada:** Un módulo versionado de Terraform que aprovisiona Cloud Run (`min=0`), Secret Manager, Service Accounts de mínimo privilegio y alertas de presupuesto.
3. **Pipeline llave en mano:** Workflows reutilizables de Cloud Build con validaciones obligatorias en PR (Gitleaks, Hadolint, tests, Trivy) y despliegue en `main` por digest inmutable (`@sha256`).
4. **Seguridad por defecto:** Firma criptográfica con Cloud KMS y verificación con Binary Authorization antes de admitir cualquier revisión en Cloud Run, más logs estructurados en JSON.
5. **Qué dejo fuera a propósito (y descarté):** Descarté GKE e Istio/Service Mesh por sobrecosto y carga operativa para una API *stateless*; dejo fuera bases de datos dedicadas, pipelines a medida por equipo y cambios manuales en consola.
6. **Métricas de adopción y éxito:** Porcentaje de servicios en producción nacidos del *template* (meta >85%), tiempo desde la creación del repo hasta el primer deploy en producción (<30 min), proporción de despliegues vía pipeline vs. *break-glass* y encuesta trimestral de fricción (DX) a los equipos de desarrollo.

---

## 2. Conectividad segura: Cloud Run ↔ Sistema On-Premise (SOAP) ↔ AWS

### Qué haría y por qué
1. **Salida privada desde Cloud Run:** Configuraría **Direct VPC Egress** desde Cloud Run hacia una subred de una Shared VPC en GCP, forzando que el tráfico hacia rangos privados salga por la VPC sin pagar instancias fijas de *Serverless VPC Access Connector*.
2. **Tramo GCP ↔ On-Premise (SOAP):**
   - **Red:** **HA VPN (Cloud VPN con dos túneles IPSec activos/activos y BGP dinámico con Cloud Router)** entre la VPC de GCP y el firewall perimetral del datacenter gubernamental (~USD 73/mes, SLA 99.99%).
   - **Aplicación y seguridad:** Como los sistemas SOAP legacy suelen ser frágiles y lentos, colocaría un adaptador interno (o Envoy/Apigee interno) con **mTLS**, timeouts estrictos (3–5 s), *circuit breaker* y caché de corto plazo en Memorystore/en memoria para no saturar el backend on-premise ante picos ciudadanos. Las credenciales WS-Security/certificados vivirían en **Secret Manager**.
3. **Tramo GCP ↔ AWS:**
   - **Identidad (cero llaves estáticas):** Usaría **Workload Identity Federation cruzada (OIDC)**: Cloud Run presenta el token OIDC de `sa-tramites-run` a AWS STS (`AssumeRoleWithWebIdentity`) para asumir un IAM Role en AWS con permisos mínimos y credenciales temporales de 15 minutos.
   - **Red:** Si el servicio en AWS es un endpoint HTTPS (API Gateway/ALB), saldría por **TLS 1.3** autenticado con IAM SigV4 y restringido por IP de **Cloud NAT** estática + AWS WAF. Si es un recurso privado (RDS/ECS interno), levantaría un segundo par de túneles **Site-to-Site IPSec VPN con BGP** entre el *Virtual Private Gateway* de AWS y el *Cloud Router* de GCP.

### Qué descarté y por qué
- **Dedicated / Partner Interconnect y AWS Direct Connect (de entrada):** Los descarté para el lanzamiento porque implican meses de provisión con telcos y cientos de dólares mensuales fijos; solo se justifican si el tráfico sostenido supera varios Gbps o requiere latencia determinística sub-10ms.
- **Exponer el SOAP on-premise a internet con IP Whitelisting:** Descartado por riesgo alto de seguridad en sistemas legacy (XML External Entity, falta de parches).
- **Guardar `AWS_ACCESS_KEY_ID` / `AWS_SECRET` estáticas en Secret Manager:** Descartado porque las llaves IAM de larga vida son el vector número uno de filtración; OIDC elimina el secreto estático por completo.

---

## 3. Controles para evitar que `dev` gaste USD 2,000 en un fin de semana

Una sola barrera no basta; aplicaría **tres capas de defensa**:

1. **Límites duros en tiempo de ejecución y Cuotas (Prevención — impiden el gasto antes de que ocurra):**
   - En Cloud Run (`dev`): `min_instance_count = 0`, **`max_instance_count = 3`**, `cpu_idle = true` y concurrencia de 80 (incluso ante un bucle infinito o un ataque de tráfico el sábado por la noche, 3 instancias con tope de CPU gastan menos de USD 5 en todo el fin de semana).
   - **Organization Policies y Quotas en el proyecto `dev`:** Bloquear la creación de recursos costosos (`constraints/compute.restrictVmSku` permitiendo solo series `e2-micro`/`e2-small`, denegar GPUs/TPUs, prohibir IPs públicas innecesarias y limitar `maximumBytesBilled` por consulta en BigQuery).
   - **CI/CD con Infracost o validación en PR:** Bloquear en el Pull Request cualquier cambio de Terraform en `dev` que suba `max_instance_count`, cambie `min_instance_count > 0` o agregue instancias dedicadas.
2. **Apagado programado (Higiene fuera de horario laboral):**
   - Un job de **Cloud Scheduler** (viernes 19:00 a lunes 06:00, hora de El Salvador) que detenga instancias de Compute Engine/Cloud SQL de desarrollo y limpie artefactos temporales, más *cleanup policies* en Artifact Registry (conservar solo las últimas 5 imágenes).
3. **Presupuesto con *Circuit Breaker* automático (Detección y corte):**
   - **Cloud Billing Budget** mensual bajo en `dev` (ej. USD 30) con umbrales al 50%, 80% y 100% conectado a un tópico de **Pub/Sub** que dispara una **Cloud Run Function**. Si el gasto de `dev` supera el 100%, la función envía alerta al canal de guardia de SRE y **ejecuta contención automática** (deshabilitar temporalmente los servicios costosos o desvincular la cuenta de facturación del proyecto `dev`).

### Qué descarté y por qué
- **Confiar solo en alertas de presupuesto por correo electrónico:** Los datos de facturación tienen latencia y nadie revisa correos de alertas un domingo en la madrugada; sin cuotas duras (`max_instances`) ni *circuit breaker* por Pub/Sub, el lunes a las 8:00 AM el gasto ya ocurrió.
- **Aplicar apagado automático por presupuesto en producción:** El *kill-switch* que desvincula facturación solo se aplica en `dev`/`sandbox`; en producción provocaría una caída total de un servicio ciudadano.
