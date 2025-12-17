provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}

data "google_client_config" "default" {}

# NOTE:
# kubernetes/helm provider จะใช้ค่า endpoint/CA จาก resource gke โดยตรง
# แนะนำ apply แบบ 2 ขั้นเพื่อให้ชัวร์ว่า cluster สร้างก่อน (ดูคำสั่งท้ายสุด)
provider "kubernetes" {
  host  = "https://${google_container_cluster.gke.endpoint}"
  token = data.google_client_config.default.access_token

  cluster_ca_certificate = base64decode(
    google_container_cluster.gke.master_auth[0].cluster_ca_certificate
  )
}

provider "helm" {
  kubernetes {
    host  = "https://${google_container_cluster.gke.endpoint}"
    token = data.google_client_config.default.access_token

    cluster_ca_certificate = base64decode(
      google_container_cluster.gke.master_auth[0].cluster_ca_certificate
    )
  }
}
