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

# -------------------------------------------------------------------
# Google Provider
# -------------------------------------------------------------------

provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}

# -------------------------------------------------------------------
# GKE Cluster
# -------------------------------------------------------------------

resource "google_container_cluster" "gke" {
  name     = var.cluster_name
  location = var.zone

  remove_default_node_pool = true
  initial_node_count       = 1

  network    = "default"
  subnetwork = "default"

  ip_allocation_policy {}
}

# -------------------------------------------------------------------
# Node Pool
# -------------------------------------------------------------------

resource "google_container_node_pool" "general" {
  name     = "${var.cluster_name}-pool"
  location = var.zone
  cluster  = google_container_cluster.gke.name

  initial_node_count = var.node_count

  node_config {
    machine_type = var.machine_type

    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]

    metadata = {
      disable-legacy-endpoints = "true"
    }
  }

  # OPTIONAL
  # autoscaling {
  #   min_node_count = 1
  #   max_node_count = 3
  # }
}

# -------------------------------------------------------------------
# Get Cluster Info (Endpoint + CA Cert)
# -------------------------------------------------------------------

data "google_container_cluster" "cluster" {
  name     = google_container_cluster.gke.name
  location = var.zone
}

# -------------------------------------------------------------------
# Use Google Auth Token Automatically
# -------------------------------------------------------------------

data "google_client_config" "default" {}

# -------------------------------------------------------------------
# Kubernetes Provider
# -------------------------------------------------------------------

provider "kubernetes" {
  host = "https://${data.google_container_cluster.cluster.endpoint}"

  token = data.google_client_config.default.access_token

  cluster_ca_certificate = base64decode(
    data.google_container_cluster.cluster.master_auth[0].cluster_ca_certificate
  )
}

# -------------------------------------------------------------------
# Helm Provider
# -------------------------------------------------------------------

provider "helm" {
  kubernetes {
    host = "https://${data.google_container_cluster.cluster.endpoint}"

    token = data.google_client_config.default.access_token

    cluster_ca_certificate = base64decode(
      data.google_container_cluster.cluster.master_auth[0].cluster_ca_certificate
    )
  }
}

# -------------------------------------------------------------------
# Namespace
# -------------------------------------------------------------------

resource "kubernetes_namespace" "jhub" {
  metadata {
    name = "jhub"
  }
}

# -------------------------------------------------------------------
# Deploy JupyterHub via Helm
# -------------------------------------------------------------------

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


# -------------------------------------------------------------------
# Auto configure kubeconfig after cluster is ready
# -------------------------------------------------------------------

resource "null_resource" "get_kubeconfig" {
  provisioner "local-exec" {
    command = "gcloud container clusters get-credentials ${var.cluster_name} --zone ${var.zone} --project ${var.project_id}"
  }

  depends_on = [
    google_container_cluster.gke,
    google_container_node_pool.general
  ]
}