######################################################################################
# Resource Groups
######################################################################################

module "resource_groups" {
  source = "./terraform-azure-lz-modules/resource-group"

  for_each = var.resource_groups

  name             = "${local.name}-${each.value.resource}-${each.value.role}"
  location         = var.location
  enable_telemetry = coalesce(try(each.value.enable_telemetry, null), var.enable_telemetry)
  lock             = try(each.value.lock, null)
  role_assignments = try(each.value.role_assignments, {})

  tags = merge(local.common_tags, try(each.value.tags, {}))
}

######################################################################################
# Azure Container Registry
######################################################################################

module "acr" {
  source = "./terraform-azure-lz-modules/acr"

  for_each = var.acr_registries

  name                = local.name_acr
  location            = var.location
  resource_group_name = module.resource_groups[each.value.resource_group_key].resource_group_name

  acr_sku                       = each.value.acr_sku
  admin_enabled                 = each.value.admin_enabled
  public_network_access_enabled = each.value.public_network_access_enabled

  zone_redundancy_enabled           = each.value.zone_redundancy_enabled
  enable_geo_replication            = each.value.enable_geo_replication
  geo_replication_locations         = each.value.geo_replication_locations
  geo_replication_private_endpoints = each.value.geo_replication_private_endpoints

  enable_private_endpoint                = each.value.enable_private_endpoint
  acr_network_resource_group_name_for_pe = each.value.acr_network_resource_group_name_for_pe
  acr_vnet_name_for_pe                   = each.value.acr_vnet_name_for_pe
  acr_subnet_name_for_pe                 = each.value.acr_subnet_name_for_pe

  private_dns_zone_resource_id = try(
    "/subscriptions/${each.value.acr_private_dns_zone_resource_id.subscriptions}/resourceGroups/${each.value.acr_private_dns_zone_resource_id.resourceGroups}/providers/Microsoft.Network/privateDnsZones/${each.value.acr_private_dns_zone_name}",
    null
  )
  acr_private_dns_zone_name = each.value.acr_private_dns_zone_name
  additional_vnet_links     = each.value.acr_additional_vnet_links

  subscription_id      = var.subscription_id
  acr_role_assignments = each.value.acr_role_assignments
  allowed_ip_addresses = try(each.value.acr_allowed_ip_addresses, [])

  tags       = merge(local.common_tags, try(each.value.tags, {}))
  depends_on = [module.resource_groups]
}

######################################################################################
# Azure Key Vault
######################################################################################

module "keyvault" {
  source = "./terraform-azure-lz-modules/keyvaultv2"

  for_each = var.key_vaults

  keyvault_sku_name                           = each.value.keyvault_sku_name
  keyvault_network_acls                       = each.value.keyvault_network_acls
  soft_delete_retention_days                  = each.value.soft_delete_retention_days
  purge_protection_enabled                    = each.value.purge_protection_enabled
  keyvault_rbac                               = each.value.keyvault_rbac
  keyvault_roles                              = []
  enable_keyvault_private_endpoint            = true
  keyvault_network_resource_group_name_for_pe = each.value.keyvault_network_resource_group_name_for_pe
  keyvault_vnet_name_for_pe                   = each.value.keyvault_vnet_name_for_pe
  keyvault_subnet_name_for_pe                 = each.value.keyvault_subnet_name_for_pe
  private_dns_zone_kv_resource_id = try(
    "/subscriptions/${each.value.keyvault_private_dns_zone_kv_resource_id.subscriptions}/resourceGroups/${each.value.keyvault_private_dns_zone_kv_resource_id.resourceGroups}/providers/Microsoft.Network/privateDnsZones/${each.value.keyvault_private_dns_zone_name}",
    null
  )
  keyvault_private_dns_zone_name             = each.value.keyvault_private_dns_zone_name
  keyvault_private_dns_zone_group_name       = "default"
  keyvault_additional_vnet_links             = each.value.keyvault_additional_vnet_links
  keyvault_private_endpoint_subresource_name = "vault"
  resource_group_name                        = module.resource_groups[each.value.resource_group_key].resource_group_name
  location                                   = var.location
  region                                     = var.region_short
  env                                        = var.env_short
  team                                       = var.team_short
  tags                                       = merge(local.common_tags, try(each.value.tags, {}))
  random_suffix                              = ""

  depends_on = [module.resource_groups]
}

######################################################################################
# Azure Kubernetes Service (AKS)
######################################################################################
module "aks" {
  source = "./terraform-azure-lz-modules/aks"

  for_each = var.aks_clusters

  aks_cluster_name             = local.aks_cluster_name
  aks_node_resource_group_name = local.aks_node_resource_group_name
  resource_group_name          = module.resource_groups[each.value.resource_group_key].resource_group_name
  azure_location               = var.location
  sku_tier                     = each.value.sku_tier
  enable_telemetry             = each.value.enable_telemetry
  kubernetes_version           = each.value.kubernetes_version
  aks_identity_name            = local.aks_identity_name
  region                       = var.region
  env                          = var.env
  automatic_channel_upgrade    = each.value.automatic_channel_upgrade
  node_os_channel_upgrade      = each.value.node_os_channel_upgrade
  upgrade_override             = each.value.upgrade_override

  oidc_issuer_enabled               = each.value.oidc_issuer_enabled
  workload_identity_enabled         = each.value.workload_identity_enabled
  workload_identities               = each.value.workload_identities
  keyvault_id                       = try(module.keyvault["main"].keyvault_id, null)
  role_based_access_control_enabled = each.value.role_based_access_control_enabled
  rbac_aad_azure_rbac_enabled       = each.value.rbac_aad_azure_rbac_enabled
  vm_cluster_admin_principal_ids    = each.value.vm_cluster_admin_principal_ids

  default_node_pool = each.value.default_node_pool
  node_pools        = each.value.node_pools

  nodes_network_resource_group_name = each.value.nodes_network_resource_group_name
  nodes_vnet_name                   = each.value.nodes_vnet_name
  nodes_subnet_name                 = each.value.nodes_subnet_name
  network_profile = {
    network_plugin      = each.value.network_plugin
    network_plugin_mode = each.value.network_plugin_mode
    network_data_plane  = each.value.network_dataplane
    network_policy      = each.value.network_dataplane == "cilium" ? null : each.value.network_policy
    pod_cidr            = each.value.net_profile_pod_cidr
    service_cidr        = each.value.net_profile_service_cidr
    dns_service_ip      = each.value.net_profile_dns_service_ip
    outbound_type       = each.value.outbound_type
  }

  private_cluster_enabled             = each.value.private_cluster_enabled
  private_cluster_public_fqdn_enabled = each.value.private_cluster_public_fqdn_enabled
  aks_private_dns_zone_mode           = each.value.aks_private_dns_zone_mode
  aks_private_dns_zone_id = try(
    "/subscriptions/${each.value.aks_private_dns_zone_id.subscription_id}/resourceGroups/${each.value.aks_private_dns_zone_id.resource_group_name}/providers/Microsoft.Network/privateDnsZones/${each.value.aks_private_dns_zone_id.private_dns_zone_name}",
    null
  )

  storage_profile_disk_driver_enabled         = each.value.storage_profile_disk_driver_enabled
  storage_profile_file_driver_enabled         = each.value.storage_profile_file_driver_enabled
  storage_profile_blob_driver_enabled         = each.value.storage_profile_blob_driver_enabled
  storage_profile_snapshot_controller_enabled = each.value.storage_profile_snapshot_controller_enabled

  service_mesh_profile        = each.value.service_mesh_profile
  workload_autoscaler_profile = each.value.workload_autoscaler_profile

  maintenance_window              = each.value.maintenance_window
  maintenance_window_auto_upgrade = each.value.maintenance_window_auto_upgrade
  maintenance_window_node_os      = each.value.maintenance_window_node_os

  web_app_routing = each.value.web_app_routing != null ? {
    dns_zone_ids = try(
      each.value.web_app_routing.dns_zone_ids != null ? each.value.web_app_routing.dns_zone_ids : (
        each.value.ingress_private_dns_zone_resource_id != null ? [
          "/subscriptions/${each.value.ingress_private_dns_zone_resource_id.subscription_id}/resourceGroups/${each.value.ingress_private_dns_zone_resource_id.resource_group_name}/providers/Microsoft.Network/privateDnsZones/${var.ingress_dns_zone_name}"
        ] : null
      ),
      null
    )
    default_nginx_controller = each.value.web_app_routing.default_nginx_controller
  } : null
  azure_policy_enabled = each.value.azure_policy_enabled

  ingress_dns_zone_name                  = var.ingress_dns_zone_name
  ingress_private_dns_zone_resource_id   = each.value.ingress_private_dns_zone_resource_id
  ingress_dns_zone_additional_vnet_links = each.value.ingress_dns_zone_additional_vnet_links
  image_cleaner_enabled                  = each.value.image_cleaner_enabled
  image_cleaner_interval_hours           = each.value.image_cleaner_interval_hours
  microsoft_defender_enabled             = each.value.microsoft_defender_enabled
  fluxcd_enabled                         = each.value.fluxcd_enabled
  attached_acr_id_map                    = each.value.attached_acr_id_map

  base_name = local.base_name

  log_analytics_workspace_id  = each.value.log_analytics_workspace_id
  enable_container_insights   = each.value.enable_container_insights
  enable_oms_agent            = try(each.value.enable_oms_agent, true)
  monitor_metrics_enabled     = each.value.monitor_metrics_enabled
  enable_application_insights = each.value.enable_application_insights
  application_insights_type   = each.value.application_insights_type
  cost_analysis_enabled       = each.value.cost_analysis_enabled

  aks_diagnostic_log_categories    = try(each.value.diagnostic_log_categories, null)
  aks_diagnostic_log_groups        = try(each.value.diagnostic_log_groups, null)
  aks_diagnostic_metric_categories = try(each.value.diagnostic_metric_categories, null)

  tags = merge(local.common_tags, try(each.value.tags, {}))

  depends_on = [module.resource_groups, module.keyvault]
}

resource "azurerm_role_assignment" "aks_node_rg_contributor" {
  count = var.create_aks ? 1 : 0

  role_definition_name = "Contributor"
  scope                = module.aks[keys(module.aks)[0]].node_resource_group_id
  principal_id         = module.aks[keys(module.aks)[0]].kubelet_identity_id

  depends_on = [module.aks]
}

# ============================================================================
# Flux CD GitOps Module
# ============================================================================
module "flux" {
  source = "./terraform-azure-lz-modules/flux"

  count  = var.create_aks && var.fluxcd_enabled ? 1 : 0

  # Core Configuration
  region              = var.region
  env                 = var.env
  resource_group_name = module.resource_groups[var.aks_clusters[keys(var.aks_clusters)[0]].resource_group_key].resource_group_name
  aks_cluster_name    = local.aks_cluster_name

  # Flux Configuration
  fluxcd_enabled         = var.fluxcd_enabled
  flux_github_owner      = var.flux_github_owner
  flux_github_repository = var.flux_github_repository
  flux_github_branch     = var.flux_github_branch
  flux_github_path       = var.flux_github_path
  flux_ssh_private_key   = var.flux_ssh_private_key
  flux_namespace_name    = var.flux_namespace_name

  # Kubernetes Secret Configuration
  create_kubernetes_secret   = var.create_kubernetes_secret
  keyvault_name              = local.name_keyvault
  keyvault_uri               = try(module.keyvault[keys(module.keyvault)[0]].keyvault_uri, "")
  external_secrets_client_id = var.create_aks ? module.aks[keys(module.aks)[0]].workload_identity_client_ids["external-secrets"] : ""
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  ingress_dns_zone_name      = var.ingress_dns_zone_name
  acr_login_server           = "${local.name_acr}.azurecr.io"

  depends_on = [
    module.aks,
    module.keyvault
  ]
}

######################################################################################
# PostgreSQL Flexible Server
######################################################################################

module "postgres" {
  source = "./terraform-azure-lz-modules/postgres"

  for_each = var.postgres_servers

  name                = local.postgres_server_name[each.key]
  resource_group_name = module.resource_groups[each.value.resource_group_key].resource_group_name
  location            = var.location

  delegated_subnet_id           = data.azurerm_subnet.pg[each.key].id
  private_dns_zone_id           = local.postgres_private_dns_zone_resource_id[each.key]
  public_network_access_enabled = each.value.public_network_access_enabled

  sku_name          = each.value.sku_name
  postgres_version  = each.value.postgres_version
  storage_mb        = each.value.storage_mb
  storage_tier      = each.value.storage_tier
  auto_grow_enabled = each.value.auto_grow_enabled
  availability_zone = each.value.availability_zone

  backup_retention_days        = each.value.backup_retention_days
  geo_redundant_backup_enabled = each.value.geo_redundant_backup_enabled

  high_availability  = each.value.high_availability
  maintenance_window = each.value.maintenance_window

  server_log_retention_days  = each.value.server_log_retention_days
  log_analytics_workspace_id = local.postgres_log_analytics_workspace_id[each.key]
  diagnostic_log_categories  = each.value.diagnostic_log_categories
  diagnostic_metrics_enabled = each.value.diagnostic_metrics_enabled

  administrator_login    = each.value.administrator_login
  administrator_password = try(each.value.pg_password, var.pg_password)
  authentication         = each.value.authentication

  azure_ad_administrators = local.postgres_azure_ad_administrators[each.key]

  databases        = each.value.databases
  configurations   = each.value.configurations
  firewall_rules   = each.value.firewall_rules
  role_assignments = each.value.role_assignments

  tags = merge(local.common_tags, each.value.tags)

  depends_on = [module.resource_groups, module.aks]
}

######################################################################################
# Azure Backup for AKS
######################################################################################

module "backup" {
  source = "./terraform-azure-lz-modules/aks-backup"

  for_each = var.backup_vaults

  backup_vault_name              = local.name_backupvault
  resource_group_name            = module.resource_groups[each.value.resource_group_key].resource_group_name
  location                       = var.location
  subscription_id                = data.azurerm_client_config.current.subscription_id
  tenant_id                      = data.azurerm_client_config.current.tenant_id
  aks_cluster_id                 = module.aks[keys(module.aks)[0]].aks_id
  aks_cluster_name               = local.aks_cluster_name
  aks_resource_group_name        = module.resource_groups[var.aks_clusters[keys(var.aks_clusters)[0]].resource_group_key].resource_group_name
  aks_control_plane_principal_id = module.aks[keys(module.aks)[0]].aks_identity_principal_id
  backup_storage_account_name    = local.backup_storage_account_name

  backup_container_name    = local.backup_container_name
  storage_account_tier     = each.value.backup_storage_account_tier
  storage_replication_type = each.value.backup_storage_replication_type

  backup_vault_datastore_type = each.value.backup_vault_datastore_type
  backup_vault_redundancy     = each.value.backup_vault_redundancy
  backup_extension_name       = local.backup_extension_name

  backup_policy_name        = local.backup_policy_name
  backup_frequency          = each.value.backup_frequency
  backup_retention_days     = each.value.backup_retention_days
  backup_retention_criteria = each.value.backup_retention_criteria

  backup_instance_name                    = local.backup_instance_name
  backup_excluded_namespaces              = each.value.backup_excluded_namespaces
  backup_included_namespaces              = each.value.backup_included_namespaces
  backup_excluded_resource_types          = each.value.backup_excluded_resource_types
  backup_included_resource_types          = each.value.backup_included_resource_types
  backup_label_selectors                  = each.value.backup_label_selectors
  backup_cluster_scoped_resources_enabled = each.value.backup_cluster_scoped_resources_enabled
  backup_volume_snapshot_enabled          = each.value.backup_volume_snapshot_enabled

  backup_vault_aks_role     = each.value.backup_vault_aks_role
  backup_vault_storage_role = each.value.backup_vault_storage_role

  tags       = merge(local.common_tags, try(each.value.tags, {}))
  depends_on = [module.resource_groups, module.aks]
}

######################################################################################
# Azure Managed Service bus
######################################################################################

module "servicebus" {
  source = "./terraform-azure-lz-modules/servicebus"

  count  = var.servicebus != null ? 1 : 0

  name                = local.servicebus_name
  resource_group_name = var.servicebus != null ? module.resource_groups[var.servicebus.resource_group_key].resource_group_name : null
  location            = var.location

  sku                           = var.servicebus != null ? var.servicebus.sku : "Premium"
  capacity                      = var.servicebus != null ? var.servicebus.capacity : 1
  public_network_access_enabled = var.servicebus != null ? var.servicebus.public_network_access_enabled : false
  local_auth_enabled            = var.servicebus != null ? var.servicebus.local_auth_enabled : false
  minimum_tls_version           = var.servicebus != null ? var.servicebus.minimum_tls_version : "1.2"

  # Private endpoint + existing private DNS zone (data.azurerm_private_dns_zone.sb)
  private_endpoint_subnet_id = var.servicebus != null ? data.azurerm_subnet.sb[0].id : null
  private_dns_zone_id        = local.servicebus_private_dns_zone_resource_id

  # Network rules: when empty, wrapper uses default_action Allow (private-endpoint-only; PE subnet does not need Microsoft.ServiceBus service endpoint)
  network_rule_subnet_ids               = var.servicebus != null ? var.servicebus.network_rule_subnet_ids : []
  network_rule_cidr_or_ip_rules         = var.servicebus != null ? var.servicebus.network_rule_cidr_or_ip_rules : []
  network_rule_trusted_services_allowed = var.servicebus != null ? var.servicebus.network_rule_trusted_services_allowed : false

  queues           = var.servicebus != null ? var.servicebus.queues : {}
  topics           = var.servicebus != null ? var.servicebus.topics : {}
  role_assignments = local.servicebus_role_assignments

  tags = var.servicebus != null ? merge(local.common_tags, try(var.servicebus.tags, {})) : local.common_tags

  depends_on = [module.resource_groups, module.aks]
}

######################################################################################
# Azure Managed Redis
######################################################################################

module "managed_redis" {
  source = "./terraform-azure-lz-modules/managed_redis"

  count  = var.managed_redis != null ? 1 : 0

  name                = local.managed_redis_name
  resource_group_name = module.resource_groups[var.managed_redis.resource_group_key].resource_group_name
  location            = var.location

  sku_name                      = var.managed_redis.sku_name
  public_network_access_enabled = var.managed_redis.public_network_access_enabled
  high_availability_enabled     = var.managed_redis.high_availability_enabled
  identity                      = var.managed_redis.identity
  customer_managed_key          = var.managed_redis.customer_managed_key
  default_database              = var.managed_redis.default_database
  tags                          = merge(local.common_tags, try(var.managed_redis.tags, {}))

  # Private endpoint (internal-only). Use created zone or existing (data source).
  private_endpoint_name                = "${local.managed_redis_name}-pe"
  private_endpoint_resource_group_name = var.managed_redis.private_endpoint.resource_group_name
  private_endpoint_location            = var.location
  private_endpoint_subnet_id           = data.azurerm_subnet.redis[0].id
  private_endpoint_nic_name            = "${local.managed_redis_name}-pe-nic"
  private_service_connection_name      = "${local.managed_redis_name}-psc"
  private_service_is_manual_connection = false
  private_dns_zone_id                  = local.managed_redis_private_dns_zone_resource_id
  private_dns_zone_group_name          = "default"
  role_assignments                     = try(var.managed_redis.role_assignments, {})

  depends_on = [module.resource_groups, module.aks]
}

# Grant AKS workload identities access to Managed Redis default database (Entra/AAD auth).
# Uses access policy assignment on the default database, not Azure RBAC role.
resource "azurerm_managed_redis_access_policy_assignment" "redis_workload_identity" {
  for_each = var.managed_redis != null && var.create_aks && length(try(var.managed_redis.grant_redis_to_workload_identity_keys, [])) > 0 ? toset(var.managed_redis.grant_redis_to_workload_identity_keys) : toset([])

  managed_redis_id = module.managed_redis[0].id
  object_id        = module.aks[keys(module.aks)[0]].workload_identity_principal_ids[each.key]

  depends_on = [module.managed_redis]
}

######################################################################################
# Central DNS Zone VNet Links
# Links this environment's VNet to private DNS zones.
# Most zones live in IT-Shared (uses azurerm.it_shared provider).
# Zones in the current AKS subscription (e.g. ssl/ingress) use the default provider.
# Set use_current_subscription = true on any entry that lives outside IT-Shared.
######################################################################################

# Zones in IT-Shared subscription (default — subscription_id omitted or null)
resource "azurerm_private_dns_zone_virtual_network_link" "central_dns_links" {
  for_each = {
    for k, v in var.central_dns_zone_links : k => v
    if try(data.azurerm_virtual_network.this[0].id, null) != null &&
       coalesce(v.subscription_id, var.it_shared_subscription_id) == var.it_shared_subscription_id
  }

  provider = azurerm.it_shared

  name                  = "${local.name}-${each.key}-link"
  private_dns_zone_name = each.value.zone_name
  resource_group_name   = each.value.zone_resource_group
  virtual_network_id    = data.azurerm_virtual_network.this[0].id
  registration_enabled  = false

  tags = local.common_tags
}

# Zones in other subscriptions (subscription_id set and differs from IT-Shared)
# Uses the default azurerm provider scoped to var.subscription_id
resource "azurerm_private_dns_zone_virtual_network_link" "central_dns_links_current_sub" {
  for_each = {
    for k, v in var.central_dns_zone_links : k => v
    if try(data.azurerm_virtual_network.this[0].id, null) != null &&
       v.subscription_id != null && v.subscription_id != var.it_shared_subscription_id
  }

  name                  = "${local.name}-${each.key}-link"
  private_dns_zone_name = each.value.zone_name
  resource_group_name   = each.value.zone_resource_group
  virtual_network_id    = data.azurerm_virtual_network.this[0].id
  registration_enabled  = false

  tags = local.common_tags
}

######################################################################################
# Azure Function App - Storage Account
######################################################################################

module "function_app_storage" {
  source = "./terraform-azure-lz-modules/storage-account"

  for_each = var.function_apps

  name                          = lower(replace("${var.region_short_v2}${var.team_short}${var.env_short}${each.value.resource}st", "-", ""))
  resource_group_name           = module.resource_groups[each.value.resource_group_key].resource_group_name
  location                      = var.location
  account_tier                  = each.value.storage_account.account_tier
  account_replication_type      = each.value.storage_account.account_replication_type
  public_network_access_enabled = each.value.storage_account.public_network_access_enabled
  enable_telemetry              = false
  role_assignments              = each.value.storage_account.role_assignments

  tags = merge(local.common_tags, each.value.tags)

  depends_on = [module.resource_groups]
}

# ######################################################################################
# # Azure Function App
# ######################################################################################

module "function_app" {
  source = "./terraform-azure-lz-modules/function-app"

  for_each = var.function_apps

  name                = "${local.name}-${each.value.resource}"
  resource_group_name = module.resource_groups[each.value.resource_group_key].resource_group_name
  location            = var.location
  service_plan_name   = "${local.name}-${each.value.resource}-asp"

  # App Service Plan
  sku_name               = each.value.sku_name
  zone_balancing_enabled = each.value.zone_balancing_enabled
  os_type                = each.value.os_type

  # Storage Account (from storage-account module)
  storage_account_name       = module.function_app_storage[each.key].storage_account_name
  storage_account_access_key = module.function_app_storage[each.key].primary_access_key

  # Function App Runtime
  dotnet_version              = each.value.dotnet_version
  use_dotnet_isolated_runtime = each.value.use_dotnet_isolated_runtime
  functions_extension_version = each.value.functions_extension_version
  app_settings                = each.value.app_settings

  # Networking
  public_network_access_enabled = each.value.public_network_access_enabled
  virtual_network_subnet_id     = each.value.vnet_integration_subnet != null ? data.azurerm_subnet.func_vnet_integration[each.key].id : null
  private_endpoint_subnet_id    = each.value.private_endpoint != null ? data.azurerm_subnet.func_pe[each.key].id : null
  private_dns_zone_id           = local.function_app_private_dns_zone_resource_id

  # Identity
  managed_identities = each.value.managed_identities

  # RBAC
  role_assignments = each.value.role_assignments

  # Telemetry
  enable_telemetry = false

  tags = merge(local.common_tags, each.value.tags)

  depends_on = [module.resource_groups, module.function_app_storage]
}

module "StaticWebApp" {
  source = "./terraform-azure-lz-modules/StaticWebApp"

  for_each = var.static_web_apps

  name                = "${local.name}-${each.value.prefix}"
  resource_group_name = module.resource_groups[each.value.resource_group_key].resource_group_name
  location            = "westeurope"
  sku_tier            = each.value.sku_tier
  sku_size            = each.value.sku_tier
  custom_domains      = each.value.custom_domains
  role_assignments    = each.value.role_assignments

  private_endpoints = each.value.private_endpoint != null ? {
    main = {
      subnet_resource_id            = data.azurerm_subnet.swa[each.key].id
      private_dns_zone_resource_ids = toset([data.azurerm_private_dns_zone.swa[each.key].id])
      location                      = var.location # PE must be in the VNet's region, not the SWA's
    }
  } : {}
  
  tags = merge(local.common_tags, each.value.tags)
}

######################################################################################
#Storage Accounts
######################################################################################
module "storage_accounts" {
  source   = "./terraform-azure-lz-modules/storage-account"
  for_each = var.storage_accounts

  name = lower("${var.region_short_v2}${coalesce(var.env_short_v2, var.env_short)}${each.value.name}")

  resource_group_name = module.resource_groups[each.value.resource_group_key].resource_group_name
  location            = var.location
  enable_telemetry    = coalesce(try(each.value.enable_telemetry, null), var.enable_telemetry)

  account_tier              = try(each.value.account_tier, "Standard")
  account_replication_type  = try(each.value.account_replication_type, "LRS")
  account_kind              = try(each.value.account_kind, "StorageV2")
  shared_access_key_enabled = try(each.value.shared_access_key_enabled, true)

  public_network_access_enabled = try(each.value.public_network_access_enabled, false)
  enable_network_rules          = try(each.value.enable_network_rules, true)
  network_rules_bypass          = try(each.value.network_rules_bypass, ["AzureServices"])
  network_rules_default_action  = try(each.value.network_rules_default_action, "Deny")
  allowed_ip_addresses          = try(each.value.allowed_ip_addresses, [])
  allowed_subnet_ids            = try(each.value.allowed_subnet_ids, [])

  role_assignments = try(each.value.role_assignments, {})

  containers = each.value.containers

  private_endpoints = each.value.private_endpoint != null ? {
    blob = {
      name                          = "${local.name_storage}-pe-blob"
      subnet_resource_id            = data.azurerm_subnet.storage_pe[each.key].id
      subresource_name              = "blob"
      private_dns_zone_resource_ids = local.storage_blob_private_dns_zone_resource_id[each.key] != null ? [local.storage_blob_private_dns_zone_resource_id[each.key]] : []
      tags = merge(local.common_tags, try(each.value.tags, {}))
    }
  } : {}

  blob_delete_after_days = try(each.value.blob_delete_after_days, null)

  tags       = merge(local.common_tags, try(each.value.tags, {}))
  depends_on = [module.resource_groups]
}

# Grant this cluster's node (kubelet) identity "Azure Service Bus Data Sender"
resource "azurerm_role_assignment" "aks_nodes_external_servicebus_sender" {
  for_each = var.create_aks ? toset(var.external_servicebus_scope_ids) : toset([])

  role_definition_name = "Azure Service Bus Data Sender"
  scope                = each.value
  principal_id         = module.aks[keys(module.aks)[0]].kubelet_identity_id

  depends_on = [module.aks]
}

# Grant this cluster's node (kubelet) identity "Azure Service Bus Data Receiver"
resource "azurerm_role_assignment" "aks_nodes_external_servicebus_receiver" {
  for_each = var.create_aks ? toset(var.external_servicebus_scope_ids) : toset([])

  role_definition_name = "Azure Service Bus Data Receiver"
  scope                = each.value
  principal_id         = module.aks[keys(module.aks)[0]].kubelet_identity_id

  depends_on = [module.aks]
}

# Grant this cluster's node (kubelet) identity "Storage Blob Data Contributor" on external storage accounts
resource "azurerm_role_assignment" "aks_nodes_storage_blob_contributor" {
  for_each = var.create_aks ? toset(var.external_storage_scope_ids) : toset([])

  role_definition_name = "Storage Blob Data Contributor"
  scope                = each.value
  principal_id         = module.aks[keys(module.aks)[0]].kubelet_identity_id

  depends_on = [module.aks]
}