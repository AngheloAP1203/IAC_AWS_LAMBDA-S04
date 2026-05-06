# --- ELASTIC IPs PARA NAT ---
resource "aws_eip" "nat_a" {
  domain = "vpc"
  tags   = { Name = "eip-nat-a-${var.environment}" }
}

resource "aws_eip" "nat_b" {
  domain = "vpc"
  tags   = { Name = "eip-nat-b-${var.environment}" }
}

# --- NAT GATEWAYS ---
resource "aws_nat_gateway" "nat_a" {
  allocation_id = aws_eip.nat_a.id
  subnet_id     = aws_subnet.public_a.id
  tags          = { Name = "nat-a-${var.environment}" }
  depends_on    = [aws_internet_gateway.main]
}

resource "aws_nat_gateway" "nat_b" {
  allocation_id = aws_eip.nat_b.id
  subnet_id     = aws_subnet.public_b.id
  tags          = { Name = "nat-b-${var.environment}" }
  depends_on    = [aws_internet_gateway.main]
}
