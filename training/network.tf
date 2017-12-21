variable "vpc_cidr_block" {}

#Create a VPC with Terraform
resource "aws_vpc" "custom_vpc" {
 cidr_block = "${var.vpc_cidr_block}"

 tags {
    Name = "Terraform Custom VPC"
    }
}
