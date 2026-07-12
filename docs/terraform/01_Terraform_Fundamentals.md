
## 1. What is Terraform?

Terraform is an Infrastructure as Code (IaC) tool developed by HashiCorp.

It allows infrastructure to be defined using declarative configuration files written in HCL (HashiCorp Configuration Language).

Instead of manually creating infrastructure from the AWS Console, infrastructure is defined as code.

Example:

```hcl
resource "aws_instance" "lab_ec2" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t3.micro"
}

Terraform determines what actions are required to make the real infrastructure match the desired configuration.

2. Declarative Infrastructure

Terraform uses a declarative model.

We define the desired state:

I want:

1 VPC
1 Public Subnet
1 Internet Gateway
1 Route Table
1 Security Group
3 EC2 Instances

Terraform determines how to create the infrastructure.

This is different from an imperative approach where every implementation step must be explicitly defined.

Conceptually:

Terraform Configuration
        |
        v
Desired Infrastructure State
        |
        v
Terraform compares configuration with state
        |
        v
Execution Plan
        |
        v
AWS Infrastructure
3. Terraform Core Architecture

The main components used in our project are:

Terraform Configuration (.tf files)
            |
            v
       Terraform Core
            |
            +------------------+
            |                  |
            v                  v
     Terraform State       AWS Provider
                                   |
                                   v
                              AWS APIs
                                   |
                                   v
                         AWS Infrastructure

Terraform Core reads the configuration and state.

The AWS provider communicates with AWS APIs.

4. Terraform Configuration Files

Our Foundation lab currently uses:

terraform-aws-foundation/
├── .terraform.lock.hcl
├── compute.tf
├── data.tf
├── locals.tf
├── main.tf
├── moved.tf
├── networking.tf
├── outputs.tf
├── provider.tf
├── security.tf
├── storage.tf
├── terraform.tfvars.example
├── variables.tf
└── versions.tf

Terraform reads all .tf files in the current working directory as one configuration.

The filenames are primarily for organization.

For example:

networking.tf

contains networking resources.

compute.tf

contains EC2 resources.

security.tf

contains Security Group configuration.

Terraform combines these files into one configuration.

5. Terraform Block Types

Important Terraform blocks include:

Terraform Block

Used to configure Terraform itself.

Example:

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}
Provider Block

Configures a provider.

Example:

provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile
}
Resource Block

Creates or manages infrastructure.

Example:

resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
}

Resource address:

aws_vpc.main

General format:

resource_type.resource_name
Data Block

Reads information from an existing system.

Example:

data "aws_ami" "ubuntu" {
  most_recent = true

  owners = ["099720109477"]
}

Data source address:

data.aws_ami.ubuntu
Variable Block

Defines an input variable.

Example:

variable "aws_region" {
  description = "AWS Region"
  type        = string
}
Output Block

Displays or exports information from Terraform.

Example:

output "vpc_id" {
  value = aws_vpc.main.id
}
Locals Block

Defines reusable local expressions.

Example:

locals {
  common_tags = {
    Project   = "terraform-aws-lab"
    ManagedBy = "Terraform"
  }
}
6. Terraform Provider

A provider is a plugin that allows Terraform to communicate with an external API.

Examples include:

AWS
Azure
Google Cloud
Kubernetes
GitHub
Docker

Our project uses the AWS provider:

required_providers {
  aws = {
    source  = "hashicorp/aws"
    version = "~> 6.0"
  }
}

Provider source:

hashicorp/aws

Provider constraint:

~> 6.0

This permits compatible AWS provider versions within the specified constraint.

7. Terraform Provider Installation

When we run:

terraform init

Terraform:

Initializes the working directory.
Downloads required providers.
Initializes the backend.
Creates or updates .terraform.lock.hcl.
Prepares modules if modules are configured.

The downloaded provider files are stored under:

.terraform/

The .terraform/ directory is local working data and should not be committed to Git.

8. Terraform Dependency Lock File

Terraform creates:

.terraform.lock.hcl

This file records the selected provider versions and package checksums.

Example:

provider "registry.terraform.io/hashicorp/aws" {
  version     = "6.53.0"
  constraints = "~> 6.0"
}

Important distinction:

provider.tf / required_providers
        |
        v
Defines allowed provider versions

.terraform.lock.hcl
        |
        v
Records the selected provider version

The lock file should normally be committed to Git.

9. Terraform Standard Workflow

The core workflow is:

Write
  |
  v
terraform fmt
  |
  v
terraform validate
  |
  v
terraform plan
  |
  v
Review Plan
  |
  v
terraform apply
  |
  v
Verify Infrastructure
  |
  v
terraform destroy
10. terraform fmt

Command:

terraform fmt

Purpose:

Formats Terraform configuration into the standard HCL style.

It improves:

readability
consistency
code review quality

We should run it after modifying Terraform code.

11. terraform validate

Command:

terraform validate

Purpose:

Checks whether the Terraform configuration is syntactically valid and internally consistent.

Example:

Success! The configuration is valid.

Important:

Successful validation does not mean infrastructure has been created.

12. terraform plan

Command:

terraform plan

Terraform compares:

Configuration
      +
Current State
      +
Provider Information
      |
      v
Execution Plan

Example:

Plan: 10 to add, 0 to change, 0 to destroy.

Terraform plan symbols:

+   Create

~   Update in-place

-   Destroy

-/+ Replace

Always inspect the execution plan before applying changes.

13. terraform apply

Command:

terraform apply

Terraform:

Creates an execution plan.
Requests confirmation.
Calls provider APIs.
Creates or modifies infrastructure.
Updates Terraform state.

Example:

Apply complete! Resources: 8 added, 0 changed, 0 destroyed.
14. terraform destroy

Command:

terraform destroy

Terraform plans the destruction of resources managed by the current state.

After successful destruction:

Terraform State
      |
      v
Managed resources removed

Running:

terraform state list

may return no resources after a complete destroy.

15. Our AWS Foundation Architecture

Our Terraform Foundation lab creates infrastructure similar to:

AWS
 |
 v
VPC
 |
 +-----------------------------+
 |                             |
 v                             v
Internet Gateway          Public Subnet
                               |
                               v
                         Route Table
                               |
                               v
                         Security Group
                               |
                               v
                    +----------+----------+
                    |          |          |
                    v          v          v
                   web        app         db
                   EC2        EC2         EC2

The EC2 instances are created using:

for_each = var.instances

Current instance configuration:

web -> t3.micro
app -> t3.micro
db  -> t3.small
16. Resource References

Terraform resources can reference attributes from other resources.

Example:

subnet_id = aws_subnet.public.id

This means:

EC2 Instance
     |
     | requires subnet ID
     v
aws_subnet.public

Terraform uses these references to determine resource dependencies.

17. Implicit Dependencies

Example:

resource "aws_subnet" "public" {
  vpc_id = aws_vpc.main.id
}

Because the subnet references:

aws_vpc.main.id

Terraform knows:

Create VPC
    |
    v
Create Subnet

This is called an implicit dependency.

Explicit depends_on is not required when Terraform can determine the dependency from resource references.

18. Terraform Dependency Graph

Terraform creates a dependency graph internally.

Example:

VPC
 |
 +------> Internet Gateway
 |
 +------> Subnet
            |
            v
       Route Table Association
            |
            v
           EC2

VPC
 |
 v
Security Group
 |
 v
EC2

This graph allows Terraform to:

determine creation order
determine destruction order
execute independent operations in parallel
19. Important Files: Commit vs Ignore

Files that should normally be committed:

*.tf
.terraform.lock.hcl
terraform.tfvars.example
README.md
documentation

Files that should not normally be committed:

.terraform/
*.tfstate
*.tfstate.*
terraform.tfvars
crash logs
sensitive variable files

Our repository uses .gitignore to protect these local files.

20. Foundation Commands Cheat Sheet
# Initialize Terraform
terraform init

# Format configuration
terraform fmt

# Validate configuration
terraform validate

# Preview infrastructure changes
terraform plan

# Create or modify infrastructure
terraform apply

# Destroy managed infrastructure
terraform destroy

# Show Terraform version
terraform version

# List resources in state
terraform state list

# Show current workspace
terraform workspace show

# Show Terraform outputs
terraform output
21. Key Foundation Lessons
Lesson 1

Terraform is declarative.

We define the desired infrastructure state.

Lesson 2

All .tf files in the same working directory form one Terraform configuration.

Lesson 3

Providers communicate with external APIs.

For our project:

Terraform
    |
    v
AWS Provider
    |
    v
AWS API
    |
    v
AWS Infrastructure
Lesson 4

Resource references automatically create dependencies.

Example:

vpc_id = aws_vpc.main.id
Lesson 5

Always inspect terraform plan before terraform apply.

Lesson 6

Terraform state is critical.

Terraform uses state to map configuration resources to real infrastructure.

Lesson 7

Do not commit state files, real tfvars files, or .terraform/ to Git.

Lesson 8

Commit .terraform.lock.hcl to maintain consistent provider selections.

22. Quick Interview Revision

Q: What is Terraform?

Terraform is a declarative Infrastructure as Code tool used to provision and manage infrastructure through configuration files.

Q: What is a Terraform provider?

A provider is a plugin that allows Terraform to communicate with an external API such as AWS, Azure, Kubernetes, or GitHub.

Q: What does terraform init do?

It initializes the working directory, installs providers and modules, initializes the backend, and creates or updates the dependency lock file.

Q: What is the difference between terraform validate and terraform plan?

terraform validate checks configuration syntax and internal consistency. terraform plan evaluates the desired configuration against current state and provider information to determine infrastructure changes.

Q: Should .terraform.lock.hcl be committed?

Yes, it should normally be committed because it records selected provider versions and checksums.

Q: Should terraform.tfstate be committed?

No. State may contain sensitive information and should be stored using an appropriate state backend rather than committed to source control.

Q: What is an implicit dependency?

An implicit dependency occurs when one Terraform resource references an attribute of another resource, allowing Terraform to automatically determine the dependency order.

23. Foundation Status

Topics covered in the complete Foundation phase:

Terraform Workflow
Providers
Provider Version Constraints
Dependency Lock File
Resources
Data Sources
Variables
tfvars
Outputs
Resource References
Dependencies
Locals
merge()
count
count.index
for_each
each.key
each.value
set(string)
map(string)
map(object)
For Expressions
Splat Expressions
Dynamic Blocks
moved Blocks
State Basics
Git Integration
Terraform .gitignore
