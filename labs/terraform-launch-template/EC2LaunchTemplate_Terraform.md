We’ll now build the Launch Template lab incrementally.

Step 1 — Create provider.tf

Run:

cat > provider.tf <<'EOF'
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}
EOF

Then verify:

cat provider.tf
Why this first?

This establishes Terraform's connection to AWS:

Terraform
   │
   │ AWS Provider
   ▼
AWS us-east-1

We're intentionally keeping this lab minimal. No modules, variables, VPC, EKS, etc. yet.

=========================================================

Step 2 — Create variables.tf

Run:

cat > variables.tf <<'EOF'
variable "ami_id" {
  description = "AMI ID for the EC2 instance"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "key_name" {
  description = "EC2 key pair name"
  type        = string
}
EOF

Then:

cat variables.tf
What we're learning here

We're deliberately separating configuration from the resource definition:

variables.tf
     │
     ├── ami_id
     ├── instance_type
     └── key_name
     │
     ▼
   main.tf
     │
     ▼
Launch Template

Notice that we're not creating a VPC or Security Group in this lab. We'll use existing AWS networking information where necessary.

After this, we'll create terraform.tfvars.example and then main.tf, where the important part begins:

resource "aws_launch_template" "web" {
  ...
}

That's the Terraform resource we specifically want to understand.

================================================

Step 3 — Create terraform.tfvars.example

Run:

cat > terraform.tfvars.example <<'EOF'
ami_id        = "ami-xxxxxxxxxxxxxxxxx"
instance_type = "t3.micro"
key_name      = "your-key-pair-name"
EOF

Then:

cat terraform.tfvars.example
Why .example?

We keep the structure in Git, but we don't put our real environment-specific values into the example.

Later we'll create your local:

terraform.tfvars

and keep it out of Git if it contains environment-specific values.

Our lab will now look like:

terraform-launch-template/
├── provider.tf
├── variables.tf
└── terraform.tfvars.example

Next comes the important part: main.tf.

There we'll create the actual aws_launch_template and I'll explain each argument rather than just giving you a large block to copy.

===================================================

Step 4 — Create main.tf

For the first iteration, keep the Launch Template intentionally small:

cat > main.tf <<'EOF'
resource "aws_launch_template" "web" {
  name_prefix   = "terraform-web-"
  image_id      = var.ami_id
  instance_type = var.instance_type
  key_name      = var.key_name

  tag_specifications {
    resource_type = "instance"

    tags = {
      Name = "terraform-launch-template"
    }
  }
}
EOF

Then check it:

cat main.tf
Understand what we just created

The important distinction is:

aws_launch_template
        │
        ├── AMI
        ├── Instance type
        ├── Key pair
        └── Instance tags

This does NOT create an EC2 instance.

A Launch Template is essentially an EC2 instance blueprint.

Launch Template
      │
      │ "If you launch an instance,
      │  use these settings"
      ▼
EC2 Instance

That's an important concept for the next topic, Auto Scaling Groups:

Launch Template
       │
       ▼
      ASG
       │
       ├── EC2
       ├── EC2
       └── EC2

We'll deliberately understand this separation before adding ASG.

One thing to notice

We haven't specified:

subnet
security group
VPC
public IP

That's intentional for the first iteration.

After we validate the basic Launch Template, we'll add network/security configuration and see exactly where those settings belong.

===================================================

Step 5 — Initialize Terraform

Run:

terraform init

Then:

terraform validate

You should see:

Success! The configuration is valid.
Step 6 — Get an actual AMI ID

Our terraform.tfvars.example contains a placeholder:

ami-xxxxxxxxxxxxxxxxx

We need a real AMI before plan/apply.

Since you're working in us-east-1, run:

aws ec2 describe-images \
  --region us-east-1 \
  --owners amazon \
  --filters \
    "Name=name,Values=al2023-ami-2023*" \
    "Name=architecture,Values=x86_64" \
    "Name=state,Values=available" \
  --query 'Images | sort_by(@, &CreationDate)[-1].[ImageId,Name]' \
  --output table

This will give us a current Amazon Linux 2023 x86_64 AMI.

==================================================================

Step 7 — Create your local terraform.tfvars

Run:

cat > terraform.tfvars <<'EOF'
ami_id        = "ami-0db1c5c6dc64eb019"
instance_type = "t3.micro"
key_name      = "YOUR_KEY_PAIR_NAME"
EOF

Important: replace YOUR_KEY_PAIR_NAME with the actual EC2 key-pair name you already use in AWS.

You can find it with:

aws ec2 describe-key-pairs \
  --region us-east-1 \
  --query 'KeyPairs[*].KeyName' \
  --output table

Then edit:

nano terraform.tfvars

and put the actual key name.

Verify:

cat terraform.tfvars
One important thing before apply

Our Launch Template currently contains only:

AMI
Instance type
Key pair
Tags

It doesn't launch an EC2 instance yet.

So the next command will be:

terraform plan

and we should expect approximately:

Plan: 1 to add, 0 to change, 0 to destroy.

That is exactly what we want for this first exercise:

Terraform
   │
   ▼
aws_launch_template.web
   │
   ├── AMI
   ├── t3.micro
   ├── key pair
   └── tags

No EC2 instance yet.

Run the key-pair command first and show me the output. Then we'll put the real name into terraform.tfvars and run terraform plan.

===================================

Important distinction

At this point:

AWS
│
└── Launch Template
      ├── AMI
      ├── t3.micro
      ├── Key pair
      └── Tags

There is still no EC2 instance being created.

That's the key concept I want you to remember:

Launch Template = configuration/blueprint, not an EC2 instance.

Step 8 — Apply it

Now run:

terraform apply

Terraform should again show:

Plan: 1 to add, 0 to change, 0 to destroy.

Enter:

yes

After completion, run:

terraform state list

and:

aws ec2 describe-launch-templates \
  --region us-east-1 \
  --query 'LaunchTemplates[*].[LaunchTemplateName,LaunchTemplateId,DefaultVersionNumber]' \
  --output table

We want to see the Launch Template actually exists in AWS.

Then we'll inspect it with:

terraform show

Don't create an EC2 manually yet. First we'll understand exactly what Terraform created and how Launch Template versions work. That versioning concept becomes very important when we move to Auto Scaling Groups.

=======================================================================================================

Where we go next

For our infrastructure-automation goal, we should learn Launch Templates in this order:

1. Basic Launch Template             ✅ DONE
       │
       ▼
2. Launch Template configuration
   ├── network
   ├── security group
   ├── user_data
   └── EBS
       │
       ▼
3. Launch Template versions          ← NEXT
       │
       ▼
4. Auto Scaling Group
       │
       ▼
5. Scaling policies
       │
       ▼
6. ALB + ASG
       │
       ▼
7. CloudWatch integration

We should not jump directly to ASG. The reason is that ASG relies heavily on the Launch Template/version concepts.

Step 1: Understand what we already created

Your current Terraform is essentially:

resource "aws_launch_template" "web" {
  name_prefix   = "terraform-web-"
  image_id      = var.ami_id
  instance_type = var.instance_type
  key_name      = var.key_name

  tag_specifications {
    resource_type = "instance"

    tags = {
      Name = "terraform-launch-template"
    }
  }
}

This gives us:

Setting	Current value
AMI	Amazon Linux 2023
Instance type	t3.micro
Key pair	my-key1
Instance tag	terraform-launch-template
Launch Template version	1

So the next concept is versioning.

Step 2 — Launch Template versioning

This is important because when we modify the Launch Template, AWS doesn't simply overwrite the old configuration conceptually.

For example:

Version 1
AMI = ami-AAAA
Instance = t3.micro

Later:

Version 2
AMI = ami-BBBB
Instance = t3.micro

Then:

Version 3
AMI = ami-BBBB
Instance = t3.small

We can therefore think:

Launch Template
       │
       ├── Version 1
       ├── Version 2
       └── Version 3

This becomes very useful with ASG:

                 Launch Template
                       │
                    Version 2
                       │
                       ▼
              Auto Scaling Group
                 /      |      \
               EC2     EC2     EC2
Let's inspect our current version

Run:

aws ec2 describe-launch-template-versions \
  --region us-east-1 \
  --launch-template-id lt-0128d472933158d45 \
  --query 'LaunchTemplateVersions[*].[VersionNumber,DefaultVersion,LaunchTemplateData.ImageId,LaunchTemplateData.InstanceType]' \
  --output table

And also:

terraform state list

==================================================

Step 1 — Let's inspect our current Terraform

Run:

cat main.tf

and:

cat variables.tf

You already showed me main.tf, which currently has:

resource "aws_launch_template" "web" {
  name_prefix   = "terraform-web-"
  image_id      = var.ami_id
  instance_type = var.instance_type
  key_name      = var.key_name

  tag_specifications {
    resource_type = "instance"

    tags = {
      Name = "terraform-launch-template"
    }
  }
}

Good.

Important concept

Terraform sees this as one Launch Template resource:

aws_launch_template.web

AWS internally maintains versions:

Launch Template
       │
       ├── Version 1
       │     ├── AMI = old
       │     └── type = t3.micro
       │
       ├── Version 2
       │     ├── AMI = new
       │     └── type = t3.micro
       │
       └── Version 3
             └── ...

This becomes extremely important when we connect it to an Auto Scaling Group.

Step 2 — Understand $Latest and $Default

AWS has two important concepts:

$Latest
   ↓
most recently created Launch Template version

$Default
   ↓
version explicitly configured as default

For your current lab:

Version 1
Default = True

Therefore:

$Latest  → Version 1
$Default → Version 1

Later we will deliberately create:

Version 2

and demonstrate a situation such as:

Version 1 → Default
Version 2 → Latest

That distinction is very important for ASG automation.

Step 3 — Make one controlled change

Let's change only the instance type.

Current:

default = "t3.micro"

Change it to:

default = "t3.small"

Do not apply yet.

Run:

sed -i 's/default        = "t3.micro"/default        = "t3.small"/' variables.tf

If the spacing doesn't match, simply edit variables.tf manually.

Then verify:

grep -A5 'variable "instance_type"' variables.tf

We want:

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.small"
}

Then:

terraform fmt
terraform validate

Expected:

Success! The configuration is valid.
Then STOP before apply

Run:

terraform plan

We want to observe what Terraform intends to do.

This is an important Terraform lesson:

Changing the Launch Template configuration does not mean Terraform simply edits the existing AWS Launch Template version in place.

Terraform/AWS versioning behavior is exactly what we want to understand before introducing ASG.

Send me the output of:

terraform plan

================================

Yes. We are exactly where we left off with the Terraform Launch Template lab.

Your latest output confirms the important checkpoint:

No changes. Your infrastructure matches the configuration.

And from the previous step, we also verified:

Launch Template exists
Launch Template ID: lt-0128d472933158d45
Default version: 1
AMI: ami-0db1c5c6dc64eb019
Instance type: t3.micro
Terraform state contains aws_launch_template.web

So do not change anything yet.

Where we are in the learning path

We are learning this as infrastructure automation, not just memorizing Terraform resources.

For Launch Templates, we've covered:

What a Launch Template is
Terraform aws_launch_template
Variables for AMI / instance type / key pair
terraform.tfvars.example
terraform fmt
terraform validate
terraform plan
terraform apply
Terraform state tracking
AWS CLI verification
Launch Template versions
Default version

The next useful concept is:

Launch Template + Auto Scaling Group

That's where Launch Template becomes practically useful. A Launch Template by itself is mainly an EC2 configuration blueprint. An Auto Scaling Group uses that blueprint to actually manage a fleet of EC2 instances.

Our sequence

We'll keep it simple:

Launch Template
       ↓
Auto Scaling Group
       ↓
Scaling policies
       ↓
ALB
       ↓
CloudWatch

And later we'll connect these concepts into the larger infrastructure project.

Next step

Before building the ASG, let's make sure you understand one important distinction:

AMI
 ↓
Launch Template
 ↓
ASG
 ↓
EC2 instances

Launch Template = "How should an EC2 instance be created?"

Auto Scaling Group = "How many instances should exist, and where/how should they be maintained?"

That's the next concept we'll build.

=============================================================

Step 2 — Create the Auto Scaling Group

We're going to keep this lab deliberately simple.

Our architecture will be:

                Launch Template
                  Version 2
                  t3.small
                     │
                     ▼
             Auto Scaling Group
              min = 1
              desired = 2
              max = 3
                  │
             ┌────┴────┐
             ▼         ▼
           EC2        EC2
        t3.small    t3.small

We also need subnets. Rather than building another VPC just for this exercise, we'll use the default VPC.

1. Create data.tf

From:

cd ~/aws-terraform-learning/labs/terraform-launch-template

create:

nano data.tf

Put:

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}
What this teaches

We are not creating the VPC.

Terraform is asking AWS:

"Give me the existing default VPC."

That's the purpose of a data source.

We've already learned data sources earlier, so this is applying that knowledge to a real infrastructure use case.

2. Create asg.tf
nano asg.tf

Put:

resource "aws_autoscaling_group" "web" {
  name             = "terraform-web-asg"
  min_size         = 1
  desired_capacity = 2
  max_size         = 3

  vpc_zone_identifier = data.aws_subnets.default.ids

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
The important parts
Capacity
min_size         = 1
desired_capacity = 2
max_size         = 3

Meaning:

Minimum instances     = 1
Normal desired state  = 2
Maximum instances     = 3

Initially ASG should create 2 EC2 instances.

Subnets
vpc_zone_identifier = data.aws_subnets.default.ids

This tells the ASG:

You can launch instances into these subnets.

Because we're retrieving all subnets belonging to the default VPC, the ASG can distribute instances across available AZs/subnets.

Most important part
launch_template {
  id      = aws_launch_template.web.id
  version = aws_launch_template.web.latest_version
}

This connects our two resources:

aws_launch_template.web
        │
        │ latest_version
        ▼
aws_autoscaling_group.web

And because:

latest_version = 2

the ASG will use:

t3.small

rather than the old Version 1:

t3.micro
3. Format and validate

Run:

terraform fmt

then:

terraform validate

Expected:

Success! The configuration is valid.

Then:

terraform plan
Stop here

Don't apply yet.

Send me the terraform plan output.

We'll inspect exactly what Terraform intends to create, especially the ASG's relationship with Launch Template Version 2, before we create the EC2 instances.

=================================================================

Your Terraform configuration will create:

aws_autoscaling_group.web

with:

Setting	Value
Launch Template	lt-0128d472933158d45
Launch Template version	2
Min instances	1
Desired instances	2
Max instances	3
Subnets	6
Name tag	terraform-asg-web

The important part for our learning is:

launch_template {
    id      = "lt-0128d472933158d45"
    version = "2"
}

So we have now connected the two concepts:

Launch Template
      │
      │ version 2
      ▼
Auto Scaling Group
      │
      ├── desired = 2
      ├── min     = 1
      └── max     = 3
             │
             ▼
        EC2 Instances

This is real infrastructure automation, not just learning isolated Terraform resources.

Next: Apply it

Since this is a learning lab and we want to actually see ASG create instances, run:

terraform apply

Review:

Plan: 1 to add, 0 to change, 0 to destroy.

Then type:

yes
After apply

Don't immediately modify anything.

We'll verify the automation from three perspectives.

1. Terraform
terraform state list

We should see:

aws_autoscaling_group.web
aws_launch_template.web
2. AWS ASG
aws autoscaling describe-auto-scaling-groups \
  --region us-east-1 \
  --auto-scaling-group-names terraform-asg-web \
  --query 'AutoScalingGroups[0].[AutoScalingGroupName,MinSize,DesiredCapacity,MaxSize,Instances[*].[InstanceId,LifecycleState,HealthStatus]]' \
  --output table
3. EC2
aws ec2 describe-instances \
  --region us-east-1 \
  --filters "Name=tag:Name,Values=terraform-asg-web" \
  --query 'Reservations[*].Instances[*].[InstanceId,InstanceType,State.Name,PrivateIpAddress]' \
  --output table

We should see 2 EC2 instances.

Then we'll do the important learning

Once the ASG is running, our next exercise will be:

Change the ASG desired capacity

For example:

desired = 2
        ↓
desired = 3

and observe:

Terraform
   ↓
ASG desired capacity changes
   ↓
ASG launches another EC2
   ↓
3 instances

Then we'll learn scale-in, and after that we'll add CloudWatch + scaling policy.

So our progression is now:

✅ Launch Template
   └── Versioning

➡️ Auto Scaling Group
   ├── min / desired / max
   ├── Launch Template integration
   ├── Multiple AZs
   └── EC2 lifecycle

➡️ Scaling Policies
   ├── Target Tracking
   └── CloudWatch metric

➡️ ALB
   └── ALB → Target Group → ASG

➡️ Complete automated application infrastructure

Go ahead with terraform apply now. After it completes, send me the output of terraform state list and the ASG verification command. We'll build the next piece from what you actually get

======================================================

Next exercise: prove scaling

Before adding CloudWatch or ALB, let's understand the ASG itself properly.

Our first experiment:

desired = 2
    ↓
desired = 3
    ↓
Terraform changes ASG
    ↓
ASG launches 3rd EC2

Open your ASG Terraform file:

cat main.tf

Find the section similar to:

resource "aws_autoscaling_group" "web" {
  min_size         = 1
  desired_capacity = 2
  max_size         = 3

Change only:

desired_capacity = 3

Then:

terraform fmt
terraform plan

We want to see something like:

~ desired_capacity = 2 -> 3

Plan: 0 to add, 1 to change, 0 to destroy.

Don't apply yet.

Send me that plan output.

We'll use it to understand the difference between:

Terraform changing the ASG configuration
AWS ASG performing the actual scaling action
EC2 instances being created by the ASG

That's the next important piece before we move to CloudWatch-driven automatic scaling.

==============================================

Perfect. The EC2 verification is exactly what we wanted.

You now have 3 running instances across 3 AZs:

Instance	Type	AZ	State
i-03c2dfd387be4eac1	t3.small	us-east-1f	running
i-0c3f27acd02802312	t3.small	us-east-1a	running
i-015130799520158b0	t3.small	us-east-1d	running

So the ASG successfully achieved:

desired_capacity = 3

and distributed the instances across multiple Availability Zones.

About the first command error

This:

Row should have 1 elements, instead it has 4

is just an AWS CLI table-formatting issue caused by putting a nested list together with scalar values in one table row.

It doesn't indicate an ASG problem.

Let's verify the ASG with simpler queries.

Run:

aws autoscaling describe-auto-scaling-groups \
  --region us-east-1 \
  --auto-scaling-group-names terraform-web-asg \
  --query 'AutoScalingGroups[0].[MinSize,DesiredCapacity,MaxSize]' \
  --output table

Expected:

---------------------------
| DescribeAutoScalingGroups |
+----+----+----+
| 1  | 3  | 3  |
+----+----+----+

Then:

aws autoscaling describe-auto-scaling-groups \
  --region us-east-1 \
  --auto-scaling-group-names terraform-web-asg \
  --query 'AutoScalingGroups[0].Instances[*].[InstanceId,LifecycleState,HealthStatus,AvailabilityZone]' \
  --output table

This should give us the three instances cleanly.

And we have completed an important exercise

Our experiment was:

Before
desired = 2
instances = 2

       ↓

Terraform change

desired = 3

       ↓

ASG attempts launch

       ↓

us-east-1e
t3.small unavailable
       ↓
launch FAILED

       ↓

ASG retries

       ↓

us-east-1f
launch SUCCESS

       ↓

Final
desired = 3
instances = 3

This is excellent infrastructure automation knowledge.

We didn't just learn:

"Here is how to write aws_autoscaling_group."

We learned how Terraform, ASG, EC2, Launch Templates and Availability Zones interact.

One thing before we move on

We currently have 3 × t3.small instances running. Since this is a learning lab, after we finish verifying the ASG, we'll eventually scale it back down to desired = 1 or destroy the lab before moving to the next exercise.

======================================================================

Step 1 — Check current ASG state

Run this simpler command:

aws autoscaling describe-auto-scaling-groups \
  --region us-east-1 \
  --auto-scaling-group-names terraform-web-asg \
  --query 'AutoScalingGroups[0].[MinSize,DesiredCapacity,MaxSize]' \
  --output table

You should see approximately:

--------------------------------
| DescribeAutoScalingGroups    |
+------+----------+------------+
|  1   |    3     |     3      |
+------+----------+------------+

Then:

aws ec2 describe-instances \
  --region us-east-1 \
  --filters "Name=tag:Name,Values=terraform-asg-web" \
  --query 'Reservations[*].Instances[*].[InstanceId,InstanceType,State.Name,Placement.AvailabilityZone]' \
  --output table

You already know this gives us the actual EC2 instances.

Step 2 — Let's deliberately scale DOWN

This is a useful exercise because we will see the relationship:

desired_capacity
       ↓
ASG controller
       ↓
EC2 instance count

Change your Terraform ASG configuration from:

desired_capacity = 3

to:

desired_capacity = 2

Keep:

min_size = 1
max_size = 3

So:

resource "aws_autoscaling_group" "web" {
  name                = "terraform-web-asg"

  min_size            = 1
  desired_capacity    = 2
  max_size            = 3

  ...
}

Then:

terraform fmt
terraform validate
terraform plan

The important part of the plan should be:

~ desired_capacity = 3 -> 2

Plan: 0 to add, 1 to change, 0 to destroy.
Don't apply yet if the plan shows anything else unexpected.

If it looks like that, then:

terraform apply

and enter:

yes
What should happen?

Terraform changes the ASG desired capacity:

3
↓
2

The ASG controller notices that it has one instance too many:

Desired = 2
Current = 3

        ↓

Terminate one instance

Eventually:

EC2
├── instance-1  running
└── instance-2  running

instead of:

EC2
├── instance-1  running
├── instance-2  running
└── instance-3  running

Then verify:

aws ec2 describe-instances \
  --region us-east-1 \
  --filters "Name=tag:Name,Values=terraform-asg-web" \
  --query 'Reservations[*].Instances[*].[InstanceId,InstanceType,State.Name,Placement.AvailabilityZone]' \
  --output table

And:

aws autoscaling describe-auto-scaling-groups \
  --region us-east-1 \
  --auto-scaling-group-names terraform-web-asg \
  --query 'AutoScalingGroups[0].[MinSize,DesiredCapacity,MaxSize]' \
  --output table
One important concept

Notice what we are not doing:

We are not manually terminating an EC2 instance.

We change:

desired_capacity = 2

and let the ASG controller reconcile the actual infrastructure.

That's an important DevOps/Kubernetes-style concept:

Desired State
     │
     ▼
Terraform
     │
     ▼
AWS ASG
     │
     ▼
Actual EC2 instances

Once we finish scale-down and scale-up, we'll move to the more important Launch Template + ASG exercise: changing the Launch Template version and understanding what happens to existing instances versus newly launched instances.

=======================================================

Next exercise: ASG scaling

We have already learned:

Launch Template
      │
      ▼
Launch Template Version 1
      │
      ▼
Launch Template Version 2
      │
      ▼
Auto Scaling Group
      │
      ├── min = 1
      ├── desired = 3
      └── max = 3

Now we should actually see the Auto Scaling Group control the number of EC2 instances.

Step 1 — Check current ASG state

Run this simpler command:

aws autoscaling describe-auto-scaling-groups \
  --region us-east-1 \
  --auto-scaling-group-names terraform-web-asg \
  --query 'AutoScalingGroups[0].[MinSize,DesiredCapacity,MaxSize]' \
  --output table

You should see approximately:

--------------------------------
| DescribeAutoScalingGroups    |
+------+----------+------------+
|  1   |    3     |     3      |
+------+----------+------------+

Then:

aws ec2 describe-instances \
  --region us-east-1 \
  --filters "Name=tag:Name,Values=terraform-asg-web" \
  --query 'Reservations[*].Instances[*].[InstanceId,InstanceType,State.Name,Placement.AvailabilityZone]' \
  --output table

You already know this gives us the actual EC2 instances.

Step 2 — Let's deliberately scale DOWN

This is a useful exercise because we will see the relationship:

desired_capacity
       ↓
ASG controller
       ↓
EC2 instance count

Change your Terraform ASG configuration from:

desired_capacity = 3

to:

desired_capacity = 2

Keep:

min_size = 1
max_size = 3

So:

resource "aws_autoscaling_group" "web" {
  name                = "terraform-web-asg"

  min_size            = 1
  desired_capacity    = 2
  max_size            = 3

  ...
}

Then:

terraform fmt
terraform validate
terraform plan

The important part of the plan should be:

~ desired_capacity = 3 -> 2

Plan: 0 to add, 1 to change, 0 to destroy.
Don't apply yet if the plan shows anything else unexpected.

If it looks like that, then:

terraform apply

and enter:

yes
What should happen?

Terraform changes the ASG desired capacity:

3
↓
2

The ASG controller notices that it has one instance too many:

Desired = 2
Current = 3

        ↓

Terminate one instance

Eventually:

EC2
├── instance-1  running
└── instance-2  running

instead of:

EC2
├── instance-1  running
├── instance-2  running
└── instance-3  running

Then verify:

aws ec2 describe-instances \
  --region us-east-1 \
  --filters "Name=tag:Name,Values=terraform-asg-web" \
  --query 'Reservations[*].Instances[*].[InstanceId,InstanceType,State.Name,Placement.AvailabilityZone]' \
  --output table

And:

aws autoscaling describe-auto-scaling-groups \
  --region us-east-1 \
  --auto-scaling-group-names terraform-web-asg \
  --query 'AutoScalingGroups[0].[MinSize,DesiredCapacity,MaxSize]' \
  --output table
One important concept

Notice what we are not doing:

We are not manually terminating an EC2 instance.

We change:

desired_capacity = 2

and let the ASG controller reconcile the actual infrastructure.

That's an important DevOps/Kubernetes-style concept:

Desired State
     │
     ▼
Terraform
     │
     ▼
AWS ASG
     │
     ▼
Actual EC2 instances

Once we finish scale-down and scale-up, we'll move to the more important Launch Template + ASG exercise: changing the Launch Template version and understanding what happens to existing instances versus newly launched instances.

=======================================================================

