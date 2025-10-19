variable "vpc_id" {
  type = string
  description = "vpc id of default vpc"
}

variable "vpc_cidr_block" {
  type = string
  description = "vpc cidr"
}


variable "private_subnet_cidrs_map" {
  type = map(string)
  default = {
    "priv-subnet-a" = "172.31.96.0/20"
    "priv-subnet-b" = "172.31.112.0/20"
  }
}


variable "nat_gateway_subnet_id" {
  type        = string
  description = "Subnet ID for NAT gateway"
}
