resource "yandex_compute_instance" "app" {
  name                      = var.vm_name_app
  allow_stopping_for_update = true
  platform_id               = "standard-v2"


  labels = {
    tags = "reddit-app"
  }
  resources {
    cores         = 2
    memory        = 0.5
    core_fraction = 5
  }

  boot_disk {
    initialize_params {
      image_id = var.app_disk_image
    }
  }

  network_interface {
    subnet_id = var.subnet_id
    nat       = true
  }

  metadata = {
    ssh-keys = "appuser:${file(var.public_key_path)}"
  }

  scheduling_policy {
    preemptible = true
  }
}
