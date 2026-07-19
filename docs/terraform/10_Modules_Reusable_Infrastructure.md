
# Terraform 09 – Modules (Reusable Infrastructure)

## Objective

Learn how to organize Terraform code into reusable modules, pass data between modules, and instantiate a module multiple times using `for_each`.

---

# 1. What is a Terraform Module?

A Terraform module is a collection of Terraform configuration files that work together to provision a specific piece of infrastructure.

Examples:

- VPC Module
- EC2 Module
- EKS Module
- RDS Module

Instead of copying code, we reuse modules.

---

# 2. Module Types

## Root Module

The directory where Terraform commands are executed.

Example:

```
terraform-modules/
│
├── main.tf
├── variables.tf
├── outputs.tf
```

Only one Root Module exists.

---

## Child Module

Reusable Terraform code.

Example

```
modules/
├── network/
└── compute/
```

Child modules are never executed directly.

The Root Module calls them.

---

# 3. Project Structure

```
terraform-modules/

├── main.tf
├── variables.tf
├── outputs.tf
├── terraform.tfvars

└── modules

    ├── network
    │
    │── main.tf
    │── variables.tf
    │── outputs.tf

    └── compute

        ├── main.tf
        ├── variables.tf
        ├── outputs.tf
```

---

# 4. Network Module

Responsible for creating:

- VPC
- Public Subnet
- Internet Gateway
- Route Table
- Route Association

Outputs:

```
vpc_id
subnet_id
internet_gateway_id
route_table_id
```

These outputs are consumed by other modules.

---

# 5. Compute Module

Responsible only for EC2 creation.

Inputs:

```
ami_id
instance_type
subnet_id
instance_name
```

Outputs

```
instance_id
public_ip
private_ip
```

Notice that the compute module knows nothing about VPC creation.

It only receives a subnet ID.

This keeps the module reusable.

---

# 6. Root Module

The Root Module connects all child modules.

Example

```
module "network" {

    source = "./modules/network"

    ...

}

module "compute" {

    source = "./modules/compute"

    ...

}
```

Think of the Root Module as the orchestrator.

---

# 7. Passing Outputs Between Modules

Network Module exports

```
subnet_id
```

Root Module passes it into Compute Module

```
subnet_id = module.network.subnet_id
```

This is called Module Composition.

---

# 8. Creating Multiple Module Instances

Initially

```
module "compute"
```

creates

```
1 EC2
```

After introducing

```
for_each = var.instances
```

Terraform creates

```
module.compute["web"]

module.compute["app"]

module.compute["db"]
```

from the same reusable module.

---

# 9. Variable Map

```
instances = {

    web = {
        instance_type = "t3.micro"
    }

    app = {
        instance_type = "t3.micro"
    }

    db = {
        instance_type = "t3.micro"
    }

}
```

Each key becomes a separate module instance.

---

# 10. Using each.key and each.value

```
instance_name = each.key

instance_type = each.value.instance_type
```

Produces

```
web
app
db
```

without writing three different module blocks.

---

# 11. Output Changes

Before

```
instance_id

↓

i-123456
```

After

```
instance_id = {

    web = ...

    app = ...

    db = ...

}
```

Reason

```
module.compute

↓

Object

↓

web

app

db
```

The Root Module now owns multiple module instances.

---

# 12. Using For Expressions

Example

```
output "instance_id" {

    value = {

        for k, v in module.compute :

        k => v.instance_id

    }

}
```

This loops through every module instance and creates a map.

---

# 13. State Layout

Before

```
module.compute.aws_instance.this
```

After

```
module.compute["web"].aws_instance.this

module.compute["app"].aws_instance.this

module.compute["db"].aws_instance.this
```

Terraform stores each module instance separately.

---

# 14. Common Mistakes

## Mistake 1

Putting

```
module "compute"
```

inside

```
modules/compute/main.tf
```

Wrong.

Only the Root Module calls child modules.

---

## Mistake 2

Using

```
module.compute.instance_id
```

after introducing

```
for_each
```

Now

```
module.compute
```

is an object.

Use a `for` expression instead.

---

## Mistake 3

Hardcoding dependencies inside child modules.

Instead pass everything through variables.

---

# 15. Commands Used

```
terraform fmt

terraform init

terraform validate

terraform plan

terraform apply

terraform state list

terraform output

terraform destroy
```

---

# 16. Interview Questions

## Q1. What is a Terraform Module?

Reusable Terraform configuration.

---

## Q2. Difference between Root Module and Child Module?

Root Module executes Terraform.

Child Modules are reusable building blocks.

---

## Q3. Why use Modules?

- Reusability
- Maintainability
- Standardization
- Easier collaboration

---

## Q4. What is Module Composition?

Passing outputs from one module into another.

Example

```
module.network.subnet_id
```

↓

```
module.compute.subnet_id
```

---

## Q5. Can a Module create multiple resources?

Yes.

Using

```
count
```

or

```
for_each
```

---

## Q6. What happens when using for_each on Modules?

Terraform creates multiple module instances.

Example

```
module.compute["web"]

module.compute["app"]

module.compute["db"]
```

---

## Q7. Why did outputs change to maps?

Because the module became an object containing multiple module instances.

---

## Q8. What is a For Expression?

A Terraform expression used to transform collections.

Example

```
for k, v in module.compute :
k => v.instance_id
```

---

# 17. Final Mental Model

```
                    Root Module
                         │
        ┌────────────────┴────────────────┐
        │                                 │
        │                                 │
   Network Module                  Compute Module
        │                                 │
        │                                 │
        ▼                                 ▼
      VPC                      module.compute["web"]

      Subnet                   module.compute["app"]

      IGW                      module.compute["db"]

      Route Table
```

The Root Module orchestrates.

Child Modules build infrastructure.

Modules communicate through Inputs and Outputs.

The same module can be instantiated multiple times using `for_each`.
