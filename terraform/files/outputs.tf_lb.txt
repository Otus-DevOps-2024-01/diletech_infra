output "external_ip_address_app" {
  value = join(", ", [for instance in yandex_compute_instance.app : instance.network_interface.0.nat_ip_address])
}
output "load_balancer_ip_address" {
  value = join(", ", flatten(yandex_lb_network_load_balancer.lb.listener[*].external_address_spec[*].address))
}
