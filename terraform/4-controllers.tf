############################
# K8s Control Pane instances
############################

resource "aws_instance" "controller" {
  count         = var.number_of_controller
  ami           = lookup(var.amis, var.region)
  instance_type = var.controller_instance_type

  iam_instance_profile = aws_iam_instance_profile.ec2_kubernetes.id

  subnet_id                   = aws_subnet.ec2_kubernetes.id
  private_ip                  = cidrhost(var.vpc_cidr, 20 + count.index)
  associate_public_ip_address = true  # Instances have public, dynamic IP
  source_dest_check           = false # TODO Required??

  availability_zone      = var.zone
  vpc_security_group_ids = ["${aws_security_group.ec2_kubernetes.id}"]
  key_name               = var.default_keypair_name
  tags = merge(
    local.common_tags,
    {
      "Owner"           = "${var.owner}"
      "Name"            = "controller-${count.index}"
      "ansibleFilter"   = "${var.ansibleFilter}"
      "ansibleNodeType" = "controller"
      "ansibleNodeName" = "controller.${count.index}"
    }
  )
}

resource "aws_instance" "controller_etcd" {
  count         = var.number_of_controller_etcd
  ami           = lookup(var.amis, var.region)
  instance_type = var.controller_instance_type

  iam_instance_profile = aws_iam_instance_profile.ec2_kubernetes.id

  subnet_id                   = aws_subnet.ec2_kubernetes.id
  private_ip                  = cidrhost(var.vpc_cidr, 40 + count.index)
  associate_public_ip_address = true  # Instances have public, dynamic IP
  source_dest_check           = false # TODO Required??

  availability_zone      = var.zone
  vpc_security_group_ids = ["${aws_security_group.ec2_kubernetes.id}"]
  key_name               = var.default_keypair_name

  tags = merge(
    local.common_tags,
    {
      "Owner"           = "${var.owner}",
      "Name"            = "controller-etcd-${count.index}",
      "ansibleFilter"   = "${var.ansibleFilter}",
      "ansibleNodeType" = "controller.etcd",
      "ansibleNodeName" = "controller.etcd.${count.index}"
    }
  )
}

###############################
## Kubernetes API Load Balancer
###############################

resource "aws_elb" "ec2_kubernetes_api" {
  name                      = var.elb_name
  instances                 = aws_instance.controller[*].id
  subnets                   = ["${aws_subnet.ec2_kubernetes.id}"]
  cross_zone_load_balancing = false

  security_groups = ["${aws_security_group.ec2_kubernetes_api.id}"]

  listener {
    lb_port           = 6443
    instance_port     = 6443
    lb_protocol       = "TCP"
    instance_protocol = "TCP"
  }

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 15
    target              = "HTTPS:6443/"
    interval            = 30
  }

  tags = merge(
    local.common_tags,
    {
      "Name"  = "kubernetes",
      "Owner" = "${var.owner}"
    }
  )
}

############
## Security
############

resource "aws_security_group" "ec2_kubernetes_api" {
  vpc_id = aws_vpc.ec2_kubernetes.id
  name   = "kubernetes-api"

  # Allow inbound traffic to the port used by Kubernetes API HTTPS
  ingress {
    from_port   = 6443
    to_port     = 6443
    protocol    = "TCP"
    cidr_blocks = ["${var.control_cidr}"]
  }

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    local.common_tags,
    {
      "Name"  = "kubernetes-api",
      "Owner" = "${var.owner}"
    }
  )
}

############
## Outputs
############

output "kubernetes_api_dns_name" {
  value = aws_elb.ec2_kubernetes_api.dns_name
}
