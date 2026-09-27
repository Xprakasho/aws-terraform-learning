Good. Let's start with EBS closure and do it one concept at a time.

We already completed the practical flow:

EBS Volume
   ↓
EC2 block device
   ↓
Filesystem (XFS)
   ↓
Mount point (/data)
   ↓
Application data

We also created and verified an EBS snapshot.

EBS — what remains

I want to cover only the pieces that matter for production-level understanding:

EBS encryption + KMS
Snapshot → new EBS volume → restore
Backup/restore architecture
EBS performance: IOPS vs throughput
delete_on_termination and lifecycle
Production design checklist
Then a short EBS interview/troubleshooting checkpoint

We won't repeat the basic volume/attach/format/mount lab.

Step 1 — EBS encryption

The important architecture is:

EC2
 │
 └── EBS Volume
       │
       ├── Data
       │
       └── Encryption
             │
             └── AWS KMS key

There are two important concepts:

Encryption at rest
The data stored on the EBS volume is encrypted.

KMS
AWS KMS manages the cryptographic key used for encryption.

For a production Terraform resource, we'd typically see something like:

resource "aws_ebs_volume" "data" {
  availability_zone = "us-east-1a"
  size              = 20
  type              = "gp3"

  encrypted = true

  tags = {
    Name = "application-data"
  }
}

If you use the AWS-managed EBS key, you don't necessarily need to specify a KMS key yourself.

For explicit customer-managed-key control:

resource "aws_ebs_volume" "data" {
  availability_zone = "us-east-1a"
  size              = 20
  type              = "gp3"

  encrypted  = true
  kms_key_id = aws_kms_key.ebs.arn
}

The key architectural distinction is:

EBS encryption
      │
      └── protects data at rest

KMS
      │
      └── manages the encryption key

And importantly, encryption doesn't change the fundamental EBS model:

Application
    ↓
Filesystem
    ↓
Block device
    ↓
Encrypted EBS volume
    ↓
AWS storage infrastructure
One thing to understand before we touch Terraform

There are three different concepts that are easy to mix up:

Concept	Purpose
EBS encryption	Protect data at rest
KMS key	Controls the cryptographic key
EBS snapshot	Point-in-time backup/copy mechanism

So:

Encryption ≠ backup.

An encrypted EBS volume is still not a backup strategy.

Next, we'll take the snapshot we already created conceptually and walk through Snapshot → Restore → New Volume → Attach → Verify, because that completes the EBS lifecycle

=============================================================================

1. The architecture we want to understand

We already have:

EC2
 │
 └── EBS Volume
       │
       └── /data
            └── test.txt

A snapshot gives us a point-in-time copy:

EBS Volume
     │
     └── Snapshot
            │
            └── New EBS Volume
                    │
                    └── EC2
                         │
                         └── /restore

The key idea is:

You don't normally "restore a snapshot onto" the existing volume. You create a new EBS volume from the snapshot, then attach that new volume to an EC2 instance.

This is an important operational distinction.

2. Our previous snapshot

From our previous EBS lab, we created:

Snapshot:
snap-050d7ef424d36040b

and it was based on the 5-GiB data volume.

Before doing anything, let's verify that the snapshot still exists:

aws ec2 describe-snapshots \
  --region us-east-1 \
  --snapshot-ids snap-050d7ef424d36040b \
  --query 'Snapshots[0].[SnapshotId,State,Progress,VolumeId,VolumeSize,Encrypted]' \
  --output table

We expect something conceptually like:

------------------------------------------------
| SnapshotId | State     | Progress | Encrypted |
------------------------------------------------
| snap-...   | completed | 100%     | False     |
------------------------------------------------
3. Before we run restore

There are two different restore scenarios we should understand:

Scenario A — accidental data loss

Original Volume
       ↓
     Data
       ↓
   Snapshot
       ↓
Original volume/data damaged
       ↓
Create new volume from snapshot
       ↓
Attach new volume
       ↓
Recover data

Scenario B — disaster recovery

Production EBS
      ↓
Periodic snapshots
      ↓
Snapshot stored independently
      ↓
Failure
      ↓
Create replacement EBS
      ↓
Attach to replacement EC2
      ↓
Application recovery

This is why snapshots are an important part of the backup and recovery strategy.

4. One important limitation

An EBS volume is Availability Zone scoped.

For example:

Snapshot
   │
   ├── can be used to create volume in us-east-1a
   ├── can be used to create volume in us-east-1b
   └── can be used to create volume in us-east-1c

The snapshot itself isn't tied to the original volume's AZ in the same way an EBS volume is.

So:

EBS Volume → AZ specific

Snapshot → can be used to create a new volume in another AZ

That's an important difference.

Our practical exercise

We'll now do this carefully:

1. Verify snapshot
        ↓
2. Create NEW EBS volume from snapshot
        ↓
3. Attach it to EC2
        ↓
4. lsblk
        ↓
5. Identify filesystem
        ↓
6. Mount it
        ↓
7. Verify test.txt
        ↓
8. Understand what actually happened
        ↓
9. Clean up
==============================================================

Yes. We can reuse this exact EBS lab. In fact, that's better than creating another lab.

Your current plan is clean:

Plan: 4 to add, 0 to change, 0 to destroy

It will create:

EC2
 ├── Root EBS
 └── 5 GiB gp3 EBS
       │
       └── volume_attachment

The important thing is that your current aws_ebs_volume.data is a fresh volume. We can use it to demonstrate the complete lifecycle again.

What I suggest

Let's proceed in this order:

CURRENT PLAN
    ↓
terraform apply
    ↓
EC2 + 5 GiB EBS
    ↓
Verify /dev/nvme1n1
    ↓
Format XFS
    ↓
Mount /data
    ↓
Create test data
    ↓
Create EBS snapshot
    ↓
DESTROY Terraform resources
    ↓
Snapshot remains
    ↓
Create NEW EBS volume FROM snapshot
    ↓
Launch/reuse EC2
    ↓
Attach restored volume
    ↓
Mount /restore
    ↓
Verify original test data

That last part is the actual restore exercise we want.

One small change before apply

Your plan currently shows:

encrypted = (known after apply)

Let's make encryption explicit so we also close the EBS encryption topic.

In ebs.tf, use:

resource "aws_ebs_volume" "data" {
  availability_zone = "us-east-1a"
  size              = 5
  type              = "gp3"

  encrypted = true

  tags = {
    Name = "terraform-ebs-data"
  }
}

resource "aws_volume_attachment" "data" {
  device_name = "/dev/sdf"
  volume_id   = aws_ebs_volume.data.id
  instance_id = aws_instance.web.id
}

Then run:

terraform plan

We want to see:

encrypted = true

After that:

terraform apply

Don't format or mount anything yet. First we'll verify that the encrypted EBS volume was created and attached correctly. Then we'll proceed one step at a time.

================================================

Perfect. The apply was successful. Your screenshot confirms the Terraform state now contains all four managed resources:

aws_ebs_volume.data
aws_instance.web
aws_security_group.web
aws_volume_attachment.data

And both EC2 and EBS are in us-east-1a, which is exactly what we need.

Step 1 — Verify the EBS volume from AWS

Let's first confirm the volume is:

5 GiB
gp3
in-use
attached to the new EC2
encrypted

Run:

aws ec2 describe-volumes \
  --region us-east-1 \
  --filters Name=tag:Name,Values=terraform-ebs-data \
  --query 'Volumes[0].[VolumeId,Size,VolumeType,State,AvailabilityZone,Encrypted,Attachments[0].InstanceId]' \
  --output table

We should see something similar to:

---------------------------------------------------------
| VolumeId       | Size | Type | State    | AZ | Encrypted |
---------------------------------------------------------
| vol-xxxxxxxx   | 5    | gp3  | in-use   | ...| True      |
---------------------------------------------------------
What we're proving

This one command validates several things:

Terraform
   │
   ├── created EBS
   │
   ├── gp3
   │
   ├── 5 GiB
   │
   ├── us-east-1a
   │
   ├── encrypted = true
   │
   └── attached to EC2

Once we confirm that, then we'll SSH into the instance and verify the Linux block device with:

lsblk

Don't format it yet. We want to observe the raw restored/attached storage layer first, just like we did in the original lab.

=================================================================

Perfect. This is exactly what we wanted to see.

What your output proves
nvme0n1    8G  disk
└─nvme0n1p1 8G  part  /

nvme1n1    5G  disk

So:

EC2
 │
 ├── nvme0n1 → Root EBS → /
 │
 └── nvme1n1 → Data EBS → currently unformatted/unmounted

And lsblk -f confirms:

nvme0n1p1 → xfs  → /
nvme0n1p128 → vfat → /boot/efi
nvme1n1 → no filesystem

The important point is that AWS EBS encryption is transparent to Linux. We explicitly created the volume with encrypted = true, AWS reports Encrypted=True, and Linux simply sees the resulting block device.

Now let's create some data

We need data on this volume before creating the snapshot. Otherwise our restore exercise won't prove anything.

Run:

sudo mkfs -t xfs /dev/nvme1n1

Then:

sudo mkdir -p /data
sudo mount /dev/nvme1n1 /data

Verify:

df -h /data

Then create a file:

echo "EBS snapshot restore test" | sudo tee /data/restore-test.txt

Verify:

cat /data/restore-test.txt

And finally:

lsblk -f

At this point we'll have:

EBS Volume
    ↓
/dev/nvme1n1
    ↓
XFS filesystem
    ↓
/data
    ↓
restore-test.txt

Stop there. Don't create the snapshot yet. Send me the output, and we'll create the snapshot from this encrypted EBS volume and then perform the actual restore.

===========================================================

Excellent. The data-volume portion is complete and verified.

We now have a real filesystem and data:

EBS 5 GiB encrypted volume
        │
        ↓
/dev/nvme1n1
        │
        ↓
XFS filesystem
        │
        ↓
/data
        │
        ↓
restore-test.txt
        │
        └── "EBS snapshot restore test"

Your lsblk -f confirms the XFS filesystem and UUID:

nvme1n1  xfs  37cb9cd3-13df-407d-a923-7c438c6639f4  /data
Next: create the snapshot

First, from your WSL/local terminal (not the EC2 SSH session), get the volume ID:

aws ec2 describe-volumes \
  --region us-east-1 \
  --filters Name=tag:Name,Values=terraform-ebs-data \
  --query 'Volumes[0].VolumeId' \
  --output text

It should return something like:

vol-xxxxxxxxxxxxxxxxx

Then create the snapshot:

aws ec2 create-snapshot \
  --region us-east-1 \
  --volume-id <VOLUME_ID> \
  --description "EBS encrypted volume restore lab"

For example:

aws ec2 create-snapshot \
  --region us-east-1 \
  --volume-id vol-xxxxxxxxxxxxxxxxx \
  --description "EBS encrypted volume restore lab"
Then verify the snapshot

Use the snapshot ID returned by the previous command:

aws ec2 describe-snapshots \
  --region us-east-1 \
  --snapshot-ids <SNAPSHOT_ID> \
  --query 'Snapshots[0].[SnapshotId,State,Progress,VolumeSize,Encrypted,VolumeId]' \
  --output table

We want:

State       completed
Progress    100%
VolumeSize  5
Encrypted   True

Important: don't destroy the Terraform resources yet.

We'll first let the snapshot reach completed, then we'll deliberately destroy the EC2/EBS resources and use the snapshot to create a new volume, which will prove the complete recovery workflow.

================================================================

Perfect. ✅ The snapshot is now completed successfully.

We have:

Snapshot:     snap-0cf0fff3f2d081cff8
Source:       vol-05f00ee6712139b8a
Size:         5 GiB
State:        completed
Progress:     100%
Encrypted:    True

This is a useful point because we have now proven:

Encrypted EBS Volume
        │
        ↓
     Snapshot
        │
        ├── completed
        └── encrypted
Now we do the actual recovery exercise

Before destroying anything, remember:

The snapshot is NOT Terraform-managed.

Your Terraform state manages:

aws_ebs_volume.data
aws_volume_attachment.data
aws_instance.web
aws_security_group.web

The snapshot was created with AWS CLI, so it exists independently of Terraform.

Step 1 — Destroy the Terraform lab

From your current WSL terminal:

terraform destroy

Confirm with:

yes

This should remove:

EC2
Security Group
EBS volume
Volume attachment

but the snapshot should remain.

After destroy, verify:

terraform state list

We should only have the data sources:

data.aws_subnet.selected
data.aws_subnets.default
data.aws_vpc.default

Then verify that our snapshot still exists:

aws ec2 describe-snapshots \
  --region us-east-1 \
  --snapshot-ids snap-0cf0fff3f2d081cff8 \
  --query 'Snapshots[0].[SnapshotId,State,Progress,VolumeSize,Encrypted,VolumeId]' \
  --output table
Why we're doing this

This deliberately demonstrates an important production concept:

Terraform-managed infrastructure
          │
          │ terraform destroy
          ↓
       DELETED

AWS Snapshot
          │
          │ independent of Terraform
          ↓
       REMAINS

Then we'll take that surviving snapshot and create:

Snapshot
   ↓
NEW EBS Volume
   ↓
NEW EC2
   ↓
Attach
   ↓
Mount
   ↓
cat restore-test.txt

If restore-test.txt comes back, we've proven actual data recovery, not just snapshot creation.

========================================================

Perfect. The recovery setup is correct. ✅

Your output proves two important things:

Terraform destroyed all 4 managed resources

aws_volume_attachment.data
aws_ebs_volume.data
aws_instance.web
aws_security_group.web

The snapshot survived independently

Snapshot:   snap-0cf0fff3f2d081cff8
State:      completed
Progress:   100%
Size:       5 GiB
Encrypted:  True

That is exactly the behavior we wanted to demonstrate.

Now: restore the volume from the snapshot

We are going to create a new EBS volume, but this time from the snapshot.

Run:

aws ec2 create-volume \
  --region us-east-1 \
  --availability-zone us-east-1a \
  --snapshot-id snap-0cf0fff3f2d081cff8 \
  --volume-type gp3 \
  --tag-specifications 'ResourceType=volume,Tags=[{Key=Name,Value=terraform-ebs-restored}]'

You'll get a response containing something like:

VolumeId: vol-xxxxxxxxxxxxxxxxx
State:    creating
AZ:       us-east-1a
Size:     5
SnapshotId: snap-0cf0fff3f2d081cff8
Encrypted: true
Important concept

Notice what we're doing:

Original EBS
    │
    ├── 5 GiB
    ├── XFS
    └── restore-test.txt
          │
          ↓
       Snapshot
          │
          ↓
   NEW EBS VOLUME
          │
          ├── 5 GiB
          ├── encrypted
          └── contains snapshot data

The original EBS volume is gone.

The new volume is being reconstructed from the snapshot.

After creating it

Don't attach it yet.

First verify that the new volume becomes available:

aws ec2 describe-volumes \
  --region us-east-1 \
  --filters Name=tag:Name,Values=terraform-ebs-restored \
  --query 'Volumes[0].[VolumeId,State,Size,VolumeType,AvailabilityZone,Encrypted,SnapshotId]' \
  --output table

We want:

available
5
gp3
us-east-1a
True
snap-0cf0fff3f2d081cff8

Run the create-volume command first and show me the output. Then we'll create a small EC2 again and attach this restored volume.

=================================================

Perfect. This is the core restore operation successfully completed. ✅

The new volume:

Volume ID:       vol-010c648f27fe3fbd4
Size:            5 GiB
Type:            gp3
AZ:              us-east-1a
State:           available
Encrypted:       True
Source snapshot: snap-0cf0ff3f2d081cff8

And AWS also shows the KMS key used:

KmsKeyId: arn:aws:kms:...:key/5114c5d2-febc-444c-a873-aed51539385d

So our recovery chain is now:

Original EBS
    │
    │ encrypted
    ▼
Snapshot
snap-0cf0ff3f2d081cff8
    │
    │ restore
    ▼
NEW EBS
vol-010c648f27fe3fbd4
    │
    ├── 5 GiB
    ├── gp3
    ├── encrypted
    └── available
One important distinction

The volume restore is complete, but the data recovery isn't proven yet.

We still need:

New EBS
   ↓
Attach to EC2
   ↓
Linux sees block device
   ↓
Mount filesystem
   ↓
Read restore-test.txt

That last step is what proves the snapshot actually contains our original data.

Next step: create a temporary EC2

Since the original EC2 was destroyed, we need another EC2 in us-east-1a.

We can reuse your existing Terraform configuration, but do not run terraform apply yet, because that would also recreate the original EBS resource and attachment.

For this recovery test, I recommend creating only a temporary EC2 with AWS CLI. This keeps the distinction very clear:

Terraform
   └── original infrastructure → destroyed

AWS CLI
   ├── snapshot → survived
   ├── restored EBS → created
   └── temporary EC2 → create now

First, let's create the temporary EC2.

But rather than guessing your AMI/key/security-group details, use the same values from the Terraform lab that we already know worked.

Run:

terraform show

At this point the Terraform resources are destroyed, so terraform show won't give us those values.

Instead, let's inspect your existing Terraform configuration:

grep -E 'ami|key_name|instance_type|security_group' *.tf

Send me that output. Then I'll give you the exact one-command EC2 creation for the restore test.

============================================================

Good — we confirmed the Terraform configuration uses:

AMI          → var.ami_id
Instance     → var.instance_type
Key pair     → var.key_name
Security SG  → aws_security_group.web

We already know from the successful run that these were:

AMI          ami-0db1c5c6dc64eb019
Instance     t3.small
Key pair     my-key1
Subnet       subnet-01c106a6ea27f27bb
AZ           us-east-1a
VPC          vpc-0dc7156d13d263648

For this restore exercise, I don't want to bring the whole Terraform lab back. That would recreate the original EBS volume, which defeats the purpose.

We'll create a temporary EC2 + temporary security group with AWS CLI, then attach the restored volume.

Step 1 — Create temporary security group

Run:

aws ec2 create-security-group \
  --region us-east-1 \
  --group-name ebs-restore-temp-sg \
  --description "Temporary SG for EBS restore lab" \
  --vpc-id vpc-0dc7156d13d263648

It will return something like:

"GroupId": "sg-xxxxxxxxxxxxxxxxx"

Save that sg-... value.

Then add SSH access:

aws ec2 authorize-security-group-ingress \
  --region us-east-1 \
  --group-id <SG_ID> \
  --protocol tcp \
  --port 22 \
  --cidr 0.0.0.0/0

This is lab-only; in production we'd restrict SSH access rather than expose it to the internet.

Step 2 — Launch temporary EC2

Once you have the SG ID, run:

aws ec2 run-instances \
  --region us-east-1 \
  --image-id ami-0db1c5c6dc64eb019 \
  --instance-type t3.small \
  --key-name my-key1 \
  --subnet-id subnet-01c106a6ea27f27bb \
  --security-group-ids <SG_ID> \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=ebs-restore-temp}]'

Notice the critical part:

subnet → subnet-01c106a6ea27f27bb
              ↓
         us-east-1a

because our restored EBS volume is also:

vol-010c648f27fe3fbd4
        ↓
   us-east-1a

So:

Temporary EC2
   us-east-1a
       │
       │ attach
       ▼
Restored EBS
   us-east-1a

Do only Step 1 first. Send me the GroupId returned by create-security-group; then we'll launch the temporary EC2 and attach the restored volume.

=======================================================

Perfect. The temporary EC2 is created successfully:

Instance:       i-06b88c8995d3ede10
AZ:             us-east-1a
Subnet:         subnet-01c106a6ea27f27bb
Private IP:     172.31.3.120
Instance type:  t3.small
Key:            my-key1
SG:             sg-0ed14f6349e1ebfa3

And importantly, it is in the same AZ as our restored EBS:

EC2     → us-east-1a
EBS     → us-east-1a
Next: wait for EC2 to become running

Run:

aws ec2 wait instance-running \
  --region us-east-1 \
  --instance-ids i-06b88c8995d3ede10

Then verify:

aws ec2 describe-instances \
  --region us-east-1 \
  --instance-ids i-06b88c8995d3ede10 \
  --query 'Reservations[0].Instances[0].[InstanceId,State.Name,PrivateIpAddress,PublicIpAddress,Placement.AvailabilityZone]' \
  --output table

We want:

running
us-east-1a
Then attach the restored EBS

Our restored volume is:

vol-010c648f27fe3fbd4

Attach it:

aws ec2 attach-volume \
  --region us-east-1 \
  --volume-id vol-010c648f27fe3fbd4 \
  --instance-id i-06b88c8995d3ede10 \
  --device /dev/sdf

Then verify:

aws ec2 describe-volumes \
  --region us-east-1 \
  --volume-ids vol-010c648f27fe3fbd4 \
  --query 'Volumes[0].[VolumeId,State,Attachments[0].InstanceId,Attachments[0].Device]' \
  --output table

We should see:

vol-010c648f27fe3fbd4
in-use
i-06b88c8995d3ede10
/dev/sdf

Don't mount or format anything yet. This time the volume already contains the XFS filesystem and our restore-test.txt. Formatting it would destroy the evidence we're trying to recover.

After the attach succeeds, we'll SSH in and identify the restored filesystem with lsblk -f.

===============================================================

Perfect. The attachment is now fully attached:

EC2
i-06b88c8995d3ede10
us-east-1a
running

and the restored volume is:

EBS
vol-010c648f27fe3fbd4
us-east-1a
in-use
/dev/sdf

So the AWS-side restore and attachment are complete. ✅

Now SSH into the temporary EC2

Use:

ssh -i ~/.ssh/my-key1.pem ec2-user@3.219.231.9

If your key is stored somewhere else, use the same path you used for the earlier EBS lab.

Once inside, do not run mkfs. The restored volume already contains the filesystem from the snapshot.

Run only:

lsblk

and:

lsblk -f

We expect to discover a new device, probably:

nvme1n1    5G disk

with:

xfs
UUID ...

The key thing we're looking for is that the restored volume already has the XFS filesystem. Then we'll mount it without formatting and check whether:

/data/restore-test.txt

has returned.

That will be the actual proof of EBS snapshot → volume → data recovery.

Exactly. This is the result we wanted. ✅

The restored volume is already carrying the original filesystem:

nvme1n1   5G   xfs   UUID=37cb9cd3-13df-407d-a923-7c438c6639f4

Compare that with the original volume before the snapshot:

nvme1n1   xfs   UUID=37cb9cd3-13df-407d-a923-7c438c6639f4

Same filesystem UUID. That is strong evidence that we recovered the filesystem from the snapshot rather than creating a new filesystem.

Now mount it — but DON'T format it

Run:

sudo mkdir -p /restore
sudo mount /dev/nvme1n1 /restore

Verify:

df -h /restore

Then:

ls -la /restore

And finally:

cat /restore/restore-test.txt

We expect:

EBS snapshot restore test

If that appears, we've completed the full recovery chain:

Original EBS
    ↓
Filesystem + data
    ↓
Snapshot
    ↓
Original EBS destroyed
    ↓
NEW EBS from snapshot
    ↓
Attach to NEW EC2
    ↓
Mount
    ↓
Original data recovered

Run those three verification commands and show me the output. After that we'll close EBS properly.

================================================================================================================

Excellent. That is the proof we wanted. ✅

You successfully recovered the original data:

/dev/nvme1n1    5.0G    68M    4.9G    /restore

EBS snapshot restore test
What we have now demonstrated end-to-end
Terraform
   │
   └── Encrypted EBS volume
          │
          ├── XFS filesystem
          └── restore-test.txt
                    │
                    ▼
              EBS Snapshot
                    │
          Original volume destroyed
                    │
                    ▼
          New EBS from snapshot
                    │
                    ▼
             New EC2 instance
                    │
                    ▼
              Mount /restore
                    │
                    ▼
          restore-test.txt
                    │
                    ▼
       "EBS snapshot restore test"

So we've covered the important EBS concepts and actually proved them, not just discussed them:

EBS block storage
Root vs data volume
EBS AZ dependency
gp3
Filesystem and mount
EBS encryption
KMS relationship
Snapshot creation
Snapshot persistence beyond Terraform resource destruction
Snapshot → new EBS volume
Attaching restored volume to another EC2
Data recovery
Terraform vs AWS-created resource lifecycle
One important production lesson

The snapshot itself is not the same thing as an application-consistent backup.

For databases and transactional applications, backup strategy has to consider application/database consistency. That's one reason RDS automated backups and snapshots are different from simply snapshotting an attached EBS volume.

Now clean up the restore lab

We're finished with the recovery proof, so let's avoid leaving billable resources running.

From your WSL terminal, first exit the EC2:

exit

Then terminate the temporary EC2:

aws ec2 terminate-instances \
  --region us-east-1 \
  --instance-ids i-06b88c8995d3ede10

Wait for termination:

aws ec2 wait instance-terminated \
  --region us-east-1 \
  --instance-ids i-06b88c8995d3ede10

Then delete the restored EBS volume:

aws ec2 delete-volume \
  --region us-east-1 \
  --volume-id vol-010c648f27fe3fbd4

And delete the temporary security group:

aws ec2 delete-security-group \
  --region us-east-1 \
  --group-id sg-0ed14f6349e1ebfa3
Finally, delete the snapshot

Since we've now completed the restore-from-snapshot exercise, we don't need to retain this lab snapshot.

aws ec2 delete-snapshot \
  --region us-east-1 \
  --snapshot-id snap-0cf0ff3f2d081cff8

Then verify the important resources are gone.

Once that's clean, EBS is complete and we can move directly to RDS.

=====================================================================================