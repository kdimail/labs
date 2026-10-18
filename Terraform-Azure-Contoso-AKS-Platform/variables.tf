# Azure Provider Configuration
variable "subscription_id" {
  description = "Azure subscription ID"
  type        = string
  default     = ""
}

variable "it_shared_subscription_id" {
  description = "Azure subscription ID of the IT-Shared subscription where central private DNS zones live."
  type        = string
  default     = ""
}

######################################################################################
# VNet Lookup for Central DNS Zone Linking
######################################################################################
variable "vnet_name" {
  description = "Name of this environment's VNet. Used to link the VNet to central IT-Shared private DNS zones."
  type        = string
  default     = null
}

variable "vnet_resource_group_name" {
  description = "Resource group of this environment's VNet."
  type        = string
  default     = null
}

variable "central_dns_zone_links" {
  description = "Map of private DNS zones to link this environment's VNet to. Omit subscription_id (or set null) for zones in IT-Shared — those use the azurerm.it_shared provider. Set subscription_id for zones in the current AKS subscription or any other subscription that maps to the default provider (e.g. ingress/ssl zones)."
  type = map(object({
    zone_name           = string
    zone_resource_group = string
    subscription_id     = optional(string, null)
  }))
  default = {}
}

# Resource Groups
variable "resource_groups" {
  description = "Map of resource groups to create"
  type = map(object({
    resource = string
    role     = string
    tags     = optional(map(string), {})
    role_assignments = optional(map(object({
      role_definition_id_or_name             = string
      principal_id                           = string
      description                            = optional(string, null)
      skip_service_principal_aad_check       = optional(bool, false)
      condition                              = optional(string, null)
      condition_version                      = optional(string, null)
      delegated_managed_identity_resource_id = optional(string, null)
      principal_type                         = optional(string, null)
    })), {})
  }))
  default = {}
}

# Resource Naming Convention

variable "env" {
  description = "Environment name"
  type        = string
  default     = ""
}

variable "region" {
  description = "Region code"
  type        = string
  default     = ""
}

variable "company_location" {
  description = "Organization location code (e.g., ISIL)"
  type        = string
  default     = ""
}

variable "location" {
  description = "Azure region location (e.g., israelcentral)"
  type        = string
  default     = ""
}

variable "role" {
  description = "Role of the resource"
  type        = string
  default     = ""
}

# Tags

variable "terraform" {
  description = "Indicates if resource is managed by Terraform"
  type        = string
  default     = "true"
}

variable "team" {
  description = "Team responsible for the resource"
  type        = string
  default     = ""
}

variable "team_short" {
  description = "Short code for the team"
  type        = string
  default     = ""
}

variable "env_short" {
  description = "Short code for the environment"
  type        = string
  default     = ""
}

variable "env_short_v2" {
  description = "Short code for the environment (v2). When set, takes precedence over env_short."
  type        = string
  default     = null
}

variable "region_short" {
  description = "Short code for the region"
  type        = string
  default     = ""
}

variable "region_short_v2" {
  description = "Short code for the region (v2)"
  type        = string
  default     = ""
}

variable "businessservice" {
  description = "Business service name"
  type        = string
  default     = ""
}

variable "owner" {
  description = "Owner of the resource"
  type        = string
  default     = ""
}

variable "CreatedBy" {
  description = "Creator of the resource"
  type        = string
  default     = ""
}

variable "managedby" {
  description = "Management method"
  type        = string
  default     = "Terraform"
}

######################################################################################
# Object-Based Resource Definitions
######################################################################################

# ACR Registries
variable "acr_registries" {
  description = "Map of ACR registries to create"
  type = map(object({
    resource_group_key                     = string
    resource                               = string
    acr_sku                                = string
    admin_enabled                          = bool
    public_network_access_enabled          = bool
    enable_private_endpoint                = bool
    acr_network_resource_group_name_for_pe = string
    acr_vnet_name_for_pe                   = string
    acr_subnet_name_for_pe                 = string
    acr_private_dns_zone_resource_id = object({
      subscriptions  = string
      resourceGroups = string
    })
    acr_private_dns_zone_name = string
    acr_additional_vnet_links = map(object({
      vnet_id              = string
      registration_enabled = bool
    }))
    enable_geo_replication    = bool
    zone_redundancy_enabled   = bool
    geo_replication_locations = list(string)
    geo_replication_private_endpoints = map(object({
      location               = string
      resource_group_name    = string
      vnet_name              = string
      subnet_name            = string
      pe_resource_group_name = optional(string)
      private_dns_zone_ids   = list(string)
    }))
    acr_role_assignments = list(object({
      principal_id = string
      roles        = list(string)
      description  = string
    }))
    acr_allowed_ip_addresses = optional(list(string), [])
    tags                     = optional(map(string), {})
  }))
  default = {}
}

# AKS Clusters
variable "aks_clusters" {
  description = "Map of AKS clusters to create"
  type = map(object({
    resource_group_key                  = string
    resource                            = string
    sku_tier                            = string
    kubernetes_version                  = string
    automatic_channel_upgrade           = optional(string)
    node_os_channel_upgrade             = string
    upgrade_override = optional(object({
      force_upgrade_enabled = bool
      effective_until       = optional(string)
    }))
    private_cluster_enabled             = bool
    private_cluster_public_fqdn_enabled = bool
    enable_telemetry                    = bool
    aks_private_dns_zone_mode           = string
    aks_private_dns_zone_id = object({
      subscription_id       = string
      resource_group_name   = string
      private_dns_zone_name = string
    })
    attached_acr_id_map = map(object({
      subscription_id     = string
      resource_group_name = string
      acr_name            = string
    }))
    nodes_network_resource_group_name = string
    nodes_vnet_name                   = string
    nodes_subnet_name                 = string
    network_plugin                    = string
    network_plugin_mode               = string
    network_dataplane                 = string
    network_policy                    = optional(string)
    outbound_type                     = string
    net_profile_pod_cidr              = string
    net_profile_service_cidr          = string
    net_profile_dns_service_ip        = string
    role_based_access_control_enabled = bool
    rbac_aad_azure_rbac_enabled       = bool
    oidc_issuer_enabled               = bool
    workload_identity_enabled         = bool
    vm_cluster_admin_principal_ids = map(object({
      principal_id   = string
      principal_type = optional(string, null) # e.g. "Group", "ServicePrincipal", "User". Null = Azure auto-infers.
    }))
    default_node_pool = object({
      name                         = string
      node_public_ip_enabled       = bool
      zones                        = list(string)
      node_count                   = number
      min_count                    = optional(number)
      max_count                    = optional(number)
      enable_auto_scaling          = bool
      vm_size                      = string
      only_critical_addons_enabled = bool
      temporary_name_for_rotation  = string
      orchestrator_version         = optional(string)
      os_sku                       = string
      upgrade_settings = object({
        max_surge                     = string
        node_soak_duration_in_minutes = number
        drain_timeout_in_minutes      = number
      })
    })
    node_pools = map(object({
      name                        = string
      node_public_ip_enabled      = bool
      zones                       = list(string)
      node_count                  = optional(number)
      min_count                   = optional(number)
      max_count                   = optional(number)
      auto_scaling_enabled        = bool
      vm_size                     = string
      temporary_name_for_rotation = string
      node_labels                 = map(string)
      node_taints                 = list(string)
      max_pods                    = number
      mode                        = string
      os_sku                      = string
      orchestrator_version        = optional(string)
      upgrade_settings = object({
        max_surge                     = string
        node_soak_duration_in_minutes = number
        drain_timeout_in_minutes      = number
      })
    }))
    storage_profile_disk_driver_enabled         = bool
    storage_profile_file_driver_enabled         = bool
    storage_profile_blob_driver_enabled         = bool
    storage_profile_snapshot_controller_enabled = bool
    service_mesh_profile = optional(object({
      mode                             = string
      internal_ingress_gateway_enabled = bool
      external_ingress_gateway_enabled = bool
    }))
    workload_autoscaler_profile = object({
      keda_enabled = bool
    })
    image_cleaner_enabled        = bool
    image_cleaner_interval_hours = number
    web_app_routing = object({
      dns_zone_ids             = optional(list(string))
      default_nginx_controller = string
    })
    workload_identities = map(object({
      identity_name        = string
      kubernetes_namespace = string
      service_account_name = string
      roles = list(object({
        scope           = string
        definition_name = string
      }))
    }))
    ingress_private_dns_zone_resource_id = optional(object({
      subscription_id     = string
      resource_group_name = string
      dns_zone_name       = string
    }))
    ingress_dns_zone_additional_vnet_links = map(object({
      vnet_id              = string
      registration_enabled = bool
    }))
    maintenance_window              = optional(any)
    maintenance_window_auto_upgrade = optional(any)
    maintenance_window_node_os      = optional(any)
    log_analytics_workspace_id = object({
      subscription_id     = string
      resource_group_name = string
      workspace_name      = string
    })
    enable_container_insights   = bool
    monitor_metrics_enabled     = bool
    enable_application_insights = bool
    application_insights_type   = string
    cost_analysis_enabled       = bool
    enable_oms_agent            = optional(bool, true)
    # Optional: minimize Log Analytics ingestion (defaults in AKS module if omitted)
    # Use diagnostic_log_categories for individual categories (e.g. ["kube-audit-admin"]).
    # Use diagnostic_log_groups for coarse groups (["audit"] or ["allLogs"]). Use one or the other.
    diagnostic_log_categories    = optional(list(string), [])
    diagnostic_log_groups        = optional(list(string), [])
    diagnostic_metric_categories = optional(list(string), [])

    fluxcd_enabled             = bool
    azure_policy_enabled       = bool
    microsoft_defender_enabled = bool
    tags                       = optional(map(string), {})
  }))
  default = {}
}


# Key Vaults
variable "key_vaults" {
  description = "Map of Key Vaults to create"
  type = map(object({
    resource_group_key                          = string
    resource                                    = string
    keyvault_sku_name                           = string
    soft_delete_retention_days                  = number
    purge_protection_enabled                    = bool
    keyvault_network_resource_group_name_for_pe = string
    keyvault_vnet_name_for_pe                   = string
    keyvault_subnet_name_for_pe                 = string
    keyvault_private_dns_zone_kv_resource_id = object({
      subscriptions  = string
      resourceGroups = string
    })
    keyvault_private_dns_zone_name = string
    keyvault_additional_vnet_links = map(object({
      vnet_id              = string
      registration_enabled = bool
    }))
    keyvault_network_acls = object({
      default_action             = string
      bypass                     = string
      ip_rules                   = list(string)
      virtual_network_subnet_ids = list(string)
    })
    keyvault_rbac = map(object({
      principal_id               = string
      role_definition_id_or_name = string
      principal_type             = optional(string, null) # e.g. "Group", "ServicePrincipal", "User". Null = Azure auto-infers.
    }))
    tags = optional(map(string), {})
  }))
  default = {}
}

# Backup Vaults
variable "backup_vaults" {
  description = "Map of Backup Vaults to create for AKS"
  type = map(object({
    resource_group_key                      = string
    resource                                = string
    backup_storage_account_tier             = string
    backup_storage_replication_type         = string
    backup_vault_datastore_type             = string
    backup_vault_redundancy                 = string
    backup_frequency                        = string
    backup_retention_days                   = number
    backup_retention_criteria               = string
    backup_excluded_namespaces              = list(string)
    backup_included_namespaces              = list(string)
    backup_excluded_resource_types          = list(string)
    backup_included_resource_types          = list(string)
    backup_label_selectors                  = list(string)
    backup_cluster_scoped_resources_enabled = bool
    backup_volume_snapshot_enabled          = bool
    backup_vault_aks_role                   = string
    backup_vault_storage_role               = string
    tags                                    = optional(map(string), {})
  }))
  default = {}
} # ============================================================================
# Azure Container Registry (ACR) Configuration
# ============================================================================

# ACR Basic Configuration
# ----------------------------------------------------------------------------

variable "create_acr" {
  description = "Whether to create an Azure Container Registry"
  type        = bool
  default     = false
}

variable "acr_sku" {
  description = "The SKU name of the container registry"
  type        = string
  default     = "Premium"
}

variable "admin_enabled" {
  description = "Specifies whether the admin user is enabled"
  type        = bool
  default     = false
}

variable "public_network_access_enabled" {
  description = "Whether public network access is allowed for the container registry"
  type        = bool
  default     = false
}

# ACR High Availability & Replication
# ----------------------------------------------------------------------------

variable "zone_redundancy_enabled" {
  description = "Whether zone redundancy is enabled"
  type        = bool
  default     = false
}

variable "enable_geo_replication" {
  description = "Whether to enable geo-replication"
  type        = bool
  default     = false
}

variable "geo_replication_locations" {
  description = "List of Azure locations for geo-replication"
  type        = list(string)
  default     = []
}

variable "geo_replication_private_endpoints" {
  description = "Map of geo-replication regions to private endpoint configuration"
  type = map(object({
    location               = string
    resource_group_name    = string
    vnet_name              = string
    subnet_name            = string
    pe_resource_group_name = optional(string)
    private_dns_zone_ids   = list(string)
  }))
  default = {}
}

# ACR Private Endpoint Configuration
# ----------------------------------------------------------------------------

variable "enable_private_endpoint" {
  description = "Whether to enable private endpoint"
  type        = bool
  default     = false
}

variable "acr_network_resource_group_name_for_pe" {
  description = "Network resource group name for private endpoint"
  type        = string
  default     = ""
}

variable "acr_vnet_name_for_pe" {
  description = "VNet name for private endpoint"
  type        = string
  default     = ""
}

variable "acr_subnet_name_for_pe" {
  description = "Subnet name for private endpoint"
  type        = string
  default     = ""
}

variable "acr_private_dns_zone_resource_id" {
  description = "Private DNS zone configuration object. Set to null to create a new DNS zone. Provide object with subscriptions and resourceGroups to use existing zone."
  type = object({
    subscriptions  = string
    resourceGroups = string
  })
  default = null
}

variable "acr_private_dns_zone_name" {
  description = "ACR private DNS zone name"
  type        = string
  default     = "privatelink.azurecr.io"
}

variable "acr_additional_vnet_links" {
  description = "Additional VNets to link to the ACR private DNS zone (for VMs/resources in other VNets)"
  type = map(object({
    vnet_id              = string
    registration_enabled = optional(bool, false)
  }))
  default = {}
}

# ACR RBAC Configuration
# ----------------------------------------------------------------------------

variable "acr_role_assignments" {
  description = "ACR role assignments"
  type = list(object({
    principal_id = string
    roles        = list(string)
    description  = string
  }))
  default = []
}

# ============================================================================
# Azure Kubernetes Service (AKS) Configuration
# ============================================================================

# AKS Basic Configuration
# ----------------------------------------------------------------------------

variable "create_aks" {
  description = "Whether to create AKS cluster"
  type        = bool
  default     = true
}

variable "aks_cluster_pre_exists" {
  description = "Set to false only on the very first deployment, before the AKS cluster exists. Prevents the kubernetes provider data source from failing with a 'not found' error on initial creation. Defaults to true for all subsequent runs."
  type        = bool
  default     = true
}

variable "aks_cluster_name" {
  description = "Name of the AKS cluster"
  type        = string
  default     = ""
}

variable "sku_tier" {
  description = "SKU tier for the AKS cluster (Free, Standard, Premium)"
  type        = string
  default     = "Standard"

  validation {
    condition     = contains(["Free", "Standard", "Premium"], var.sku_tier)
    error_message = "The sku_tier must be one of: Free, Standard, or Premium."
  }
}

variable "oidc_issuer_enabled" {
  description = "Enable OIDC issuer"
  type        = bool
  default     = true
}

variable "workload_identity_enabled" {
  description = "Enable workload identity"
  type        = bool
  default     = true
}

variable "workload_identities" {
  type = map(object({
    identity_name        = string
    kubernetes_namespace = string
    service_account_name = string
    roles = list(object({
      scope           = string
      definition_name = string
    }))
  }))
  default     = {}
  description = "Map of workload identities to create"
}

# AKS Node Pools Configuration
# ----------------------------------------------------------------------------

variable "default_node_pool" {
  description = "Configuration for the default node pool"
  type = object({
    name                         = string
    zones                        = list(string)
    node_count                   = number
    min_count                    = number
    max_count                    = number
    enable_auto_scaling          = bool
    vm_size                      = string
    only_critical_addons_enabled = bool
    temporary_name_for_rotation  = string
    upgrade_settings = object({
      max_surge                     = string
      node_soak_duration_in_minutes = number
    })
  })
  default = {
    name                         = "system"
    zones                        = ["1", "2", "3"]
    node_count                   = 3
    min_count                    = 3
    max_count                    = 6
    enable_auto_scaling          = true
    vm_size                      = "Standard_D4s_v3"
    only_critical_addons_enabled = false
    temporary_name_for_rotation  = "systemtemp"
    upgrade_settings = {
      max_surge                     = "33%"
      node_soak_duration_in_minutes = 0
    }
  }
}

variable "node_pools" {
  description = "Additional node pools configuration. Set node_count to null when auto_scaling_enabled is true."
  type = map(object({
    name                        = string
    zones                       = optional(set(string))
    node_count                  = optional(number)
    min_count                   = optional(number)
    max_count                   = optional(number)
    auto_scaling_enabled        = optional(bool)
    vm_size                     = string
    temporary_name_for_rotation = optional(string)
    node_labels                 = optional(map(string))
    node_taints                 = optional(list(string))
    max_pods                    = optional(number)
    mode                        = optional(string)
    os_sku                      = optional(string)
    vnet_subnet_id              = optional(string)
    upgrade_settings = object({
      max_surge                     = string
      node_soak_duration_in_minutes = number
      drain_timeout_in_minutes      = optional(number)
    })
  }))
  default = {}
}

# AKS Networking Configuration
# ----------------------------------------------------------------------------

variable "nodes_network_resource_group_name" {
  description = "Resource group name where networking resources are created"
  type        = string
  default     = ""
}

variable "nodes_vnet_name" {
  description = "Name of the existing VNet for AKS nodes"
  type        = string
  default     = ""
}

variable "nodes_subnet_name" {
  description = "Name of the existing nodes subnet"
  type        = string
  default     = ""
}

variable "network_plugin" {
  description = "Network plugin to use (azure, kubenet)"
  type        = string
  default     = "azure"

  validation {
    condition     = contains(["azure", "kubenet"], var.network_plugin)
    error_message = "The network_plugin must be either 'azure' or 'kubenet'."
  }
}

variable "network_plugin_mode" {
  description = "Network plugin mode (overlay for Azure CNI Overlay)"
  type        = string
  default     = null
}

variable "network_dataplane" {
  description = "Network dataplane (azure, cilium)"
  type        = string
  default     = "azure"

  validation {
    condition     = contains(["azure", "cilium"], var.network_dataplane)
    error_message = "The network_dataplane must be either 'azure' or 'cilium'."
  }
}

variable "network_policy" {
  description = "Network policy to use (azure, calico). Not used when Cilium is the dataplane"
  type        = string
  default     = "azure"
}

variable "net_profile_pod_cidr" {
  description = "CIDR for pod network (required for overlay mode)"
  type        = string
  default     = null
}

variable "net_profile_service_cidr" {
  description = "CIDR for service network (required for overlay mode)"
  type        = string
  default     = null
}

variable "net_profile_dns_service_ip" {
  description = "DNS service IP address (must be within service CIDR)"
  type        = string
  default     = null
}

variable "outbound_type" {
  description = "The outbound (egress) routing method (loadBalancer, userDefinedRouting, managedNATGateway, userAssignedNATGateway)"
  type        = string
  default     = "loadBalancer"

  validation {
    condition     = contains(["loadBalancer", "userDefinedRouting", "managedNATGateway", "userAssignedNATGateway"], var.outbound_type)
    error_message = "The outbound_type must be one of: loadBalancer, userDefinedRouting, managedNATGateway, or userAssignedNATGateway."
  }
}

# AKS Private DNS Configuration
# ----------------------------------------------------------------------------

variable "aks_private_dns_zone_mode" {
  type        = string
  default     = "System"
  description = "The private DNS zone mode for the AKS cluster. Possible values are 'System', 'Custom', or 'Existing'."

  validation {
    condition     = contains(["System", "Custom", "Existing"], var.aks_private_dns_zone_mode)
    error_message = "The aks_private_dns_zone_mode must be one of: System, Custom, Existing."
  }
}

variable "aks_private_dns_zone_id" {
  type = object({
    subscription_id       = string
    resource_group_name   = string
    private_dns_zone_name = string
  })
  default     = null
  description = "Existing private DNS zone reference (used when aks_private_dns_zone_mode is set to 'Existing')."

  validation {
    condition     = var.aks_private_dns_zone_mode != "Existing" || var.aks_private_dns_zone_id != null
    error_message = "aks_private_dns_zone_id must be provided when aks_private_dns_zone_mode is set to 'Existing'."
  }
}

variable "dns_zone_prefix" {
  description = "The prefix to use for AKS private DNS zone when `private_dns_zone_mode` is set to 'Custom'. If not specified, will use the cluster name"
  type        = string
  default     = null
}

# AKS Cluster Upgrade Configuration
# ----------------------------------------------------------------------------

variable "automatic_channel_upgrade" {
  description = "The automatic upgrade channel for the cluster (none, patch, rapid, stable)"
  type        = string
  default     = "stable"

  validation {
    condition     = var.automatic_channel_upgrade == null ? true : contains(["none", "patch", "rapid", "stable", "node-image"], var.automatic_channel_upgrade)
    error_message = "The automatic_channel_upgrade must be one of: none, patch, rapid, stable, or node-image."
  }
}

variable "node_os_channel_upgrade" {
  description = "The upgrade channel for the node OS (None, Unmanaged, SecurityPatch, NodeImage)"
  type        = string
  default     = "NodeImage"
}

# AKS Private Cluster Configuration
# ----------------------------------------------------------------------------

variable "private_cluster_enabled" {
  description = "Enable private cluster"
  type        = bool
  default     = true
}

variable "private_cluster_public_fqdn_enabled" {
  description = "Enable public FQDN for private cluster"
  type        = bool
  default     = false
}

# AKS Service Mesh Configuration
# ----------------------------------------------------------------------------

variable "service_mesh_profile" {
  description = "Service mesh profile configuration"
  type = object({
    mode                             = string
    internal_ingress_gateway_enabled = bool
    external_ingress_gateway_enabled = bool
  })
  default = null
}

# AKS Workload Autoscaler Configuration
# ----------------------------------------------------------------------------

variable "workload_autoscaler_profile" {
  description = "Workload autoscaler profile configuration"
  type = object({
    keda_enabled = bool
  })
  default = null
}

# AKS Azure Policy Configuration
# ----------------------------------------------------------------------------

variable "azure_policy_enabled" {
  description = "Enable Azure Policy for Kubernetes on the AKS cluster"
  type        = bool
  default     = true
}

# AKS RBAC Configuration
# ----------------------------------------------------------------------------

variable "role_based_access_control_enabled" {
  description = "Enable role-based access control"
  type        = bool
  default     = true
}

variable "rbac_aad_azure_rbac_enabled" {
  description = "Enable Azure RBAC for Kubernetes authorization"
  type        = bool
  default     = true
}

# AKS External DNS Configuration
# ----------------------------------------------------------------------------

# variable "enable_external_dns" {
#   description = "Enable External DNS for automatic DNS record management"
#   type        = bool
#   default     = false
# }

variable "ingress_dns_zone_name" {
  description = "Domain name for External DNS Private DNS Zone (e.g., contoso.iscar.internal). Set to null to skip DNS zone creation (useful when using existing/centralized DNS zone)."
  type        = string
  default     = null
  nullable    = true
}

variable "ingress_private_dns_zone_resource_id" {
  description = "Private DNS zone configuration object for ingress. Set to null to create a new DNS zone. Provide object with subscription_id, resource_group_name, and dns_zone_name to use existing zone."
  type = object({
    subscription_id     = string
    resource_group_name = string
    dns_zone_name       = string
  })
  default  = null
  nullable = true
}

variable "ingress_dns_zone_additional_vnet_links" {
  description = "Additional VNets to link to the ingress private DNS zone when creating a new zone. Only used when ingress_private_dns_zone_resource_id is null. The nodes VNet is automatically linked."
  type = map(object({
    vnet_id              = string
    registration_enabled = optional(bool, false)
  }))
  default = {}
}


# AKS Web App Routing (Ingress) Configuration
# ----------------------------------------------------------------------------

variable "web_app_routing" {
  description = "Web app routing (ingress) configuration. If dns_zone_ids is not provided and ingress_private_dns_zone_resource_id is null, it will automatically use the created DNS zone."
  type = object({
    dns_zone_ids             = optional(list(string), null)
    default_nginx_controller = optional(string, "AnnotationControlled")
  })
  default = null
}

# AKS Storage Configuration
# ----------------------------------------------------------------------------

variable "storage_profile_disk_driver_enabled" {
  description = "Enable disk driver"
  type        = bool
  default     = true
}

variable "storage_profile_file_driver_enabled" {
  description = "Enable file driver"
  type        = bool
  default     = true
}

variable "storage_profile_blob_driver_enabled" {
  description = "Enable blob driver in storage profile"
  type        = bool
  default     = false
}

variable "storage_profile_snapshot_controller_enabled" {
  description = "Enable snapshot controller in storage profile"
  type        = bool
  default     = true
}

# AKS Telemetry & Version Configuration
# ----------------------------------------------------------------------------

variable "enable_telemetry" {
  description = "Enable telemetry in upstream modules (if supported)."
  type        = bool
  default     = true
}

variable "kubernetes_version" {
  description = "AKS Kubernetes version (e.g., 1.30.7). Use null/empty to let Azure pick default."
  type        = string
  default     = null
}

# AKS VM Cluster Admin Configuration
# ----------------------------------------------------------------------------

variable "vm_cluster_admin_principal_ids" {
  description = "Map of VM managed identity principal IDs that need cluster admin access to AKS. Both 'Azure Kubernetes Service Cluster Admin Role' and 'Azure Kubernetes Service RBAC Cluster Admin' will be assigned."
  type = map(object({
    principal_id   = string
    principal_type = optional(string, null) # e.g. "Group", "ServicePrincipal", "User". Null = Azure auto-infers.
  }))
  default = {}
}

# AKS Maintenance Windows Configuration
# ----------------------------------------------------------------------------

variable "maintenance_window" {
  type        = any
  default     = null
  description = "The maintenance window for the Kubernetes cluster. Set to null or {} to disable."
}

variable "maintenance_window_auto_upgrade" {
  type        = any
  default     = null
  description = <<-EOT
Maintenance window for auto-upgrade. Set to null or {} to disable.

Available attributes:
 - `day_of_month` - (Optional) The day of the month for the maintenance run. Required in combination with RelativeMonthly frequency. Value between 0 and 31 (inclusive).
 - `day_of_week` - (Optional) The day of the week for the maintenance run. Options are `Monday`, `Tuesday`, `Wednesday`, `Thurday`, `Friday`, `Saturday` and `Sunday`. Required in combination with weekly frequency.
 - `duration` - (Required) The duration of the window for maintenance to run in hours.
 - `frequency` - (Required) Frequency of maintenance. Possible options are `Weekly`, `AbsoluteMonthly` and `RelativeMonthly`.
 - `interval` - (Required) The interval for maintenance runs. Depending on the frequency this interval is week or month based.
 - `start_date` - (Optional) The date on which the maintenance window begins to take effect.
 - `start_time` - (Optional) The time for maintenance to begin, based on the timezone determined by `utc_offset`. Format is `HH:mm`.
 - `utc_offset` - (Optional) Used to determine the timezone for cluster maintenance.
 - `week_index` - (Optional) The week in the month used for the maintenance run. Options are `First`, `Second`, `Third`, `Fourth`, and `Last`.

 ---
 `not_allowed` block supports the following:
 - `end` - (Required) The end of a time span, formatted as an RFC3339 string.
 - `start` - (Required) The start of a time span, formatted as an RFC3339 string.
EOT
}

variable "maintenance_window_node_os" {
  type        = any
  default     = null
  description = <<-EOT
Maintenance window for node OS updates. Set to null or {} to disable.

Available attributes:
 - `day_of_month` -
 - `day_of_week` - (Optional) The day of the week for the maintenance run. Options are `Monday`, `Tuesday`, `Wednesday`, `Thurday`, `Friday`, `Saturday` and `Sunday`. Required in combination with weekly frequency.
 - `duration` - (Required) The duration of the window for maintenance to run in hours.
 - `frequency` - (Required) Frequency of maintenance. Possible options are `Daily`, `Weekly`, `AbsoluteMonthly` and `RelativeMonthly`.
 - `interval` - (Required) The interval for maintenance runs. Depending on the frequency this interval is week or month based.
 - `start_date` - (Optional) The date on which the maintenance window begins to take effect.
 - `start_time` - (Optional) The time for maintenance to begin, based on the timezone determined by `utc_offset`. Format is `HH:mm`.
 - `utc_offset` - (Optional) Used to determine the timezone for cluster maintenance.
 - `week_index` - (Optional) The week in the month used for the maintenance run. Options are `First`, `Second`, `Third`, `Fourth`, and `Last`.

 ---
 `not_allowed` block supports the following:
 - `end` - (Required) The end of a time span, formatted as an RFC3339 string.
 - `start` - (Required) The start of a time span, formatted as an RFC3339 string.
EOT
}

# AKS ACR Integration Configuration
# ----------------------------------------------------------------------------

variable "attached_acr_id_map" {
  type = map(object({
    subscription_id     = string
    resource_group_name = string
    acr_name            = string
  }))
  default     = {}
  description = "Azure Container Registry configuration for attached ACRs. Map key is a descriptive name, value contains subscription_id, resource_group_name, and acr_name. The full resource ID will be constructed automatically."
  nullable    = false
}

# AKS Image Cleaner Configuration
# ----------------------------------------------------------------------------

variable "image_cleaner_enabled" {
  type        = bool
  default     = true
  description = "(Optional) Specifies whether Image Cleaner is enabled."
}

variable "image_cleaner_interval_hours" {
  type        = number
  default     = 48
  description = "(Optional) Specifies the interval in hours when images should be cleaned up. Defaults to `48`."
}

variable "microsoft_defender_enabled" {
  type        = bool
  default     = true
  description = "(Optional) Is Microsoft Defender on the cluster enabled? Requires `var.log_analytics_workspace_enabled` to be `true` to set this variable to `true`."
  nullable    = false
}

# ============================================================================
# AKS GitOps & Policy
# ============================================================================

variable "fluxcd_enabled" {
  description = "Enable Flux v2 (GitOps) extension on the AKS cluster (extension only, configuration managed separately in addons)"
  type        = bool
  default     = false
}

# Azure Backup for AKS
# Note: Resource names are automatically generated using naming conventions in locals.tf

variable "enable_aks_backup" {
  description = "Enable Azure Backup for AKS cluster"
  type        = bool
  default     = false
}

# Storage Configuration

variable "backup_storage_account_tier" {
  description = "Storage account tier (Standard or Premium)"
  type        = string
  default     = "Standard"

  validation {
    condition     = contains(["Standard", "Premium"], var.backup_storage_account_tier)
    error_message = "Storage account tier must be either 'Standard' or 'Premium'."
  }
}

variable "backup_storage_replication_type" {
  description = "Storage account replication type (LRS, GRS, RAGRS, ZRS, GZRS, RAGZRS)"
  type        = string
  default     = "LRS"

  validation {
    condition     = contains(["LRS", "GRS", "RAGRS", "ZRS", "GZRS", "RAGZRS"], var.backup_storage_replication_type)
    error_message = "Storage replication type must be one of: LRS, GRS, RAGRS, ZRS, GZRS, RAGZRS."
  }
}

# Backup Vault Configuration
variable "backup_vault_datastore_type" {
  description = "Datastore type for the backup vault"
  type        = string
  default     = "VaultStore"

  validation {
    condition     = contains(["VaultStore", "OperationalStore"], var.backup_vault_datastore_type)
    error_message = "Datastore type must be either 'VaultStore' or 'OperationalStore'."
  }
}

variable "backup_vault_redundancy" {
  description = "Redundancy setting for the backup vault (LocallyRedundant or GeoRedundant)"
  type        = string
  default     = "LocallyRedundant"

  validation {
    condition     = contains(["LocallyRedundant", "GeoRedundant"], var.backup_vault_redundancy)
    error_message = "Vault redundancy must be either 'LocallyRedundant' or 'GeoRedundant'."
  }
}

# Backup Policy Configuration
variable "backup_frequency" {
  description = "Backup frequency in ISO 8601 duration format (e.g., R/2024-01-01T00:00:00+00:00/P1D for daily)"
  type        = string
  default     = "R/2024-01-01T00:00:00+00:00/P1D" # Daily backups

  validation {
    condition     = can(regex("^R/", var.backup_frequency))
    error_message = "Backup frequency must be in ISO 8601 repeating interval format (e.g., R/2024-01-01T00:00:00+00:00/P1D)."
  }
}

variable "backup_retention_days" {
  description = "Number of days to retain backups in OperationalStore"
  type        = number
  default     = 7

  validation {
    condition     = var.backup_retention_days >= 1 && var.backup_retention_days <= 360
    error_message = "Backup retention days must be between 1 and 360."
  }
}

variable "backup_retention_criteria" {
  description = "Retention criteria for backups (FirstOfDay, FirstOfWeek, FirstOfMonth, FirstOfYear)"
  type        = string
  default     = "FirstOfDay"

  validation {
    condition     = contains(["FirstOfDay", "FirstOfWeek", "FirstOfMonth", "FirstOfYear"], var.backup_retention_criteria)
    error_message = "Backup retention criteria must be one of: FirstOfDay, FirstOfWeek, FirstOfMonth, FirstOfYear."
  }
}

# Backup Instance Configuration
variable "backup_excluded_namespaces" {
  description = "List of Kubernetes namespaces to exclude from backup"
  type        = list(string)
  default     = []
}

variable "backup_included_namespaces" {
  description = "List of Kubernetes namespaces to include in backup (use ['*'] for all)"
  type        = list(string)
  default     = ["*"]
}

variable "backup_excluded_resource_types" {
  description = "List of Kubernetes resource types to exclude from backup"
  type        = list(string)
  default     = []
}

variable "backup_included_resource_types" {
  description = "List of Kubernetes resource types to include in backup (empty means all)"
  type        = list(string)
  default     = []
}

variable "backup_label_selectors" {
  description = "List of label selectors to filter resources for backup"
  type        = list(string)
  default     = []
}

variable "backup_cluster_scoped_resources_enabled" {
  description = "Enable backup of cluster-scoped resources (e.g., ClusterRoles, StorageClasses)"
  type        = bool
  default     = true
}

variable "backup_volume_snapshot_enabled" {
  description = "Enable volume snapshots for persistent volumes"
  type        = bool
  default     = true
}

# RBAC Role Definitions
variable "backup_vault_aks_role" {
  description = "Azure role to assign to backup vault for AKS cluster access"
  type        = string
  default     = "Contributor"
}

variable "backup_vault_storage_role" {
  description = "Azure role to assign to backup vault for storage account access"
  type        = string
  default     = "Storage Blob Data Contributor"
}

# Azure Key Vault Configuration

variable "create_keyvault" {
  description = "Enable creation of Key Vaults"
  type        = bool
  default     = false
}

variable "keyvault_sku_name" {
  description = "SKU name for Key Vault (standard or premium)"
  type        = string
  default     = "standard"
}

variable "keyvault_network_acls" {
  description = "Network ACLs for Key Vault"
  type = object({
    default_action             = optional(string, "Deny")
    bypass                     = optional(string, "AzureServices")
    ip_rules                   = optional(list(string), [])
    virtual_network_subnet_ids = optional(list(string), [])
  })
  default = {
    default_action             = "Deny"
    bypass                     = "AzureServices"
    ip_rules                   = []
    virtual_network_subnet_ids = []
  }
}

variable "soft_delete_retention_days" {
  description = "Number of days to retain soft deleted Key Vault"
  type        = number
  default     = 7
}

variable "purge_protection_enabled" {
  description = "Enable purge protection for Key Vault"
  type        = bool
  default     = false
}

variable "keyvault_rbac" {
  description = "RBAC role assignments for Key Vault (passed to AVM module)"
  type = map(object({
    principal_id               = string
    role_definition_id_or_name = string
  }))
  default = {}
}

variable "keyvault_roles" {
  description = "Additional role assignments for Key Vault (managed via azurerm_role_assignment)"
  type = list(object({
    principal_id = string
    role         = string
  }))
  default = []
}

# Private Endpoint Configuration
variable "enable_keyvault_private_endpoint" {
  description = "Enable private endpoint for Key Vault (blocks public internet access)"
  type        = bool
  default     = true
}

variable "keyvault_network_resource_group_name_for_pe" {
  description = "Network resource group name for Key Vault private endpoint"
  type        = string
  default     = ""
}

variable "keyvault_vnet_name_for_pe" {
  description = "VNet name for Key Vault private endpoint"
  type        = string
  default     = ""
}

variable "keyvault_subnet_name_for_pe" {
  description = "Subnet name for Key Vault private endpoint"
  type        = string
  default     = ""
}

# Private DNS Zone Configuration
variable "keyvault_private_dns_zone_kv_resource_id" {
  description = "Private DNS zone configuration object for Key Vault. Set to null to create a new DNS zone. Provide object with subscriptions and resourceGroups to use existing zone."
  type = object({
    subscriptions  = string
    resourceGroups = string
  })
  default = null
}

variable "keyvault_private_dns_zone_name" {
  description = "Private DNS zone name for Key Vault private endpoint"
  type        = string
  default     = "privatelink.vaultcore.azure.net"
}

variable "keyvault_additional_vnet_links" {
  description = "Additional VNet links for Key Vault private DNS zone (e.g., link to shared VNet)"
  type = map(object({
    vnet_id              = string
    registration_enabled = bool
  }))
  default = {}
}

variable "keyvault_private_dns_zone_group_name" {
  description = "Name for Key Vault private DNS zone group"
  type        = string
  default     = "default"
}

variable "keyvault_private_endpoint_subresource_name" {
  description = "Subresource name for Key Vault private endpoint"
  type        = string
  default     = "vault"
}

# ============================================================================
# Monitoring Variables 
# ============================================================================

# ============================================================================
# AKS Monitoring Configuration
# ----------------------------------------------------------------------------

variable "log_analytics_workspace_id" {
  description = "Existing Log Analytics Workspace configuration. If null, a new workspace will be created per environment. Split into components for better readability."
  type = object({
    subscription_id     = string
    resource_group_name = string
    workspace_name      = string
  })
  default = null
}

variable "enable_application_insights" {
  description = "Enable Application Insights for AKS monitoring"
  type        = bool
  default     = false
}

variable "log_analytics_workspace_enabled" {
  description = "Enable Log Analytics workspace for AKS monitoring"
  type        = bool
  default     = true
}

variable "enable_container_insights" {
  description = "Enable Container Insights for AKS monitoring"
  type        = bool
  default     = true
}

variable "monitor_metrics_enabled" {
  description = <<-EOT
    Enable Prometheus metrics collection and Azure Monitor managed service for Prometheus.
    When enabled, AKS will scrape Prometheus metrics from the cluster and send them to Azure Monitor.
    This integrates with Azure Managed Grafana for visualization and alerting.
    Requires Azure Monitor Workspace to be available (created in shared infrastructure).
  EOT
  type        = bool
  default     = true
}

variable "log_analytics_sku" {
  description = "SKU for Log Analytics workspace"
  type        = string
  default     = "PerGB2018"
}

variable "log_analytics_retention_days" {
  description = "Retention period in days for Log Analytics workspace"
  type        = number
  default     = 30
}




# ============================================================================
# AKS Monitoring & Management
# ============================================================================



variable "application_insights_type" {
  description = "Application type for Application Insights"
  type        = string
  default     = "other"

  validation {
    condition     = contains(["web", "other", "java", "MobileCenter", "Node.JS", "phone", "store"], var.application_insights_type)
    error_message = "Application type must be one of: web, other, java, MobileCenter, Node.JS, phone, store."
  }
}

variable "cost_analysis_enabled" {
  description = "Enable cost analysis for AKS cluster. When enabled, collects and analyzes cost and usage data."
  type        = bool
  default     = true
}

# =============================================================================
# External Service Bus role assignments (cross-state)
# Grant "Azure Service Bus Data Sender" to this cluster's node (kubelet) identity
# on Service Bus namespaces that live in a different Terraform state.
# Pass the full resource IDs e.g.:
#   /subscriptions/<sub>/resourceGroups/<rg>/providers/Microsoft.ServiceBus/namespaces/<name>
# =============================================================================

variable "external_servicebus_scope_ids" {
  description = "List of external Service Bus namespace resource IDs on which the AKS node (kubelet) identity should receive 'Azure Service Bus Data Sender'. Use for cross-state role assignments."
  type        = list(string)
  default     = []
}

variable "external_storage_scope_ids" {
  description = "List of external Storage Account resource IDs on which the AKS node (kubelet) identity should receive 'Storage Blob Data Contributor'. Use for cross-state role assignments."
  type        = list(string)
  default     = []
}

# =============================================================================
# Service Bus (internal-only, private endpoint, AKS managed identity)
# =============================================================================

variable "servicebus" {
  description = "Optional Service Bus namespace: internal network only, private endpoint, AKS pods connect via managed identity. Set to null to skip. Uses Premium SKU (required for private endpoint)."
  type = object({
    resource_group_key            = string
    name                          = optional(string) # default: ${local.name}-sb
    sku                           = optional(string, "Premium")
    capacity                      = optional(number, 1)
    public_network_access_enabled = optional(bool, false)
    local_auth_enabled            = optional(bool, false) # Entra ID only when false
    minimum_tls_version           = optional(string, "1.2")

    # Private endpoint (required for internal-only)
    private_endpoint = object({
      resource_group_name = string
      vnet_name           = string
      subnet_name         = string
    })
    private_dns_zone = object({
      subscriptions         = string # subscription ID where the DNS zone lives
      resourceGroups        = string # resource group name where the DNS zone lives
      private_dns_zone_name = string # e.g. privatelink.servicebus.windows.net
    })

    # Network rules (Premium): deny by default; optional allow list
    network_rule_subnet_ids               = optional(list(string), [])
    network_rule_cidr_or_ip_rules         = optional(list(string), [])
    network_rule_trusted_services_allowed = optional(bool, false)

    queues = optional(map(any), {})
    topics = optional(map(any), {})

    # RBAC: explicit + AKS workload identities via grant_servicebus_to_workload_identity_keys
    role_assignments = optional(map(object({
      principal_id                     = string
      role_definition_name             = string # e.g. "Azure Service Bus Data Owner"
      description                      = optional(string)
      principal_type                   = optional(string, null) # e.g. "Group", "ServicePrincipal", "User". Null = Azure auto-infers.
      skip_service_principal_aad_check = optional(bool, true)
    })), {})
    grant_servicebus_to_workload_identity_keys = optional(list(string), [])

    tags = optional(map(string), {})
  })
  default = null
}

# =============================================================================
# Azure Managed Redis (production-grade, internal-only, private endpoint)
# =============================================================================
# Matches current azurerm_managed_redis schema (cluster + default_database).
variable "managed_redis" {
  description = "Optional Azure Managed Redis (Enterprise): internal-only, private endpoint. AKS pods connect via workload identity (grant_redis_to_workload_identity_keys). Set to null to skip."
  type = object({
    resource_group_key = string
    name               = optional(string)
    sku_name           = string # e.g. Enterprise_E10, Enterprise_E20
    location           = optional(string)

    public_network_access_enabled = optional(bool, false)
    high_availability_enabled     = optional(bool, true)

    identity = optional(object({
      type         = string
      identity_ids = optional(list(string), null)
    }), { type = "SystemAssigned", identity_ids = null })

    customer_managed_key = optional(object({
      key_vault_key_id          = string
      user_assigned_identity_id = string
    }), null)

    default_database = optional(object({
      access_keys_authentication_enabled            = optional(bool, true)
      client_protocol                               = optional(string, "Encrypted")
      clustering_policy                             = optional(string, "OSSCluster")
      eviction_policy                               = optional(string, "VolatileLRU")
      geo_replication_group_name                    = optional(string, null)
      persistence_append_only_file_backup_frequency = optional(string, null)
      persistence_redis_database_backup_frequency   = optional(string, null)
      module = optional(list(object({
        name = string
        args = optional(string, null)
      })), [])
    }), null)

    private_endpoint = object({
      resource_group_name = string
      vnet_name           = string
      subnet_name         = string
    })
    # When true, create the private DNS zone; when false, construct resource ID from subscriptions/resourceGroups.
    create_private_dns_zone = optional(bool, false)
    private_dns_zone = object({
      subscriptions         = string
      resourceGroups        = string
      private_dns_zone_name = string # Azure Managed Redis: use privatelink.redis.azure.net
    })

    grant_redis_to_workload_identity_keys = optional(list(string), [])

    role_assignments = optional(map(object({
      principal_id         = string
      role_definition_name = string
      principal_type       = optional(string, null) # e.g. "Group", "ServicePrincipal", "User". Null = Azure auto-infers.
    })), {})

    tags = optional(map(string), {})
  })
  default = null
}

variable "static_web_apps" {
  type = map(object({
    prefix             = string
    sku_tier           = optional(string, "Standard")
    resource_group_key = string

    private_endpoint = optional(object({
      resource_group_name = string
      vnet_name           = string
      subnet_name         = string
    }))
    private_dns_zone = optional(object({
      resource_group_name   = string
      private_dns_zone_name = string
    }))

    tags = optional(map(string), {})
    custom_domains = optional(map(object({
      domain_name          = string
      validation_type      = optional(string, "cname-delegation")
      create_cname_records = optional(bool, false)
      cname_name           = optional(string)
      cname_zone_name      = optional(string)
      cname_record         = optional(string)
      create_txt_records   = optional(bool, false)
      txt_name             = optional(string)
      txt_zone_name        = optional(string)
    })), {})
    role_assignments = optional(map(object({
      role_definition_id_or_name             = string
      principal_id                           = string
      description                            = optional(string, null)
      skip_service_principal_aad_check       = optional(bool, false)
      condition                              = optional(string, null)
      condition_version                      = optional(string, null)
      delegated_managed_identity_resource_id = optional(string, null)
      principal_type                         = optional(string, null)
    })), {})
  }))
  description = "Map of Static Web Apps to create"
  default     = {}
}

######################################################################################
# Azure Function Apps
######################################################################################

variable "function_app_private_dns_zone" {
  description = "Shared private DNS zone reference used by all Function Apps (privatelink.azurewebsites.net). All function apps in this deployment share a single DNS zone."
  type = object({
    subscriptions         = string
    resourceGroups        = string
    private_dns_zone_name = string
  })
  default = null
}

variable "function_apps" {
  description = "Map of Azure Function Apps to create. Each entry provisions a storage account (via the storage-account module), an App Service Plan, and a Function App (via the AVM web-site module)."
  type = map(object({
    resource_group_key = string
    resource           = string # naming token (e.g. "func")

    # App Service Plan
    sku_name               = optional(string, "P1v2")
    zone_balancing_enabled = optional(bool, false)
    os_type                = optional(string, "Windows")

    # Function App Runtime
    dotnet_version              = optional(string, "v8.0")
    use_dotnet_isolated_runtime = optional(bool, true)
    functions_extension_version = optional(string, "~4")
    app_settings                = optional(map(string), {})

    # Storage Account (created via storage-account module)
    storage_account = object({
      account_tier                  = optional(string, "Standard")
      account_replication_type      = optional(string, "LRS")
      public_network_access_enabled = optional(bool, false)
      role_assignments = optional(map(object({
        principal_id                     = string
        role_definition_name             = string
        description                      = optional(string, null)
        principal_type                   = optional(string, null)
        skip_service_principal_aad_check = optional(bool, true)
      })), {})
    })

    # Networking
    public_network_access_enabled = optional(bool, false)

    vnet_integration_subnet = optional(object({
      resource_group_name = string
      vnet_name           = string
      subnet_name         = string
    }), null)

    private_endpoint = optional(object({
      resource_group_name = string
      vnet_name           = string
      subnet_name         = string
    }), null)

    # Identity
    managed_identities = optional(object({
      system_assigned            = optional(bool, false)
      user_assigned_resource_ids = optional(set(string), [])
    }), {})

    # RBAC
    role_assignments = optional(map(object({
      role_definition_id_or_name             = string
      principal_id                           = string
      description                            = optional(string, null)
      skip_service_principal_aad_check       = optional(bool, false)
      condition                              = optional(string, null)
      condition_version                      = optional(string, null)
      delegated_managed_identity_resource_id = optional(string, null)
      principal_type                         = optional(string, null)
    })), {})

    tags = optional(map(string), {})
  }))
  default = {}
}

######################################################################################
# Storage Accounts
######################################################################################
variable "storage_accounts" {
  description = "Map of Storage Accounts to create."
  type = map(object({
    resource_group_key            = string
    resource                      = optional(string, "st")
    name_override                 = optional(string, null)
    name                          = optional(string, null)
    account_tier                  = optional(string, "Standard")
    account_replication_type      = optional(string, "LRS")
    account_kind                  = optional(string, "StorageV2")
    public_network_access_enabled = optional(bool, false)
    shared_access_key_enabled     = optional(bool, true)

    enable_network_rules         = optional(bool, true)
    network_rules_bypass         = optional(list(string), ["AzureServices"])
    network_rules_default_action = optional(string, "Deny")
    allowed_ip_addresses         = optional(list(string), [])
    allowed_subnet_ids           = optional(list(string), [])

    containers = optional(map(object({
      name          = string
      public_access = optional(string, "None")
    })), {})

    private_endpoint = optional(object({
      resource_group_name = string
      vnet_name           = string
      subnet_name         = string
    }), null)

    private_dns_zone = optional(object({
      subscriptions         = string
      resourceGroups        = string
      private_dns_zone_name = string
    }), null)

    # Lifecycle: delete blobs after N days. Azure minimum is 1 day.
    blob_delete_after_days = optional(number, null)

    role_assignments = optional(map(object({
      principal_id                     = string
      role_definition_name             = string
      principal_type                   = optional(string, null)
      skip_service_principal_aad_check = optional(bool, true)
    })), {})

    tags = optional(map(string), {})
  }))
  default = {}
}
