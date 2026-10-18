# ============================================================================
# Root Module Outputs - Essential Only
# ============================================================================

output "resource_groups" {
  description = "Map of resource group names"
  value       = { for k, v in module.resource_groups : k => v.resource_group_name }
}

output "acr_registries" {
  description = "Map of ACR registry information"
  value       = { for k, v in module.acr : k => {
    id           = v.acr_id
    name         = v.acr_name
    login_server = v.acr_login_server
  }}
}

# output "aks_clusters" {
#   description = "Map of AKS cluster information"
#   value       = { for k, v in module.aks : k => {
#     id   = v.aks_id
#     name = v.aks_cluster_name
#   }}
# }

output "key_vaults" {
  description = "Map of Key Vault information"
  value       = { for k, v in module.keyvault : k => {
    id   = v.keyvault_id
    name = v.keyvault_name
  }}
}

output "postgres_servers" {
  description = "Map of PostgreSQL Flexible Server information"
  value = { for k, v in module.postgres : k => {
    id   = v.id
    name = v.name
    fqdn = v.fqdn
  }}
}

output "postgres_connection_strings" {
  description = "Map of PostgreSQL connection strings (without password)"
  value       = { for k, v in module.postgres : k => v.connection_strings }
  sensitive   = true
}

# output "backup_vaults" {
#   description = "Map of Backup Vault information"
#   value       = { for k, v in module.backup : k => {
#     id   = v.backup_vault_id
#     name = v.backup_vault_name
#   }}
# }

# output "flux_ssh_key" {
#   description = "Flux SSH public key for GitHub repository access"
#   value       = var.fluxcd_enabled && var.create_aks ? module.flux[0].ssh-key : null
#   sensitive   = true
# }