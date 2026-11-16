# Parte C: Preguntas de Criterio

## 1. En 10 líneas o menos, describe un Golden Path para este servicio: qué incluye, qué dejas fuera a propósito y cómo medirías si los equipos lo usan.

Armaría una plantilla de repositorio lista para clonar (para Go, Python y React) que ya traiga el Dockerfile multistage con usuario no-root, `.gitignore`, `.env.example` y logs en JSON para Cloud Logging.
Por el lado de infraestructura, les daría un módulo de Terraform ya probado que levante Cloud Run (`min=0`), Secret Manager, las Service Accounts con permisos mínimos y la alerta de presupuesto sin que el equipo tenga que escribir IAM desde cero.
El pipeline en Cloud Build vendría preconfigurado en dos archivos: uno para PRs (tests, Gitleaks, Hadolint y Trivy) y otro para `main` que publique con versión fija, firme la imagen con KMS y despliegue por digest con Binary Authorization activo.
Dejo fuera a propósito Kubernetes (GKE), Service Mesh y bases de datos propias por servicio, porque para un servicio de consulta stateless solo meten costo fijo y carga operativa que el equipo no necesita. También dejo fuera que cada equipo arme su propio pipeline a mano o pida permisos por consola.
Para medir si de verdad lo están usando, revisaría cuántos servicios nuevos nacen desde la plantilla vs. repos armados por su cuenta, cuánto tardan desde que crean el repo hasta su primer deploy en producción y cuántas veces piden soporte a DevOps para poder desplegar.

---

## 2. El servicio tiene que consultar un sistema on-premise (SOAP) y un servicio en AWS. ¿Cómo conectas las tres partes de forma segura? Considera costo y riesgo.

**Cómo lo conectaría:**
- **De Cloud Run hacia adentro:** Usaría **Direct VPC Egress** en Cloud Run saliendo hacia nuestra VPC en GCP. Descarté usar *Serverless VPC Access Connectors* porque dejan instancias e2 encendidas cobrando todo el mes aunque no haya tráfico.
- **De GCP al sistema SOAP on-premise:** Levantaría una **HA VPN (Cloud VPN con IPSec y BGP en Cloud Router)** contra el firewall del datacenter. Cuesta alrededor de USD 70 al mes los dos túneles y da buena disponibilidad sin meterse al gasto de un enlace dedicado. Como los servicios SOAP viejos suelen ser lentos y si reciben muchas peticiones de golpe se caen, pondría un timeout corto (3 a 5 segundos), un *circuit breaker* y un caché corto (por ejemplo 1 o 2 minutos en memoria o Memorystore) para que si un ciudadano recarga la página 10 veces seguidas no golpeemos 10 veces al servidor on-premise. Los certificados o credenciales del SOAP los leería desde Secret Manager.
- **De GCP a AWS:** Para la autenticación **descarté guardar llaves estáticas (`AWS_ACCESS_KEY_ID`) en Secret Manager** porque si se filtran son un problema grave. En su lugar usaría **Workload Identity Federation (OIDC)**: la Service Account de Cloud Run usa su token OIDC para asumir un rol en AWS (`AssumeRoleWithWebIdentity`) con credenciales temporales. A nivel de red, si lo que consumimos en AWS es una API por HTTPS, saldría por TLS 1.3 pasando por Cloud NAT (para tener IP fija si del lado de AWS piden filtrar origen). Si es un servicio privado dentro de la VPC de AWS, levantaría otra VPN Site-to-Site IPSec entre AWS y el mismo Cloud Router de GCP.
- **Qué más descarté:** Descarté **Dedicated/Partner Interconnect** y **AWS Direct Connect** porque para un solo servicio de consulta es demasiado caro y toma semanas con el proveedor; solo valdría la pena si ya estuviéramos moviendo tráfico pesado de varios ministerios. Tampoco expondría jamás el SOAP a internet público aunque tuviera IP whitelist.

---

## 3. ¿Qué controles pondrías para que un ambiente de desarrollo no gaste USD 2,000 en un fin de semana?

**Descarté quedarme solo con la alerta de presupuesto por correo**, porque los correos de facturación llegan con retraso y si algo se queda en un ciclo infinito un sábado en la noche, nadie va a ver el correo hasta el lunes cuando ya se gastaron los USD 2,000.

Pondría tres controles prácticos combinados:

1. **Topes duros en los recursos y cuotas del proyecto `dev`:**
   - En Cloud Run dejaría `min_instance_count = 0`, `cpu_idle = true` y un **`max_instance_count` bajo (2 o 3 instancias)**. Con ese tope, aunque un dev deje un loop infinito o hagan pruebas de carga por error todo el fin de semana, 3 instancias no pasan de unos pocos dólares.
   - A nivel de proyecto en GCP aplicaría **Organization Policies y cuotas de API** para bloquear en `dev` cosas que disparan la factura rápido: prohibir GPUs, máquinas grandes de Compute Engine (permitir solo `e2-micro` o `e2-small`), clusters grandes de GKE y poner límite de bytes procesados por query en BigQuery.
2. **Apagado automático fuera de horario:**
   - En `dev` nadie trabaja de madrugada ni domingo. Pondría un job en **Cloud Scheduler** los viernes a las 7:00 PM que apague cualquier VM o instancia de base de datos de desarrollo y las vuelva a encender el lunes a las 6:00 AM.
3. **Presupuesto con corte automático (Pub/Sub + Cloud Run Function):**
   - Configuraría un presupuesto bajo para `dev` (por ejemplo USD 30 o USD 50 al mes) conectado a un tópico de **Pub/Sub**. Si llega al 100%, además de mandar mensaje al chat del equipo, dispara una función que apaga los servicios del proyecto `dev` o desvincula temporalmente la facturación de ese proyecto. Esto lo descartaría en producción porque tiraría el servicio, pero para un ambiente de desarrollo es el seguro más efectivo.
