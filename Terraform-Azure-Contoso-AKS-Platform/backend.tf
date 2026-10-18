  terraform { 
    backend "azurerm" {
      # Backend configuration will be provided via terraform.tfbackend or -backend-config
      # Use: terraform init -backend-config="environments/contoso-shared/terraform.tfbackend"
    }
  }