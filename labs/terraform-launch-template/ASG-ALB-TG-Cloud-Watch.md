Step 1 — Build our own VPC

Your current data.tf is selecting the default VPC, so we're going to stop doing that.

1. Create network.tf

Run:

nano network.tf

Put this in:

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "terraform-web-vpc"
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "terraform-web-igw"
  }
}

resource "aws_subnet" "public" {
  count = length(var.public_subnet_cidrs)

  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "terraform-public-${var.availability_zones[count.index]}"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "terraform-public-rt"
  }
}

resource "aws_route_table_association" "public" {
  count = length(aws_subnet.public)

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

Save:

Ctrl+O → Enter → Ctrl+X

Step 2 — Add network variables

Open:

nano variables.tf

Keep your existing variables and add:

variable "vpc_cidr" {
  description = "CIDR block for the Terraform VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "Availability zones for public subnets"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

So our network becomes:

VPC
10.0.0.0/16
│
├── us-east-1a
│   └── 10.0.1.0/24
│
└── us-east-1b
    └── 10.0.2.0/24

This is much cleaner than using the AWS default 172.31.0.0/16.

Step 3 — Remove the default-VPC data source

Your current data.tf contains:

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

We don't need this anymore.

You can simply remove the contents of data.tf, or remove the file:

rm data.tf

Don't worry—we aren't deleting AWS infrastructure here. We're only deleting the Terraform data-source configuration.

Step 4 — Change the ASG subnet reference

Your current asg.tf has:

vpc_zone_identifier = data.aws_subnets.default.ids

Change it to:

vpc_zone_identifier = aws_subnet.public[*].id

So that part becomes:

resource "aws_autoscaling_group" "web" {
  name             = "terraform-web-asg"
  min_size         = 1
  desired_capacity = 1
  max_size         = 3

  vpc_zone_identifier = aws_subnet.public[*].id

  launch_template {
    id      = aws_launch_template.web.id
    version = aws_launch_template.web.latest_version
  }

  tag {
    key                 = "Name"
    value               = "terraform-asg-web"
    propagate_at_launch = true
  }
}

This is an important Terraform dependency:

aws_subnet.public
       ↓
aws_autoscaling_group.web

Terraform automatically understands that the subnets must exist before the ASG can use them.

Step 5 — Format and validate

Now run:

terraform fmt

Then:

terraform validate

We want:

Success! The configuration is valid.

Then:

terraform plan
Stop here.

Don't apply yet.

Send me the terraform plan output.

We'll inspect that first and make sure Terraform sees:

+ aws_vpc.main
+ aws_internet_gateway.main
+ aws_subnet.public[0]
+ aws_subnet.public[1]
+ aws_route_table.public
+ aws_route_table_association.public[0]
+ aws_route_table_association.public[1]
+ aws_launch_template.web
+ aws_autoscaling_group.web
+ aws_autoscaling_policy.cpu_target

Once that is clean, we'll move to Step 2: Security Groups + ALB + Target Group + Listener, all managed by Terraform.

========================================================

The right approach for this module

I recommend we do not put a VPC ID in terraform.tfvars.

Instead, let's make this lab properly Terraform-managed:

Terraform
│
├── VPC
│   ├── Internet Gateway
│   ├── Public Subnet AZ-a
│   ├── Public Subnet AZ-b
│   └── Route Table
│
├── Security Groups
│   ├── ALB SG
│   └── Web/EC2 SG
│
├── Launch Template
│
├── Auto Scaling Group
│   └── CPU Target Tracking
│
├── Application Load Balancer
│   ├── Target Group
│   └── Listener :80
│
└── CloudWatch
    ├── CPU Alarm
    └── ALB/ASG monitoring

This is much better than manually creating the ALB/TG and then connecting them.

And importantly, VPC/subnets won't need to be manually created either.

Step 1 — Change data.tf

Your current data.tf discovers the default VPC:

data "aws_vpc" "default" {
  default = true
}

We don't want that anymore.

Replace data.tf with:

# No data sources needed.
# VPC and subnets are managed by Terraform.

Or simply leave data.tf empty for now.

Step 3 — Create security groups

Create:

nano security_groups.tf

Use:

resource "aws_security_group" "alb" {
  name        = "terraform-web-alb-sg"
  description = "Allow HTTP traffic to ALB"
  vpc_id      = aws_vpc.web.id

  ingress {
    description = "HTTP from Internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "terraform-web-alb-sg"
  }
}

resource "aws_security_group" "web" {
  name        = "terraform-web-sg"
  description = "Allow HTTP traffic from ALB"
  vpc_id      = aws_vpc.web.id

============================

Exactly — we found the leftover reference from the vpc.tf version we removed.

Your actual VPC resource is:

resource "aws_vpc" "main"

but security_groups.tf still says:

vpc_id = aws_vpc.web.id

There is no aws_vpc.web anymore, so Terraform correctly reports:

Reference to undeclared resource aws_vpc.web

Fix security_groups.tf

Run:

sed -i 's/aws_vpc\.web\.id/aws_vpc.main.id/g' security_groups.tf

Then verify:

cat security_groups.tf

You should see both:

vpc_id = aws_vpc.main.id

So the two resources become:

resource "aws_security_group" "alb" {
  name        = "terraform-web-alb-sg"
  description = "Allow HTTP traffic to ALB"
  vpc_id      = aws_vpc.main.id

and:

resource "aws_security_group" "web" {
  name        = "terraform-web-sg"
  description = "Allow HTTP traffic from ALB"
  vpc_id      = aws_vpc.main.id
Then validate
terraform fmt
terraform validate

Don't apply yet.

If validation succeeds, our next step is to create alb.tf containing all three pieces together:

ALB
 │
 ├── Listener :80
 │
 └── Target Group :80
        │
        └── ASG

And we'll connect the ASG to the target group with Terraform, so no manual ALB/TG creation is needed.

After that we'll add CloudWatch and do one final terraform plan before applying the complete module.

==================================

Yes — now we have identified the next leftover reference from the old VPC design.

Your networking is now based on:

aws_vpc.main
aws_subnet.public[count.index]
aws_route_table.public

But asg.tf is still referring to the old hard-coded subnet resources:

aws_subnet.public_a
aws_subnet.public_b

Those no longer exist.

1. Fix asg.tf

Open it:

nano asg.tf

Change the vpc_zone_identifier section to:

vpc_zone_identifier = aws_subnet.public[*].id

So your complete asg.tf should be:

resource "aws_autoscaling_group" "web" {
  name             = "terraform-web-asg"
  min_size         = 1
  desired_capacity = 1
  max_size         = 3

  vpc_zone_identifier = aws_subnet.public[*].id

  launch_template {
    id      = aws_launch_template.web.id
    version = aws_launch_template.web.latest_version
  }

  tag {
    key                 = "Name"
    value               = "terraform-asg-web"
    propagate_at_launch = true
  }
}
2. Also fix the Launch Template security group

This is important because your EC2 instances need to use the web security group, which allows HTTP only from the ALB.

Your current main.tf doesn't attach any security group.

Add this inside aws_launch_template.web:

vpc_security_group_ids = [aws_security_group.web.id]

So:

resource "aws_launch_template" "web" {
  name_prefix   = "terraform-web-"
  image_id      = var.ami_id
  instance_type = var.instance_type
  key_name      = var.key_name

  vpc_security_group_ids = [aws_security_group.web.id]

  tag_specifications {
    resource_type = "instance"

    tags = {
      Name = "terraform-launch-template"
    }
  }
}

This gives us the intended traffic path:

Internet
   |
   | HTTP :80
   v
ALB
[terraform-web-alb-sg]
   |
   | HTTP :80
   v
EC2
[terraform-web-sg]

And the EC2 SG rule:

ALB SG  --->  EC2 :80

is already correctly configured in your security_groups.tf.

3. Format + validate

Run:

terraform fmt

then:

terraform validate

We want:

Success! The configuration is valid.
4. One important point about your VPC design

You asked yesterday whether Terraform can automatically select a VPC rather than putting a VPC name into terraform.tfvars.

Yes, but there are two different approaches.

For this lab, we're doing the better learning approach:

Terraform creates the VPC
        ↓
Terraform creates subnets
        ↓
Terraform creates route table
        ↓
Terraform creates security groups
        ↓
Terraform creates ALB
        ↓
Terraform creates Target Group
        ↓
Terraform connects Target Group → ASG
        ↓
ASG launches EC2

Therefore we don't need a VPC ID in terraform.tfvars at all.

Terraform knows the VPC because we reference:

aws_vpc.main.id

and the subnets because:

aws_subnet.public[*].id

That's much cleaner than manually supplying:

vpc_id = "vpc-xxxxx"

for this particular lab.

5. Then we'll build the ALB completely in Terraform

After terraform validate succeeds, don't apply yet.

Our next files will be approximately:

terraform-launch-template/
│
├── provider.tf
├── variables.tf
├── terraform.tfvars
│
├── vpc.tf / network.tf
├── security_groups.tf
│
├── main.tf
├── asg.tf
├── scaling.tf
│
├── alb.tf              ← next
└── cloudwatch.tf       ← final part

alb.tf will create automatically:

ALB
 ├── ALB Security Group
 ├── Listener :80
 └── Target Group
          |
          v
       ASG
          |
      EC2 instances

And we will attach the target group to the ASG with Terraform:

target_group_arns = [aws_lb_target_group.web.arn]

So no manual ALB creation, no manual target registration.

Finally we'll add CloudWatch, then this module is complete.

For now, just make the two changes above and run:

terraform fmt
terraform validate

==================================

Your current plan shows 12 resources, all expected:

VPC
Internet Gateway
2 public subnets
Public route table
2 route-table associations
ALB security group
Web/EC2 security group
Launch Template
ASG
CPU target-tracking policy

The plan confirms the new VPC is 10.0.0.0/16, with subnets 10.0.1.0/24 and 10.0.2.0/24.

Also, your Launch Template is now correctly getting a security-group ID dynamically rather than hard-coding it.

But don't apply yet

There is one thing missing: ALB + Target Group + Listener.

Your plan currently has:

VPC
 │
 ├── Public Subnet A
 ├── Public Subnet B
 │
 ├── Security Groups
 │
 ├── Launch Template
 │       ↓
 │      ASG
 │       ↓
 │      EC2
 │
 └── Internet Gateway

We want the final architecture to be:

                    Internet
                       │
                       │ HTTP :80
                       ▼
              ┌─────────────────┐
              │       ALB       │
              │ terraform-web   │
              └────────┬────────┘
                       │
                       │ Target Group
                       ▼
              ┌─────────────────┐
              │       ASG       │
              │ min=1 max=3     │
              └────────┬────────┘
                       │
                ┌──────┴──────┐
                ▼             ▼
              EC2-1         EC2-2

And Terraform will create and connect everything automatically.

Step 1 — Create alb.tf

Run:

nano alb.tf

Put this in it:

resource "aws_lb" "web" {
  name               = "terraform-web-alb"
  internal           = false
  load_balancer_type = "application"

  security_groups = [aws_security_group.alb.id]
  subnets         = aws_subnet.public[*].id

  tags = {
    Name = "terraform-web-alb"
  }
}

resource "aws_lb_target_group" "web" {
  name     = "terraform-web-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  health_check {
    enabled             = true
    path                = "/"
    protocol            = "HTTP"
    port                = "traffic-port"
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 30
  }

  tags = {
    Name = "terraform-web-tg"
  }
}

resource "aws_lb_listener" "web" {
  load_balancer_arn = aws_lb.web.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web.arn
  }
}
Step 2 — Attach Target Group to ASG

Now modify asg.tf.

Add:

target_group_arns = [aws_lb_target_group.web.arn]

So the ASG becomes:

resource "aws_autoscaling_group" "web" {
  name             = "terraform-web-asg"
  min_size         = 1
  desired_capacity = 1
  max_size         = 3

  vpc_zone_identifier = aws_subnet.public[*].id

  target_group_arns = [aws_lb_target_group.web.arn]

  launch_template {
    id      = aws_launch_template.web.id
    version = aws_launch_template.web.latest_version
  }

  tag {
    key                 = "Name"
    value               = "terraform-asg-web"
    propagate_at_launch = true
  }
}

This is the key piece.

Terraform will understand:

ALB Target Group
       │
       ▼
      ASG
       │
       ▼
EC2 instances

You will not manually register EC2 instances with the Target Group.

When ASG creates another EC2 during scale-out, AWS automatically registers it with the Target Group.

When ASG scales in, the instance is removed from the Target Group.

That's exactly the architecture we wanted to learn.

Step 3 — Format and validate
terraform fmt

then:

terraform validate

Then:

terraform plan

Don't run terraform apply yet.

This time the plan should additionally show:

aws_lb.web
aws_lb_target_group.web
aws_lb_listener.web

and the ASG should show:

target_group_arns = ...

So we're aiming for roughly:

12 existing resources
+
3 ALB resources
=
15 resources

After that we'll review the plan once, apply it, verify:

VPC
 ├── ALB
 ├── Target Group
 ├── Listener
 └── ASG
      └── EC2

Then we'll finish the module with CloudWatch monitoring.

  ingress {
    description     = "HTTP from ALB"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "terraform-web-sg"
  }
}

Notice this fixes something we discovered yesterday.

Previously we had:

ALB SG
   ↓
EC2 SG

but the Launch Template didn't explicitly specify the EC2 SG.

We'll fix that next.

Step 4 — Update main.tf

Your current Launch Template needs:

network_interfaces {
  security_groups = [aws_security_group.web.id]
}

So change main.tf to:

resource "aws_launch_template" "web" {
  name_prefix   = "terraform-web-"
  image_id      = var.ami_id
  instance_type = var.instance_type
  key_name      = var.key_name

  network_interfaces {
    security_groups = [aws_security_group.web.id]
  }

  tag_specifications {
    resource_type = "instance"

    tags = {
      Name = "terraform-launch-template"
    }
  }
}

Now every EC2 launched by the ASG gets the correct security group.

Step 5 — Update asg.tf

Remove:

vpc_zone_identifier = data.aws_subnets.default.ids

and use:

vpc_zone_identifier = [
  aws_subnet.public_a.id,
  aws_subnet.public_b.id
]

So the complete ASG becomes:

resource "aws_autoscaling_group" "web" {
  name             = "terraform-web-asg"
  min_size         = 1
  desired_capacity = 1
  max_size         = 3

  vpc_zone_identifier = [
    aws_subnet.public_a.id,
    aws_subnet.public_b.id
  ]

  health_check_type         = "ELB"
  health_check_grace_period = 300

  launch_template {
    id      = aws_launch_template.web.id
    version = aws_launch_template.web.latest_version
  }

  tag {
    key                 = "Name"
    value               = "terraform-asg-web"
    propagate_at_launch = true
  }
}

We'll later attach the target group to this ASG.

Important: don't apply yet

We're building this incrementally so you understand the architecture rather than just throwing a huge Terraform configuration at AWS.

Our next pieces are:

vpc.tf                 ✅
security_groups.tf     ✅
main.tf                ✅ updated
asg.tf                 ✅ updated
scaling.tf             ✅ already done

alb.tf                 ⏭️ next
cloudwatch.tf          ⏭️ after ALB
outputs.tf              ⏭️ final

Then we'll run:

terraform fmt
terraform validate
terraform plan

and inspect the plan before creating anything.

One important design decision

You asked yesterday whether Terraform can automatically select a VPC.

Yes, using a data "aws_vpc" lookup is possible, for example by tags. But for this lab, since we currently have no dedicated non-default VPC, creating the VPC in Terraform is the better engineering design.

================================================

Perfect — now the issue is completely clear. Do not keep both vpc.tf and network.tf.

Your existing network.tf is actually the better design for this lab because it is parameterized with variables:

var.vpc_cidr
var.public_subnet_cidrs
var.availability_zones

That means we can reuse the module without hard-coding the VPC/subnets.

1. Keep network.tf

Your existing structure is good:

network.tf
├── aws_vpc.main
├── aws_internet_gateway.main
├── aws_subnet.public[count]
├── aws_route_table.public
└── aws_route_table_association.public[count]

So delete the new vpc.tf that we just created:

rm vpc.tf

Then:

terraform fmt
terraform validate

The duplicate route-table error should disappear.

2. Important: our previous asg.tf references need correction

I previously told you to use:

aws_subnet.public_a.id
aws_subnet.public_b.id

But those resources don't exist in your existing design.

Your network.tf creates:

aws_subnet.public

with count.

Therefore your ASG should use:

vpc_zone_identifier = aws_subnet.public[*].id
Change asg.tf to:
resource "aws_autoscaling_group" "web" {
  name             = "terraform-web-asg"
  min_size         = 1
  desired_capacity = 1
  max_size         = 3

  vpc_zone_identifier = aws_subnet.public[*].id

  health_check_type         = "ELB"
  health_check_grace_period = 300

  launch_template {
    id      = aws_launch_template.web.id
    version = aws_launch_template.web.latest_version
  }

  tag {
    key                 = "Name"
    value               = "terraform-asg-web"
    propagate_at_launch = true
  }
}

This is actually a useful Terraform concept:

aws_subnet.public[*].id

means:

Give me the IDs of all instances of the aws_subnet.public resource.

So if variables define 2 subnets:

aws_subnet.public[0] → us-east-1a
aws_subnet.public[1] → us-east-1b

the ASG automatically gets both.

3. We also need to fix security_groups.tf

The security group configuration I gave you earlier used:

vpc_id = aws_vpc.web.id

But your actual VPC resource is:

aws_vpc.main

Therefore use:

vpc_id = aws_vpc.main.id

for both security groups.

So:

resource "aws_security_group" "alb" {
  name        = "terraform-web-alb-sg"
  description = "Allow HTTP traffic to ALB"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTP from Internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "terraform-web-alb-sg"
  }
}

resource "aws_security_group" "web" {
  name        = "terraform-web-sg"
  description = "Allow HTTP traffic from ALB"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "HTTP from ALB"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "terraform-web-sg"
  }
}
4. main.tf also needs the correct SG relationship

Your Launch Template should be:

resource "aws_launch_template" "web" {
  name_prefix   = "terraform-web-"
  image_id      = var.ami_id
  instance_type = var.instance_type
  key_name      = var.key_name

  network_interfaces {
    security_groups = [aws_security_group.web.id]
  }

  tag_specifications {
    resource_type = "instance"

    tags = {
      Name = "terraform-launch-template"
    }
  }
}

So now the dependency chain is correct:

aws_vpc.main
     │
     ├── aws_subnet.public[*]
     │
     ├── aws_security_group.alb
     │
     └── aws_security_group.web
                  │
                  ↓
          aws_launch_template.web
                  │
                  ↓
          aws_autoscaling_group.web
5. And your variables are the key to making this reusable

Your terraform.tfvars should eventually contain something like:

ami_id        = "ami-0db1c5c6dc64eb019"
instance_type = "t3.micro"
key_name      = "my-key1"

vpc_cidr = "10.0.0.0/16"

public_subnet_cidrs = [
  "10.0.1.0/24",
  "10.0.2.0/24"
]

availability_zones = [
  "us-east-1a",
  "us-east-1b"
]

This is much cleaner than giving Terraform a pre-existing VPC ID.

The module becomes:

terraform.tfvars
       │
       ├── VPC CIDR
       ├── subnet CIDRs
       └── AZs
              │
              ↓
        network.tf
              │
              ↓
        VPC + Subnets
              │
       ┌──────┴──────┐
       ↓             ↓
      ALB           ASG
       │             │
       ↓             ↓
 Target Group   Launch Template
                     │
                     ↓
                    EC2

And later, when we build alb.tf, we'll reference:

aws_vpc.main.id
aws_subnet.public[*].id
aws_security_group.alb.id

rather than manually entering AWS IDs.

So our immediate action

Run:

rm vpc.tf
terraform fmt
terraform validate

Don't run terraform apply yet.

Paste the output of:

terraform validate

Then we'll verify the network + ASG pieces before creating the ALB/TG configuration.

==========================================

Exactly — we found the leftover reference from the vpc.tf version we removed.

Your actual VPC resource is:

resource "aws_vpc" "main"

but security_groups.tf still says:

vpc_id = aws_vpc.web.id

There is no aws_vpc.web anymore, so Terraform correctly reports:

Reference to undeclared resource aws_vpc.web

Fix security_groups.tf

Run:

sed -i 's/aws_vpc\.web\.id/aws_vpc.main.id/g' security_groups.tf

Then verify:

cat security_groups.tf

You should see both:

vpc_id = aws_vpc.main.id

So the two resources become:

resource "aws_security_group" "alb" {
  name        = "terraform-web-alb-sg"
  description = "Allow HTTP traffic to ALB"
  vpc_id      = aws_vpc.main.id

and:

resource "aws_security_group" "web" {
  name        = "terraform-web-sg"
  description = "Allow HTTP traffic from ALB"
  vpc_id      = aws_vpc.main.id
Then validate
terraform fmt
terraform validate

Don't apply yet.

If validation succeeds, our next step is to create alb.tf containing all three pieces together:

ALB
 │
 ├── Listener :80
 │
 └── Target Group :80
        │
        └── ASG

And we'll connect the ASG to the target group with Terraform, so no manual ALB/TG creation is needed.

Yes — now we have identified the next leftover reference from the old VPC design.

Your networking is now based on:

aws_vpc.main
aws_subnet.public[count.index]
aws_route_table.public

But asg.tf is still referring to the old hard-coded subnet resources:

aws_subnet.public_a
aws_subnet.public_b

Those no longer exist.

1. Fix asg.tf

Open it:

nano asg.tf

Change the vpc_zone_identifier section to:

vpc_zone_identifier = aws_subnet.public[*].id

So your complete asg.tf should be:

resource "aws_autoscaling_group" "web" {
  name             = "terraform-web-asg"
  min_size         = 1
  desired_capacity = 1
  max_size         = 3

  vpc_zone_identifier = aws_subnet.public[*].id

  launch_template {
    id      = aws_launch_template.web.id
    version = aws_launch_template.web.latest_version
  }

  tag {
    key                 = "Name"
    value               = "terraform-asg-web"
    propagate_at_launch = true
  }
}
2. Also fix the Launch Template security group

This is important because your EC2 instances need to use the web security group, which allows HTTP only from the ALB.

Your current main.tf doesn't attach any security group.

Add this inside aws_launch_template.web:

vpc_security_group_ids = [aws_security_group.web.id]

So:

resource "aws_launch_template" "web" {
  name_prefix   = "terraform-web-"
  image_id      = var.ami_id
  instance_type = var.instance_type
  key_name      = var.key_name

  vpc_security_group_ids = [aws_security_group.web.id]

  tag_specifications {
    resource_type = "instance"

    tags = {
      Name = "terraform-launch-template"
    }
  }
}

This gives us the intended traffic path:

Internet
   |
   | HTTP :80
   v
ALB
[terraform-web-alb-sg]
   |
   | HTTP :80
   v
EC2
[terraform-web-sg]

And the EC2 SG rule:

ALB SG  --->  EC2 :80

is already correctly configured in your security_groups.tf.

3. Format + validate

Run:

terraform fmt

then:

terraform validate

We want:

Success! The configuration is valid.
4. One important point about your VPC design

You asked yesterday whether Terraform can automatically select a VPC rather than putting a VPC name into terraform.tfvars.

Yes, but there are two different approaches.

For this lab, we're doing the better learning approach:

Terraform creates the VPC
        ↓
Terraform creates subnets
        ↓
Terraform creates route table
        ↓
Terraform creates security groups
        ↓
Terraform creates ALB
        ↓
Terraform creates Target Group
        ↓
Terraform connects Target Group → ASG
        ↓
ASG launches EC2

Therefore we don't need a VPC ID in terraform.tfvars at all.

Terraform knows the VPC because we reference:

aws_vpc.main.id

and the subnets because:

aws_subnet.public[*].id

That's much cleaner than manually supplying:

vpc_id = "vpc-xxxxx"

for this particular lab.

5. Then we'll build the ALB completely in Terraform

After terraform validate succeeds, don't apply yet.

Our next files will be approximately:

terraform-launch-template/
│
├── provider.tf
├── variables.tf
├── terraform.tfvars
│
├── vpc.tf / network.tf
├── security_groups.tf
│
├── main.tf
├── asg.tf
├── scaling.tf
│
├── alb.tf              ← next
└── cloudwatch.tf       ← final part

alb.tf will create automatically:

ALB
 ├── ALB Security Group
 ├── Listener :80
 └── Target Group
          |
          v
       ASG
          |
      EC2 instances

And we will attach the target group to the ASG with Terraform:

target_group_arns = [aws_lb_target_group.web.arn]

So no manual ALB creation, no manual target registration.

Finally we'll add CloudWatch, then this module is complete.

For now, just make the two changes above and run:

terraform fmt
terraform validate

===========================================================

Yes — this plan is clean now. The important thing is that Terraform is no longer trying to use the old aws_vpc.web, public_a, or public_b resources.

Your current plan shows 12 resources, all expected:

VPC
Internet Gateway
2 public subnets
Public route table
2 route-table associations
ALB security group
Web/EC2 security group
Launch Template
ASG
CPU target-tracking policy

The plan confirms the new VPC is 10.0.0.0/16, with subnets 10.0.1.0/24 and 10.0.2.0/24.

Also, your Launch Template is now correctly getting a security-group ID dynamically rather than hard-coding it.

But don't apply yet

There is one thing missing: ALB + Target Group + Listener.

Your plan currently has:

VPC
 │
 ├── Public Subnet A
 ├── Public Subnet B
 │
 ├── Security Groups
 │
 ├── Launch Template
 │       ↓
 │      ASG
 │       ↓
 │      EC2
 │
 └── Internet Gateway

We want the final architecture to be:

                    Internet
                       │
                       │ HTTP :80
                       ▼
              ┌─────────────────┐
              │       ALB       │
              │ terraform-web   │
              └────────┬────────┘
                       │
                       │ Target Group
                       ▼
              ┌─────────────────┐
              │       ASG       │
              │ min=1 max=3     │
              └────────┬────────┘
                       │
                ┌──────┴──────┐
                ▼             ▼
              EC2-1         EC2-2

And Terraform will create and connect everything automatically.

Step 1 — Create alb.tf

Run:

nano alb.tf

Put this in it:

resource "aws_lb" "web" {
  name               = "terraform-web-alb"
  internal           = false
  load_balancer_type = "application"

  security_groups = [aws_security_group.alb.id]
  subnets         = aws_subnet.public[*].id

  tags = {
    Name = "terraform-web-alb"
  }
}

resource "aws_lb_target_group" "web" {
  name     = "terraform-web-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  health_check {
    enabled             = true
    path                = "/"
    protocol            = "HTTP"
    port                = "traffic-port"
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 30
  }

  tags = {
    Name = "terraform-web-tg"
  }
}

resource "aws_lb_listener" "web" {
  load_balancer_arn = aws_lb.web.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web.arn
  }
}
Step 2 — Attach Target Group to ASG

Now modify asg.tf.

Add:

target_group_arns = [aws_lb_target_group.web.arn]

So the ASG becomes:

resource "aws_autoscaling_group" "web" {
  name             = "terraform-web-asg"
  min_size         = 1
  desired_capacity = 1
  max_size         = 3

  vpc_zone_identifier = aws_subnet.public[*].id

  target_group_arns = [aws_lb_target_group.web.arn]

  launch_template {
    id      = aws_launch_template.web.id
    version = aws_launch_template.web.latest_version
  }

  tag {
    key                 = "Name"
    value               = "terraform-asg-web"
    propagate_at_launch = true
  }
}

This is the key piece.

Terraform will understand:

ALB Target Group
       │
       ▼
      ASG
       │
       ▼
EC2 instances

You will not manually register EC2 instances with the Target Group.

When ASG creates another EC2 during scale-out, AWS automatically registers it with the Target Group.

When ASG scales in, the instance is removed from the Target Group.

That's exactly the architecture we wanted to learn.

Step 3 — Format and validate
terraform fmt

then:

terraform validate

Then:

terraform plan

Don't run terraform apply yet.

This time the plan should additionally show:

aws_lb.web
aws_lb_target_group.web
aws_lb_listener.web

and the ASG should show:

target_group_arns = ...

So we're aiming for roughly:

12 existing resources
+
3 ALB resources
=
15 resources

After that we'll review the plan once, apply it, verify:

VPC
 ├── ALB
 ├── Target Group
 ├── Listener
 └── ASG
      └── EC2

Then we'll finish the module with CloudWatch monitoring

==========================================================================

Step 1 — Create cloudwatch.tf

Run:

nano cloudwatch.tf

Add:

resource "aws_cloudwatch_metric_alarm" "asg_cpu_high" {
  alarm_name          = "terraform-web-asg-cpu-high"
  alarm_description   = "Alarm when ASG average CPU utilization is high"
  comparison_operator = "GreaterThanThreshold"

  evaluation_periods = 2
  period              = 60
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  statistic           = "Average"

  threshold = 70

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.web.name
  }

  treat_missing_data = "notBreaching"
}

resource "aws_cloudwatch_metric_alarm" "alb_unhealthy_hosts" {
  alarm_name          = "terraform-web-alb-unhealthy"
  alarm_description   = "Alarm when ALB has unhealthy targets"
  comparison_operator = "GreaterThanOrEqualToThreshold"

  evaluation_periods = 2
  period              = 60

  metric_name = "UnHealthyHostCount"
  namespace   = "AWS/ApplicationELB"
  statistic   = "Average"

  threshold = 1

  dimensions = {
    TargetGroup  = aws_lb_target_group.web.arn_suffix
    LoadBalancer = aws_lb.web.arn_suffix
  }

  treat_missing_data = "notBreaching"
}
What these two alarms do
Alarm 1 — ASG CPU
EC2 instances
      │
      ▼
AWS/EC2 CPUUtilization
      │
      ▼
ASG average CPU
      │
      │ > 70%
      ▼
CloudWatch Alarm

This is monitoring only.

Your existing target-tracking policy is what handles autoscaling at the 50% target. CloudWatch alarms created by target tracking are separate from this explicit monitoring alarm. Your existing scaling policy is confirmed in the plan.

Alarm 2 — ALB unhealthy targets
ALB
 │
 ▼
Target Group
 │
 ├── EC2 healthy
 └── EC2 unhealthy
          │
          ▼
UnHealthyHostCount >= 1
          │
          ▼
CloudWatch Alarm

This is useful operationally because it tells us:

The load balancer currently has at least one unhealthy backend.

Step 2 — Format
terraform fmt
Step 3 — Validate
terraform validate

Expected:

Success! The configuration is valid.
Step 4 — Plan
terraform plan

Previously:

Plan: 15 to add, 0 to change, 0 to destroy.

Now we should have:

Plan: 17 to add, 0 to change, 0 to destroy.

because we added:

aws_cloudwatch_metric_alarm.asg_cpu_high
aws_cloudwatch_metric_alarm.alb_unhealthy_hosts

========================================================

Step 1 — Create cloudwatch.tf

Run:

nano cloudwatch.tf

Add:

resource "aws_cloudwatch_metric_alarm" "asg_cpu_high" {
  alarm_name          = "terraform-web-asg-cpu-high"
  alarm_description   = "Alarm when ASG average CPU utilization is high"
  comparison_operator = "GreaterThanThreshold"

  evaluation_periods = 2
  period              = 60
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  statistic           = "Average"

  threshold = 70

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.web.name
  }

  treat_missing_data = "notBreaching"
}

resource "aws_cloudwatch_metric_alarm" "alb_unhealthy_hosts" {
  alarm_name          = "terraform-web-alb-unhealthy"
  alarm_description   = "Alarm when ALB has unhealthy targets"
  comparison_operator = "GreaterThanOrEqualToThreshold"

  evaluation_periods = 2
  period              = 60

  metric_name = "UnHealthyHostCount"
  namespace   = "AWS/ApplicationELB"
  statistic   = "Average"

  threshold = 1

  dimensions = {
    TargetGroup  = aws_lb_target_group.web.arn_suffix
    LoadBalancer = aws_lb.web.arn_suffix
  }

  treat_missing_data = "notBreaching"
}
What these two alarms do
Alarm 1 — ASG CPU
EC2 instances
      │
      ▼
AWS/EC2 CPUUtilization
      │
      ▼
ASG average CPU
      │
      │ > 70%
      ▼
CloudWatch Alarm

This is monitoring only.

Your existing target-tracking policy is what handles autoscaling at the 50% target. CloudWatch alarms created by target tracking are separate from this explicit monitoring alarm. Your existing scaling policy is confirmed in the plan.

Alarm 2 — ALB unhealthy targets
ALB
 │
 ▼
Target Group
 │
 ├── EC2 healthy
 └── EC2 unhealthy
          │
          ▼
UnHealthyHostCount >= 1
          │
          ▼
CloudWatch Alarm

This is useful operationally because it tells us:

The load balancer currently has at least one unhealthy backend.

Step 2 — Format
terraform fmt
Step 3 — Validate
terraform validate

Expected:

Success! The configuration is valid.
Step 4 — Plan
terraform plan

Previously:

Plan: 15 to add, 0 to change, 0 to destroy.

Now we should have:

Plan: 17 to add, 0 to change, 0 to destroy.

because we added:

aws_cloudwatch_metric_alarm.asg_cpu_high
aws_cloudwatch_metric_alarm.alb_unhealthy_hosts

Don't apply yet.

Send me the final terraform plan summary. Then we'll do the one and only apply for this clean setup, verify VPC → ALB → TG → ASG → EC2 → CloudWatch, and close this module.

==============================================================

✅ The clean Terraform deployment is now successful.

You have exactly the expected 17 resources in Terraform state:

1 VPC
1 Internet Gateway
2 subnets
1 route table
2 route-table associations
2 security groups
1 launch template
1 ASG
1 autoscaling policy
1 ALB
1 ALB listener
1 target group
2 CloudWatch alarms

And the key confirmation is:

Apply complete! Resources: 17 added, 0 changed, 0 destroyed.

Your terraform state list also confirms all 17 resources are now managed by Terraform.

One important thing we should verify now

Before destroying, let's verify the actual runtime relationship:

VPC
 ↓
Public Subnets
 ↓
ALB
 ↓
Target Group
 ↓
ASG
 ↓
EC2

Run this first:

aws autoscaling describe-auto-scaling-groups \
  --region us-east-1 \
  --auto-scaling-group-names terraform-web-asg \
  --query 'AutoScalingGroups[0].[MinSize,DesiredCapacity,MaxSize,Instances[*].[InstanceId,LifecycleState,HealthStatus]]' \
  --output json

Then:

aws elbv2 describe-target-health \
  --region us-east-1 \
  --target-group-arn $(aws elbv2 describe-target-groups \
    --region us-east-1 \
    --names terraform-web-tg \
    --query 'TargetGroups[0].TargetGroupArn' \
    --output text) \
  --query 'TargetHealthDescriptions[*].[Target.Id,TargetHealth.State,TargetHealth.Reason]' \
  --output table

We don't need to generate load again — we already proved scaling yesterday.

After these two checks, we'll verify the ALB endpoint once, verify CloudWatch alarms,

================================

Good — the infrastructure itself is working, but there is one functional issue we should fix before calling this module complete.

Current status

Your ASG is correct:

Min      1
Desired  1
Max      3

EC2: i-068db10489485ffa9
State: InService
Health: Healthy

But:

Target Group
└── i-068db10489485ffa9
    └── unhealthy
        └── Target.FailedHealthChecks

This means AWS infrastructure is healthy, but the application on port 80 isn't responding.

The reason is visible in our Terraform design: the Launch Template creates the EC2, but we haven't configured it to install/start a web server.

Let's fix it properly with Terraform

Instead of manually SSHing and installing nginx, we'll make the Launch Template self-configuring.

Add this to main.tf inside aws_launch_template.web:

user_data = base64encode(<<-EOF
  #!/bin/bash
  dnf install -y nginx
  systemctl enable nginx
  systemctl start nginx
EOF
)

So the Launch Template will automatically do:

ASG launches EC2
       ↓
User Data executes
       ↓
Install nginx
       ↓
Start nginx
       ↓
Port 80 responds
       ↓
ALB health check
       ↓
Healthy

This is actually the proper production-style approach for this lab because the instance becomes reproducible.

Then run
terraform fmt
terraform validate
terraform plan

Terraform should show the Launch Template changing, which will cause the ASG to use the updated template.

Then:

terraform apply

After the new instance comes up, check:

aws autoscaling describe-auto-scaling-groups \
  --region us-east-1 \
  --auto-scaling-group-names terraform-web-asg \
  --query 'AutoScalingGroups[0].Instances[*].[InstanceId,LifecycleState,HealthStatus]' \
  --output table

Then:

aws elbv2 describe-target-health \
  --region us-east-1 \
  --target-group-arn $(aws elbv2 describe-target-groups \
    --region us-east-1 \
    --names terraform-web-tg \
    --query 'TargetGroups[0].TargetGroupArn' \
    --output text) \
  --query 'TargetHealthDescriptions[*].[Target.Id,TargetHealth.State,TargetHealth.Reason]' \
  --output table

===============================================================

Correct — it is still unhealthy:

i-068db10489485ffa9
unhealthy
Target.FailedHealthChecks

The most likely reason now is that the currently running EC2 was created from the previous Launch Template version, before we added the nginx user_data.

Updating the Launch Template does not automatically recreate an existing ASG instance.

Let's fix it cleanly

Since this is a lab and we have desired=1, terminate the current instance. The ASG will automatically launch a new instance from the latest Launch Template.

Run:

aws ec2 terminate-instances \
  --region us-east-1 \
  --instance-ids i-068db10489485ffa9

Then watch the ASG:

aws autoscaling describe-auto-scaling-groups \
  --region us-east-1 \
  --auto-scaling-group-names terraform-web-asg \
  --query 'AutoScalingGroups[0].Instances[*].[InstanceId,LifecycleState,HealthStatus]' \
  --output table

Initially you may see:

Pending

Wait a few minutes until the new instance becomes:

InService
Healthy

Then check the Target Group again:

aws elbv2 describe-target-health \
  --region us-east-1 \
  --target-group-arn $(aws elbv2 describe-target-groups \
    --region us-east-1 \
    --names terraform-web-tg \
    --query 'TargetGroups[0].TargetGroupArn' \
    --output text) \
  --query 'TargetHealthDescriptions[*].[Target.Id,TargetHealth.State,TargetHealth.Reason]' \
  --output table

We want:

healthy

This will prove our Terraform Launch Template user-data → nginx → ALB health check chain works.

=============================================================================

Excellent. ✅ Now it is healthy.

Instance: i-06b4b71ada7cf0bb9
Target:   healthy
Reason:   None

So we have successfully verified the complete path:

Internet
   ↓
ALB :80
   ↓
Target Group :80
   ↓
EC2
   ↓
nginx :80
   ↓
ALB Health Check = HEALTHY
One final functional check

Let's hit the ALB once:

aws elbv2 describe-load-balancers \
  --region us-east-1 \
  --names terraform-web-alb \
  --query 'LoadBalancers[0].DNSName' \
  --output text

It will return something like:

terraform-web-alb-xxxxx.us-east-1.elb.amazonaws.com

Then:

curl -I http://<ALB-DNS-NAME>

Expected:

HTTP/1.1 200 OK
Server: nginx/...

Once we see 200 OK, this module is functionally complete.

Then we'll verify the two CloudWatch alarms and finally:

====================================================================

Exactly. ✅ Final functional test passed.

Your ALB returned:

HTTP/1.1 200 OK
Server: nginx/1.30.4
Content-Type: text/html

So the complete stack is working:

Internet
   │
   ▼
ALB :80
   │
   ▼
Target Group :80
   │
   ▼
EC2
   │
   ▼
nginx :80

And we've already independently proven the ASG scaling behavior yesterday.

Module status
Component	Status
VPC	✅
Internet Gateway	✅
Public subnets	✅
Route table	✅
Security Groups	✅
Launch Template	✅
ASG	✅
CPU Target Tracking	✅
ALB	✅
Target Group	✅
Listener	✅
EC2	✅
nginx	✅
ALB Health Check	✅
ALB HTTP response	✅ 200 OK
CloudWatch alarms	✅ Created

This is now a complete end-to-end Terraform deployment.

Before we finish, let's verify CloudWatch once, then destroy the lab so there are no running AWS resources.

Run:

aws cloudwatch describe-alarms \
  --region us-east-1 \
  --alarm-names terraform-web-asg-cpu-high terraform-web-alb-unhealthy \
  --query 'MetricAlarms[*].[AlarmName,StateValue,MetricName,Threshold]' \
  --output table