# ============================================================================
# Flux CD GitOps Variables
# ============================================================================
# Note: fluxcd_enabled is declared in variables-aks.tf as it's used by both
# the AKS module (for the extension) and the Flux module (for configuration)

variable "flux_github_owner" {
  description = "GitHub organization or user that owns the Flux repository"
  type        = string
  default     = ""
}

variable "flux_github_repository" {
  description = "Name of the GitHub repository for Flux"
  type        = string
  default     = ""
}

variable "flux_github_branch" {
  description = "Branch to track in the Flux repository"
  type        = string
  default     = "main"
}

variable "flux_github_path" {
  description = "Path within the repository for Flux manifests (empty = auto-generate from environment)"
  type        = string
  default     = ""
}

variable "flux_ssh_private_key" {
  description = "SSH private key for GitHub repository access (base64 encoded). Set via TF_VAR_flux_ssh_private_key env var"
  type        = string
  default     = ""
  sensitive   = true
}

variable "flux_namespace_name" {
  description = "Kubernetes namespace for Flux system components"
  type        = string
  default     = "flux-system"
}

variable "create_kubernetes_secret" {
  description = "Whether to create the Kubernetes secret for external-secrets operator in the Flux module"
  type        = bool
  default     = true
}