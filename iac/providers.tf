terraform {
    required_version = ">= 1.0.0"

    required_providers {
        aws = {
            source  = "hashicorp/aws"
            version = "~> 5.0"
        }
    }
}

provider "aws" {
    region  = var.aws_region
    profile = var.aws_profile

    # Etiquetar todos los recursos del proyecto
    default_tags {
        tags = {
            Project     = var.project_name
            Environment = var.environment
            Owner       = "AngheloAlcantara"
        }
    }
}
