variable mysql_db_pass {}

# Creating environment variable for Docker Containers
data "template_file" "ecs_task_template" {
  template = "${file("ecs-task-definition.json.tpl")}"

  vars {
    mysql_password     = "${var.mysql_db_pass}"
  }
}

# Creating ECS cluster
resource "aws_ecs_cluster" "wordpress-ecs" {
  name = "wordpress"
}

# Creating ECS Task Definition
resource "aws_ecs_task_definition" "wp-ecs-def" {
  family                = "wordpress-ecs"
  container_definitions = "${data.template_file.ecs_task_template.rendered}"
}

# Creating IAM roles for ECS Service
resource "aws_iam_role" "ecs_service" {
  name = "wp-ecs-service-role"

  assume_role_policy = <<EOF
{
  "Version": "2008-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Service": "ecs.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}

EOF
}

# Creating IAM Policy for ECS Service
resource "aws_iam_role_policy" "ecs_service" {
  name = "ecs-role-policy"
  role = "${aws_iam_role.ecs_service.name}"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "elasticloadbalancing:*",
        "ec2:*",
        "ecs:*"
      ],
      "Resource": [
        "*"
      ]
    }
  ]
}
EOF
}

# Creating Front-end ELB
resource "aws_elb" "ecs-elb" {
  name            = "wp-ecs-elb"
  security_groups = ["${aws_security_group.web.id}"]

  listener {
    instance_port     = 80
    instance_protocol = "http"
    lb_port           = 80
    lb_protocol       = "http"
  }

  instances = ["${aws_instance.ecs.id}"]
}

# Creating ECS Service
resource "aws_ecs_service" "wp-ecs" {
  name            = "wp-ecs-service"
  cluster         = "${aws_ecs_cluster.wordpress-ecs.id}"
  task_definition = "${aws_ecs_task_definition.wp-ecs-def.arn}"
  desired_count   = 1
  iam_role        = "${aws_iam_role.ecs_service.name}"
  depends_on      = ["aws_iam_role_policy.ecs_service", "aws_ecs_task_definition.wp-ecs-def"]

  load_balancer {
    elb_name       = "${aws_elb.ecs-elb.id}"
    container_name = "wordpress"
    container_port = "80"
  }
}

# Creating ECS Optimized EC2 instance to run containers 
resource "aws_instance" "ecs" {
  ami                    = "ami-05991b6a"
  instance_type          = "t2.micro"
  vpc_security_group_ids = ["${aws_security_group.web.id}"]
  iam_instance_profile   = "${aws_iam_instance_profile.ecs.name}"

  tags {
    Name        = "WP-ECS Instance"
  }

  user_data = <<USER_DATA
#!/bin/bash
echo ECS_CLUSTER=${aws_ecs_cluster.wordpress-ecs.name} >> /etc/ecs/ecs.config
USER_DATA
}

# Creating IAM Role for EC2 instance profile
resource "aws_iam_role" "ecs_instance" {
  name = "ecs-instance-role"
  path = "/"

  assume_role_policy = <<EOF
{
  "Version": "2008-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}

EOF
}

# Creating EC2 instance profile with ECS IAM role
resource "aws_iam_instance_profile" "ecs" {
  name = "ecs-instance-profile"
  role = "${aws_iam_role.ecs_instance.name}"
}

# Creating IAM Policy for EC2 instance with access to ECS and ECR
resource "aws_iam_role_policy" "ecs_instance" {
  name = ".ecs-instance-role-policy"
  role = "${aws_iam_role.ecs_instance.name}"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ecr:BatchCheckLayerAvailability",
        "ecr:BatchGetImage",
        "ecr:GetDownloadUrlForLayer",
        "ecr:GetAuthorizationToken",
        "ecs:CreateCluster",
        "ecs:DeregisterContainerInstance",
        "ecs:DiscoverPollEndpoint",
        "ecs:Poll",
        "ecs:RegisterContainerInstance",
        "ecs:Submit*"
      ],
      "Resource": [
        "*"
      ]
    }
  ]
}
EOF
}
