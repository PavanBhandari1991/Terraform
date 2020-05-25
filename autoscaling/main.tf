# Define your Provider which in this case : AWS 
# Profile Defines the "aws_access_key_id" and "aws_secret_access_key" 
provider "aws" {
    profile = "default"
    region  = "us-east-1"
}

#Using Default VPC to Manage Subnets in which the EC2 Instances will be deployed 
resource "aws_default_vpc" "default" {}


#Defining 2 Subnets out of 6 in the Default Region
resource "aws_default_subnet" "default_az1" {
  availability_zone = "us-east-1a"

  tags = {
    Name = "Terraform"
  }

}
resource "aws_default_subnet" "default_az2" {
  availability_zone = "us-east-1b"

  tags = {
    Name = "Terraform"
  } 
}


#Defining Security Group to Allow 80,443,22,6379(Redis) Ports 
resource "aws_security_group" "web" {
    name        = "my-prod-web"
    description = "Allow Standard HTTP and HTTPS Inbound and Everything OutBound"
    ingress {
        from_port   = 80
        to_port     = 80
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
  
    ingress {
        from_port   = 443
        to_port     = 443
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    ingress {
        from_port   = 6379
        to_port     = 6379
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    ingress {
        from_port   = 22
        to_port     = 22
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    egress {
        from_port   = 22
        to_port     = 22
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    egress {
        from_port   = 0
        to_port     = 0
        protocol    = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }

    egress {
        from_port   = 6379
        to_port     = 6379
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
    tags = {
    Name = "Terraform"
  }
}

#Define a Public Key from your Local to SSH to the Instances that are created as part of this template
# resource "aws_key_pair" "mykey" {
#   key_name   = "mykey"
#   public_key = ""
# }


#Defining a Load Balancer and Span upto the 2 Subnets defined in the previous resource template. 
resource "aws_elb" "web" {
  name            = "web"
  subnets         = ["${aws_default_subnet.default_az1.id}", "${aws_default_subnet.default_az2.id}"]
  security_groups = ["${aws_security_group.web.id}"]

  listener {
    instance_port     = 80
    instance_protocol = "http"
    lb_port           = 80
    lb_protocol       = "http"
  } 

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 3
    interval            = 30
    target              = "HTTP:80/"
  }

  tags = {
    Name = "Terraform"
  }
}

#Defining a Launch Template for the Autoscaling Group
resource "aws_launch_template" "web" {
  name_prefix            = "web"
  image_id               = "ami-0150abdb3abab0d28"
  instance_type          = "t2.micro"
  vpc_security_group_ids = ["${aws_security_group.web.id}"]
  #If "aws_key_pair" is enabled, uncomment the below line    
  #key_name = “${aws_key_pair.mykey.key_name}”
  
  tags = {
    Name = "Terraform"
  }

}

#Define a Autoscaling Group 
resource "aws_autoscaling_group" "web" {
  availability_zones        = ["us-east-1a", "us-east-1b"]
  vpc_zone_identifier       = ["${aws_default_subnet.default_az1.id}", "${aws_default_subnet.default_az2.id}"]
  desired_capacity          = 2
  max_size                  = 20
  min_size                  = 1
  health_check_grace_period = 300 
  health_check_type         = "EC2"

#Using the Launch Template 
  launch_template {
    id      = "${aws_launch_template.web.id}"
    version = "$Latest"
  }

  tag {
    key = "Name" 
    value = "Terraform"
    propagate_at_launch = true

  }
}

#Define an Autoscaling Policy to Scale In/Out 
resource "aws_autoscaling_policy" "web_out" {
  name                   = "terraform-autopolicy-up"
  scaling_adjustment     = 1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = "${aws_autoscaling_group.web.name}"
}

#Define a Metric : If Average CPU of Autoscaling Group is above Threshold, it will trigger the defined autoscaling Policy 
resource  "aws_cloudwatch_metric_alarm" "cpualarm-up" {
  
  alarm_name                = "terraform-cpu-alarm-up"
  comparison_operator       = "GreaterThanOrEqualToThreshold"
  evaluation_periods        = "2"
  metric_name               = "CPUUtilization"
  namespace                 = "AWS/EC2"
  period                    = "120"
  statistic                 = "Average"
  threshold                 = "60"
  
  dimensions = {
    AutoScalingGroupName = "${aws_autoscaling_group.web.name}"
  }

  alarm_description = "This metric monitor EC2 instance cpu utilization"
  alarm_actions     = ["${aws_autoscaling_policy.web_out.arn}"]
}


resource "aws_autoscaling_policy" "web_in" {
  name                   = "terraform-autopolicy-down"
  scaling_adjustment     = -1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = "${aws_autoscaling_group.web.name}"
}


resource  "aws_cloudwatch_metric_alarm" "cpualarm-down" {
  
  alarm_name                = "terraform-cpu-alarm-down"
  comparison_operator       = "LessThanOrEqualToThreshold"
  evaluation_periods        = "2"
  metric_name               = "CPUUtilization"
  namespace                 = "AWS/EC2"
  period                    = "120"
  statistic                 = "Average"
  threshold                 = "30"
  
  dimensions = {
    AutoScalingGroupName = "${aws_autoscaling_group.web.name}"
  }

  alarm_description = "This metric monitor EC2 instance cpu utilization"
  alarm_actions     = ["${aws_autoscaling_policy.web_in.arn}"]
}

#Attach ELB & Autoscaling group
resource "aws_autoscaling_attachment" "web" {
  autoscaling_group_name = "${aws_autoscaling_group.web.id}"
  elb                    = "${aws_elb.web.id}"
}

#Defining a Single ElastiCache Redis Instance Running on Port 6379
resource "aws_elasticache_cluster" "web_redis" {
  cluster_id           = "web-redis"
  engine               = "redis"
  node_type            = "cache.t2.micro"
  num_cache_nodes      = 1
  parameter_group_name = "default.redis3.2"
  engine_version       = "3.2.10"
  port                 = 6379
  security_group_ids   = ["${aws_security_group.web.id}"]
}