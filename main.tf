# ---------------------------
# (Optional) Enable APIs
# ---------------------------
resource "google_project_service" "container" {
  project = var.project_id
  service = "container.googleapis.com"
}

resource "google_project_service" "compute" {
  project = var.project_id
  service = "compute.googleapis.com"
}

# ---------------------------
# GKE Cluster
# ---------------------------
resource "google_container_cluster" "gke" {
  name     = var.cluster_name
  location = var.zone

  remove_default_node_pool = true
  initial_node_count       = 1

  network    = "default"
  subnetwork = "default"

  ip_allocation_policy {}

  depends_on = [
    google_project_service.container,
    google_project_service.compute
  ]
}

# ---------------------------
# Node Pool
# ---------------------------
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

  depends_on = [
    google_container_cluster.gke
  ]
}

# ---------------------------
# Namespace
# ---------------------------
resource "kubernetes_namespace" "jhub" {
  metadata {
    name = "jhub"
  }

  depends_on = [
    google_container_node_pool.general
  ]
}

# ---------------------------
# Deploy JupyterHub via Helm
# ---------------------------
resource "helm_release" "jhub" {
  name      = "jhub"
  namespace = kubernetes_namespace.jhub.metadata[0].name

  repository = "https://jupyterhub.github.io/helm-chart/"
  chart      = "jupyterhub"
  version    = "3.3.7"

  values = [
    file("${path.module}/values.yaml")
  ]

  timeout = 1200
  wait    = false

  depends_on = [
    google_container_node_pool.general,
    kubernetes_namespace.jhub
  ]
}

# ---------------------------
# Optional: ทำให้ kubectl ใช้ได้ทันที
# ---------------------------
resource "null_resource" "get_kubeconfig" {
  provisioner "local-exec" {
    command = "gcloud container clusters get-credentials ${var.cluster_name} --zone ${var.zone} --project ${var.project_id}"
  }

  depends_on = [
    google_container_node_pool.general
  ]
}
