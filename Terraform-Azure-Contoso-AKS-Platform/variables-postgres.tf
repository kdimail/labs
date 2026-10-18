
# ============================================================================
# PostgreSQL Flexible Server
# ============================================================================

variable "pg_password" {
  description = "Administrator password for PostgreSQL Flexible Server(s). Set via TF_VAR_pg_password or in a secure manner (e.g. Key Vault reference)."
  type        = string
  default     = null
  sensitive   = true
}

variable "postgres_servers" {
  description = "Map of PostgreSQL Flexible Servers to create. Key is a logical name (e.g. main)."
  type = map(object({
    resource_group_key = string
    resource           = string # e.g. "pg" for naming
    name              = optional(string) # override computed name if set

    # Networking - reference existing delegated subnet and private DNS zone
    delegated_subnet = object({
      resource_group_name = string
      vnet_name           = string
      subnet_name         = string
    })
    private_dns_zone = object({
      subscriptions         = string # subscription ID where the DNS zone lives
      resourceGroups        = string # resource group name where the DNS zone lives
      private_dns_zone_name = string # e.g. privatelink.postgres.database.azure.com
    })
    public_network_access_enabled = optional(bool, false)

    # Server configuration
    sku_name          = optional(string, "GP_Standard_D2s_v3")
    postgres_version  = optional(string, "16")
    storage_mb        = optional(number, 32768)
    storage_tier      = optional(string, "P10")
    auto_grow_enabled = optional(bool, true)
    availability_zone = optional(string)

    # Backup
    backup_retention_days        = optional(number, 7)
    geo_redundant_backup_enabled = optional(bool, false)

    # High availability
    high_availability = optional(object({
      mode                      = string # ZoneRedundant or SameZone
      standby_availability_zone = optional(string)
    }))

    # Maintenance
    maintenance_window = optional(object({
      day_of_week  = optional(number, 0)
      start_hour   = optional(number, 0)
      start_minute = optional(number, 0)
    }))

    # Diagnostics - reference existing Log Analytics workspace
    log_analytics_workspace_id = optional(object({
      subscriptions  = string # subscription ID where the workspace lives
      resourceGroups = string # resource group name where the workspace lives
      workspace_name = string
    }))
    server_log_retention_days   = optional(number) # 1-7 when set
    diagnostic_log_categories   = optional(list(string), ["PostgreSQLLogs"])
    diagnostic_metrics_enabled  = optional(bool, true)

    # Authentication (administrator_login; password from here or var.pg_password)
    pg_password         = optional(string) # per-server; falls back to var.pg_password
    administrator_login = optional(string, "pgadmin")
    authentication = optional(object({
      active_directory_auth_enabled = optional(bool, false)
      password_auth_enabled         = optional(bool, true)
      tenant_id                     = optional(string)
    }))

    # Azure AD administrators (e.g. AKS workload identity) for managed identity login
    azure_ad_administrators = optional(map(object({
      principal_id   = string
      principal_name = string
    })), {})
    # Grant PostgreSQL Azure AD login to these AKS workload identity keys (resolved from module.aks)
    grant_postgres_to_workload_identity_keys = optional(list(string), [])

    # Optional: databases, configurations, firewall_rules, role_assignments
    databases       = optional(map(object({
      charset   = optional(string, "UTF8")
      collation = optional(string, "en_US.utf8")
    })), {})
    configurations  = optional(map(string), {})
    firewall_rules  = optional(map(object({
      start_ip_address = string
      end_ip_address   = string
    })), {})
    role_assignments = optional(map(object({
      principal_id         = string
      role_definition_name = string
    })), {})

    tags = optional(map(string), {})
  }))
  default = {}
}