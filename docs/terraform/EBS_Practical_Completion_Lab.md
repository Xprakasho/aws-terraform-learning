Module: EBS Practical Completion Lab

Objective

Understand the complete lifecycle of an EBS volume:

Terraform
   ↓
Create EBS Volume
   ↓
Attach to EC2
   ↓
Detect block device
   ↓
Format filesystem
   ↓
Mount volume
   ↓
Write data
   ↓
Unmount / remount
   ↓
Verify persistence
   ↓
Understand snapshot
   ↓
Destroy safely
Important design decision

We should use a separate lab directory, not modify the completed EKS or launch-template module.

Suggested structure:

aws-terraform-learning/
└── labs/
    ├── terraform-launch-template/
    ├── terraform-modules/
    ├── terraform-aws-iam-authentication/
    └── terraform-ebs-practical/

We should build this incrementally:

Phase 1 — Architecture and prerequisites

Understand:

EBS volume

Availability Zone limitation

EC2 attachment

Device name versus Linux device name

Filesystem

Mount point

Snapshot

Important point:

An EBS volume must be attached to an EC2 instance in the same Availability Zone.

Phase 2 — Create EBS volume with Terraform

Initially create only the volume:

resource "aws_ebs_volume" "data" {
  availability_zone = var.availability_zone
  size              = 10
  type              = "gp3"

  tags = {
    Name = "terraform-ebs-data"
  }
}

We should understand every parameter before continuing.

Phase 3 — Attach the volume

Attach it to an existing or lab-created EC2 instance:

resource "aws_volume_attachment" "data" {
  device_name = "/dev/sdf"
  volume_id   = aws_ebs_volume.data.id
  instance_id = aws_instance.web.id
}

However, we should first decide whether to:

Create a small EC2 instance in this lab, or

Attach the volume to an existing temporary EC2 instance.

For a clean and reproducible lab, I recommend creating the EC2 instance within the same Terraform lab, then destroying everything together.

Phase 4 — Verify from EC2

After SSH access:

lsblk

Then inspect filesystem information:

sudo fdisk -l

The attached volume may appear as something such as:

/dev/nvme1n1

Even though Terraform used:

/dev/sdf

This is normal on Nitro-based EC2 instances because AWS may expose the device as an NVMe device inside Linux.

Phase 5 — Format and mount

Example commands:

sudo mkfs -t ext4 /dev/nvme1n1

Create a mount point:

sudo mkdir -p /data

Mount it:

sudo mount /dev/nvme1n1 /data

Verify:

df -h
mount | grep /data

Then write test data:

echo "EBS persistence test" | sudo tee /data/test.txt
cat /data/test.txt

Safety note: mkfs destroys any existing filesystem on the selected device. We must verify the device carefully before running it.

Phase 6 — Persistence verification

We can verify persistence by:

Unmounting and mounting again.

Confirming the file remains.

Optionally stopping and starting the EC2 instance.

Confirming that the EBS volume and data remain.

Example:

sudo umount /data
sudo mount /dev/nvme1n1 /data
cat /data/test.txt

The key concept:

Instance store is ephemeral.

EBS is persistent block storage independent of the EC2 instance lifecycle, provided the volume is retained and not deleted.

Phase 7 — Snapshot understanding

We should understand and inspect snapshot creation, preferably through Terraform or AWS CLI.

Conceptually:

EBS Volume
   ↓
Snapshot
   ↓
New EBS Volume
   ↓
Attach to another EC2 instance

We should also understand:

Snapshot is a point-in-time backup.

Snapshot is regional.

A snapshot can be used to create another EBS volume.

Snapshot storage and EBS volume storage have separate costs.

Creating a snapshot does not mean the volume is automatically restored or replaced.

Phase 8 — Safe destruction

Before destruction:

df -h
lsblk

Unmount:

sudo umount /data

Then from the Terraform directory:

terraform plan
terraform destroy

We should confirm whether the volume has:

delete_on_termination = false

or whether the Terraform-managed attachment and volume will be destroyed together.

For this lab, the goal is to avoid leaving billable resources behind.

Phase 9 — Documentation

After completion, document:

terraform-ebs-practical/
├── main.tf
├── variables.tf
├── provider.tf
├── terraform.tfvars.example
├── outputs.tf
└── README.md

And update the notes under:

labs/terraform-modules/

or create a dedicated note such as:

AWS_EBS_Practical_Lab.md

Then:

git status
git add .
git commit -m "Add EBS practical lab"
git push
Correct next-step order

Our immediate roadmap should therefore be:

EBS practical completion
   ↓
Review/document EBS
   ↓
EKS application deployment
   ↓
Kubernetes application fundamentals
   ↓
Service and external exposure
   ↓
Helm
   ↓
HPA and application scaling
   ↓
CloudWatch / observability
   ↓
AI application deployment
   ↓
AI-agent deployment

=================================================================

EBS Lab — Phase 1: Minimal Terraform Configuration

For this lab, we will use:

A dedicated Terraform directory.

An existing VPC and subnet selected automatically through data sources.

A new EC2 instance.

A new EBS volume.

Terraform attachment between the EBS volume and EC2.

We will not create a new VPC for this small lab. We will automatically select your existing VPC rather than asking you to manually provide a VPC ID in terraform.tfvars.

However, we should select the VPC carefully. Since you may have multiple VPCs in the future, we will initially use the default VPC, because it is suitable for this isolated learning lab and avoids creating unnecessary networking resources.

Step 1: Create the initial files

Run:

touch provider.tf variables.tf terraform.tfvars data.tf

Check:

ls -l
Step 2: Create provider.tf

Open the file:

nano provider.tf

Add:

terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

Save the file.

Why this configuration?

Parameter
Purpose
required_version
Defines the minimum Terraform version
required_providers
Declares the AWS provider
source
Uses the official HashiCorp AWS provider
version
Keeps the provider within the 6.x major version
region
Gets the AWS region from a variable

Step 3: Create variables.tf

Run:

nano variables.tf

Add:

variable "aws_region" {
  description = "AWS region for the EBS lab"
  type        = string
  default     = "us-east-1"
}

variable "ami_id" {
  description = "AMI ID for the EC2 instance"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.small"
}

variable "key_name" {
  description = "Existing EC2 key pair name"
  type        = string
}
Step 4: Create terraform.tfvars

Run:

nano terraform.tfvars

Add your existing values:

aws_region    = "us-east-1"
ami_id        = "ami-0db1c5c6dc64eb019"
instance_type = "t3.small"
key_name      = "my-key1"

Note
The AMI ID must be valid in us-east-1. If this AMI becomes unavailable or is not suitable for the current account, we will replace it with a valid Amazon Linux AMI using a data source.

Step 5: Initialize Terraform

Run:
terraform init
Then:
terraform fmt
Then:
terraform validate

At this stage, validation should succeed because the provider and variables are now defined.

Expected result
Success! The configuration is valid.

Do not run terraform apply yet. We have not created any resources.

Send me the output of:
terraform init
terraform validate

===================================================================

Phase 2 — Automatically Select VPC and Subnet

We will not provide a VPC ID or VPC name in terraform.tfvars.

For this lab, Terraform will automatically discover the default VPC and one of its subnets using AWS data sources.

Why use a data source?

A Terraform resource creates infrastructure:

resource "aws_vpc" "main" {
  ...
}

A data source discovers existing infrastructure:

data "aws_vpc" "default" {
  default = true
}

So:

Existing AWS VPC
       ↓
Terraform data source
       ↓
VPC ID
       ↓
EC2 / EBS resources

For a small EBS lab, this avoids creating another VPC and avoids unnecessary cleanup.

Step 1: Create data.tf

Run:

nano data.tf

Add:

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

data "aws_subnet" "selected" {
  id = data.aws_subnets.default.ids[0]
}

Explanation
1. Discover the default VPC
data "aws_vpc" "default" {
  default = true
}

Terraform asks AWS:

Give me the account's default VPC.
We can then reference its ID:
data.aws_vpc.default.id

2. Discover subnets belonging to that VPC
data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

This returns a list of subnet IDs.

3. Select one subnet
data "aws_subnet" "selected" {
  id = data.aws_subnets.default.ids[0]
}

The [0] means:

Select the first subnet from the discovered subnet list.

For this lab, one subnet is sufficient because we are learning EBS attachment, not high availability.

Step 2: Add outputs for discovery

Create outputs.tf:

nano outputs.tf

Add:

output "vpc_id" {
  description = "Selected default VPC ID"
  value       = data.aws_vpc.default.id
}

output "subnet_id" {
  description = "Selected subnet ID"
  value       = data.aws_subnet.selected.id
}

output "availability_zone" {
  description = "Availability Zone of the selected subnet"
  value       = data.aws_subnet.selected.availability_zone
}

Why output the Availability Zone?

This is particularly important for EBS.

An EBS volume is Availability Zone-specific.

For example:

EC2 → us-east-1a
EBS → us-east-1a

is valid.

But:

EC2 → us-east-1a
EBS → us-east-1b

is not directly attachable.

Therefore, we must ensure that the EBS volume is created in the same Availability Zone as the EC2 instance.

Step 3: Format and validate

Run:
terraform fmt
Then:
terraform validate
Then:
terraform plan

At this stage, because we have only data sources and outputs, Terraform should show no resources to create.

You may see output values as:

vpc_id
subnet_id
availability_zone

Do not run apply yet.

Send me the output of:
terraform validate
terraform plan

After that, we will create Phase 3: EC2 instance, ensuring it uses the automatically selected subnet and Availability Zone.

=====================================================

Excellent. The data-source discovery worked successfully.

What Terraform discovered

Item
Value
VPC ID
vpc-0dc7156d13d263648
Selected subnet
subnet-0d31b4f8ad97a7713
Availability Zone
us-east-1e

Your output confirms:

data.aws_vpc.default       → Read complete
data.aws_subnets.default   → Read complete
data.aws_subnet.selected   → Read complete

And importantly:

Plan: no resources to create

Only output values changed because data sources discover existing infrastructure; they do not create it.

Important observation

The selected subnet is in:

us-east-1e

That means our EC2 instance and EBS volume must both be placed in us-east-1e.

Remember:

EBS volume AZ = EC2 instance AZ

Otherwise, AWS will reject the attachment.

Phase 3 — Create the EC2 Instance

Now we will create only the EC2 instance. We will not create the EBS volume yet.

This follows our lab method:

Learn → Code → Validate → Plan → Apply → Verify

Step 1: Create compute.tf

Run:
nano compute.tf

Add:

resource "aws_instance" "web" {
  ami                         = var.ami_id
  instance_type               = var.instance_type
  key_name                    = var.key_name
  subnet_id                   = data.aws_subnet.selected.id
  associate_public_ip_address = true

  vpc_security_group_ids = [aws_security_group.web.id]

  tags = {
    Name = "terraform-ebs-lab-ec2"
  }
}

Explanation
Parameter
Purpose
ami
Operating system image
instance_type
EC2 capacity, currently t3.small
key_name
Existing EC2 key pair
subnet_id
Places EC2 in the discovered subnet
associate_public_ip_address
Allows public access for this learning lab
vpc_security_group_ids
Applies the EC2 security group
tags
Gives the instance a recognizable name

Important dependency
This line:

vpc_security_group_ids = [aws_security_group.web.id]

assumes that security_groups.tf already exists in this new lab.

At the moment, we have not created that security group in terraform-ebs. Therefore, before validation, we need to create a minimal security group.

Phase 3A — Create the EC2 Security Group

Create:

nano security_groups.tf

Add:

resource "aws_security_group" "web" {
  name        = "terraform-ebs-web-sg"
  description = "Allow SSH and HTTP for EBS learning lab"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "SSH from administrator"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP for web verification"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "terraform-ebs-web-sg"
  }
}

Security note
For a temporary learning lab, this is acceptable, but in production:

SSH should be restricted to your public IP.
HTTP should only be open when required.
Prefer AWS Systems Manager Session Manager over public SSH where possible.

Step 2: Add EC2 outputs

Create or edit outputs.tf:

nano outputs.tf

Keep the existing VPC outputs and add:

output "instance_id" {
  description = "EC2 instance ID"
  value       = aws_instance.web.id
}

output "instance_private_ip" {
  description = "Private IP address of the EC2 instance"
  value       = aws_instance.web.private_ip
}

output "instance_public_ip" {
  description = "Public IP address of the EC2 instance"
  value       = aws_instance.web.public_ip
}

output "instance_availability_zone" {
  description = "Availability Zone of the EC2 instance"
  value       = aws_instance.web.availability_zone
}

Your complete outputs.tf should contain:

output "vpc_id" {
  description = "Selected default VPC ID"
  value       = data.aws_vpc.default.id
}

output "subnet_id" {
  description = "Selected subnet ID"
  value       = data.aws_subnet.selected.id
}

output "availability_zone" {
  description = "Availability Zone of the selected subnet"
  value       = data.aws_subnet.selected.availability_zone
}

output "instance_id" {
  description = "EC2 instance ID"
  value       = aws_instance.web.id
}

output "instance_private_ip" {
  description = "Private IP address of the EC2 instance"
  value       = aws_instance.web.private_ip
}

output "instance_public_ip" {
  description = "Public IP address of the EC2 instance"
  value       = aws_instance.web.public_ip
}

output "instance_availability_zone" {
  description = "Availability Zone of the EC2 instance"
  value       = aws_instance.web.availability_zone
}

Step 3: Format and validate

Run:
terraform fmt
Then:
terraform validate
Then inspect the plan:
terraform plan

Expected plan will include approximately:

aws_security_group.web
aws_instance.web

The data sources will only be read.

You should see something similar to:

Plan: 2 to add, 0 to change, 0 to destroy.

Do not apply yet. First send me the output of:

terraform validate
terraform plan

===============================================

Phase 4 — Apply EC2 Infrastructure

Run:

terraform apply

Terraform will display the plan again and ask:

Do you want to perform these actions?
  Enter a value:

Enter:

yes

Wait until you see something similar to:

Apply complete! Resources: 2 added, 0 changed, 0 destroyed.

Then verify the Terraform outputs:

terraform output

Also check the EC2 state directly through AWS:

aws ec2 describe-instances \
  --region us-east-1 \
  --filters "Name=tag:Name,Values=terraform-ebs-lab-ec2" \
  --query 'Reservations[*].Instances[*].[InstanceId,State.Name,InstanceType,Placement.AvailabilityZone,PrivateIpAddress,PublicIpAddress]' \
  --output table

Expected result should show one instance:

running
t3.small
us-east-1e

The actual instance ID and IP addresses will be assigned by AWS.

Do not create or attach EBS yet

First, send me:

The terraform apply result.

The terraform output result.

The EC2 verification table.

Then we will create the EBS volume in the same us-east-1e Availability Zone and attach it to this instance.

=============================================

Excellent. The EC2 instance was successfully created in us-east-1a, resolving yesterday’s Availability Zone issue.

Your current outputs confirm:

Resource
Value
VPC
vpc-0dc7156d13d263648
Subnet
subnet-01c106a6ea27f27bb
Availability Zone
us-east-1a
Instance ID
i-0fb647e497d4cd17e
Private IP
172.31.7.177
Public IP
32.195.72.22
Now we continue the EBS practical lab. We will not create another EC2 instance.

Step 1 — Verify Terraform resources

Run:

terraform state list

Expected resources should include something similar to:

aws_instance.web
aws_ebs_volume.data
aws_volume_attachment.data

The exact EBS resource names depend on your configuration.

Then check the EC2 instance:

aws ec2 describe-instances \
  --region us-east-1 \
  --instance-ids i-0fb647e497d4cd17e \
  --query 'Reservations[0].Instances[0].[InstanceId,State.Name,Placement.AvailabilityZone,PrivateIpAddress,PublicIpAddress]' \
  --output table

Expected state:

running
Step 2 — Verify the EBS volume from AWS

First identify the attached volumes:

aws ec2 describe-instances \
  --region us-east-1 \
  --instance-ids i-0fb647e497d4cd17e \
  --query 'Reservations[0].Instances[0].BlockDeviceMappings[*].[Device,Ebs.VolumeId,Ebs.Status]' \
  --output table

You should see the root volume and the additional EBS volume.

Then inspect the EBS volume details. Replace vol-xxxxxxxx with the additional volume ID:

aws ec2 describe-volumes \
  --region us-east-1 \
  --volume-ids vol-xxxxxxxx \
  --query 'Volumes[0].[VolumeId,Size,VolumeType,State,AvailabilityZone,Attachments[0].InstanceId]' \
  --output table

We want to confirm:

Volume state: in-use

Volume type: likely gp3

Availability Zone: us-east-1a

Attached instance: i-0fb647e497d4cd17e

Important: EBS volumes are Availability-Zone specific. The volume and EC2 instance must be in the same AZ. Your current instance is in us-east-1a, so the volume should also be in us-east-1a.

Step 3 — Connect to the EC2 instance

Use your existing key pair:

ssh -i ~/.ssh/my-key1.pem ec2-user@32.195.72.22

If your key is stored elsewhere, use that actual path.

Once connected, run:

lsblk

Expected output will resemble:

NAME        MAJ:MIN RM  SIZE RO TYPE MOUNTPOINTS
nvme0n1     259:0    0    8G  0 disk
├─nvme0n1p1 259:1    0    8G  0 part /
└─...
nvme1n1     259:2    0    5G  0 disk

The names may differ. On modern Nitro-based EC2 instances, an EBS volume configured as /dev/sdf in Terraform often appears inside Linux as something like:

/dev/nvme1n1

Do not format the root disk. We need to identify the new, unmounted disk before formatting it.

Run these additional commands:

lsblk -f
df -h
sudo file -s /dev/nvme1n1

Replace /dev/nvme1n1 only if lsblk shows that your additional disk has a different device name.

What we are checking

Check
Purpose

lsblk
Detect disks and partitions
lsblk -f
Check filesystem type and UUID
df -h
Check currently mounted filesystems
file -s
Determine whether the disk is empty or already formatted

For now, run Steps 1 and 2 from your WSL terminal, then SSH into the instance and run lsblk and lsblk -f. Share the output before formatting anything.

========================================
What the Terraform state proves

Your state contains only:

data.aws_subnet.selected
data.aws_subnets.default
data.aws_vpc.default
aws_instance.web
aws_security_group.web

There is no EBS volume resource and no volume attachment resource.

Your compute.tf also contains only:

resource "aws_instance" "web" {
  ...
}

Therefore, the earlier AWS volume:

vol-0230671703b135c36

was actually the EC2 root EBS volume, not a separate data volume.

That explains everything:

nvme0n1 → 8 GiB root disk → /

There is no second disk because we have not yet created one.

Important correction to our earlier interpretation

The output:

Apply complete! Resources: 2 added

means Terraform created:

EC2 instance

Security group

It did not create a separate EBS data volume.

The root disk is automatically created by EC2 from the AMI. It is not the EBS practical resource we intended to study.

Now we will add the actual EBS resources

We will keep the existing EC2 instance and add:

aws_ebs_volume

aws_volume_attachment

The new EBS volume must be in the same Availability Zone as the EC2 instance.

Your instance is in:

us-east-1a

We should avoid hardcoding the AZ again. We can derive it from the selected subnet.

Step 1 — Add ebs.tf

From your current directory:

~/aws-terraform-learning/labs/terraform-ebs

Create the file:

touch ebs.tf

Open it in VS Code:

code ebs.tf

Add:

resource "aws_ebs_volume" "data" {
  availability_zone = data.aws_subnet.selected.availability_zone
  size              = 5
  type              = "gp3"

  tags = {
    Name = "terraform-ebs-data"
  }
}

resource "aws_volume_attachment" "data" {
  device_name = "/dev/sdf"
  volume_id   = aws_ebs_volume.data.id
  instance_id = aws_instance.web.id
}

Understand the configuration
aws_ebs_volume.data
availability_zone = data.aws_subnet.selected.availability_zone

This dynamically selects the AZ of the subnet where the EC2 instance is deployed.

Current result:

us-east-1a
This avoids manually entering:
availability_zone = "us-east-1a"

The volume must be created in the same AZ as the EC2 instance.
size = 5
Creates a 5 GiB data volume.
type = "gp3"
Uses the general-purpose SSD volume type.

aws_volume_attachment.data
device_name = "/dev/sdf"

This is the device name requested from EC2. On Nitro instances, Linux may expose it as:

/dev/nvme1n1

or another NVMe name.

volume_id = aws_ebs_volume.data.id

Attaches the newly created EBS volume.

instance_id = aws_instance.web.id

Attaches it to the EC2 instance Terraform already manages.

Step 2 — Format and validate

Run:

terraform fmt

Then:

terraform validate

Expected:

Success! The configuration is valid.

Then inspect the plan:

terraform plan

Expected new resources:

aws_ebs_volume.data
aws_volume_attachment.data

The plan should show approximately:

Plan: 2 to add, 0 to change, 0 to destroy.

===================================================

The AZ is correct:

aws_ebs_volume.data
availability_zone = "us-east-1a"

The attachment points to the correct instance:

instance_id = "i-0865a73994a8dd43d"

Therefore, it is safe to proceed with the EBS creation and attachment.

Step 1 — Apply

Run:

terraform apply

Review the plan again and type:

yes

Wait for:

Apply complete! Resources: 2 added, 0 changed, 0 destroyed.
Step 2 — Verify from AWS

After apply, run:

terraform state list

Expected additional resources:

aws_ebs_volume.data
aws_volume_attachment.data

Then obtain the volume ID from Terraform:

terraform output

Or directly query the volume by its Name tag:

aws ec2 describe-volumes \
  --region us-east-1 \
  --filters "Name=tag:Name,Values=terraform-ebs-data" \
  --query 'Volumes[*].[VolumeId,Size,VolumeType,State,AvailabilityZone,Attachments[0].InstanceId]' \
  --output table

Expected result:

5 | gp3 | in-use | us-east-1a | i-0865a73994a8dd43d

Step 3 — Verify inside EC2

SSH to the current instance:

ssh -i /actual/path/to/your-key.pem ec2-user@32.195.65.109

Then run:

lsblk

This time, we expect a second disk, possibly similar to:

nvme0n1       8G disk
└─nvme0n1p1   8G part /
nvme1n1       5G disk

Then run:

lsblk -f

The new 5 GiB disk should normally have no filesystem yet.

================================================

Next step: Format and mount the EBS volume

Important: We have verified that /dev/nvme1n1 is the new, empty 5-GiB volume. We should format only that device—not /dev/nvme0n1, because /dev/nvme0n1 contains the root filesystem.

Reconnect to the instance:

ssh -i ~/.ssh/my-key1.pem ec2-user@32.195.65.109

Then verify once more:

lsblk
1. Check whether the volume contains an existing filesystem

Run:

sudo file -s /dev/nvme1n1

Expected output for a new empty volume will be similar to:

/dev/nvme1n1: data

If it reports an existing filesystem, do not format it. In our current lab, it should be empty because this is a newly created volume.

2. Format the volume with XFS

Amazon Linux commonly uses XFS, so we will use XFS for this lab:

sudo mkfs -t xfs /dev/nvme1n1

You should see output indicating that an XFS filesystem was created.

What this does

Before formatting:

EBS volume
   ↓
Raw block device

After formatting:

EBS volume
   ↓
XFS filesystem

Formatting creates the filesystem structure, but the volume is not mounted yet.

3. Create a mount directory
sudo mkdir -p /data

4. Mount the EBS volume
sudo mount /dev/nvme1n1 /data

Verify:

df -h

You should see an entry similar to:

/dev/nvme1n1    5.0G   ...   ...   ...   /data

Also verify:

lsblk -f

Expected conceptual result:

nvme1n1   xfs   <UUID>   /data

5. Test that the mounted volume is usable

Create a test file:

echo "EBS persistence test" | sudo tee /data/test.txt

Read it:

cat /data/test.txt

Expected:

EBS persistence test

Check disk usage:

df -h /data
6. Verify the filesystem UUID

Run:

sudo blkid /dev/nvme1n1

Example output:

/dev/nvme1n1: UUID="..." TYPE="xfs"

Record the UUID for understanding. We are not yet making the mount persistent across reboot unless we explicitly configure /etc/fstab.

What we have learned so far
Terraform
   │
   ├── aws_instance.web
   │
   ├── aws_ebs_volume.data
   │
   └── aws_volume_attachment.data
             │
             ▼
       EC2 instance
             │
             ▼
       /dev/nvme1n1
             │
             ▼
       XFS filesystem
             │
             ▼
          /data

And the important distinction is:

Layer
Responsibility
EBS volume
Provides persistent block storage
Volume attachment
Connects the volume to EC2
Linux device
Exposes the volume to the OS
Filesystem
Organizes data, e.g. XFS
Mount point
Makes the filesystem accessible at /data

Your immediate task

Reconnect to EC2 and run these commands one at a time:

sudo file -s /dev/nvme1n1

Then, assuming it reports data:

sudo mkfs -t xfs /dev/nvme1n1

Send me the output of file -s first. We will validate it before formatting.

===============================================

Good. The formatting succeeded, and the output confirms that /dev/nvme1n1 was formatted with XFS.

What happened

You first ran:

sudo file -s /dev/nvme1n

That failed because the device name was incomplete:

/dev/nvme1n

The correct device is:

/dev/nvme1n1

Then you correctly ran:

sudo mkfs -t xfs /dev/nvme1n1

The successful output confirms:

Device: /dev/nvme1n1

Filesystem: xfs

Block size: 4096

Filesystem creation completed successfully

Important: Formatting creates the filesystem but does not mount it.

Next step: Create the mount point

Run:

sudo mkdir -p /data

Then mount the EBS volume:

sudo mount /dev/nvme1n1 /data

Verify the mount:

lsblk -f

and:

df -h /data

You should see /dev/nvme1n1 mounted at /data.

For example, conceptually:

nvme1n1   xfs   <UUID>   /data

Then test writing data:

echo "EBS persistence test" | sudo tee /data/test.txt

Read it back:

cat /data/test.txt

Expected:

EBS persistence test

Run the mount and verification commands, then send the output of:

lsblk -f
df -h /data
cat /data/test.txt

=====================================
Next practical: Persistence verification

We should now verify what persistence means.

There are two different concepts:
Type
Meaning
Mount persistence
The volume automatically mounts after reboot
Data persistence

Data remains on the EBS volume when the EC2 instance stops/starts or is replaced, provided the volume itself is retained

Our current setup has data persistence, but /data is not yet configured for automatic mounting after reboot.

For this short lab, we can demonstrate persistence by checking the UUID and then optionally configuring /etc/fstab.

Step 1: Confirm the UUID

Run:
sudo blkid /dev/nvme1n1

You should see the UUID already shown by lsblk -f:

ff144803-9972-44dc-bcdf-a647688bb2981
Step 2: Understand the /etc/fstab entry

A persistent mount entry would look like this:

UUID=ff144803-9972-44dc-bcdf-a647688bb2981 /data xfs defaults,nofail 0 2

Meaning:

Field
Meaning
UUID
Identifies the filesystem
/data
Mount point
xfs
Filesystem type
defaults,nofail
Standard mount options; do not block boot if volume is unavailable
0
Dump setting
2
Filesystem check order

However, do not add this yet unless we want to test reboot persistence. We can keep the lab simple and avoid unnecessary reboot risk.

Next required step: Snapshot concept and creation

Before destroying the lab, we should understand and create an EBS snapshot.

A snapshot is a point-in-time backup of an EBS volume.

EBS Volume
   │
   ▼
EBS Snapshot

The snapshot is stored independently of the running EC2 instance and can later be used to create another EBS volume.

First, exit the EC2 session if you are still connected:

exit

Then identify the volume:

aws ec2 describe-volumes \
  --region us-east-1 \
  --filters "Name=tag:Name,Values=terraform-ebs-data" \
  --query 'Volumes[*].[VolumeId,Size,VolumeType,State,AvailabilityZone]' \
  --output table

Create a snapshot:

aws ec2 create-snapshot \
  --region us-east-1 \
  --volume-id vol-049c875e1f1d20dbe \
  --description "Terraform EBS lab snapshot"

The command will return a SnapshotId.

Then check its state:

aws ec2 describe-snapshots \
  --region us-east-1 \
  --filters "Name=volume-id,Values=vol-049c875e1f1d20dbe" \
  --query 'Snapshots[*].[SnapshotId,VolumeId,State,Progress,StartTime,Description]' \
  --output table

Expected initial state may be:

pending

Later it should become:

completed
Important distinction

Our Terraform resource currently has:

resource "aws_ebs_volume" "data" {
  size              = 5
  availability_zone = var.availability_zone
  type              = "gp3"

  tags = {
    Name = "terraform-ebs-data"
  }
}

And:

resource "aws_volume_attachment" "data" {
  device_name = "/dev/sdf"
  volume_id   = aws_ebs_volume.data.id
  instance_id = aws_instance.web.id
}

Terraform manages the volume and attachment, but the manually created snapshot is not automatically managed by Terraform unless we add an aws_ebs_snapshot resource.

For this lab, manual snapshot creation is useful because it lets us understand the AWS operation separately.

==============================

Excellent. The snapshot was created successfully.

Snapshot verification
Snapshot details

Property
Value
Snapshot ID
snap-050d7ef424d36040b
Source volume
vol-049c875e1f1d20dbe
Size
5 GiB
Initial state
pending
Progress
0%
Description
Terraform EBS lab snapshot
Encryption
Not encrypted

Your command confirms:

SnapshotId: snap-050d7ef424d36040b
State: pending
Progress: 0%
What pending means

The snapshot request has been accepted, but AWS is still processing the snapshot.

The source volume remains usable while the snapshot is being created.

The lifecycle is:

EBS volume
   │
   ▼
Create snapshot
   │
   ▼
pending
   │
   ▼
completed

We do not need to wait for 100% before continuing with the conceptual lesson, but we should verify its final state before cleanup.

Important snapshot concept

An EBS snapshot is not another attached disk.

EBS Volume
   │
   └── Snapshot
          │
          └── Can create a new EBS volume later

A snapshot can be used to restore data by creating a new volume from it.

Also note:

The snapshot is currently unencrypted, as shown by "Encrypted": false.

The snapshot was created manually using the AWS CLI.

Terraform does not currently manage this snapshot.

If we destroy the Terraform lab, the manually created snapshot will generally remain unless we explicitly delete it.

Next step: Verify snapshot completion

Run:

aws ec2 describe-snapshots \
  --region us-east-1 \
  --snapshot-ids snap-050d7ef424d36040b \
  --query 'Snapshots[0].[SnapshotId,VolumeId,State,Progress,VolumeSize,Encrypted,Description]' \
  --output table

If the result is:

completed
100%

the snapshot is ready.

If it still says pending, wait briefly and run the same command again.

Before destroying the lab

We should record the current resources:

terraform state list

Expected Terraform-managed resources should include:

data.aws_subnet.selected
data.aws_subnets.default
data.aws_vpc.default
aws_ebs_volume.data
aws_instance.web
aws_security_group.web
aws_volume_attachment.data

The exact list may vary slightly depending on your configuration.

Then verify the snapshot separately:

aws ec2 describe-snapshots \
  --region us-east-1 \
  --snapshot-ids snap-050d7ef424d36040b \
  --query 'Snapshots[0].[SnapshotId,State,Progress]' \
  --output table
Cleanup decision

For this lab, we should:

Verify the snapshot reaches completed.

Run terraform destroy.

Confirm the EC2 instance is terminated.

Confirm the EBS data volume is deleted.

Confirm the snapshot still exists.

Delete the snapshot manually to avoid ongoing storage charges.

Confirm no lab resources remain.

Important distinction
terraform destroy
       │
       ├── Deletes Terraform-managed EC2
       ├── Deletes Terraform-managed EBS volume
       ├── Deletes volume attachment
       └── Does not delete manually-created snapshot

Do not delete the snapshot until we have verified that it completed successfully.

=============================================

Cleanup plan

Because the snapshot is now complete, we can safely proceed toward cleanup.

Step 1: Inspect Terraform configuration

Run:

grep -R "volume_attachment\|ebs_volume" -n --include="*.tf" .
Step 2: Review the destroy plan

Run:

terraform plan -destroy

We want to confirm that Terraform plans to remove only the lab resources, such as:

EC2 instance

EBS volume

Security group

The manually created snapshot should not appear in Terraform's destroy plan because it was created using the AWS CLI and is not managed by Terraform.

Step 3: Destroy Terraform resources

After reviewing the plan:

terraform destroy

Type:

yes
Step 4: Confirm the snapshot remains

After destruction:

aws ec2 describe-snapshots \
  --region us-east-1 \
  --snapshot-ids snap-050d7ef424d36040b \
  --query 'Snapshots[0].[SnapshotId,State,Progress,VolumeId]' \
  --output table

The snapshot should still exist because it was created manually.

Step 5: Delete the snapshot

Once we confirm that the EC2 instance and EBS volume are deleted, remove the snapshot to avoid continued snapshot-storage charges:

aws ec2 delete-snapshot \
  --region us-east-1 \
  --snapshot-id snap-050d7ef424d36040b

Then verify:

aws ec2 describe-snapshots \
  --region us-east-1 \
  --snapshot-ids snap-050d7ef424d36040b

AWS should return a SnapshotNotFound-type error, confirming deletion.

EBS lab completion status
Create EC2 using Terraform
Create EBS volume using Terraform
Attach volume to EC2
Verify device using lsblk
Format volume with XFS
Mount volume at /data
Write and read test data
Create EBS snapshot
Verify snapshot completed at 100%
Inspect current Terraform attachment ownership
Destroy Terraform resources
Verify cleanup
Delete manual snapshot
Document and push EBS notes

=================================================================
