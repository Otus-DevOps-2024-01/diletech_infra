resource "yandex_lb_network_load_balancer" "lb" {
  name = "reddit-load-balancer"
  #   deletion_protection = "true"
  listener {
    name        = "test-listener"
    port        = 9292
    target_port = 9292
    protocol    = "tcp"
    external_address_spec {
      ip_version = "ipv4"
    }
  }
  attached_target_group {
    target_group_id = yandex_lb_target_group.target_lb.id
    healthcheck {
      name                = "http"
      interval            = 2
      timeout             = 1
      unhealthy_threshold = 2
      healthy_threshold   = 2
      http_options {
        port = 9292
        path = "/"
      }
    }
  }
}

resource "yandex_lb_target_group" "target_lb" {
  name = "reddit-target-group"

  dynamic "target" {
    for_each = yandex_compute_instance.app
    content {
      subnet_id = var.subnet_id
      address   = target.value.network_interface[0].ip_address
    }
  }
}
