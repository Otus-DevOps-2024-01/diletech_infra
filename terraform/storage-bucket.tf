resource "yandex_storage_bucket" "tfstate" {
  bucket        = var.bucket_name
  access_key    = var.bucket_key_id
  secret_key    = var.bucket_secret
  force_destroy = "true"
}
