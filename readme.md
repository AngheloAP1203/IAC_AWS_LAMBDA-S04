# Proyecto: Procesador de Imágenes en AWS con Terraform

En este repositorio he creado todo el código necesario para levantar mi propia arquitectura Serverless en AWS, la cual procesa imágenes automáticamente. Todo lo he hecho usando Terraform.

## Herramientas y Servicios que Utilicé

**Mis Herramientas:**
- **Terraform:** Lo utilicé para desplegar toda la infraestructura como código (IaC).
- **AWS CLI:** Lo uso para conectarme y gestionar los servicios directamente desde mi terminal.

**Servicios de AWS:**
- **API Gateway (HTTP API v2):** Lo configuré como mi punto de entrada público para recibir las peticiones.
- **AWS Lambda:** Aquí puse toda mi lógica de negocio sin usar servidores. Creé dos funciones: `upload-lambda` (para recibir mi imagen) y `crop-lambda` (para recortarla con forma circular).
- **Amazon S3:** Es mi almacenamiento. Configuré el prefijo `uploads/` para guardar mis imágenes originales y `processed/` para las que ya están recortadas.
- **Amazon SQS:** Es mi cola de mensajes principal. También le agregué una Dead-Letter Queue (DLQ) para desacoplar el proceso y manejar mis errores de forma segura.
- **Amazon VPC:** Hice que toda mi arquitectura corra dentro de una red privada usando subredes, NAT Gateways y VPC Endpoints (así me aseguro de que el tráfico de mis servicios S3 y SQS no salga a internet público).

## Mi Diagrama de la Arquitectura

He preparado mi proyecto para que pueda desplegarse en 3 entornos totalmente separados: **DEV**, **QA** y **PROD**. Para lograr esto, utilizo los `workspaces` de Terraform.

Aquí dejo el diagrama exacto que armé con todos los componentes y cómo los conecté:

```mermaid
%%{
  init: {
    "theme": "base",
    "themeVariables": {
      "primaryColor": "#1e293b",
      "primaryTextColor": "#f8fafc",
      "primaryBorderColor": "#334155",
      "lineColor": "#94a3b8",
      "secondaryColor": "#0f172a",
      "tertiaryColor": "#1e293b",
      "background": "#0f172a",
      "mainBkg": "#1e293b",
      "nodeBorder": "#475569",
      "clusterBkg": "#0f172a",
      "titleColor": "#f8fafc",
      "edgeLabelBackground": "#1e293b",
      "fontFamily": "monospace"
    },
    "flowchart": { "curve": "basis", "padding": 20 }
  }
}%%

flowchart TD

  %% ── INTERNET ──────────────────────────────────────────────────────────────
  subgraph INTERNET["Internet"]
    CLIENT["Client\n---\nPOST /upload\nmultipart/form-data or JSON+base64\nMax size: 10 MB\nAllowed: jpg, png, gif, webp"]
  end

  %% ── AWS ACCOUNT ───────────────────────────────────────────────────────────
  subgraph AWS["AWS Account — Region: us-east-1"]

    %% ── EDGE SERVICES ─────────────────────────────────────────────────────
    subgraph EDGE["AWS Managed Edge Services — outside VPC"]

      APIGW["API Gateway HTTP API v2\n---\nRoute: POST /upload\nProtocol: HTTPS, TLS 1.2+\nPayload format: 2.0\nCORS: enabled\nStage: default, auto-deploy\nThrottling: 10,000 rps\nAccess logs to CloudWatch"]

      subgraph S3_SVC["Amazon S3 — Bucket: image-processor-env-images-suffix"]
        S3_UPLOADS["uploads/ prefix\n---\nStores: original images\nSSE: AES-256\nVersioning: enabled\nLifecycle: expire after 30 days\nAccess: fully private\nOn ObjectCreated fires SQS notification"]
        S3_PROCESSED["processed/ prefix\n---\nStores: cropped circular PNGs\nSSE: AES-256\nOutput: 40x40 px, PNG, transparent bg\nLifecycle: expire after 90 days\nAccess: fully private"]
      end

      subgraph SQS_SVC["Amazon SQS"]
        SQS_QUEUE["Main Queue\n---\nName: image-processor-env-image-queue\nType: Standard\nVisibility timeout: 360 s (6x Lambda timeout)\nRetention: 1 day\nLong polling: 20 s\nMax receives before DLQ: 3"]
        SQS_DLQ["Dead-Letter Queue\n---\nName: image-processor-env-image-dlq\nRetention: 14 days\nCloudWatch alarm on any visible message"]
      end

    end

    %% ── VPC ────────────────────────────────────────────────────────────────
    subgraph VPC["VPC — CIDR: 10.0.0.0/16 — DNS resolution and hostnames enabled"]

      IGW["Internet Gateway\n---\nAttached to VPC\nEntry point for inbound\npublic traffic"]

      %% ── PUBLIC SUBNETS ──────────────────────────────────────────────────
      subgraph PUB_A["Public Subnet AZ-a — 10.0.1.0/24 — Route 0.0.0.0/0 to IGW"]
        NAT_A["NAT Gateway A\n---\nElastic IP: allocated\nRoutes outbound traffic\nfor private subnet AZ-a"]
      end

      subgraph PUB_B["Public Subnet AZ-b — 10.0.2.0/24 — Route 0.0.0.0/0 to IGW"]
        NAT_B["NAT Gateway B\n---\nElastic IP: allocated\nRoutes outbound traffic\nfor private subnet AZ-b\nHigh-availability fallback"]
      end

      %% ── PRIVATE SUBNETS ─────────────────────────────────────────────────
      subgraph PRIV_A["Private Subnet AZ-a — 10.0.11.0/24 — Route 0.0.0.0/0 to NAT-A"]

        subgraph SG_UPLOAD["SG: sg-upload-lambda | Inbound: none | Outbound: TCP 443 to vpce-s3 and vpce-sqs"]
          LAMBDA_UPLOAD["upload-lambda\n---\nRuntime: nodejs20.x\nMemory: 256 MB — Timeout: 30 s\nHandler: index.handler\nEnv: S3_BUCKET, UPLOAD_PREFIX\nDeps: @aws-sdk/client-s3, busboy, uuid\nIAM: s3:PutObject on uploads/ only\nLogs: /aws/lambda/...-upload"]
        end

        subgraph SG_CROP["SG: sg-crop-lambda | Inbound: none | Outbound: TCP 443 to vpce-s3 and vpce-sqs"]
          LAMBDA_CROP["crop-lambda\n---\nRuntime: nodejs20.x\nMemory: 512 MB — Timeout: 60 s\nHandler: index.handler\nEnv: S3_BUCKET, PROCESSED_PREFIX\nDeps: @aws-sdk/client-s3, sharp 0.33\nCrop: resize 40x40 cover, SVG circle mask\nOutput: PNG with transparent alpha\nIAM: s3:GetObject uploads/, s3:PutObject processed/\nSQS: ReceiveMessage, DeleteMessage, ChangeVisibility\nLogs: /aws/lambda/...-crop"]
        end

      end

      subgraph PRIV_B["Private Subnet AZ-b — 10.0.12.0/24 — Route 0.0.0.0/0 to NAT-B"]
        LAMBDA_UPLOAD_B["upload-lambda replica AZ-b\n---\nIdentical config to AZ-a\nLambda auto-distributes ENIs\nacross both private subnets"]
        LAMBDA_CROP_B["crop-lambda replica AZ-b\n---\nIdentical config to AZ-a\nLambda auto-distributes ENIs\nacross both private subnets"]
      end

      %% ── VPC ENDPOINTS ───────────────────────────────────────────────────
      subgraph VPCE["VPC Endpoints — traffic stays on AWS backbone, never hits public internet"]

        VPCE_S3["S3 Gateway Endpoint\n---\nType: Gateway — free, no ENI\nService: com.amazonaws.us-east-1.s3\nInjected into private subnet route tables\nPolicy: s3:GetObject and s3:PutObject\nscoped to the images bucket only"]

        VPCE_SQS["SQS Interface Endpoint\n---\nType: Interface — ENI per AZ\nService: com.amazonaws.us-east-1.sqs\nPrivate DNS: enabled\nDeployed in: priv-a, priv-b\nSG: sg-vpce-sqs\nInbound TCP 443 from sg-upload-lambda\nInbound TCP 443 from sg-crop-lambda"]

      end

    end

    %% ── IAM ───────────────────────────────────────────────────────────────
    subgraph IAM["IAM — Least-Privilege Roles"]
      ROLE_UPLOAD["Role: upload-lambda-role\n---\nAWSLambdaBasicExecutionRole\nAWSLambdaVPCAccessExecutionRole\ns3:PutObject scoped to uploads/ only"]
      ROLE_CROP["Role: crop-lambda-role\n---\nAWSLambdaBasicExecutionRole\nAWSLambdaVPCAccessExecutionRole\ns3:GetObject on uploads/\ns3:PutObject on processed/\nsqs: ReceiveMessage, DeleteMessage\nGetQueueAttributes, ChangeMessageVisibility"]
    end

    %% ── OBSERVABILITY ─────────────────────────────────────────────────────
    subgraph OBS["Observability — CloudWatch"]
      CW_UPLOAD["Log Group\n/aws/lambda/...-upload\nRetention: 14 days"]
      CW_CROP["Log Group\n/aws/lambda/...-crop\nRetention: 14 days"]
      CW_APIGW["Log Group\n/aws/apigateway/...\nRetention: 14 days\nFormat: JSON access log"]
      CW_ALARM["CloudWatch Alarm: dlq-messages-alarm\n---\nMetric: ApproximateNumberOfMessagesVisible\nNamespace: AWS/SQS\nPeriod: 60 s — Threshold: above 0\nAction: notify via SNS topic"]
    end

  end

  %% ── DATA FLOW ─────────────────────────────────────────────────────────────

  CLIENT -->|"1 - HTTPS POST /upload, TLS 1.2+, max 10 MB"| APIGW
  APIGW -->|"2 - Lambda Proxy Invoke, Payload 2.0"| LAMBDA_UPLOAD
  APIGW -->|"2 - replica invoke"| LAMBDA_UPLOAD_B

  LAMBDA_UPLOAD -->|"3 - s3:PutObject via S3 Gateway Endpoint"| VPCE_S3
  LAMBDA_UPLOAD_B -->|"3 - replica"| VPCE_S3
  VPCE_S3 -->|"writes to uploads/"| S3_UPLOADS

  S3_UPLOADS -->|"4 - S3 Event Notification, ObjectCreated, AWS internal network"| SQS_QUEUE

  SQS_QUEUE -->|"5 - ESM trigger, batch size 5, ReportBatchItemFailures"| LAMBDA_CROP
  SQS_QUEUE -->|"5 - replica"| LAMBDA_CROP_B

  LAMBDA_CROP -->|"6 - s3:GetObject via S3 Gateway Endpoint"| VPCE_S3
  LAMBDA_CROP_B -->|"6 - replica"| VPCE_S3
  S3_UPLOADS -->|"reads from"| VPCE_S3

  LAMBDA_CROP -->|"7 - s3:PutObject, name_circular.png, 40x40 PNG"| VPCE_S3
  LAMBDA_CROP_B -->|"7 - replica"| VPCE_S3
  VPCE_S3 -->|"writes to processed/"| S3_PROCESSED

  LAMBDA_CROP -->|"sqs:ReceiveMessage and DeleteMessage via Interface Endpoint"| VPCE_SQS
  LAMBDA_CROP_B -->|"same"| VPCE_SQS
  VPCE_SQS -->|"connected to"| SQS_QUEUE

  SQS_QUEUE -->|"after 3 failed receives"| SQS_DLQ
  SQS_DLQ -.->|"triggers alarm"| CW_ALARM

  LAMBDA_UPLOAD -.->|"logs"| CW_UPLOAD
  LAMBDA_CROP -.->|"logs"| CW_CROP
  APIGW -.->|"access logs"| CW_APIGW

  LAMBDA_UPLOAD -.->|"assumes"| ROLE_UPLOAD
  LAMBDA_CROP -.->|"assumes"| ROLE_CROP

  IGW -.- NAT_A
  IGW -.- NAT_B

  %% ── STYLES ────────────────────────────────────────────────────────────────

  classDef clientNode fill:#0f172a,stroke:#6366f1,stroke-width:2px,color:#e0e7ff
  classDef edgeNode fill:#1e3a5f,stroke:#3b82f6,stroke-width:2px,color:#bfdbfe
  classDef lambdaNode fill:#14532d,stroke:#22c55e,stroke-width:2px,color:#dcfce7
  classDef s3Node fill:#3b1f0f,stroke:#f97316,stroke-width:2px,color:#ffedd5
  classDef sqsNode fill:#4a1d96,stroke:#a78bfa,stroke-width:2px,color:#ede9fe
  classDef iamNode fill:#1f2937,stroke:#facc15,stroke-width:2px,color:#fef9c3
  classDef obsNode fill:#1f2937,stroke:#94a3b8,stroke-width:2px,color:#e2e8f0
  classDef vpceNode fill:#0c2340,stroke:#38bdf8,stroke-width:2px,color:#bae6fd
  classDef natNode fill:#1c1917,stroke:#84cc16,stroke-width:2px,color:#d9f99d

  class CLIENT clientNode
  class APIGW,IGW edgeNode
  class LAMBDA_UPLOAD,LAMBDA_CROP,LAMBDA_UPLOAD_B,LAMBDA_CROP_B lambdaNode
  class S3_UPLOADS,S3_PROCESSED s3Node
  class SQS_QUEUE,SQS_DLQ sqsNode
  class ROLE_UPLOAD,ROLE_CROP iamNode
  class CW_UPLOAD,CW_CROP,CW_APIGW,CW_ALARM obsNode
  class VPCE_S3,VPCE_SQS vpceNode
  class NAT_A,NAT_B natNode
```

## Mi Estructura del Proyecto

Así es como organicé mis carpetas y archivos:

```text
IAC_Semana04/
├── .gitignore
├── README.md
├── architecture.mermaid
├── assets/
│   └── mi_foto_perfil.png
├── iac/
│   ├── api_gateway.tf
│   ├── cloudwatch.tf
│   ├── endpoints.tf
│   ├── iam.tf
│   ├── lambda_crop.tf
│   ├── lambda_upload.tf
│   ├── nat.tf
│   ├── outputs.tf
│   ├── providers.tf
│   ├── route_tables.tf
│   ├── s3.tf
│   ├── security_groups.tf
│   ├── sns.tf
│   ├── sqs.tf
│   ├── subnets.tf
│   ├── terraform.tfvars.example
│   ├── variables.tf
│   └── vpc.tf
└── src/
    └── lambdas/
        ├── crop/
        │   ├── index.mjs
        │   └── package.json
        └── upload/
            ├── index.mjs
            └── package.json
```

## Pasos que sigo para Desplegar

**1. Loguearme en AWS (SSO)**
Antes de hacer nada, necesito tener mi sesión de AWS activa. En mi terminal ejecuto:
```bash
aws configure sso --use-device-code
```
Sigo el enlace, pongo mi código, selecciono mi cuenta, elijo el rol, la región y le asigno un nombre a mi perfil.

**2. Configurar mi archivo de variables**
Copio el archivo de ejemplo y coloco mis datos reales (como el ID de mi cuenta de AWS y mi región):
```bash
cp iac/terraform.tfvars.example iac/terraform.tfvars
```

**3. Inicializar Terraform**
Entro a mi carpeta de infraestructura y la inicializo:
```bash
cd iac
terraform init
```

**4. Levantar mi entorno**
Dependiendo de qué entorno necesite crear, ejecuto los comandos correspondientes. 

Para **DEV**:
```bash
terraform workspace new dev
terraform plan -var-file="terraform.tfvars"
terraform apply -var-file="terraform.tfvars" -auto-approve
```

Para **QA**:
```bash
terraform workspace new qa
terraform plan -var-file="terraform.tfvars" -var="environment=qa"
terraform apply -var-file="terraform.tfvars" -var="environment=qa" -auto-approve
```

Para **PROD**:
```bash
terraform workspace new prod
terraform plan -var-file="terraform.tfvars" -var="environment=prod"
terraform apply -var-file="terraform.tfvars" -var="environment=prod" -auto-approve
```

## ¿Cómo pruebo que mi proyecto funciona?

Suelo probarlo de dos maneras distintas:

**Opcion A: Vía Consola S3 (Manual)**
Subo manualmente una imagen a la carpeta `uploads/` de mi bucket S3. Espero un par de segundos y verifico que aparezca mi versión procesada en la carpeta `processed/`.

**Opción B: Vía API / Terminal**
Cuando termino el despliegue de Terraform, me devuelve la URL de mi API (`api_url`). Subo mi foto directamente desde la terminal con curl:
```bash
curl -X POST <URL_DEL_API> \
  -H "Content-Type: image/png" \
  --data-binary "@../assets/mi_foto_perfil.png"
```

## Mis Requisitos de Entrega (Archivo PDF)

Para completar la entrega de mi proyecto, debo subir un archivo **PDF** que incluye:
- Capturas de pantalla de mi consola de AWS mostrando que mis servicios están desplegados (asegurándome de que en las capturas se vea el ID de mi cuenta).
- La URL pública de mi proyecto y un pequeño resumen explicando cómo la uso (basándome en este README).
- **Evidencia de limpieza:** Esto es obligatorio para mí. Adjunto mis capturas ejecutando los comandos de destrucción (`terraform destroy*`) para demostrar que eliminé mis recursos correctamente.

## ¡Importante! Limpiar mis recursos

Para que no me cobren nada en AWS (sobre todo por los NAT Gateways), me aseguro de destruir todo apenas termino de probar. 

*Aviso: Antes de lanzar mi comando de destroy, entro a mi consola de S3 y vacío mi bucket manualmente, porque Terraform falla si intento borrar un bucket que todavía tiene archivos adentro.*

Mis comandos para destruir todo (elijo el entorno en el que estaba trabajando):

```bash
# Si estaba en DEV
terraform workspace select dev
terraform destroy -var-file="terraform.tfvars" -auto-approve

# Si estaba en QA
terraform workspace select qa
terraform destroy -var-file="terraform.tfvars" -var="environment=qa" -auto-approve

# Si estaba en PROD
terraform workspace select prod
terraform destroy -var-file="terraform.tfvars" -var="environment=prod" -auto-approve
```
