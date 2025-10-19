resource "aws_subnet" "this" {
    for_each = var.private_subnet_cidrs_map
    vpc_id     = var.vpc_id
    cidr_block = each.value

    tags = {
        Name = each.key
    }
}

resource "aws_route_table" "priv_subnet_rt" {
  vpc_id = var.vpc_id

  # since this is exactly the route AWS will create, the route will be adopted
  route {
    cidr_block = var.vpc_cidr_block
    gateway_id = "local"
  }
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.nat_gw01.id
  }
}

resource "aws_route_table_association" "this" {
    for_each = aws_subnet.this
    subnet_id      = each.value.id
    route_table_id = aws_route_table.priv_subnet_rt.id
}

resource "aws_eip" "nat_eip" {
  tags = {
    Name = "nat-eip"
  }
}

resource "aws_nat_gateway" "nat_gw01" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = var.nat_gateway_subnet_id

  tags = {
    Name = "nat-gw01"
  }
  # To ensure proper ordering, it is recommended to add an explicit dependency
  # on the Internet Gateway for the VPC.
  depends_on = [ aws_eip.nat_eip, aws_subnet.this ]
}
