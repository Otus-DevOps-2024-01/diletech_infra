variable "cloud_id" {
  description = "Cloud"
}
variable "folder_id" {
  description = "Folder"
}
variable "zone" {
  description = "Zone"
  default     = "ru-central1-a"
}
variable "public_key_path" {
  description = "Path to the public key used for ssh access"
}
variable "subnet_id" {
  description = "Subnet"
}
variable "service_account_key_file" {
  description = "key .json"
}
variable "private_key_path" {
  description = "Path to the privete key used for ssh access"
}
variable "instance_count" {
  description = "Count create instance app"
  default     = 1
}
variable "app_disk_image" {
  description = "Disk image for reddit app"
  default     = "reddit-app-base"
}
variable "db_disk_image" {
  description = "Disk image for reddit db"
  default     = "reddit-db-base"
}
variable "vm_name_app" {
  default     = "reddit-db"
  description = "Name for the VM instance"
}
variable "vm_name_db" {
  default     = "reddit-db"
  description = "Name for the VM instance"
}


### BEGIN var S3 backet for remote backend
variable "bucket_name" {
  description = "Name of backet for tfstate"
}
variable "bucket_secret" {
  description = "Secret of backet for tfstate"
}
variable "bucket_key_id" {
  description = "Key id of backet for tfstate"
}
variable "bucket_key_name" {
  default     = "default-terraform.state"
  description = "Key name of backet for tfstate"
}
### END var S3 backet for remote backend
