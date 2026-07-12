
# Terraform State and Moved Blocks

## 1. Purpose of This Note

This note covers:

- Terraform State
- Resource Addresses
- State Inspection
- State Drift
- Local State Files
- State Backup Files
- `terraform state` Commands
- Refactoring Terraform Resources
- `moved` Blocks
- `count` to `for_each` Migration
- Safe Infrastructure Refactoring

These concepts are critical because Terraform must remember which real infrastructure resource belongs to which resource defined in the Terraform configuration.

In our AWS Foundation lab, we experienced this directly when we changed:

```hcl
count = var.instance_count
```

to:

```hcl
for_each = var.instances
```

Terraform initially planned:

```text
2 to add
0 to change
2 to destroy
```

The reason was not AWS.

The reason was:

```text
Terraform Resource Addresses Changed
```

We then used `moved` blocks to safely migrate the state.

---

# 2. What Is Terraform State?

Terraform state is Terraform's record of the infrastructure it manages.

By default, local Terraform state is stored in:

```text
terraform.tfstate
```

Conceptually:

```text
Terraform Configuration
        |
        v
Terraform State
        |
        v
Real Infrastructure
```

Terraform uses state to understand the relationship between:

```text
Terraform Resource Address
            |
            v
Actual AWS Resource
```

Example:

```text
aws_vpc.main
        |
        v
vpc-0193894966702fe36
```

Terraform state records this relationship.

---

# 3. Why Terraform Needs State

Consider this configuration:

```hcl
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
}
```

Terraform creates an AWS VPC.

AWS returns an ID:

```text
vpc-0193894966702fe36
```

Terraform must remember:

```text
aws_vpc.main
        =
vpc-0193894966702fe36
```

Without state, Terraform would not know which existing AWS VPC belongs to:

```hcl
aws_vpc.main
```

Therefore, state allows Terraform to:

```text
Track Resources
Detect Changes
Calculate Plans
Update Infrastructure
Destroy Infrastructure
Manage Dependencies
Store Resource Attributes
```

---

# 4. Terraform's Three-Side Comparison

A useful mental model is:

```text
        Terraform Configuration
                 |
                 |
                 v
            Terraform
           Plan / Refresh
            /         \
           /           \
          v             v
Terraform State     Real Infrastructure
```

Terraform compares:

```text
Desired Configuration
Current State
Actual Infrastructure
```

Conceptually:

```text
Configuration
     |
     | What should exist?
     |
     v
Terraform State
     |
     | What does Terraform know?
     |
     v
AWS Infrastructure
       What actually exists?
```

Terraform uses this information to calculate the required actions.

---

# 5. Local State Files in Our Lab

Our Foundation lab contained:

```text
terraform.tfstate
terraform.tfstate.backup
```

The main file:

```text
terraform.tfstate
```

contains the current local state.

The backup file:

```text
terraform.tfstate.backup
```

contains a backup of the previous state snapshot.

These files were visible when we ran:

```bash
tree -a
```

---

# 6. State Files Must Not Be Committed to Git

Our `.gitignore` contains:

```gitignore
.terraform/
*.tfstate
*.tfstate.*
*.tfvars
```

Therefore:

```text
terraform.tfstate
terraform.tfstate.backup
terraform.tfvars
.terraform/
```

are not committed to Git.

We verified this using:

```bash
git check-ignore -v \
labs/terraform-aws-foundation/.terraform \
labs/terraform-aws-foundation/terraform.tfstate \
labs/terraform-aws-foundation/terraform.tfstate.backup \
labs/terraform-aws-foundation/terraform.tfvars
```

Terraform state may contain infrastructure details and potentially sensitive information.

Therefore:

```text
Do not commit Terraform state to Git.
```

In professional environments, Terraform state is normally stored using a remote backend.

Remote state and state locking will be covered during Intermediate Terraform.

---

# 7. Terraform Resource Addresses

Terraform identifies managed objects using resource addresses.

Example:

```hcl
resource "aws_vpc" "main" {
}
```

Resource address:

```text
aws_vpc.main
```

Structure:

```text
aws_vpc
   |
   +----> Resource Type

main
   |
   +----> Resource Name
```

General format:

```text
resource_type.resource_name
```

---

# 8. Resource Addresses with count

Previously, our EC2 configuration used:

```hcl
resource "aws_instance" "lab_ec2" {
  count = var.instance_count
}
```

With:

```hcl
instance_count = 2
```

Terraform created:

```text
aws_instance.lab_ec2[0]
aws_instance.lab_ec2[1]
```

These are index-based resource addresses.

Conceptually:

```text
count

0 ----> First EC2 Instance

1 ----> Second EC2 Instance
```

Terraform state tracked:

```text
aws_instance.lab_ec2[0]
aws_instance.lab_ec2[1]
```

---

# 9. Resource Addresses with for_each

Later, we changed the configuration to:

```hcl
resource "aws_instance" "lab_ec2" {
  for_each = var.instances
}
```

Initially, our instances were:

```hcl
instances = ["web", "app"]
```

Terraform now expected:

```text
aws_instance.lab_ec2["web"]
aws_instance.lab_ec2["app"]
```

These are key-based resource addresses.

Conceptually:

```text
for_each

"web" ----> Web EC2 Instance

"app" ----> App EC2 Instance
```

Later we added:

```text
"db"
```

Terraform created:

```text
aws_instance.lab_ec2["db"]
```

---

# 10. count vs for_each Resource Addresses

With `count`:

```text
aws_instance.lab_ec2[0]
aws_instance.lab_ec2[1]
```

With `for_each`:

```text
aws_instance.lab_ec2["web"]
aws_instance.lab_ec2["app"]
```

The important point is:

```text
Terraform Resource Identity Changed
```

Terraform does not automatically know:

```text
[0] = "web"

[1] = "app"
```

From Terraform's perspective:

```text
Old Resource Addresses:

aws_instance.lab_ec2[0]
aws_instance.lab_ec2[1]


New Resource Addresses:

aws_instance.lab_ec2["web"]
aws_instance.lab_ec2["app"]
```

These appear to be different resources.

---

# 11. What Happened in Our Lab?

After changing:

```hcl
count = var.instance_count
```

to:

```hcl
for_each = var.instances
```

Terraform planned:

```text
Plan: 2 to add, 0 to change, 2 to destroy.
```

Why?

Terraform state contained:

```text
aws_instance.lab_ec2[0]
aws_instance.lab_ec2[1]
```

But the configuration expected:

```text
aws_instance.lab_ec2["web"]
aws_instance.lab_ec2["app"]
```

Terraform therefore calculated:

```text
Old addresses no longer exist in configuration
                    |
                    v
                 DESTROY


New addresses do not exist in state
                    |
                    v
                  CREATE
```

Result:

```text
2 Destroy
2 Create
```

---

# 12. Why This Is Dangerous in Production

Suppose these EC2 instances were production servers.

Terraform plan:

```text
2 to add
0 to change
2 to destroy
```

If we blindly ran:

```bash
terraform apply
```

Terraform could:

```text
Destroy Existing Servers
        |
        v
Create Replacement Servers
```

Possible consequences:

```text
Downtime
Data Loss
IP Address Changes
Application Failure
Service Disruption
```

This is why infrastructure engineers must carefully inspect:

```bash
terraform plan
```

before applying changes.

---

# 13. What Is a moved Block?

A `moved` block tells Terraform that a resource address has changed.

General syntax:

```hcl
moved {
  from = OLD_RESOURCE_ADDRESS
  to   = NEW_RESOURCE_ADDRESS
}
```

Conceptually:

```text
Old Terraform Address
        |
        | moved
        v
New Terraform Address
```

The real infrastructure resource does not need to be destroyed.

Terraform updates its understanding of the resource identity.

---

# 14. Our moved Blocks

We created:

```text
moved.tf
```

with mappings similar to:

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
aws_instance.lab_ec2[0]
          |
          v
aws_instance.lab_ec2["web"]
```

and:

```text
aws_instance.lab_ec2[1]
          |
          v
aws_instance.lab_ec2["app"]
```

Terraform could now understand that these were the same infrastructure resources with new Terraform addresses.

---

# 15. Result After Using moved Blocks

Before `moved` blocks:

```text
Plan: 2 to add, 0 to change, 2 to destroy.
```

After adding the correct state migration:

```text
Plan: 0 to add, 2 to change, 0 to destroy.
```

The important improvement was:

```text
0 to destroy
```

Terraform preserved the existing EC2 instances.

The remaining changes were related to configuration differences rather than Terraform incorrectly treating the existing EC2 instances as completely new resources.

---

# 16. Configuration Refactoring vs Infrastructure Change

This distinction is extremely important.

Sometimes we change Terraform code structure without wanting to change real infrastructure.

Example:

```text
count
  |
  v
for_each
```

This is primarily a Terraform configuration refactoring.

Our intention:

```text
Change Terraform Resource Addressing
```

Not:

```text
Destroy EC2 Instances
Create New EC2 Instances
```

Without state migration:

```text
Code Refactoring
      |
      v
Terraform Sees New Resource Addresses
      |
      v
Destroy + Create
```

With `moved` blocks:

```text
Code Refactoring
      |
      v
Declare Address Migration
      |
      v
Terraform Preserves Resource Identity
```

---

# 17. terraform state list

We used:

```bash
terraform state list
```

After our `for_each` configuration, the output contained:

```text
data.aws_ami.ubuntu
aws_instance.lab_ec2["app"]
aws_instance.lab_ec2["web"]
aws_internet_gateway.igw
aws_route_table.public_rt
aws_route_table_association.public_assoc
aws_s3_bucket.lab_bucket
aws_security_group.public_sg
aws_subnet.public
aws_vpc.main
```

This command shows the resource addresses currently tracked by Terraform state.

Important:

```text
terraform state list
```

does not show AWS resource IDs directly.

It shows:

```text
Terraform Resource Addresses
```

---

# 18. terraform state show

To inspect a specific resource:

```bash
terraform state show aws_vpc.main
```

For a `for_each` resource:

```bash
terraform state show 'aws_instance.lab_ec2["web"]'
```

Quotes are useful because the shell may interpret special characters.

This command displays information Terraform stores about the selected resource.

Conceptually:

```text
terraform state list
        |
        v
Find Resource Address
        |
        v
terraform state show
        |
        v
Inspect Resource Details
```

---

# 19. terraform show

Another useful command is:

```bash
terraform show
```

This displays information from the current state.

Difference:

```text
terraform state list
        |
        +----> List Resource Addresses


terraform state show ADDRESS
        |
        +----> Inspect One Resource


terraform show
        |
        +----> Display Current State Information
```

---

# 20. terraform state Commands

Common commands include:

```bash
terraform state list
terraform state show
terraform state mv
terraform state rm
```

These commands directly interact with Terraform state.

They must be used carefully.

---

# 21. terraform state mv

The command:

```bash
terraform state mv
```

moves a resource from one Terraform address to another.

Conceptually:

```text
OLD ADDRESS
     |
     v
terraform state mv
     |
     v
NEW ADDRESS
```

Example:

```bash
terraform state mv \
'aws_instance.lab_ec2[0]' \
'aws_instance.lab_ec2["web"]'
```

This directly modifies the state.

---

# 22. moved Block vs terraform state mv

Both can be used during resource address migrations.

`moved` block:

```hcl
moved {
  from = aws_instance.lab_ec2[0]
  to   = aws_instance.lab_ec2["web"]
}
```

CLI command:

```bash
terraform state mv \
'aws_instance.lab_ec2[0]' \
'aws_instance.lab_ec2["web"]'
```

Comparison:

| Feature | moved Block | terraform state mv |
|---|---|---|
| Stored in Configuration | Yes | No |
| Reviewable in Git | Yes | No |
| Documents Refactoring | Yes | No |
| Directly Modifies State | Applied through Terraform workflow | Yes |
| Useful for Team Workflows | Yes | Requires operational coordination |

For configuration refactoring, `moved` blocks provide a declarative and reviewable record of the address change.

---

# 23. terraform state rm

The command:

```bash
terraform state rm RESOURCE_ADDRESS
```

removes a resource from Terraform state.

Important:

```text
terraform state rm
```

does not necessarily delete the real AWS resource.

Instead:

```text
Terraform Stops Tracking the Resource
```

Conceptually:

```text
Before:

Terraform State ----> AWS Resource


After state rm:

Terraform State      AWS Resource
     X                     |
                           |
                    Still Exists
```

This is an advanced and potentially dangerous operation.

Use it only when the operational reason is clearly understood.

---

# 24. State Is Not the Same as Infrastructure

This is a critical mental model.

```text
Terraform Configuration
```

is not:

```text
Terraform State
```

And:

```text
Terraform State
```

is not:

```text
AWS Infrastructure
```

They are three separate things.

```text
Configuration
     |
     | Desired Infrastructure
     |
     v
Terraform State
     |
     | Terraform's Record
     |
     v
Actual AWS Infrastructure
```

Problems can occur when these three are not synchronized correctly.

---

# 25. State Drift

State drift occurs when actual infrastructure differs from the expected Terraform-managed configuration/state.

Example:

Terraform creates:

```text
Security Group:

SSH
HTTP
HTTPS
```

Someone manually changes the AWS console and removes:

```text
HTTP
```

Now:

```text
Terraform Configuration:

SSH
HTTP
HTTPS


Actual AWS:

SSH
HTTPS
```

There is a difference.

Terraform can detect this during planning and propose corrective actions.

---

# 26. Manual Changes and Terraform

Suppose Terraform manages:

```text
Environment = "dev"
```

Someone manually changes the AWS resource to:

```text
Environment = "test"
```

The Terraform configuration still contains:

```text
Environment = "dev"
```

A subsequent Terraform plan may detect the difference and propose restoring:

```text
test ---> dev
```

We practiced a related tag change in our lab when Terraform showed:

```text
Environment = "dev" -> "test"
```

and later changed it back.

---

# 27. terraform refresh

Historically, Terraform provided:

```bash
terraform refresh
```

to update state based on real infrastructure.

In modern Terraform workflows, explicit `terraform refresh` usage is generally less common.

Terraform planning operations can refresh state information as part of normal workflow.

A useful command is:

```bash
terraform plan -refresh-only
```

This allows you to review state changes caused by differences in remote infrastructure without planning normal configuration changes.

Important principle:

```text
Do not run state-changing operations blindly.
```

Always inspect the proposed changes.

---

# 28. State and terraform destroy

When we ran:

```bash
terraform destroy
```

Terraform used state to identify the infrastructure resources under its management.

Conceptually:

```text
Terraform State
      |
      v
Identify Managed Resources
      |
      v
Build Dependency Graph
      |
      v
Destroy Resources
      |
      v
Update Terraform State
```

After destroying everything, we ran:

```bash
terraform state list
```

and received no resources.

That was expected because Terraform no longer tracked any managed resources in that state.

---

# 29. What Happened When We Recreated Infrastructure?

After destroying the lab, we ran:

```bash
terraform plan
```

Terraform showed:

```text
Plan: 8 to add, 0 to change, 0 to destroy.
```

Why?

Because:

```text
Configuration Defined Resources
```

but:

```text
Terraform State Contained No Managed Resources
```

Terraform therefore planned to create the infrastructure again.

---

# 30. State and Outputs

Outputs are also connected to Terraform state.

Example:

```hcl
output "vpc_id" {
  value = aws_vpc.main.id
}
```

After apply:

```text
vpc_id = "vpc-0193894966702fe36"
```

Terraform obtains this information from the managed resource attributes recorded during infrastructure operations.

Our outputs included:

```text
instance_private_ip
instance_public_ip
subnet_id
ubuntu_ami_id
vpc_id
```

---

# 31. count Outputs vs for_each Outputs

With `count`, we used splat expressions:

```hcl
output "instance_public_ip" {
  value = aws_instance.lab_ec2[*].public_ip
}
```

Output:

```text
[
  "3.239.15.35",
  "98.92.227.86"
]
```

After changing to `for_each`, the splat expression was no longer appropriate for the resource structure.

We changed the output to a `for` expression:

```hcl
output "instance_public_ip" {
  value = {
    for name, instance in aws_instance.lab_ec2 :
    name => instance.public_ip
  }
}
```

Output:

```text
{
  "app" = "98.92.227.86"
  "web" = "3.239.15.35"
}
```

This change reflects the difference between:

```text
count
  |
  v
List / Tuple Style Resource Instances
```

and:

```text
for_each
  |
  v
Map / Key-Based Resource Instances
```

---

# 32. Why Stable Resource Addresses Matter

Consider:

```hcl
instances = [
  "web",
  "app",
  "db"
]
```

With `count`, addresses may be:

```text
[0]
[1]
[2]
```

If list ordering changes, resource identity can become difficult to manage safely.

With `for_each`:

```text
["web"]
["app"]
["db"]
```

The key becomes part of the resource identity.

This is often more stable for infrastructure where resources have meaningful unique names.

---

# 33. Important State Safety Rules

Follow these rules:

```text
1. Never manually edit terraform.tfstate unless handling an exceptional recovery scenario with full understanding.

2. Never commit terraform.tfstate to Git.

3. Always inspect terraform plan.

4. Be suspicious of unexpected destroy operations.

5. Understand resource addresses before refactoring.

6. Use moved blocks for declarative resource address migrations.

7. Back up state before risky manual state operations.

8. Use remote state and locking for professional team environments.

9. Do not treat Terraform state as an ordinary configuration file.

10. Understand the difference between configuration, state, and real infrastructure.
```

---

# 34. Professional Workflow Before Refactoring

Suppose we want to change:

```text
count
```

to:

```text
for_each
```

Safe workflow:

```text
1. Inspect Current State

terraform state list


2. Understand Old Resource Addresses

aws_instance.lab_ec2[0]
aws_instance.lab_ec2[1]


3. Define New Configuration

for_each = var.instances


4. Determine New Resource Addresses

aws_instance.lab_ec2["web"]
aws_instance.lab_ec2["app"]


5. Create moved Blocks

OLD ADDRESS ---> NEW ADDRESS


6. Format Configuration

terraform fmt


7. Validate Configuration

terraform validate


8. Run Plan

terraform plan


9. Inspect Carefully for Destroy / Replacement


10. Apply Only After Understanding the Plan

terraform apply


11. Verify State

terraform state list
```

---

# 35. Our Exact Learning Path

Our lab evolved through:

```text
Single EC2 Instance
        |
        v
count = 2
        |
        v
Multiple Indexed Instances
        |
        v
for_each
        |
        v
Terraform Planned Destroy + Create
        |
        v
Investigated Resource Addresses
        |
        v
Added moved Blocks
        |
        v
Preserved Existing EC2 Instances
        |
        v
Added "db"
        |
        v
Terraform Created Only One New EC2 Instance
```

This was an important practical Terraform state exercise.

---

# 36. Interview Perspective

**Question: What is Terraform state?**

Answer:

Terraform state is Terraform's record of the infrastructure resources it manages. It maps Terraform resource addresses to real infrastructure objects and stores resource attributes required for planning and managing infrastructure changes.

---

**Question: Why does Terraform need state?**

Answer:

Terraform needs state to map configuration resources to real infrastructure objects, track resource metadata, calculate changes, manage dependencies, and determine which resources should be created, modified, or destroyed.

---

**Question: What happened when you migrated from count to for_each?**

Answer:

The resource addresses changed from numeric indexes such as `aws_instance.lab_ec2[0]` to key-based addresses such as `aws_instance.lab_ec2["web"]`. Terraform initially interpreted them as different resources and planned to destroy the old instances and create new ones. I used `moved` blocks to map the old addresses to the new addresses and preserve the existing infrastructure.

---

**Question: What is a moved block?**

Answer:

A `moved` block declaratively tells Terraform that a resource address has changed. It allows Terraform to preserve the existing infrastructure object while updating its resource address in state instead of unnecessarily destroying and recreating it.

---

**Question: What is the difference between moved blocks and terraform state mv?**

Answer:

Both can migrate resource addresses. A `moved` block is declarative, stored in configuration, reviewable in Git, and useful for documenting refactoring. `terraform state mv` is an imperative CLI operation that directly changes the current state.

---

**Question: What does terraform state list do?**

Answer:

It lists the Terraform resource addresses currently tracked in state.

---

**Question: What does terraform state rm do?**

Answer:

It removes a resource from Terraform state without necessarily deleting the real infrastructure object. Terraform then stops managing that object unless it is imported or otherwise brought back under management.

---

**Question: What is state drift?**

Answer:

State drift is a condition where actual infrastructure differs from the infrastructure expected by the Terraform configuration and recorded state, often because of manual or external changes.

---

**Question: Should terraform.tfstate be committed to Git?**

Answer:

No. Terraform state should not be committed to Git because it can contain sensitive infrastructure information and because team environments require controlled shared-state access, typically through a remote backend with locking.

---

# 37. Final Mental Model

```text
                TERRAFORM CONFIGURATION
                         |
                         | Desired State
                         v
                  TERRAFORM ENGINE
                    /          \
                   /            \
                  v              v
        TERRAFORM STATE      AWS INFRASTRUCTURE
                  \              /
                   \            /
                    v          v
                   COMPARISON
                       |
                       v
                 EXECUTION PLAN
                       |
         +-------------+-------------+
         |             |             |
         v             v             v
       CREATE        CHANGE        DESTROY
```

Resource identity:

```text
Terraform Address
        |
        v
Terraform State
        |
        v
Real AWS Resource
```

Safe refactoring:

```text
Old Resource Address
        |
        v
     moved {}
        |
        v
New Resource Address
        |
        v
Same Infrastructure Resource
```

---

# 38. Key Lessons from Our Lab

```text
terraform.tfstate
        |
        +----> Terraform's infrastructure record


terraform state list
        |
        +----> Shows tracked resource addresses


count
        |
        +----> Numeric resource addresses


for_each
        |
        +----> Key-based resource addresses


count ---> for_each
        |
        +----> Resource addresses changed


Unexpected:

2 add
2 destroy
        |
        +----> Investigate before apply


moved {}
        |
        +----> Map old address to new address


Result:

0 destroy
        |
        +----> Existing infrastructure preserved


Main Professional Lesson:

Never judge a Terraform change only by the code.

Always understand:

Configuration
+
Resource Addresses
+
State
+
Execution Plan
+
Real Infrastructure
```
