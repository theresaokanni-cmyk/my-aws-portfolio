[11/6, 3:21 PM] Tessy C.Okanni: <h2>We Protect Your Business Too</h2>
<p>We no just put you online. We lock your website, we backup your work, and we keep hackers away.</p>
<p>✅ Padlock Security (SSL)</p>
<p>✅ Backup - Your work no go loss</p>
<p>✅ Protection from hackers</p>
<p><b>Put Online + Protect = CloudLume Tech</b></p>
[11/6, 3:34 PM] Tessy C.Okanni: provider "aws" {
  region = "eu-west-1"
}

# 1. Get default VPC and subnets in 2 zones
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# 2. Security Group - Allow website traffic
resource "aws_security_group" "web_sg" {
  name        = "cloudlume-web-sg"
  description = "Allow HTTP traffic"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# 3. Launch Template - Your website on every server
resource "aws_launch_template" "web" {
  name_prefix   = "cloudlume-"
  image_id      = "ami-0c55b159cbfafe1f0"
  instance_type = "t2.micro"
  vpc_security_group_ids = [aws_security_group.web_sg.id]

  user_data = base64encode(<<-EOF
              #!/bin/bash
              yum update -y
              yum install -y httpd
              systemctl start httpd
              systemctl enable httpd
              echo "<h1>CloudLume Tech - Protected and Scalable</h1><p>We Put You Online + We Protect You</p>" > /var/www/html/index.html
              EOF
  )
}

# 4. Load Balancer - Shares traffic
resource "aws_lb" "web_lb" {
  name               = "cloudlume-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.web_sg.id]
  subnets            = data.aws_subnets.default.ids
}

resource "aws_lb_target_group" "web_tg" {
  name     = "cloudlume-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = data.aws_vpc.default.id
}

resource "aws_lb_listener" "web_listener" {
  load_balancer_arn = aws_lb.web_lb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web_tg.arn
  }
}

# 5. Auto Scaling - Handles traffic automatically
resource "aws_autoscaling_group" "web_asg" {
  desired_capacity    = 2
  max_size            = 4
  min_size            = 2
  vpc_zone_identifier = data.aws_subnets.default.ids
  target_group_arns   = [aws_lb_target_group.web_tg.arn]

  launch_template {
    id      = aws_launch_template.web.id
    version = "$Latest"
  }
}

# 6. CloudFront - Spreads your site to different locations
resource "aws_cloudfront_distribution" "web_cdn" {
  origin {
    domain_name = aws_lb.web_lb.dns_name
    origin_id   = "cloudlume-origin"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  enabled             = true
  default_root_object = "index.html"

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "cloudlume-origin"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}

output "load_balancer_url" {
  value = aws_lb.web_lb.dns_name
}

output "cloudfront_url" {
  value = aws_cloudfront_distribution.web_cdn.domain_name
}
