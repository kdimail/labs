# Data source for current Azure configuration
data "azurerm_client_config" "current" {}

# Reads the current AKS cluster endpoint for kubernetes provider configuration.
# Uses a direct Azure API call (not the module output), so the provider always has
# a known host even when the AKS cluster resource is planned for replacement
# (e.g. pod_cidr / network_profile changes that force cluster recreation).
# Set aks_cluster_pre_exists = false only on the very first deployment, before the
# cluster exists, to prevent a "not found" error from this data source.
data "azurerm_kubernetes_cluster" "k8s_provider_config" {
  count               = var.create_aks && var.aks_cluster_pre_exists ? 1 : 0
  name                = local.aks_cluster_name
  resource_group_name = "${local.name}-rg-core"
}

# VNet lookup for linking this environment's VNet to central IT-Shared private DNS zones
data "azurerm_virtual_network" "this" {
  count = var.vnet_name != null && var.vnet_resource_group_name != null ? 1 : 0

  name                = var.vnet_name
  resource_group_name = var.vnet_resource_group_name
}

data "azurerm_subnet" "pg" {
  for_each = var.postgres_servers

  name                 = each.value.delegated_subnet.subnet_name
  virtual_network_name = each.value.delegated_subnet.vnet_name
  resource_group_name  = each.value.delegated_subnet.resource_group_name
}

# Private endpoint subnet lookup for ServiceBus
data "azurerm_subnet" "sb" {
  count = var.servicebus != null ? 1 : 0

  name                 = var.servicebus.private_endpoint.subnet_name
  virtual_network_name = var.servicebus.private_endpoint.vnet_name
  resource_group_name  = var.servicebus.private_endpoint.resource_group_name
}

# Private endpoint subnet lookup for Managed Redis
data "azurerm_subnet" "redis" {
  count = var.managed_redis != null ? 1 : 0

  name                 = var.managed_redis.private_endpoint.subnet_name
  virtual_network_name = var.managed_redis.private_endpoint.vnet_name
  resource_group_name  = var.managed_redis.private_endpoint.resource_group_name
}

# Private endpoint subnet lookup for Storage Accounts
data "azurerm_subnet" "storage_pe" {
  for_each = {
    for k, v in var.storage_accounts : k => v.private_endpoint
    if v.private_endpoint != null
  }

  name                 = each.value.subnet_name
  virtual_network_name = each.value.vnet_name
  resource_group_name  = each.value.resource_group_name
}

# VNet integration subnet lookup for Function Apps
data "azurerm_subnet" "func_vnet_integration" {
  for_each = {
    for k, v in var.function_apps : k => v.vnet_integration_subnet
    if v.vnet_integration_subnet != null
  }

  name                 = each.value.subnet_name
  virtual_network_name = each.value.vnet_name
  resource_group_name  = each.value.resource_group_name
}

# Private endpoint subnet lookup for Function Apps
data "azurerm_subnet" "func_pe" {
  for_each = {
    for k, v in var.function_apps : k => v.private_endpoint
    if v.private_endpoint != null
  }

  name                 = each.value.subnet_name
  virtual_network_name = each.value.vnet_name
  resource_group_name  = each.value.resource_group_name
}

# Private endpoint subnet lookup for Static Web Apps
data "azurerm_subnet" "swa" {
  for_each = { for k, v in var.static_web_apps : k => v.private_endpoint if v.private_endpoint != null }

  name                 = each.value.subnet_name
  virtual_network_name = each.value.vnet_name
  resource_group_name  = each.value.resource_group_name
}

data "azurerm_private_dns_zone" "swa" {
  for_each = { for k, v in var.static_web_apps : k => v if v.private_dns_zone != null }

  provider            = azurerm.it_shared
  name                = each.value.private_dns_zone.private_dns_zone_name
  resource_group_name = each.value.private_dns_zone.resource_group_name
}