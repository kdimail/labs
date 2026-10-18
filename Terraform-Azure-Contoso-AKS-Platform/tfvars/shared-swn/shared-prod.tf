######################################################################################
# ENVIRONMENT & NAMING
######################################################################################
env              = "Shared-Prod"
region           = "SwitzerlandNorth"
team             = "Contoso"
company_location = "ISIL"
location         = "switzerlandnorth"

region_short = "SwitzerlandNo"
region_short_v2 = "SWN"
team_short = "hzn"
env_short  = "ShProd"

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
vnet_name                = "Switzerlandnorth-LZ-Contoso-Shared-Prod-vnet"
vnet_resource_group_name = "Switzerlandnorth-LZ-Contoso-Shared-Prod-rg-net"

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
  keyvault = {
    zone_name           = "privatelink.vaultcore.azure.net"
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
acr_registries = {
  main = {
    resource_group_key = "core"
    resource           = "acr"

    acr_sku                       = "Premium"
    admin_enabled                 = false
    public_network_access_enabled = false
    enable_private_endpoint       = true

    acr_network_resource_group_name_for_pe = "Switzerlandnorth-LZ-Contoso-Shared-Prod-rg-net"
    acr_vnet_name_for_pe                   = "Switzerlandnorth-LZ-Contoso-Shared-Prod-vnet"
    acr_subnet_name_for_pe                 = "Switzerlandnorth-LZ-Contoso-Shared-Prod-deps-pe-subnet"

    acr_private_dns_zone_resource_id = {
      subscriptions  = "${TF_VAR_IT_SHARED_SUBSCRIPTION_ID}"
      resourceGroups = "ILCentral-LZ-IT-Shared-rg-net"
    }
    acr_private_dns_zone_name = "privatelink.azurecr.io"

    acr_additional_vnet_links = {}

    enable_geo_replication            = true
    zone_redundancy_enabled           = true
    geo_replication_locations         = ["westus3"]
    # geo_replication_private_endpoints = {}
    geo_replication_private_endpoints = {
      westus3 = {
        location             = "westus3"
        resource_group_name  = "WestUS3-LZ-Contoso-Shared-Prod-rg-net"
        vnet_name            = "WestUS3-LZ-Contoso-Shared-Prod-vnet"
        subnet_name          = "WestUS3-LZ-Contoso-Shared-Prod-aks-nodes-subnet"
        private_dns_zone_ids = []
      }
    }

    acr_role_assignments = [
      {
        principal_id = "${TF_VAR_TERRAFORM_AZURE_RUNNER_MNG_ID_NON_PROD}" # Linux VM managed identity
        roles        = ["AcrPull", "AcrPush", "Contributor"]
        description  = "Linux VM - Docker pull/push access"
      },
      {
        principal_id = "${TF_VAR_TERRAFORM_AZURE_RUNNER_MNG_ID_PROD}" # Linux VM managed identity
        roles        = ["AcrPull", "AcrPush", "Contributor"]
        description  = "Linux VM - Docker pull/push access"
      },
      {
        principal_id = "${TF_VAR_TERRAFORM_AZURE_RUNNER_MNG_ID_NON_PROD2}" # Linux VM managed identity
        roles        = ["AcrPull", "AcrPush", "Contributor"]
        description  = "Linux VM - Docker pull/push access"
      },
      {
        principal_id = "${TF_VAR_TERRAFORM_AZURE_RUNNER_MNG_ID_PROD2}" # Linux VM managed identity
        roles        = ["AcrPull", "AcrPush", "Contributor"]
        description  = "Linux VM - Docker pull/push access"
      },
      {
        principal_id   = "${TF_VAR_TERRAFORM_AZURE_CONTOSO_ADMINS_GROUP_ID}"
        roles          = ["AcrPull", "AcrPush"]
        description    = "Contoso Admins Group - Docker pull/push/delete access for management"
        principal_type = "Group"
      },
      {
        principal_id   = "${TF_VAR_TERRAFORM_AZURE_CONTOSO_DEVS_GROUP_ID}"
        roles          = ["AcrPull"]
        description    = "Contoso Devs Group - Docker pull access for development"
        principal_type = "Group"
      }
    ]

    tags = {
      Category    = "ACR"
      SubCategory = "platform"
      Department  = "IT"
    }
  }
}
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
    nodes_network_resource_group_name = "Switzerlandnorth-LZ-Contoso-Shared-Prod-rg-net"
    nodes_vnet_name                   = "Switzerlandnorth-LZ-Contoso-Shared-Prod-vnet"
    nodes_subnet_name                 = "Switzerlandnorth-LZ-Contoso-Shared-Prod-aks-nodes-subnet"

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
        vnet_id              = "/subscriptions/${TF_VAR_IT_SHARED_SUBSCRIPTION_ID}/resourceGroups/Switzerlandnorth-LZ-IT-Shared-rg-net/providers/Microsoft.Network/virtualNetworks/Switzerlandnorth-LZ-IT-Shared-vnet"
        
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
      private_dns_zone_name = "private.switzerlandnorth.azmk8s.io"
    }

    # ACR Configuration - Attached ACRs
    # Split into components for better readability and maintainability
    # Full resource ID will be constructed automatically
    attached_acr_id_map = {
      shared = {
        subscription_id     = "${TF_VAR_subscription_aks_id}"
        resource_group_name = "Switzerlandnorth-LZ-Contoso-Shared-Prod-rg-core"
        acr_name            = "SwitzerlandNoLZhznShProd"
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
      node_count                   = 3
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
        min_count                   = 3
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
      resource_group_name = "ILCentral-LZ-IT-Shared-rg-deps"
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

    keyvault_network_resource_group_name_for_pe = "Switzerlandnorth-LZ-Contoso-Shared-Prod-rg-net"
    keyvault_vnet_name_for_pe                   = "Switzerlandnorth-LZ-Contoso-Shared-Prod-vnet"
    keyvault_subnet_name_for_pe                 = "Switzerlandnorth-LZ-Contoso-Shared-Prod-deps-pe-subnet"

    keyvault_private_dns_zone_kv_resource_id = {
      subscriptions  = "${TF_VAR_IT_SHARED_SUBSCRIPTION_ID}"
      resourceGroups = "ILCentral-LZ-IT-Shared-rg-net"
    }
    keyvault_private_dns_zone_name = "privatelink.vaultcore.azure.net"
    keyvault_additional_vnet_links = {}

    keyvault_network_acls = {
      default_action             = "Deny"
      bypass                     = "AzureServices"
      ip_rules                   = []
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
flux_github_path       = "./contoso/flux/clusters/switzerlandnorth-shared-prod"      # Path within repo for manifests (empty = auto-generate from env)

# Flux namespace (default: flux-system)

flux_namespace_name = "flux-system"

# SSH private key for GitHub access (base64 encoded)

# Recommended: Set via environment variable TF_VAR_flux_ssh_private_key

# flux_ssh_private_key = "base64-encoded-private-key"
create_kubernetes_secret = true

static_web_apps = {
  # FE = {
  #   prefix   = "FrontEnd"
  #   sku_tier = "Standard"
  #   resource_group_key = "core"

  #   tags = {
  #     Category    = "Frontend"
  #     SubCategory = "StaticWebApp"
  #     Department  = "IT"
  #   }
  # }
}

######################################################################################
# PostgreSQL Flexible Server
######################################################################################
postgres_servers = {
  main = {
    pg_password="admin"
    resource_group_key = "core"
    resource           = "pg"

    # Delegated subnet (must be delegated to Microsoft.DBforPostgreSQL/flexibleServers)
    delegated_subnet = {
      resource_group_name = "Switzerlandnorth-LZ-Contoso-Shared-Prod-rg-net"
      vnet_name           = "Switzerlandnorth-LZ-Contoso-Shared-Prod-vnet"
      subnet_name         = "Switzerlandnorth-LZ-Contoso-Shared-Prod-postgres-subnet"
    }
    # Private DNS zone for PostgreSQL (e.g. privatelink.postgres.database.azure.com)
    private_dns_zone = {
      subscriptions         = "${TF_VAR_IT_SHARED_SUBSCRIPTION_ID}"
      resourceGroups        = "ILCentral-LZ-IT-Shared-rg-net"
      private_dns_zone_name = "privatelink.postgres.database.azure.com"
    }
    public_network_access_enabled = false

    sku_name         = "GP_Standard_D2ds_v5"
    postgres_version = "16"
    storage_mb       = 65536
    storage_tier     = "P20"
    auto_grow_enabled = true
    availability_zone = "1"

    backup_retention_days        = 35
    geo_redundant_backup_enabled = false

    high_availability = {
      mode                      = "ZoneRedundant"
      standby_availability_zone = "2"
    }

    maintenance_window = {
      day_of_week  = 0
      start_hour   = 2
      start_minute = 0
    }

    # Omit subscription_id to use var.subscription_id (provider subscription)
    log_analytics_workspace_id = {
      subscriptions  = "${TF_VAR_IT_SHARED_SUBSCRIPTION_ID}"
      resourceGroups = "ILCentral-LZ-IT-Shared-rg-deps"
      workspace_name = "ILCentral-LZ-IT-Shared-log-analytics"
    }
    server_log_retention_days  = 7
    diagnostic_log_categories  = ["PostgreSQLLogs"]
    diagnostic_metrics_enabled = false

    administrator_login = "pgadmin"
    # Authentication: allow both (1) user + password and (2) Azure AD
    authentication = {
      password_auth_enabled         = true  # login with administrator_login + TF_VAR_pg_password
      active_directory_auth_enabled = true  # Azure AD / Microsoft Entra sign-in
      # tenant_id = "" # optional; omit to use default tenant
    }

    # Allow AKS pods to connect using workload identity (managed identity). Keys match AKS workload_identities.
    # grant_postgres_to_workload_identity_keys = ["external-secrets"]
    grant_postgres_to_workload_identity_keys = []

    databases  = {}
    configurations = {}
    firewall_rules  = {}
    role_assignments = {
      "contoso-admins" = {
        principal_id         = "${TF_VAR_TERRAFORM_AZURE_CONTOSO_ADMINS_GROUP_ID}"
        role_definition_name = "Contributor"
        principal_type       = "Group"
      }
      "contoso-devs" = {
        principal_id         = "${TF_VAR_TERRAFORM_AZURE_CONTOSO_DEVS_GROUP_ID}"
        role_definition_name = "Contributor"
        principal_type       = "Group"
      }
    }

    tags = {
      Category    = "PostgreSQL"
      SubCategory = "platform"
      Department  = "IT"
    }
  }
}

servicebus = {
  resource_group_key = "core"
  name              = "servicebus" # 6–50 chars; must not end with -sb, -mgmt, or hyphen (Azure)
  sku               = "Premium"   # smallest tier that supports private endpoint; capacity 1
  capacity          = 1
  public_network_access_enabled = false
  local_auth_enabled            = false
  minimum_tls_version          = "1.2"

  private_endpoint = {
    resource_group_name = "Switzerlandnorth-LZ-Contoso-Shared-Prod-rg-net"
    vnet_name           = "Switzerlandnorth-LZ-Contoso-Shared-Prod-vnet"
    subnet_name         = "Switzerlandnorth-LZ-Contoso-Shared-Prod-deps-pe-subnet"
  }

  private_dns_zone = {
    subscriptions         = "${TF_VAR_IT_SHARED_SUBSCRIPTION_ID}"
    resourceGroups        = "ILCentral-LZ-IT-Shared-rg-net"
    private_dns_zone_name = "privatelink.servicebus.windows.net"
  }

  network_rule_subnet_ids              = []
  network_rule_cidr_or_ip_rules        = []
  network_rule_trusted_services_allowed = false

  queues = {}
  topics = {}

  role_assignments = {
    "contoso-admins" = {
      principal_id         = "${TF_VAR_TERRAFORM_AZURE_CONTOSO_ADMINS_GROUP_ID}"
      role_definition_name = "Azure Service Bus Data Owner"
      principal_type       = "Group"
    }
    "contoso-devs" = {
      principal_id         = "${TF_VAR_TERRAFORM_AZURE_CONTOSO_DEVS_GROUP_ID}"
      role_definition_name = "Azure Service Bus Data Owner"
      principal_type       = "Group"
    }
  }
  grant_servicebus_to_workload_identity_keys = ["external-secrets"]

  tags = {
    Category    = "ServiceBus"
    SubCategory = "platform"
    Department  = "IT"
  }
}

######################################################################################
# Azure Managed Redis (production-grade, internal-only, private endpoint)
######################################################################################
# AKS pods connect via workload identity; add keys to grant_redis_to_workload_identity_keys.
# Matches current azurerm_managed_redis schema (cluster + default_database).
######################################################################################
managed_redis = {
  resource_group_key = "core"
  name               = "redis"
  # Valid SKUs: Balanced_B*, ComputeOptimized_X*, FlashOptimized_A*, MemoryOptimized_M*; smallest = Balanced_B0
  sku_name           = "Balanced_B0"
  public_network_access_enabled = false
  high_availability_enabled     = true

  identity = {
    type         = "SystemAssigned"
    identity_ids = null
  }

  default_database = {
    access_keys_authentication_enabled = true
    client_protocol                    = "Encrypted"
    clustering_policy                  = "OSSCluster"
    eviction_policy                    = "VolatileLRU"
  }

  private_endpoint = {
    resource_group_name = "Switzerlandnorth-LZ-Contoso-Shared-Prod-rg-net"
    vnet_name           = "Switzerlandnorth-LZ-Contoso-Shared-Prod-vnet"
    subnet_name         = "Switzerlandnorth-LZ-Contoso-Shared-Prod-deps-pe-subnet"
  }
  # Use existing private DNS zone (create_private_dns_zone = false).
  create_private_dns_zone = false
  private_dns_zone = {
    subscriptions         = "${TF_VAR_IT_SHARED_SUBSCRIPTION_ID}"
    resourceGroups        = "ILCentral-LZ-IT-Shared-rg-net"
    private_dns_zone_name = "privatelink.redis.azure.net"
  }

  role_assignments = {
    "contoso-admins" = {
      principal_id         = "${TF_VAR_TERRAFORM_AZURE_CONTOSO_ADMINS_GROUP_ID}"
      role_definition_name = "Contributor"
      principal_type       = "Group"
    }
    "contoso-devs" = {
      principal_id         = "${TF_VAR_TERRAFORM_AZURE_CONTOSO_DEVS_GROUP_ID}"
      role_definition_name = "Contributor"
      principal_type       = "Group"
    }
  }

  grant_redis_to_workload_identity_keys = ["external-secrets"]

  tags = {
    Category    = "Redis"
    SubCategory = "platform"
    Department  = "IT"
  }
}

######################################################################################
#Storage Accounts
######################################################################################
storage_accounts = {
  centrifugo = {
    resource_group_key = "core"
    resource           = "st"

    name                     = "exporttoexcel"
    account_tier             = "Standard"
    account_replication_type = "ZRS"
    account_kind             = "StorageV2"

    public_network_access_enabled = false
    shared_access_key_enabled     = true

    enable_network_rules         = true
    network_rules_bypass         = ["AzureServices"]
    network_rules_default_action = "Deny"
    allowed_ip_addresses         = ["212.25.106.78"]
    allowed_subnet_ids           = []

    containers = {
      exporttoexcel = { name = "export-to-excel" }
    }

    private_endpoint = {
      resource_group_name = "Switzerlandnorth-LZ-Contoso-Shared-Prod-rg-net"
      vnet_name           = "Switzerlandnorth-LZ-Contoso-Shared-Prod-vnet"
      subnet_name         = "Switzerlandnorth-LZ-Contoso-Shared-Prod-deps-pe-subnet"
    }

    private_dns_zone = {
      subscriptions         = "${TF_VAR_IT_SHARED_SUBSCRIPTION_ID}"
      resourceGroups        = "ILCentral-LZ-IT-Shared-rg-net"
      private_dns_zone_name = "privatelink.blob.core.windows.net"
    }

    # Delete exported Excel files after 1 day (Azure lifecycle management minimum).
    # The application should issue SAS tokens with a 2-hour expiry for download URLs.
    blob_delete_after_days = 1

    tags = {
      Category    = "storage-account"
      SubCategory = "contoso-export-to-excel"
      Department  = "IT"
    }
  }
}