# Provider GCP
provider "google" {
  project = "elmoh-cloud-lab2"
  region  = "europe-west1"
  zone    = "europe-west1-b"
}

# VM pour le load generator
resource "google_compute_instance" "loadgen_vm" {
  name         = "loadgen-vm"
  machine_type = "e2-micro"  # Petite VM pour économiser
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

  metadata_startup_script = <<-EOT
    #!/bin/bash
    # Installation de Docker
    apt-get update
    apt-get install -y docker.io
    systemctl start docker
    systemctl enable docker
    
    # Attendre que Docker soit prêt
    sleep 10
    
    # Lancer le load generator
    docker run -d \
      --name loadgen \
      --restart unless-stopped \
      -e FRONTEND_ADDR=34.22.160.178:80 \
      -e USERS=5 \
      -e RATE=1 \
      us-central1-docker.pkg.dev/google-samples/microservices-demo/loadgenerator:v0.10.3
  EOT

  tags = ["loadgen"]
}

# Output pour afficher l'IP de la VM
output "vm_external_ip" {
  value = google_compute_instance.loadgen_vm.network_interface[0].access_config[0].nat_ip
}
