# ---------------------------
# outputs.tf
# ---------------------------

output "gke_endpoint" {
  description = "GKE control plane endpoint"
  value       = google_container_cluster.gke.endpoint
}

output "jupyterhub_namespace" {
  description = "Namespace ที่ติดตั้ง JupyterHub"
  value       = kubernetes_namespace.jhub.metadata[0].name
}

output "jupyterhub_release_name" {
  description = "ชื่อ Helm release ของ JupyterHub"
  value       = helm_release.jhub.name
}

# ---------------------------
# JupyterHub Public URL/IP (จาก Service: proxy-public)
# ต้องใช้ values.yaml ที่ตั้ง proxy.service.type: LoadBalancer
# ---------------------------

data "kubernetes_service" "jhub_proxy_public" {
  metadata {
    name      = "proxy-public"
    namespace = kubernetes_namespace.jhub.metadata[0].name
  }

  depends_on = [helm_release.jhub]
}

output "jupyterhub_external_ip" {
  description = "External IP ของ JupyterHub (ถ้าได้เป็น IP)"
  value       = try(data.kubernetes_service.jhub_proxy_public.status[0].load_balancer[0].ingress[0].ip, null)
}

output "jupyterhub_external_hostname" {
  description = "External Hostname ของ JupyterHub (ถ้าได้เป็น hostname)"
  value       = try(data.kubernetes_service.jhub_proxy_public.status[0].load_balancer[0].ingress[0].hostname, null)
}

output "jupyterhub_url" {
  description = "URL ที่ใช้เข้า JupyterHub (จะเป็น IP หรือ hostname อย่างใดอย่างหนึ่ง)"
  value = (
    try(data.kubernetes_service.jhub_proxy_public.status[0].load_balancer[0].ingress[0].hostname, null) != null ?
    "http://${data.kubernetes_service.jhub_proxy_public.status[0].load_balancer[0].ingress[0].hostname}" :
    try(data.kubernetes_service.jhub_proxy_public.status[0].load_balancer[0].ingress[0].ip, null) != null ?
    "http://${data.kubernetes_service.jhub_proxy_public.status[0].load_balancer[0].ingress[0].ip}" :
    null
  )
}
