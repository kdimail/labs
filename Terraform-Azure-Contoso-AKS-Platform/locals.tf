######################################################################################
# Central Configuration
######################################################################################

locals {
  name = "${var.region}-LZ-${var.team}-${var.env}"

  # Special naming for storage accounts and key vaults (lowercase, no dashes, max 24 chars)
  name_storage = lower(replace("${var.region_short}lz${var.team_short}${var.env_short}st", "-", ""))
  # name_keyvault = replace("${var.region}lz${var.team_short}${var.env_short}kv", "-", "")
  name_keyvault    = replace("${var.region_short}${var.env_short}${var.team_short}kv", "-", "")
  name_acr         = replace("${var.region_short}LZ${var.team_short}${var.env_short}", "-", "")
  name_backupvault = replace("${var.region_short}LZ${var.team_short}${var.env_short}bk", "-", "")

  common_tags = {
    Terraform   = "true"
    CreatedBy   = "Terraform"
    Environment = var.env
    Team        = var.team
    Region      = var.region
    Company     = var.company_location
  }

  # Resource naming convention following the standard pattern
  resource_group_name          = "${local.name}-rg"
  aks_cluster_name             = "${local.name}-aks"
  aks_identity_name            = "${local.name}-aks-identity"
  aks_node_resource_group_name = "MC_${local.name}-aks-nodes" # Must be under 80 chars

  # Backup resource names
  backup_storage_account_name = lower(replace("${var.region_short}${var.team_short}${var.env_short}bk", "-", ""))
  backup_container_name       = lower("${var.region_short}LZ${var.team_short}${var.env_short}-aks-backups")
  backup_extension_name       = lower("${var.region_short}LZ${var.team_short}${var.env_short}-aks-backup-ext")
  backup_policy_name          = lower("${var.region_short}LZ${var.team_short}${var.env_short}-backup-policy")
  backup_instance_name        = lower("${var.region_short}LZ${var.team_short}${var.env_short}-backup-instance")

  # Azure resource IDs constructed from tfvars objects
  aks_private_dns_zone_resource_id      = var.aks_private_dns_zone_id != null ? "/subscriptions/${var.aks_private_dns_zone_id.subscription_id}/resourceGroups/${var.aks_private_dns_zone_id.resource_group_name}/providers/Microsoft.Network/privateDnsZones/${var.aks_private_dns_zone_id.private_dns_zone_name}" : null
  acr_private_dns_zone_resource_id      = var.acr_private_dns_zone_resource_id != null ? "/subscriptions/${var.acr_private_dns_zone_resource_id.subscriptions}/resourceGroups/${var.acr_private_dns_zone_resource_id.resourceGroups}/providers/Microsoft.Network/privateDnsZones/${var.acr_private_dns_zone_name}" : null
  keyvault_private_dns_zone_resource_id = var.keyvault_private_dns_zone_kv_resource_id != null ? "/subscriptions/${var.keyvault_private_dns_zone_kv_resource_id.subscriptions}/resourceGroups/${var.keyvault_private_dns_zone_kv_resource_id.resourceGroups}/providers/Microsoft.Network/privateDnsZones/${var.keyvault_private_dns_zone_name}" : null
  base_name                             = "${var.env}-${var.region}"
  log_analytics_workspace_resource_id   = var.log_analytics_workspace_id != null ? "/subscriptions/${var.log_analytics_workspace_id.subscription_id}/resourceGroups/${var.log_analytics_workspace_id.resource_group_name}/providers/Microsoft.OperationalInsights/workspaces/${var.log_analytics_workspace_id.workspace_name}" : null

  # PostgreSQL - per-server computed values
  # postgres_server_name = {
  #   for k, v in var.postgres_servers : k => "${local.name}-${v.resource}"
  # }
  postgres_server_name = {
    for k, v in var.postgres_servers : k => coalesce(v.name, "${local.name}-${v.resource}")
  }

  postgres_private_dns_zone_resource_id = {
    for k, v in var.postgres_servers : k =>
    "/subscriptions/${v.private_dns_zone.subscriptions}/resourceGroups/${v.private_dns_zone.resourceGroups}/providers/Microsoft.Network/privateDnsZones/${v.private_dns_zone.private_dns_zone_name}"
  }

  postgres_log_analytics_workspace_id = {
    for k, v in var.postgres_servers : k =>
    v.log_analytics_workspace_id != null ? "/subscriptions/${v.log_analytics_workspace_id.subscriptions}/resourceGroups/${v.log_analytics_workspace_id.resourceGroups}/providers/Microsoft.OperationalInsights/workspaces/${v.log_analytics_workspace_id.workspace_name}" : null
  }

  # Merge static azure_ad_administrators with AKS workload identities granted postgres access
  postgres_azure_ad_administrators = {
    for k, v in var.postgres_servers : k => merge(
      v.azure_ad_administrators,
      {
        for wi_key in v.grant_postgres_to_workload_identity_keys :
        wi_key => {
          principal_id   = module.aks[keys(module.aks)[0]].workload_identity_principal_ids[wi_key]
          principal_name = wi_key
        }
      }
    )
  }

  # ServiceBus computed values
  servicebus_name = var.servicebus != null ? "${local.name}-${var.servicebus.name}" : null

  servicebus_private_dns_zone_resource_id = var.servicebus != null ? "/subscriptions/${var.servicebus.private_dns_zone.subscriptions}/resourceGroups/${var.servicebus.private_dns_zone.resourceGroups}/providers/Microsoft.Network/privateDnsZones/${var.servicebus.private_dns_zone.private_dns_zone_name}" : null

  servicebus_role_assignments = var.servicebus != null ? merge(
    var.servicebus.role_assignments,
    {
      for wi_key in var.servicebus.grant_servicebus_to_workload_identity_keys :
      wi_key => {
        principal_id         = module.aks[keys(module.aks)[0]].workload_identity_principal_ids[wi_key]
        role_definition_name = "Azure Service Bus Data Owner"
      }
    }
  ) : {}

  managed_redis_name                         = var.managed_redis != null ? coalesce("${local.name}-${var.managed_redis.name}", "${local.name}-redis") : null
  managed_redis_private_dns_zone_resource_id = var.managed_redis != null ? "/subscriptions/${var.managed_redis.private_dns_zone.subscriptions}/resourceGroups/${var.managed_redis.private_dns_zone.resourceGroups}/providers/Microsoft.Network/privateDnsZones/${var.managed_redis.private_dns_zone.private_dns_zone_name}" : null

  # Storage Account computed values
  storage_blob_private_dns_zone_resource_id = {
    for k, v in var.storage_accounts : k =>
    v.private_dns_zone != null ? "/subscriptions/${v.private_dns_zone.subscriptions}/resourceGroups/${v.private_dns_zone.resourceGroups}/providers/Microsoft.Network/privateDnsZones/${v.private_dns_zone.private_dns_zone_name}" : null
  }

  # Function App computed values
  function_app_private_dns_zone_resource_id = var.function_app_private_dns_zone != null ? "/subscriptions/${var.function_app_private_dns_zone.subscriptions}/resourceGroups/${var.function_app_private_dns_zone.resourceGroups}/providers/Microsoft.Network/privateDnsZones/${var.function_app_private_dns_zone.private_dns_zone_name}" : null
}

