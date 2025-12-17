variable "project_id" {
  type        = string
  description = "GCP Project ID"
}

variable "region" {
  type        = string
  description = "GCP region"
  default     = "asia-southeast1"
}

variable "zone" {
  type        = string
  description = "GCP zone (เช่น asia-southeast1-b)"
  default     = "asia-southeast1-b"
}

variable "cluster_name" {
  type        = string
  description = "GKE cluster name"
  default     = "gke-jhub"
}

variable "node_count" {
  type        = number
  description = "จำนวน node ใน node pool"
  default     = 2
}

variable "machine_type" {
  type        = string
  description = "machine type ของ node pool"
  default     = "e2-standard-2"
}
