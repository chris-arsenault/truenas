variable "truenas_api_key" {
  description = "TrueNAS API key"
  type        = string
  sensitive   = true
}

variable "truenas_base_url" {
  description = "TrueNAS API base URL (e.g. https://truenas.local/api/v2.0)"
  type        = string
}

variable "pool_name" {
  description = "ZFS pool name for datasets"
  type        = string
  default     = "tank"
}
