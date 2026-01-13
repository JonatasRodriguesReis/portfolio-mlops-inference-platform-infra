resource "aws_vpc" "eks_vpc" {
  cidr_block           = var.cidr_block
  #the dns support already comes as true by default
  # good practice is to explicitly define it
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-vpc"
    }
  )
}