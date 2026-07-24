
Objective

This lab extends the reusable Terraform module architecture by introducing shared configuration and dynamic resource creation.

Instead of hardcoding values inside individual modules, the root module becomes the central place for:

Common tags
Region
Owner information
Environment
Project name
Dynamic AMI lookup
Multiple EC2 instance definitions

Child modules become generic and reusable by accepting values from the root module.

Architecture
Root Module
│
├── provider.tf
├── variables.tf
├── locals.tf
├── data.tf
├── outputs.tf
├── main.tf
│
├── Network Module
│
├── Security Group Module
│
└── Compute Module
What Changed in the Root Module
1. Added locals.tf

Created a centralized location for common values.

Example:

locals {

  common_tags = {
    Environment = "lab"
    Project     = "terraform-modules"
    Owner       = "Om"
    ManagedBy   = "Terraform"
  }

}

Purpose:

Avoid repeating tags
Maintain consistency
Update tags in one place
2. Added data.tf

Replaced the hardcoded AMI.

Old approach

ami_id = "ami-052355af2a014bd2c"

New approach

data "aws_ami" "ubuntu" {

  most_recent = true

  owners = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

}

Purpose:

Always deploy the latest Ubuntu AMI
Avoid manual AMI updates
Improve portability
3. Updated provider.tf

Added default tags.

provider "aws" {

  region = "us-east-1"

  default_tags {

    tags = local.common_tags

  }

}

Result:

Every AWS resource automatically receives:

Environment
Project
Owner
ManagedBy
4. Updated main.tf
Compute Module

Old

module "compute" {

    ami_id = "ami-xxxxxxxx"

}

New

module "compute" {

    ami_id = data.aws_ami.ubuntu.id

}

Purpose

Use dynamically discovered AMI.

Multiple EC2 Instances

Added

for_each = var.instances

Now Terraform creates:

app

db

web

without duplicating module blocks.

Changes in Child Modules
Network Module

No functional changes.

The module remains reusable.

Inputs:

VPC CIDR
Subnet CIDR
Availability Zone

Outputs:

VPC ID
Subnet ID
Route Table ID
Internet Gateway ID
Compute Module

No structural changes.

The module still accepts:

ami_id

instance_type

subnet_id

instance_name

The root module now supplies these values dynamically.

The child module does not know:

which AMI
how many instances
environment
owner

This keeps the module generic.

Security Group Module

Created a reusable Security Group module.

Responsibilities:

Create Security Group
Allow SSH
Allow HTTP
Allow HTTPS
Allow all outbound traffic

Outputs:

security_group_id

Future compute modules can consume this output.

Module Communication
                 Root Module
                      │
        ┌─────────────┼──────────────┐
        │             │              │
        ▼             ▼              ▼
    Network      Security Group   Compute
        │             │              ▲
        │             │              │
        └─────────────┴──────────────┘

The root module coordinates all modules.

Child modules never communicate directly with each other.

Important Design Decision

We intentionally kept:

locals
data sources
provider
variables

inside the Root Module.

Why?

Because these values represent environment-specific configuration.

Child modules should remain reusable.

Terraform Commands
terraform fmt

terraform validate

terraform plan

terraform apply

terraform output

terraform state list
Verification

Verified:

Latest Ubuntu AMI selected automatically
Three EC2 instances created
Shared tags applied
Security Group created
VPC created
Route Table created
Outputs generated correctly
State file updated correctly
Key Learning
Before
Hardcoded AMI

Repeated Tags

Single EC2

No Shared Configuration
After
Dynamic AMI

Shared Tags

Reusable Modules

Multiple EC2

Centralized Configuration

Cleaner Root Module
Interview Questions
Why keep locals in the root module?

Because environment-specific configuration should be centralized. Child modules should remain generic and reusable.

Why use a data source for the AMI?

To avoid hardcoding AMI IDs and always deploy the latest approved image automatically.

Why use default_tags?

To ensure all AWS resources receive consistent metadata without repeating tag blocks in every resource.

Why use for_each with modules?

To create multiple module instances from a single definition, reducing duplication and improving scalability.

Engineering Takeaway

This lab demonstrates a production-style Terraform architecture where the root module owns environment configuration, while child modules focus only on provisioning resources. Shared values such as tags, AMIs, and instance definitions are centralized in the root, making the infrastructure easier to maintain, scale, and reuse across different environments
