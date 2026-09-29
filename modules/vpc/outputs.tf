output "vpc_id" {
  description = "VPC ID."
  value       = aws_vpc.this.id
}

output "vpc_cidr_block" {
  description = "VPC CIDR block."
  value       = aws_vpc.this.cidr_block
}

output "public_subnet_ids" {
  description = "Public subnet IDs (one per AZ)."
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "Private subnet IDs (one per AZ)."
  value       = aws_subnet.private[*].id
}

output "private_route_table_ids" {
  description = "Private route table IDs."
  value       = aws_route_table.private[*].id
}

output "nat_gateway_public_ips" {
  description = "Public IPs of the NAT gateways (useful for allow-listing egress traffic)."
  value       = aws_eip.nat[*].public_ip
}

output "azs" {
  description = "Availability zones in use."
  value       = var.azs
}
