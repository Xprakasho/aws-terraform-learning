
# Terraform count, for_each, and Dynamic Blocks

## 1. Purpose of This Note

This note covers:

- Terraform Meta-Arguments
- `count`
- `count.index`
- `for_each`
- `each.key`
- `each.value`
- Sets and Maps with `for_each`
- Maps of Objects
- Resource Identity
- `count` vs `for_each`
- Migrating from `count` to `for_each`
- Dynamic Blocks
- `dynamic`
- Dynamic Block Iterators
- `content`
- Dynamic Security Group Rules
- When to Use and Avoid Dynamic Blocks

These concepts are closely related because they solve different types of repetition in Terraform.

In our AWS Foundation lab, we practiced all three.

The learning path was:

```text
Single EC2 Instance
        |
        v
count
        |
        v
Multiple Indexed EC2 Instances
        |
        v
for_each
        |
        v
Named EC2 Instances
        |
        v
Map of Objects
        |
        v
Different Configuration Per Instance
```

For Security Groups:

```text
Single Static ingress Block
        |
        v
Multiple Static ingress Blocks
        |
        v
List of ingress Rule Objects
        |
        v
dynamic Block
        |
        v
Multiple Generated ingress Blocks
```

---

# 2. What Are Terraform Meta-Arguments?

Terraform provides special arguments that control how resources and modules behave.

Common meta-arguments include:

```text
count

for_each

depends_on

provider

lifecycle
```

Example:

```hcl
resource "aws_instance" "lab_ec2" {
  count = 2

  ami           = data.aws_ami.ubuntu.id
  instance_type = "t3.micro"
}
```

Here:

```text
count
```

is not a normal EC2 argument.

It is a Terraform meta-argument.

It tells Terraform:

```text
Create Multiple Instances of This Resource Block
```

---

# 3. What Is count?

The `count` meta-argument creates multiple instances of a resource or module.

Example:

```hcl
resource "aws_instance" "lab_ec2" {
  count = 2

  ami           = data.aws_ami.ubuntu.id
  instance_type = "t3.micro"
}
```

Terraform creates:

```text
aws_instance.lab_ec2[0]

aws_instance.lab_ec2[1]
```

Conceptually:

```text
Resource Block
      |
      v
   count = 2
      |
   +--+--+
   |     |
   v     v
  [0]   [1]
```

---

# 4. Our First count Configuration

Initially, our lab used:

```hcl
resource "aws_instance" "lab_ec2" {
  count = var.instance_count

  ami           = data.aws_ami.ubuntu.id
  instance_type = var.instance_type
}
```

Variable:

```hcl
variable "instance_count" {
  description = "Number of EC2 instances"
  type        = number
}
```

tfvars:

```hcl
instance_count = 2
```

Terraform created:

```text
aws_instance.lab_ec2[0]

aws_instance.lab_ec2[1]
```

---

# 5. count.index

When `count` is used, Terraform provides:

```hcl
count.index
```

The index starts from:

```text
0
```

For:

```hcl
count = 3
```

Terraform creates:

```text
count.index = 0

count.index = 1

count.index = 2
```

Example:

```hcl
tags = {
  Name = "Terraform-EC2-${count.index + 1}"
}
```

Results:

```text
Terraform-EC2-1

Terraform-EC2-2

Terraform-EC2-3
```

---

# 6. Why We Used count.index + 1

Terraform indexing starts at:

```text
0
```

Therefore:

```hcl
count.index
```

would create:

```text
Terraform-EC2-0

Terraform-EC2-1
```

We preferred:

```text
Terraform-EC2-1

Terraform-EC2-2
```

Therefore, we used:

```hcl
count.index + 1
```

---

# 7. Resource Identity with count

With:

```hcl
count = 3
```

resource addresses are:

```text
aws_instance.lab_ec2[0]

aws_instance.lab_ec2[1]

aws_instance.lab_ec2[2]
```

The resource identity is based on:

```text
Numeric Index
```

Conceptually:

```text
[0] ---> EC2 Instance

[1] ---> EC2 Instance

[2] ---> EC2 Instance
```

This works well when the resources are nearly identical.

---

# 8. The Limitation of count

Suppose we want:

```text
Web Server

Application Server

Database Server
```

Using:

```text
[0]

[1]

[2]
```

does not clearly express the purpose of each resource.

Compare:

```text
aws_instance.lab_ec2[0]
```

with:

```text
aws_instance.lab_ec2["web"]
```

The second resource address is more meaningful.

This is one reason to use:

```text
for_each
```

---

# 9. What Is for_each?

The `for_each` meta-argument creates one resource instance for every element of a map or set.

Example:

```hcl
resource "aws_instance" "lab_ec2" {
  for_each = var.instances

  ami           = data.aws_ami.ubuntu.id
  instance_type = var.instance_type
}
```

If:

```hcl
instances = ["web", "app"]
```

and the variable is a set:

```hcl
variable "instances" {
  type = set(string)
}
```

Terraform creates:

```text
aws_instance.lab_ec2["web"]

aws_instance.lab_ec2["app"]
```

---

# 10. Resource Identity with for_each

With `for_each`, the resource identity is based on keys.

Example:

```text
"web"

"app"

"db"
```

Terraform resource addresses:

```text
aws_instance.lab_ec2["web"]

aws_instance.lab_ec2["app"]

aws_instance.lab_ec2["db"]
```

Conceptually:

```text
for_each
    |
    +------> "web" ---> EC2
    |
    +------> "app" ---> EC2
    |
    +------> "db"  ---> EC2
```

---

# 11. count vs for_each

Comparison:

| Feature | count | for_each |
|---|---|---|
| Identity | Numeric index | Unique key |
| Example Address | `[0]` | `["web"]` |
| Current Item | `count.index` | `each.key`, `each.value` |
| Best For | Similar resources | Meaningfully identified resources |
| Collection Input | Number | Map or Set |
| Resource Removal | Can cause index shifts | Key-based control |
| Per-Resource Configuration | More difficult | Easier |

Mental model:

```text
count
  |
  v
How many?


for_each
  |
  v
Which named items?
```

---

# 12. Our Migration from count to for_each

Our original configuration:

```hcl
resource "aws_instance" "lab_ec2" {
  count = var.instance_count
}
```

Resource addresses:

```text
aws_instance.lab_ec2[0]

aws_instance.lab_ec2[1]
```

We changed it to:

```hcl
resource "aws_instance" "lab_ec2" {
  for_each = var.instances
}
```

New addresses:

```text
aws_instance.lab_ec2["web"]

aws_instance.lab_ec2["app"]
```

Terraform initially planned:

```text
2 to add

2 to destroy
```

Why?

Because Terraform saw:

```text
[0]
[1]
```

and:

```text
["web"]
["app"]
```

as different resource addresses.

---

# 13. Safe Migration Using moved Blocks

We used:

```hcl
moved {
  from = aws_instance.lab_ec2[0]
  to   = aws_instance.lab_ec2["web"]
}

moved {
  from = aws_instance.lab_ec2[1]
  to   = aws_instance.lab_ec2["app"]
}
```

This told Terraform:

```text
[0] ---> ["web"]

[1] ---> ["app"]
```

Result:

```text
Existing Infrastructure Preserved
```

This was an important lesson:

```text
Changing Terraform Code Structure
Does Not Automatically Mean
We Want to Replace Infrastructure
```

---

# 14. Adding a New Instance with for_each

After the migration, we had:

```hcl
instances = ["web", "app"]
```

Then we added:

```hcl
instances = ["web", "app", "db"]
```

Terraform plan showed:

```text
Plan: 1 to add, 0 to change, 0 to destroy.
```

Why?

Existing keys:

```text
web

app
```

remained unchanged.

Only the new key:

```text
db
```

was added.

Conceptually:

```text
Existing:

web ---> Keep

app ---> Keep


New:

db ---> Create
```

This demonstrates the advantage of stable key-based resource identity.

---

# 15. Using a Set with for_each

Our initial `for_each` variable was:

```hcl
variable "instances" {
  description = "EC2 instances to create"
  type        = set(string)
}
```

tfvars:

```hcl
instances = ["web", "app", "db"]
```

For a set of strings:

```text
each.key
```

and:

```text
each.value
```

represent the same string.

Conceptually:

```text
"web"

each.key   = "web"

each.value = "web"
```

---

# 16. Why a Set Was Not Enough

A set allowed us to define:

```text
web

app

db
```

But suppose we want:

```text
web ---> t3.micro

app ---> t3.micro

db  ---> t3.small
```

A simple set:

```hcl
set(string)
```

cannot store detailed configuration for each EC2 instance.

We need a more complex data structure.

Solution:

```text
Map of Objects
```

---

# 17. Map of Objects

We evolved our instance variable to:

```hcl
variable "instances" {
  description = "EC2 instances to create"

  type = map(object({
    instance_type = string
    monitoring    = bool
    environment   = string
  }))
}
```

This means:

```text
Map
 |
 +----> Key = Instance Name
 |
 +----> Value = Configuration Object
```

---

# 18. Our Instance Map

Our example configuration:

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

Conceptually:

```text
instances
    |
    +----> web
    |       |
    |       +----> instance_type
    |       +----> monitoring
    |       +----> environment
    |
    +----> app
    |       |
    |       +----> instance_type
    |       +----> monitoring
    |       +----> environment
    |
    +----> db
            |
            +----> instance_type
            +----> monitoring
            +----> environment
```

---

# 19. Using each.key

With:

```hcl
for_each = var.instances
```

we use:

```hcl
each.key
```

to access:

```text
web

app

db
```

Example:

```hcl
tags = {
  Name = "Terraform-EC2-${each.key}"
}
```

Results:

```text
Terraform-EC2-web

Terraform-EC2-app

Terraform-EC2-db
```

---

# 20. Using each.value

We use:

```hcl
each.value
```

to access the configuration object.

Example:

```hcl
instance_type = each.value.instance_type
```

For `web`:

```text
each.key = web

each.value.instance_type = t3.micro
```

For `db`:

```text
each.key = db

each.value.instance_type = t3.small
```

---

# 21. Professional EC2 Configuration

A more reusable EC2 configuration is:

```hcl
resource "aws_instance" "lab_ec2" {
  for_each = var.instances

  ami           = data.aws_ami.ubuntu.id
  instance_type = each.value.instance_type
  monitoring    = each.value.monitoring

  subnet_id = aws_subnet.public.id

  vpc_security_group_ids = [
    aws_security_group.public_sg.id
  ]

  key_name = "my-key1"

  tags = merge(
    local.common_tags,
    {
      Name        = "Terraform-EC2-${each.key}"
      Environment = each.value.environment
    }
  )
}
```

Now each EC2 instance can have different configuration.

---

# 22. What Is a Dynamic Block?

A dynamic block generates repeated nested blocks inside a resource.

General syntax:

```hcl
dynamic "BLOCK_NAME" {
  for_each = COLLECTION

  content {
    ...
  }
}
```

Example:

```hcl
dynamic "ingress" {
  for_each = var.ingress_rules

  content {
    description = ingress.value.description
    from_port   = ingress.value.from_port
    to_port     = ingress.value.to_port
    protocol    = ingress.value.protocol
    cidr_blocks = ingress.value.cidr_blocks
  }
}
```

---

# 23. Why Did We Need a Dynamic Block?

Our original Security Group contained:

```hcl
ingress {
  description = "SSH"
  from_port   = 22
  to_port     = 22
  protocol    = "tcp"
  cidr_blocks = ["0.0.0.0/0"]
}
```

To add HTTP:

```hcl
ingress {
  description = "HTTP"
  from_port   = 80
  to_port     = 80
  protocol    = "tcp"
  cidr_blocks = ["0.0.0.0/0"]
}
```

To add HTTPS:

```hcl
ingress {
  description = "HTTPS"
  from_port   = 443
  to_port     = 443
  protocol    = "tcp"
  cidr_blocks = ["0.0.0.0/0"]
}
```

This works.

But it creates repetitive configuration.

---

# 24. Static Blocks vs Dynamic Blocks

Static configuration:

```text
ingress SSH Block

ingress HTTP Block

ingress HTTPS Block
```

Dynamic configuration:

```text
ingress_rules Variable
         |
         v
    dynamic Block
         |
         v
+--------+--------+
|        |        |
v        v        v
SSH     HTTP    HTTPS
```

The dynamic block generates the nested `ingress` blocks.

---

# 25. Our ingress_rules Variable

We defined:

```hcl
variable "ingress_rules" {
  description = "Ingress rules for the public security group"

  type = list(object({
    description = string
    from_port   = number
    to_port     = number
    protocol    = string
    cidr_blocks = list(string)
  }))
}
```

This is:

```text
List
  |
  v
Objects
  |
  +----> description
  +----> from_port
  +----> to_port
  +----> protocol
  +----> cidr_blocks
```

---

# 26. Our ingress_rules Values

In `terraform.tfvars.example`:

```hcl
ingress_rules = [
  {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  },
  {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  },
  {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
]
```

Terraform receives three objects.

Therefore, the dynamic block creates three nested `ingress` blocks.

---

# 27. Our Dynamic Security Group Configuration

The configuration:

```hcl
resource "aws_security_group" "public_sg" {
  name        = "terraform-public-sg"
  description = "Public security group"
  vpc_id      = aws_vpc.main.id

  dynamic "ingress" {
    for_each = var.ingress_rules

    content {
      description = ingress.value.description
      from_port   = ingress.value.from_port
      to_port     = ingress.value.to_port
      protocol    = ingress.value.protocol
      cidr_blocks = ingress.value.cidr_blocks
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    local.common_tags,
    {
      Name = "Terraform-Public-SG"
    }
  )
}
```

---

# 28. Breaking Down the Dynamic Block

Configuration:

```hcl
dynamic "ingress" {
```

Meaning:

```text
Generate ingress Blocks
```

Next:

```hcl
for_each = var.ingress_rules
```

Meaning:

```text
Loop Through Every ingress Rule Object
```

Next:

```hcl
content {
```

Meaning:

```text
Define the Contents of Each Generated ingress Block
```

---

# 29. Dynamic Block Iterator

By default, the iterator name is the dynamic block label.

Example:

```hcl
dynamic "ingress" {
```

Default iterator:

```text
ingress
```

Therefore:

```hcl
ingress.value.description
```

```hcl
ingress.value.from_port
```

```hcl
ingress.value.to_port
```

are valid.

Mental model:

```text
dynamic "ingress"
        |
        v
Default Iterator Name
        |
        v
ingress
        |
        +----> ingress.key
        |
        +----> ingress.value
```

---

# 30. ingress.value

Our collection is:

```hcl
var.ingress_rules
```

Each item is an object:

```hcl
{
  description = "HTTP"
  from_port   = 80
  to_port     = 80
  protocol    = "tcp"
  cidr_blocks = ["0.0.0.0/0"]
}
```

Inside the dynamic block:

```hcl
ingress.value
```

represents the entire current object.

Therefore:

```hcl
ingress.value.description
```

returns:

```text
HTTP
```

and:

```hcl
ingress.value.from_port
```

returns:

```text
80
```

---

# 31. How Terraform Processes Our Dynamic Block

Input:

```text
Rule 1 = SSH

Rule 2 = HTTP

Rule 3 = HTTPS
```

Terraform processing:

```text
var.ingress_rules
        |
        v
dynamic "ingress"
        |
        +----> Rule 1
        |         |
        |         v
        |     ingress Block
        |
        +----> Rule 2
        |         |
        |         v
        |     ingress Block
        |
        +----> Rule 3
                  |
                  v
              ingress Block
```

Result:

```text
3 AWS Security Group Ingress Rules
```

We verified all three rules in AWS:

```text
22  TCP  0.0.0.0/0

80  TCP  0.0.0.0/0

443 TCP  0.0.0.0/0
```

---

# 32. Custom Iterator Names

We can explicitly define an iterator:

```hcl
dynamic "ingress" {
  for_each = var.ingress_rules

  iterator = rule

  content {
    description = rule.value.description
    from_port   = rule.value.from_port
    to_port     = rule.value.to_port
    protocol    = rule.value.protocol
    cidr_blocks = rule.value.cidr_blocks
  }
}
```

Now:

```text
rule.value
```

is used instead of:

```text
ingress.value
```

Custom iterators can improve readability, especially with nested dynamic blocks.

---

# 33. Resource for_each vs Dynamic for_each

This distinction is critical.

Resource:

```hcl
resource "aws_instance" "lab_ec2" {
  for_each = var.instances
}
```

creates:

```text
Multiple AWS Resources
```

Dynamic block:

```hcl
dynamic "ingress" {
  for_each = var.ingress_rules
}
```

creates:

```text
Multiple Nested Blocks Inside One Resource
```

Comparison:

```text
Resource for_each
       |
       v
Multiple Resource Instances


Dynamic Block for_each
       |
       v
Multiple Nested Configuration Blocks
Inside One Resource
```

---

# 34. count vs for_each vs dynamic

This is the key comparison:

| Concept | Purpose |
|---|---|
| `count` | Create multiple indexed resource/module instances |
| `for_each` | Create multiple key-based resource/module instances |
| `dynamic` | Generate repeated nested blocks |

Mental model:

```text
count
   |
   v
Repeat Resource by Number


for_each
   |
   v
Repeat Resource by Key


dynamic
   |
   v
Repeat Nested Blocks
Inside a Resource
```

---

# 35. A Common Interview Trap

Question:

**Can dynamic blocks create multiple resources?**

Answer:

No.

Dynamic blocks generate repeated nested blocks inside a resource, data source, provider, or provisioner configuration where supported.

To create multiple resource instances, use:

```text
count
```

or:

```text
for_each
```

---

# 36. Another Important Difference

This:

```hcl
resource "aws_instance" "lab_ec2" {
  for_each = var.instances
}
```

creates:

```text
EC2 web

EC2 app

EC2 db
```

This:

```hcl
dynamic "ingress" {
  for_each = var.ingress_rules
}
```

creates:

```text
One Security Group
        |
        +----> SSH Rule
        |
        +----> HTTP Rule
        |
        +----> HTTPS Rule
```

---

# 37. When to Use count

Use `count` when:

```text
Resources Are Nearly Identical

Only the Number of Resources Matters

Resource Identity Does Not Need Meaningful Keys

Simple Conditional Resource Creation Is Needed
```

Example:

```hcl
count = var.create_instance ? 1 : 0
```

This means:

```text
true  ---> Create One Resource

false ---> Create Zero Resources
```

---

# 38. When to Use for_each

Use `for_each` when:

```text
Resources Have Unique Names

Resources Need Different Configuration

Stable Resource Identity Is Important

Working with Maps or Sets

Adding or Removing Individual Resources
```

Example:

```text
web

app

db
```

is a strong use case for `for_each`.

---

# 39. When to Use Dynamic Blocks

Use dynamic blocks when:

```text
A Resource Contains Repeated Nested Blocks

Nested Configuration Comes from Variables

The Number of Nested Blocks Can Change

You Want to Reduce Repetitive Nested Configuration
```

Our Security Group ingress rules were a suitable learning example.

---

# 40. When Not to Use Dynamic Blocks

Do not use dynamic blocks simply because they look advanced.

For example, if a Security Group always has one simple SSH rule:

```hcl
ingress {
  from_port   = 22
  to_port     = 22
  protocol    = "tcp"
  cidr_blocks = ["10.0.0.0/8"]
}
```

A dynamic block may add unnecessary complexity.

Use dynamic blocks when they improve:

```text
Reusability

Maintainability

Configuration Flexibility
```

Do not use them when they reduce readability.

---

# 41. Important Security Lesson from Our Lab

Our learning configuration used:

```text
SSH   0.0.0.0/0

HTTP  0.0.0.0/0

HTTPS 0.0.0.0/0
```

This was useful for understanding dynamic blocks.

However, in production:

```text
SSH from 0.0.0.0/0
```

is generally not a good security practice.

SSH access should normally be restricted using mechanisms such as:

```text
Trusted CIDR Ranges

VPN Access

Bastion Hosts

AWS Systems Manager Session Manager
```

Infrastructure reusability must not come at the cost of security.

---

# 42. Our Complete Learning Progression

We started with:

```hcl
resource "aws_instance" "lab_ec2" {
}
```

Then:

```hcl
count = var.instance_count
```

Then:

```hcl
for_each = var.instances
```

Then:

```text
set(string)
```

Then:

```text
map(object(...))
```

Then:

```hcl
each.key
```

and:

```hcl
each.value
```

For Security Groups:

```text
Static ingress Block
        |
        v
Repeated Static Blocks
        |
        v
list(object(...))
        |
        v
dynamic "ingress"
```

This is the correct progression from basic Terraform syntax toward reusable infrastructure code.

---

# 43. Professional Design Pattern

A reusable Terraform configuration often follows:

```text
variables.tf
     |
     v
Define Complex Input Types
     |
     v
terraform.tfvars
     |
     v
Provide Environment Configuration
     |
     v
for_each
     |
     v
Create Key-Based Resources
     |
     v
dynamic Blocks
     |
     v
Create Repeated Nested Configuration
     |
     v
locals + merge()
     |
     v
Standardize Naming and Tags
     |
     v
outputs.tf
     |
     v
Return Useful Infrastructure Information
```

---

# 44. Interview Perspective

**Question: What is the difference between count and for_each?**

Answer:

`count` creates multiple resource or module instances using numeric indexes, while `for_each` creates instances using unique keys from a map or set. I prefer `for_each` when resources have meaningful identities or different configurations because key-based addressing is generally more stable and readable.

---

**Question: What is count.index?**

Answer:

`count.index` is the numeric index of the current resource instance when the `count` meta-argument is used. The index begins at zero.

---

**Question: What are each.key and each.value?**

Answer:

When `for_each` is used, `each.key` represents the current collection key and `each.value` represents the value associated with that key.

---

**Question: Why did you migrate from count to for_each?**

Answer:

I initially used `count` to create multiple identical EC2 instances. I migrated to `for_each` because I wanted meaningful resource identities such as web, app, and db and needed different configuration values for individual instances.

---

**Question: What problem did you face during count to for_each migration?**

Answer:

The Terraform resource addresses changed from numeric indexes to key-based addresses. Terraform initially planned to destroy the old resources and create new ones. I used `moved` blocks to map the old resource addresses to the new addresses and preserve the existing infrastructure.

---

**Question: What is a dynamic block?**

Answer:

A dynamic block generates repeated nested configuration blocks from a collection. In my AWS lab, I used a dynamic block to generate Security Group ingress blocks from a list of ingress rule objects.

---

**Question: What is the difference between for_each on a resource and for_each inside a dynamic block?**

Answer:

Resource-level `for_each` creates multiple resource instances. A dynamic block's `for_each` creates multiple nested blocks inside a single resource configuration.

---

**Question: What is the content block inside a dynamic block?**

Answer:

The `content` block defines the body of each nested block generated by the dynamic block.

---

**Question: What is the default iterator name in a dynamic block?**

Answer:

By default, the iterator name is the dynamic block label. For example, in `dynamic "ingress"`, the default iterator is `ingress`, so values can be accessed using expressions such as `ingress.value.from_port`.

---

# 45. Final Mental Model

```text
                    TERRAFORM REPETITION
                            |
          +-----------------+-----------------+
          |                 |                 |
          v                 v                 v
        count           for_each           dynamic
          |                 |                 |
          v                 v                 v
       Number             Keys           Nested Blocks
          |                 |                 |
          v                 v                 v
    count.index         each.key         iterator.value
                            |
                            v
                        each.value
```

Resource example:

```text
count = 3

EC2[0]
EC2[1]
EC2[2]
```

Resource example:

```text
for_each

EC2["web"]
EC2["app"]
EC2["db"]
```

Nested block example:

```text
dynamic "ingress"

Security Group
     |
     +----> SSH
     |
     +----> HTTP
     |
     +----> HTTPS
```

---

# 46. Key Lessons from Our Lab

```text
count
   |
   +----> Multiple Indexed Resources


count.index
   |
   +----> Current Numeric Index


for_each
   |
   +----> Multiple Key-Based Resources


each.key
   |
   +----> Resource Identity


each.value
   |
   +----> Resource Configuration


set(string)
   |
   +----> Simple Named Resources


map(object(...))
   |
   +----> Named Resources with Different Configuration


dynamic
   |
   +----> Repeated Nested Blocks


content
   |
   +----> Body of Generated Nested Block


count ---> for_each
   |
   +----> Resource Address Change


moved {}
   |
   +----> Safe State Migration
```

The main professional takeaway is:

```text
Use count when the number matters.

Use for_each when identity matters.

Use dynamic blocks when repeated nested configuration matters.
```

Before choosing any of them, understand:

```text
Data Structure
+
Resource Identity
+
State Impact
+
Configuration Readability
+
Infrastructure Lifecycle
```
