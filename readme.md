# Image Processor — Serverless AWS con Terraform

![Terraform](https://img.shields.io/badge/Terraform-v1.0%2B-7B42BC?style=flat-square&logo=terraform)
![AWS](https://img.shields.io/badge/AWS-us--east--1-FF9900?style=flat-square&logo=amazonaws)
![Node.js](https://img.shields.io/badge/Node.js-20.x-339933?style=flat-square&logo=nodedotjs)

**Curso:** Infraestructura como Código (IaC) — Semana 04  
**Autor:** Anghelo Alcantara · Universidad Privada Antenor Orrego  
**Cuenta AWS:** `331520981032` · **Región:** `us-east-1`

---

## ¿Qué hace este proyecto?

Básicamente es un sistema que recibe imágenes por HTTP, las guarda en S3 y automáticamente las recorta en formato circular de 40×40 px usando una Lambda que se dispara con SQS. Todo desplegado en AWS con Terraform y soportando tres entornos: DEV, QA y PROD.

El flujo es:

```
Cliente  →  API Gateway (POST /upload)
         →  Lambda upload  →  S3 (uploads/)
         →  S3 Event       →  SQS
         →  Lambda crop    →  S3 (processed/)
```

La imagen queda como PNG circular con fondo transparente en el prefijo `processed/` del bucket.

---

## Servicios AWS usados

| Servicio | Para qué |
|---|---|
| API Gateway HTTP v2 | Endpoint `POST /upload`, CORS habilitado |
| Lambda `upload-lambda` | Recibe la imagen y la sube a S3 (acepta multipart y base64) |
| Lambda `crop-lambda` | Descarga de S3, recorta con Sharp a 40×40 px circular, sube el resultado |
| S3 | Bucket privado con AES-256, versionado y lifecycle (30 días uploads, 90 días processed) |
| SQS | Cola principal + Dead-Letter Queue (DLQ), dispara la crop-lambda |
| SNS | Notificación cuando hay mensajes en la DLQ |
| CloudWatch | Log groups de las Lambdas y alarma sobre la DLQ |
| VPC | Red privada en 2 zonas de disponibilidad |
| NAT Gateway | Para que las Lambdas puedan salir a internet si lo necesitan |
| VPC Endpoints | S3 (Gateway, gratis) y SQS (Interface) para que el tráfico no salga de AWS |
| IAM | Roles con permisos mínimos para cada Lambda |

---

## Estructura del repositorio

```
IAC_Semana04/
├── .gitignore
├── README.md
├── architecture.mermaid
├── architecture.mermaid.svg
├── assets/
│   └── mi_foto_perfil.png      <- imagen de prueba
│
├── iac/
│   ├── providers.tf
│   ├── variables.tf
│   ├── outputs.tf
│   ├── terraform.tfvars.example
│   ├── terraform.tfvars         
│   ├── vpc.tf
│   ├── subnets.tf
│   ├── nat.tf
│   ├── route_tables.tf
│   ├── endpoints.tf
│   ├── security_groups.tf
│   ├── s3.tf
│   ├── sqs.tf
│   ├── sns.tf
│   ├── cloudwatch.tf
│   ├── iam.tf
│   ├── api_gateway.tf
│   ├── lambda_upload.tf
│   └── lambda_crop.tf
│
└── src/
    └── lambdas/
        ├── upload/
        │   ├── index.mjs
        │   └── package.json
        └── crop/
            ├── index.mjs
            └── package.json
```

---

## Configuración inicial

El archivo `terraform.tfvars` tiene los datos reales de la cuenta y **no se sube al repositorio**. Para configurarlo en una máquina nueva:

```bash
cp iac/terraform.tfvars.example iac/terraform.tfvars
```

Luego editar el `terraform.tfvars` con los datos reales:

```hcl
environment    = "dev"
aws_region     = "us-east-1"
project_name   = "image-processor"
aws_profile    = "anghelo-sso"      # nombre real del perfil SSO
aws_account_id = "331520981032"     # ID real de la cuenta
```

Antes de cualquier comando de Terraform, renovar el token SSO:

```bash
aws sso login --profile anghelo-sso
aws sts get-caller-identity --profile anghelo-sso
```

---

## Cómo desplegar

```bash
cd iac
terraform init
```

### Entorno DEV

```bash
terraform workspace new dev
terraform plan  -var-file="terraform.tfvars"
terraform apply -var-file="terraform.tfvars" -auto-approve
```

### Entorno QA

```bash
terraform workspace new qa
terraform plan  -var-file="terraform.tfvars" -var="environment=qa"
terraform apply -var-file="terraform.tfvars" -var="environment=qa" -auto-approve
```

### Entorno PROD

```bash
terraform workspace new prod
terraform plan  -var-file="terraform.tfvars" -var="environment=prod"
terraform apply -var-file="terraform.tfvars" -var="environment=prod" -auto-approve
```

---

## Probar el endpoint

Una vez desplegado, obtener la URL con:

```bash
terraform output api_url
```

Enviar la imagen de prueba:

```bash
curl -X POST <URL_DEL_OUTPUT> \
  -H "Content-Type: image/png" \
  --data-binary "@../assets/mi_foto_perfil.png"
```

Respuesta esperada:
```json
{ "message": "Imagen recibida", "file": "uuid.png" }
```

Después de unos segundos, la imagen recortada aparece en el prefijo `processed/` del bucket S3.

---

## Destruir los recursos

> Importante: los NAT Gateways cobran ~$0.045/hora cada uno. Siempre destruir al terminar las pruebas.

Antes de destruir, vaciar el bucket desde la consola de S3 (botón "Empty"), porque Terraform no puede eliminar un bucket con objetos dentro.

```bash
# DEV
terraform destroy -var-file="terraform.tfvars" -auto-approve

# QA
terraform workspace select qa
terraform destroy -var-file="terraform.tfvars" -var="environment=qa" -auto-approve

# PROD
terraform workspace select prod
terraform destroy -var-file="terraform.tfvars" -var="environment=prod" -auto-approve
```

El tiempo total entre `apply`, capturas y `destroy` es de unos 15-20 minutos. Costo real aproximado: menos de $0.05 USD.

---

## Outputs disponibles

| Output | Descripción |
|---|---|
| `api_url` | URL completa del endpoint `/upload` |
| `s3_bucket_name` | Nombre del bucket del entorno activo |
| `sqs_queue_url` | URL de la cola SQS principal |
| `workspace_activo` | Entorno desplegado (`dev`, `qa` o `prod`) |

---

## Notas

- El diagrama de arquitectura completo está en `architecture.mermaid`.
- Los commits siguen Conventional Commits en español (`feat`, `build`, `docs`, etc.).
- Se usó GitFlow: ramas `feature/setup-iac`, `feature/setup-lambdas` y `feature/documentacion` mergeadas a `develop`, luego `release/v1