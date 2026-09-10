Today's Plan (2–3 Hours)

We'll create a new lab in your repository.

labs/
└── terraform-aws-iam-authentication/
    ├── main.tf
    ├── iam.tf
    ├── variables.tf
    ├── outputs.tf
    ├── user-data.sh
    └── README.md

This lab will be completely separate from the previous one, so it becomes a reusable reference.

Lab 1 — Build the Authentication Flow

Terraform will create:

VPC
   │
Subnet
   │
EC2
   │
IAM Role
   │
Instance Profile
   │
Permission Policy

Nothing manual except:

terraform apply
Lab 2 — Verify STS

SSH into EC2.

Run:

aws sts get-caller-identity

Now you'll see the role that the instance has assumed.

This is the first time you'll witness STS in action.

Lab 3 — Verify IMDS

Run:

curl http://169.254.169.254/latest/meta-data/

You'll discover what IMDS exposes.

Lab 4 — Verify IAM Role

Run:

curl http://169.254.169.254/latest/meta-data/iam/security-credentials/

Expected output:

Platform-EC2-Role

Now you'll know exactly which role is attached.

Lab 5 — Verify Temporary Credentials

Run:

curl http://169.254.169.254/latest/meta-data/iam/security-credentials/Platform-EC2-Role

You'll see something like:

{
  "AccessKeyId": "...",
  "SecretAccessKey": "...",
  "Token": "...",
  "Expiration": "..."
}

This is one of the most eye-opening labs because it proves:

STS generated temporary credentials.
IMDS made them available.
No permanent Access Keys are stored on the EC2.
Lab 6 — Break Authorization

We'll remove the policy:

SecretsManagerRead

Then test:

aws secretsmanager ...

Expected result:

AccessDenied

Authentication still works.

Authorization fails.

This is exactly what we discussed in theory.

Lab 7 — Break Trust

This is the most interesting one.

We'll intentionally modify the Trust Policy.

Instead of:

{
  "Service": "ec2.amazonaws.com"
}

We'll change it (or remove EC2).

Observe what happens.

This demonstrates why the Trust Policy is required before STS can issue credentials.

Why Terraform Instead of the AWS Console?

Because six months from now, I want you to be able to say:

"I can provision secure AWS infrastructure using Terraform."

That's much more valuable than:

"I know where to click in the AWS Console."

What We'll Build Today

By the end of today, you'll have implemented and verified:

✔ IAM Role
✔ IAM Policy
✔ Trust Policy
✔ Instance Profile
✔ STS
✔ IMDS
✔ AWS CLI
✔ Temporary Credentials
✔ Authentication
✔ Authorization
✔ Access Denied Scenarios

============================================================================================

📘 Lab 01 – EC2 IAM Authentication with Terraform
🎯 Objective

Build an EC2 instance that:

Uses an IAM Role (no Access Keys)
Assumes the role automatically via STS
Retrieves temporary credentials through IMDS
Verifies the identity using AWS CLI

By the end, you'll understand the complete authentication flow from theory to practice.

Step 0 – Create a New Lab

Inside your repository:

labs/
└── terraform-aws-iam-authentication/
    ├── main.tf
    ├── provider.tf
    ├── variables.tf
    ├── iam.tf
    ├── ec2.tf
    ├── outputs.tf
    ├── user-data.sh
    ├── terraform.tfvars
    └── README.md
Before We Write Any Code

I have one question.

Do you already have a working Terraform AWS project with:
✅ VPC
✅ Public Subnet
✅ Internet Gateway
✅ Route Table
✅ Security Group
✅ EC2

Or

Do you want this lab to create all of those resources from scratch?

My Recommendation

Since you've already completed the AWS Foundation modules, reuse your existing infrastructure.

We'll only add the IAM components.

That keeps the lab focused on authentication rather than rebuilding networking.

So today's architecture becomes:

Existing VPC
      │
Existing Public Subnet
      │
Existing Security Group
      │
      ▼
New EC2
      │
      ▼
IAM Role
      │
      ▼
Instance Profile
      │
      ▼
STS
      │
      ▼
Temporary Credentials

Terraform Resource

Create a new file:

iam.tf

Our first resource will be:

resource "aws_iam_role" "ec2_role" {

  name = "terraform-lab-ec2-role"

  assume_role_policy = jsonencode({

    Version = "2012-10-17"

    Statement = []

  })

}

Don't worry—we'll fill in the Statement in Phase 2 when we build the Trust Policy.

For now, I want you to understand the resource itself.

Explain Every Parameter
1️⃣ Resource Type
resource "aws_iam_role"

This tells Terraform:

Create an IAM Role in AWS.

2️⃣ Local Name
ec2_role

This is only for Terraform.

We'll reference it later like:

aws_iam_role.ec2_role.name

Think of it as a variable name inside Terraform.

3️⃣ Name
name = "terraform-lab-ec2-role"

This is the actual IAM Role name that you'll see in the AWS Console.

For example:

AWS Console

IAM

Roles

terraform-lab-ec2-role
4️⃣ assume_role_policy

This is the most important parameter in this resource.

It answers:

Who is allowed to assume (use) this role?

Today it's empty because we haven't learned Trust Policies yet.

In Phase 2, we'll populate it.

5️⃣ Why jsonencode()?

AWS expects the trust policy as JSON.

Terraform lets us write it as HCL and converts it to JSON automatically with:

jsonencode({...})

This keeps the configuration readable and avoids escaping quotes manually.

Why Not Write JSON Directly?

You could do something like:

assume_role_policy = <<EOF
{
  ...
}
EOF

But jsonencode() is the preferred Terraform approach because it's easier to maintain and less error-prone.

🚫 We Are NOT Applying Yet

At the end of Phase 1, we will only:

terraform fmt
terraform validate

Expected result: terraform validate will fail because the Trust Policy (Statement) is intentionally incomplete. 
That's okay—we'll fix it in Phase 2.

✅ We Are Ready for Phase 2

Now we'll complete the missing part of the role.

You'll replace the empty Statement with:

Statement = [
  {
    Effect = "Allow"

    Principal = {
      Service = "ec2.amazonaws.com"
    }

    Action = "sts:AssumeRole"
  }
]

===============================================================================================================================

📘 Phase 2 – Trust Policy
Objective

Complete the IAM Role by telling AWS:

"Who is allowed to use this role?"

This is called the Trust Policy.

Architecture

Before adding the Trust Policy:

EC2
 │
 ▼
IAM Role
 │
 ▼
❌ AWS doesn't know who can use it

After adding the Trust Policy:

EC2
 │
 ▼
IAM Role
 │
 ▼
Trust Policy
 │
 ▼
EC2 is trusted
Terraform Code

Update your iam.tf to:

resource "aws_iam_role" "ec2_role" {

  name = "terraform-lab-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Principal = {
          Service = "ec2.amazonaws.com"
        }

        Action = "sts:AssumeRole"
      }
    ]
  })
}

Don't move to the next phase yet. Let's understand every line.

Line 1
Version = "2012-10-17"
What is it?

This is the policy language version.

It is not:

AWS version
Terraform version
IAM Role version

It simply tells AWS:

"Interpret this policy using the IAM policy language introduced on 2012-10-17."

You'll see this in almost every IAM policy.

You normally never change it.

Line 2
Statement = [
Why is it a list?

Because one policy can contain multiple rules.

Example:

Statement

Rule 1

Rule 2

Rule 3

Rule 4

Today we only have one rule.

Later you may have several.

Rule

Our only rule is:

{

Everything inside this block is one Trust Rule.

Effect
Effect = "Allow"

Meaning:

Allow

AWS also supports:

Deny

For Trust Policies, almost all examples use Allow.

Principal

This is the most important field.

Principal = {

    Service = "ec2.amazonaws.com"

}

This answers:

Who is trusted?

Answer:

EC2 Service

Only EC2 is allowed to assume this role.

Think of It Like a Building

Imagine your office.

The security guard asks:

Who are you?

You answer:

EC2

The Trust Policy checks:

Is EC2 trusted?

YES

↓

Enter

If Lambda arrives:

Lambda

↓

Trust Policy

↓

No

↓

Access Denied
Why ec2.amazonaws.com?

This is the service principal for Amazon EC2.

Every AWS service has its own principal.

Examples:

AWS Service	Service Principal
EC2	ec2.amazonaws.com
Lambda	lambda.amazonaws.com
ECS Tasks	ecs-tasks.amazonaws.com
EKS Pods (IRSA)	OIDC provider (we'll learn later)
Action
Action = "sts:AssumeRole"

This is another very important line.

It means:

EC2 is allowed to call the AWS STS AssumeRole API for this role.

Remember:

AssumeRole does not create the role.

It means:

EC2

↓

Requests

↓

"I want to become terraform-lab-ec2-role"

↓

STS checks Trust Policy

↓

If allowed

↓

Issues Temporary Credentials
Complete Flow

Now everything starts connecting.

EC2 Boots
      │
      ▼
Attached IAM Role
      │
      ▼
Trust Policy
      │
      ▼
Is EC2 trusted?
      │
      ▼
YES
      │
      ▼
STS
      │
      ▼
Temporary Credentials
      │
      ▼
IMDS
      │
      ▼
AWS SDK
      │
      ▼
Application

This is exactly what happens every time an EC2 with an IAM Role starts.

===========================================================================================================================

📘 Phase 3 – Permission Policy
Objective

So far our architecture is:

EC2
 │
 ▼
IAM Role
 │
 ▼
Trust Policy
 │
 ▼
STS
 │
 ▼
Temporary Credentials

At this point, EC2 has an identity.

But what happens if the application tries:

Read S3 Bucket

Can it?

No.

Why?

Because we haven't given the role any permissions yet.

Authentication vs Authorization

This is where many engineers get confused.

Authentication

Answers:

Who are you?

AWS answer:

IAM Role
Authorization

Answers:

What are you allowed to do?

AWS answer:

Permission Policy
Real Example

Suppose your EC2 application wants to:

Read Secrets Manager

The request goes like this:

Application
      │
      ▼
AWS SDK
      │
      ▼
Temporary Credentials
      │
      ▼
Secrets Manager
      │
      ▼
Permission Policy Check

AWS asks:

Does this role have permission to call GetSecretValue?

If Yes:

Return Secret

If No:

AccessDenied
What is a Permission Policy?

A Permission Policy is simply a document that defines:

What actions are allowed (or denied) on which AWS resources.

Unlike the Trust Policy, which asks "Who?", the Permission Policy asks:

What?
Policy Types

There are two main types you'll use.

1. AWS Managed Policy

Created and maintained by AWS.

Examples:

AmazonSSMManagedInstanceCore

AmazonS3ReadOnlyAccess

CloudWatchAgentServerPolicy

Advantages:

AWS updates them.
Easy to attach.
Great for learning and common use cases.
2. Customer Managed Policy

Created by you.

Example:

Allow

secretsmanager:GetSecretValue

Only on

arn:aws:secretsmanager:...

Advantages:

Fine-grained permissions.
Follows the Principle of Least Privilege.
Preferred for production.
What Should We Use Today?

For this lab:

We'll start with an AWS Managed Policy.

Why?

Because we want to focus on IAM concepts first, not on writing custom JSON policies.

We'll attach:

AmazonSSMManagedInstanceCore
Why This Policy?

It allows the EC2 instance to communicate with AWS Systems Manager (SSM).

Benefits:

Register the instance with Systems Manager.
Run commands remotely (if the SSM Agent is present and networking allows it).
In many environments, connect without opening SSH (port 22).

This is a common production practice.

Terraform Resource

We'll use:

resource "aws_iam_role_policy_attachment" "ssm_core" {

  role       = aws_iam_role.ec2_role.name

  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"

}

Let's understand every line.

Line 1
resource "aws_iam_role_policy_attachment"

Terraform creates an attachment.

Notice:

It is not creating a policy.

It is attaching an existing AWS Managed Policy to the IAM Role.

Line 2
role = aws_iam_role.ec2_role.name

This tells Terraform:

Attach the policy to:

terraform-lab-ec2-role

This is why we gave the role the Terraform name ec2_role in Phase 1.

Line 3
policy_arn

Every AWS Managed Policy has a unique ARN.

For this lab:

arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore

You're not writing the policy yourself—you're referencing AWS's predefined policy.

Architecture After Phase 3
EC2
 │
 ▼
IAM Role
 │
 ├──────────────┐
 │              │
 ▼              ▼
Trust Policy    Permission Policy
 │              │
 ▼              ▼
Who?        What can it do?

Now the role has:

An identity.
A trusted principal (EC2).
A permission policy.

It's still not attached to the EC2 because we haven't created the Instance Profile yet.

================================================================================================================

 That comes in Phase 4.

📘 Phase 3 – Add Permission Policy Attachment
Step 1: Open iam.tf

Right now it should contain your IAM Role from Phases 1 and 2.

At the bottom of the file, add this new resource:

############################################
# Attach AWS Managed Policy to IAM Role
############################################

resource "aws_iam_role_policy_attachment" "ssm_core" {

  role       = aws_iam_role.ec2_role.name

  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"

}
Explain Every Line
Resource Type
resource "aws_iam_role_policy_attachment"

Terraform will attach an existing IAM Policy to an IAM Role.

Notice the wording:

❌ It does not create a policy.
✅ It attaches an existing policy.
Local Name
ssm_core

This is just Terraform's internal reference.

We could have named it:

attachment1

or

ec2_ssm_policy

But ssm_core is descriptive and easy to understand.

Role
role = aws_iam_role.ec2_role.name

This means:

Attach the policy to the role we created earlier.

Terraform resolves this automatically.

aws_iam_role.ec2_role.name
            │
            ▼
terraform-lab-ec2-role
policy_arn
policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"

This is the AWS Managed Policy.

Break down the ARN:

arn
 │
 ▼
aws
 │
 ▼
iam
 │
 ▼
aws
 │
 ▼
policy
 │
 ▼
AmazonSSMManagedInstanceCore

Meaning:

Attach AWS's predefined Systems Manager policy to this IAM Role.

Architecture After Phase 3
IAM Role
     │
     ▼
Trust Policy
     │
     ▼
Permission Policy

Notice:

EC2 is still not connected.

That happens in Phase 4.

Validate

Run:

terraform fmt

Then:

terraform validate

Expected output:

Success! The configuration is valid.

Do not run:

terraform plan

or

terraform apply

yet.

📘 New Phase 0 – Provider

Let's start with the minimum required files.

provider.tf
terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}
Question

Why don't we write:

region = "us-east-1"

Because later we'll use:

region = var.aws_region

so the lab becomes reusable.

variables.tf

We'll also need:

variable "aws_region" {
  description = "AWS Region"
  type        = string
}
terraform.tfvars
aws_region = "us-east-1"
Now Run
terraform init

NOT

terraform validate

Why?

Because terraform init:

Downloads the AWS provider
Creates the .terraform directory
Creates .terraform.lock.hcl

Only after initialization can Terraform validate the configuration.

===================================================================================================================

📘 Phase 4 – Instance Profile
🎯 Objective

Connect the EC2 Instance with the IAM Role.

Current Architecture

Right now, this is what we have:

                IAM Role
                   │
          ┌────────┴────────┐
          │                 │
          ▼                 ▼
   Trust Policy      Permission Policy

Everything looks good.

But...

Where is EC2?

Nowhere.

The EC2 has no way to use this role.

Why Can't EC2 Use an IAM Role Directly?

This is one of the most common interview questions.

People think:

EC2
 │
 ▼
IAM Role

AWS doesn't work like that.

AWS requires an intermediate object called an Instance Profile.

The real architecture is:

EC2
 │
 ▼
Instance Profile
 │
 ▼
IAM Role
 │
 ├───────────────┐
 │               │
 ▼               ▼
Trust Policy    Permission Policy

Instance Profile = Bridge between EC2 and IAM Role.

Real Life Analogy

Imagine you join a company.

You have:

Employee

The company has:

Employee Badge

Can you simply say:

"I'm an employee."

and walk into the server room?

No.

You need to wear the badge.

Think of it like this:

Employee
     │
     ▼
Badge Holder
     │
     ▼
Employee Badge

The badge holder is like the Instance Profile.

Terraform Resource

Now open iam.tf.

Below the policy attachment, add:

############################################
# Instance Profile
############################################

resource "aws_iam_instance_profile" "ec2_profile" {

  name = "terraform-lab-ec2-profile"

  role = aws_iam_role.ec2_role.name

}
Explain Every Line
Resource Type
resource "aws_iam_instance_profile"

Terraform creates an Instance Profile.

Notice:

It is not an IAM Role.
It is not a Policy.
It is simply the object that allows EC2 to use the role.
Local Name
ec2_profile

Terraform reference.

Later we'll write:

aws_iam_instance_profile.ec2_profile.name
Name
name = "terraform-lab-ec2-profile"

This is the name you'll see in AWS.

Role
role = aws_iam_role.ec2_role.name

This connects:

Instance Profile
        │
        ▼
IAM Role

Terraform automatically understands the dependency.

Dependency Graph

One of Terraform's strengths is that it builds a dependency graph.

Without you writing anything extra, Terraform understands:

IAM Role
     │
     ▼
Instance Profile

It knows the IAM Role must be created before the Instance Profile.

What Happens During EC2 Boot?

Once we attach the Instance Profile (Phase 5), AWS performs this flow:

EC2 Starts
      │
      ▼
Instance Profile
      │
      ▼
IAM Role
      │
      ▼
Trust Policy
      │
      ▼
STS
      │
      ▼
Temporary Credentials
      │
      ▼
IMDS
      │
      ▼
Application

This is the complete authentication chain you've been learning.

Validate

Run:

terraform fmt
terraform validate

We still do not run plan or apply.

=========================================================================================================

🚀 Phase 5 – Attach the Instance Profile to EC2

Now we'll finally connect everything.

Until now we've created:

✅ IAM Role
✅ Trust Policy
✅ Permission Policy
✅ Instance Profile

But the EC2 instance still isn't using any of them.

Objective

Modify the EC2 resource so AWS knows which Instance Profile to attach when the instance launches.

Find Your EC2 Resource

Open your ec2.tf.

You'll have something similar to:

resource "aws_instance" "web" {

  ami           = ...
  instance_type = ...
  subnet_id     = ...

  ...

}

Inside that resource, add one line:

iam_instance_profile = aws_iam_instance_profile.ec2_profile.name

That's it.

Explain This Line
iam_instance_profile = aws_iam_instance_profile.ec2_profile.name

Terraform says:

"When creating this EC2 instance, attach the Instance Profile named terraform-lab-ec2-profile."

Notice:

We're not attaching the IAM Role directly.

We're attaching the Instance Profile, because that's how EC2 integrates with IAM.

Final Architecture Before Deployment

Once you add that line, the complete chain is in place:

EC2
 │
 ▼
Instance Profile
 │
 ▼
IAM Role
 │
 ├──────────────┐
 │              │
 ▼              ▼
Trust Policy    Permission Policy
 │
 ▼
STS
 │
 ▼
Temporary Credentials
 │
 ▼
IMDS
 │
 ▼
AWS SDK
 │
 ▼
Application
🧠 Your Task
Add:
iam_instance_profile = aws_iam_instance_profile.ec2_profile.name

to your aws_instance resource.

Run:
terraform fmt
terraform validate

=================================================================================================================

Step 1 — Create main.tf
############################################
# VPC
############################################

resource "aws_vpc" "main" {

  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "terraform-lab-vpc"
  }

}

############################################
# Public Subnet
############################################

resource "aws_subnet" "public" {

  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = true

  tags = {
    Name = "terraform-lab-public-subnet"
  }

}

############################################
# Internet Gateway
############################################

resource "aws_internet_gateway" "igw" {

  vpc_id = aws_vpc.main.id

  tags = {
    Name = "terraform-lab-igw"
  }

}

############################################
# Route Table
############################################

resource "aws_route_table" "public" {

  vpc_id = aws_vpc.main.id

  route {

    cidr_block = "0.0.0.0/0"

    gateway_id = aws_internet_gateway.igw.id

  }

}

############################################
# Route Table Association
############################################

resource "aws_route_table_association" "public" {

  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id

}

Next Step: Add the Security Group

Append this to the end of main.tf.

############################################
# Security Group
############################################

resource "aws_security_group" "ec2_sg" {

  name        = "terraform-lab-sg"
  description = "Security Group for IAM Lab"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "SSH"
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

  tags = {
    Name = "terraform-lab-sg"
  }

}


WS won't know what inbound or outbound traffic is allowed.

This Security Group allows:

Inbound: SSH (TCP 22)
Outbound: All traffic (needed so the instance can reach AWS services, download packages, etc.)
After Adding It

Run:

terraform fmt
terraform validate

Your terraform plan shows:

Plan: 9 to add, 0 to change, 0 to destroy.

Final Step Before Deployment

Now we'll create the EC2 instance in ec2.tf.

We'll also use a data source to fetch the latest Amazon Linux 2023 AMI instead of hardcoding an AMI ID.

Step 1: Add the AMI data source (if you don't already have one)

In main.tf (or data.tf if you later create one):

data "aws_ami" "amazon_linux" {

  most_recent = true

  owners = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}
Step 2: Create ec2.tf
resource "aws_instance" "iam_lab" {

  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = "t2.micro"

  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]

  iam_instance_profile   = aws_iam_instance_profile.ec2_profile.name

  user_data = file("${path.module}/user-data.sh")

  tags = {
    Name = "terraform-iam-lab"
  }

}

Why Each Parameter Matters
Parameter	                  Purpose
ami	                          Operating system image
instance_type	                  EC2 size (Free Tier: t2.micro)
subnet_id	                  Which subnet to launch into
vpc_security_group_ids	          Firewall rules
iam_instance_profile	          Attaches the IAM Role to the EC2
user_data	                  Executes your startup script on first boot
tags	                          Makes the instance easier to identify

The key line for this lab is:

iam_instance_profile = aws_iam_instance_profile.ec2_profile.name

This is where everything you've learned about IAM comes together.

After Adding It

Run:

terraform fmt
terraform validate
terraform plan

One Small Improvement

Since this is your IAM Authentication Lab, I also recommend adding these outputs before we deploy:

Create outputs.tf:

output "instance_id" {
  value = aws_instance.iam_lab.id
}

output "public_ip" {
  value = aws_instance.iam_lab.public_ip
}

output "iam_role" {
  value = aws_iam_role.ec2_role.name
}

output "instance_profile" {
  value = aws_iam_instance_profile.ec2_profile.name
}

output "vpc_id" {
  value = aws_vpc.main.id
}

These will make the verification steps much easier after deployment.

Final Pre-Apply Checklist
Check	Status
Provider	✅
Variables	✅
VPC	✅
Public Subnet	✅
Internet Gateway	✅
Route Table	✅
Security Group	✅
AMI Data Source	✅
IAM Role	✅
Trust Policy	✅
Permission Policy	✅
Instance Profile	✅
EC2	✅
User Data	✅
Outputs	⏳ Add before apply
After terraform apply

This is the verification sequence we'll follow:

Step 1

Verify the EC2 is running:

terraform output
Step 2

SSH to the instance:

ssh -i <key> ec2-user@<public-ip>

(or ubuntu@ if you switch back to Ubuntu AMIs)

Step 3

Verify the IAM Role is attached:

aws sts get-caller-identity

This proves the instance has obtained temporary credentials through STS.

Step 4

Inspect the Instance Metadata Service (IMDS):

curl http://169.254.169.254/latest/meta-data/

Then:

curl http://169.254.169.254/latest/meta-data/iam/security-credentials/

This should return the attached IAM role name.

Step 5

Retrieve the temporary credentials (for learning only):

curl http://169.254.169.254/latest/meta-data/iam/security-credentials/<role-name>

We'll examine the JSON and identify:

AccessKeyId
SecretAccessKey
Token
Expiration

This will complete the authentication flow you've been studying:

EC2
   │
   ▼
Instance Profile
   │
   ▼
IAM Role
   │
   ▼
Trust Policy
   │
   ▼
STS
   │
   ▼
Temporary Credentials
   │
   ▼
IMDS
   │
   ▼
AWS SDK
   │
   ▼
Application
One last recommendation

Before typing terraform apply, save a copy of the plan:

=====================================================================================================

These are the temporary credentials issued by AWS STS.

Also Add a Variable (Recommended)

In variables.tf:

variable "key_name" {
  description = "AWS EC2 Key Pair name"
  type        = string
}

In terraform.tfvars:

key_name = "my-key1"

Then in ec2.tf:

key_name = var.key_name

This is a better practice than hardcoding it.



Once I verify your ec2.tf, we'll run:

terraform apply


🎯 Now Let's Verify the IAM Authentication Flow

This is the real purpose of today's lab.

Step 1: Check if AWS CLI is installed

Run:

aws --version

If installed, you'll see something like:

aws-cli/2.x.x

If not, we'll install it.

Step 2: Verify the IAM Role

Run:

aws sts get-caller-identity
Expected Output
{
  "UserId": "...",
  "Account": "123456789012",
  "Arn": "arn:aws:sts::123456789012:assumed-role/terraform-lab-ec2-role/..."
}

The important part is:

assumed-role/terraform-lab-ec2-role

This proves:

EC2
   │
   ▼
Instance Profile
   │
   ▼
IAM Role
   │
   ▼
STS
   │
   ▼
Temporary Credentials

is working.

Step 3: Verify IMDSv2

Your EC2 console already showed:

IMDSv2: Required

So we must first obtain a token.

Run:

TOKEN=$(curl -X PUT \
"http://169.254.169.254/latest/api/token" \
-H "X-aws-ec2-metadata-token-ttl-seconds: 21600")

Then:

echo $TOKEN

You should see a long token string.

Step 4: Read Metadata
curl -H "X-aws-ec2-metadata-token: $TOKEN" \
http://169.254.169.254/latest/meta-data/

Look for:

ami-id
hostname
instance-id
iam
network
security-groups

The iam directory confirms an Instance Profile is attached.

Step 5: Read the IAM Role Name
curl -H "X-aws-ec2-metadata-token: $TOKEN" \
http://169.254.169.254/latest/meta-data/iam/security-credentials/

Expected:

terraform-lab-ec2-role
Step 6: View Temporary Credentials

Now use the role name returned above:

curl -H "X-aws-ec2-metadata-token: $TOKEN" \
http://169.254.169.254/latest/meta-data/iam/security-credentials/terraform-lab-ec2-role

You'll see JSON similar to:

{
  "AccessKeyId": "...",
  "SecretAccessKey": "...",
  "Token": "...",
  "Expiration": "..."
}

Don't worry about the actual values—we're interested in understanding what they represent.

🧠 Engineering Understanding

After these commands, you'll have verified the entire authentication flow:

Application
      │
      ▼
AWS SDK
      │
      ▼
IMDSv2
      │
      ▼
Temporary Credentials
      │
      ▼
STS
      │
      ▼
IAM Role
      │
      ▼
Instance Profile
      │
      ▼
EC2

This is one of the most important AWS concepts for cloud engineers, DevOps engineers, and platform engineers.

Next Goal

Run the commands in order and share the outputs:

aws --version
aws sts get-caller-identity
IMDS token generation
IAM role name from metadata

What Actually Happened Behind the Scenes?

Let's walk through it step by step.

1. EC2 Booted
        │
        ▼
2. Instance Profile Attached
        │
        ▼
3. IAM Role Found
        │
        ▼
4. Trust Policy Checked
        │
        ▼
5. STS Issued Temporary Credentials
        │
        ▼
6. IMDS Stored Credentials
        │
        ▼
7. AWS CLI Requested Credentials
        │
        ▼
8. STS Verified Identity
        │
        ▼
9. You Received:
   assumed-role/terraform-lab-ec2-role

That is exactly what you verified today.

One More Verification
