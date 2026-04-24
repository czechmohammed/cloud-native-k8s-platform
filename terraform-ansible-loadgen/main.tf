# Provider GCP
provider "google" {
  project = "elmoh-cloud-lab2"
  region  = "europe-west1"
  zone    = "europe-west1-b"
}

# VM pour le load generator (infrastructure seulement)
resource "google_compute_instance" "loadgen_vm_v2" {
  name         = "loadgen-vm-v2"
  machine_type = "e2-micro"
  zone         = "europe-west1-b"

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2204-lts"
    }
  }

  network_interface {
    network = "default"
    access_config {
      # IP publique éphémère
    }
  }

  # Pas de startup script - Ansible s'en charge !
  
  tags = ["loadgen"]
  
  # Métadonnées pour SSH
  metadata = {
    ssh-keys = "${var.ssh_user}:${file(var.ssh_pub_key_path)}"
  }
}

# Variables
variable "ssh_user" {
  default = "elmoh"
}

variable "ssh_pub_key_path" {
  default = "~/.ssh/google_compute_engine.pub"
}

# Output
output "vm_external_ip" {
  value = google_compute_instance.loadgen_vm_v2.network_interface[0].access_config[0].nat_ip
}

output "vm_name" {
  value = google_compute_instance.loadgen_vm_v2.name
}
