data "aws_vpc" "default" {
  default = true
}

# security group allowing inbound traffic to the Caddy instance in ECS, in default VPC
resource "aws_security_group" "caddy_ecs" {
  name        = "caddy_ecs"
  description = "Allow inbound traffic to Caddy in ECS"
  vpc_id      = data.aws_vpc.default.id
}

resource "aws_vpc_security_group_ingress_rule" "caddy_ecs_allow_http" {
  security_group_id = aws_security_group.caddy_ecs.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
}

# to allow ECS to pull its own image and to write logs
# acceptable tradeoff to allow everywhere on all protocols and ports, because this is just a POC and will be torn down
# in real application, this should be scoped down as much as possible, we try to follow least-privilege principle
resource "aws_vpc_security_group_egress_rule" "caddy_ecs_allow_egress" {
  security_group_id = aws_security_group.caddy_ecs.id
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}