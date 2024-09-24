variable "cluster_name" {
  type = string
}

variable "cluster_security_group_id" {
  type = string
}

variable "encrypt_file_system" {
  default = true
  type    = bool
}

variable "private_subnets" {
  type = list(string)
}

variable "replication_protection" {
  default = false
  type    = bool
}

variable "vpc_id" {
  type = string
}
