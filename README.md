# Lista de Tareas Simple - Proyecto DevOps ES3

Aplicación web mínima que permite crear, listar, actualizar y eliminar tareas.
Implementa un flujo DevOps completo: Git, CI/CD, contenedores Docker, Infraestructura como Código (Terraform + AWS), monitoreo, logging y seguridad.

## Tecnologías

- Node.js 18 + Express
- PostgreSQL 15
- Docker + Docker Compose
- GitHub Actions (CI/CD)
- Terraform (AWS EC2, SNS, CloudWatch, IAM)
- AWS CloudTrail (trazabilidad manual)
- Checkov (escaneo de seguridad IaC)

## Estructura del proyecto

```text0
/
├── app/                  # Código fuente
├── tests/                # Pruebas automatizadas (Jest)
├── .github/workflows/    # Pipeline CI/CD con Checkov y Terraform
├── docker/               # Dockerfile y docker-compose
├── infra/                # Terraform (IaC) para ES3
│   ├── main.tf           # EC2, SG, IAM (LabRole), SNS, CloudWatch, Log Group
│   ├── variables.tf
│   ├── provider.tf
│   └── outputs.tf
├── docs/                 # Informe y evidencias
└── README.md

## Ejecución local
Clonar el repositorio.

Crear archivo .env con las variables:

env
DB_HOST=localhost
DB_PORT=5432
DB_USER=todo_user
DB_PASSWORD=todo_pass
DB_NAME=todo_db
PORT=3000
Levantar con Docker Compose:

bash
docker-compose -f docker/docker-compose.yml up -d
Acceder a http://localhost:3000/tareas

Pipeline CI/CD
CI (test-and-security): se ejecuta en cada push y pull request a main. Corre npm ci, npm test, npm run lint, Checkov (escaneo de seguridad de Terraform) y terraform validate.

CD (deploy): se ejecuta al hacer push a main. Configura credenciales AWS desde secrets y ejecuta terraform plan y terraform apply para crear la infraestructura.

Infraestructura como Código (ES3)
La infraestructura se declara en infra/ y se despliega automáticamente desde GitHub Actions. Recursos creados:

## Recurso	Propósito	Criterio ES3

Security Group	Restringe SSH a IP del desarrollador; abre puerto 3000	10
Instancia EC2 (t3.micro)	Servidor de la aplicación	—
IAM Instance Profile (LabRole)	Mínimo privilegio (rol preexistente del Learner Lab)	8
SNS Topic + Suscripción email	Notificaciones de alarmas	2
Alarma CloudWatch (CPU > 70%)	Detección temprana de incidentes	2
CloudWatch Log Group	Centralización de logs de la app	1
CloudTrail (manual)	Trazabilidad de acciones en la cuenta	3
Justificación de métricas y logs (Criterio 4)
Métrica/Log	Justificación
CPUUtilization (EC2)	Es el indicador principal de saturación del servidor. Un pico sostenido >70% indica que la instancia no podrá responder a los usuarios, probablemente por un bucle en el código o un ataque. La alarma permite detectarlo proactivamente.
CloudWatch Log Group /aws/ec2/todo-app-es3-*	Centraliza los logs de la aplicación. Permite buscar errores específicos y correlacionarlos con las métricas de CPU.
CloudTrail Event History	Requerido para auditar quién creó o modificó recursos (Security Groups, instancias). Sin esto no hay trazabilidad forense ante incidentes de seguridad.
Matriz de trazabilidad de pruebas (Criterio 7)
Requerimiento	Prueba automatizada	Herramienta
La app responde en HTTP :3000	test_app_running (Jest + Supertest)	GitHub Actions
El código Terraform no tiene configuraciones inseguras	Escaneo Checkov	GitHub Actions
La sintaxis de Terraform es válida	terraform validate	GitHub Actions
El pipeline solo despliega si las pruebas pasan	needs: test-and-security	GitHub Actions
Limitaciones del entorno Learner Lab

## Debido a las políticas de seguridad (SCP) del laboratorio, no fue posible:

Crear roles IAM personalizados (se usó LabRole preexistente).

Crear el bucket S3 y CloudTrail vía Terraform por bloqueo de s3:GetBucketObjectLockConfiguration.

Configurar cifrado KMS en el Log Group.

El CloudTrail y su bucket S3 se crearon manualmente desde la consola de AWS para demostrar la trazabilidad. En un entorno de producción, estos recursos se declararían en Terraform con las configuraciones avanzadas correspondientes.

## Secretos necesarios en GitHub
AWS_ACCESS_KEY_ID

AWS_SECRET_ACCESS_KEY

AWS_SESSION_TOKEN

ALERT_EMAIL

MY_IP

## Roles del equipo
Johnny Valladares: Líder DevOps / IaC

Sebastián Gallardo: Desarrollo / Contenedores

Benjamín Castro: QA / Documentación

## Reflexión final del equipo
La implementación de monitoreo y seguridad en un entorno Cloud educativo presentó desafíos por las restricciones del Learner Lab, pero permitió comprender la importancia de la trazabilidad (CloudTrail), la detección temprana (alarmas) y el mínimo privilegio (IAM). El pipeline automatizado con Checkov y Terraform validate demuestra que la seguridad puede integrarse desde etapas tempranas del desarrollo, reduciendo riesgos antes de llegar a producción.