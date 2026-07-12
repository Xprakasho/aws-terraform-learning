
# Terraform Dependencies and Resource Graph

## 1. Purpose of This Note

This note covers how Terraform understands relationships between resources.

Important concepts:

- Implicit Dependencies
- Explicit Dependencies
- Resource References
- `depends_on`
- Terraform Dependency Graph
- Resource Creation Order
- Resource Destruction Order

In our AWS Foundation lab, multiple resources depended on each other:

```text
VPC
 |
 +----> Subnet
 |
 +----> Security Group

Internet Gateway
 |
 v
Route Table
 |
 v
Route Table Association

Subnet + Security Group + AMI
 |
 v
EC2 Instances
```

Terraform automatically analyzed these relationships before creating the infrastructure.

---

# 2. Why Dependencies Are Important

Infrastructure resources cannot always be created independently.

For example, an AWS subnet needs a VPC.

```text
VPC must exist
      |
      v
Subnet can be created
```

An EC2 instance in our lab required:

```text
AMI
Subnet
Security Group
```

Therefore, Terraform needed to understand these relationships.

Terraform uses dependencies to determine the correct order for:

```text
Resource creation
Resource modification
Resource destruction
```

---

# 3. Resource References

The most common way to create a dependency is by referencing an attribute of another resource.

Example:

```hcl
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
}
```

Subnet:

```hcl
resource "aws_subnet" "public" {
  vpc_id = aws_vpc.main.id

  cidr_block = "10.0.1.0/24"
}
```

This expression:

```hcl
aws_vpc.main.id
```

references the VPC.

Terraform automatically understands:

```text
aws_subnet.public
        |
        v
depends on
        |
        v
aws_vpc.main
```

This is called an:

```text
Implicit Dependency
```

---

# 4. Understanding a Terraform Resource Reference

Consider:

```hcl
aws_vpc.main.id
```

Breakdown:

```text
aws_vpc
   |
   +----> Resource Type

main
   |
   +----> Local Resource Name

id
   |
   +----> Resource Attribute
```

General format:

```text
resource_type.resource_name.attribute
```

Example:

```hcl
aws_subnet.public.id
```

means:

```text
Resource Type  = aws_subnet

Resource Name  = public

Attribute      = id
```

---

# 5. Implicit Dependencies

An implicit dependency is automatically created when one Terraform object references another.

Example from our lab:

```hcl
resource "aws_subnet" "public" {
  vpc_id = aws_vpc.main.id
}
```

Terraform detects:

```text
Subnet depends on VPC
```

No additional configuration is required.

Another example:

```hcl
resource "aws_security_group" "public_sg" {
  vpc_id = aws_vpc.main.id
}
```

Terraform detects:

```text
Security Group depends on VPC
```

---

# 6. EC2 Dependencies in Our Lab

Our EC2 configuration contained:

```hcl
resource "aws_instance" "lab_ec2" {
  for_each = var.instances

  ami           = data.aws_ami.ubuntu.id
  instance_type = each.value.instance_type

  subnet_id = aws_subnet.public.id

  vpc_security_group_ids = [
    aws_security_group.public_sg.id
  ]
}
```

Terraform detected several relationships.

```text
EC2
 |
 +----> AMI Data Source
 |
 +----> Subnet
 |
 +----> Security Group
```

These references automatically created dependencies.

---

# 7. Dependency Chain in Our Lab

Our infrastructure contained the following relationships:

```text
aws_vpc.main
     |
     +--------------------+
     |                    |
     v                    v
aws_subnet.public   aws_security_group.public_sg
     |
     v
aws_instance.lab_ec2
```

A more complete view:

```text
                AWS AMI Data Source
                        |
                        v
VPC -----> Subnet -----> EC2
 |                       ^
 |                       |
 +----> Security Group --+

VPC -----> Internet Gateway
                 |
                 v
            Route Table
                 |
                 v
       Route Table Association
                 ^
                 |
               Subnet
```

Terraform builds these relationships automatically from references in the configuration.

---

# 8. Terraform Dependency Graph

Terraform creates an internal dependency graph.

The graph represents:

```text
Resources
Data Sources
Dependencies
Relationships
```

Terraform analyzes the graph before performing operations.

Conceptually:

```text
Terraform Configuration
          |
          v
Parse Resource References
          |
          v
Build Dependency Graph
          |
          v
Calculate Execution Plan
          |
          v
Create / Update / Destroy Resources
```

---

# 9. Terraform Does Not Simply Read Files Top to Bottom

This is an important concept.

Terraform does not create resources based on the order of `.tf` files.

For example:

```text
main.tf
networking.tf
compute.tf
security.tf
```

Terraform does not necessarily process:

```text
main.tf first

then networking.tf

then compute.tf
```

Terraform loads all `.tf` files in the working directory as one configuration.

Then it builds the dependency graph.

Therefore:

```text
File order does not control resource creation order.
```

Dependencies control resource creation order.

---

# 10. Example: File Names Do Not Define Dependencies

Suppose:

```text
compute.tf
```

contains:

```hcl
subnet_id = aws_subnet.public.id
```

And:

```text
networking.tf
```

contains:

```hcl
resource "aws_subnet" "public" {
  ...
}
```

Terraform understands the dependency even though the resources are in separate files.

Why?

Because of:

```hcl
aws_subnet.public.id
```

Terraform sees the resource reference and builds the dependency relationship.

---

# 11. Resource Creation Order

Terraform creates resources according to the dependency graph.

Example:

```text
VPC
 |
 v
Subnet
 |
 v
EC2
```

Creation order:

```text
1. VPC

2. Subnet

3. EC2
```

Terraform cannot create the subnet before the VPC because:

```hcl
vpc_id = aws_vpc.main.id
```

Terraform cannot create EC2 before the subnet because:

```hcl
subnet_id = aws_subnet.public.id
```

---

# 12. Parallel Resource Creation

Terraform can create independent resources in parallel.

Example:

```text
             VPC
              |
       +------+------+
       |             |
       v             v
    Subnet      Security Group
```

After the VPC exists:

```text
Subnet
```

and:

```text
Security Group
```

may be created independently.

Terraform can therefore process them concurrently.

This improves infrastructure deployment efficiency.

---

# 13. Resource Destruction Order

Terraform also uses the dependency graph during destruction.

Creation:

```text
VPC
 |
 v
Subnet
 |
 v
EC2
```

Destruction generally occurs in reverse dependency order:

```text
EC2
 |
 v
Subnet
 |
 v
VPC
```

Why?

Because Terraform should not attempt to delete a VPC while resources that depend on it still exist.

---

# 14. Explicit Dependencies

Sometimes Terraform cannot automatically detect a required dependency.

In such situations, we can use:

```hcl
depends_on
```

Example:

```hcl
resource "aws_instance" "example" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t3.micro"

  depends_on = [
    aws_internet_gateway.igw
  ]
}
```

This explicitly tells Terraform:

```text
Create the Internet Gateway before this EC2 resource.
```

This is called:

```text
Explicit Dependency
```

---

# 15. depends_on Syntax

General syntax:

```hcl
depends_on = [
  resource_type.resource_name
]
```

Example:

```hcl
depends_on = [
  aws_vpc.main
]
```

Multiple dependencies:

```hcl
depends_on = [
  aws_vpc.main,
  aws_internet_gateway.igw
]
```

---

# 16. Implicit vs Explicit Dependencies

| Feature | Implicit Dependency | Explicit Dependency |
|---|---|---|
| Created By | Resource Reference | `depends_on` |
| Terraform Detects Automatically | Yes | Manually Defined |
| Preferred Method | Yes | Only When Necessary |
| Example | `aws_vpc.main.id` | `depends_on = [aws_vpc.main]` |

Preferred approach:

```text
Use resource references whenever possible.
```

Use:

```text
depends_on
```

only when the dependency cannot be represented through normal references.

---

# 17. Why Implicit Dependencies Are Preferred

Consider:

```hcl
resource "aws_subnet" "public" {
  vpc_id = aws_vpc.main.id
}
```

This line provides Terraform with two pieces of information:

```text
1. The value required for vpc_id

2. The dependency relationship
```

Compare that with:

```hcl
resource "aws_subnet" "public" {
  vpc_id = "vpc-123456"

  depends_on = [
    aws_vpc.main
  ]
}
```

The second configuration is less maintainable.

The resource reference is preferable because it naturally connects the resources.

---

# 18. Data Source Dependencies

Dependencies are not limited to managed resources.

Our EC2 instances used:

```hcl
ami = data.aws_ami.ubuntu.id
```

Terraform must first retrieve information from the data source.

Conceptually:

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

Terraform understands this relationship from:

```hcl
data.aws_ami.ubuntu.id
```

---

# 19. Known After Apply

During our lab, Terraform plan displayed:

```text
(Known after apply)
```

Example:

```text
instance_public_ip = (Known after apply)
```

Why?

Because some attributes do not exist until AWS creates the resource.

Conceptually:

```text
Terraform Configuration
        |
        v
Resource Creation
        |
        v
AWS Assigns Attribute
        |
        v
Terraform Records Value
```

Examples include:

```text
Resource IDs
Public IP addresses
Private IP addresses
ARNs
```

These values may be unavailable during the planning phase.

---

# 20. Terraform Graph Command

Terraform provides:

```bash
terraform graph
```

This command generates a representation of the Terraform dependency graph.

Example:

```bash
terraform graph
```

The output uses the DOT graph description language.

The raw output is not designed primarily for normal terminal reading.

It can be processed by visualization tools such as Graphviz.

The important Foundation-level concept is:

```text
Terraform internally builds a dependency graph from the configuration.
```

---

# 21. Dependency Example from Our Networking Configuration

Our networking configuration conceptually contains:

```text
VPC
 |
 +----> Internet Gateway
 |
 +----> Subnet
 |
 +----> Security Group
```

The route table depends on:

```text
VPC
Internet Gateway route target
```

The route table association depends on:

```text
Route Table
Subnet
```

EC2 depends on:

```text
Subnet
Security Group
AMI
```

Terraform calculates the complete execution order from these relationships.

---

# 22. Important Professional Practice

Before running:

```bash
terraform apply
```

always inspect:

```bash
terraform plan
```

Look for:

```text
What resources will be created?

What resources will be changed?

What resources will be destroyed?

Are replacements expected?

Are dependency-driven changes expected?
```

For an infrastructure engineer, reading the execution plan is as important as writing Terraform code.

---

# 23. Common Mistake: Unnecessary depends_on

Bad pattern:

```hcl
resource "aws_subnet" "public" {
  vpc_id = aws_vpc.main.id

  depends_on = [
    aws_vpc.main
  ]
}
```

The explicit dependency is unnecessary.

Why?

Because this already creates the dependency:

```hcl
vpc_id = aws_vpc.main.id
```

Terraform automatically knows:

```text
Subnet depends on VPC
```

Do not add `depends_on` when a normal resource reference already represents the relationship.

---

# 24. Common Mistake: Assuming File Order Matters

Incorrect assumption:

```text
Terraform executes:

main.tf
then networking.tf
then compute.tf
```

Correct understanding:

```text
Terraform loads the complete configuration
                |
                v
       Builds Dependency Graph
                |
                v
      Determines Execution Order
```

The names of `.tf` files are primarily for human organization.

---

# 25. Interview Perspective

**Question: How does Terraform determine resource creation order?**

Answer:

Terraform analyzes references between resources and builds a dependency graph. Resources are created according to their dependencies rather than according to the order of `.tf` files.

---

**Question: What is an implicit dependency?**

Answer:

An implicit dependency is automatically created when one Terraform resource references an attribute of another resource. For example, using `aws_vpc.main.id` as the `vpc_id` of a subnet tells Terraform that the subnet depends on the VPC.

---

**Question: What is an explicit dependency?**

Answer:

An explicit dependency is manually defined using the `depends_on` meta-argument. It is used when a dependency exists but Terraform cannot infer it from normal resource references.

---

**Question: What is the difference between implicit and explicit dependencies?**

Answer:

Implicit dependencies are automatically detected from references between Terraform objects. Explicit dependencies are manually declared with `depends_on`. Implicit dependencies are generally preferred because they directly express the flow of data between resources.

---

**Question: Does Terraform execute `.tf` files in order?**

Answer:

No. Terraform loads all `.tf` files in the current module as one configuration, builds a dependency graph, and determines execution order based on resource relationships.

---

**Question: Can Terraform create multiple resources simultaneously?**

Answer:

Yes. Terraform can process independent parts of the dependency graph concurrently when there are no dependency relationships requiring sequential execution.

---

# 26. Final Mental Model

```text
Terraform Configuration
          |
          v
  Read All .tf Files
          |
          v
Analyze Resource References
          |
          v
Build Dependency Graph
          |
          v
+---------------------------+
|                           |
v                           v
Dependent Resources    Independent Resources
|                           |
v                           v
Correct Order           Parallel Execution
|                           |
+-------------+-------------+
              |
              v
       Terraform Apply
```

---

# 27. Key Lessons from Our Lab

```text
aws_vpc.main.id
        |
        +----> Creates implicit dependency

aws_subnet.public.id
        |
        +----> EC2 depends on Subnet

aws_security_group.public_sg.id
        |
        +----> EC2 depends on Security Group

data.aws_ami.ubuntu.id
        |
        +----> EC2 uses AMI Data Source

depends_on
        |
        +----> Explicit dependency

All .tf Files
        |
        +----> One Terraform Configuration

Dependency Graph
        |
        +----> Controls Execution Order
```

The main professional takeaway is:

```text
Terraform does not execute infrastructure code line by line.

Terraform builds and executes a dependency graph.
```
