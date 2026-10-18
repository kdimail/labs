terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 4.56.0"
    }
    azapi = {
      source  = "azure/azapi"
      version = "~> 2.4"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.9"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">=2.37.1"
    }
  }
}

provider "azurerm" {
  subscription_id = var.subscription_id
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
}

# Cross-subscription provider for IT-Shared resources (private DNS zones)
provider "azurerm" {
  alias           = "it_shared"
  subscription_id = var.it_shared_subscription_id
  features {}
}

provider "azapi" {
  subscription_id = var.subscription_id
}

provider "kubernetes" {
  host                   = var.create_aks ? module.aks["main"].kube_config[0].host : null
  cluster_ca_certificate = var.create_aks ? base64decode(module.aks["main"].kube_config[0].cluster_ca_certificate) : null
 
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "kubelogin"
    args = [
      "get-token",
      "--server-id", "6dae42f8-4368-4678-94ff-3960e28e3630",
      "--login", "azurecli"
    ]
  }
}