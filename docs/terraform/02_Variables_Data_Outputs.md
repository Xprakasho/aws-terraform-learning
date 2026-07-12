
# Terraform Variables, Data Sources, and Outputs

## 1. Purpose of This Note

This note covers three important Terraform concepts:

- Input Variables
- Data Sources
- Outputs

These concepts control how information enters, moves through, and leaves a Terraform configuration.

The basic flow is:

```text
Input Variables
      |
      v
Terraform Configuration
      |
      +------> Resources
      |
      +------> Data Sources
      |
      v
Outputs
```

In our AWS Foundation lab, we used all three concepts.

---

# 2. Terraform Input Variables

Variables allow values to be passed into Terraform configurations.

Without variables:

```hcl
resource "aws_instance" "lab_ec2" {
  instance_type = "t3.micro"
}
```

The value is hardcoded.

With variables:

```hcl
resource "aws_instance" "lab_ec2" {
  instance_type = var.instance_type
}
```

Now the configuration is reusable.

---

# 3. Variable Declaration

Variables are normally declared in:

```text
variables.tf
```

Example:

```hcl
variable "aws_region" {
  description = "AWS Region"
  type        = string
}
```

This block defines the variable.

It does not necessarily provide the value.

General syntax:

```hcl
variable "variable_name" {
  description = "Description"
  type        = data_type
}
```

---

# 4. Variable Reference

A variable is referenced using:

```text
var.variable_name
```

Example:

```hcl
provider "aws" {
  region = var.aws_region
}
```

Flow:

```text
variable "aws_region"
        |
        v
var.aws_region
        |
        v
provider "aws"
```

---

# 5. terraform.tfvars

The actual values can be stored in:

```text
terraform.tfvars
```

Example:

```hcl
aws_region  = "us-east-1"
aws_profile = "om-Devops"
```

Terraform automatically loads:

```text
terraform.tfvars
```

Our flow becomes:

```text
variables.tf
Defines the variable
        |
        v
terraform.tfvars
Provides the value
        |
        v
var.aws_region
        |
        v
Terraform Resource or Provider
```

Important distinction:

```text
variables.tf
    =
What input does the configuration accept?

terraform.tfvars
    =
What values are provided to those inputs?
```

---

# 6. terraform.tfvars.example

The real:

```text
terraform.tfvars
```

should normally not be committed to Git.

Instead, we created:

```text
terraform.tfvars.example
```

Example:

```hcl
aws_region  = "us-east-1"
aws_profile = "your-aws-profile"
```

The purpose is:

```text
terraform.tfvars
        |
        +--> Real local values
        +--> Git ignored

terraform.tfvars.example
        |
        +--> Example values
        +--> Safe to commit
```

A user cloning the repository can run:

```bash
cp terraform.tfvars.example terraform.tfvars
```

and then modify the local values.

---

# 7. Variable Types

Terraform supports several data types.

Important types include:

```text
string
number
bool
list
set
map
object
tuple
```

We practiced several of these types.

---

# 8. string

Example:

```hcl
variable "aws_region" {
  type = string
}
```

Value:

```hcl
aws_region = "us-east-1"
```

---

# 9. number

Example:

```hcl
variable "instance_count" {
  type = number
}
```

Value:

```hcl
instance_count = 2
```

We used this with:

```hcl
count = var.instance_count
```

---

# 10. bool

Example:

```hcl
monitoring = false
```

The type is:

```text
bool
```

Possible values:

```text
true
false
```

---

# 11. set(string)

We first used:

```hcl
variable "instances" {
  description = "EC2 instances to create"
  type        = set(string)
}
```

Value:

```hcl
instances = ["web", "app"]
```

Used with:

```hcl
for_each = var.instances
```

For a `set(string)`:

```text
each.key   = each.value
```

Example:

```text
web

each.key   = "web"
each.value = "web"
```

This is useful when we only need unique names.

---

# 12. map(string)

We then changed the configuration to:

```hcl
variable "instances" {
  type = map(string)
}
```

Values:

```hcl
instances = {
  web = "t3.micro"
  app = "t3.micro"
  db  = "t3.small"
}
```

Now:

```text
each.key
    =
EC2 logical name

each.value
    =
EC2 instance type
```

Example:

```text
web = "t3.micro"
```

Terraform sees:

```text
each.key   = "web"
each.value = "t3.micro"
```

The resource could use:

```hcl
instance_type = each.value
```

---

# 13. map(object)

We then evolved the configuration into:

```hcl
variable "instances" {
  description = "EC2 instance configurations"

  type = map(object({
    instance_type = string
    monitoring    = bool
    environment   = string
  }))
}
```

Values:

```hcl
instances = {
  web = {
    instance_type = "t3.micro"
    monitoring    = false
    environment   = "dev"
  }

  app = {
    instance_type = "t3.micro"
    monitoring    = false
    environment   = "dev"
  }

  db = {
    instance_type = "t3.small"
    monitoring    = false
    environment   = "dev"
  }
}
```

Now:

```text
each.key
    =
web

each.value
    =
Complete object
```

Therefore:

```hcl
each.value.instance_type
each.value.monitoring
each.value.environment
```

can be accessed separately.

Example:

```hcl
resource "aws_instance" "lab_ec2" {
  for_each = var.instances

  instance_type = each.value.instance_type
  monitoring    = each.value.monitoring

  tags = {
    Name        = "Terraform-EC2-${each.key}"
    Environment = each.value.environment
  }
}
```

---

# 14. Evolution of Our Variable Design

We practiced the following progression:

```text
number
   |
   v
count
   |
   v
set(string)
   |
   v
for_each
   |
   v
map(string)
   |
   v
map(object)
```

More specifically:

```text
instance_count = 2

        ↓

count = var.instance_count

        ↓

instances = ["web", "app"]

        ↓

for_each = var.instances

        ↓

instances = {
  web = "t3.micro"
  app = "t3.micro"
}

        ↓

instances = {
  web = {
    instance_type = "t3.micro"
    monitoring    = false
    environment   = "dev"
  }
}
```

This progression made the Terraform configuration increasingly flexible.

---

# 15. Variables vs Data Sources

One of the important questions from our lab was:

> Why do we need Data Sources when we already have variables and terraform.tfvars?

The answer is:

```text
Variables
    =
Values WE provide to Terraform

Data Sources
    =
Values Terraform READS from an external system
```

Example variable:

```hcl
instance_type = var.instance_type
```

We provide:

```hcl
instance_type = "t3.micro"
```

Example data source:

```hcl
ami = data.aws_ami.ubuntu.id
```

Terraform asks AWS:

```text
Find the latest Ubuntu AMI matching these filters.
```

---

# 16. Hardcoded AMI vs Data Source

Initially, our configuration used:

```hcl
ami = var.ami_id
```

and:

```hcl
ami_id = "ami-00d4b620340d50fd3"
```

Problem:

AMI IDs can vary by:

- AWS Region
- operating system version
- architecture
- image release

The hardcoded value can become outdated.

We replaced it with a data source.

---

# 17. AWS AMI Data Source

Our `data.tf` contains an AMI data source similar to:

```hcl
data "aws_ami" "ubuntu" {
  most_recent = true

  owners = ["099720109477"]

  filter {
    name = "name"

    values = [
      "ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"
    ]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}
```

Terraform queries AWS for the AMI.

---

# 18. Data Source Address

The data source address is:

```text
data.aws_ami.ubuntu
```

Breakdown:

```text
data
 |
 +--> Data source

aws_ami
 |
 +--> Data source type

ubuntu
 |
 +--> Local Terraform name
```

To access the AMI ID:

```hcl
data.aws_ami.ubuntu.id
```

---

# 19. Resource Using a Data Source

Our EC2 resource uses:

```hcl
ami = data.aws_ami.ubuntu.id
```

Flow:

```text
AWS API
   |
   v
data.aws_ami.ubuntu
   |
   v
AMI ID
   |
   v
aws_instance.lab_ec2
```

This creates a dependency between the data lookup and EC2 configuration.

---

# 20. Resource vs Data Source

Resource:

```hcl
resource "aws_instance" "lab_ec2" {
}
```

Purpose:

```text
Create or manage infrastructure
```

Data source:

```hcl
data "aws_ami" "ubuntu" {
}
```

Purpose:

```text
Read information
```

Summary:

```text
resource
    |
    v
CREATE / MANAGE

data
    |
    v
READ
```

---

# 21. Terraform Outputs

Outputs allow Terraform to display or expose information.

Example:

```hcl
output "vpc_id" {
  value = aws_vpc.main.id
}
```

After apply:

```text
Outputs:

vpc_id = "vpc-0193894966702fe36"
```

---

# 22. Why Outputs Are Useful

Outputs are useful for:

- displaying resource information
- debugging
- passing values between modules
- exposing infrastructure IDs
- automation and CI/CD pipelines

Examples:

```text
VPC ID
Subnet ID
Public IP
Private IP
Load Balancer DNS Name
```

---

# 23. Output for a Single Resource

Example:

```hcl
output "subnet_id" {
  value = aws_subnet.public.id
}
```

This works because:

```text
aws_subnet.public
```

represents one resource instance.

---

# 24. Outputs with count

When we used:

```hcl
count = var.instance_count
```

Terraform created addresses similar to:

```text
aws_instance.lab_ec2[0]
aws_instance.lab_ec2[1]
```

We used a splat expression:

```hcl
output "instance_public_ip" {
  value = aws_instance.lab_ec2[*].public_ip
}
```

Result:

```text
instance_public_ip = [
  "3.239.15.35",
  "98.92.227.86"
]
```

The output type was a list.

---

# 25. Splat Expression

Syntax:

```text
[*]
```

Example:

```hcl
aws_instance.lab_ec2[*].public_ip
```

Conceptually:

```text
aws_instance.lab_ec2[0].public_ip
aws_instance.lab_ec2[1].public_ip

             ↓

[
  "3.239.15.35",
  "98.92.227.86"
]
```

Splat expressions are particularly convenient for list-like resource collections created with `count`.

---

# 26. Problem After Changing to for_each

We changed:

```hcl
count = var.instance_count
```

to:

```hcl
for_each = var.instances
```

The resource addresses changed.

Before:

```text
aws_instance.lab_ec2[0]
aws_instance.lab_ec2[1]
```

After:

```text
aws_instance.lab_ec2["web"]
aws_instance.lab_ec2["app"]
```

Our old output:

```hcl
aws_instance.lab_ec2[*].public_ip
```

no longer worked as intended.

Terraform returned an error similar to:

```text
Error: Unsupported attribute

This object does not have an attribute named "public_ip".
```

---

# 27. Why the Output Failed

With `for_each`, Terraform resources are represented as a map.

Conceptually:

```text
{
  web = EC2 object
  app = EC2 object
}
```

Therefore, we changed the output to a `for` expression.

---

# 28. Outputs with for_each

Correct output:

```hcl
output "instance_public_ip" {
  value = {
    for key, instance in aws_instance.lab_ec2 :
    key => instance.public_ip
  }
}
```

Result:

```text
instance_public_ip = {
  "app" = "98.92.227.86"
  "web" = "3.239.15.35"
}
```

For private IPs:

```hcl
output "instance_private_ip" {
  value = {
    for key, instance in aws_instance.lab_ec2 :
    key => instance.private_ip
  }
}
```

---

# 29. Understanding the For Expression

Expression:

```hcl
{
  for key, instance in aws_instance.lab_ec2 :
  key => instance.public_ip
}
```

Breakdown:

```text
for
 |
 +--> Start iteration

key
 |
 +--> web, app, db

instance
 |
 +--> Current EC2 resource object

in aws_instance.lab_ec2
 |
 +--> Resource map to iterate

key => instance.public_ip
 |
 +--> Build output map
```

Result:

```text
{
  web = "public-ip"
  app = "public-ip"
  db  = "public-ip"
}
```

---

# 30. List Output vs Map Output

With `count`:

```text
[
  "10.0.1.39",
  "10.0.1.91"
]
```

The IP addresses are identified by position.

With `for_each`:

```text
{
  app = "10.0.1.91"
  web = "10.0.1.39"
}
```

The IP addresses are identified by meaningful keys.

For infrastructure resources, meaningful keys are often easier to manage.

---

# 31. Important Error We Encountered

Error:

```text
Unsupported attribute
```

Configuration:

```hcl
value = aws_instance.lab_ec2[*].public_ip
```

Cause:

The EC2 resource changed from:

```text
count
```

to:

```text
for_each
```

The resource collection changed from list-like instances to a map of instances.

Fix:

```hcl
value = {
  for key, instance in aws_instance.lab_ec2 :
  key => instance.public_ip
}
```

---

# 32. Variables, Data Sources, Resources, and Outputs Together

Our complete information flow is:

```text
terraform.tfvars
        |
        v
Input Variables
        |
        +----------------------+
        |                      |
        v                      v
AWS Provider             EC2 Configuration
                               |
AWS API                         |
   |                            |
   v                            |
Data Source                     |
   |                            |
   v                            |
Latest Ubuntu AMI ID -----------+
        |
        v
EC2 Resources
        |
        v
Resource Attributes
        |
        v
Outputs
```

---

# 33. Quick Comparison

| Concept | Purpose | Example |
|---|---|---|
| Variable | Accept input | `var.aws_region` |
| tfvars | Provide variable values | `aws_region = "us-east-1"` |
| Data Source | Read external information | `data.aws_ami.ubuntu.id` |
| Resource | Create/manage infrastructure | `aws_instance.lab_ec2` |
| Output | Expose information | `instance.public_ip` |

---

# 34. Important Commands

Display all outputs:

```bash
terraform output
```

Display one output:

```bash
terraform output vpc_id
```

Inspect configuration validity:

```bash
terraform validate
```

Preview changes:

```bash
terraform plan
```

---

# 35. Interview Revision

**Q: What is the difference between variables and data sources?**

Variables receive values provided by users, tfvars files, environment variables, or other input mechanisms. Data sources retrieve information from external systems through providers.

**Q: Why did we replace the hardcoded AMI ID with a data source?**

AMI IDs can differ between regions and change as new images are released. The data source allows Terraform to query AWS for an AMI matching the required filters.

**Q: What is the difference between variables.tf and terraform.tfvars?**

`variables.tf` declares the input interface, including names and types. `terraform.tfvars` provides concrete values for those variables.

**Q: Why do we commit terraform.tfvars.example but not terraform.tfvars?**

The example file documents required input values without exposing local or sensitive configuration. The real tfvars file may contain environment-specific or sensitive values.

**Q: What is an output?**

An output exposes a value from the Terraform configuration, such as a resource ID, IP address, or DNS name.

**Q: Why did the splat expression fail after changing from count to for_each?**

`count` creates resource instances addressed numerically, while `for_each` creates a map of resource instances addressed by keys. A `for` expression is appropriate for transforming the `for_each` resource map into a keyed output map.

**Q: What is map(object)?**

It is a Terraform collection type where each map key points to a structured object containing multiple typed attributes.

---

# 36. Revision Cheat Sheet

```text
VARIABLE

Declare:
variable "aws_region" {
  type = string
}

Reference:
var.aws_region

Provide value:
aws_region = "us-east-1"
```

```text
DATA SOURCE

Declare:
data "aws_ami" "ubuntu" {
}

Reference:
data.aws_ami.ubuntu.id
```

```text
SINGLE RESOURCE OUTPUT

aws_vpc.main.id
```

```text
COUNT OUTPUT

aws_instance.lab_ec2[*].public_ip

Result:
LIST
```

```text
FOR_EACH OUTPUT

{
  for key, instance in aws_instance.lab_ec2 :
  key => instance.public_ip
}

Result:
MAP
```

```text
SET(STRING)

each.key   = value
each.value = value
```

```text
MAP(STRING)

each.key   = resource name
each.value = one string value
```

```text
MAP(OBJECT)

each.key = resource name

each.value.instance_type
each.value.monitoring
each.value.environment
```

---

# 37. Key Lessons

1. Variables accept input into Terraform configurations.
2. `variables.tf` declares variables.
3. `terraform.tfvars` provides local values.
4. `terraform.tfvars.example` documents expected values safely.
5. Data sources retrieve information from providers.
6. Resources create or manage infrastructure.
7. Outputs expose useful Terraform values.
8. `count` and `for_each` create different resource collection shapes.
9. Splat expressions are convenient for list-like collections.
10. For expressions are useful for transforming maps created by `for_each`.
11. `map(object)` supports structured and scalable resource configuration.
12. Understanding Terraform types is essential for troubleshooting expressions and outputs.
