# Despliegue Automatizado: Express.js + Docker → AWS ECR con GitHub Actions

## Objetivo

Automatizar la creación de imágenes Docker en AWS ECR cada vez que se hace push a la rama `main` del repositorio.

---

## Arquitectura del Sistema

```
┌─────────────┐    push main    ┌──────────────────┐
│   GitHub    │ ──────────────► │  GitHub Actions  │
│ Repository  │                 │   (CI/CD)        │
└─────────────┘                 └────────┬─────────┘
                                         │ OIDC
                                         ▼
┌──────────────────┐     push image     ┌────────────┐
│    AWS ECR       │ ◄───────────────── │  AWS IAM   │
│ express/type     │                    │   OIDC     │
└──────────────────┘                    │   Role     │
                                        └────────────┘
```

---

## Requisitos Previos

- Cuenta de AWS activa
- Repositorio en GitHub (`fjmg84/express-deploy-AWS-farget`)
- AWS CLI configurada con perfil adecuado
- Docker instalado localmente (opcional, para pruebas)

---

## Paso 1: Configuración de OIDC Provider en AWS IAM

### 1.1 Crear el Identity Provider

1. Ir a **AWS Console → IAM → Access management → Identity providers**
2. Click en **Add provider**
3. Seleccionar **OpenID Connect**
4. Configurar:

| Campo | Valor |
|-------|-------|
| Provider URL | `https://token.actions.githubusercontent.com` |
| Client ID | `sts.amazonaws.com` |
| Thumbprint | Dejar vacío (AWS lo calcula automáticamente) |

5. Click en **Add provider**

### 1.2 Crear el Rol IAM para GitHub Actions

1. Ir a **AWS Console → IAM → Access management → Roles**
2. Click en **Create role**
3. Seleccionar **Trusted entity type**: Web identity
4. Configurar:

| Campo | Valor |
|-------|-------|
| Identity provider | `https://token.actions.githubusercontent.com` |
| Audience | `sts.amazonaws.com` |
| GitHub organization | `fjmg84` |
| Repository | `express-deploy-AWS-farget` (o `*` para todos) |

5. Click en **Next**
6. En permisos, buscar y seleccionar: **`AmazonEC2ContainerRegistryPowerUser`**
7. Click en **Next**
8. Nombre del rol: `github-actions-ecr-deploy`
9. Descripción (opcional): `Role for GitHub Actions to push Docker images to ECR`
10. Click en **Create role**

### 1.3 Copiar el ARN del Rol

Una vez creado, copiar el ARN del rol (necesario para los secrets de GitHub):

```
arn:aws:iam::624373582708:role/github-actions-ecr-deploy
```

---

## Paso 2: Crear Repository en AWS ECR

### 2.1 Crear el Repository

1. Ir a **AWS Console → Amazon ECR → Repositories**
2. Click en **Create repository**
3. Configurar:

| Campo | Valor |
|-------|-------|
| Visibility settings | Private |
| Repository name | `express/type` |
| Tag immutability | Disabled (recomendado) |

4. Click en **Create repository**

### 2.2 Copiar el URI del Repository

En la página del repository, copiar el URI:

```
624373582708.dkr.ecr.sa-east-1.amazonaws.com/express/type
```

---

## Paso 3: Configurar GitHub Environments y Secrets

### 3.1 Crear Environment `production`

1. Ir al repositorio en GitHub: **Settings → Environments → New environment**
2. Nombre: `production`
3. Opcional: Configurar **Deployment branch policy** para proteger la rama `main`

### 3.2 Añadir Environment Secrets

Dentro del environment `production`:

1. Ir a **Environment secrets → Add secret**

| Secret Name | Value |
|------------|-------|
| `AWS_ROLE_ARN` | `arn:aws:iam::624373582708:role/github-actions-ecr-deploy` |
| `AWS_REGION` | `sa-east-1` |
| `ECR_REPOSITORY` | `express/type` |

### 3.3 Añadir Environment Variables

Dentro del environment `production`:

1. Ir a **Environment variables → Add variable**

| Variable Name | Value |
|--------------|-------|
| `AWS_REGION` | `sa-east-1` |
| `ECR_REPOSITORY` | `express/type` |

---

## Paso 4: Workflow de GitHub Actions

El archivo `.github/workflows/build-and-push.yml` contiene la configuración del pipeline CI/CD.

### Contenido completo del workflow

```yaml
name: Build and Push to ECR

on:
  push:
    branches:
      - main

permissions:
  id-token: write
  contents: read

jobs:
  build-and-push:
    runs-on: ubuntu-latest
    environment: production

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.AWS_ROLE_ARN }}
          aws-region: ${{ secrets.AWS_REGION }}

      - name: Login to Amazon ECR
        id: login-ecr
        uses: aws-actions/amazon-ecr-login@v2

      - name: Build Docker image
        run: docker build -t ${{ vars.ECR_REPOSITORY }}:latest .

      - name: Tag images
        run: |
          docker tag ${{ vars.ECR_REPOSITORY }}:latest \
            ${{ steps.login-ecr.outputs.registry }}/${{ vars.ECR_REPOSITORY }}:latest
          docker tag ${{ vars.ECR_REPOSITORY }}:latest \
            ${{ steps.login-ecr.outputs.registry }}/${{ vars.ECR_REPOSITORY }}:${{ github.sha }}

      - name: Push images to ECR
        run: |
          docker push ${{ steps.login-ecr.outputs.registry }}/${{ vars.ECR_REPOSITORY }}:latest
          docker push ${{ steps.login-ecr.outputs.registry }}/${{ vars.ECR_REPOSITORY }}:${{ github.sha }}
```

### Explicación del workflow

| Paso | Descripción |
|------|-------------|
| `checkout` | Descarga el código del repositorio |
| `configure-aws-credentials` | Autenticación OIDC con AWS usando el rol IAM |
| `amazon-ecr-login` | Login en ECR para poder hacer push |
| `docker build` | Construye la imagen Docker |
| `docker tag` | Etiqueta la imagen con `latest` y el commit SHA |
| `docker push` | Sube ambas imágenes a ECR |

### Comportamiento de tags

Cada push genera dos imágenes en ECR:

| Tag | Descripción | Ejemplo |
|-----|-------------|---------|
| `latest` | Siempre apunta a la última versión | `624373582708.dkr.ecr.sa-east-1.amazonaws.com/express/type:latest` |
| Commit SHA | Identifica la versión exacta | `624373582708.dkr.ecr.sa-east-1.amazonaws.com/express/type:a1b2c3d4` |

---

## Paso 5: Agregar el Workflow al Repositorio

### 5.1 Estructura del proyecto

```
express-deploy-AWS-farget/
├── .github/
│   └── workflows/
│       └── build-and-push.yml     ← Workflow CI/CD
├── index.js                       ← Código Express
├── package.json
├── Dockerfile
├── docker-compose.yml
└── .dockerignore
```

### 5.2 Comandos para subir

```bash
git add .
git commit -m "Add CI/CD workflow for ECR deployment"
git push origin main
```

---

## Paso 6: Verificar el Despliegue

### 6.1 Monitorear el workflow

1. Ir a **Actions** en el repositorio GitHub
2. Ver el workflow en ejecución
3. Revisar logs si hay errores

### 6.2 Verificar imagen en ECR

1. Ir a **AWS Console → Amazon ECR → Repositories**
2. Seleccionar `express/type`
3. Verificar que las imágenes `latest` y SHA están presentes

### 6.3 Verificar tags desde CLI

```bash
aws ecr list-images --repository-name express/type --region sa-east-1 --profile TU_PROFILE
```

---

## Troubleshooting

### Error: Credentials could not be loaded

**Causa:** Falta el permiso `id-token: write` para OIDC.

**Solución:** Añadir al inicio del workflow:

```yaml
permissions:
  id-token: write
  contents: read
```

### Error: Access Denied al hacer push a ECR

**Causa:** El rol IAM no tiene permisos suficientes.

**Solución:** Verificar que el rol tiene la política `AmazonEC2ContainerRegistryPowerUser` o equivalente.

### Error: Repository not found

**Causa:** El ECR Repository no existe o el nombre está mal.

**Solución:** Verificar que el nombre del repository coincide exactamente en:
- GitHub Environment Variable `ECR_REPOSITORY`
- Nombre del repository en AWS ECR

---

## Buenas Prácticas

### Seguridad

1. **Usar OIDC** en lugar de Access Keys (más seguro, no requiere credenciales almacenadas)
2. **Limitar el rol IAM** solo al repository específico si es posible
3. **No almacenar secretos** en variables de repository (usar Environment secrets)
4. **Proteger la rama main** con branch protection rules

### Mantenimiento

1. Revisar periódicamente los logs de GitHub Actions
2. Limpiar imágenes antiguas en ECR (configurar lifecycle policy)
3. Actualizar las versiones de las actions (`aws-actions/configure-aws-credentials@v4` → `v4` mínimo)

### Limpieza de imágenes ECR

Crear una lifecycle policy para eliminar imágenes antiguas:

1. Ir a **Amazon ECR → Repositories → express/type → Lifecycle policy**
2. Crear política:

```json
{
  "rules": [
    {
      "rulePriority": 1,
      "description": "Keep last 10 images",
      "selection": {
        "tagStatus": "any",
        "countType": "imageCountMoreThan",
        "countNumber": 10
      },
      "action": {
        "type": "expire"
      }
    }
  ]
}
```

---

## Próximos Pasos (Opcional)

### Desplegar a AWS ECS Fargate

1. Crear un ECS Cluster (Fargate)
2. Crear Task Definition
3. Crear Service con Application Load Balancer
4. Modificar el workflow para invocar `aws ecs update-service` después del push

### Monitoreo

1. Configurar CloudWatch para logs de GitHub Actions
2. Añadir notificaciones de Slack/Email en caso de fallo
3. Configurar dashboards para métricas de ECR

---

## Referencias

- [GitHub Actions: Configure AWS Credentials](https://github.com/aws-actions/configure-aws-credentials)
- [GitHub Actions: Amazon ECR Login](https://github.com/aws-actions/amazon-ecr-login)
- [AWS IAM OIDC Provider](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_providers_create_oidc.html)
- [Amazon ECR Documentation](https://docs.aws.amazon.com/ecr/)