data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

# ec2 resources

resource "aws_key_pair" "ec2_key" {
  key_name   = "ec2-key"
  public_key = "to be generated according to the user case < example ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQD3F6tyPEFEzV0LX3X8BsXdMsQz1x2cEikKDEY0aIj41qgxMCP/iteneqXSIFZBp5vizPvaoIR3Um9xK7PGoW8giupGn+EPuxIA4cDM4vzOqOkiMPhz5XK0whEjkVzTo4+S0puvDZuwIsdiW9mxhJc7tgBNL0cYlWSYVkz4G/fslNfRPW5mYAM49f4fhtxPb5ok4Q2Lg9dPKVHO/Bgeu5woMc7RY0p1ej6D4CKFE6lymSDJpW0YHX/wqE9+cfEauh7xZcG0q9t2ta6F6fmX0agvpFyZo8aFbXeUBr7osSCJNgvavWbM/06niWrOvYX2xwWdhXmXSrbX8ZbabVohBK41 email@example.com>"
}

resource "aws_instance" "ec2_1" {
    ami = data.aws_ami.ubuntu.id
    instance_type = "t3.micro"
    key_name = aws_key_pair.ec2_key.key_name
    subnet_id = "sub-1233123232132"
    security_groups = [aws_security_group.ec2_security_group]
    root_block_device {
        volume_size = 30
    }
    tags = {
      "Name"= "ec2_1"
    }
}

resource "aws_instance" "ec2_2" {
    ami = data.aws_ami.ubuntu.id
    instance_type = "t3.micro"
    key_name = aws_key_pair.ec2_key.key_name
    security_groups = [aws_security_group.ec2_security_group]
    subnet_id = "sub-1233123232132"
    root_block_device {
        volume_size = 30
    }
    tags = {
      "Name"= "ec2_2"
    }
}

#security group for ec2 instances

resource "aws_security_group" "ec2_security_group" {
  name        = "ec2_secrity_group"
  vpc_id      = "vpc-2342312321312"

}
resource "aws_vpc_security_group_ingress_rule" "ingress_ec2_security_group_rule" {
  security_group_id = aws_security_group.lb_security_group.id
  cidr_ipv4         = "10.0.0.0/24"
  from_port         = 80
  ip_protocol       = "tcp"
  to_port           = 80
}

resource "aws_vpc_security_group_egress_rule" "egress_rule_ec2_sg" {
  security_group_id = aws_security_group.lb_security_group.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

# We're putting ec2 instances under Target groups and attaching it to the load balancer

resource "aws_lb_target_group" "ec2_target_group" {
  name        = "ec2-tg"
  port        = 80
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = "vpc-2342312321312"
}

resource "aws_lb_target_group_attachment" "ec2_1_target_group_attachment" {
  target_group_arn = aws_lb_target_group.ec2_target_group.arn
  target_id        = aws_instance.ec2_1.id
  port             = 80
}

resource "aws_lb_target_group_attachment" "ec2_2_target_group_attachment" {
  target_group_arn = aws_lb_target_group.ec2_target_group.arn
  target_id        = aws_instance.ec2_2.id
  port             = 80
}

# load balancer resources

resource "aws_lb" "ec2_lb" {
    depends_on = [ aws_security_group.lb_security_group ]
    name               = "test-lb-tf"
    internal           = false
    load_balancer_type = "application"
    security_groups    = [aws_security_group.lb_security_group.id]
    subnets            = ["sub-1233123232132"]

    enable_deletion_protection = true
    tags = {
      Environment = "production"
    }
}

# load balancer security group

resource "aws_security_group" "lb_security_group" {
  name        = "lb_secrity_group"
  vpc_id      = "vpc-2342312321312"

  tags = {
    Name = "allow_tls"
  }
}

resource "aws_vpc_security_group_ingress_rule" "lb_security_group_rule" {
  security_group_id = aws_security_group.lb_security_group.id
  cidr_ipv4         = "10.0.0.0/24"
  from_port         = 443
  ip_protocol       = "tcp"
  to_port           = 80
}

resource "aws_vpc_security_group_egress_rule" "egress_rule_lb_sg" {
  security_group_id = aws_security_group.lb_security_group.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

resource "aws_lb_listener" "lb_listner_ec2" {
  load_balancer_arn = aws_lb.ec2_lb.arn
  port              = "80"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = "arn:aws:iam::187416307283:server-certificate/test_cert_rab3wuqwgja25ct3n4jdj2tzu4"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ec2_target_group.arn
  }
}
