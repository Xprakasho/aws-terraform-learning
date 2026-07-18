
# Terraform Modules Foundation

## Objective

Learn how to organize Terraform configurations into reusable modules by separating infrastructure into logical building blocks.

---

# What is a Terraform Module?

A Terraform module is a collection of Terraform configuration files that work together to perform a specific task.

Every Terraform configuration is a module.

- Root Module → The directory where Terraform commands are executed.
- Child Module → A reusable module called from the root module.

Example:

```
Root Module
    │
    ├── Network Module
    ├── Compute Module
    └── Database Module
```

---

# Why Do We Need Modules?

Without modules:

```
main.tf

VPC
Subnet
Internet Gateway
Route Table
Security Group
EC2
IAM
S3
Load Balancer
```

One large file becomes difficult to maintain.

Problems:

- Duplicate code
- Hard to reuse
- Difficult for teams
- Error-prone
- Poor scalability

Modules solve these problems by making Terraform reusable.

---

# Module Architecture

```
terraform-modules/

├── main.tf
├── variables.tf
├── outputs.tf
├── provider.tf
│
└── modules/
      ├── network/
      │      main.tf
      │      variables.tf
      │      outputs.tf
      │
      └── compute/
             main.tf
             variables.tf
             outputs.tf
```

---

# Root Module Responsibilities

The Root Module is the entry point.

Responsibilities

- Calls child modules
- Passes input variables
- Connects modules together
- Exposes final outputs

Example

```hcl
module "network" {
  source = "./modules/network"

  vpc_cidr          = var.vpc_cidr
  subnet_cidr       = var.subnet_cidr
  availability_zone = var.availability_zone
}

module "compute" {
  source = "./modules/compute"

  ami_id        = "ami-xxxxxxxx"
  subnet_id     = module.network.subnet_id
  instance_type = "t3.micro"
  instance_name = "Terraform-Module-EC2"
}
```

---

# Network Module

Resources Created

- aws_vpc
- aws_subnet
- aws_internet_gateway
- aws_route_table
- aws_route_table_association

Outputs

- VPC ID
- Subnet ID
- Internet Gateway ID
- Route Table ID

Purpose

Provide networking resources to other modules.

---

# Compute Module

Resources Created

- aws_instance

Inputs

- AMI ID
- Instance Type
- Subnet ID
- Instance Name

Outputs

- Instance ID
- Public IP
- Private IP

Purpose

Deploy EC2 instances without knowing how the network was created.

---

# Module Communication

Modules communicate using outputs.

Example

Network Module

```
output "subnet_id" {
  value = aws_subnet.public.id
}
```

Root Module

```
subnet_id = module.network.subnet_id
```

Compute Module

```
variable "subnet_id" {}

subnet_id = var.subnet_id
```

This keeps modules independent and reusable.

---

# Terraform Dependency Graph

Terraform automatically builds dependencies.

```
Network Module
      │
      ▼
Outputs
      │
      ▼
Root Module
      │
      ▼
Inputs
      │
      ▼
Compute Module
```

No explicit `depends_on` is required because Terraform detects the dependency through references.

---

# Module Namespace in State

Without Modules

```
aws_vpc.main
aws_instance.web
```

With Modules

```
module.network.aws_vpc.main

module.network.aws_subnet.public

module.compute.aws_instance.this
```

Each module has its own namespace.

Verify:

```bash
terraform state list
```

Example output:

```
module.compute.aws_instance.this

module.network.aws_vpc.main

module.network.aws_subnet.public

module.network.aws_internet_gateway.igw

module.network.aws_route_table.public

module.network.aws_route_table_association.public
```

---

# Outputs

Terraform displayed:

```
instance_id

public_ip

private_ip

vpc_id

subnet_id

internet_gateway_id

route_table_id
```

These outputs came from child modules and were exposed by the root module.

---

# Commands Used

Initialize

```bash
terraform init
```

Validate

```bash
terraform validate
```

Format

```bash
terraform fmt -recursive
```

Plan

```bash
terraform plan
```

Apply

```bash
terraform apply
```

View State

```bash
terraform state list
```

Destroy

```bash
terraform destroy
```

---

# Troubleshooting Performed During Lab

## 1. Module Not Installed

Error

```
Module not installed
```

Resolution

```bash
terraform init
```

---

## 2. Missing Variable Values

Terraform prompted for:

```
availability_zone
```

Reason

Values were only in `terraform.tfvars.example`.

Resolution

```
cp terraform.tfvars.example terraform.tfvars
```

or provide values manually.

---

## 3. Free Tier Instance Error

Error

```
InvalidParameterCombination

Instance type is not eligible for Free Tier
```

Resolution

Changed

```
t2.micro
```

to

```
t3.micro
```

---

# Advantages of Modules

- Code Reuse
- Standardization
- Easier Maintenance
- Smaller Files
- Better Team Collaboration
- Independent Development
- Easier Testing
- Production Ready

---

# Enterprise Module Layout

```
modules/

network/

security/

compute/

database/

iam/

monitoring/

dns/

storage/

logging/
```

Projects simply reuse these modules.

---

# Interview Questions

### Q1. What is a Terraform Module?

A reusable collection of Terraform resources grouped together to perform a specific function.

---

### Q2. Difference between Root Module and Child Module?

Root Module

- Entry point
- Executes Terraform commands
- Calls modules

Child Module

- Reusable
- Contains resources
- Invoked by root module

---

### Q3. How do modules communicate?

Through outputs and input variables.

---

### Q4. How does Terraform know module execution order?

Terraform automatically builds a dependency graph using references such as:

```hcl
subnet_id = module.network.subnet_id
```

---

### Q5. How do modules appear in Terraform state?

Example

```
module.compute.aws_instance.this

module.network.aws_vpc.main
```

---

### Q6. Why are modules important?

They make Terraform reusable, maintainable, scalable, and suitable for team collaboration.

---

# Key Takeaways

- Modules are reusable Terraform packages.
- The Root Module orchestrates child modules.
- Child modules expose outputs.
- Other modules consume those outputs as inputs.
- Terraform automatically creates the dependency graph.
- Modules namespace resources in the Terraform state.
- Modules are the foundation of production-grade Terraform repositories.
