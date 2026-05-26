# Guía de migración: Floci → AWS real

## Arquitectura objetivo

```
GitHub repo
  ├── express-docker/          # Código de la app Express
  │   └── .github/workflows/
  │       ├── build-and-push.yml    # Build + push a ECR
  │       └── deploy-infra.yml      # Terraform apply en aws-infra/
  └── floci/aws-infra/         # Terraform para la infraestructura AWS
```

## Prerrequisitos

- Cuenta de AWS con permisos para crear recursos
- GitHub repo con OIDC configurado (ya lo tenés: `AWS_ROLE_ARN`)
- Terraform >= 1.10 instalado localmente
- AWS CLI configurado

---

## Paso 1: Crear backend S3 + DynamoDB

Terraform necesita un lugar remoto para guardar el state.

### Opción A — Manual (una sola vez)

```bash
# Variables
BUCKET="floci-terraform-state-$(openssl rand -hex 4)"
REGION="us-east-1"

# Crear bucket S3
aws s3api create-bucket \
  --bucket $BUCKET \
  --region $REGION

# Habilitar versioning
aws s3api put-bucket-versioning \
  --bucket $BUCKET \
  --versioning-configuration Status=Enabled

# Crear tabla DynamoDB para locks
aws dynamodb create-table \
  --table-name floci-terraform-locks \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region $REGION

# Anotar el nombre del bucket
echo "Bucket: $BUCKET"
```

### Opción B — Bootstrap con Terraform (recomendado)

Crear un directorio aparte `aws-infra/bootstrap/` con:

```hcl
# bootstrap/main.tf
resource "aws_s3_bucket" "terraform_state" {
  bucket = "floci-terraform-state-${random_id.suffix.hex}"
}

resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_dynamodb_table" "terraform_locks" {
  name         = "floci-terraform-locks"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"
  attribute {
    name = "LockID"
    type = "S"
  }
}

resource "random_id" "suffix" {
  byte_length = 4
}

output "bucket_name" {
  value = aws_s3_bucket.terraform_state.id
}
```

```bash
cd aws-infra/bootstrap
terraform init
terraform apply   # te muestra el bucket name
```

---

## Paso 2: Agregar backend.tf

Una vez creado el bucket y la tabla, crear `aws-infra/backend.tf`:

```hcl
terraform {
  backend "s3" {
    bucket         = "floci-terraform-state-XXXX"  # reemplazar con el bucket real
    key            = "floci-infra/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "floci-terraform-locks"
    encrypt        = true
  }
}
```

Luego inicializar:
```bash
cd aws-infra
terraform init -migrate   # migra el state local a S3
```

Esto pregunta si querés copiar el state local a S3 — decís que sí.

---

## Paso 3: Actualizar provider.tf para AWS real

Remover todos los endpoints de Floci y las configuraciones `skip_*`, `access_key`, `secret_key`.

Queda así:

```hcl
terraform {
  required_version = ">= 1.10"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.50.0"
    }
  }
}

provider "aws" {
  region = var.region
}
```

---

## Paso 4: Limpiar workarounds de Floci

### 4a. compute/ecs.tf — Quitar lifecycle ignore_changes

Eliminar el bloque (líneas 108-115):

```hcl
# ❌ ELIMINAR
lifecycle {
  ignore_changes = [
    requires_compatibilities,
    execution_role_arn,
    task_role_arn,
  ]
}
```

Y también en el servicio (líneas 163-169):

```hcl
# ❌ ELIMINAR
lifecycle {
  ignore_changes = [
    scheduling_strategy,
    platform_version,
  ]
}
```

### 4b. database/rds-postgres.tf — Agregar storage_encrypted

Agregar después de `storage_type`:

```hcl
storage_encrypted = true
```

Y eliminar el `lifecycle { ignore_changes = [tags, tags_all] }` (AWS real sí persiste tags).

### 4c. Actualizar ECS task definition para AWS real

En `compute/ecs.tf`, actualizar las variables de entorno del contenedor para que apunten al RDS real y obtengan credenciales de forma segura (Secrets Manager o variables):

```hcl
environment = [
  { name = "ENVIRONMENT", value = var.environment },
  { name = "PORT", value = "3000" },
  { name = "DB_HOST", value = ... },   # Endpoint del RDS
  { name = "DB_PORT", value = "5432" },
  { name = "DB_USERNAME", value = ... },
  { name = "DB_PASSWORD", value = ... },  # Ideal: usar secrets
  { name = "DB_NAME", value = ... },
  { name = "DB_LOGGING", value = "true" },
]
```

> **Recomendación**: Usar `aws_secretsmanager_secret` para las credenciales de la BD en lugar de hardcodearlas en el task definition. O usar variables de Terraform marcadas como `sensitive`.

---

## Paso 5: Actualizar dev.tfvars

En `aws-infra/dev.tfvars` ajustar los valores para AWS real:

```hcl
environment = "dev"
project     = "floci"

# ... networking sin cambios ...

# RDS en dev puede ser db.t3.micro para ahorrar
db_instance_class    = "db.t3.micro"
db_allocated_storage = 20
db_username          = "app_user"
db_password          = "un_password_seguro_aqui"

# Imagen de ECR (la que sube build-and-push.yml)
# Inicialmente podés dejar una imagen pública para probar
ecs_app_image         = "nginx:alpine"
ecs_app_cpu           = 256
ecs_app_memory        = 512
ecs_app_desired_count = 1
ecs_app_port          = 3000
```

> **Nota**: Para usar la imagen de ECR, después del primer deploy exitoso cambiás `ecs_app_image` por `$ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/mi-app:latest`.

---

## Paso 6: Crear workflow deploy-infra.yml

Crear `express-docker/.github/workflows/deploy-infra.yml`:

```yaml
name: Deploy AWS Infrastructure

on:
  push:
    branches: [main]
    paths:
      - 'aws-infra/**'

permissions:
  id-token: write
  contents: read

jobs:
  terraform:
    runs-on: ubuntu-24.04
    environment: production
    defaults:
      run:
        working-directory: ./aws-infra

    steps:
      - name: Checkout code
        uses: actions/checkout@v6

      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v6
        with:
          role-to-assume: ${{ secrets.AWS_ROLE_ARN }}
          aws-region: ${{ secrets.AWS_REGION }}

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: "1.10.0"

      - name: Terraform Init
        run: terraform init

      - name: Terraform Format
        run: terraform fmt -check

      - name: Terraform Validate
        run: terraform validate

      - name: Terraform Plan
        run: terraform plan -var-file=dev.tfvars

      - name: Terraform Apply
        run: terraform apply -var-file=dev.tfvars -auto-approve
```

---

## Paso 7: Integrar build-and-push con deploy a ECS

En `build-and-push.yml`, agregar un paso después del push a ECR para forzar un nuevo deploy en ECS:

```yaml
      - name: Deploy to ECS
        run: |
          aws ecs update-service \
            --cluster floci-cluster-dev \
            --service floci-app-dev \
            --force-new-deployment \
            --region ${{ secrets.AWS_REGION }}
```

> **Alternativa más elegante**: Usar `terraform apply -var="ecs_app_image=$REGISTRY/$REPO:$SHA"` para que Terraform actualice el task definition con la imagen exacta recién pusheada.

---

## Paso 8: Configurar secrets en GitHub

| Secret | Dónde obtenerlo |
|---|---|
| `AWS_ROLE_ARN` | IAM → Roles → ARN del rol con OIDC (ya lo tenés) |
| `AWS_REGION` | `us-east-1` o la región que uses |

---

## Paso 9: Primer deploy

```bash
# 1. Migrar state local a S3
cd floci/aws-infra
terraform init -migrate

# 2. Validar que el state se migró bien
terraform state list

# 3. Aplicar contra AWS real (crea toda la infra)
terraform apply -var-file=dev.tfvars

# 4. Verificar que los recursos se crearon
aws ecs list-services --cluster floci-cluster-dev
aws rds describe-db-instances --db-instance-identifier floci-pg-dev
aws elbv2 describe-load-balancers

# 5. Hacer push a main para probar el workflow
git add .
git commit -m "Migrate infra to AWS real"
git push origin main
```

---

## Resumen de cambios

| Archivo | Cambio |
|---|---|
| `aws-infra/backend.tf` | Nuevo — configura S3 + DynamoDB como backend |
| `aws-infra/provider.tf` | Eliminar endpoints Floci, skip_*, credenciales dummy |
| `aws-infra/compute/ecs.tf` | Eliminar `lifecycle ignore_changes`, actualizar env vars |
| `aws-infra/database/rds-postgres.tf` | Agregar `storage_encrypted`, eliminar ignore_changes |
| `.github/workflows/deploy-infra.yml` | Nuevo — Terraform CI/CD |
| `.github/workflows/build-and-push.yml` | Agregar paso de deploy a ECS |
| GitHub Secrets | `AWS_ROLE_ARN` y `AWS_REGION` (ya tenés `AWS_ROLE_ARN`) |

---

## Costos estimados mensuales (dev)

| Recurso | Costo aprox |
|---|---|
| ALB | ~$20 |
| ECS Fargate (0.25 vCPU, 0.5GB) | ~$12 |
| RDS db.t3.micro | ~$15 |
| NAT Gateway (si usás subnets privadas) | ~$32 |
| S3 + DynamoDB (state) | ~$1 |
| **Total** | **~$80/mes** |

> Para ahorrar en dev considerar: usar FARGATE_SPOT, eliminar NAT Gateway usando solo subnets públicas en dev, o apagar RDS cuando no se use.
