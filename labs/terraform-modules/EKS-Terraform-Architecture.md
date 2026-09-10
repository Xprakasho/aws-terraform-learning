Since Argo CD/GitOps is the next major stage, we should first build enough EKS understanding that when Argo CD deploys into the cluster, you understand what is underneath it rather than treating EKS as a black box.

And yes: we continue using our Terraform module architecture, not a separate throwaway EKS lab.

Where we are

Our existing platform:

terraform-modules/
│
├── data.tf
├── locals.tf
├── main.tf
├── outputs.tf
├── provider.tf
├── variables.tf
│
└── modules/
    ├── compute/
    ├── iam-role/
    ├── key-pair/
    ├── network/
    └── security-group/

We will now extend this.

New EKS module
modules/
├── compute/
├── iam-role/
├── key-pair/
├── network/
├── security-group/
└── eks/
    ├── main.tf
    ├── variables.tf
    └── outputs.tf

But we won't immediately write the module.

First we need to understand what Terraform is actually going to create.

EKS mental model

Think of EKS as two major layers:

                 EKS CLUSTER
                      │
          ┌───────────┴───────────┐
          │                       │
     Control Plane             Data Plane
          │                       │
   AWS managed by AWS        Worker Capacity
                                  │
                       ┌──────────┴──────────┐
                       │                     │
                  EC2 Nodes             EC2 Nodes
                       │                     │
                       └──────────┬──────────┘
                                  │
                              Kubernetes
                                  │
                              Pods

The important distinction:

EKS Control Plane

AWS manages:

Kubernetes API server
etcd
control-plane infrastructure
control-plane availability
Data Plane

We still need compute capacity for workloads.

That can be:

EKS Managed Node Groups
Self-managed EC2 nodes
Fargate
other EKS compute options

For our learning path, we'll start with EKS Managed Node Groups.

How this connects to our existing modules

This is where your modular approach becomes useful.

Network Module
       │
       ├── VPC
       ├── Private Subnets
       └── Route Tables
              │
              ▼
        EKS Module
              │
       ┌──────┴──────┐
       │             │
 EKS Cluster    Node Group
       │             │
       │           IAM Role
       │             │
       └──────┬──────┘
              ▼
         Kubernetes

So EKS doesn't replace our networking module.

EKS consumes the networking module's outputs.

For example:

module "network" {
  source = "./modules/network"
}

Then:

module "eks" {
  source = "./modules/eks"

  vpc_id     = module.network.vpc_id
  subnet_ids = module.network.private_subnet_ids
}

That's exactly the module-to-module relationship we wanted to learn.

And this will prepare us for Argo CD

Eventually:

Terraform
   │
   ├── VPC
   ├── Subnets
   ├── IAM
   ├── EKS
   └── Node Groups
            │
            ▼
       EKS Cluster
            │
            ▼
        kubectl
            │
            ▼
        Argo CD
            │
            ▼
      Kubernetes Apps
            │
            ▼
       AUSF-UDM / Nginx /
       other applications

Terraform's responsibility:

Build the platform.

Argo CD's responsibility:

Continuously reconcile applications inside Kubernetes.

That separation is extremely important.

Today's EKS progression

I suggest we do it in this order:

Part 1 — EKS architecture

Understand:

Control plane
Data plane
API server
Node groups
Pods
AWS ↔ Kubernetes boundary
Part 2 — EKS networking

Understand:

VPC
 │
 ├── Private Subnet AZ1
 ├── Private Subnet AZ2
 └── Private Subnet AZ3

and why EKS nodes normally belong in private subnets.

Part 3 — EKS IAM

Connect what we just learned:

IAM Role
   │
   ├── EKS Cluster Role
   │
   └── Node IAM Role

This is where today's IAM lab becomes directly useful.

Part 4 — Terraform EKS module

Then we'll actually build:

modules/eks/
Part 5 — Managed Node Group

Understand:

EKS Cluster
      │
      ▼
Managed Node Group
      │
      ▼
EC2
      │
      ▼
Kubernetes Node
Part 6 — Connect with kubectl

Finally:

aws eks update-kubeconfig ...
kubectl get nodes

and prove that our Terraform-created EKS cluster is actually usable.

One important boundary

We do not install Argo CD yet.

First we'll get to:

AWS
 ↓
Terraform
 ↓
VPC
 ↓
EKS
 ↓
Node Group
 ↓
kubectl
 ↓
Kubernetes cluster

Once that is solid, Argo CD becomes the next layer:

Git
 ↓
Argo CD
 ↓
EKS
 ↓
Kubernetes
 ↓
Application

That way you won't just learn "how to install Argo CD". You'll understand the entire platform it is operating on.

So yes — today we start EKS, using the existing Terraform modules as our foundation.

=================================================================================

I would keep EKS as a separate module, even though EKS ultimately uses compute capacity.

The reason is that "compute" is a broader infrastructure category, while EKS is a managed Kubernetes platform, not simply another EC2 compute resource.

I would structure our modules like this
modules/
├── network/
├── security-group/
├── iam-role/
├── key-pair/
│
├── compute/
│   ├── launch-template
│   ├── autoscaling
│   └── ec2
│
├── eks/
│   ├── cluster
│   ├── node-group
│   └── iam
│
├── storage/
└── monitoring/

Conceptually:

Cloud Platform
│
├── Compute
│   ├── EC2
│   ├── Launch Template
│   └── Auto Scaling Group
│
├── Kubernetes Platform
│   └── EKS
│       ├── Control Plane
│       └── Managed Node Groups
│
├── Networking
├── Storage
├── Security
└── Monitoring
Why separate eks?

Because EKS introduces Kubernetes-specific concerns that don't belong inside a generic EC2 compute module:

EKS cluster
Kubernetes API endpoint
Cluster IAM role
Node IAM role
Managed node groups
Kubernetes version
Add-ons
Cluster security groups
OIDC / Pod Identity
Kubernetes networking
EKS access configuration

If we put all of that into compute, the module eventually becomes something like:

compute/
├── ec2
├── launch-template
├── asg
├── eks
├── node-group
├── kubernetes
└── ...

That's too tightly coupled.

But there is an important relationship

EKS does depend on compute, but it doesn't have to be implemented inside the compute module.

Think:

                 Network
                    │
        ┌───────────┴───────────┐
        │                       │
     Compute                   EKS
        │                       │
   EC2 / ASG              EKS Cluster
                              │
                         Node Groups
                              │
                             EC2

The EKS node group ultimately launches EC2 instances, but AWS manages that relationship for us when we use EKS Managed Node Groups.

That's why I would not make our compute module responsible for EKS node groups.

This also helps our learning objective

We're trying to understand modern cloud architecture, not just make Terraform work.

So we'll deliberately separate:

Generic compute
modules/compute/

Used for:

EC2
Launch Template
ASG
Kubernetes platform
modules/eks/

Used for:

EKS Cluster
Managed Node Groups
EKS Add-ons
EKS IAM

Then later:

modules/eks/
       │
       ▼
EKS
       │
       ▼
Argo CD
       │
       ▼
Kubernetes Applications

This separation will make Argo CD much easier to understand.

So I would revise our five-pillar model slightly:

Cloud Platform
│
├── Networking
├── Compute
│   ├── EC2
│   ├── Launch Template
│   └── ASG
│
├── Kubernetes Platform
│   └── EKS
│
├── Storage
├── Security
└── Monitoring

Bottom line: keep EKS as a separate modules/eks module. It will still consume outputs from network, security, and iam-role, and its managed node groups provide the compute capacity. This gives us a cleaner architecture and maps much better to how platform teams separate responsibilities.

====================================================================================================================================

EKS — Part 1: Architecture

Our objective today is to understand what Terraform will eventually create and how it connects to the modules we already have.

1. What is EKS?

Amazon EKS (Elastic Kubernetes Service) is AWS's managed Kubernetes service.

The key word is managed.

AWS manages the Kubernetes control plane for us, while we still need to provide compute capacity for our workloads.

Think:

                    EKS
                     │
          ┌──────────┴──────────┐
          │                     │
     Control Plane          Data Plane
       AWS-managed          We manage/use
          │                     │
    ┌─────┼─────┐         ┌─────┴─────┐
    │     │     │         │           │
 API   Scheduler etc.   Node        Node
 Server                    │           │
                           ▼           ▼
                          Pods        Pods
2. Control Plane

The control plane is the Kubernetes brain.

Important components conceptually include:

API Server
Scheduler
Controller Manager
etcd

For EKS, AWS operates this control-plane infrastructure for us.

We don't SSH into the EKS control plane.

We interact with it through the Kubernetes API.

For example:

kubectl get nodes

kubectl communicates with the Kubernetes API server.

3. Data Plane

This is where your applications actually run.

For our first EKS implementation, we'll use:

EKS Managed Node Groups

Architecture:

EKS Cluster
     │
     ▼
Managed Node Group
     │
 ┌───┴────┐
 ▼        ▼
EC2      EC2
 │        │
 ▼        ▼
Pods     Pods

AWS manages much of the lifecycle of the node group, while the EC2 instances provide the actual Kubernetes worker capacity.

4. Where does our existing Terraform project fit?

This is where our modular approach becomes useful.

We already have:

modules/
├── network/
├── security-group/
├── iam-role/
├── key-pair/
└── compute/

We're adding:

modules/
└── eks/

The EKS module doesn't recreate networking.

Instead:

                network module
                     │
          ┌──────────┴──────────┐
          ▼                     ▼
        VPC ID             Private Subnets
          │                     │
          └──────────┬──────────┘
                     ▼
                 EKS module
                     │
             ┌───────┴───────┐
             ▼               ▼
        EKS Cluster      Node Group
                              │
                              ▼
                             EC2

That's an important Terraform design principle:

A module should consume infrastructure it depends on rather than duplicate it.

5. EKS IAM

Today's IAM lab now becomes directly useful.

EKS involves multiple IAM relationships.

At a high level:

EKS Cluster
     │
     ▼
Cluster IAM Role

and:

Managed Node Group
     │
     ▼
Node IAM Role

The node role is conceptually similar to what we just built for EC2:

EC2
 │
 ▼
Instance Profile
 │
 ▼
IAM Role
 │
 ▼
AWS permissions

With EKS managed nodes, AWS handles much of the node lifecycle, but the underlying nodes still require appropriate IAM permissions.

6. EKS Networking

This is where I want to be careful.

Our current network module has mainly:

VPC
Public Subnet
Internet Gateway
Route Table

That is not yet the network architecture I want for our EKS platform.

Before creating the EKS cluster, we'll evolve the network module toward:

VPC
│
├── Public Subnet AZ1
├── Public Subnet AZ2
│
├── Private Subnet AZ1
└── Private Subnet AZ2

Then:

Public Subnets
     │
     ├── ALB
     └── NAT Gateway
             │
             ▼
Private Subnets
     │
     └── EKS Nodes

This is why we're not going to blindly create the EKS module yet.

EKS depends on a suitable network.

7. The Architecture We're Building

Our eventual platform will look like:

                         Internet
                            │
                            ▼
                           ALB
                            │
                 ┌──────────┴──────────┐
                 │                     │
             Public AZ1            Public AZ2
                 │                     │
                 └──────────┬──────────┘
                            │
                       EKS Cluster
                            │
                 ┌──────────┴──────────┐
                 │                     │
            Private AZ1            Private AZ2
                 │                     │
              Node 1                  Node 2
                 │                     │
               Pods                   Pods
                 │                     │
                 └──────────┬──────────┘
                            │
                       NAT Gateway
                            │
                         Internet

Later, Argo CD sits inside the Kubernetes layer, not inside Terraform's infrastructure layer:

Terraform
   │
   ▼
AWS Infrastructure
   │
   ▼
EKS
   │
   ▼
Kubernetes
   │
   ▼
Argo CD
   │
   ▼
Applications

That's the boundary I want you to understand very clearly.

8. Terraform vs Argo CD

This will be extremely important later.

Terraform

We use it to provision:

VPC
Subnets
NAT
IAM
Security Groups
EKS
Node Groups
ALB infrastructure
Storage infrastructure
CloudWatch
Argo CD

We use it to manage Kubernetes application state:

Namespaces
Deployments
Services
ConfigMaps
Ingress
Helm Applications
Application configuration

So:

Terraform = Platform / Infrastructure
Argo CD   = Kubernetes Application Delivery

There can be some overlap, but this is our primary boundary.

9. Today's first checkpoint

Before we touch Terraform, I want you to be able to answer these five questions:

Q1

What does AWS manage in EKS?

Q2

Where do our application Pods actually run?

Q3

Why do we need worker/node capacity if AWS manages the control plane?

Q4

Why should our EKS module consume the network module's outputs rather than create another VPC?

Q5

What's the difference between:

EKS Cluster

and

Managed Node Group

===================================================================================================

Q1 — What does AWS manage?

Your answer:

Control plane

✅ Correct.

EKS manages the Kubernetes control-plane components for us.

AWS
 │
 ▼
EKS Control Plane
 ├── API Server
 ├── Scheduler
 ├── Controllers
 └── etcd

You don't manage these EC2 machines directly.

Q2 — Where do application Pods run?

Your answer:

Data plane, because application runs in data-plane EC2.

✅ Correct for our design.

We'll use:

EKS
 │
 ▼
Managed Node Group
 │
 ▼
EC2 Nodes
 │
 ▼
Pods

So remember:

Pods run on Kubernetes nodes. Our nodes will be EC2 instances.

Q3 — Why consume outputs from the Network module?

Your answer is exactly the modular Terraform thinking we want.

You said:

create resource once, use it as output with another module, save time and avoid repetition.

✅ Correct.

For example:

Network Module
     │
     ├── creates VPC
     └── creates private subnets
              │
              ▼
          Outputs
              │
              ▼
        EKS Module

EKS doesn't recreate the VPC.

It consumes:

module.network.vpc_id
module.network.private_subnet_ids

This is the foundation for the remote-state concept you specifically want to learn later.

Q4 — EKS Cluster vs Node Group

You said:

EKS cluster = AWS managed cluster
node-group = still need to learn

Good. Let's learn that now.

EKS Cluster

The cluster is the Kubernetes platform/control plane.

EKS Cluster
     │
     └── Kubernetes API

It gives us the Kubernetes control plane and its integration with AWS.

Managed Node Group

A Managed Node Group is a collection of worker nodes that provide compute capacity for the EKS cluster.

Think of it like this:

              EKS Cluster
            AWS-managed
                  │
                  │
                  ▼
         Managed Node Group
                  │
          ┌───────┴───────┐
          ▼               ▼
       EC2 Node        EC2 Node
          │               │
       ┌──┴──┐         ┌──┴──┐
       │Pods │         │Pods │
       └─────┘         └─────┘

The node group isn't the application.

It provides the machines on which Kubernetes can schedule applications.

Why call it a "node group"?

Because we don't want to manually create:

EC2-1
EC2-2
EC2-3

and individually configure them as Kubernetes workers.

Instead we tell EKS:

"I want a managed group of worker nodes with this instance type, this scaling range, these subnets, and this IAM role."

For example, conceptually:

Desired = 2
Minimum = 2
Maximum = 4
Instance Type = t3.medium

AWS/EKS manages the node-group lifecycle.

So:

Managed Node Group
        │
        ├── EC2 Node 1
        ├── EC2 Node 2
        └── ...
The Important Distinction

Don't mix these three things:

EKS Cluster
    ↓
Kubernetes control plane
Node Group
    ↓
Collection of worker nodes
Pod
    ↓
Application workload

So if we deploy Nginx:

EKS Cluster
      │
      ▼
Node Group
      │
 ┌────┴────┐
 ▼         ▼
Node      Node
 │
 ▼
Nginx Pod
Now connect this with our Terraform modules

This is where your existing architecture becomes useful.

modules/
│
├── network/
│      └── VPC + Subnets
│
├── security-group/
│
├── iam-role/
│
├── compute/
│      └── EC2 / Launch Template / ASG
│
└── eks/                     ← NEW
       │
       ├── EKS Cluster
       │
       └── Managed Node Group

Notice something important:

The EKS node group uses EC2, but we are not going to put the node group inside modules/compute.

Why?

Because:

compute module
    → generic EC2 infrastructure

eks module
    → Kubernetes-specific infrastructure

The EKS module can internally cause EC2 nodes to exist through the managed node group, while keeping Kubernetes-specific concerns isolated.

One More Important Concept

Eventually we'll have two different types of scaling.

EC2/ASG
Launch Template
      ↓
ASG
      ↓
EC2

This is our generic compute architecture.

EKS
EKS
 ↓
Managed Node Group
 ↓
EC2
 ↓
Pods

Here Kubernetes is scheduling workloads onto the nodes.

Later we'll learn that there are actually two scaling dimensions:

Application Pods
       ↓
Horizontal Pod Autoscaler

Worker Nodes
       ↓
Node Group / Cluster Autoscaler

That's a very important concept for production Kubernetes.

Our next step

Now that the basic architecture is clear, we should not write the EKS Terraform yet.

Next we'll design the prerequisites:

1. Network
   ↓
2. Private Subnets
   ↓
3. IAM
   ↓
4. Security
   ↓
5. EKS Cluster
   ↓
6. Managed Node Group
   ↓
7. kubectl
   ↓
8. Deploy first Pod

And because your current network module was originally built around public infrastructure, our first actual modification should probably be the Network module, adding the private-subnet/Multi-AZ structure EKS needs.

===================================================================================================================

Current network module

Right now it creates:

modules/network/
│
├── main.tf
├── variables.tf
└── outputs.tf

and main.tf has:

VPC
 │
 ├── Public Subnet
 │
 ├── Internet Gateway
 │
 └── Public Route Table

Your root module then consumes:

module.network.vpc_id
module.network.subnet_id

and passes the subnet into the existing compute module.

That is good modular design and we should preserve it.

What we need to evolve

For EKS, I don't want to simply add one private subnet and call it done.

We should evolve the network toward:

                         VPC
                          │
             ┌────────────┴────────────┐
             │                         │
        Availability Zone 1       Availability Zone 2
             │                         │
       ┌─────┴─────┐             ┌─────┴─────┐
       │           │             │           │
     Public      Private       Public      Private
     Subnet      Subnet        Subnet      Subnet
       │           │             │           │
       │           └──────┬──────┘           │
       │                  │                  │
       │              NAT Gateway            │
       │                  │                  │
       └──────────── Internet ───────────────┘

But we should build this incrementally.

Important: don't modify anything yet

Before we change the module, I want to see two more pieces of your existing implementation:

1. Network outputs

Run:

cat modules/network/outputs.tf
2. Root variables

Run:

cat variables.tf

And also:

cat terraform.tfvars

I specifically want to see how you're currently defining:

vpc_cidr
subnet_cidr
availability_zone

because right now your module interface is single-value oriented:

variable "subnet_cidr"
variable "availability_zone"

For the EKS architecture, we'll probably evolve that interface.

Why this is an important Terraform lesson

Currently:

Root
 │
 │ vpc_cidr
 │ subnet_cidr
 │ availability_zone
 ▼
Network Module
 │
 └── creates resources

We eventually want something closer to:

Root
 │
 │ network inputs
 ▼
Network Module
 │
 ├── VPC
 ├── Public Subnets
 ├── Private Subnets
 ├── NAT
 └── Route Tables
       │
       ▼
     Outputs
       │
       ├── vpc_id
       ├── public_subnet_ids
       └── private_subnet_ids
                │
                ▼
             EKS Module

And then:

module "eks" {
  source = "./modules/eks"

  vpc_id     = module.network.vpc_id
  subnet_ids = module.network.private_subnet_ids
}

That is the module interaction I want you to learn, rather than just copying an EKS Terraform configuration.

One more thing

Your current compute module uses:

subnet_id = module.network.subnet_id

We should not break that immediately.

We'll make the network module evolve in a controlled way so that:

Existing EC2
     │
     ▼
Existing public subnet

continues working while we add:

New EKS
   │
   ▼
Private subnet(s)

This is also a realistic infrastructure-engineering lesson: extend an existing module without unnecessarily breaking its consumers.

So send me these three outputs:

cat modules/network/outputs.tf
cat variables.tf
cat terraform.tfvars

==========================================================================================

1. Current module interface

Today the root gives the network module:

vpc_cidr
subnet_cidr
availability_zone
common_tags

So the module effectively creates:

VPC
 │
 └── 10.0.1.0/24
      │
      └── us-east-1a

And it returns:

vpc_id
subnet_id
internet_gateway_id
route_table_id

This works perfectly for our current EC2 deployment.

2. What EKS needs

We now need to expand the interface.

I suggest we move toward:

Network inputs
│
├── vpc_cidr
│
├── public_subnet_cidrs
│
├── private_subnet_cidrs
│
└── availability_zones

For example:

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

That gives us:

                    VPC
               10.0.0.0/16
                    │
       ┌────────────┴────────────┐
       │                         │
      AZ-a                      AZ-b
       │                         │
 ┌─────┴─────┐             ┌─────┴─────┐
 │           │             │           │
Public      Private       Public      Private
10.0.1/24   10.0.11/24    10.0.2/24   10.0.12/24

This is much more useful for EKS.

3. But there is a Terraform state issue

We currently have:

aws_subnet.public

and our compute module is using:

module.network.subnet_id

So I don't want to immediately convert aws_subnet.public into a for_each resource.

If we do something like:

resource "aws_subnet" "public" {
  for_each = ...
}

Terraform will see:

aws_subnet.public

becoming:

aws_subnet.public["us-east-1a"]
aws_subnet.public["us-east-1b"]

That introduces a state migration/change problem.

This is actually a very useful Terraform concept, but we don't need to mix it into today's EKS learning.

4. So let's evolve safely

For now, keep:

aws_subnet.public

exactly as it is.

That means our existing:

EC2
 ↓
Public Subnet

continues working.

Then add new resources:

Existing
────────────────────

aws_subnet.public
us-east-1a
10.0.1.0/24


New
────────────────────

aws_subnet.public_2
us-east-1b
10.0.2.0/24

aws_subnet.private_1
us-east-1a
10.0.11.0/24

aws_subnet.private_2
us-east-1b
10.0.12.0/24

Eventually we'll output:

vpc_id

public_subnet_ids

private_subnet_ids

while retaining the existing:

subnet_id

for backward compatibility with our current compute module.

That's a real-world module evolution pattern.

5. Then NAT Gateway

After the subnets exist:

Private Subnet
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

So EKS nodes can remain private:

EKS Node
   │
   ▼
10.0.11.x
   │
   ▼
NAT
   │
   ▼
Internet

No public IP is required on the worker node.

6. Our final network module interface

Eventually, I want:

modules/network/
│
├── main.tf
├── variables.tf
└── outputs.tf
Inputs
vpc_cidr

public_subnet_cidrs

private_subnet_cidrs

availability_zones

common_tags
Outputs
vpc_id

subnet_id                    ← keep existing

public_subnet_ids

private_subnet_ids

internet_gateway_id

nat_gateway_ids

public_route_table_id

private_route_table_ids

Then our future EKS module can simply consume:

module.network.vpc_id

and:

module.network.private_subnet_ids
7. And this is the important architecture lesson

We're creating a dependency chain:

                NETWORK MODULE
                      │
        ┌─────────────┼─────────────┐
        │             │             │
      VPC        Public Subnets   Private Subnets
        │                           │
        │                           ▼
        │                       NAT Gateway
        │                           │
        └──────────────┬────────────┘
                       │
                       ▼
                  EKS MODULE
                       │
               ┌───────┴───────┐
               │               │
          EKS Cluster     Node Group
                               │
                               ▼
                              EC2
                               │
                               ▼
                              Pods

This is exactly the module-to-module architecture we wanted to learn.

8. One decision before coding

For our first EKS implementation, I recommend:

Region:       us-east-1
AZs:          us-east-1a
              us-east-1b

VPC:          10.0.0.0/16

Public:
              10.0.1.0/24
              10.0.2.0/24

Private:
              10.0.11.0/24
              10.0.12.0/24

And:

NAT Gateway:  1 initially

Why 1 NAT?

Not because it's the ideal production architecture. For production HA we'd normally discuss one NAT Gateway per AZ versus the cost trade-off.

For our learning platform, one NAT keeps the architecture and AWS bill simpler. Once EKS works, we'll explicitly discuss why production designs often use multiple NAT Gateways.

So the next actual coding step

Do not change main.tf yet.

First update the root variables and terraform.tfvars so our module has the new inputs.

Then we'll update:

modules/network/variables.tf

Then:

modules/network/main.tf

Then outputs.

That gives us a clean progression:

Variables
   ↓
Module Interface
   ↓
Resources
   ↓
Outputs
   ↓
Root Consumers
   ↓
terraform plan

This is exactly how I want you to learn Terraform module design—not just copy a finished module.

Step 1 — variables.tf

Your current:

variable "vpc_cidr" {
  description = "VPC CIDR"
  type        = string
}

variable "subnet_cidr" {
  description = "Subnet CIDR"
  type        = string
}

variable "availability_zone" {
  description = "Availability Zone"
  type        = string
}

We want to replace the single-subnet inputs with lists:

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
Why list(string)?

Previously:

subnet_cidr = "10.0.1.0/24"

One value.

Now:

public_subnet_cidrs = [
  "10.0.1.0/24",
  "10.0.2.0/24"
]

Multiple values.

Same for private subnets:

private_subnet_cidrs = [
  "10.0.11.0/24",
  "10.0.12.0/24"
]

And AZs:

availability_zones = [
  "us-east-1a",
  "us-east-1b"
]

This is our first step toward using Terraform expressions such as for_each/count in the network module.

Step 2 — terraform.tfvars

Change this:

vpc_cidr          = "10.0.0.0/16"
subnet_cidr       = "10.0.1.0/24"
availability_zone = "us-east-1a"

to:

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

Leave the rest of your terraform.tfvars unchanged:

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

key_name        = "terraform-lab-key"
public_key_path = "~/.ssh/id_ed25519.pub"

role_name = "terraform-lab-role"
Step 3 — Don't run apply

At this point, our root configuration and tfvars have changed, but the network module still expects the old variables:

Root
 │
 ├── public_subnet_cidrs      NEW
 ├── private_subnet_cidrs     NEW
 └── availability_zones       NEW
          │
          ▼
Network module
 │
 ├── subnet_cidr              OLD
 └── availability_zone        OLD

So we're deliberately in an incomplete intermediate state.

That's okay.

Next we'll modify:

modules/network/variables.tf

Then main.tf and outputs.tf.

After making these two changes, run only:
terraform fmt

Don't run plan yet.

Then show me:

cat variables.tf
cat terraform.tfvars

We'll verify the root interface before moving to the network module itself.

===================================================================================

Current flow
terraform.tfvars
      │
      ├── vpc_cidr
      ├── public_subnet_cidrs[]
      ├── private_subnet_cidrs[]
      └── availability_zones[]
               │
               ▼
          root variables

And the values are consistent:

AZ-a
 ├── Public  10.0.1.0/24
 └── Private 10.0.11.0/24

AZ-b
 ├── Public  10.0.2.0/24
 └── Private 10.0.12.0/24

No CIDR overlap, and everything is inside:

10.0.0.0/16
One important observation

The root module is now ahead of the child module.

Currently:

Root
 │
 ├── public_subnet_cidrs
 ├── private_subnet_cidrs
 └── availability_zones
          │
          ▼
Network module
 │
 ├── subnet_cidr        ← old
 └── availability_zone  ← old

So don't run terraform apply.

Next step: update the network module interface

Open:

nano modules/network/variables.tf

Replace the old:

variable "subnet_cidr" {
  ...
}

variable "availability_zone" {
  ...
}

with:

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets"
  type        = list(string)
}

variable "availability_zones" {
  description = "Availability Zones for the subnets"
  type        = list(string)
}

Keep these unchanged:

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
}

variable "common_tags" {
  description = "Common tags"
  type        = map(string)
}

So the child module will now understand the same interface as the root.

Don't modify main.tf yet.

After saving, run:

terraform fmt

Then:

cat modules/network/variables.tf

Send me that output.

Then we'll tackle the interesting part: converting those lists into actual AWS subnets using Terraform for_each. That's a useful Terraform concept because you'll see how one module dynamically creates multiple resources from structured input.

Perfect. This child module interface now matches the root inputs.

We have:

Root
 │
 ├── public_subnet_cidrs
 ├── private_subnet_cidrs
 └── availability_zones
          │
          ▼
Network Module
 │
 ├── public_subnet_cidrs
 ├── private_subnet_cidrs
 └── availability_zones

Now we need to change the root main.tf module call, because it still passes the old variables.

Currently you have:

module "network" {

  source = "./modules/network"

  vpc_cidr          = var.vpc_cidr
  subnet_cidr       = var.subnet_cidr
  availability_zone = var.availability_zone

  common_tags = local.common_tags

}

Replace it with:

module "network" {

  source = "./modules/network"

  vpc_cidr             = var.vpc_cidr
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  availability_zones   = var.availability_zones

  common_tags = local.common_tags

}
Notice the Terraform flow
terraform.tfvars
       │
       ▼
root variable
       │
       ▼
module "network"
       │
       ▼
child module variable

For example:

terraform.tfvars
    │
    │ public_subnet_cidrs
    ▼
var.public_subnet_cidrs
    │
    ▼
module.network.public_subnet_cidrs
    │
    ▼
modules/network/variables.tf

This is worth understanding because you'll use the same pattern when we connect:

Network → EKS
IAM     → EKS
Security → EKS
After changing main.tf

Run:

terraform fmt
terraform validate

Do not run apply yet.

validate may still complain because modules/network/main.tf is still expecting the old resources/variables.

That's expected.

Our next step will be the actual interesting part:

public_subnet_cidrs
        +
availability_zones
        ↓
      for_each
        ↓
Public Subnet AZ-a
Public Subnet AZ-b

and then we'll add the private subnets.

This is where you'll see how Terraform turns our structured module inputs into multiple AWS resources.

Exactly. This is the expected intermediate error.

Terraform is now telling us that we successfully changed the module interface, but modules/network/main.tf is still using the old interface:

Old:
var.subnet_cidr
var.availability_zone

New:
var.public_subnet_cidrs
var.private_subnet_cidrs
var.availability_zones

So we've reached the next step.

Now we modify modules/network/main.tf

Don't change the VPC or IGW yet. We'll replace the subnet section first.

Current subnet resource

You have:

resource "aws_subnet" "public" {

  vpc_id = aws_vpc.main.id

  cidr_block = var.subnet_cidr

  availability_zone = var.availability_zone

  map_public_ip_on_launch = true

  tags = merge(
    var.common_tags,
    {
      Name = "Terraform-Module-Public-Subnet"
    }
  )

}

We're going to introduce for_each so the module can create multiple public subnets.

Step 1 — Understand the mapping

We have:

public_subnet_cidrs = [
  "10.0.1.0/24",
  "10.0.2.0/24"
]

availability_zones = [
  "us-east-1a",
  "us-east-1b"
]

We want:

index 0
  CIDR → 10.0.1.0/24
  AZ   → us-east-1a

index 1
  CIDR → 10.0.2.0/24
  AZ   → us-east-1b

Terraform's for_each works best when we create a map containing both values.

We'll eventually use:

for_each = {
  for index, cidr in var.public_subnet_cidrs :
  index => {
    cidr = cidr
    az   = var.availability_zones[index]
  }
}

Conceptually:

{
  0 = {
    cidr = "10.0.1.0/24"
    az   = "us-east-1a"
  }

  1 = {
    cidr = "10.0.2.0/24"
    az   = "us-east-1b"
  }
}

Then each subnet gets its matching CIDR and AZ.

Step 2 — Replace the public subnet resource

Replace only the current aws_subnet "public" block with:

resource "aws_subnet" "public" {

  for_each = {
    for index, cidr in var.public_subnet_cidrs :
    index => {
      cidr = cidr
      az   = var.availability_zones[index]
    }
  }

  vpc_id = aws_vpc.main.id

  cidr_block = each.value.cidr

  availability_zone = each.value.az

  map_public_ip_on_launch = true

  tags = merge(
    var.common_tags,
    {
      Name = "Terraform-Module-Public-Subnet-${each.value.az}"
    }
  )

}
Important

We are deliberately using:

for_each

instead of count.

Why?

Because later we want to work with named infrastructure objects rather than simply numeric positions. This becomes particularly useful when our infrastructure gets larger.

But there is one problem

Our existing compute module currently expects:

module.network.subnet_id

Previously:

module.network.subnet_id
       ↓
aws_subnet.public.id

After for_each, there isn't one aws_subnet.public.id.

There are now:

aws_subnet.public[0]
aws_subnet.public[1]

So our existing output:

output "subnet_id" {
  value = aws_subnet.public.id
}

will also become invalid.

Don't fix that yet.

I want you to see this dependency chain:

Change resource structure
        ↓
Output changes
        ↓
Root consumer changes
        ↓
Compute module changes

This is exactly why module design matters.

Your task now

Make only this change to:

modules/network/main.tf

Then run:

terraform fmt
terraform validate

Don't change outputs.tf yet.

The validation error we get next will be useful because it will show us exactly which downstream references need to evolve.

Exactly. This is the expected next dependency error, and it demonstrates an important Terraform rule.

We changed:

resource "aws_subnet" "public" {
  for_each = ...
}

So Terraform no longer sees one resource:

aws_subnet.public

It now sees multiple instances:

aws_subnet.public[0]
aws_subnet.public[1]

Therefore this old output is no longer valid:

output "subnet_id" {
  value = aws_subnet.public.id
}

Terraform is correctly telling us:

aws_subnet.public has for_each, so you must specify which instance.

But let's design the output properly

We don't want:

output "subnet_id" {
  value = aws_subnet.public[0].id
}

That would throw away the benefit of creating multiple subnets.

Instead, let's expose all public subnet IDs.

Change the old subnet_id output to:

output "public_subnet_ids" {
  description = "IDs of public subnets"

  value = [
    for subnet in aws_subnet.public : subnet.id
  ]
}

This will produce:

public_subnet_ids = [
  "subnet-xxxxx",
  "subnet-yyyyy"
]
But we have an existing compute dependency

Our root currently has:

subnet_id = module.network.subnet_id

And that's used by:

Compute module
      ↓
EC2
      ↓
Public subnet

We don't want to break that yet.

So I recommend keeping a backward-compatible output for now:

output "subnet_id" {
  description = "Primary public subnet ID for existing EC2 workloads"

  value = aws_subnet.public[0].id
}

And add:

output "public_subnet_ids" {
  description = "IDs of all public subnets"

  value = [
    for subnet in aws_subnet.public : subnet.id
  ]
}

So we'll have:

Network Module Outputs
│
├── subnet_id
│     └── first public subnet
│         ↓
│       Existing EC2
│
└── public_subnet_ids
      ├── public AZ-a
      └── public AZ-b

This is a very useful lesson:

Don't break existing module consumers unnecessarily when evolving a module.

One small improvement

Since our for_each keys are currently:

0
1

the output order follows those keys.

Later, we can make the module even cleaner by using AZ names as the keys:

us-east-1a
us-east-1b

Then we'd have:

aws_subnet.public["us-east-1a"]
aws_subnet.public["us-east-1b"]

That is actually a more production-friendly design, but let's not introduce another change right now. We are learning one concept at a time.

Do this now

Open:

nano modules/network/outputs.tf

Replace the existing subnet_id block with:

output "subnet_id" {
  description = "Primary public subnet ID for existing EC2 workloads"

  value = aws_subnet.public[0].id
}

output "public_subnet_ids" {
  description = "IDs of all public subnets"

  value = [
    for subnet in aws_subnet.public : subnet.id
  ]
}

Keep these outputs for now:

output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "internet_gateway_id" {
  description = "Internet Gateway ID"
  value       = aws_internet_gateway.igw.id
}

output "route_table_id" {
  description = "Public Route Table ID"
  value       = aws_route_table.public.id
}

Then:

terraform fmt
terraform validate
Don't add private subnet outputs yet.

We haven't created the private subnets. We'll do that next.

Exactly. This is another expected consequence of introducing for_each.

We fixed the subnet resource and the output, but there is still one old reference in main.tf.

Your current route-table association is effectively:

resource "aws_route_table_association" "public" {

  subnet_id = aws_subnet.public.id

  route_table_id = aws_route_table.public.id

}

Terraform is saying:

aws_subnet.public now has multiple instances, so .id is no longer valid.

Fix the route-table association

Because we want every public subnet associated with the same public route table, this is a perfect use of for_each.

Replace the existing association with:

resource "aws_route_table_association" "public" {

  for_each = aws_subnet.public

  subnet_id = each.value.id

  route_table_id = aws_route_table.public.id

}

Now Terraform understands:

aws_subnet.public
       │
       ├── subnet AZ-a ──┐
       │                 │
       └── subnet AZ-b ──┤
                         ▼
                  Public Route Table

So both public subnets get:

0.0.0.0/0
   │
   ▼
Internet Gateway
This is an important for_each pattern

Notice what we did:

for_each = aws_subnet.public

Terraform is using the instances created by another resource as the collection.

Then:

each.value.id

means:

"Give me the subnet ID for the current subnet instance."

So conceptually:

Subnet A
   │
   └── each.value.id
          ↓
      Association A

Subnet B
   │
   └── each.value.id
          ↓
      Association B

This is much better than manually writing:

aws_route_table_association "public_1"
aws_route_table_association "public_2"
Make only this change

In:

modules/network/main.tf

change:

resource "aws_route_table_association" "public" {

  subnet_id = aws_subnet.public.id

  route_table_id = aws_route_table.public.id

}

to:

resource "aws_route_table_association" "public" {

  for_each = aws_subnet.public

  subnet_id = each.value.id

  route_table_id = aws_route_table.public.id

}

Then run:

terraform fmt
terraform validate
Don't apply yet.

We're still completing the public-subnet conversion.

Our dependency chain currently looks like:

public_subnet_cidrs
        │
        ▼
aws_subnet.public
   for_each
        │
        ├──────────────┐
        ▼              ▼
Outputs         Route Table Association
                       │
                       ▼
                Public Route Table
                       │
                       ▼
                  Internet Gateway

Once terraform validate passes, we'll move to the private subnets, where the architecture becomes interesting:

Private Subnet
      │
      ▼
Private Route Table
      │
      ▼
NAT Gateway
      │
      ▼
Internet Gateway

And those private subnet IDs will eventually become the input to our EKS module.

Yes — this error is not related to the network changes. We have uncovered an existing problem in our iam-role module.

Terraform is now validating the whole configuration and found that modules/iam-role/outputs.tf contains references to resources that do not exist inside that module.

What Terraform is telling us

Your iam-role module is apparently trying to output:

aws_instance.iam_lab
aws_iam_role.ec2_role
aws_iam_instance_profile.ec2_profile
aws_vpc.main

But a Terraform module has its own resource namespace.

For example:

modules/iam-role/
│
├── main.tf
│      └── aws_iam_role.ec2_role
│
└── outputs.tf
       └── can reference aws_iam_role.ec2_role

It cannot reference:

aws_instance.iam_lab
aws_vpc.main

unless those resources are actually declared inside modules/iam-role.

This is actually a good architecture lesson

Our standalone IAM lab had something like:

IAM Lab
├── EC2
├── VPC
├── IAM Role
└── Instance Profile

But our modular project is different.

We have separated responsibilities:

network/
   └── VPC

iam-role/
   └── IAM Role
   └── Instance Profile

compute/
   └── EC2

Therefore:

iam-role/outputs.tf

should only output IAM-related resources.

Let's fix this cleanly

Before changing anything, run:

cat modules/iam-role/outputs.tf

and:

cat modules/iam-role/main.tf

Send me both.

I expect we'll find something like:

output "instance_id" {
  value = aws_instance.iam_lab.id
}

output "public_ip" {
  value = aws_instance.iam_lab.public_ip
}

output "iam_role" {
  value = aws_iam_role.ec2_role.name
}

output "instance_profile" {
  value = aws_iam_instance_profile.ec2_profile.name
}

output "vpc_id" {
  value = aws_vpc.main.id
}

The first, second and fifth outputs definitely don't belong in this module.

Also, your root main.tf currently expects:

iam_instance_profile = module.iam_role.instance_profile_name

So we need to make sure the IAM module exposes that exact output name.

The intended architecture is:

                 ROOT
                  │
        ┌─────────┼──────────┐
        │         │          │
     network   iam-role    compute
        │         │          │
        │         ├── Role   │
        │         └── Profile│
        │                    │
        └────────────────────┘

And:

iam-role
   │
   └── instance_profile_name
             │
             ▼
          compute
             │
             ▼
            EC2

Don't change anything yet. Show me those two IAM module files, and we'll clean up this module without disturbing the IAM work we've already completed.

Perfect. Now we can see the problem clearly. This is an existing module cleanup, not an EKS/network problem.

Your iam-role/main.tf is correctly structured around:

iam-role module
│
├── IAM Role
├── SSM Policy Attachment
└── Instance Profile

But outputs.tf was copied from the earlier standalone IAM lab and still references EC2/VPC resources that belong to other modules.

1. What is valid in this module?

From your main.tf, these resources actually exist:

aws_iam_role.this
aws_iam_role_policy_attachment.ssm
aws_iam_instance_profile.this

Therefore the outputs should reference those resources.

Your current invalid outputs are:

aws_instance.iam_lab
aws_vpc.main
aws_iam_role.ec2_role
aws_iam_instance_profile.ec2_profile

None of those resources exist in this module.

2. Replace modules/iam-role/outputs.tf

I recommend making it:

output "iam_role_name" {
  description = "Name of the IAM role"
  value       = aws_iam_role.this.name
}

output "instance_profile_name" {
  description = "Name of the EC2 instance profile"
  value       = aws_iam_instance_profile.this.name
}

That's it.

Notice that this matches what our root main.tf already expects:

iam_instance_profile = module.iam_role.instance_profile_name

So the flow becomes:

terraform.tfvars
      │
      ▼
role_name
      │
      ▼
iam-role module
      │
      ├── IAM Role
      │
      └── Instance Profile
                │
                ▼
        instance_profile_name
                │
                ▼
          compute module
                │
                ▼
               EC2

This is exactly how our modules should communicate.

3. One thing I noticed

Your main.tf output ends here:

resource "aws_iam_instance_profile" "this" {

  name = var.role_name

  role = aws_iam_role.this.name

Make sure there is a closing:

}

at the end of the file.

So the complete block should be:

resource "aws_iam_instance_profile" "this" {

  name = var.role_name

  role = aws_iam_role.this.name
}

If your actual file already has the }, you're fine—the terminal output you pasted simply may have cut off the final line.

4. Why are we doing this now?

This is actually an excellent lesson in module boundaries.

We now have:

network module
    │
    └── owns VPC/subnets/routes

iam-role module
    │
    └── owns IAM role/profile

security-group module
    │
    └── owns security groups

compute module
    │
    └── owns EC2

No module should pretend to own resources belonging to another module.

Instead they communicate through:

inputs  →  module  →  outputs

Exactly what you wanted to learn.

Do this now

Replace modules/iam-role/outputs.tf with:

output "iam_role_name" {
  description = "Name of the IAM role"
  value       = aws_iam_role.this.name
}

output "instance_profile_name" {
  description = "Name of the EC2 instance profile"
  value       = aws_iam_instance_profile.this.name
}

Then:

terraform fmt
terraform validate

Don't apply.

If validation passes, we'll return to our network work and continue with the private subnets. The IAM cleanup is simply removing the stale outputs that were accidentally carried over from our standalone IAM lab.

==================================================================================================================

Yes — the error confirms that the old outputs.tf content is still present. Terraform is reading these three old outputs:

instance_id
public_ip
vpc_id

So the replacement was not fully applied/saved.

Let's verify first

Run:

cat modules/iam-role/outputs.tf

You should not see:

output "instance_id" { ... }

output "public_ip" { ... }

output "vpc_id" { ... }

The file should contain only:

output "iam_role_name" {
  description = "Name of the IAM role"
  value       = aws_iam_role.this.name
}

output "instance_profile_name" {
  description = "Name of the EC2 instance profile"
  value       = aws_iam_instance_profile.this.name
}
Easiest way to fix it

You can overwrite the file directly:

cat > modules/iam-role/outputs.tf <<'EOF'
output "iam_role_name" {
  description = "Name of the IAM role"
  value       = aws_iam_role.this.name
}

output "instance_profile_name" {
  description = "Name of the EC2 instance profile"
  value       = aws_iam_instance_profile.this.name
}
EOF

Then verify:

cat modules/iam-role/outputs.tf

and:

terraform fmt
terraform validate
Why this happened

Our old standalone IAM lab had:

EC2
VPC
IAM Role
Instance Profile

but our module architecture separates them:

network/
    VPC

iam-role/
    IAM Role
    Instance Profile

compute/
    EC2

So iam-role/outputs.tf must only expose things actually created by iam-role.

Once terraform validate passes, we go straight back to the network work.

====================================================================================

Yes — now we can see exactly why it still errors. The old outputs were not deleted. Your file currently contains both the new outputs and the old invalid outputs:

output "instance_id" {
  value = aws_instance.iam_lab.id
}

output "public_ip" {
  value = aws_instance.iam_lab.public_ip
}

and at the bottom:

output "vpc_id" {
  value = aws_vpc.main.id

Those three must be removed completely.

Do this exactly

Run:

cat > modules/iam-role/outputs.tf <<'EOF'
output "iam_role_name" {
  description = "Name of the IAM role"
  value       = aws_iam_role.this.name
}

output "instance_profile_name" {
  description = "Name of the EC2 instance profile"
  value       = aws_iam_instance_profile.this.name
}
EOF

Now verify:

cat modules/iam-role/outputs.tf

It must show only:

output "iam_role_name" {
  description = "Name of the IAM role"
  value       = aws_iam_role.this.name
}

output "instance_profile_name" {
  description = "Name of the EC2 instance profile"
  value       = aws_iam_instance_profile.this.name
}

Then:

terraform fmt
terraform validate
Important

Don't add instance_id, public_ip, or vpc_id back.

Our module ownership is now:

network
 └── VPC / Subnets / Routes

iam-role
 └── IAM Role / Instance Profile

compute
 └── EC2

So iam-role should expose only:

IAM Role Name
Instance Profile Name

Once validation passes, we'll return immediately to the network module and continue the EKS preparation with private subnets.

======================================================== start EKS Structure ======================================================

Step 1 — Add Private Subnets

Open:

nano modules/network/main.tf

Place this after the public subnet resource:

resource "aws_subnet" "private" {

  for_each = {
    for index, cidr in var.private_subnet_cidrs :
    index => {
      cidr = cidr
      az   = var.availability_zones[index]
    }
  }

  vpc_id = aws_vpc.main.id

  cidr_block = each.value.cidr

  availability_zone = each.value.az

  map_public_ip_on_launch = false

  tags = merge(
    var.common_tags,
    {
      Name = "Terraform-Module-Private-Subnet-${each.value.az}"
    }
  )

}
Understand what this creates

Our input:

private_subnet_cidrs = [
  "10.0.11.0/24",
  "10.0.12.0/24"
]

availability_zones = [
  "us-east-1a",
  "us-east-1b"
]

becomes:

aws_subnet.private[0]
    CIDR = 10.0.11.0/24
    AZ   = us-east-1a

aws_subnet.private[1]
    CIDR = 10.0.12.0/24
    AZ   = us-east-1b

And importantly:

map_public_ip_on_launch = false

So:

Public subnet
    ↓
Public IP possible

Private subnet
    ↓
No public IP
Step 2 — Validate

Run:

terraform fmt
terraform validate

Then don't apply yet.

If validation succeeds, we'll add the private route tables and associations.

The architecture will then become:

                    VPC
                     │
        ┌────────────┴────────────┐
        │                         │
     PUBLIC                    PRIVATE
        │                         │
   Public RT                  Private RT
        │                         │
      IGW                    NAT Gateway
        │                         │
    Internet                 Internet

That's the foundation we need before we connect the EKS module.

=======================================================

Perfect. ✅

terraform fmt       → completed
terraform validate  → Success!

So the private subnet resource is syntactically and structurally valid.

Our network module now has:

VPC 10.0.0.0/16
│
├── Public
│   ├── 10.0.1.0/24 → us-east-1a
│   └── 10.0.2.0/24 → us-east-1b
│
└── Private
    ├── 10.0.11.0/24 → us-east-1a
    └── 10.0.12.0/24 → us-east-1b
Next: Private Route Tables

We need to keep private traffic separate from the public route table.

Add this to modules/network/main.tf:

resource "aws_route_table" "private" {

  for_each = {
    for index, az in var.availability_zones :
    index => az
  }

  vpc_id = aws_vpc.main.id

  tags = merge(
    var.common_tags,
    {
      Name = "Terraform-Module-Private-RT-${each.value}"
    }
  )

}

Then associate each private subnet with its corresponding private route table:

resource "aws_route_table_association" "private" {

  for_each = aws_subnet.private

  subnet_id = each.value.id

  route_table_id = aws_route_table.private[each.key].id

}
The relationship we're building
Private Subnet[0]
      │
      ▼
Private RT[0]
      │
      └── us-east-1a

Private Subnet[1]
      │
      ▼
Private RT[1]
      │
      └── us-east-1b

For now, these route tables have no default route. That's intentional.

Next we'll add the NAT Gateway and then the private default routes:

Private RT
   │
   └── 0.0.0.0/0
          ↓
      NAT Gateway
          ↓
       IGW
          ↓
      Internet

After adding the two resources, run:

terraform fmt
terraform validate

Still don't apply yet. We want to finish the network topology first and then review the complete terraform plan before creating anything.

=============================================================

Perfect. ✅ Validation passes again.

We now have the complete subnet + route-table structure:

VPC
│
├── Public
│   ├── Subnet AZ-a ──→ Public RT
│   └── Subnet AZ-b ──→ Public RT
│
└── Private
    ├── Subnet AZ-a ──→ Private RT
    └── Subnet AZ-b ──→ Private RT

The important part is that the private route tables currently don't have an Internet route. That's correct—we haven't added NAT yet.

Next: NAT Gateway

We'll add:

Elastic IP
NAT Gateway in a public subnet
Private route:
Private Subnet
      ↓
Private Route Table
      ↓
0.0.0.0/0
      ↓
NAT Gateway
      ↓
Internet Gateway
      ↓
Internet

For our learning environment, we'll use one NAT Gateway to control cost.

Before adding it, I want you to understand one critical distinction:

Internet Gateway
→ allows resources with public connectivity to communicate with Internet

NAT Gateway
→ allows private resources to initiate outbound Internet connections
  without giving those resources public IPs

That's particularly important for EKS nodes.

Next coding step

We'll add the NAT resources to:

modules/network/main.tf

and then add the private default routes.

Don't apply anything yet. We'll finish the network module, inspect the complete plan, and only then decide whether to create the infrastructure.

==============================================

Yes. Let's add the NAT layer now.

1. Add an Elastic IP

In modules/network/main.tf, add:

resource "aws_eip" "nat" {

  domain = "vpc"

  tags = merge(
    var.common_tags,
    {
      Name = "Terraform-Module-NAT-EIP"
    }
  )

}

This gives the NAT Gateway a stable public IP.

2. Add the NAT Gateway

Put this after the EIP:

resource "aws_nat_gateway" "main" {

  allocation_id = aws_eip.nat.id

  subnet_id = aws_subnet.public[0].id

  depends_on = [
    aws_internet_gateway.igw
  ]

  tags = merge(
    var.common_tags,
    {
      Name = "Terraform-Module-NAT-Gateway"
    }
  )

}
Notice this:
subnet_id = aws_subnet.public[0].id

We're deliberately putting the NAT Gateway in public subnet 0:

Public AZ-a
10.0.1.0/24
     │
     ▼
NAT Gateway
     │
     ▼
Internet Gateway

For this learning environment, one NAT Gateway is enough.

3. Add the private default route

Now we need to tell each private route table:

For Internet-bound traffic, send it through the NAT Gateway.

Add:

resource "aws_route" "private_nat" {

  for_each = aws_route_table.private

  route_table_id = each.value.id

  destination_cidr_block = "0.0.0.0/0"

  nat_gateway_id = aws_nat_gateway.main.id

}

Now the complete path becomes:

EKS Node
10.0.11.x
    │
    ▼
Private Route Table
    │
    │ 0.0.0.0/0
    ▼
NAT Gateway
    │
    ▼
Public Subnet
10.0.1.x
    │
    ▼
Internet Gateway
    │
    ▼
Internet

And importantly:

EKS Node
   │
   └── NO public IP

That's exactly the architecture we want for private worker nodes.

4. Validate

Run:

terraform fmt
terraform validate

If successful, don't apply yet.

Then run:

terraform plan

We're now at the point where the plan becomes very useful. We should review what Terraform intends to create before touching AWS.

Send me the final terraform plan summary, especially:

Plan: X to add, X to change, X to destroy.

and we'll inspect it together before applying.

=================================================================

Yes — that aws_route block is correct. It completes the private subnet → NAT Gateway routing.

resource "aws_route" "private_nat" {

  for_each = aws_route_table.private

  route_table_id = each.value.id

  destination_cidr_block = "0.0.0.0/0"

  nat_gateway_id = aws_nat_gateway.main.id

}
What Terraform will create

Because:

for_each = aws_route_table.private

we have two private route tables:

aws_route_table.private[0]
aws_route_table.private[1]

Therefore Terraform creates:

aws_route.private_nat[0]
aws_route.private_nat[1]

Both point to the same NAT Gateway:

                    NAT Gateway
                        │
             ┌──────────┴──────────┐
             │                     │
      Private RT [0]         Private RT [1]
             │                     │
      Private Subnet [0]     Private Subnet [1]
       10.0.11.0/24           10.0.12.0/24
       us-east-1a              us-east-1b

So both private subnets can make outbound connections through the NAT Gateway.

Now run
terraform fmt
terraform validate

If you get:

Success! The configuration is valid.

then don't apply yet.

Next run:

terraform plan

and show me the plan summary plus any errors/warnings.

We want to verify the complete network before creating it:

VPC
├── 2 Public Subnets
├── 2 Private Subnets
├── IGW
├── Public Route Table
├── Private Route Tables
├── EIP
└── NAT Gateway

Then we'll fix the remaining module outputs/root references before apply.

=========================================================================

What the plan is telling us

We should expect roughly this architecture:

VPC
│
├── Public Subnet A ─────┐
├── Public Subnet B ─────┤
│                        │
│                   Public RT
│                        │
│                       IGW
│
├── Private Subnet A ─── Private RT A ──┐
├── Private Subnet B ─── Private RT B ──┤
│                                       │
│                                  NAT Gateway
│                                       │
└───────────────────────────────────────┘

And our existing modules are also being created:

IAM Role
Instance Profile
Security Group
3 × EC2
Key Pair

So 25 resources is plausible for the current complete configuration.

However, I don't want to apply yet.

There is one thing we still need to finish before applying.

We need private subnet outputs

Our network module currently exposes:

vpc_id
subnet_id
public_subnet_ids
internet_gateway_id
route_table_id

But EKS will need:

private_subnet_ids

Eventually:

module "eks" {

  source = "./modules/eks"

  vpc_id     = module.network.vpc_id
  subnet_ids = module.network.private_subnet_ids

}

That is the module-to-module dependency we specifically want to learn.

Add this to modules/network/outputs.tf
output "private_subnet_ids" {
  description = "IDs of all private subnets"

  value = [
    for subnet in aws_subnet.private : subnet.id
  ]
}

And I also recommend exposing the NAT Gateway:

output "nat_gateway_id" {
  description = "ID of the NAT Gateway"

  value = aws_nat_gateway.main.id
}

And the private route tables:

output "private_route_table_ids" {
  description = "IDs of private route tables"

  value = [
    for route_table in aws_route_table.private : route_table.id
  ]
}

Then:

terraform fmt
terraform validate
One more thing before apply

Your plan shows these root outputs:

instance_id
private_ip
public_ip
vpc_id
subnet_id
route_table_id
internet_gateway_id

Those are fine—they're outputs from our root project, not the IAM module problem we just fixed.

But I want us to make one final review of the plan before spending money on NAT Gateway.

Run:

terraform plan -no-color | grep -E '^  # aws_'

That will give us the resource list without all the noise.

Send me that output.

Then we'll verify:

VPC
2 public subnets
2 private subnets
IGW
public RT + associations
private RTs + associations
EIP
NAT Gateway
private NAT routes
IAM
Security Group
EC2

If that checks out, then we can apply the network foundation.

And after that, we'll build the separate modules/eks module and consume:

module.network.vpc_id
module.network.private_subnet_ids

That's the point where our Terraform architecture starts looking like a real modern cloud platform rather than a collection of independent labs.

Yes — validation is clean. ✅

The reason your second command returned nothing is just the grep pattern. The plan resource lines aren't matching:

grep -E '^  # aws_'

So this does not mean the plan has no resources. Your previous plan already confirmed:

Plan: 25 to add, 0 to change, 0 to destroy.
Let's get the resource list correctly

Run:

terraform plan -no-color | grep -E '^  #|^#'

You should see lines similar to:

  # aws_vpc.main will be created
  # aws_subnet.public[0] will be created
  # aws_subnet.public[1] will be created
  # aws_subnet.private[0] will be created
  # aws_subnet.private[1] will be created
  ...

If you want the cleanest review, run:

terraform plan -no-color | grep -E 'will be created|will be changed|will be destroyed|Plan:'

Send me that output.

Then we'll do the final sanity check before apply.

One important point

We have not applied the new network yet, so this is still safe:

Code
 ↓
terraform validate    ✅
 ↓
terraform plan        ✅ 25 add / 0 change / 0 destroy
 ↓
FINAL REVIEW           ← we are here
 ↓
terraform apply

After that, we'll create the EKS module separately and feed it:

module.network.vpc_id
module.network.private_subnet_ids

which is exactly the module composition pattern you wanted to learn.

Excellent. This is the clean plan we wanted. ✅

Your final plan confirms:

Plan: 25 to add
       0 to change
       0 to destroy

And the resource list is consistent with our intended architecture.

Network
module.network
│
├── VPC
│
├── Public
│   ├── subnet[0]
│   ├── subnet[1]
│   ├── public route table
│   └── associations[0..1]
│
├── Private
│   ├── subnet[0]
│   ├── subnet[1]
│   ├── private route tables[0..1]
│   ├── associations[0..1]
│   └── NAT routes[0..1]
│
├── Internet Gateway
├── EIP
└── NAT Gateway
Other modules
module.iam_role
├── IAM Role
├── SSM policy attachment
└── Instance Profile

module.security_group
└── Security Group

module.key_pair
└── Key Pair

module.compute
├── web EC2
├── app EC2
└── db EC2

That gives us a very important Terraform architecture lesson:

                    ROOT
                      │
       ┌──────────────┼──────────────┐
       ▼              ▼              ▼
    NETWORK         IAM          SECURITY
       │
       │ outputs
       ▼
    COMPUTE

And the network module is now much closer to what EKS needs.

One thing before apply

I want to correct one point from my previous step: we don't need another plan review. You've already shown the relevant resource list and the 25/0/0 summary.

So if you're ready to create this lab infrastructure, run:

terraform apply

Terraform will show the plan again and ask:

Do you want to perform these actions?
Only 'yes' will be accepted to approve.

Enter:

yes
Important cost note

This creates a NAT Gateway, which is a billable AWS resource. Since we're using it for learning, after we're finished with the EKS work we'll make sure we understand what should be destroyed/retained rather than accidentally leaving it running.

==========================================================================

Excellent. ✅ The network foundation is now actually deployed in AWS.

Apply complete!
25 added
0 changed
0 destroyed

The outputs also confirm our existing EC2 workloads are running in the new VPC:

VPC:              vpc-0d8c4099ca854e3c4
IGW:              igw-06e16120c3ea3ab62

And we have three EC2 instances:

app → 10.0.1.223
db  → 10.0.1.228
web → 10.0.1.142

with public IPs as expected because they're currently using the public subnet.

One thing we should verify before EKS

Our Terraform outputs haven't yet been expanded to show:

private_subnet_ids
public_subnet_ids
nat_gateway_id
private_route_table_ids

The resources exist, but exposing them through module outputs is what allows another module to consume them cleanly.

So let's finish that interface now.

Update modules/network/outputs.tf

Add:

output "private_subnet_ids" {
  description = "IDs of all private subnets"

  value = [
    for subnet in aws_subnet.private : subnet.id
  ]
}

output "public_subnet_ids" {
  description = "IDs of all public subnets"

  value = [
    for subnet in aws_subnet.public : subnet.id
  ]
}

output "nat_gateway_id" {
  description = "ID of the NAT Gateway"

  value = aws_nat_gateway.main.id
}

output "private_route_table_ids" {
  description = "IDs of private route tables"

  value = [
    for route_table in aws_route_table.private : route_table.id
  ]
}

Then:

terraform fmt
terraform validate
terraform output

We don't need another apply for these because outputs don't create AWS resources; after validation, terraform output should read the values from state.

Then we'll have the clean module interface:

NETWORK MODULE
│
├── vpc_id
├── public_subnet_ids
├── private_subnet_ids   ← EKS will consume this
├── internet_gateway_id
├── nat_gateway_id
├── route_table_id
└── private_route_table_ids
Then the next phase is finally EKS

We'll create:

modules/
├── network/        ✅
├── security-group/ ✅
├── iam-role/       ✅
├── key-pair/       ✅
├── compute/        ✅
└── eks/            ⏭️

And the key connection will be:

module "eks" {
  source = "./modules/eks"

  vpc_id     = module.network.vpc_id
  subnet_ids = module.network.private_subnet_ids
}

That is the module-to-module state/output flow you've been wanting to learn.

Yes — the network module outputs file is correct now. ✅

But there's one important Terraform behavior visible in your screenshot:

Why terraform output doesn't show the new outputs yet

You added:

private_subnet_ids
public_subnet_ids
nat_gateway_id
private_route_table_ids

after the previous terraform apply.

Terraform outputs are stored in the state. Merely adding an output block to configuration doesn't immediately put its value into the state.

That's why:

terraform output

still shows only the older outputs.

Do this now

First:

terraform plan

You should see something approximately like:

Plan: 0 to add, 0 to change, 0 to destroy

Changes to Outputs:
  + nat_gateway_id = ...
  + private_route_table_ids = ...
  + private_subnet_ids = ...
  + public_subnet_ids = ...

This is not going to recreate the infrastructure.

Then:

terraform apply

Terraform should effectively say:

Apply complete! Resources: 0 added, 0 changed, 0 destroyed.

with the new outputs.

Then:

terraform output

You should get something along the lines of:

private_subnet_ids = [
  "subnet-...",
  "subnet-..."
]

public_subnet_ids = [
  "subnet-...",
  "subnet-..."
]

nat_gateway_id = "nat-..."

private_route_table_ids = [
  "rtb-...",
  "rtb-..."
]
Then our module interface is complete

We'll have:

NETWORK MODULE
│
├── vpc_id
│
├── public_subnet_ids
│
├── private_subnet_ids       ← ⭐ EKS needs this
│
├── internet_gateway_id
│
├── nat_gateway_id
│
├── route_table_id
│
└── private_route_table_ids

And this is exactly the point we wanted to reach.

Next module

We'll create:

modules/
├── compute/
├── iam-role/
├── key-pair/
├── network/
├── security-group/
└── eks/                 ← NEW
    ├── main.tf
    ├── variables.tf
    └── outputs.tf

Then the root will connect them:

module "eks" {
  source = "./modules/eks"

  vpc_id     = module.network.vpc_id
  subnet_ids = module.network.private_subnet_ids
}

So Network creates the infrastructure, Network outputs the IDs, and EKS consumes those outputs.

That's the module composition pattern we wanted to learn.

For now, run the plan → apply → output sequence above and show me the new terraform output. Then we'll start the eks module.

======================================================================================

Good question. We don't need outputs just to make Terraform work. We need them to make modules communicate with each other cleanly.

Think of an output as a module's public interface.

1. Inside the network module

The network module creates:

modules/network
│
├── VPC
├── Public subnets
├── Private subnets
├── NAT Gateway
└── Route tables

The actual IDs are internal to that module:

aws_vpc.main.id
aws_subnet.private[0].id
aws_subnet.private[1].id

Another module should not reach inside and reference those resources directly.

So we expose selected values:

output "vpc_id" {
  value = aws_vpc.main.id
}

output "private_subnet_ids" {
  value = [
    for subnet in aws_subnet.private : subnet.id
  ]
}

That creates the interface:

NETWORK MODULE
      │
      │ outputs
      ▼
┌─────────────────────────┐
│ vpc_id                  │
│ private_subnet_ids      │
│ public_subnet_ids       │
│ nat_gateway_id          │
└─────────────────────────┘
2. EKS consumes those outputs

This is the important part.

Our future root configuration will say:

module "eks" {

  source = "./modules/eks"

  vpc_id = module.network.vpc_id

  subnet_ids = module.network.private_subnet_ids

}

Notice:

module.network.vpc_id

and:

module.network.private_subnet_ids

Those are outputs of the network module.

So the dependency becomes:

                 ROOT
                  │
        ┌─────────┴─────────┐
        ▼                   ▼
   NETWORK MODULE       EKS MODULE
        │                   ▲
        │                   │
        └── outputs ────────┘

More specifically:

network
   │
   ├── creates VPC
   ├── creates private subnets
   │
   └── outputs
         │
         ├── vpc_id
         └── private_subnet_ids
                  │
                  ▼
                EKS

This is why outputs matter.

3. Why terraform output is different

This is where the confusion is.

There are two different concepts:

A. Module output
output "private_subnet_ids" {
  value = [...]
}

This means:

"Make this value available to the parent module."

B. CLI command
terraform output

This means:

"Show me the root module's output values from Terraform state."

They're related, but they're not the same thing.

You don't need to run:

terraform output

for EKS to consume:

module.network.private_subnet_ids

Terraform handles that dependency internally.

4. Your screenshot is actually fine

You got:

No changes. Your infrastructure matches the configuration.

That's good.

We're not changing AWS infrastructure just because we added outputs.

The infrastructure is already:

25 resources

and remains unchanged.

The outputs are essentially metadata/interface information, not new AWS infrastructure.

5. Why I wanted you to add them now

Because we're about to build:

modules/eks/

and I want the EKS module to consume the network module properly.

Instead of doing something ugly like:

# Don't do this
subnet_id = "subnet-0bfcc2f5c8812b90c"

we want:

subnet_ids = module.network.private_subnet_ids

That gives us:

Hardcoded architecture ❌

EKS
 │
 └── subnet-0abc123...


Module-driven architecture ✅

EKS
 │
 └── module.network.private_subnet_ids

And if the network changes tomorrow, Terraform follows the dependency automatically.

The key rule I want you to remember

Resources are created inside a module. Outputs expose selected values from that module. Inputs consume values into another module.

So:

             MODULE A
        ┌────────────────┐
        │ creates        │
        │ resources      │
        └───────┬────────┘
                │
             outputs
                │
                ▼
             MODULE B
        ┌────────────────┐
        │ receives       │
        │ inputs         │
        └────────────────┘

For our project:

Network
   │
   │ vpc_id
   │ private_subnet_ids
   ▼
EKS

That is the exact pattern we're going to use next.

So don't worry about whether terraform output visibly shows them right now. The important thing is that the network module defines those outputs, because our EKS module will consume them.

Ah — now I see the issue. You're absolutely right.

The outputs we added are child-module outputs:

modules/network/outputs.tf

They are available to the root module, but they are not automatically exposed by the root module's terraform output command.

That's why you don't see them.

Think of it as two layers
modules/network/outputs.tf
        │
        │ exposes to ROOT
        ▼
root outputs.tf
        │
        │ exposes to CLI
        ▼
terraform output

So we need to re-export the network outputs from the root.

1. Open root outputs.tf

Run:

cat outputs.tf

You probably already have things like:

output "vpc_id" {
  value = module.network.vpc_id
}

We need to add the new ones.

Add:

output "public_subnet_ids" {
  description = "IDs of public subnets"
  value       = module.network.public_subnet_ids
}

output "private_subnet_ids" {
  description = "IDs of private subnets"
  value       = module.network.private_subnet_ids
}

output "nat_gateway_id" {
  description = "NAT Gateway ID"
  value       = module.network.nat_gateway_id
}

output "private_route_table_ids" {
  description = "IDs of private route tables"
  value       = module.network.private_route_table_ids
}
2. Now the complete flow makes sense
Child module
# modules/network/outputs.tf

output "private_subnet_ids" {
  value = [
    for subnet in aws_subnet.private : subnet.id
  ]
}

means:

Network module exposes private_subnet_ids.

Then root:

# outputs.tf

output "private_subnet_ids" {
  value = module.network.private_subnet_ids
}

means:

Root module exposes the network module's private_subnet_ids.

Then:

terraform output

means:

Show the root module's exposed outputs.

3. And this is exactly what EKS will use

We don't actually need the root CLI output for EKS.

EKS will directly consume:

module.network.private_subnet_ids

But the root output is useful for us as operators to inspect what Terraform has produced.

So:

                    NETWORK MODULE
                         │
                private_subnet_ids
                         │
                         ▼
                       ROOT
                    ┌────┴────┐
                    │         │
                 EKS       terraform
                              output

Two consumers can use the same module output.

Do this now

First show me:

cat outputs.tf

I'll review the existing root outputs so we don't duplicate vpc_id or accidentally conflict with anything.

Then we'll add only what's missing.

Yes. ✅ These root outputs are correct.

You now have the full chain:

modules/network/outputs.tf
        │
        ▼
root outputs.tf
        │
        ▼
terraform output

Your root file exposes:

public_subnet_ids
private_subnet_ids
nat_gateway_id
private_route_table_ids

So the EKS module can consume the child module output directly, while terraform output can show the values because the root re-exports them.

Now run
terraform fmt
terraform validate
terraform plan

Because we're only adding root outputs, the plan should say approximately:

Plan: 0 to add, 0 to change, 0 to destroy

with Changes to Outputs.

Then run:

terraform apply

You should get:

Apply complete! Resources: 0 added, 0 changed, 0 destroyed.

Then:

terraform output

Now you should finally see:

public_subnet_ids
private_subnet_ids
nat_gateway_id
private_route_table_ids
This is the exact distinction we just learned

Child output:

module.network.private_subnet_ids

→ makes the value available to the root module.

Root output:

output "private_subnet_ids" {
  value = module.network.private_subnet_ids
}

→ makes it visible through:

terraform output

And later EKS doesn't need the CLI output at all. It will consume:

subnet_ids = module.network.private_subnet_ids

directly.

Once you confirm those four values appear in terraform output, we're ready to create modules/eks/.

So the root outputs did not require any AWS infrastructure changes. That's the key point.

Now run:

terraform output

This time, the root should expose the new values:

public_subnet_ids
private_subnet_ids
nat_gateway_id
private_route_table_ids

If they appear, we're done with the network module.

Current architecture
                    ROOT
                     │
              ┌──────┴──────┐
              ▼             ▼
           NETWORK          ...
              │
      ┌───────┴────────┐
      │                │
    creates          outputs
      │                │
      ▼                ▼
   VPC/Subnets    private_subnet_ids
   NAT/Routes     public_subnet_ids
                         │
                         │
                         ▼
                    Future EKS

And importantly, we don't need to create anything else in the network right now.

Once terraform output shows those values, we'll start the separate:

modules/eks/
├── main.tf
├── variables.tf
└── outputs.tf

module and connect it to:

vpc_id     = module.network.vpc_id
subnet_ids = module.network.private_subnet_ids

That will be our first real module → module dependency in this project.

=======================================================================================

Perfect. ✅ Now the output chain is working exactly as intended.

We can clearly see the values exposed by the root module:

vpc_id
  └── vpc-0d8c4099ca854e3c4

public_subnet_ids
  ├── subnet-0bfcc2f5c8812b90c
  └── subnet-0af0c3b3488499638

private_subnet_ids
  ├── subnet-0e3c50c21a4218022
  └── subnet-05ea6fe59bd84f4e9

nat_gateway_id
  └── nat-042ad3bb68b208dfc

This is exactly the interface our EKS module needs.

The important part

We're no longer going to hardcode:

subnet_ids = [
  "subnet-0e3c50c21a4218022",
  "subnet-05ea6fe59bd84f4e9"
]

Instead:

subnet_ids = module.network.private_subnet_ids

So if the network changes, EKS follows the dependency.

Now we start the EKS module

Our project is becoming:

terraform-modules/
│
├── modules/
│   ├── compute/
│   ├── iam-role/
│   ├── key-pair/
│   ├── network/          ✅
│   ├── security-group/
│   └── eks/              ← NEW
│
├── main.tf
├── variables.tf
├── outputs.tf
└── terraform.tfvars

We'll keep EKS separate from compute, as we decided earlier.

EKS module responsibility
EKS module
│
├── EKS Cluster
├── EKS Cluster IAM Role
├── EKS Node Group
└── Node Group IAM Role

And it will consume, not recreate:

Network module
    │
    ├── VPC ID
    └── Private Subnet IDs
             │
             ▼
         EKS module

That's the architecture we're aiming for.

One important EKS design decision

Before writing the module, we're going to use:

EKS Managed Node Group.

So conceptually:

AWS
│
└── EKS
    │
    ├── Control Plane
    │      └── AWS managed
    │
    └── Managed Node Group
           ├── EC2
           └── EC2

This lets us focus on understanding:

EKS control plane
cluster IAM role
node IAM role
node group
subnet placement
Kubernetes networking
module dependencies

rather than manually managing an ASG first.

Next step

We'll create the directory:

mkdir -p modules/eks

Then create:

modules/eks/
├── main.tf
├── variables.tf
└── outputs.tf

We'll start with variables.tf only, just like we did with the network module. This will let you see exactly what the EKS module expects from the root rather than giving you a giant EKS configuration all at once.

=======================================================================================

Step 1 — Create the EKS module

From:

~/aws-terraform-learning/labs/terraform-modules

run:

mkdir -p modules/eks
touch modules/eks/main.tf
touch modules/eks/variables.tf
touch modules/eks/outputs.tf

Check:

tree modules/eks

Expected:

modules/eks/
├── main.tf
├── outputs.tf
└── variables.tf
Step 2 — Start with variables.tf

Don't put resources yet.

Open:

nano modules/eks/variables.tf

Put:

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "cluster_version" {
  description = "Kubernetes version for the EKS cluster"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID for the EKS cluster"
  type        = string
}

variable "subnet_ids" {
  description = "Private subnet IDs for EKS"
  type        = list(string)
}

variable "node_instance_types" {
  description = "EC2 instance types for EKS worker nodes"
  type        = list(string)
}

variable "node_desired_size" {
  description = "Desired number of worker nodes"
  type        = number
}

variable "node_min_size" {
  description = "Minimum number of worker nodes"
  type        = number
}

variable "node_max_size" {
  description = "Maximum number of worker nodes"
  type        = number
}

variable "common_tags" {
  description = "Common tags"
  type        = map(string)
}
Why these variables?

We're deliberately separating inputs from implementation.

                 EKS MODULE INPUTS

cluster_name ────────────────┐
cluster_version ─────────────┤
vpc_id ──────────────────────┤
subnet_ids ──────────────────┤
node_instance_types ─────────┤
node_desired_size ───────────┤
node_min_size ───────────────┤
node_max_size ───────────────┤
common_tags ─────────────────┘
                              │
                              ▼
                         EKS MODULE

The important one for our module-learning objective is:

variable "subnet_ids" {
  type = list(string)
}

The root will eventually provide:

subnet_ids = module.network.private_subnet_ids

So we're explicitly learning:

Network module
      │
      │ output: private_subnet_ids
      ▼
Root module
      │
      │ input: subnet_ids
      ▼
EKS module

That's the pattern I want you to understand rather than simply memorizing EKS syntax.

Step 3 — Root terraform.tfvars

We'll eventually add:

cluster_name   = "terraform-eks-lab"
cluster_version = "1.33"

node_instance_types = [
  "t3.medium"
]

node_desired_size = 2
node_min_size     = 1
node_max_size     = 3

Don't add these yet.

First let's create the EKS module's variable interface and validate it.

Run:

terraform fmt
terraform validate

It may complain that the root has not supplied the new variables yet — that's expected once we add the root module block. For now, just show me the result.

Then we'll build modules/eks/main.tf, starting with the EKS cluster IAM role. That's a good place to continue our IAM learning because EKS introduces a second trust relationship:

EC2 Node Role
Principal = ec2.amazonaws.com

EKS Cluster Role
Principal = eks.amazonaws.com

That will reinforce the Trust Policy vs Permission Policy concept we just completed.

Exactly. ✅

Your structure is now correct:

modules/eks/
├── main.tf
├── outputs.tf
└── variables.tf

And:

terraform validate
Success! The configuration is valid.

Good — we haven't connected EKS to the root yet, so validation is clean.

Next: modules/eks/main.tf

Let's build this in layers.

First, we'll create the EKS cluster IAM role. This reinforces what we just learned with EC2 IAM.

Add this to modules/eks/main.tf:

resource "aws_iam_role" "cluster" {

  name = "${var.cluster_name}-cluster-role"

  assume_role_policy = jsonencode({

    Version = "2012-10-17"

    Statement = [

      {
        Effect = "Allow"

        Principal = {
          Service = "eks.amazonaws.com"
        }

        Action = "sts:AssumeRole"
      }

    ]

  })

  tags = var.common_tags
}
Stop here and understand it

This is the Trust Policy.

Principal = {
  Service = "eks.amazonaws.com"
}

means:

EKS service is trusted to assume this role.

And:

Action = "sts:AssumeRole"

means:

EKS can assume this IAM role through AWS STS.

Compare it with the EC2 role we already built:

EC2 Role
Principal = ec2.amazonaws.com

versus:

EKS Cluster Role
Principal = eks.amazonaws.com

So:

             IAM ROLE
                │
        Trust Policy
                │
       Who can assume it?
          /          \
         /            \
       EC2            EKS
        │              │
ec2.amazonaws.com   eks.amazonaws.com

Important: this trust policy does not give EKS permissions to do anything yet.

That's the distinction:

Trust Policy
    ↓
Who may assume the role?

Permission Policy
    ↓
What can the role do?

For the EKS cluster, AWS provides the required managed permission policy:

AmazonEKSClusterPolicy

We'll attach that next.

Your task now

Put only the aws_iam_role.cluster resource into:

modules/eks/main.tf

Then run:

terraform fmt
terraform validate

Send me the validation result. Then we'll add the cluster permission policy attachment and examine the two policies side-by-side.

Perfect. ✅

terraform fmt       ✅
terraform validate  ✅

The EKS cluster IAM role is syntactically and structurally valid.

Now let's add the Permission Policy separately so you can clearly see the difference from the Trust Policy.

Add to modules/eks/main.tf
resource "aws_iam_role_policy_attachment" "cluster_policy" {

  role = aws_iam_role.cluster.name

  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"

}

Now we have:

EKS Cluster Role
│
├── Trust Policy
│     └── eks.amazonaws.com
│
└── Permission Policy
      └── AmazonEKSClusterPolicy
The distinction

Trust Policy:

Principal = {
  Service = "eks.amazonaws.com"
}

Action = "sts:AssumeRole"

Answers:

Who is allowed to become this role?

Permission Policy:

policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"

Answers:

What permissions does the assumed role have?

So we're applying the same IAM model you learned with EC2:

EC2
 └── Role
      ├── Trust → ec2.amazonaws.com
      └── Permission → SSM policy


EKS
 └── Cluster Role
      ├── Trust → eks.amazonaws.com
      └── Permission → EKS Cluster Policy

Run:

terraform fmt
terraform validate

Once that is clean, don't create the EKS cluster yet. Next we'll add the actual aws_eks_cluster resource and connect it to:

module.network.vpc_id
module.network.private_subnet_ids

That's where the module-to-module wiring becomes real.

Perfect. ✅

The EKS module currently has:

EKS Cluster IAM Role
├── Trust Policy
│   └── eks.amazonaws.com
│
└── Permission Policy
    └── AmazonEKSClusterPolicy

And Terraform confirms:

terraform fmt       ✅
terraform validate  ✅

So we're ready for the actual EKS cluster resource.

Next: aws_eks_cluster

Add this below the IAM resources in:

modules/eks/main.tf
resource "aws_eks_cluster" "this" {

  name     = var.cluster_name
  role_arn = aws_iam_role.cluster.arn
  version  = var.cluster_version

  vpc_config {
    subnet_ids = var.subnet_ids
  }

  tags = var.common_tags

}
Notice the important flow

The EKS module doesn't know anything about the actual subnet IDs.

It only knows:

subnet_ids = var.subnet_ids

The root module will later provide:

subnet_ids = module.network.private_subnet_ids

So:

NETWORK MODULE
     │
     │ private_subnet_ids
     ▼
ROOT MODULE
     │
     │ subnet_ids
     ▼
EKS MODULE
     │
     ▼
aws_eks_cluster

That's the module composition we wanted to learn.

And the IAM connection

The cluster gets the role we just created:

role_arn = aws_iam_role.cluster.arn

So the complete EKS cluster relationship becomes:

                  EKS Cluster
                       │
                       │ assumes
                       ▼
                Cluster IAM Role
                  /           \
                 /             \
        Trust Policy       Permission Policy
        eks.amazonaws      AmazonEKSClusterPolicy
             .com
                       │
                       ▼
                  VPC Config
                       │
                       ▼
              Private Subnets

Don't add the node group yet.

Add only aws_eks_cluster.this, then run:

terraform fmt
terraform validate

If validation is clean, we'll connect the root module to EKS next.



Perfect. ✅

The EKS module currently has:

EKS Cluster IAM Role
├── Trust Policy
│   └── eks.amazonaws.com
│
└── Permission Policy
    └── AmazonEKSClusterPolicy

And Terraform confirms:

terraform fmt       ✅
terraform validate  ✅

So we're ready for the actual EKS cluster resource.

Next: aws_eks_cluster

Add this below the IAM resources in:

modules/eks/main.tf
resource "aws_eks_cluster" "this" {

  name     = var.cluster_name
  role_arn = aws_iam_role.cluster.arn
  version  = var.cluster_version

  vpc_config {
    subnet_ids = var.subnet_ids
  }

  tags = var.common_tags

}
Notice the important flow

The EKS module doesn't know anything about the actual subnet IDs.

It only knows:

subnet_ids = var.subnet_ids

The root module will later provide:

subnet_ids = module.network.private_subnet_ids

So:

NETWORK MODULE
     │
     │ private_subnet_ids
     ▼
ROOT MODULE
     │
     │ subnet_ids
     ▼
EKS MODULE
     │
     ▼
aws_eks_cluster

That's the module composition we wanted to learn.

And the IAM connection

The cluster gets the role we just created:

role_arn = aws_iam_role.cluster.arn

So the complete EKS cluster relationship becomes:

                  EKS Cluster
                       │
                       │ assumes
                       ▼
                Cluster IAM Role
                  /           \
                 /             \
        Trust Policy       Permission Policy
        eks.amazonaws      AmazonEKSClusterPolicy
             .com
                       │
                       ▼
                  VPC Config
                       │
                       ▼
              Private Subnets

Don't add the node group yet.

Add only aws_eks_cluster.this, then run:

terraform fmt
terraform
 validate

If validation is clean, we'll connect the root module to EKS next.

===========================================================

Perfect. ✅

terraform fmt       → clean
terraform validate  → Success

So the EKS cluster resource is valid.

Current EKS module

We now have:

modules/eks/
├── main.tf
│   ├── aws_iam_role.cluster
│   ├── aws_iam_role_policy_attachment.cluster_policy
│   └── aws_eks_cluster.this
├── variables.tf
└── outputs.tf

And the dependency chain is:

Network Module
     │
     ├── vpc_id
     └── private_subnet_ids
             │
             ▼
        EKS Module
             │
             └── aws_eks_cluster
Next: connect EKS to the root module

Now we need to actually instantiate the EKS module from the root main.tf.

Add this after your existing modules:

module "eks" {

  source = "./modules/eks"

  cluster_name   = "terraform-eks-lab"
  cluster_version = "1.33"

  vpc_id = module.network.vpc_id

  subnet_ids = module.network.private_subnet_ids

  node_instance_types = [
    "t3.medium"
  ]

  node_desired_size = 2
  node_min_size     = 1
  node_max_size     = 3

  common_tags = local.common_tags

}
But notice something important

At this point we're passing:

vpc_id = module.network.vpc_id

but our aws_eks_cluster currently doesn't actually use var.vpc_id.

That's intentional for the moment, but we should clean that up before applying. EKS's vpc_config primarily needs the subnet IDs; the VPC is implicitly determined by those subnets.

So vpc_id is useful as an explicit module input for architectural clarity, but the resource itself doesn't need to reference it.

Also, we are not creating the node group yet. The node-related variables are currently just preparing the module interface.

Do not run apply

After adding the root module block, run:

terraform fmt
terraform validate
terraform plan

The plan will now be very important because Terraform will show us the EKS cluster and IAM resources it intends to create.

Do not apply it yet.

Send me the plan summary. Then we'll review exactly what Terraform wants to create before we introduce the managed node group.

Yes — 28 makes sense. 👍

You previously destroyed the infrastructure, so Terraform is now starting from an empty state and the new EKS module adds 3 additional resources on top of the 25-resource foundation.

Why 28?

Your previous foundation:

Network + IAM + SG + Key Pair + 3 EC2
= 25 resources

EKS module currently adds:

1. aws_iam_role.cluster
2. aws_iam_role_policy_attachment.cluster_policy
3. aws_eks_cluster.this

Therefore:

25 existing foundation
+ 3 EKS resources
------------------
= 28

And importantly, the node group is NOT being created yet.

Your root module:

module "eks" {

  source = "./modules/eks"

  cluster_name    = "terraform-eks-lab"
  cluster_version = "1.33"

  vpc_id = module.network.vpc_id

  subnet_ids = module.network.private_subnet_ids

  node_instance_types = [
    "t3.medium"
  ]

  node_desired_size = 2
  node_min_size     = 1
  node_max_size     = 3

  common_tags = local.common_tags

}

is currently passing the node configuration into the module, but we haven't created aws_eks_node_group yet.

So the architecture currently is:

                ROOT
                 │
       ┌─────────┴──────────┐
       ▼                    ▼
   NETWORK                 EKS
       │                    │
       │                    ├── Cluster IAM Role
       │                    ├── EKS Cluster
       │                    └── Cluster Policy
       │
       ├── VPC
       └── Private Subnets
                │
                └──────────► EKS
One important observation

You have:

vpc_id = module.network.vpc_id

but our current aws_eks_cluster resource uses:

vpc_config {
  subnet_ids = var.subnet_ids
}

So var.vpc_id isn't actually consumed by the resource yet.

That's not an error, but we'll decide later whether to keep it as an explicit architectural input or remove it.

Before we apply

Since you said 28 is expected, let's inspect the plan.

Run:

terraform plan

Don't apply yet.

I want to see the EKS portion, especially:

aws_iam_role.cluster
aws_iam_role_policy_attachment.cluster_policy
aws_eks_cluster.this

Once that looks correct, we'll apply the cluster only.

Then we'll learn the next major EKS concept:

EKS Cluster
     │
     ▼
Managed Node Group
     │
     ├── Node IAM Role
     ├── EC2 worker nodes
     └── Kubernetes workloads

That's where your node_instance_types, desired, min, and max variables will finally become active.

===============================================================================

Yes — keep the same configuration. 👍

We don't need to change anything yet.

Your root module "eks" block is fine for this stage:

module "eks" {

  source = "./modules/eks"

  cluster_name    = "terraform-eks-lab"
  cluster_version = "1.33"

  vpc_id = module.network.vpc_id

  subnet_ids = module.network.private_subnet_ids

  node_instance_types = [
    "t3.medium"
  ]

  node_desired_size = 2
  node_min_size     = 1
  node_max_size     = 3

  common_tags = local.common_tags
}
Current stage

We have 28 resources planned:

25  → existing foundation
 3  → EKS cluster
     ├── Cluster IAM Role
     ├── Cluster IAM Policy Attachment
     └── EKS Cluster

The node variables:

node_instance_types
node_desired_size
node_min_size
node_max_size

are not active yet because we haven't created the managed node group.

So let's keep the configuration as-is.

Next

Run:

terraform plan

If the plan shows:

Plan: 28 to add, 0 to change, 0 to destroy

and the EKS resources are the expected three, then we can apply.

After the cluster is created, we'll build the node IAM role + managed node group. That will be the point where your t3.medium, desired=2, min=1, max=3 actually take effect.

=============================================================================

Yes — this confirms the network foundation is successfully recreated and the module outputs are working. ✅

The important values for EKS are now available:

VPC
└── vpc-0a61035190fc0abe7

Public subnets
├── subnet-018d7376fc79c8301
└── subnet-0b11aac6cdff15681

Private subnets
├── subnet-0edb151a77a2576bd
└── subnet-09263a993fe25a85f

NAT Gateway
└── nat-015e9783384bb8052

And notice the IDs are different from our previous deployment. That's expected because you destroyed and recreated the infrastructure.

The important module flow is now proven
module.network
      │
      ├── vpc_id
      │      ↓
      │   module.eks
      │
      └── private_subnet_ids
             ↓
          module.eks

Your root configuration:

vpc_id     = module.network.vpc_id
subnet_ids = module.network.private_subnet_ids

will therefore resolve to the current infrastructure automatically.

Now don't use terraform output for the next check

We need to see what Terraform intends to create for EKS.

Run:

terraform plan

We're expecting:

Plan: 28 to add, 0 to change, 0 to destroy

and specifically:

module.eks.aws_iam_role.cluster
module.eks.aws_iam_role_policy_attachment.cluster_policy
module.eks.aws_eks_cluster.this

Do not apply yet. Send me that plan summary/EKS section, and we'll verify the cluster configuration before creating the control plane.

Yes, this output is correct. ✅ It confirms the current network deployment and module outputs.

The two values EKS will consume are:

vpc_id
└── vpc-0a61035190fc0abe7

private_subnet_ids
├── subnet-0edb151a77a2576bd
└── subnet-09263a993fe25a85f

And these are being passed automatically through:

vpc_id     = module.network.vpc_id
subnet_ids = module.network.private_subnet_ids

So don't change anything.

Now the next command is simply:
terraform plan

We need to inspect the plan, not terraform output again.

Look for:

module.eks.aws_iam_role.cluster
module.eks.aws_iam_role_policy_attachment.cluster_policy
module.eks.aws_eks_cluster.this

and the summary should be approximately:

Plan: 28 to add, 0 to change, 0 to destroy.

Don't run apply yet.

Send me the EKS portion of the plan. We'll verify the control-plane configuration first, then apply it.

=====================================================================

Next: Node IAM Role

Now we'll add the second IAM role.

This is different from the EKS cluster role.

Cluster role
Trust:
eks.amazonaws.com

Used by:

EKS Control Plane
Node role
Trust:
ec2.amazonaws.com

Used by:

EKS Worker Nodes

So we're reinforcing the IAM concept:

EKS Cluster
   │
   └── Cluster Role
          └── eks.amazonaws.com


EKS Node Group
   │
   └── Node Role
          └── ec2.amazonaws.com
Add to modules/eks/main.tf
resource "aws_iam_role" "node" {

  name = "${var.cluster_name}-node-role"

  assume_role_policy = jsonencode({

    Version = "2012-10-17"

    Statement = [

      {
        Effect = "Allow"

        Principal = {
          Service = "ec2.amazonaws.com"
        }

        Action = "sts:AssumeRole"
      }

    ]

  })

  tags = var.common_tags
}

Then we'll attach the required node permissions.

For now, only add the role.

Run:

terraform fmt
terraform validate

Don't apply yet.

Once that validates, we'll attach:

AmazonEKSWorkerNodePolicy
AmazonEC2ContainerRegistryPullOnly
AmazonEKS_CNI_Policy

and then build the Managed Node Group.

That is the point where our t3.medium, desired=2, min=1, max=3 settings actually become infrastructure.

================================================================

Perfect. ✅

terraform validate
Success! The configuration is valid.

The EKS node IAM role is valid.

Current EKS architecture
EKS
│
├── Control Plane
│    │
│    └── Cluster IAM Role
│         ├── Trust → eks.amazonaws.com
│         └── AmazonEKSClusterPolicy
│
└── Worker Nodes
     │
     └── Node IAM Role
          └── Trust → ec2.amazonaws.com

Now let's add the three node permissions.

In modules/eks/main.tf, add:

resource "aws_iam_role_policy_attachment" "node_worker" {

  role = aws_iam_role.node.name

  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"

}

resource "aws_iam_role_policy_attachment" "node_cni" {

  role = aws_iam_role.node.name

  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"

}

resource "aws_iam_role_policy_attachment" "node_ecr" {

  role = aws_iam_role.node.name

  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPullOnly"

}
Understand what each one is doing
Policy	Purpose
AmazonEKSWorkerNodePolicy	Allows worker nodes to interact with EKS
AmazonEKS_CNI_Policy	Allows the AWS VPC CNI to manage pod networking
AmazonEC2ContainerRegistryPullOnly	Allows nodes to pull container images from ECR

So the node role becomes:

Node IAM Role
│
├── Trust Policy
│     └── ec2.amazonaws.com
│
├── AmazonEKSWorkerNodePolicy
├── AmazonEKS_CNI_Policy
└── AmazonEC2ContainerRegistryPullOnly

Again:

Trust Policy
    ↓
Who can assume the role?

Permission Policies
    ↓
What can that role do?

This is the same IAM pattern we learned earlier, now applied to EKS.

Then validate
terraform fmt
terraform validate

Don't apply yet.

After validation succeeds, we'll create the aws_eks_node_group resource. That's where your:

node_instance_types = ["t3.medium"]
node_desired_size   = 2
node_min_size       = 1
node_max_size       = 3
finally become actual worker-node infrastructure

=================================================================

Next: Managed Node Group

Now we finally use the variables we prepared earlier.

Add this to modules/eks/main.tf:

resource "aws_eks_node_group" "this" {

  cluster_name = aws_eks_cluster.this.name

  node_group_name = "${var.cluster_name}-nodes"

  node_role_arn = aws_iam_role.node.arn

  subnet_ids = var.subnet_ids

  instance_types = var.node_instance_types

  scaling_config {
    desired_size = var.node_desired_size
    min_size     = var.node_min_size
    max_size     = var.node_max_size
  }

  tags = var.common_tags

  depends_on = [
    aws_iam_role_policy_attachment.node_worker,
    aws_iam_role_policy_attachment.node_cni,
    aws_iam_role_policy_attachment.node_ecr
  ]
}
Now our variables become real infrastructure
node_instance_types = ["t3.medium"]
             ↓
        EC2 node type

desired = 2
             ↓
        start with 2 nodes

min = 1
             ↓
        don't scale below 1

max = 3
             ↓
        don't scale above 3

And:

subnet_ids = var.subnet_ids

means the worker nodes are placed in the private subnets coming from our network module:

module.network.private_subnet_ids
            │
            ▼
       EKS module
            │
            ▼
    Managed Node Group
            │
       ┌────┴────┐
       ▼         ▼
    Private   Private
    Subnet A  Subnet B
Why depends_on?

This is worth understanding.

The node group uses:

node_role_arn = aws_iam_role.node.arn

but that alone doesn't necessarily express the full operational dependency on the policy attachments.

We want:

Node IAM Role
     │
     ├── Worker Policy
     ├── CNI Policy
     └── ECR Policy
             │
             ▼
       Node Group

So:

depends_on = [
  ...
]

ensures the required permissions are attached before Terraform creates the node group.

Now validate

Run:

terraform fmt
terraform validate

Then don't apply yet.

Next we'll run:

terraform plan

and carefully inspect what AWS is going to create.

At that point the EKS layer should add 5 resources:

1 × Cluster IAM Role
1 × Cluster Policy Attachment
1 × EKS Cluster
1 × Node IAM Role
3 × Node Policy Attachments
1 × Managed Node Group

Actually, that's 8 EKS resources total, so if your network/foundation is already present, the full resource count should reflect those 8. We'll verify the exact plan rather than assuming the count.

=================================================================

Excellent. This is exactly the plan we expected. ✅

The important line is:

Plan: 5 to add, 0 to change, 0 to destroy.

And 5 resources makes perfect sense because the EKS control plane already exists.

What will be added
EKS Node Layer
│
├── 1. Node IAM Role
│      └── Trust: ec2.amazonaws.com
│
├── 2. AmazonEKSWorkerNodePolicy
│
├── 3. AmazonEKS_CNI_Policy
│
├── 4. AmazonEC2ContainerRegistryPullOnly
│
└── 5. Managed Node Group
       │
       ├── instance type: t3.medium
       ├── desired: 2
       ├── minimum: 1
       ├── maximum: 3
       │
       ├── Private subnet
       │     subnet-09263a993fe25a85f
       │
       └── Private subnet
             subnet-0edb151a77a2576bd
This is particularly important

Look at:

subnet_ids = [
  "subnet-09263a993fe25a85f",
  "subnet-0edb151a77a2576bd",
]

Those are not hardcoded in the EKS module.

They came through:

module.network.private_subnet_ids
            ↓
root module
            ↓
module.eks.subnet_ids
            ↓
aws_eks_node_group.this

We've now demonstrated the module composition pattern in a real deployment.

And the scaling configuration is correct

Your plan shows:

desired = 2
min     = 1
max     = 3

Meaning:

                 Node Group
                     │
             ┌───────┴───────┐
             ▼               ▼
          Node 1           Node 2
          t3.medium        t3.medium

        Minimum = 1
        Desired = 2
        Maximum = 3

The Auto Scaling behavior behind the managed node group can therefore maintain between 1 and 3 nodes, with 2 desired.

One correction to our earlier count

Earlier I said the EKS layer would add 8 resources. That was the full EKS module count from an empty state:

3 cluster resources
+
5 node resources
=
8

But your cluster resources are already present:

aws_iam_role.cluster
aws_iam_role_policy_attachment.cluster_policy
aws_eks_cluster.this

Therefore this plan correctly shows only:

5 to add

Good Terraform state reasoning. 👍

We can apply now

The plan shows:

0 to change
0 to destroy

and the five additions are exactly what we want.

Run:

terraform apply

Review the plan and enter:

yes

This will create two t3.medium EKS worker nodes, so AWS billing will increase while they are running.

The node group can take several minutes to become ACTIVE. That's normal.

When it completes, send me the final output.

Then we'll do the really useful part:

AWS EKS
   │
   ├── Control Plane
   │
   └── Node Group
         │
         ├── EC2 Node
         └── EC2 Node
                │
                ▼
             kubectl
                │
                ▼
          Kubernetes API

We'll verify the cluster and nodes using AWS CLI + kubectl, and then we'll be in a proper position to start the Argo CD learning you originally wanted EKS for.

==============================================================================================

What should we do?

Since this is a learning lab and we don't want unnecessary cost, I recommend changing:

node_instance_types = [
  "t3.medium"
]

to a Free-Tier-eligible instance type available to your account/region.

First, let's ask AWS what it considers eligible, rather than guessing.

Run:

aws ec2 describe-instance-types \
  --filters Name=free-tier-eligible,Values=true \
  --query 'InstanceTypes[].InstanceType' \
  --output text

Then we'll choose an appropriate type from your actual account's response.

Important

Don't change the Terraform configuration yet.

And don't destroy anything manually.

The node group is still in CREATING because the ASG keeps trying to reach desired capacity. Once we decide the correct instance type, we'll update the Terraform variable and let Terraform reconcile it properly.

This was a very useful failure for the EKS lab — we just demonstrated why EKS troubleshooting requires looking below the EKS abstraction into ASG/EC2 events.

============================================================

Your account reports these as Free-Tier eligible:

c7i-flex.large
t4g.small
t4g.micro
t3.micro
t3.small
m7i-flex.large

For our EKS + future Argo CD lab, I recommend:

node_instance_types = [
  "t3.small"
]
Why t3.small
Type	vCPU	Memory	Our use
t3.micro	2	1 GiB	Too small for EKS + Argo CD
t3.small	2	2 GiB	Best lab choice
t4g.small	2	2 GiB	ARM architecture; adds architecture considerations
t3.medium	2	4 GiB	Good technically, but your account rejects it

So let's stay with x86 t3.small. It keeps our EKS lab simple and gives us more room for Kubernetes components than t3.micro.

Change the root EKS configuration

Currently:

node_instance_types = [
  "t3.medium"
]

Change it to:

node_instance_types = [
  "t3.small"
]

Your other settings remain exactly the same:

node_desired_size = 2
node_min_size     = 1
node_max_size     = 3
Then

First, if the original terraform apply is still running, stop that Terraform process with:

Ctrl+C

This does not automatically destroy the infrastructure already created.

Then:

terraform fmt
terraform validate
terraform plan
One important thing

Our current AWS node group is still:

CREATING

and has:

Desired: 2
Instances: 0

because every t3.medium launch failed due to the Free Tier restriction. We have confirmed this from the ASG activity history.

So after changing to t3.small, don't assume Terraform will immediately replace the failed configuration. Let's inspect the new plan first.

Send me the section around:

module.eks.aws_eks_node_group.this

and the final:

Plan: X to add, Y to change, Z to destroy

Then we'll decide whether Terraform can reconcile the existing CREATING node group cleanly or whether we need to handle the failed node group first.

Yes. This is the correct Terraform response to the failed node group.

The key lines are:

module.eks.aws_eks_node_group.this is tainted, so must be replaced

and:

"t3.medium" -> "t3.small"

with:

status = "CREATE_FAILED"

So Terraform has correctly detected that the previous node group failed and is proposing:

-/+ destroy and then create replacement

Plan: 1 to add, 0 to change, 1 to destroy.
What will happen

Terraform will replace:

terraform-eks-lab-nodes
        │
        └── failed t3.medium node group

with:

terraform-eks-lab-nodes
        │
        └── new t3.small node group
              │
              ├── desired = 2
              ├── min     = 1
              └── max     = 3

The previous node group is already CREATE_FAILED, so we're not destroying a healthy production workload here. The replacement is exactly what we want for this lab.

One thing I want you to notice

This is an important Terraform concept:

Configuration changed
        +
Existing resource is tainted/failed
        ↓
Terraform determines replacement is required
        ↓
-/+ destroy and create

Terraform is not modifying the EC2 instances individually. The resource being managed here is the EKS managed node group. AWS will create the new underlying ASG and instances as part of that replacement.

I would proceed

Run:

terraform apply

Review that it says:

-/+ module.eks.aws_eks_node_group.this

and:

Plan: 1 to add, 0 to change, 1 to destroy.

Then enter:

yes

This time, with t3.small, the EC2 launch should no longer hit the Free Tier restriction that caused the previous failure. The previous failure was explicitly recorded for t3.medium in both us-east-1a and us-east-1b.

Let it run. The node group may again take several minutes, but this time we'll monitor it with the same AWS CLI approach rather than just waiting blindly.

=======================================================

Excellent. ✅ EKS worker-node layer is now successfully deployed.

The important result:

module.eks.aws_eks_node_group.this:
Creation complete after 2m23s

and:

Apply complete! Resources: 1 added, 0 changed, 1 destroyed.

So the failed t3.medium node group was replaced successfully with the t3.small configuration.

Current architecture
AWS
│
├── VPC
│   ├── Public Subnet A
│   ├── Public Subnet B
│   │
│   ├── Private Subnet A ──┐
│   │                       │
│   └── Private Subnet B ──┤
│                           │
│                        NAT Gateway
│
└── EKS
    │
    ├── AWS Managed Control Plane
    │      │
    │      └── Cluster IAM Role
    │
    └── Managed Node Group
           │
           ├── t3.small
           └── t3.small

And importantly, the EKS module is consuming the network module:

module.network
    │
    ├── vpc_id
    │
    └── private_subnet_ids
             │
             ▼
        module.eks
             │
             ▼
       node group

That's exactly the modular Terraform architecture we wanted to learn.

Now let's verify Kubernetes

Don't immediately move to Argo CD yet. First prove that the EKS platform is healthy.

Run:

aws eks describe-cluster \
  --name terraform-eks-lab \
  --query 'cluster.{name:name,status:status,version:version,endpoint:endpoint}' \
  --output table

We want:

status = ACTIVE
version = 1.33

Then:

aws eks describe-nodegroup \
  --cluster-name terraform-eks-lab \
  --nodegroup-name terraform-eks-lab-nodes \
  --query 'nodegroup.{status:status,instanceTypes:instanceTypes,desired:scalingConfig.desiredSize,min:scalingConfig.minSize,max:scalingConfig.maxSize}' \
  --output table

We want:

status       ACTIVE
instance     t3.small
desired      2
min          1
max          3
Then configure kubectl

Run:

aws eks update-kubeconfig \
  --region us-east-1 \
  --name terraform-eks-lab

Then:

kubectl get nodes -o wide

This is the important transition:

Terraform
   ↓
AWS EKS
   ↓
Control Plane
   ↓
Managed Node Group
   ↓
EC2 Worker Nodes
   ↓
kubectl

Once kubectl get nodes shows 2 Ready nodes, we've completed the EKS foundation.

Then we'll move to the next logical step:

EKS → Kubernetes fundamentals → Helm → Argo CD → GitOps

rather than jumping directly into Argo CD without understanding what it's deploying onto.

====================================================================================

Good — the EKS infrastructure itself is healthy. We have:

Cluster: ACTIVE, Kubernetes 1.33
Node group: ACTIVE
Nodes desired: 2
Instance type: t3.small

The problem is specifically local kubectl configuration, not EKS.

Your kubectl error:

The connection to the server localhost:8080 was refused

means kubectl has no usable kubeconfig/current context, so it falls back to localhost:8080.

And this command failed:

aws eks update-kubeconfig \
  --region us-east-1 \
  --name terraform-eks-lab

with:

'NoneType' object is not iterable

AWS's current EKS documentation requires AWS CLI v2.12.3+ (or CLI v1.27.160+) for update-kubeconfig, so let's check your CLI version first.

Step 1 — check AWS CLI

Run:

aws --version

Also:

which aws

and:

aws configure list

Don't change anything yet.

Why I'm checking this first

Your AWS CLI clearly works because:

aws eks describe-cluster

and:

aws eks describe-nodegroup

both work.

So this is not an AWS credential problem.

update-kubeconfig needs to retrieve the cluster endpoint and CA information and write a kubeconfig entry. AWS documents that this command creates/merges the kubeconfig under ~/.kube/config by default.

We therefore want to find out whether we're dealing with:

AWS CLI version
        ↓
update-kubeconfig implementation
        ↓
~/.kube/config

rather than touching the EKS cluster itself.

Don't manually create kubeconfig yet

Once we see aws --version, we'll fix the client side cleanly.

After that the expected flow is:

aws eks update-kubeconfig
          ↓
~/.kube/config
          ↓
kubectl config current-context
          ↓
kubectl get nodes
          ↓
2 × Ready

Send me the output of:

aws --version
which aws
aws configure list

and we'll resolve this before proceeding to Kubernetes/Argo CD.

==================================================================

Exactly — this is an important EKS concept, and you do NOT need to SSH into an EC2 worker node to manage the cluster.

Your current architecture is:

                    AWS ACCOUNT
                         │
              ┌──────────┴──────────┐
              │                     │
       EKS CONTROL PLANE       EKS DATA PLANE
       AWS managed             Your EC2 nodes
              │                     │
       ┌──────┴──────┐        ┌─────┴─────┐
       │             │        │           │
   API Server   etcd/control  Node 1     Node 2
                  components  t3.small   t3.small
1. Where is the EKS control plane?

AWS manages it for you.

When we created:

resource "aws_eks_cluster" "this" {
  ...
}

AWS created the Kubernetes control plane.

You don't SSH into it.

You don't manage its EC2 instances.

You don't install kube-apiserver, etcd, scheduler, etc. yourself.

That's the major difference between EKS and building Kubernetes manually.

2. Where are the application Pods?

Your application Pods run on the worker nodes:

EKS Control Plane
       │
       │ Kubernetes API
       ▼
┌──────────────────────┐
│ Managed Node Group   │
│                      │
│ EC2 t3.small         │
│   └── Pods            │
│                      │
│ EC2 t3.small         │
│   └── Pods            │
└──────────────────────┘

Those EC2 instances are the data plane.

So your original answer from the EKS learning session was correct:

Control plane → AWS managed
Data plane → EC2 worker nodes

3. Then where does kubectl run?

This is the part that was confusing you.

kubectl can run outside the EC2 nodes.

For example, right now you're here:

Windows
   │
   └── WSL Ubuntu
          │
          └── kubectl

And kubectl communicates with:

WSL
 │
 │ HTTPS
 ▼
EKS Kubernetes API Server
 │
 ▼
Control Plane
 │
 ▼
Worker Nodes
 │
 ▼
Pods

You therefore do not need to SSH into either EC2 node.

4. Why did your kubectl say localhost:8080?

This is a completely separate issue.

Your:

kubectl get nodes

returned:

The connection to the server localhost:8080 was refused

That means kubectl currently doesn't have a valid Kubernetes context/configuration.

It is not saying the EKS cluster is running on localhost.

It is essentially saying:

"I don't know which Kubernetes API server you want me to talk to, so I'm trying my default configuration."

Your EKS cluster itself is healthy:

EKS Cluster
status = ACTIVE
version = 1.33

Node Group
status = ACTIVE
desired = 2
instance = t3.small

So the problem is entirely on your WSL client side.

5. And we just found another important thing

Your AWS CLI is:

aws-cli/1.22.34

That's quite old.

That explains why:

aws eks update-kubeconfig

gave:

'NoneType' object is not iterable

So don't touch the EKS infrastructure.

We need to fix the AWS CLI on your WSL machine.

The architecture we are learning is:

Terraform
   │
   ├── Creates VPC
   ├── Creates NAT
   ├── Creates EKS control plane
   └── Creates managed node group
             │
             ▼
          AWS EKS
             │
       Kubernetes API
             ▲
             │
          kubectl
             ▲
             │
       Your WSL machine

And this is actually the model you need to understand for Argo CD:

Git
 │
 ▼
Argo CD
 │
 │ talks to Kubernetes API
 ▼
EKS Control Plane
 │
 ▼
Worker Nodes
 │
 ▼
Application Pods

Argo CD does not need to be installed on your laptop or directly on an EC2 node either. Eventually, we'll deploy Argo CD inside the Kubernetes cluster, and it will communicate with the Kubernetes API.

So you're asking the right question at exactly the right point.

Next step: fix the AWS CLI on WSL, generate the kubeconfig, and then use kubectl from WSL without SSHing into EC2.

Next session step is straightforward:

Upgrade AWS CLI in WSL from 1.22.34 to AWS CLI v2.

Run:

aws eks update-kubeconfig --region us-east-1 --name terraform-eks-lab

Verify:

kubectl config current-context
kubectl get nodes -o wide
Confirm 2 t3.small nodes are Ready.

Then inspect the cluster with:

kubectl get pods -A
After that we'll move into Helm → Argo CD → GitOps.

And importantly, no SSH into the EKS worker nodes is required for normal Kubernetes administration.

======================================================================

Step 1 — Install AWS CLI v2

You're on WSL Ubuntu x86_64, so use AWS's official Linux x86_64 installer. AWS recommends the bundled installer for Linux.

Run:

cd ~
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install --update

Then check:

aws --version
which aws

We want something like:

aws-cli/2.x.x ...

and preferably:

/usr/local/bin/aws

AWS CLI v1 and v2 intentionally use the same aws command, so after installing v2 it's important to verify which executable your shell is actually finding.

If which aws still says /usr/bin/aws

Run:

hash -r
which aws
aws --version

If necessary:

type -a aws

That will show us whether WSL has both v1 and v2 installed.

Step 2 — Don't reconfigure credentials

Your existing credentials are already working.

We know this because:

aws eks describe-cluster

successfully returned:

terraform-eks-lab
ACTIVE
1.33

So do not run aws configure again unless we discover the credentials disappeared.

After v2 is installed, verify:

aws sts get-caller-identity

It should return your existing AWS account identity.

Step 3 — Generate kubeconfig

Once aws --version shows v2:

aws eks update-kubeconfig \
  --region us-east-1 \
  --name terraform-eks-lab

AWS says this creates/merges the cluster configuration into ~/.kube/config by default.

Then:

kubectl config current-context

You should see an EKS context similar to:

arn:aws:eks:us-east-1:587748224379:cluster/terraform-eks-lab

Then:

kubectl get nodes -o wide

Expected:

NAME              STATUS   ROLES    ...
ip-10-0-x-x       Ready    <none>   ...
ip-10-0-x-x       Ready    <none>   ...
The architecture we're proving
Your WSL
   │
   │ kubectl
   ▼
~/.kube/config
   │
   │ HTTPS + AWS authentication
   ▼
EKS API Server
   │
   ▼
AWS-managed Control Plane
   │
   ▼
Managed Node Group
   ├── EC2 t3.small
   └── EC2 t3.small

This is exactly why you don't need to SSH into the EC2 nodes to use Kubernetes.

Start with the AWS CLI v2 installation and send me the output of:

aws --version
which aws

before we proceed.

================================================================

Exactly — you were just one step short. The download succeeded and unzip is now installed.

The reason this failed:

sudo ./aws/install --update

is simply that the ZIP has not been extracted yet, so the ./aws/ directory doesn't exist.

AWS's official installation sequence is:

download ZIP
   ↓
unzip ZIP
   ↓
./aws/install

Continue from where you are

You're currently in ~, and awscliv2.zip is already there.

Run:

unzip -u awscliv2.zip

You should see a lot of files being extracted and eventually an aws/ directory.

Then:

sudo ./aws/install --update
Then verify

Run:

aws --version

and:

which aws

Because you currently have the old v1 at:

/usr/bin/aws

we want the new installation to normally resolve to:

/usr/local/bin/aws

If it still shows /usr/bin/aws, don't change anything manually yet. Run:

type -a aws

and send me the output.

One important point

Your existing AWS credentials/configuration are not being replaced by this installation. We're replacing the AWS CLI executable, not your ~/.aws configuration.

Once v2 is active, we'll retry:

aws eks update-kubeconfig \
  --region us-east-1 \
  --name terraform-eks-lab

Then:

kubectl config current-context
kubectl get nodes -o wide

===========================================================================

Perfect. The AWS CLI v2 is installed successfully. Your screenshot confirms:

/usr/local/bin/aws

But your shell is still executing the old /usr/bin/aws:

aws-cli/1.22.34

This is a shell command cache issue, not an installation problem.

Step 1 — refresh the shell command cache

Run:

hash -r

Then:

aws --version

Now we expect something like:

aws-cli/2.x.x ...

And verify:

which aws

should remain:

/usr/local/bin/aws
Step 2 — verify AWS identity

Once v2 is showing:

aws sts get-caller-identity

This should work exactly as before.

Step 3 — retry EKS kubeconfig

Then:

aws eks update-kubeconfig \
  --region us-east-1 \
  --name terraform-eks-lab

You should get something similar to:

Added new context arn:aws:eks:us-east-1:...:cluster/terraform-eks-lab to /home/om/.kube/config

Then:

kubectl config current-context

and finally:

kubectl get nodes -o wide

We are expecting 2 Ready nodes.

So don't reinstall anything — the installation is already done. Just run hash -r first

==================================================================

Now let's verify the Kubernetes layer

Before Helm or Argo CD, I want you to see what Kubernetes actually has.

Run:

kubectl get pods -A

Then:

kubectl get namespaces

And:

kubectl get nodes

The first command is particularly important because you'll see the AWS/EKS system workloads already running on your worker nodes.

After that, we'll inspect:

Node
 ├── kube-system Pods
 ├── CoreDNS
 ├── kube-proxy
 └── AWS VPC CNI

That gives us the Kubernetes foundation we need before we introduce Helm and Argo CD.

And importantly, we're still following your Terraform-module approach:

Terraform root
│
├── network module
├── security-group module
├── IAM module
├── key-pair module
├── compute module
└── EKS module
       │
       ├── EKS control plane
       └── EKS managed node group
                │
                └── Kubernetes
                     │
                     ├── Helm
                     └── Argo CD

This is now becoming a realistic modern cloud platform rather than isolated Terraform labs.
