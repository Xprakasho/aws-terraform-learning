# Terraform Loops, Expressions, and Collections

## 1. Purpose of This Note

This note covers Terraform concepts used to create and manage multiple resources efficiently:

- `count`
- `count.index`
- Splat Expressions
- `for_each`
- `each.key`
- `each.value`
- Sets
- Maps
- Objects
- `for` Expressions

These concepts are important because production infrastructure normally contains multiple resources rather than a single EC2 instance, subnet, security rule, or other resource.

---

## 2. The Problem: Creating Multiple Resources

Initially, we created one EC2 instance:

```hcl
resource "aws_instance" "lab_ec2" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = var.instance_type
}
```

This works for one instance.

However, creating separate resource blocks for multiple instances causes code duplication:

```hcl
resource "aws_instance" "web" {
  ...
}

resource "aws_instance" "app" {
  ...
}

resource "aws_instance" "db" {
  ...
}
```

Terraform provides two important meta-arguments for creating multiple resource instances:

```text
count
for_each
```

---

# 3. count

`count` creates multiple instances of a resource based on a number.

Example:

```hcl
variable "instance_count" {
  description = "Number of EC2 instances"
  type        = number
}
```

Value:

```hcl
instance_count = 2
```

Resource:

```hcl
resource "aws_instance" "lab_ec2" {
  count = var.instance_count

  ami           = data.aws_ami.ubuntu.id
  instance_type = var.instance_type
}
```

Terraform creates:

```text
aws_instance.lab_ec2[0]
aws_instance.lab_ec2[1]
```

The resources are identified using numeric indexes.

---

## 4. count.index

`count.index` provides the index number of the current resource instance.

The index starts from:

```text
0
```

Example:

```hcl
tags = {
  Name = "Terraform-EC2-${count.index + 1}"
}
```

Terraform creates tags:

```text
Terraform-EC2-1
Terraform-EC2-2
```

Without `+ 1`, the names would be:

```text
Terraform-EC2-0
Terraform-EC2-1
```

---

## 5. Resource Addresses with count

When `count` is used, Terraform identifies resources using numeric indexes.

Example:

```text
aws_instance.lab_ec2[0]
aws_instance.lab_ec2[1]
```

The Terraform state may show:

```bash
terraform state list
```

Output:

```text
aws_instance.lab_ec2[0]
aws_instance.lab_ec2[1]
```

This is important because Terraform uses the resource address to track infrastructure.

---

# 6. Splat Expressions

When multiple resources are created using `count`, we often need to retrieve the same attribute from all instances.

Example:

```hcl
output "instance_public_ip" {
  value = aws_instance.lab_ec2[*].public_ip
}
```

The expression:

```text
[*]
```

is called a splat expression.

It means:

```text
Get this attribute from every resource instance.
```

Example:

```hcl
aws_instance.lab_ec2[*].public_ip
```

Possible output:

```text
[
  "3.239.15.35",
  "98.92.227.86"
]
```

Another example:

```hcl
aws_instance.lab_ec2[*].private_ip
```

Possible output:

```text
[
  "10.0.1.39",
  "10.0.1.91"
]
```

---

## 7. Limitation of count

`count` identifies resources using numeric indexes:

```text
[0]
[1]
[2]
```

This makes the infrastructure less descriptive.

For example:

```text
aws_instance.lab_ec2[0]
```

does not immediately tell us whether the instance is:

```text
web
app
db
```

Another concern is that changing the order of a list can affect resource addressing.

For infrastructure with meaningful resource identities, `for_each` is often a better choice.

---

# 8. for_each

`for_each` creates multiple resource instances from a collection.

Supported collection types commonly include:

```text
set
map
```

Example:

```hcl
variable "instances" {
  description = "EC2 instances to create"
  type        = set(string)
}
```

Values:

```hcl
instances = ["web", "app"]
```

Resource:

```hcl
resource "aws_instance" "lab_ec2" {
  for_each = var.instances

  ami           = data.aws_ami.ubuntu.id
  instance_type = var.instance_type

  tags = {
    Name = "Terraform-EC2-${each.key}"
  }
}
```

Terraform creates:

```text
aws_instance.lab_ec2["web"]
aws_instance.lab_ec2["app"]
```

These resource addresses are more descriptive than numeric indexes.

---

# 9. each.key

When `for_each` is used, Terraform provides:

```text
each.key
```

For this set:

```hcl
instances = ["web", "app", "db"]
```

Terraform processes:

```text
each.key = "web"
each.key = "app"
each.key = "db"
```

Example:

```hcl
tags = {
  Name = "Terraform-EC2-${each.key}"
}
```

Terraform creates:

```text
Terraform-EC2-web
Terraform-EC2-app
Terraform-EC2-db
```

---

# 10. Sets

A set is a collection of unique values.

Example variable:

```hcl
variable "instances" {
  type = set(string)
}
```

Value:

```hcl
instances = ["web", "app", "db"]
```

Important characteristics:

```text
Unique values
No meaningful numeric index
Works well with for_each
```

For a set of strings:

```text
each.key == each.value
```

Therefore:

```hcl
each.key
```

and:

```hcl
each.value
```

both return the instance name.

---

# 11. Maps

A map stores information as key-value pairs.

Example:

```hcl
instances = {
  web = "t3.micro"
  app = "t3.micro"
  db  = "t3.small"
}
```

Structure:

```text
KEY        VALUE

web   ->   t3.micro
app   ->   t3.micro
db    ->   t3.small
```

When using `for_each`:

```text
each.key
```

returns:

```text
web
app
db
```

And:

```text
each.value
```

returns:

```text
t3.micro
t3.micro
t3.small
```

Example:

```hcl
resource "aws_instance" "lab_ec2" {
  for_each = var.instances

  ami           = data.aws_ami.ubuntu.id
  instance_type = each.value

  tags = {
    Name = "Terraform-EC2-${each.key}"
  }
}
```

---

# 12. map(object)

For production-style configurations, a simple map may not contain enough information.

Each EC2 instance may need multiple properties:

```text
instance type
monitoring
environment
```

We can use:

```text
map(object)
```

Example variable:

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

---

## 13. Using each.key and each.value with Objects

Resource:

```hcl
resource "aws_instance" "lab_ec2" {
  for_each = var.instances

  ami           = data.aws_ami.ubuntu.id
  instance_type = each.value.instance_type
  monitoring    = each.value.monitoring

  tags = {
    Name        = "Terraform-EC2-${each.key}"
    Environment = each.value.environment
  }
}
```

For the `web` instance:

```text
each.key
```

returns:

```text
web
```

While:

```text
each.value.instance_type
```

returns:

```text
t3.micro
```

And:

```text
each.value.environment
```

returns:

```text
dev
```

This makes the configuration much more reusable and scalable.

---

# 14. count vs for_each

| Feature | count | for_each |
|---|---|---|
| Input | Number | Set or Map |
| Resource Identity | Numeric Index | Meaningful Key |
| Example Address | `[0]` | `["web"]` |
| Access Variable | `count.index` | `each.key`, `each.value` |
| Best Use | Identical Resources | Individually Identified Resources |

Example with `count`:

```text
aws_instance.lab_ec2[0]
aws_instance.lab_ec2[1]
```

Example with `for_each`:

```text
aws_instance.lab_ec2["web"]
aws_instance.lab_ec2["app"]
```

For our AWS lab, `for_each` is the better design because our EC2 instances have meaningful identities.

---

# 15. Important Lab Observation: Changing count to for_each

Initially, our EC2 instances used:

```hcl
count = var.instance_count
```

Terraform state addresses were:

```text
aws_instance.lab_ec2[0]
aws_instance.lab_ec2[1]
```

We then changed the configuration to:

```hcl
for_each = var.instances
```

New resource addresses became:

```text
aws_instance.lab_ec2["web"]
aws_instance.lab_ec2["app"]
```

Terraform identifies infrastructure using resource addresses.

Therefore, changing:

```text
count
```

to:

```text
for_each
```

changes the resource addresses.

Terraform may interpret this as:

```text
Old resources removed
New resources created
```

unless the state migration is explicitly handled.

This is why Terraform planning and state management are critical when refactoring infrastructure code.

---

# 16. for Expressions

A `for` expression transforms one collection into another collection.

General syntax:

```hcl
[
  for item in collection : result
]
```

Example:

```hcl
[
  for instance in var.instances : instance
]
```

For maps:

```hcl
{
  for key, value in collection :
  key => result
}
```

---

## 17. for Expression Used in Our Outputs

With `for_each`, the old splat expression was no longer appropriate.

Old output:

```hcl
output "instance_public_ip" {
  value = aws_instance.lab_ec2[*].public_ip
}
```

We changed it to:

```hcl
output "instance_public_ip" {
  value = {
    for name, instance in aws_instance.lab_ec2 :
    name => instance.public_ip
  }
}
```

The result became:

```text
instance_public_ip = {
  "app" = "98.92.227.86"
  "web" = "3.239.15.35"
}
```

This is more useful than:

```text
[
  "3.239.15.35",
  "98.92.227.86"
]
```

because each IP address is associated with a meaningful instance name.

---

# 18. Understanding the for Expression

Consider:

```hcl
{
  for name, instance in aws_instance.lab_ec2 :
  name => instance.public_ip
}
```

Breaking it down:

```text
name
```

represents the resource key:

```text
web
app
db
```

`instance` represents the complete EC2 resource object.

Therefore:

```text
instance.public_ip
```

retrieves the public IP.

The expression creates:

```text
KEY  => VALUE
```

Example:

```text
web => 3.239.15.35
app => 98.92.227.86
```

---

# 19. Adding a New Instance with for_each

Initially:

```hcl
instances = ["web", "app"]
```

Terraform managed:

```text
aws_instance.lab_ec2["web"]
aws_instance.lab_ec2["app"]
```

We added:

```text
db
```

Configuration:

```hcl
instances = ["web", "app", "db"]
```

Terraform plan showed:

```text
Plan: 1 to add, 0 to change, 0 to destroy.
```

This demonstrated an important advantage of stable `for_each` keys.

Terraform preserved:

```text
web
app
```

and only created:

```text
db
```

---

# 20. Terraform State After for_each

Command:

```bash
terraform state list
```

Example:

```text
aws_instance.lab_ec2["app"]
aws_instance.lab_ec2["db"]
aws_instance.lab_ec2["web"]
```

This clearly shows how Terraform tracks each resource using its key.

The resource identity is now directly visible in the state.

---

# 21. Key Lessons

### count

Use when:

```text
Resources are nearly identical
Only the number of resources matters
```

### for_each

Use when:

```text
Resources have meaningful identities
Different resources need different configurations
Stable resource addressing is important
```

### Splat Expressions

Use to retrieve the same attribute from multiple count-based resources.

Example:

```hcl
aws_instance.lab_ec2[*].public_ip
```

### for Expressions

Use to transform collections and create custom output structures.

Example:

```hcl
{
  for name, instance in aws_instance.lab_ec2 :
  name => instance.public_ip
}
```

---

# 22. Interview Perspective

**Question: What is the difference between count and for_each?**

Answer:

`count` creates multiple resource instances using numeric indexes, while `for_each` creates resource instances using unique keys from a set or map. I prefer `for_each` when resources have meaningful identities because the resource addresses are more stable and descriptive.

---

**Question: What is count.index?**

Answer:

`count.index` is the numeric index of the current resource instance created using `count`. The index starts from zero.

---

**Question: What are each.key and each.value?**

Answer:

When using `for_each`, `each.key` represents the current collection key and `each.value` represents its associated value. With a map of objects, I can use them to configure individual resources with different properties.

---

**Question: What is a splat expression?**

Answer:

A splat expression retrieves the same attribute from all instances of a resource collection. For example, `aws_instance.lab_ec2[*].public_ip` returns the public IP addresses of multiple count-based EC2 instances.

---

**Question: Why can changing count to for_each recreate resources?**

Answer:

Terraform tracks infrastructure using resource addresses. `count` uses numeric addresses such as `[0]`, while `for_each` uses keyed addresses such as `["web"]`. Changing between them changes the resource addresses, so Terraform may plan resource destruction and recreation unless the state addresses are migrated.

---

# 23. Final Mental Model

```text
Need Multiple Resources
        |
        v
Are Resources Identical?
        |
        +---- YES ----> count
        |                 |
        |                 v
        |            count.index
        |
        +---- NO -----> for_each
                          |
                          +----> each.key
                          |
                          +----> each.value

Need Multiple Attributes?
        |
        v
    map(object)

Need to Transform Collection?
        |
        v
   for Expression

Need Attributes from Multiple
count-based Resources?
        |
        v
   Splat Expression
```

---

# 24. Commands Used During Practice

```bash
terraform fmt
terraform validate
terraform plan
terraform apply
terraform output
terraform state list
```

These commands helped us observe how changes to collections, `count`, and `for_each` affected Terraform configuration, outputs, execution plans, and state.
