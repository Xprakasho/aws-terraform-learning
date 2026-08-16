# AWS Terraform Modules → EKS Learning Notes

## 1. Learning Objective

This lab is part of the broader AWS/Terraform learning path.

The goal is not simply to memorize Terraform syntax. The goal is to
understand how a modern cloud platform is assembled from reusable
Terraform modules and how those modules feed outputs into other modules.

The architecture we are building is:

``` text
Terraform Root
│
├── Network
├── Security Group
├── IAM Role
├── Key Pair
├── Compute
└── EKS
     │
     ├── EKS Control Plane
     └── Managed Node Group
            │
            └── EC2 Worker Nodes
                   │
                   └── Kubernetes Pods
```

The important design principle is:

> Create a resource once in the appropriate module, expose the required
> information through outputs, and consume those outputs from other
> modules.

------------------------------------------------------------------------

# 2. Terraform Module Structure

Our root module evolved into this structure:

``` text
terraform-modules/
├── data.tf
├── locals.tf
├── main.tf
├── modules
│   ├── compute
│   │   ├── main.tf
│   │   ├── outputs.tf
│   │   ├── user-data.sh
│   │   └── variables.tf
│   ├── iam-role
│   │   ├── main.tf
│   │   ├── outputs.tf
│   │   └── variables.tf
│   ├── key-pair
│   │   ├── main.tf
│   │   ├── outputs.tf
│   │   └── variables.tf
│   ├── network
│   │   ├── main.tf
│   │   ├── outputs.tf
│   │   └── variables.tf
│   ├── security-group
│   │   ├── main.tf
│   │   ├── outputs.tf
│   │   └── variables.tf
│   └── eks
│       ├── main.tf
│       ├── outputs.tf
│       └── variables.tf
├── outputs.tf
├── provider.tf
├── terraform.tfvars
└── variables.tf
```

The EKS module was intentionally created as a **separate module** rather
than putting EKS into the generic compute module.

Reason:

-   EC2 compute and EKS are different abstractions.
-   EKS contains a managed Kubernetes control plane.
-   EKS managed node groups are a separate AWS service abstraction.
-   Keeping EKS separate makes the module reusable and easier to
    understand.

------------------------------------------------------------------------

# 3. Network Module Evolution

Initially the network module supported one public subnet.

We then expanded it to support:

-   Multiple public subnets
-   Multiple private subnets
-   Multiple Availability Zones
-   NAT Gateway
-   Private route tables
-   Private routes through NAT

Root variables became:

``` hcl
variable "vpc_cidr" {
  description = "VPC CIDR"
  type        = string
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets"
  type        = list(string)
}

variable "availability_zones" {
  description = "Availability Zones for the network"
  type        = list(string)
}

variable "instances" {
  description = "EC2 instances to create"

  type = map(object({
    instance_type = string
  }))
}
```

Example lab configuration:

``` hcl
vpc_cidr = "10.0.0.0/16"

public_subnet_cidrs = [
  "10.0.1.0/24",
  "10.0.2.0/24"
]

private_subnet_cidrs = [
  "10.0.11.0/24",
  "10.0.12.0/24"
]

availability_zones = [
  "us-east-1a",
  "us-east-1b"
]
```

The important network pattern is:

``` text
VPC
│
├── Public Subnet A
├── Public Subnet B
│
├── Private Subnet A ── Private RT ──┐
│                                    │
└── Private Subnet B ── Private RT ──┤
                                     │
                                NAT Gateway
                                     │
                                Public Subnet
                                     │
                                Internet Gateway
```

Private workloads can therefore reach the internet for outbound traffic
without receiving public IP addresses.

------------------------------------------------------------------------

# 4. Terraform `for_each` and Multiple Subnets

When resources use `for_each`, their attributes must be accessed using a
specific instance key.

For example:

``` hcl
aws_subnet.public[each.key].id
```

rather than:

``` hcl
aws_subnet.public.id
```

We encountered this error during the network expansion:

``` text
Error: Missing resource instance key

Because aws_subnet.public has "for_each" set,
its attributes must be accessed on specific instances.
```

This was an important Terraform lesson:

``` text
for_each resource
      ↓
creates multiple instances
      ↓
resource["key"]
```

------------------------------------------------------------------------

# 5. Network Outputs

The network module exposes values needed by other modules.

Important outputs:

``` hcl
output "vpc_id" {
  value = aws_vpc.main.id
}

output "public_subnet_ids" {
  value = [
    for subnet in aws_subnet.public : subnet.id
  ]
}

output "private_subnet_ids" {
  value = [
    for subnet in aws_subnet.private : subnet.id
  ]
}

output "nat_gateway_id" {
  value = aws_nat_gateway.main.id
}

output "private_route_table_ids" {
  value = [
    for route_table in aws_route_table.private : route_table.id
  ]
}
```

The root module can then consume:

``` hcl
module.network.vpc_id
```

and:

``` hcl
module.network.private_subnet_ids
```

This is the core module-to-module dependency pattern.

------------------------------------------------------------------------

# 6. NAT Gateway

We added a NAT route for private route tables:

``` hcl
resource "aws_route" "private_nat" {

  for_each = aws_route_table.private

  route_table_id = each.value.id

  destination_cidr_block = "0.0.0.0/0"

  nat_gateway_id = aws_nat_gateway.main.id
}
```

Conceptually:

``` text
Private EC2 / EKS Node
        │
        ▼
Private Route Table
        │
        ▼
NAT Gateway
        │
        ▼
Internet Gateway
        │
        ▼
Internet
```

This became important for EKS because the worker nodes were placed in
private subnets.

------------------------------------------------------------------------

# 7. EKS Architecture

The most important EKS concept learned:

## Control Plane

AWS manages the EKS control plane.

It includes the Kubernetes control-plane functionality such as:

-   Kubernetes API server
-   Control-plane components
-   Cluster state/control functions

We do not SSH into the EKS control plane.

## Data Plane

The application workloads run on worker nodes.

In this lab:

``` text
EKS Managed Node Group
        │
        ├── EC2 t3.small
        └── EC2 t3.small
```

Application Pods run on these worker nodes.

Therefore:

``` text
Control Plane → AWS managed

Data Plane → EC2 worker nodes
```

------------------------------------------------------------------------

# 8. Why EKS Is a Separate Terraform Module

The root module consumes the existing network module:

``` hcl
module "eks" {

  source = "./modules/eks"

  cluster_name    = "terraform-eks-lab"
  cluster_version = "1.33"

  vpc_id = module.network.vpc_id

  subnet_ids = module.network.private_subnet_ids

  node_instance_types = [
    "t3.small"
  ]

  node_desired_size = 2
  node_min_size     = 1
  node_max_size     = 3

  common_tags = local.common_tags
}
```

The important relationship is:

``` text
module.network
     │
     ├── vpc_id
     │
     └── private_subnet_ids
              │
              ▼
        module.eks
```

We do **not** create another VPC inside the EKS module.

Benefits:

-   Avoids duplication
-   Keeps ownership clear
-   Makes modules reusable
-   Creates explicit dependencies
-   Models how real Terraform projects are structured

------------------------------------------------------------------------

# 9. EKS IAM Concepts

The EKS module contains separate IAM responsibilities.

## Cluster IAM Role

The EKS control plane assumes the cluster IAM role.

The role uses a trust relationship for:

``` text
Principal:
eks.amazonaws.com

Action:
sts:AssumeRole
```

The cluster role receives the required EKS cluster policy.

## Node IAM Role

The EC2 worker nodes require their own IAM role.

The trust relationship allows:

``` text
Principal:
ec2.amazonaws.com

Action:
sts:AssumeRole
```

The node role receives the policies required by the EKS managed node
group, including:

-   AmazonEKSWorkerNodePolicy
-   AmazonEKS_CNI_Policy
-   AmazonEC2ContainerRegistryPullOnly

The conceptual separation is:

``` text
EKS Control Plane
       │
       └── Cluster IAM Role

EC2 Worker Nodes
       │
       └── Node IAM Role
```

------------------------------------------------------------------------

# 10. First EKS Deployment Attempt

The initial node group used:

``` hcl
node_instance_types = [
  "t3.medium"
]
```

with:

``` hcl
node_desired_size = 2
node_min_size     = 1
node_max_size     = 3
```

Terraform successfully created the EKS cluster, but the node group
remained in:

``` text
CREATING
```

The Auto Scaling Group showed:

``` text
Desired = 2
Instances = []
```

This was an important troubleshooting situation.

Instead of guessing, we inspected AWS.

------------------------------------------------------------------------

# 11. EKS / ASG Troubleshooting

We identified the Auto Scaling Group created by the EKS managed node
group.

The ASG existed and had:

``` text
Desired capacity = 2
Instances = []
```

The EKS node group had:

``` text
status = CREATING
health.issues = []
```

We then inspected Auto Scaling activity history.

The actual launch failure showed that the requested `t3.medium` instance
type was not eligible under the account's Free Tier restriction.

This demonstrated an important troubleshooting pattern:

``` text
EKS Node Group
      │
      ▼
Auto Scaling Group
      │
      ▼
EC2 Instance Launch
      │
      ▼
AWS capacity / account validation
```

The failure was therefore below the EKS abstraction.

Lesson:

> When an EKS managed node group is stuck creating, inspect the node
> group and underlying Auto Scaling Group instead of assuming that EKS
> itself is broken.

------------------------------------------------------------------------

# 12. Choosing a Different Instance Type

We asked AWS which instance types were reported as Free-Tier eligible:

``` bash
aws ec2 describe-instance-types \
  --filters Name=free-tier-eligible,Values=true \
  --query 'InstanceTypes[].InstanceType' \
  --output text
```

The account returned types including:

``` text
c7i-flex.large
t4g.small
t4g.micro
t3.micro
t3.small
m7i-flex.large
```

For this lab we selected:

``` hcl
node_instance_types = [
  "t3.small"
]
```

Reason:

-   2 vCPU
-   2 GiB memory
-   x86 architecture
-   Simple choice for this Kubernetes learning lab
-   Avoids introducing ARM architecture considerations from the T4g
    family

------------------------------------------------------------------------

# 13. Terraform Replacement of Failed Node Group

After changing `t3.medium` to `t3.small`, Terraform reported:

``` text
module.eks.aws_eks_node_group.this is tainted, so must be replaced
```

and:

``` text
-/+ destroy and then create replacement
```

The plan was:

``` text
Plan: 1 to add, 0 to change, 1 to destroy.
```

This was expected because the previous node group had failed creation.

Terraform correctly reconciled the failed resource by replacing it.

The replacement completed successfully:

``` text
module.eks.aws_eks_node_group.this:
Creation complete after 2m23s
```

and:

``` text
Apply complete! Resources: 1 added, 0 changed, 1 destroyed.
```

------------------------------------------------------------------------

# 14. Verify EKS Through AWS CLI

We verified the cluster:

``` bash
aws eks describe-cluster \
  --name terraform-eks-lab \
  --query 'cluster.{name:name,status:status,version:version,endpoint:endpoint}' \
  --output table
```

Result:

``` text
status  = ACTIVE
version = 1.33
```

We verified the node group:

``` bash
aws eks describe-nodegroup \
  --cluster-name terraform-eks-lab \
  --nodegroup-name terraform-eks-lab-nodes \
  --query 'nodegroup.{status:status,instanceTypes:instanceTypes,desired:scalingConfig.desiredSize,min:scalingConfig.minSize,max:scalingConfig.maxSize}' \
  --output table
```

Result:

``` text
status        ACTIVE
instanceType  t3.small
desired       2
min           1
max           3
```

At this point the AWS-side EKS infrastructure was healthy.

------------------------------------------------------------------------

# 15. AWS CLI Version Problem

Initially the WSL environment had:

``` text
aws-cli/1.22.34
```

The command:

``` bash
aws eks update-kubeconfig \
  --region us-east-1 \
  --name terraform-eks-lab
```

failed with:

``` text
'NoneType' object is not iterable
```

The EKS cluster itself was healthy, so we investigated the client.

The AWS CLI was upgraded to v2.

After installation, the shell was still resolving the old executable,
so:

``` bash
hash -r
```

was required.

The final AWS CLI version was:

``` text
aws-cli/2.36.24
```

and:

``` bash
which aws
```

returned:

``` text
/usr/local/bin/aws
```

------------------------------------------------------------------------

# 16. Configure kubectl for EKS

After AWS CLI v2 was active:

``` bash
aws eks update-kubeconfig \
  --region us-east-1 \
  --name terraform-eks-lab
```

successfully added the EKS context to:

``` text
~/.kube/config
```

We verified:

``` bash
kubectl config current-context
```

and received the EKS cluster context.

Important concept:

> `kubectl` runs from the administrator's machine. It does not need to
> run from an EC2 worker node.

Our actual architecture is:

``` text
WSL
 │
 │ kubectl
 │
 ▼
EKS Kubernetes API Server
 │
 ▼
AWS Managed Control Plane
 │
 ▼
Worker Nodes
 │
 ▼
Pods
```

SSH access to worker nodes is not required for normal Kubernetes
administration.

------------------------------------------------------------------------

# 17. Kubernetes Cluster Verification

We ran:

``` bash
kubectl get nodes -o wide
```

and obtained two Ready nodes.

Both were:

``` text
STATUS = Ready
VERSION = v1.33.13-eks...
OS = Amazon Linux 2023
CONTAINER-RUNTIME = containerd
```

We then inspected all Pods:

``` bash
kubectl get pods -A
```

The expected system components were running in `kube-system`.

Examples:

``` text
aws-node
coredns
kube-proxy
```

The result was:

``` text
aws-node     Running
coredns      Running
kube-proxy   Running
```

We also checked namespaces:

``` bash
kubectl get ns
```

The standard namespaces were present:

``` text
default
kube-node-lease
kube-public
kube-system
```

This proved that the Kubernetes foundation was healthy.

------------------------------------------------------------------------

# 18. What the EKS System Pods Do

## aws-node

AWS VPC CNI component.

It provides Kubernetes networking integrated with the AWS VPC.

Conceptually:

``` text
Pod
 │
 ▼
AWS VPC CNI
 │
 ▼
AWS VPC networking
```

## kube-proxy

Runs on worker nodes and supports Kubernetes Service networking.

## CoreDNS

Provides Kubernetes DNS.

For example, applications can resolve Kubernetes Services using
Kubernetes DNS names.

------------------------------------------------------------------------

# 19. Final Architecture Achieved

At the end of this session:

``` text
                         AWS
                          │
             ┌────────────┴────────────┐
             │                         │
          Network                     EKS
             │                         │
       ┌─────┴─────┐          ┌────────┴────────┐
       │           │          │                 │
    Public      Private    Control Plane     Node Group
    Subnets     Subnets    AWS Managed          │
       │           │                           │
       │         NAT Gateway             ┌─────┴─────┐
       │           │                     │           │
       │        Internet              EC2 t3.small EC2 t3.small
       │                                  │           │
       └──────────────────────────────────┴───────────┘
                                             │
                                            Pods
```

And from the administrator workstation:

``` text
WSL
 │
 ├── AWS CLI v2
 │
 └── kubectl
       │
       ▼
   EKS API Server
```

------------------------------------------------------------------------

# 20. Key Lessons

### Terraform

-   Modules should have clear responsibilities.
-   Root modules compose reusable child modules.
-   Module outputs become inputs to other modules.
-   `for_each` creates keyed resource instances.
-   Multiple resource instances must be referenced using their keys.
-   Terraform can replace failed/tainted resources.
-   `terraform plan` is an important diagnostic tool, not just a
    pre-apply step.

### AWS Networking

-   Public and private subnets have different routing purposes.
-   NAT Gateway provides outbound internet access for private resources.
-   EKS worker nodes can run in private subnets.
-   EKS consumes the existing VPC rather than creating a separate VPC.

### EKS

-   AWS manages the control plane.
-   Worker nodes form the data plane.
-   Managed node groups are backed by EC2 Auto Scaling infrastructure.
-   EKS node-group failures may originate from the underlying ASG/EC2
    layer.
-   EKS does not require SSH access to worker nodes for normal
    administration.
-   `kubectl` normally operates remotely through the Kubernetes API.

### Kubernetes

-   Nodes are the worker machines.
-   Pods run on nodes.
-   `aws-node` handles AWS VPC CNI networking.
-   `kube-proxy` supports Service networking.
-   CoreDNS provides cluster DNS.
-   Kubernetes has standard system namespaces.

------------------------------------------------------------------------

# 21. Current Learning Checkpoint

Completed:

``` text
Terraform module architecture             ✅
Network module                            ✅
Public/private subnets                    ✅
NAT Gateway                               ✅
Private routing                           ✅
IAM module                                ✅
Compute module                            ✅
EKS module                                ✅
EKS control plane                         ✅
EKS managed node group                    ✅
AWS CLI v2                                ✅
kubectl / kubeconfig                      ✅
2 Ready EKS worker nodes                  ✅
Kubernetes system Pods verified           ✅
```

------------------------------------------------------------------------

# 22. What We Will Do Next

Before continuing, destroy the AWS lab resources to avoid unnecessary
cost:

``` bash
terraform destroy
```

Then verify that the infrastructure is gone.

After cleanup, we will recreate the environment when needed and continue
from the Kubernetes layer.

## Next learning sequence

### Step 1 --- Manual Kubernetes deployment

We will deliberately avoid Argo CD initially.

We will deploy one simple application using `kubectl` and learn:

``` text
Deployment
    │
    ▼
ReplicaSet
    │
    ▼
Pods
    │
    ▼
Service
```

We will inspect the resources rather than only applying YAML.

### Step 2 --- Helm

Take the same application and package it using Helm.

Learn:

-   Chart structure
-   `values.yaml`
-   Templates
-   Releases
-   Upgrades
-   Rollbacks

### Step 3 --- Argo CD

Then introduce GitOps:

``` text
Git Repository
      │
      ▼
    Argo CD
      │
      ▼
 Kubernetes API
      │
      ▼
      EKS
      │
      ▼
 Application
```

The purpose is to understand **why Argo CD exists**, rather than
learning Argo CD as a collection of commands.

------------------------------------------------------------------------

# 23. Final Mental Model

The overall platform we are building toward is:

``` text
                         Git
                          │
                          ▼
                    GitHub Actions
                          │
                          ▼
                     Container
                       Image
                          │
                          ▼
                         ECR
                          │
                          ▼
Terraform ─────────────► EKS
  │                       │
  ├── Network             ├── Kubernetes
  ├── Security            │
  ├── IAM                 ├── Helm
  ├── Compute             │
  └── EKS                 └── Argo CD
                              │
                              ▼
                         Application
```

This is the broader direction of the DevOps/GitOps learning path.
