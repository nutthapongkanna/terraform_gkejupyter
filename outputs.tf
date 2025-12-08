output "gke_endpoint" {
  value = google_container_cluster.gke.endpoint
}

output "jupyterhub_namespace" {
  value = kubernetes_namespace.jhub.metadata[0].name
}

output "jupyterhub_service" {
  value = helm_release.jhub.name
}
