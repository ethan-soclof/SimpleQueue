terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "3.52.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.0.1"
    }
  }
}

data "terraform_remote_state" "gke" {
  backend = "local"

  config = {
    path = "../provision-gke-cluster/terraform.tfstate"
  }
}

# Retrieve GKE cluster information
provider "google" {
  project = data.terraform_remote_state.gke.outputs.project_id
  region  = data.terraform_remote_state.gke.outputs.region
}

# Configure kubernetes provider with Oauth2 access token.
# https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/client_config
# This fetches a new token, which will expire in 1 hour.
data "google_client_config" "default" {}

data "google_container_cluster" "my_cluster" {
  name     = data.terraform_remote_state.gke.outputs.kubernetes_cluster_name
  location = data.terraform_remote_state.gke.outputs.region
}

provider "kubernetes" {
  host = data.terraform_remote_state.gke.outputs.kubernetes_cluster_host

  token                  = data.google_client_config.default.access_token
  cluster_ca_certificate = base64decode(data.google_container_cluster.my_cluster.master_auth[0].cluster_ca_certificate)
}


resource "kubernetes_service" "rabbit" {
  metadata {
    name = "rabbit"
    labels = {
      app = "rabbit"
    }
  }
  spec {
    selector = {
      app = "rabbit"
    }
    port {
      port        = 5672
      target_port = 5672
    }

    type = "LoadBalancer"
  }
}

resource "kubernetes_deployment" "rabbit" {
  metadata {
    name = "rabbit"
    labels = {
      app = "rabbit"
    }
  }

  spec {
    replicas = 1
    selector {
      match_labels = {
        app = "rabbit"
      }
    }
    template {
      metadata {
        labels = {
          app = "rabbit"
        }
      }
      spec {
        container {
          image = "rabbitmq:3-management"
          name  = "rabbit"

          port {
            container_port = 5672
          }
          resources {
            limits = {
              cpu    = "0.5"
              memory = "512Mi"
            }
            requests = {
              cpu    = "250m"
              memory = "50Mi"
            }
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "gateway" {
  metadata {
    name = "gateway"
    labels = {
      app = "gateway"
    }
  }
  spec {
    selector = {
      app = "gateway"
    }
    port {
      port        = 5000
      target_port = 5000
    }

    type = "LoadBalancer"
  }
}

output "gateway_ip" {
  value = kubernetes_service.gateway.status.0.load_balancer.0.ingress.0.ip
}


resource "kubernetes_deployment" "gateway" {
  metadata {
    name = "gateway"
    labels = {
      app = "gateway"
    }
  }

  spec {
    replicas = 1
    selector {
      match_labels = {
        app = "gateway"
      }
    }
    template {
      metadata {
        labels = {
          app = "gateway"
        }
      }
      spec {
        container {
          image = "etansoclof/q_gateway:6.2"
          name  = "gateway"

          port {
            container_port = 5000
          }

          env {
            name  = "RABBIT_HOST"
            value = "rabbit"
          }
          env {
            name  = "RABBIT_PASSWORD"
            value = "guest"
          }
          env {
            name  = "RABBIT_PORT"
            value = "5672"
          }
          env {
            name  = "RABBIT_USER"
            value = "guest"
          }
          resources {
            limits = {
              cpu    = "0.5"
              memory = "512Mi"
            }
            requests = {
              cpu    = "250m"
              memory = "50Mi"
            }
          }
        }
      }
    }
  }
}

resource "kubernetes_deployment" "process" {
  metadata {
    name = "process"
    labels = {
      app = "process"
    }
  }

  spec {
    replicas = 1
    selector {
      match_labels = {
        app = "process"
      }
    }
    template {
      metadata {
        labels = {
          app = "process"
        }
      }
      spec {
        container {
          image = "etansoclof/q_process:7.0"
          name  = "process"

          env {
            name  = "RABBIT_HOST"
            value = "rabbit"
          }
          env {
            name  = "RABBIT_PASSWORD"
            value = "guest"
          }
          env {
            name  = "RABBIT_PORT"
            value = "5672"
          }
          env {
            name  = "RABBIT_USER"
            value = "guest"
          }
        }
      }
    }
  }
}




