terraform {
  required_version = ">= 1.5.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}

# -------------------------------------------------------------------------------------
# GKE Cluster
# -------------------------------------------------------------------------------------

resource "google_container_cluster" "gke" {
  name     = var.cluster_name
  location = var.zone

  remove_default_node_pool = true
  initial_node_count       = 1

  network    = "default"
  subnetwork = "default"

  ip_allocation_policy {}
}

resource "google_container_node_pool" "general" {
  name       = "${var.cluster_name}-pool"
  location   = var.zone
  cluster    = google_container_cluster.gke.name

  initial_node_count = var.node_count

  node_config {
    machine_type = var.machine_type
    oauth_scopes = ["https://www.googleapis.com/auth/cloud-platform"]
    metadata = {
      disable-legacy-endpoints = "true"
    }
  }
}

# -------------------------------------------------------------------------------------
# Kubernetes Provider Connection
# -------------------------------------------------------------------------------------

data "google_container_cluster" "cluster" {
  name     = google_container_cluster.gke.name
  location = var.zone
}

provider "kubernetes" {
  host = "https://${data.google_container_cluster.cluster.endpoint}"

  cluster_ca_certificate = base64decode(
    data.google_container_cluster.cluster.master_auth[0].cluster_ca_certificate
  )

  token = data.google_container_cluster.cluster.master_auth[0].access_token
}

provider "helm" {
  kubernetes {
    host = "https://${data.google_container_cluster.cluster.endpoint}"

    cluster_ca_certificate = base64decode(
      data.google_container_cluster.cluster.master_auth[0].cluster_ca_certificate
    )

    token = data.google_container_cluster.cluster.master_auth[0].access_token
  }
}

# -------------------------------------------------------------------------------------
# Namespace
# -------------------------------------------------------------------------------------

resource "kubernetes_namespace" "jhub" {
  metadata {
    name = "jhub"
  }
}

# -------------------------------------------------------------------------------------
# Helm Install JupyterHub
# -------------------------------------------------------------------------------------

resource "helm_release" "jhub" {
  name       = "jhub"
  namespace  = kubernetes_namespace.jhub.metadata[0].name
  repository = "https://jupyterhub.github.io/helm-chart/"
  chart      = "jupyterhub"
  version    = "3.3.7"

  values = [
    file("${path.module}/values.yaml")
  ]

  timeout = 900
  wait    = false
}
