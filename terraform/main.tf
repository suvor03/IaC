terraform {
  required_version = ">= 1.5.0"

  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
  }
}

provider "docker" {}

provider "local" {}

locals {
  nodes = {
    web = {
      name  = "node-1"
      ports = [{ internal = 80, external = 8080 }]
    }
    app = {
      name  = "node-2"
      ports = [{ internal = 8000, external = 8000 }]
    }
    db = {
      name  = "node-3"
      ports = []
    }
  }
}

resource "docker_image" "ubuntu" {
  name         = "ubuntu:22.04"
  keep_locally = true
}

resource "docker_network" "lab" {
  name   = "${var.project_name}-network"
  driver = "bridge"
}

resource "docker_container" "nodes" {
  for_each = local.nodes

  name         = each.value.name
  image        = docker_image.ubuntu.image_id
  command      = ["tail", "-f", "/dev/null"]
  restart      = "unless-stopped"
  network_mode = "bridge"
  log_driver   = "json-file"
  log_opts = {
    "max-file" = "5"
    "max-size" = "20m"
  }

  labels {
    label = "managed-by"
    value = "terraform"
  }

  labels {
    label = "lab"
    value = var.project_name
  }

  networks_advanced {
    name    = docker_network.lab.name
    aliases = [each.value.name]
  }

  dynamic "ports" {
    for_each = each.value.ports

    content {
      internal = ports.value.internal
      external = ports.value.external
      ip       = "0.0.0.0"
    }
  }
}

resource "local_file" "ansible_inventory" {
  filename        = "${path.module}/../ansible/inventory.ini"
  content         = templatefile("${path.module}/inventory.tftpl", { nodes = { for key, node in local.nodes : key => node.name } })
  file_permission = "0644"

  depends_on = [docker_container.nodes]
}
