# AWS + Lambda Integration: Arquitectura Multientorno v1.0

Este proyecto consiste en la implementación de una arquitectura serverless escalable en Amazon Web Services, diseñada mediante Infraestructura como Código (IaC) para soportar un ciclo de vida de desarrollo completo.

## Objetivo del Proyecto
Desplegar una solución basada en AWS Lambda que integre diversos servicios de la nube, siguiendo estrictamente el diseño de arquitectura definido en el diagrama de flujo (Mermaid) adjunto en la documentación.

## Alcance de la Infraestructura
La infraestructura está diseñada para ser agnóstica al entorno, permitiendo el despliegue segregado en las siguientes etapas:

* **DEV (Desarrollo):** Entorno de pruebas iniciales y experimentación.
* **QA (Quality Assurance):** Entorno espejo para pruebas de integración y validación de calidad.
* **PROD (Producción):** Entorno final de alta disponibilidad y configuraciones de seguridad estrictas.

## Requerimientos del Sistema

### Arquitectura de Nube (AWS)
- **Cómputo:** Funciones AWS Lambda configuradas con los permisos mínimos necesarios (IAM Least Privilege).
- **Integraciones:** Conexión con los servicios definidos en el diagrama (API Gateway, S3, o bases de datos según corresponda).
- **Segregación:** Aislamiento total de recursos entre los tres entornos (DEV, QA, PROD).

### Infraestructura como Código (IaC)
- **Herramienta:** Terraform.
- **Gestión de Estados:** Implementación de Workspaces para manejar los estados de los tres entornos de forma independiente.
- **Parametrización:** Uso de archivos de variables específicos para cada entorno para evitar la duplicidad de código.

## Especificaciones de Entrega

Para la validación de este proyecto, se han considerado los siguientes puntos críticos:

1.  **Fidelidad al Diagrama:** El código debe ser una representación exacta de los componentes y flujos definidos en el archivo Mermaid.
2.  **Flexibilidad de Diseño:** Se permite la modificación o adición de componentes no considerados en el diagrama original, siempre que aporten estabilidad o seguridad a la arquitectura.
3.  **Evidencia de Ciclo de Vida:**
    * Pruebas de despliegue exitoso en los tres entornos.
    * Documentación fotográfica de la consola de AWS que verifique la existencia de los recursos y la identidad de la cuenta.
    * **Política de Costo Cero:** Evidencia mandatoria de la destrucción total de los recursos (`terraform destroy`) tras la finalización de las pruebas.

## Consideraciones de Seguridad
- No se deben incluir credenciales de AWS en el código fuente.
- Todos los recursos deben cumplir con las etiquetas (tags) correspondientes para identificación por entorno.

## Pasos para ejecutar
-  cd terraform
- terraform init
Para el entorno "DEV"
- terraform workspace new dev
- terraform plan -var-file="dev.tfvars"
- terraform apply -var-file="dev.tfvars" -auto-approve
- curl -X POST <TU_API_URL_AQUI> \
  -H "Content-Type: image/png" \
  --data-binary "@../foto.png"
- Ve a la consola de S3 en el navegador, selecciona el bucket image-processor-dev-images-upao-pagan y haz clic en el boton "Empty" (Vaciar).
- terraform destroy -var-file="dev.tfvars" -auto-approve

Para el entorno "QA"
- terraform workspace new qa
- terraform plan -var-file="qa.tfvars"
- terraform apply -var-file="qa.tfvars" -auto-approve
- curl -X POST <TU_API_URL_AQUI> \
  -H "Content-Type: image/png" \
  --data-binary "@../foto.png"
- Ve a la consola de S3 en el navegador, selecciona el bucket image-processor-qa-images-upao-pagan y haz clic en el boton "Empty" (Vaciar).
- terraform destroy -var-file="qa.tfvars" -auto-approve

Para el entorno "PROD"
- terraform workspace new prod
- terraform plan -var-file="prod.tfvars"
- terraform apply -var-file="prod.tfvars" -auto-approve
- curl -X POST <TU_API_URL_AQUI> \
  -H "Content-Type: image/png" \
  --data-binary "@../foto.png"
- Ve a la consola de S3 en el navegador, selecciona el bucket image-processor-prod-images-upao-pagan y haz clic en el boton "Empty" (Vaciar).
- terraform destroy -var-file="prod.tfvars" -auto-approve
