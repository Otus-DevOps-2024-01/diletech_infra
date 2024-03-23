resource "yandex_vpc_network" "app-network" {
  name = var.vpc_name
}

resource "yandex_vpc_subnet" "app-subnet" {
  name           = var.subnet_name
  network_id     = yandex_vpc_network.app-network.id
  v4_cidr_blocks = var.subnet_cidr
}
