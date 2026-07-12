
# Terraform Locals, merge(), and Expressions

## 1. Purpose of This Note

This note covers:

- Local Values
- `locals` Blocks
- Difference Between Variables and Locals
- `merge()` Function
- Terraform Expressions
- Conditional Expressions
- For Expressions
- Splat Expressions
- Resource References with `count`
- Resource References with `for_each`
- Transforming Terraform Data

We practiced these concepts while improving our AWS Foundation lab from a basic static configuration into a more reusable Terraform configuration.

---

# 2. What Are Local Values?

Local values allow us to define reusable expressions inside a Terraform module.

Syntax:

```hcl
locals {
  project_name = "terraform-aws-lab"
}
```

Reference:

```hcl
local.project_name
```

General syntax:

```text
local.LOCAL_NAME
```

Example:

```hcl
local.common_tags
```

Important:

```text
locals {
  ...
}
```

defines local values.

But:

```text
local.value_name
```

references a local value.

Notice the difference:

```text
Definition  = locals

Reference   = local
```

---

# 3. Why Use Locals?

Suppose we repeatedly use:

```hcl
tags = {
  Project     = "terraform-aws-lab"
  Environment = "dev"
  ManagedBy   = "Terraform"
  Owner       = "Om"
}
```

Without locals, we may repeat these tags across:

```text
VPC
Subnet
Security Group
EC2
S3
```

This creates duplicated configuration.

Instead:

```hcl
locals {
  common_tags = {
    Project     = "terraform-aws-lab"
    Environment = "dev"
    ManagedBy   = "Terraform"
    Owner       = "Om"
  }
}
```

Then:

```hcl
tags = local.common_tags
```

This improves:

```text
Readability
Consistency
Maintainability
Reusability
```

---

# 4. Variables vs Locals

Variables and locals are not the same.

Input variable:

```hcl
variable "aws_region" {
  type = string
}
```

Reference:

```hcl
var.aws_region
```

Local value:

```hcl
locals {
  project_name = "terraform-aws-lab"
}
```

Reference:

```hcl
local.project_name
```

Comparison:

| Feature | Variable | Local |
|---|---|---|
| Purpose | Accept external input | Reuse internal values or expressions |
| Reference | `var.name` | `local.name` |
| Can Be Set in tfvars | Yes | No |
| Can Use Expressions | Yes, depending on context | Yes |
| Used for Internal Calculations | Possible | Common |
| User Configurable | Yes | No |

Mental model:

```text
Variable
   |
   v
Input enters Terraform


Local
   |
   v
Terraform internally calculates or reuses a value
```

---

# 5. Locals in Our AWS Foundation Lab

Our lab contains:

```text
locals.tf
```

We used locals for common resource tags.

Conceptually:

```hcl
locals {
  common_tags = {
    Project     = "terraform-aws-lab"
    Environment = "dev"
    ManagedBy   = "Terraform"
    Owner       = "Om"
  }
}
```

Then resources can reuse:

```hcl
local.common_tags
```

Example:

```hcl
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"

  tags = local.common_tags
}
```

---

# 6. The Problem with Only common_tags

Suppose the VPC requires:

```text
Project
Environment
ManagedBy
Owner
Name
```

But `local.common_tags` contains only:

```text
Project
Environment
ManagedBy
Owner
```

We need to add:

```text
Name = "Terraform-VPC"
```

We should not duplicate all common tags manually.

Bad approach:

```hcl
tags = {
  Project     = "terraform-aws-lab"
  Environment = "dev"
  ManagedBy   = "Terraform"
  Owner       = "Om"
  Name        = "Terraform-VPC"
}
```

This defeats the purpose of reusable common tags.

Instead, we can use:

```text
merge()
```

---

# 7. What Is merge()?

`merge()` combines multiple maps or objects.

Example:

```hcl
merge(
  {
    Environment = "dev"
  },
  {
    Name = "Terraform-VPC"
  }
)
```

Result:

```hcl
{
  Environment = "dev"
  Name        = "Terraform-VPC"
}
```

General concept:

```text
Map A
  +
Map B
  |
  v
merge()
  |
  v
Combined Map
```

---

# 8. merge() in Our Lab

Example:

```hcl
tags = merge(
  local.common_tags,
  {
    Name = "Terraform-VPC"
  }
)
```

Result:

```text
Project     = terraform-aws-lab
Environment = dev
ManagedBy   = Terraform
Owner       = Om
Name        = Terraform-VPC
```

This allows:

```text
Common Tags
    +
Resource-Specific Tags
    |
    v
Final Resource Tags
```

---

# 9. merge() with EC2 and for_each

Our EC2 instances use:

```hcl
for_each = var.instances
```

We can create resource-specific tags:

```hcl
tags = merge(
  local.common_tags,
  {
    Name = "Terraform-EC2-${each.key}"
  }
)
```

For:

```text
web
app
db
```

Terraform creates:

```text
Terraform-EC2-web

Terraform-EC2-app

Terraform-EC2-db
```

Conceptually:

```text
local.common_tags
        +
each.key
        |
        v
merge()
        |
        v
Unique Tags Per EC2 Instance
```

---

# 10. merge() Conflict Behavior

Suppose:

```hcl
merge(
  {
    Environment = "dev"
  },
  {
    Environment = "test"
  }
)
```

Result:

```text
Environment = "test"
```

Why?

When duplicate keys exist:

```text
Later Value Wins
```

Conceptually:

```text
First Map:

Environment = dev


Second Map:

Environment = test


Final Result:

Environment = test
```

This is important when designing tag structures.

---

# 11. What Is a Terraform Expression?

An expression represents or calculates a value.

Examples:

```hcl
var.aws_region
```

```hcl
aws_vpc.main.id
```

```hcl
local.common_tags
```

```hcl
each.key
```

```hcl
count.index
```

```hcl
data.aws_ami.ubuntu.id
```

```hcl
merge(local.common_tags, { Name = "Terraform-VPC" })
```

All of these are Terraform expressions.

Expressions can:

```text
Reference Values
Transform Data
Select Values
Create Collections
Calculate Results
Build Strings
```

---

# 12. Literal Values vs Expressions

Literal value:

```hcl
instance_type = "t3.micro"
```

Expression:

```hcl
instance_type = var.instance_type
```

Literal:

```hcl
Name = "Terraform-VPC"
```

Expression:

```hcl
Name = "Terraform-EC2-${each.key}"
```

A literal is directly written.

An expression is evaluated by Terraform.

---

# 13. String Interpolation

We used:

```hcl
Name = "Terraform-EC2-${each.key}"
```

Terraform evaluates:

```text
each.key = web
```

Result:

```text
Terraform-EC2-web
```

For:

```text
each.key = app
```

Result:

```text
Terraform-EC2-app
```

For:

```text
each.key = db
```

Result:

```text
Terraform-EC2-db
```

Syntax:

```text
${EXPRESSION}
```

inside a string.

---

# 14. Conditional Expressions

Terraform supports conditional expressions.

Syntax:

```hcl
condition ? true_value : false_value
```

Example:

```hcl
instance_type = var.environment == "prod" ? "t3.medium" : "t3.micro"
```

Meaning:

```text
Is environment prod?
        |
    +---+---+
    |       |
   YES      NO
    |       |
    v       v
t3.medium  t3.micro
```

General syntax:

```text
condition ? value_if_true : value_if_false
```

---

# 15. count Expressions

When using:

```hcl
count = var.instance_count
```

Terraform creates multiple resource instances.

Reference current index:

```hcl
count.index
```

Example:

```hcl
tags = {
  Name = "Terraform-EC2-${count.index + 1}"
}
```

Results:

```text
count.index = 0

Terraform-EC2-1


count.index = 1

Terraform-EC2-2
```

We used:

```hcl
count.index + 1
```

because Terraform indexes start from:

```text
0
```

---

# 16. for_each Expressions

After migrating from `count`, we used:

```hcl
for_each = var.instances
```

For a set:

```hcl
instances = ["web", "app"]
```

we used:

```hcl
each.key
```

Later, our variable evolved into a map of objects:

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

Now we can use:

```hcl
each.key
```

and:

```hcl
each.value
```

---

# 17. each.key and each.value

For:

```hcl
for_each = var.instances
```

and:

```hcl
instances = {
  web = {
    instance_type = "t3.micro"
  }
}
```

Terraform evaluates:

```text
each.key
    |
    v
"web"
```

and:

```text
each.value
    |
    v
{
  instance_type = "t3.micro"
}
```

Therefore:

```hcl
instance_type = each.value.instance_type
```

returns:

```text
t3.micro
```

---

# 18. count.index vs each.key

With `count`:

```hcl
count.index
```

Example:

```text
0
1
2
```

With `for_each`:

```hcl
each.key
```

Example:

```text
web
app
db
```

Comparison:

| count | for_each |
|---|---|
| `count.index` | `each.key` |
| Numeric identity | Key-based identity |
| `[0]` | `["web"]` |
| `[1]` | `["app"]` |
| Good for identical resources | Good for meaningfully identified resources |

---

# 19. What Is a For Expression?

A `for` expression transforms one collection into another collection.

General idea:

```text
Input Collection
       |
       v
for Expression
       |
       v
Transformation
       |
       v
Output Collection
```

Example:

```hcl
[for name in var.instances : upper(name)]
```

Input:

```text
web
app
db
```

Output:

```text
WEB
APP
DB
```

---

# 20. List For Expression

Syntax:

```hcl
[
  for ITEM in COLLECTION :
  RESULT
]
```

Example:

```hcl
[
  for name in var.instances :
  upper(name)
]
```

Conceptually:

```text
web ---> WEB

app ---> APP

db  ---> DB
```

Result:

```text
[
  "WEB",
  "APP",
  "DB"
]
```

---

# 21. Map For Expression

Syntax:

```hcl
{
  for KEY, VALUE in COLLECTION :
  NEW_KEY => NEW_VALUE
}
```

We used this pattern in our outputs.

Example:

```hcl
output "instance_public_ip" {
  value = {
    for name, instance in aws_instance.lab_ec2 :
    name => instance.public_ip
  }
}
```

This transforms:

```text
EC2 Resource Map
```

into:

```text
Name ---> Public IP
```

---

# 22. Our Public IP For Expression

Configuration:

```hcl
output "instance_public_ip" {
  value = {
    for name, instance in aws_instance.lab_ec2 :
    name => instance.public_ip
  }
}
```

Terraform processes:

```text
web EC2
   |
   v
web = 3.239.15.35


app EC2
   |
   v
app = 98.92.227.86
```

Result:

```text
instance_public_ip = {
  "app" = "98.92.227.86"
  "web" = "3.239.15.35"
}
```

Later, after adding `db`:

```text
instance_public_ip = {
  "app" = ...
  "db"  = ...
  "web" = ...
}
```

---

# 23. Breaking Down the For Expression

Expression:

```hcl
{
  for name, instance in aws_instance.lab_ec2 :
  name => instance.public_ip
}
```

Breakdown:

```text
aws_instance.lab_ec2
        |
        v
Input Collection
```

```text
name
        |
        v
Current Map Key
```

```text
instance
        |
        v
Current Resource Instance
```

```text
name => instance.public_ip
        |
        v
Output Key => Output Value
```

Mental model:

```text
for KEY, VALUE in COLLECTION :
KEY => VALUE.ATTRIBUTE
```

---

# 24. Our Private IP For Expression

We also used:

```hcl
output "instance_private_ip" {
  value = {
    for name, instance in aws_instance.lab_ec2 :
    name => instance.private_ip
  }
}
```

Result:

```text
instance_private_ip = {
  "app" = "10.0.1.91"
  "web" = "10.0.1.39"
}
```

The transformation:

```text
EC2 Resource Map
        |
        v
Extract private_ip
        |
        v
Create New Map
```

---

# 25. Filtering with For Expressions

For expressions can also filter values.

Syntax:

```hcl
[
  for ITEM in COLLECTION :
  RESULT
  if CONDITION
]
```

Example:

```hcl
[
  for name, config in var.instances :
  name
  if config.environment == "dev"
]
```

Meaning:

```text
Read Every Instance
        |
        v
Check Environment
        |
        v
Keep Only dev Instances
```

---

# 26. Example Filtering Our Instance Map

Given:

```hcl
instances = {
  web = {
    environment = "dev"
  }

  app = {
    environment = "dev"
  }

  db = {
    environment = "prod"
  }
}
```

Expression:

```hcl
[
  for name, config in var.instances :
  name
  if config.environment == "dev"
]
```

Result:

```text
[
  "web",
  "app"
]
```

The `db` instance is excluded.

---

# 27. What Is a Splat Expression?

A splat expression extracts the same attribute from multiple resource instances or collection elements.

Syntax:

```hcl
RESOURCE[*].ATTRIBUTE
```

Example from our earlier `count` configuration:

```hcl
aws_instance.lab_ec2[*].public_ip
```

Meaning:

```text
All EC2 Instances
        |
        v
Extract public_ip
        |
        v
Return Collection of IPs
```

---

# 28. Splat Expression in Our Lab

With:

```hcl
count = var.instance_count
```

we used:

```hcl
output "instance_public_ip" {
  value = aws_instance.lab_ec2[*].public_ip
}
```

Result:

```text
[
  "3.239.15.35",
  "98.92.227.86"
]
```

Similarly:

```hcl
output "instance_private_ip" {
  value = aws_instance.lab_ec2[*].private_ip
}
```

Result:

```text
[
  "10.0.1.39",
  "10.0.1.91"
]
```

---

# 29. Why the Splat Expression Failed After for_each

After changing:

```hcl
count
```

to:

```hcl
for_each
```

we still had:

```hcl
aws_instance.lab_ec2[*].public_ip
```

Terraform returned:

```text
Error: Unsupported attribute
```

Why?

Because the shape of the resource collection changed.

With `count`:

```text
Tuple / List-Like Collection
```

With `for_each`:

```text
Map of Resource Instances
```

The previous splat expression was no longer appropriate for the new collection structure.

---

# 30. How We Fixed the Outputs

Old `count` output:

```hcl
value = aws_instance.lab_ec2[*].public_ip
```

New `for_each` output:

```hcl
value = {
  for name, instance in aws_instance.lab_ec2 :
  name => instance.public_ip
}
```

Old result:

```text
[
  "IP-1",
  "IP-2"
]
```

New result:

```text
{
  "app" = "IP-1"
  "web" = "IP-2"
}
```

This is more meaningful because each IP is connected to the resource key.

---

# 31. Splat Expression vs For Expression

| Feature | Splat Expression | For Expression |
|---|---|---|
| Syntax | `[*].attribute` | `for ... in ... :` |
| Complexity | Simple | More Flexible |
| Transformation | Limited | Powerful |
| Filtering | No direct complex filtering | Yes |
| Output Control | Limited | High |
| Useful with count | Yes | Yes |
| Useful with maps | Usually use values/for expressions | Yes |

Mental model:

```text
Splat
  |
  v
Give me the same attribute from all items


For Expression
  |
  v
Iterate, transform, filter, and construct a new collection
```

---

# 32. Collection Transformation

One of the most important Terraform skills is understanding collection transformation.

Example:

```text
Input:

aws_instance.lab_ec2
```

Structure:

```text
{
  web = EC2 Object
  app = EC2 Object
  db  = EC2 Object
}
```

We want:

```text
{
  web = Public IP
  app = Public IP
  db  = Public IP
}
```

Solution:

```hcl
{
  for name, instance in aws_instance.lab_ec2 :
  name => instance.public_ip
}
```

Conceptually:

```text
Complex Resource Objects
          |
          v
    For Expression
          |
          v
Simple Useful Output Map
```

---

# 33. Expressions and Known After Apply

Our outputs showed:

```text
(Known after apply)
```

Example:

```text
app = (known after apply)
db  = (known after apply)
web = (known after apply)
```

The `for` expression itself can be evaluated structurally.

Terraform knows the keys:

```text
app
db
web
```

But AWS has not yet assigned:

```text
public_ip
private_ip
```

Therefore:

```text
Keys
  |
  +----> Known During Plan


IP Values
  |
  +----> Known After Apply
```

---

# 34. Professional Use of Locals

Locals are useful for:

```text
Common Tags
Naming Conventions
Calculated Values
Data Transformations
Reusable Expressions
Environment-Specific Logic
Reducing Repetition
```

Example:

```hcl
locals {
  name_prefix = "${var.project_name}-${var.environment}"
}
```

Usage:

```hcl
Name = "${local.name_prefix}-vpc"
```

Result:

```text
terraform-lab-dev-vpc
```

---

# 35. Avoid Overusing Locals

Locals improve readability when used correctly.

Bad approach:

```hcl
locals {
  a = var.aws_region
  b = local.a
  c = local.b
  d = local.c
}
```

This creates unnecessary indirection.

Good locals should:

```text
Reduce Duplication

Improve Meaning

Simplify Complex Expressions

Standardize Values
```

They should not make the configuration harder to follow.

---

# 36. Professional Refactoring Example

Initial code:

```hcl
tags = {
  Project     = "terraform-aws-lab"
  Environment = "dev"
  ManagedBy   = "Terraform"
  Owner       = "Om"
  Name        = "Terraform-VPC"
}
```

Improved:

```hcl
locals {
  common_tags = {
    Project     = "terraform-aws-lab"
    Environment = "dev"
    ManagedBy   = "Terraform"
    Owner       = "Om"
  }
}
```

Resource:

```hcl
tags = merge(
  local.common_tags,
  {
    Name = "Terraform-VPC"
  }
)
```

Benefits:

```text
Less Duplication
Consistent Tags
Easier Maintenance
Cleaner Configuration
```

---

# 37. Interview Perspective

**Question: What are Terraform locals?**

Answer:

Terraform local values are named internal expressions that can be reused within a module. They are commonly used to reduce duplication, define calculated values, standardize naming, and simplify complex expressions.

---

**Question: What is the difference between a variable and a local?**

Answer:

An input variable allows values to enter a Terraform module from external sources such as tfvars, environment variables, or module arguments. A local value is defined internally and is generally used for reusable expressions, transformations, or calculated values.

---

**Question: What does the merge function do?**

Answer:

The `merge()` function combines multiple maps or objects into one. If duplicate keys exist, the value from the later argument takes precedence.

---

**Question: What is a Terraform for expression?**

Answer:

A `for` expression transforms one collection into another collection. It can create lists, sets, or maps and can also filter elements using conditions.

---

**Question: What is a splat expression?**

Answer:

A splat expression is a concise syntax for extracting the same attribute from multiple elements or resource instances, such as retrieving the public IP addresses of resources created with `count`.

---

**Question: Why did your splat expression fail after changing from count to for_each?**

Answer:

Changing from `count` to `for_each` changed the resource collection from an index-based tuple-like structure to a key-based map of resource instances. I replaced the splat expression with a `for` expression that iterated over the resource map and created a map of instance names to IP addresses.

---

**Question: What is each.key?**

Answer:

`each.key` represents the current key when a resource or module uses `for_each`.

---

**Question: What is each.value?**

Answer:

`each.value` represents the value associated with the current key in the collection supplied to `for_each`.

---

# 38. Final Mental Model

```text
INPUT VARIABLES
      |
      v
  var.name
      |
      v
+--------------------------+
| Terraform Configuration  |
+--------------------------+
      |
      +------> locals
      |           |
      |           v
      |       local.name
      |
      +------> merge()
      |           |
      |           v
      |     Combine Maps
      |
      +------> count
      |           |
      |           v
      |      count.index
      |
      +------> for_each
      |           |
      |           +----> each.key
      |           |
      |           +----> each.value
      |
      +------> Splat Expression
      |           |
      |           v
      |     Extract Attributes
      |
      +------> For Expression
                  |
                  v
         Transform Collections
```

---

# 39. Key Lessons from Our Lab

```text
locals
   |
   +----> Reusable internal values


local.common_tags
   |
   +----> Common AWS tags


merge()
   |
   +----> Common Tags + Resource-Specific Tags


count.index
   |
   +----> Numeric resource instance identity


each.key
   |
   +----> Key-based resource identity


each.value
   |
   +----> Configuration associated with the key


Splat Expression
   |
   +----> Extract same attribute from multiple instances


For Expression
   |
   +----> Transform collections


count Outputs
   |
   +----> List of IP Addresses


for_each Outputs
   |
   +----> Map of Name => IP Address
```

The main professional takeaway is:

```text
Terraform is not only about defining resources.

Professional Terraform requires understanding how to:

Store Data
Reference Data
Transform Data
Reuse Data
Preserve Resource Identity
Produce Useful Outputs
```
