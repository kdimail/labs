######################################################################################
# ENVIRONMENT & NAMING
######################################################################################
env              = "dev"
region           = "ILCentral"
team             = "Contoso"
company_location = "ISIL"
location         = "israelcentral"

region_short = "ILCentral"
region_short_v2 = "ILC"
team_short = "hzn"
env_short  = "Dev"

######################################################################################
# GLOBAL CONFIGURATION
######################################################################################
subscription_id        = "${TF_VAR_subscription_aks_id}"
it_shared_subscription_id = "${TF_VAR_IT_SHARED_SUBSCRIPTION_ID}"
enable_telemetry = false
create_aks       = true
ingress_dns_zone_name  = "contosogrp-cloud.com"

######################################################################################
# VNet + Central DNS Zone Links
######################################################################################
vnet_name                = "ILCentral-LZ-Contoso-Dev-vnet"
vnet_resource_group_name = "ILCentral-LZ-Contoso-Dev-rg-net"

central_dns_zone_links = {
  "contosogrp-cloud.com" = {
    zone_name           = "contosogrp-cloud.com"
    zone_resource_group = "ILCentral-LZ-IT-Shared-rg-net"
    subscription_id     = "${TF_VAR_IT_SHARED_SUBSCRIPTION_ID}"
  }
  postgres = {
    zone_name           = "privatelink.postgres.database.azure.com"
    zone_resource_group = "ILCentral-LZ-IT-Shared-rg-net"
  }
  servicebus = {
    zone_name           = "privatelink.servicebus.windows.net"
    zone_resource_group = "ILCentral-LZ-IT-Shared-rg-net"
  }
  redis = {
    zone_name           = "privatelink.redis.azure.net"
    zone_resource_group = "ILCentral-LZ-IT-Shared-rg-net"
  }
}

######################################################################################
# Resource Groups
######################################################################################
resource_groups = {
  core = {
    resource = "rg"
    role     = "core"

    tags = {
      Category    = "Resource Group"
      SubCategory = "core"
      Department  = "IT"
    }

    role_assignments = {
      "contoso-admins-reader" = {
        role_definition_id_or_name = "Reader"
        principal_id               = "${TF_VAR_TERRAFORM_AZURE_CONTOSO_ADMINS_GROUP_ID}"
        principal_type             = "Group"
      }
      "contoso-devs-reader" = {
        role_definition_id_or_name = "Reader"
        principal_id               = "${TF_VAR_TERRAFORM_AZURE_CONTOSO_DEVS_GROUP_ID}"
        principal_type             = "Group"
       }
    }
  }
}

######################################################################################
# Azure Container Registry (ACR)
######################################################################################
acr_registries = {}
# ============================================================================
# NETWORKING (VNet References)
######################################################################################
# Azure Kubernetes Service (AKS)
######################################################################################
aks_clusters = {
  main = {
    resource_group_key = "core"
    resource           = "aks"

    # ============================================================================
    # NETWORKING (VNet References)
    # ============================================================================
    nodes_network_resource_group_name = "ILCentral-LZ-Contoso-Dev-rg-net"
    nodes_vnet_name                   = "ILCentral-LZ-Contoso-Dev-vnet"
    nodes_subnet_name                 = "ILCentral-LZ-Contoso-Dev-aks-nodes-subnet"

    # Ingress Private DNS Zone Configuration
    # ----------------------------------------------------------------------------
    # Option 1: Use existing private DNS zone (recommended for shared infrastructure)
    # Provide the subscription_id, resource_group_name, and dns_zone_name
    ingress_private_dns_zone_resource_id = {
      subscription_id     = "${TF_VAR_IT_SHARED_SUBSCRIPTION_ID}"
      resource_group_name = "ILCentral-LZ-IT-Shared-rg-net"
      dns_zone_name       = "contosogrp-cloud.com"
    }

    # Option 2: Create new private DNS zone
    # Set ingress_private_dns_zone_resource_id = null and specify ingress_dns_zone_name
    # ingress_private_dns_zone_resource_id = null
    # ingress_dns_zone_name = "dev-contoso.iscar.internal"  # DNS zone will be created in nodes_network_resource_group_name

    # Additional VNet links for ingress DNS zone (only used when creating new zone)
    # The nodes VNet is automatically linked. Use this to link additional VNets.
    ingress_dns_zone_additional_vnet_links = {
      # "shared-vnet" = {
      #   vnet_id              = "/subscriptions/52765298-6e96-4e5a-866c-d0adfe2c48a0/resourceGroups/iscar-contoso-platform-dev-ilc-network-rg/providers/Microsoft.Network/virtualNetworks/israelcentral-dev-nodes-vnet"
      #   registration_enabled = false
      # }
      "vm-vnet" = {
        vnet_id              = "/subscriptions/${TF_VAR_IT_SHARED_SUBSCRIPTION_ID}/resourceGroups/ILCentral-LZ-IT-Shared-rg-net/providers/Microsoft.Network/virtualNetworks/ILCentral-LZ-IT-Shared-vnet"
        registration_enabled = false
      }
    }

    # ============================================================================
    # AZURE KUBERNETES SERVICE (AKS) - BASIC CONFIGURATION
    # ============================================================================
    sku_tier                            = "Standard"
    kubernetes_version                  = "1.36.4"
    automatic_channel_upgrade           = null
    node_os_channel_upgrade             = "None"
    upgrade_override = {
      force_upgrade_enabled = false
      effective_until       = "2026-10-06T00:00:00Z"
    }
    private_cluster_enabled             = true
    private_cluster_public_fqdn_enabled = false
    enable_telemetry                    = true

    # AKS Private DNS Zone Configuration
    aks_private_dns_zone_mode = "Existing"
    aks_private_dns_zone_id = {
      subscription_id       = "${TF_VAR_IT_SHARED_SUBSCRIPTION_ID}"
      resource_group_name   = "ILCentral-LZ-IT-Shared-rg-net"
      private_dns_zone_name = "private.israelcentral.azmk8s.io"
    }

    # ACR Configuration - Attached ACRs
    # Split into components for better readability and maintainability
    # Full resource ID will be constructed automatically
    attached_acr_id_map = {
      shared = {
        subscription_id     = "${TF_VAR_CONTOSO_SHARED_NON_PROD_SUBSCRIPTION_ID}"
        resource_group_name = "ILCentral-LZ-Contoso-Shared-Non-Prod-rg-core"
        acr_name            = "ilcentrallzhznshnonprod"
      }
    }

    # ============================================================================
    # AKS - NETWORKING
    # ============================================================================
    network_plugin      = "azure"
    network_plugin_mode = "overlay"
    network_dataplane   = "cilium"
    network_policy      = null
    # Outbound (egress) routing method:
    # - loadBalancer: Standard load balancer for egress (default)
    # - userDefinedRouting: Custom routing via UDR (for firewall/NVA scenarios)
    # - managedNATGateway: Azure-managed NAT Gateway
    # - userAssignedNATGateway: User-managed NAT Gateway
    outbound_type              = "userDefinedRouting"
    net_profile_pod_cidr       = "100.64.0.0/16"
    net_profile_service_cidr   = "100.96.0.0/16"
    net_profile_dns_service_ip = "100.96.0.10"

    # ============================================================================
    # AKS - RBAC & IDENTITY
    # ============================================================================
    role_based_access_control_enabled = true
    rbac_aad_azure_rbac_enabled       = true
    oidc_issuer_enabled               = true
    workload_identity_enabled         = true

    # rbac = []

    vm_cluster_admin_principal_ids = {
      linux-vm = {
        principal_id = "${TF_VAR_TERRAFORM_AZURE_RUNNER_MNG_ID_NON_PROD}"
      }
      linux-vm-prod = {
        principal_id = "${TF_VAR_TERRAFORM_AZURE_RUNNER_MNG_ID_PROD}"
      }
      linux-vm-non-prod2 = {
        principal_id = "${TF_VAR_TERRAFORM_AZURE_RUNNER_MNG_ID_NON_PROD2}"
      }
      linux-vm-prod2 = {
        principal_id = "${TF_VAR_TERRAFORM_AZURE_RUNNER_MNG_ID_PROD2}"
      }
      tf-principal_id = {
        principal_id = "5ab8ccc6-1ac0-4894-84e1-9addf9817fb6"
      }
      contoso-admins = {
        principal_id   = "${TF_VAR_TERRAFORM_AZURE_CONTOSO_ADMINS_GROUP_ID}"
        principal_type = "Group"
      }
      contoso-devs = {
        principal_id   = "${TF_VAR_TERRAFORM_AZURE_CONTOSO_DEVS_GROUP_ID}"
        principal_type = "Group"
      }
    }

    # ============================================================================
    # AKS - NODE POOLS
    # ============================================================================
    default_node_pool = {
      name                         = "system"
      node_public_ip_enabled       = false
      zones                        = ["1", "2", "3"]
      node_count                   = 1
      min_count                    = null
      max_count                    = null
      enable_auto_scaling          = false
      vm_size                      = "Standard_D2ads_v5"
      only_critical_addons_enabled = true
      temporary_name_for_rotation  = "systemtemp"
      orchestrator_version         = "1.36.4"
      os_sku                       = "Ubuntu"
      upgrade_settings = {
        max_surge                     = "33%"
        node_soak_duration_in_minutes = 0
        drain_timeout_in_minutes      = 0
      }
    }

    node_pools = {
      user = {
        name                        = "user"
        node_public_ip_enabled      = false
        zones                       = ["1", "2", "3"]
        node_count                  = null
        min_count                   = 2
        max_count                   = 5
        auto_scaling_enabled        = true
        vm_size                     = "Standard_D4ads_v5"
        temporary_name_for_rotation = "usertemp"
        node_labels = {
          "workload" = "user"
        }
        node_taints = []
        max_pods    = 110
        mode        = "User"
        os_sku      = "Ubuntu"
        orchestrator_version = "1.36.4"
        upgrade_settings = {
          max_surge                     = "33%"
          node_soak_duration_in_minutes = 0
          drain_timeout_in_minutes      = 0
        }
      }
    }

    # ============================================================================
    # AKS - FEATURES & STORAGE
    # ============================================================================
    storage_profile_disk_driver_enabled         = true
    storage_profile_file_driver_enabled         = true
    storage_profile_blob_driver_enabled         = false
    storage_profile_snapshot_controller_enabled = true

    service_mesh_profile = null

    workload_autoscaler_profile = {
      keda_enabled = true
    }

    image_cleaner_enabled        = true
    image_cleaner_interval_hours = 168

    # ============================================================================
    # AKS - WEB APP ROUTING (INGRESS)
    # ============================================================================
    web_app_routing = {
      # DNS zone IDs for ingress - Three options:
      #
      # Option 1: Auto-populate from ingress_private_dns_zone_resource_id (existing zone)
      #   - Set ingress_private_dns_zone_resource_id with zone details (see above)
      #   - Leave dns_zone_ids as null or omit it - will auto-populate
      #
      # Option 2: Auto-populate from newly created DNS zone
      #   - Set ingress_private_dns_zone_resource_id = null
      #   - Set ingress_dns_zone_name (see above)
      #   - Leave dns_zone_ids as null or omit it - will auto-populate from created zone
      #
      # Option 3: Explicitly specify existing DNS zone ID
      #   - Set dns_zone_ids with full resource ID(s)
      #   - Format: "/subscriptions/<sub-id>/resourceGroups/<rg-name>/providers/Microsoft.Network/privateDnsZones/<zone-name>"
      #
      # Current configuration: Option 2 (auto-populate from newly created DNS zone)
      # Since ingress_private_dns_zone_resource_id = null, DNS zone will be created and auto-populated here
      dns_zone_ids = null

      # Option 3: To explicitly specify existing DNS zone ID, use:
      # dns_zone_ids = [
      #   "/subscriptions/52765298-6e96-4e5a-866c-d0adfe2c48a0/resourceGroups/iscar-contoso-platform-shared-ilc-network-rg/providers/Microsoft.Network/privateDnsZones/dev-contoso.iscar.internal"
      # ]

      # Internal NGINX controller for private ingress (not exposed to internet)
      default_nginx_controller = "Internal"
    }

    # ============================================================================
    # AKS - WORKLOAD IDENTITIES
    # ============================================================================
    workload_identities = {
      # external-dns = {
      #   identity_name        = "external-dns"
      #   kubernetes_namespace = "external-dns"
      #   service_account_name = "external-dns-sa"
      #   roles = [
      #     {
      #       scope           = "/subscriptions/52765298-6e96-4e5a-866c-d0adfe2c48a0/resourceGroups/iscar-contoso-platform-shared-ilc-network-rg/providers/Microsoft.Network/privateDnsZones/dev-contoso.iscar.internal"
      #       definition_name = "Private DNS Zone Contributor"
      #     }
      #   ]
      # }

      external-secrets = {
        identity_name        = "external-secrets"
        kubernetes_namespace = "external-secrets"
        service_account_name = "external-secrets-sa"
        roles = [
          {
            # scope = "/subscriptions/52765298-6e96-4e5a-866c-d0adfe2c48a0/resourceGroups/iscar-contoso-platform-shared-ilc-network-rg/providers/Microsoft.KeyVault/vaults/<keyvault-name>"
            scope           = "module.keyvault"
            definition_name = "Key Vault Secrets Officer"
          }
        ]
      }
    }

    # ============================================================================
    # AKS - MAINTENANCE WINDOWS
    # ============================================================================
    maintenance_window = null
    # maintenance_window = {
    #   allowed = {
    #     day   = "Sunday"
    #     hours = [0, 1, 2, 3]
    #   }
    #   not_allowed = null
    # }

    maintenance_window_auto_upgrade = null
    # maintenance_window_auto_upgrade = {
    #   frequency    = "AbsoluteMonthly"
    #   duration     = 4
    #   interval     = 1
    #   day_of_month = 1
    #   start_time   = "00:00"
    #   utc_offset   = "+00:00"
    # }

    maintenance_window_node_os = null
    # maintenance_window_node_os = {
    #   frequency    = "AbsoluteMonthly"
    #   duration     = 4
    #   interval     = 1
    #   day_of_month = 1
    #   start_time   = "00:00"
    #   utc_offset   = "+00:00"
    # }

    # ============================================================================
    # MONITORING & OBSERVABILITY
    # ============================================================================
    # Log Analytics Workspace - Split into components for better readability
    # Full resource ID will be constructed automatically
    log_analytics_workspace_id = {
      subscription_id     = "${TF_VAR_IT_SHARED_SUBSCRIPTION_ID}"
      resource_group_name = "ilcentral-lz-it-shared-rg-deps"
      workspace_name      = "ILCentral-LZ-IT-Shared-log-analytics"
    }

    enable_application_insights = false
    application_insights_type   = "other"
    enable_container_insights   = false
    microsoft_defender_enabled  = true
    monitor_metrics_enabled     = false
    cost_analysis_enabled       = true

    # Log Analytics: minimum critical AKS logs (container logs → Elastic via Fluent Bit).
    enable_oms_agent             = false
    diagnostic_log_categories    = []
    diagnostic_log_groups        = []
    diagnostic_metric_categories = []

    # ============================================================================
    # EXTERNAL SERVICES
    # ============================================================================
    fluxcd_enabled       = true
    azure_policy_enabled = true

    tags = {
      Category    = "AKS"
      SubCategory = "platform"
      Department  = "IT"
    }
  }
}

######################################################################################
# Key Vaults
######################################################################################
key_vaults = {
  main = {
    resource_group_key = "core"
    resource           = "kv"

    keyvault_sku_name          = "standard"
    soft_delete_retention_days = 7
    purge_protection_enabled   = false

    keyvault_network_resource_group_name_for_pe = "ILCentral-LZ-Contoso-Dev-rg-net"
    keyvault_vnet_name_for_pe                   = "ILCentral-LZ-Contoso-Dev-vnet"
    keyvault_subnet_name_for_pe                 = "ILCentral-LZ-Contoso-Dev-deps-pe-subnet"

    keyvault_private_dns_zone_kv_resource_id = {
      subscriptions  = "${TF_VAR_IT_SHARED_SUBSCRIPTION_ID}"
      resourceGroups = "ILCentral-LZ-IT-Shared-rg-net"
    }
    keyvault_private_dns_zone_name = "privatelink.vaultcore.azure.net"
    keyvault_additional_vnet_links = {}

    keyvault_network_acls = {
      default_action             = "Allow"
      bypass                     = "AzureServices"
      ip_rules                   = ["212.25.106.78"]
      virtual_network_subnet_ids = []
    }

    keyvault_rbac = {
      "linuxvm" = {
        principal_id               = "${TF_VAR_TERRAFORM_AZURE_RUNNER_MNG_ID_NON_PROD}"
        role_definition_id_or_name = "Key Vault Secrets Officer"
      }
      "linuxvm-certificates" = {
        principal_id               = "${TF_VAR_TERRAFORM_AZURE_RUNNER_MNG_ID_NON_PROD}"
        role_definition_id_or_name = "Key Vault Certificates Officer"
      }
      "linuxvm-prod" = {
        principal_id               = "${TF_VAR_TERRAFORM_AZURE_RUNNER_MNG_ID_PROD}"
        role_definition_id_or_name = "Key Vault Secrets Officer"
      }
      "linuxvm-certificates-prod" = {
        principal_id               = "${TF_VAR_TERRAFORM_AZURE_RUNNER_MNG_ID_PROD}"
        role_definition_id_or_name = "Key Vault Certificates Officer"
      }
      "linuxvm-non-prod2" = {
        principal_id               = "${TF_VAR_TERRAFORM_AZURE_RUNNER_MNG_ID_NON_PROD2}"
        role_definition_id_or_name = "Key Vault Secrets Officer"
      }
      "linuxvm-certificates-non-prod2" = {
        principal_id               = "${TF_VAR_TERRAFORM_AZURE_RUNNER_MNG_ID_NON_PROD2}"
        role_definition_id_or_name = "Key Vault Certificates Officer"
      }
      "linuxvm-prod2" = {
        principal_id               = "${TF_VAR_TERRAFORM_AZURE_RUNNER_MNG_ID_PROD2}"
        role_definition_id_or_name = "Key Vault Secrets Officer"
      }
      "linuxvm-certificates-prod2" = {
        principal_id               = "${TF_VAR_TERRAFORM_AZURE_RUNNER_MNG_ID_PROD2}"
        role_definition_id_or_name = "Key Vault Certificates Officer"
      }
      "contoso-admins-secrets" = {
        principal_id               = "${TF_VAR_TERRAFORM_AZURE_CONTOSO_ADMINS_GROUP_ID}"
        role_definition_id_or_name = "Key Vault Secrets Officer"
        principal_type             = "Group"
      }
      "contoso-admins-certificates" = {
        principal_id               = "${TF_VAR_TERRAFORM_AZURE_CONTOSO_ADMINS_GROUP_ID}"
        role_definition_id_or_name = "Key Vault Certificates Officer"
        principal_type             = "Group"
      }
      "contoso-devs" = {
        principal_id               = "${TF_VAR_TERRAFORM_AZURE_CONTOSO_DEVS_GROUP_ID}"
        role_definition_id_or_name = "Key Vault Secrets Officer"
      }
    }

    tags = {
      Category    = "Key Vault"
      SubCategory = "platform"
      Department  = "IT"
    }
  }
}

######################################################################################
# Backup Vaults
######################################################################################
backup_vaults = {
  main = {
    resource_group_key = "core"
    resource           = "backup-vault"

    # Storage Configuration
    backup_storage_account_tier     = "Standard"
    backup_storage_replication_type = "LRS"

    # Backup Vault Configuration
    backup_vault_datastore_type = "VaultStore"
    backup_vault_redundancy     = "LocallyRedundant"

    # Backup Policy Configuration
    backup_frequency          = "R/2024-01-01T00:00:00+00:00/P1D" # Daily backups
    backup_retention_days     = 7
    backup_retention_criteria = "FirstOfDay"

    # Backup Instance Configuration
    backup_excluded_namespaces              = ["kube-system", "kube-public"]
    backup_included_namespaces              = ["default"]
    backup_excluded_resource_types          = []
    backup_included_resource_types          = []
    backup_label_selectors                  = []
    backup_cluster_scoped_resources_enabled = true
    backup_volume_snapshot_enabled          = true

    # RBAC Configuration
    backup_vault_aks_role     = "Contributor"
    backup_vault_storage_role = "Storage Blob Data Contributor"

    tags = {
      Category    = "Backup"
      SubCategory = "aks"
      Department  = "IT"
    }
  }
}

# Flux GitOps Configuration
# =============================================================================

# Enable the Flux v2 extension on AKS
fluxcd_enabled = true
# GitHub repository settings
flux_github_owner      = "contoso-grp"          # GitHub organization or username
flux_github_repository = "Apps-GitOps"           # Repository name for Flux manifests
flux_github_branch     = "main"                     # Branch to track (default: main)
flux_github_path       = "./contoso/flux/clusters/ilc-dev"      # Path within repo for manifests (empty = auto-generate from env)

# Flux namespace (default: flux-system)

flux_namespace_name = "flux-system"

# SSH private key for GitHub access (base64 encoded)

# Recommended: Set via environment variable TF_VAR_flux_ssh_private_key

# flux_ssh_private_key = "base64-encoded-private-key"
create_kubernetes_secret = true

######################################################################################
# Static Web App
######################################################################################
static_web_apps = {
  FE = {
    prefix   = "FrontEnd"
    sku_tier = "Standard"
    resource_group_key = "core"

    private_endpoint = {
      resource_group_name = "ILCentral-LZ-Contoso-Dev-rg-net"
      vnet_name           = "ILCentral-LZ-Contoso-Dev-vnet"
      subnet_name         = "ILCentral-LZ-Contoso-Dev-deps-pe-subnet"
    }
    private_dns_zone = {
      resource_group_name   = "ILCentral-LZ-IT-Shared-rg-net"
      private_dns_zone_name = "privatelink.azurestaticapps.net"
    }

    tags = {
      Category    = "Frontend"
      SubCategory = "StaticWebApp"
      Department  = "IT"
    }

    role_assignments = {
      "contoso-devs-website-contributor" = {
        role_definition_id_or_name = "Website Contributor"
        principal_id               = "${TF_VAR_TERRAFORM_AZURE_CONTOSO_GALWEB_DEVS_GROUP_ID}"
        principal_type             = "Group"
      }
    }
  }
  
  IDP = {
    prefix   = "IDP"
    sku_tier = "Standard"
    resource_group_key = "core"

    private_endpoint = {
      resource_group_name = "ILCentral-LZ-Contoso-Dev-rg-net"
      vnet_name           = "ILCentral-LZ-Contoso-Dev-vnet"
      subnet_name         = "ILCentral-LZ-Contoso-Dev-deps-pe-subnet"
    }
    private_dns_zone = {
      resource_group_name   = "ILCentral-LZ-IT-Shared-rg-net"
      private_dns_zone_name = "privatelink.azurestaticapps.net"
    }

    tags = {
      Category    = "Frontend"
      SubCategory = "StaticWebApp"
      Department  = "IT"
    }

    role_assignments = {
      "contoso-devs-website-contributor" = {
        role_definition_id_or_name = "Website Contributor"
        principal_id               = "${TF_VAR_TERRAFORM_AZURE_CONTOSO_GALWEB_DEVS_GROUP_ID}"
        principal_type             = "Group"
      }
    }
  }
}

######################################################################################
# Azure Function Apps
######################################################################################

# function_app_private_dns_zone = {
#   subscriptions         = "${TF_VAR_IT_SHARED_SUBSCRIPTION_ID}"
#   resourceGroups        = "ILCentral-LZ-IT-Shared-rg-net"
#   private_dns_zone_name = "privatelink.azurewebsites.net"
# }

# function_apps = {
#   main = {
#     resource_group_key = "core"
#     resource           = "func"

#     # App Service Plan
#     sku_name               = "B1"
#     zone_balancing_enabled = false
#     os_type                = "Windows"

#     # Function App Runtime
#     dotnet_version              = "v8.0"
#     use_dotnet_isolated_runtime = true
#     functions_extension_version = "~4"
#     app_settings                = {}

#     # Storage Account (created via storage-account module)
#     storage_account = {
#       account_tier                  = "Standard"
#       account_replication_type      = "LRS"
#       public_network_access_enabled = false
#       role_assignments = {
#         "contoso-admins" = {
#           role_definition_name = "Storage Blob Data Contributor"
#           principal_id         = "${TF_VAR_TERRAFORM_AZURE_CONTOSO_ADMINS_GROUP_ID}"
#           principal_type       = "Group"
#         }
#         "contoso-devs" = {
#           role_definition_name = "Storage Blob Data Contributor"
#           principal_id         = "${TF_VAR_TERRAFORM_AZURE_CONTOSO_DEVS_GROUP_ID}"
#           principal_type       = "Group"
#         }
#       }
#     }

#     # Networking
#     public_network_access_enabled = false

#     vnet_integration_subnet = {
#       resource_group_name = "ILCentral-LZ-Contoso-Dev-rg-net"
#       vnet_name           = "ILCentral-LZ-Contoso-Dev-vnet"
#       subnet_name         = "ILCentral-LZ-Contoso-Dev-portal-reserved-subnet"
#     }

#     private_endpoint = {
#       resource_group_name = "ILCentral-LZ-Contoso-Dev-rg-net"
#       vnet_name           = "ILCentral-LZ-Contoso-Dev-vnet"
#       subnet_name         = "ILCentral-LZ-Contoso-Dev-deps-pe-subnet"
#     }

#     # Identity
#     managed_identities = {
#       system_assigned = true
#     }

#     # RBAC
#     role_assignments = {
#       "contoso-admins" = {
#         role_definition_id_or_name = "Contributor"
#         principal_id               = "${TF_VAR_TERRAFORM_AZURE_CONTOSO_ADMINS_GROUP_ID}"
#         principal_type             = "Group"
#       }
#       "contoso-devs" = {
#         role_definition_id_or_name = "Contributor"
#         principal_id               = "${TF_VAR_TERRAFORM_AZURE_CONTOSO_DEVS_GROUP_ID}"
#         principal_type             = "Group"
#       }
#     }

#     tags = {
#       Category    = "FunctionApp"
#       SubCategory = "platform"
#       Department  = "IT"
#     }
#   }
# }

######################################################################################
# Cross-state Service Bus Role Assignments
# Grant AKS node (kubelet) identity "Azure Service Bus Data Sender" on Service Bus
# namespaces managed by a different Terraform state (e.g. shared-il-non-prod).
######################################################################################
external_servicebus_scope_ids = [
  "/subscriptions/${TF_VAR_CONTOSO_SHARED_NON_PROD_SUBSCRIPTION_ID}/resourceGroups/ILCentral-LZ-Contoso-Shared-Non-Prod-rg-core/providers/Microsoft.ServiceBus/namespaces/ILCentral-LZ-Contoso-Shared-Non-Prod-servicebus"
]

######################################################################################
# Cross-state Storage Account Role Assignments
# Grant AKS node (kubelet) identity "Storage Blob Data Contributor" on Storage Accounts
# managed by a different Terraform state (e.g. shared-il-non-prod).
######################################################################################
external_storage_scope_ids = [
  "/subscriptions/${TF_VAR_CONTOSO_SHARED_NON_PROD_SUBSCRIPTION_ID}/resourceGroups/ILCentral-LZ-Contoso-Shared-Non-Prod-rg-core/providers/Microsoft.Storage/storageAccounts/ilcshnonprdexporttoexcel"
]