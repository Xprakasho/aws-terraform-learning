
# Terraform Remote Backend, State Locking, and Lifecycle

## 1. Purpose of This Note

This note covers the Terraform concepts practiced while moving an existing AWS Foundation lab from local state to an S3 remote backend.

The main concepts are:

- Local Terraform state
- Remote Terraform state
- S3 backend
- Backend bootstrap pattern
- State migration
- Terraform backend metadata
- State locking
- Concurrent Terraform operations
- Dynamic AMI changes
- Resource replacement
- Lifecycle meta-arguments

The main lifecycle arguments practiced were:

- `create_before_destroy`
- `prevent_destroy`
- `ignore_changes`

---

# 2. Starting Point: Local Terraform State

Initially, the AWS Foundation lab used local Terraform state.

The state files were:

```text
terraform.tfstate
terraform.tfstate.backup
```

The following command was used to inspect the state:

```bash
terraform state list
```

At one point the local state was empty:

```text
The state file is empty.
No resources are represented.
```

The raw state file showed:

```json
{
  "version": 4,
  "terraform_version": "1.15.6",
  "outputs": {},
  "resources": []
}
```

This means:

```text
Terraform Configuration
        |
        v
Local State File
terraform.tfstate
        |
        v
Tracks AWS Infrastructure
```

Important:

Terraform state is not the infrastructure itself.

State is Terraform's record of the infrastructure it manages.

---

# 3. Why Use Remote State?

Local state is acceptable for learning and small personal experiments.

However, production environments normally use remote state.

Problems with local state include:

- State exists only on one machine
- Difficult for teams to share
- Risk of accidental deletion
- No centralized state management
- Concurrent Terraform operations can cause problems

Remote state solves many of these problems.

Our architecture became:

```text
Terraform Configuration
        |
        v
AWS S3 Backend
        |
        v
terraform.tfstate
        |
        v
AWS Infrastructure
```

---

# 4. Backend Bootstrap Pattern

A Terraform backend has an important bootstrap problem.

We want Terraform to store state in S3.

But the S3 bucket must already exist before Terraform can use it as a backend.

Therefore, we created a separate Terraform project.

Repository structure:

```text
aws-terraform-learning/
|
+-- labs/
|   |
|   +-- terraform-aws-foundation/
|   |
|   +-- terraform-backend-bootstrap/
|
+-- docs/
    |
    +-- terraform/
```

The bootstrap project creates the infrastructure required by the backend.

The architecture is:

```text
terraform-backend-bootstrap
        |
        v
Creates S3 Bucket
        |
        v
terraform-aws-foundation
        |
        v
Uses S3 Bucket as Backend
```

This separation is important.

The Terraform configuration using the backend should not normally create its own backend storage.

---

# 5. Backend Bootstrap Resources

The backend bootstrap project created four AWS resources.

The Terraform plan showed:

```text
Plan: 4 to add, 0 to change, 0 to destroy.
```

The resources were:

```text
aws_s3_bucket.terraform_state

aws_s3_bucket_versioning.terraform_state

aws_s3_bucket_server_side_encryption_configuration.terraform_state

aws_s3_bucket_public_access_block.terraform_state
```

The dependency graph showed:

```text
S3 Versioning
        |
        v
S3 Bucket

S3 Encryption
        |
        v
S3 Bucket

Public Access Block
        |
        v
S3 Bucket
```

The S3 bucket is the main resource.

The other resources configure the bucket.

---

# 6. S3 Bucket Configuration

The backend bucket was configured with several important security and reliability features.

## Versioning

Versioning protects previous versions of the Terraform state.

If state changes or becomes corrupted, previous versions may be recoverable.

Conceptually:

```text
terraform.tfstate
        |
        +-- Version 1
        |
        +-- Version 2
        |
        +-- Version 3
```

---

## Server-Side Encryption

Encryption protects the state data stored inside S3.

Terraform state can contain sensitive infrastructure information.

Therefore, encryption should be enabled.

---

## Public Access Block

Terraform state should never be publicly accessible.

The S3 Public Access Block prevents accidental public exposure.

The security model becomes:

```text
Terraform State Bucket
        |
        +-- Versioning Enabled
        |
        +-- Encryption Enabled
        |
        +-- Public Access Blocked
```

---

# 7. Terraform Outputs from Bootstrap Project

After applying the bootstrap configuration:

```bash
terraform output
```

The output showed:

```text
state_bucket_arn  = "arn:aws:s3:::omp-terraform-state-2026"

state_bucket_name = "omp-terraform-state-2026"
```

The output confirmed that the backend bucket was created successfully.

---

# 8. Verifying Bootstrap State

The following command was used:

```bash
terraform state list
```

The output showed:

```text
aws_s3_bucket.terraform_state

aws_s3_bucket_public_access_block.terraform_state

aws_s3_bucket_server_side_encryption_configuration.terraform_state

aws_s3_bucket_versioning.terraform_state
```

This confirmed that Terraform was managing all four backend resources.

We also inspected an individual resource:

```bash
terraform state show aws_s3_bucket.terraform_state
```

This displayed the attributes stored in Terraform state.

---

# 9. Configuring the S3 Backend

The AWS Foundation project was configured to use the S3 bucket.

Example backend configuration:

```hcl
terraform {
  backend "s3" {
    bucket       = "omp-terraform-state-2026"
    key          = "terraform-aws-foundation/terraform.tfstate"
    region       = "us-east-1"
    profile      = "om-Devops"
    encrypt      = true
    use_lockfile = true
  }
}
```

Important backend parameters:

```text
bucket
```

Specifies where the state is stored.

```text
key
```

Specifies the path of the state object inside the bucket.

```text
region
```

Specifies the AWS region.

```text
profile
```

Specifies the AWS CLI profile.

```text
encrypt
```

Enables encryption.

```text
use_lockfile
```

Enables S3 state locking.

---

# 10. Understanding the Backend Key

The backend key was:

```text
terraform-aws-foundation/terraform.tfstate
```

Therefore, the state object location became:

```text
S3 Bucket
|
+-- terraform-aws-foundation/
    |
    +-- terraform.tfstate
```

Complete conceptual location:

```text
s3://omp-terraform-state-2026/terraform-aws-foundation/terraform.tfstate
```

---

# 11. Terraform Init and State Migration

After adding the backend configuration, Terraform initialization was required.

The important command was:

```bash
terraform init -migrate-state
```

This tells Terraform:

```text
Current State
      |
      v
Move State
      |
      v
New Backend
```

In our case:

```text
Local terraform.tfstate
        |
        v
terraform init -migrate-state
        |
        v
S3 Remote State
```

This is a critical operation.

Without correct state migration, Terraform may lose track of previously managed infrastructure.

---

# 12. Verifying Remote State

After backend configuration, we checked:

```bash
terraform state pull
```

Initially the remote state was empty because no infrastructure had yet been applied into the remote state.

After applying the configuration:

```bash
terraform state list
```

The output showed:

```text
data.aws_ami.ubuntu

aws_instance.lab_ec2["app"]

aws_instance.lab_ec2["db"]

aws_instance.lab_ec2["web"]

aws_internet_gateway.igw

aws_route_table.public_rt

aws_route_table_association.public_assoc

aws_s3_bucket.lab_bucket

aws_security_group.public_sg

aws_subnet.public

aws_vpc.main
```

This confirmed that the AWS Foundation infrastructure was now represented in the remote state.

---

# 13. Verifying the State Object in S3

The AWS CLI command used was:

```bash
aws s3 ls s3://omp-terraform-state-2026/ \
  --recursive \
  --profile om-Devops
```

The output showed:

```text
terraform-aws-foundation/terraform.tfstate
```

This proved that the Terraform state was physically stored in S3.

The architecture was now:

```text
Terraform CLI
      |
      v
S3 Backend
      |
      v
terraform-aws-foundation/terraform.tfstate
      |
      v
AWS Resources
```

---

# 14. `.terraform/terraform.tfstate` vs Infrastructure State

An important concept was discovered while inspecting:

```bash
cat .terraform/terraform.tfstate
```

This file contained backend configuration information.

For example:

```text
backend type
bucket
key
region
profile
encrypt
use_lockfile
```

This file is not the main infrastructure state.

It is local Terraform backend metadata.

The distinction is:

```text
.terraform/terraform.tfstate
        |
        v
Backend Metadata
```

versus:

```text
S3 terraform.tfstate
        |
        v
Infrastructure State
```

This is an important Terraform troubleshooting concept.

---

# 15. State Locking

The S3 backend was configured with:

```hcl
use_lockfile = true
```

Terraform displayed:

```text
Acquiring state lock. This may take a few moments...
```

After completing the operation:

```text
Releasing state lock. This may take a few moments...
```

The purpose of state locking is to prevent multiple Terraform operations from modifying the same state simultaneously.

Conceptually:

```text
Terraform Process A
        |
        v
Acquires Lock
        |
        v
Modifies State
        |
        v
Releases Lock
```

While Process A owns the lock:

```text
Terraform Process B
        |
        v
Must Wait or Fail
```

---

# 16. Concurrent Terraform Operations

We tested Terraform commands from multiple terminal windows.

One terminal performed an operation.

Another terminal ran:

```bash
terraform plan
```

Terraform displayed state locking messages.

This demonstrated that remote state locking protects the shared state.

Important:

State locking does not mean every Terraform command will always fail when another terminal exists.

The result depends on:

- Whether another operation currently holds the lock
- How long the operation takes
- Whether the first operation has already released the lock

The important mental model is:

```text
No Active Lock
      |
      v
Terraform Operation Starts
      |
      v
Lock Acquired
      |
      v
Operation Runs
      |
      v
Lock Released
```

---

# 17. Dynamic AMI Data Source

The EC2 configuration used:

```hcl
ami = data.aws_ami.ubuntu.id
```

The AMI was retrieved dynamically using a Terraform data source.

This means the selected AMI can change over time.

Initially:

```text
ami-0a02a779008fa3b99
```

Later the data source returned:

```text
ami-052355af2a014bd2c
```

Terraform therefore detected:

```text
Old AMI
   |
   v
New AMI
```

---

# 18. Why the EC2 Instances Required Replacement

Terraform showed:

```text
Plan: 3 to add, 0 to change, 3 to destroy.
```

The detailed plan showed:

```text
ami = "old-ami" -> "new-ami" # forces replacement
```

Changing an EC2 AMI cannot be performed as an in-place update.

Therefore:

```text
AMI Change
    |
    v
Existing EC2 Cannot Be Modified In Place
    |
    v
EC2 Replacement Required
```

Terraform represented this as:

```text
-/+
```

or:

```text
+/-
```

depending on lifecycle behavior.

---

# 19. Understanding `# forces replacement`

The most important line in the Terraform plan was:

```text
# forces replacement
```

This tells us exactly why Terraform wants to recreate the resource.

A useful troubleshooting command was:

```bash
terraform plan | grep 'forces replacement'
```

This displayed:

```text
ami = "old-ami" -> "new-ami" # forces replacement
```

The key troubleshooting lesson is:

Do not only read:

```text
Plan: 3 to add, 0 to change, 3 to destroy
```

Always investigate:

```text
WHY?
```

Look for:

```text
# forces replacement
```

---

# 20. Lifecycle Meta-Arguments

Terraform provides the `lifecycle` block to control resource behavior.

Example:

```hcl
resource "aws_instance" "lab_ec2" {

  lifecycle {
    create_before_destroy = true
    prevent_destroy       = true

    ignore_changes = [
      ami
    ]
  }
}
```

The three lifecycle concepts practiced were:

```text
create_before_destroy
prevent_destroy
ignore_changes
```

---

# 21. `create_before_destroy`

Default replacement behavior is conceptually:

```text
Destroy Old Resource
        |
        v
Create New Resource
```

This may cause downtime.

With:

```hcl
lifecycle {
  create_before_destroy = true
}
```

Terraform attempts:

```text
Create New Resource
        |
        v
New Resource Ready
        |
        v
Destroy Old Resource
```

The plan symbol can change from:

```text
-/+
```

to:

```text
+/-
```

The important mental model is:

```text
Default
Destroy -> Create
```

versus:

```text
create_before_destroy
Create -> Destroy
```

---

# 22. `prevent_destroy`

The following lifecycle configuration was tested:

```hcl
lifecycle {
  prevent_destroy = true
}
```

Terraform returned:

```text
Error: Instance cannot be destroyed
```

The reason was:

```text
Resource has lifecycle.prevent_destroy set,
but the plan calls for this resource to be destroyed.
```

The AMI change required EC2 replacement.

Replacement includes destruction of the old instance.

Therefore:

```text
AMI Changed
      |
      v
Replacement Required
      |
      v
Old EC2 Must Be Destroyed
      |
      v
prevent_destroy Blocks Operation
```

Terraform stopped the plan.

This demonstrates that `prevent_destroy` acts as a safety mechanism.

---

# 23. `ignore_changes`

The following configuration was tested:

```hcl
lifecycle {
  ignore_changes = [
    ami
  ]
}
```

The AMI data source returned a new AMI.

However, Terraform ignored the AMI difference for the EC2 instances.

The result changed from:

```text
Plan: 3 to add, 0 to change, 3 to destroy
```

to no EC2 infrastructure changes.

Terraform only showed:

```text
Changes to Outputs
```

The mental model is:

```text
Configuration Value Changes
        |
        v
Terraform Detects Difference
        |
        v
Is Attribute in ignore_changes?
       / \
     Yes  No
      |    |
      v    v
 Ignore   Plan Change
```

---

# 24. Important Behavior of `ignore_changes`

The EC2 resources ignored the AMI change.

However, the output still changed:

```text
ubuntu_ami_id
```

because the output referenced:

```hcl
data.aws_ami.ubuntu.id
```

The data source itself returned the new AMI.

Therefore:

```text
Data Source
    |
    v
New AMI ID
    |
    +--------------------+
    |                    |
    v                    v
EC2 Resource           Output
    |                    |
ignore_changes          Changes
    |
No EC2 Replacement
```

This is an important distinction.

`ignore_changes` applies to the managed resource attribute.

It does not stop the data source from returning a new value.

It also does not automatically stop outputs from changing.

---

# 25. Lifecycle Comparison

| Lifecycle Argument | Purpose |
|---|---|
| `create_before_destroy` | Creates replacement before deleting old resource |
| `prevent_destroy` | Blocks operations that require destroying the resource |
| `ignore_changes` | Ignores selected attribute differences |

Mental model:

```text
create_before_destroy
        |
        v
Control Replacement Order
```

```text
prevent_destroy
        |
        v
Protect Resource from Destruction
```

```text
ignore_changes
        |
        v
Ignore Selected Configuration Drift
```

---

# 26. Terraform Plan Troubleshooting Workflow

A useful workflow learned from this lab is:

```text
terraform plan
      |
      v
Check Summary
      |
      v
Add / Change / Destroy?
      |
      v
Inspect Resource Details
      |
      v
Look for:
# forces replacement
      |
      v
Identify Changed Attribute
      |
      v
Check Lifecycle Rules
      |
      v
Decide Whether to Apply
```

Useful commands:

```bash
terraform plan
```

```bash
terraform plan | grep 'forces replacement'
```

```bash
terraform state list
```

```bash
terraform state show RESOURCE_ADDRESS
```

```bash
terraform state pull
```

---

# 27. Safe Backend Destruction Order

The backend must not be destroyed before the infrastructure that depends on it.

Incorrect order:

```text
Destroy Backend Bucket
        |
        v
Remote State Lost
        |
        v
Foundation Infrastructure Still Exists
```

Correct order:

```text
Foundation Infrastructure
        |
        v
terraform destroy
        |
        v
Foundation Resources Deleted
        |
        v
Backend Bootstrap
        |
        v
terraform destroy
        |
        v
Backend Resources Deleted
```

Therefore:

```text
Destroy Workload First
Destroy Backend Last
```

This is one of the most important operational lessons from the lab.

---

# 28. Key Troubleshooting Lessons

## Lesson 1: An Empty Local State Does Not Mean No AWS Resources Exist

Always distinguish between:

```text
Terraform State
```

and:

```text
Real AWS Infrastructure
```

---

## Lesson 2: Backend Metadata Is Not Infrastructure State

This file:

```text
.terraform/terraform.tfstate
```

contains backend metadata.

The real remote state is stored in S3.

---

## Lesson 3: Always Investigate Replacement

When Terraform shows:

```text
3 to add
3 to destroy
```

do not immediately apply.

Find the reason.

Look for:

```text
# forces replacement
```

---

## Lesson 4: Dynamic Data Sources Can Change

Using:

```hcl
data.aws_ami.ubuntu.id
```

means the selected AMI may change when newer images become available.

That change can trigger EC2 replacement.

---

## Lesson 5: Lifecycle Rules Change Terraform Behavior

The same AMI change produced different behavior:

```text
No Lifecycle Rule
        |
        v
Replace EC2
```

```text
create_before_destroy
        |
        v
Create New Before Destroying Old
```

```text
prevent_destroy
        |
        v
Block the Plan
```

```text
ignore_changes = [ami]
        |
        v
Ignore EC2 AMI Difference
```

---

# 29. Final Architecture

The final architecture practiced in this lab was:

```text
Developer
    |
    v
Terraform CLI
    |
    +-----------------------------+
    |                             |
    v                             v
Terraform Configuration      S3 Remote Backend
                                  |
                                  v
                           terraform.tfstate
                                  |
                                  v
                             State Locking
    |
    v
AWS Provider
    |
    +-- VPC
    |
    +-- Subnet
    |
    +-- Internet Gateway
    |
    +-- Route Table
    |
    +-- Security Group
    |
    +-- EC2 Instances
    |
    +-- S3 Lab Bucket
```

---

# 30. Interview Questions

## Q1. What is Terraform state?

Terraform state is Terraform's record of the infrastructure resources it manages and the mapping between Terraform resource addresses and real infrastructure objects.

---

## Q2. Why use remote state?

Remote state provides centralized storage, team accessibility, improved reliability, and support for state locking.

---

## Q3. Why create the backend separately?

The backend must exist before Terraform can use it to store state. Therefore, backend infrastructure is commonly created through a separate bootstrap process.

---

## Q4. What does `terraform init -migrate-state` do?

It initializes the new backend and migrates existing Terraform state from the previous backend to the new backend.

---

## Q5. What is state locking?

State locking prevents concurrent Terraform operations from modifying the same state simultaneously.

---

## Q6. Why did changing the AMI replace the EC2 instances?

The EC2 AMI is a ForceNew-style attribute. Changing it requires Terraform to replace the EC2 instance rather than update it in place.

---

## Q7. What does `create_before_destroy` do?

It changes replacement order so Terraform attempts to create the replacement resource before destroying the existing resource.

---

## Q8. What does `prevent_destroy` do?

It blocks Terraform plans that require destruction of the protected resource.

---

## Q9. What does `ignore_changes` do?

It tells Terraform to ignore changes to specified resource attributes during update planning.

---

## Q10. Why did the AMI output change even when `ignore_changes = [ami]` was configured?

Because the output referenced the AMI data source directly. The data source returned a new AMI value, while `ignore_changes` only instructed Terraform to ignore the AMI difference on the EC2 resource.

---

# 31. Final Mental Model

```text
Terraform Configuration
        |
        v
terraform init
        |
        v
Backend Initialization
        |
        v
S3 Remote State
        |
        v
State Lock
        |
        v
terraform plan
        |
        v
Compare:

Configuration
     +

State
     +

Real Infrastructure
        |
        v
Execution Plan
        |
        +-- In-Place Change
        |
        +-- Replacement
        |
        +-- Destruction
        |
        v
Lifecycle Rules
        |
        +-- create_before_destroy
        |
        +-- prevent_destroy
        |
        +-- ignore_changes
        |
        v
terraform apply
```

The central lesson is:

> Terraform is not only about creating AWS resources. Terraform manages the relationship between configuration, state, real infrastructure, dependency graphs, backend storage, locking, and resource lifecycle behavior.
