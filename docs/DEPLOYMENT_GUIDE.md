# Guía de despliegue: Express.js en AWS con Terraform y GitHub Actions

## Estructura del repositorio

```
express-docker/
├── app/                          # Código de la aplicación Express
│   ├── src/
│   │   ├── index.ts              # Entry point
│   │   ├── constant.ts
│   │   └── entity/
│   │       └── User.ts
│   ├── Dockerfile
│   ├── package.json
│   ├── tsconfig.json
│   └── docker-compose.yml
├── infra/                        # Infraestructura como código (Terraform)
│   ├── environments/
│   │   ├── dev.tfvars            # Variables para entorno dev
│   │   └── prod.tfvars           # Variables para entorno prod
│   ├── modules/                  # Módulos reutilizables
│   ├── api-gateway/              # Módulo API Gateway
│   ├── compute/                  # Módulo ECS + ALB + IAM
│   ├── database/                 # Módulo RDS PostgreSQL
│   ├── messaging/                # Módulo SQS
│   ├── monitoring/               # Módulo CloudWatch
│   ├── networking/               # Módulo VPC + subnets + security groups
│   ├── main.tf                   # Entry point de Terraform
│   ├── provider.tf               # Configuración del provider AWS
│   ├── variables.tf              # Variables globales
│   └── outputs.tf                # Outputs de la infraestructura
├── .github/workflows/
│   ├── build-and-push.yml        # CI/CD: build Docker + push a ECR
│   └── deploy-infra.yml          # CI/CD: Terraform apply
├── docs/
│   └── DEPLOYMENT_GUIDE.md       # Esta guía
└── .gitignore
```

---

## Arquitectura

```
                    GitHub Actions
                   ┌──────────────┐
                   │  build-and-  │
                   │  push.yml    │
                   └──────┬───────┘
                          │ push image
                          ▼
┌──────────┐    deploy    ┌──────────────┐
│  GitHub  │ ───────────► │   AWS ECR    │
│  Repo    │              │  Container   │
│          │              │  Registry    │
│          │              └──────┬───────┘
│          │                     │ new image
│          │                     ▼
│          │              ┌──────────────┐
│          │    infra     │  ECS Service │
│          │ ◄─────────── │  (Fargate)   │
│          │  Terraform   └──────┬───────┘
│          │                     │ connects
│          │                     ▼
│          │              ┌──────────────┐
│          │              │  RDS         │
│          │              │  PostgreSQL  │
│          │              └──────────────┘
└──────────┘
```

---

## Requisitos previos

- Cuenta de AWS activa
- GitHub repo con OIDC configurado para AWS
- Terraform >= 1.10 instalado localmente (opcional, el CI/CD lo ejecuta)
- AWS CLI configurado

---

## Paso 1: Configurar OIDC en AWS IAM

### 1.1 Crear el Identity Provider

1. AWS Console → IAM → Access management → Identity providers
2. Add provider
3. OpenID Connect
4. Provider URL: `https://token.actions.githubusercontent.com`
5. Client ID: `sts.amazonaws.com`
6. Add provider

### 1.2 Crear el Rol IAM para GitHub Actions

1. IAM → Roles → Create role
2. Trusted entity type: Web identity
3. Identity provider: `token.actions.githubusercontent.com`
4. Audience: `sts.amazonaws.com`
5. GitHub organization: `fjmg84` (tu usuario)
6. Repository: `*` (o el nombre exacto del repo)

Permisos necesarios:

| Servicio | Permisos mínimos |
|---|---|
| ECR | `AmazonEC2ContainerRegistryPowerUser` |
| ECS | `AmazonECS_FullAccess` |
| EC2/VPC | `AmazonVPCFullAccess` |
| RDS | `AmazonRDSFullAccess` |
| IAM | `IAMFullAccess` |
| S3 | `AmazonS3FullAccess` (para el backend state) |
| DynamoDB | `AmazonDynamoDBFullAccess` |
| CloudWatch | `CloudWatchFullAccess` |
| SQS | `AmazonSQSFullAccess` |
| ELB | `ElasticLoadBalancingFullAccess` |

> **Alternativa**: Crear una política custom con permisos específicos. Para simplificar al inicio, podés usar `AdministratorAccess` y luego acotar.

### 1.3 Copiar el ARN del Rol

```
arn:aws:iam::624373582708:role/github-actions-deploy-role
```

---

## Paso 2: Crear backend S3 + DynamoDB para Terraform

Terraform necesita un lugar remoto para guardar el estado (state). Se crean dos recursos:

### 2.1 Crear bucket S3

```bash
# El nombre debe ser único global
BUCKET="express-app-terraform-state-$(openssl rand -hex 4)"
echo "Bucket name: $BUCKET"

aws s3api create-bucket \
  --bucket $BUCKET \
  --region us-east-1

aws s3api put-bucket-versioning \
  --bucket $BUCKET \
  --versioning-configuration Status=Enabled
```

### 2.2 Crear tabla DynamoDB

```bash
aws dynamodb create-table \
  --table-name express-app-terraform-locks \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region us-east-1
```

### 2.3 Actualizar backend.tf

Reemplazar los valores en `infra/provider.tf` (dentro del bloque `backend "s3"`):

```hcl
backend "s3" {
  bucket         = "express-app-terraform-state-XXXX"  # el nombre único generado
  key            = "infra/terraform.tfstate"
  region         = "us-east-1"
  dynamodb_table = "express-app-terraform-locks"
  encrypt        = true
}
```

---

## Paso 3: Crear ECR Repository

```bash
aws ecr create-repository \
  --repository-name express/type \
  --region us-east-1
```

El URI del repositorio será:
```
624373582708.dkr.ecr.us-east-1.amazonaws.com/express/type
```

---

## Paso 4: Configurar GitHub Secrets

Ir a **Settings → Secrets and variables → Actions** y agregar:

### Repository Secrets

| Secret | Valor |
|---|---|
| `AWS_ROLE_ARN` | `arn:aws:iam::624373582708:role/github-actions-deploy-role` |
| `AWS_REGION` | `us-east-1` |

### Repository Variables

| Variable | Valor |
|---|---|
| `ECR_REPOSITORY` | `express/type` |

---

## Paso 5: Primer deploy de infraestructura

Antes de hacer push, ejecutar Terraform localmente para verificar que todo funciona:

```bash
cd infra

# Inicializar Terraform (apunta a S3)
terraform init

# Validar la configuración
terraform validate

# Ver el plan
terraform plan -var-file=environments/dev.tfvars

# Aplicar (crea toda la infra)
terraform apply -var-file=environments/dev.tfvars
```

### Lo que crea Terraform:

| Recurso | Nombre ejemplo (dev) |
|---|---|
| VPC | `express-app-vpc-dev` |
| Subnets públicas/privadas | `express-app-subnet-public-*` |
| Security Groups | `express-app-sg-*` |
| Internet Gateway | `express-app-igw-dev` |
| NAT Gateway | `express-app-nat-dev` |
| ALB | `express-app-alb-dev` |
| Target Group | `express-app-tg-dev` |
| ECS Cluster | `express-app-cluster-dev` |
| ECS Task Definition | `express-app-app-dev` |
| ECS Service | `express-app-app-dev` |
| RDS PostgreSQL | `express-app-pg-dev` |
| API Gateway | `express-app-api-dev` |
| SQS Queues | `express-app-orders-dev`, `express-app-notifications-dev` |
| IAM Roles | `express-app-ecs-execution-dev`, `express-app-ecs-task-dev` |
| CloudWatch Log Groups | `/ecs/express-app-app-dev`, `api-gateway` |
| CloudWatch Alarms | Según configuración |

### Outputs importantes

Al finalizar, Terraform muestra:
- `alb_dns_name` — DNS del ALB para acceder a la app
- `db_endpoint` — Endpoint de RDS
- `ecs_cluster_name` — Nombre del cluster ECS
- `api_gateway_url` — URL de API Gateway

---

## Paso 6: Workflows

### build-and-push.yml

Se activa con cambios en `app/**`. Hace:
1. Checkout
2. AWS OIDC login
3. Login a ECR
4. Build Docker image desde `./app`
5. Tag con `latest` + commit SHA
6. Push a ECR
7. Actualiza ECS service (force new deployment)

### deploy-infra.yml

Se activa con cambios en `infra/**`. Hace:
1. Checkout
2. AWS OIDC login
3. Terraform init
4. Terraform fmt -check
5. Terraform validate
6. Terraform plan
7. Terraform apply

---

## Paso 7: Hacer commit y push

```bash
git add .
git commit -m "feat: mono-repo with app/ and infra/ for AWS deployment"
git push origin feat/mono-repo-infra
```

Crear PR a `main` y mergear.

---

## CI/CD Flow completo

```
Push a main (cambios en app/)
  → build-and-push.yml
    → Build Docker image
    → Push a ECR
    → Force new ECS deployment

Push a main (cambios en infra/)
  → deploy-infra.yml
    → Terraform plan
    → Terraform apply
```

---

## Acceder a la aplicación

Una vez desplegada:

```bash
# Obtener el DNS del ALB
terraform output -state=infra/terraform.tfstate alb_dns_name

# Probar la app
curl http://<alb-dns-name>/
```

O a través de API Gateway:

```bash
terraform output -state=infra/terraform.tfstate api_gateway_url
```

---

## Gestión de entornos

- **dev**: Entorno de desarrollo (1 AZ, 1 tarea ECS, RDS micro)
- **prod**: Entorno de producción (2 AZs, 2 tareas ECS, RDS medium, Multi-AZ)

Para aplicar en prod:

```bash
cd infra
terraform apply -var-file=environments/prod.tfvars
```

---

## Buenas prácticas

### Seguridad
- Usar OIDC en vez de Access Keys
- No hardcodear credenciales en los .tf (usar variables sensitive)
- Proteger la rama main con branch protection
- Configurar lifecycle policy en ECR para limpiar imágenes viejas

### Mantenimiento
- Revisar periódicamente los logs de GitHub Actions
- Monitorear métricas de CloudWatch
- Backup automático de RDS (configurado en prod)
- El state de Terraform está versionado en S3 (se puede recuperar)

### Costos
- En dev usar FARGATE_SPOT para ahorrar
- Apagar RDS en dev cuando no se use
- El NAT Gateway es uno de los costos fijos más altos (~$32/mes)

---

## Troubleshooting

### Error: Terraform no encuentra el backend S3
**Causa:** El bucket S3 o tabla DynamoDB no existen.
**Solución:** Crearlos según el Paso 2.

### Error: Access Denied al hacer push a ECR
**Causa:** El rol IAM no tiene permisos.
**Solución:** Verificar que el rol tenga `AmazonEC2ContainerRegistryPowerUser`.

### Error: ECS service no actualiza
**Causa:** El cluster o service name no coincide.
**Solución:** Verificar los nombres en el workflow vs los creados por Terraform (`terraform output`).

### Error: docker build no encuentra archivos
**Causa:** El workflow ejecuta desde la raíz pero el Dockerfile está en `app/`.
**Solución:** Verificar que el `working-directory: ./app` está configurado en el workflow.

---

## Referencias

- [GitHub Actions: Configure AWS Credentials](https://github.com/aws-actions/configure-aws-credentials)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest)
- [AWS ECS Fargate](https://aws.amazon.com/fargate/)
- [Terraform S3 Backend](https://developer.hashicorp.com/terraform/language/settings/backends/s3)
