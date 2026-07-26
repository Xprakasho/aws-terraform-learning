
Lab Objective

Build a reusable IAM Role module and integrate it with the Compute module so every EC2 instance receives an IAM Role automatically.

Goal

Create reusable IAM Role module
Attach AWS managed policy
Create IAM Instance Profile
Connect IAM module to Compute module
Continue following modular infrastructure design
Repository Structure

Before today's lab

modules/

network/
security-group/
key-pair/
compute/

After today's lab

modules/

network/
security-group/
key-pair/
iam-role/
compute/
Why IAM Role?

Without IAM Role

EC2
 │
 └── No AWS Identity

EC2 cannot securely access:

S3
CloudWatch
Systems Manager
Parameter Store
Secrets Manager

With IAM Role

EC2
 │
 ▼
IAM Instance Profile
 │
 ▼
IAM Role
 │
 ▼
Policies

Now AWS provides temporary credentials automatically.

No Access Keys are stored on EC2.

Important AWS Concepts
IAM Role

Defines

What permissions AWS should grant.

Example

Read S3
CloudWatch
SSM
Secrets Manager
Trust Policy

Defines

Who is allowed to use this Role.

Our Trust Policy

Service = ec2.amazonaws.com

Meaning

Only EC2 instances
can assume this Role.
IAM Instance Profile

Very important interview concept.

EC2 cannot attach an IAM Role directly.

Instead

EC2
 │
 ▼
Instance Profile
 │
 ▼
IAM Role
IAM Role Module Resources

Inside

modules/iam-role/

Created

aws_iam_role

↓

aws_iam_role_policy_attachment

↓

aws_iam_instance_profile

Only three resources

Simple and reusable.

Why AmazonSSMManagedInstanceCore?

We attached

AmazonSSMManagedInstanceCore

Reason

Allows EC2 to communicate with

AWS Systems Manager
Session Manager
Run Command
Inventory

Very common production policy.

Root Module Changes

Added new module

module "iam_role" {

  source = "./modules/iam-role"

  role_name = var.role_name

}

Added new variable

role_name

Added

terraform.tfvars

role_name = "terraform-lab-role"
Compute Module Changes
Before
AMI

Subnet

Key Pair

After

AMI

Subnet

Key Pair

IAM Instance Profile

Added variable

variable "iam_instance_profile"

Added

iam_instance_profile = var.iam_instance_profile
Module Communication

Network Module

↓

Subnet ID

↓

Compute Module

Security Group Module

↓

Security Group ID

↓

Compute Module

Key Pair Module

↓

Key Name

↓

Compute Module

IAM Role Module

↓

Instance Profile Name

↓

Compute Module

Final Flow

Network
     │
     ▼
Subnet

Security Group
     │
     ▼
Security Group ID

Key Pair
     │
     ▼
Key Name

IAM Role
     │
     ▼
Instance Profile

            │
            ▼

      Compute Module

            │
            ▼

      EC2 Instances
Terraform State

After Apply

module.network

module.security_group

module.key_pair

module.iam_role

module.compute

Everything organized by module.

Very easy to troubleshoot.

Validation Process

Always follow

terraform fmt

terraform validate

terraform plan

terraform apply

terraform output

terraform state list

This should become your standard workflow.

Engineering Design Decision

We intentionally kept only five reusable modules.

modules/

network/

security-group/

key-pair/

iam-role/

compute/

We did NOT create modules like

internet-gateway/

route-table/

instance-profile/

policy-attachment/

Reason

Too much complexity.

Small infrastructure should remain simple.

Best Practice Learned Today

Each module should have one responsibility.

Module	Responsibility
Network	Networking
Security Group	Firewall
Key Pair	SSH Access
IAM Role	AWS Permissions
Compute	EC2 Deployment

This is called

Single Responsibility Principle

Interview Questions
Q1. Why use IAM Role instead of IAM User for EC2?

Because IAM Roles provide temporary credentials automatically.

No access keys are stored on the EC2 instance.

Q2. Can EC2 attach an IAM Role directly?

No.

EC2 attaches an IAM Instance Profile, which contains the IAM Role.

Q3. What does the Trust Policy define?

It defines who can assume the IAM Role.

Example

ec2.amazonaws.com
Q4. Why attach AmazonSSMManagedInstanceCore?

To allow EC2 to communicate securely with AWS Systems Manager for Session Manager, Run Command, Patch Manager, and Inventory.

Q5. Why separate IAM into its own module?

Because IAM is a reusable infrastructure component with a single responsibility: managing AWS permissions. Other modules, such as Compute, consume its outputs instead of creating IAM resources themselves.

Key Takeaways

✅ Built reusable IAM Role module.

✅ Learned the difference between IAM Role and IAM Instance Profile.

✅ Connected one module's output to another module's input.

✅ Compute module now receives:

AMI
Subnet
Security Group
Key Pair
IAM Instance Profile

✅ Continued following a clean, production-style modular design.

Final Repository Structure
aws-terraform-learning/
│
├── provider.tf
├── variables.tf
├── terraform.tfvars
├── locals.tf
├── outputs.tf
├── data.tf
│
└── modules/
    ├── network/
    ├── security-group/
    ├── key-pair/
    ├── iam-role/
    └── compute/
⭐ Today's Engineering Lesson

Today's biggest lesson wasn't creating an IAM Role—it was understanding module composition.

Each child module owns one area of responsibility and exposes only the outputs that other modules need. The root module acts as the orchestrator, connecting these modules together. This makes the infrastructure easier to understand, reuse, test, and extend.

This modular approach is the same design principle you'll see in well-structured production Terraform repositories.
