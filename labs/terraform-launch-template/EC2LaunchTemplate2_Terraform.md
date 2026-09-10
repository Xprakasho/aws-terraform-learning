1. First understand what a Scaling Policy does

Right now your ASG has:

Min     = 1
Desired = 2
Max     = 3

That means AWS knows how many instances it is allowed to have, but it doesn't yet have a rule telling it when to change that number automatically.

A scaling policy provides that rule.

For example:

CPU utilization > 70%
        ↓
Scale OUT
        ↓
2 EC2 → 3 EC2

and:

CPU utilization < 30%
        ↓
Scale IN
        ↓
3 EC2 → 2 EC2

So the relationship is:

                  ┌── Scale OUT
                  │
Metric/Alarm ──→ Scaling Policy
                  │
                  └── Scale IN
                         ↓
                    ASG capacity
Important distinction

Your ASG currently has:

min_size
desired_capacity
max_size

These define capacity boundaries/state.

Scaling policies define how AWS changes desired capacity.

2. Before creating anything, let's inspect our current ASG

Run:

aws autoscaling describe-auto-scaling-groups \
  --region us-east-1 \
  --auto-scaling-group-names terraform-web-asg \
  --query 'AutoScalingGroups[0].[AutoScalingGroupName,MinSize,DesiredCapacity,MaxSize]' \
  --output table

We expect approximately:

Min    Desired    Max
1         2        3

Then check whether we currently have any scaling policies:

aws autoscaling describe-policies \
  --region us-east-1 \
  --auto-scaling-group-name terraform-web-asg \
  --output table

Most likely you'll see no policies yet.

=========================================

Step 2 — Create scaling.tf

Let's keep the scaling policy separate from asg.tf.

Run:

touch scaling.tf

Then:

nano scaling.tf

Put this in it:

resource "aws_autoscaling_policy" "cpu_target" {
  name                   = "terraform-web-cpu-target"
  policy_type            = "TargetTrackingScaling"
  autoscaling_group_name = aws_autoscaling_group.web.name

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }

    target_value = 50.0
  }
}

Save it.

Understand this before applying

The important relationship is:

aws_autoscaling_group.web
          │
          │ name
          ▼
aws_autoscaling_policy.cpu_target

And:

policy_type = "TargetTrackingScaling"

means:

AWS should automatically adjust the ASG capacity to try to maintain the selected metric around the target.

Here:

predefined_metric_type = "ASGAverageCPUUtilization"
target_value           = 50.0

means:

Target CPU = 50%

So conceptually:

             ASG
              │
              ▼
       Average CPU metric
              │
              ▼
       Target = 50%
              │
       ┌──────┴──────┐
       │             │
     Higher        Lower
       │             │
   Scale OUT      Scale IN
       │             │
       └──────┬──────┘
              ▼
       ASG Desired Capacity
          1 → 2 → 3
And notice something important

We are not manually creating a CloudWatch alarm yet.

Target tracking can use the AWS-managed scaling mechanism for this. Later, when we reach CloudWatch, we'll learn the difference between:

Target tracking
Step scaling
CloudWatch alarms

That distinction is important.

Now DON'T apply yet

First run:

terraform fmt

then:

terraform validate

and finally:

terraform plan

We should expect Terraform to show approximately:

# aws_autoscaling_policy.cpu_target will be created
+ resource "aws_autoscaling_policy" "cpu_target" {
    + name                   = "terraform-web-cpu-target"
    + policy_type            = "TargetTrackingScaling"
    + autoscaling_group_name = "terraform-web-asg"

    + target_tracking_configuration {
        + target_value = 50
        ...
      }
}

================================

Terraform will create one resource only:

aws_autoscaling_policy.cpu_target
Let's read the important parts
autoscaling_group_name = "terraform-web-asg"

So the policy is attached to our existing ASG:

terraform-web-asg

Then:

policy_type = "TargetTrackingScaling"

This tells AWS:

Automatically adjust ASG capacity based on a target metric.

And the key configuration:

target_value = 50

with:

predefined_metric_type = "ASGAverageCPUUtilization"

means:

Try to maintain the ASG's average CPU utilization around 50%.

Your capacity limits still control the boundaries:

Min = 1
Desired = 1
Max = 3

So the policy can potentially do:

1 → 2 → 3

but never:

0

or:

4

because the ASG limits prevent that.

One interesting line

You can see:

disable_scale_in = false

That means scale-in is allowed.

So this is a two-way policy:

CPU increases
     ↓
Scale OUT

CPU decreases
     ↓
Scale IN
Now let's apply it

Run:

terraform apply

Terraform should show:

Plan: 1 to add, 0 to change, 0 to destroy.

Type:

yes

After it completes, don't change anything manually yet.

We'll first verify that AWS actually has the policy:

aws autoscaling describe-policies \
  --region us-east-1 \
  --auto-scaling-group-name terraform-web-asg \
  --query 'ScalingPolicies[*].[PolicyName,PolicyType,TargetTrackingConfiguration.TargetValue,TargetTrackingConfiguration.PredefinedMetricSpecification.PredefinedMetricType]' \
  --output table

Then we'll inspect the ASG and understand what the policy actually changed.

====================

Perfect. 👍 We have now successfully created and verified the Target Tracking Scaling Policy.

Your current architecture is:

Launch Template
      ↓
Auto Scaling Group
      ↓
Target Tracking Policy
      ↓
CPU target = 50%

And AWS confirms:

Policy:              terraform-web-cpu-target
Type:                TargetTrackingScaling
Target CPU:          50%
Metric:              ASGAverageCPUUtilization
Next: understand what the policy actually does

The important point is:

The policy does not mean "always keep 50% CPU."
It means AWS will automatically adjust the ASG capacity when average CPU utilization moves sufficiently away from the 50% target.

For example:

Current instances = 1

CPU increases
     ↓
Average CPU > 50%
     ↓
Auto Scaling increases capacity
     ↓
2 instances

And:

Current instances = 2

CPU stays low
     ↓
Average CPU < 50%
     ↓
Auto Scaling can reduce capacity
     ↓
1 instance

Your ASG limits are:

min = 1
desired = 1
max = 3

So the policy can operate between 1 and 3 instances.

Step 1 — Verify Terraform

Run:

terraform plan

We want:

No changes.

If you get that, Terraform and AWS are synchronized.

Step 2 — Check current ASG state

Run:

aws autoscaling describe-auto-scaling-groups \
  --region us-east-1 \
  --auto-scaling-group-names terraform-web-asg \
  --query 'AutoScalingGroups[0].[MinSize,DesiredCapacity,MaxSize,Instances[*].[InstanceId,LifecycleState,HealthStatus,AvailabilityZone]]' \
  --output json

This time we're using json rather than table because the nested Instances list makes the table query awkward.

Don't generate CPU load yet. First let's establish the clean baseline.

Send me the output, and then we'll do the interesting part: trigger scaling and watch the ASG go from 1 → 2 → potentially 3 instances.

======================================

Perfect. This is exactly the state we want before testing Auto Scaling policies.

Current state

From your output:

Setting	Current
Min size	1
Desired	1
Max size	3
Instances	1
Lifecycle	InService
Health	Healthy
AZ	us-east-1f

So our architecture is now:

Launch Template
      ↓
Auto Scaling Group
      ↓
Target Tracking Policy
      ↓
ASG Average CPU = 50%

And Terraform also says:

No changes.
Your infrastructure matches the configuration.

So Terraform and AWS are synchronized.

Now let's test the scaling policy

We want to demonstrate:

CPU increases
    ↓
ASG Average CPU > 50%
    ↓
Target Tracking policy reacts
    ↓
Desired capacity increases
    ↓
New EC2 instance launches
Step 1 — Confirm the current instance

Run:

aws ec2 describe-instances \
  --region us-east-1 \
  --filters "Name=tag:Name,Values=terraform-asg-web" "Name=instance-state-name,Values=running" \
  --query 'Reservations[*].Instances[*].[InstanceId,InstanceType,State.Name,Placement.AvailabilityZone,PrivateIpAddress]' \
  --output table

You should see one running t3.small.

Step 2 — Let's generate CPU load

First get the instance ID:

aws ec2 describe-instances \
  --region us-east-1 \
  --filters "Name=tag:Name,Values=terraform-asg-web" "Name=instance-state-name,Values=running" \
  --query 'Reservations[0].Instances[0].InstanceId' \
  --output text

Then we can connect to that instance and generate CPU load.

=================================

Good. We have the current running instance ID:

i-0b2bd87179b47a834

And one important observation from your screenshot:

InstanceType = t3.micro
AZ            = us-east-1f
State         = running

So right now we're back on t3.micro, which is fine for this scaling-policy experiment.

Next: generate CPU load

Before connecting, let's get its public IP:

aws ec2 describe-instances \
  --region us-east-1 \
  --instance-ids i-0b2bd87179b47a834 \
  --query 'Reservations[0].Instances[0].[PublicIpAddress,PrivateIpAddress]' \
  --output table

Run that and send me the output.

Then we'll SSH into the instance and deliberately increase CPU utilization.

The experiment we're building is:

1 EC2 instance
     │
     │ CPU load ↑
     ↓
ASG Average CPU > 50%
     │
     ↓
TargetTrackingScaling policy
     │
     ↓
Desired capacity 1 → 2
     │
     ↓
New EC2 instance launched

This is the important distinction from our earlier Launch Template versioning exercise: Terraform defines the policy, but AWS Auto Scaling makes the scaling decision dynamically at runtime.

==============================================

Trouble-shooting-EC2 SSH 

Yes. The IGW + route is now correct. Your screenshot shows:

0.0.0.0/0 → igw-09b1473e50cf40aac → Active
Instance has a public IP 34.231.240.60
But the Security Group is still the default SG, and its inbound rule only allows traffic from itself.
Therefore SSH port 22 is blocked.

So the next step is simply to allow SSH.

1. Add SSH to the existing SG

Your SG is:

sg-08e55271a062d3577

For this lab, let's allow SSH from anywhere temporarily:

aws ec2 authorize-security-group-ingress \
  --region us-east-1 \
  --group-id sg-08e55271a062d3577 \
  --protocol tcp \
  --port 22 \
  --cidr 0.0.0.0/0

You should get something like:

{
    "Return": true
}
2. Verify the rule
aws ec2 describe-security-groups \
  --region us-east-1 \
  --group-ids sg-08e55271a062d3577 \
  --query 'SecurityGroups[0].IpPermissions' \
  --output table

We want to see TCP port 22.

3. Then SSH

First try Ubuntu:

ssh -i ~/my-key1.pem ubuntu@34.231.240.60

If that doesn't work, try Amazon Linux:

ssh -i ~/my-key1.pem ec2-user@34.231.240.60

Important: your previous ssh command hanging is consistent with port 22 being blocked. Once we add the SG ingress rule, the SSH connection should at least reach the instance.

For our learning flow, we're now at:

Launch Template
       ↓
Auto Scaling Group
       ↓
Scaling Policy        ← currently working
       ↓
EC2 instances
       ↓
Internet Gateway      ← working
       ↓
Route Table           ← working
       ↓
Security Group        ← FIX NOW
       ↓
SSH

Run step 1 first and show me the output.

Good. Now the Security Group is no longer the blocking point.

You have now confirmed:

✅ Instance is running
✅ Public IP: 34.231.240.60
✅ Route table has 0.0.0.0/0 → IGW
✅ IGW is attached to the VPC
✅ Security Group now allows TCP/22 from 0.0.0.0/0
✅ Security Group egress is already open

So let's stop changing things and test the connection again.

1. Test port 22

Run:

nc -vz -w 5 34.231.240.60 22

We want:

Connection to 34.231.240.60 22 port [tcp/ssh] succeeded!
2. If port 22 succeeds, SSH

First try Ubuntu:

ssh -i ~/my-key1.pem ubuntu@34.231.240.60

If that doesn't work because the AMI uses Amazon Linux, try:

ssh -i ~/my-key1.pem ec2-user@34.231.240.60
Important

Don't change the route table, IGW, or SG again yet.

We have deliberately built the path:

Internet
   ↓
IGW
   ↓
Route Table
0.0.0.0/0 → IGW
   ↓
Public Subnet
   ↓
EC2
   ↓
Security Group
TCP/22 allowed

Now run only the nc command first and show me the output.

====================================================

Our actual objective here is:

Generate CPU load → CloudWatch metric increases → Auto Scaling policy reacts → ASG launches another EC2 instance.

So let's focus on that.

Current state

We have:

Launch Template
    ↓
ASG
    min = 1
    desired = 1
    max = 3
    ↓
Target Tracking Policy
    CPU target = 50%

And we verified the policy exists:

terraform-web-cpu-target
TargetTrackingScaling
50%
ASGAverageCPUUtilization
Step 1 — Generate CPU load

You are currently inside the EC2:

[ec2-user@ip-172-31-4-12 ~]$

Run:

sudo dnf install -y stress-ng

Then generate CPU load:

stress-ng --cpu 2 --timeout 10m

This will deliberately consume CPU for 10 minutes.

Don't worry: this is a lab instance and we're doing it specifically to test Auto Scaling.

Step 2 — From another WSL terminal, watch the ASG

Open another terminal and run:

watch -n 10 'aws autoscaling describe-auto-scaling-groups \
  --region us-east-1 \
  --auto-scaling-group-names terraform-web-asg \
  --query "AutoScalingGroups[0].[MinSize,DesiredCapacity,MaxSize,Instances[*].[InstanceId,LifecycleState,HealthStatus]]" \
  --output table'

Initially you should see approximately:

Min   Desired   Max
1       1        3

Instance
i-xxxxx   InService   Healthy

Then, if the CPU stays sufficiently above the 50% target long enough, AWS should increase:

Desired: 1 → 2

and launch a second EC2.

The key learning

This is the important distinction:

stress-ng
   ↓
EC2 CPU increases
   ↓
CloudWatch CPU metric
   ↓
Auto Scaling Target Tracking policy
   ↓
DesiredCapacity increases
   ↓
ASG launches EC2
   ↓
Launch Template creates the new instance

This is the real purpose of the exercise.

One caution: Target Tracking is not instantaneous. AWS needs to observe the metric and evaluate the policy, so don't worry if the second instance doesn't appear immediately.

Run the stress-ng command first. Then show me the ASG watch output after a few minutes.

==================================================

watch -n 10 'aws autoscaling describe-auto-scaling-groups --region us-east-1 --auto-scaling-group-names terraform-web-asg --query "AutoScalingGroups[0].[MinSize,DesiredCapacity,MaxSize,Instances[*].[InstanceId,LifecycleState,HealthStatus]]" --output table'


watch -n 10 'aws autoscaling describe-auto-scaling-groups \
  --region us-east-1 \
  --auto-scaling-group-names terraform-web-asg \
  --query "AutoScalingGroups[0].Instances[*].[InstanceId,LifecycleState,HealthStatus]" \
  --output table'


=================================================

1. Check ASG capacity

Run:

aws autoscaling describe-auto-scaling-groups \
  --region us-east-1 \
  --auto-scaling-group-names terraform-web-asg \
  --query 'AutoScalingGroups[0].[MinSize,DesiredCapacity,MaxSize]' \
  --output table

Expected:

--------------------------
| DescribeAutoScaling... |
+----+----+----+
| 1  | 1  | 3  |
+----+----+----+
2. Check instances separately
aws autoscaling describe-auto-scaling-groups \
  --region us-east-1 \
  --auto-scaling-group-names terraform-web-asg \
  --query 'AutoScalingGroups[0].Instances[*].[InstanceId,LifecycleState,HealthStatus]' \
  --output table

Initially we expect something like:

------------------------------------------
| InstanceId       | InService | Healthy |
------------------------------------------
| i-xxxxxxxx       | InService | Healthy |
------------------------------------------
3. Now the important part

You already have the scaling policy:

terraform-web-cpu-target
TargetTrackingScaling
Target = 50%
Metric = ASGAverageCPUUtilization

So if your stress-ng process is still running on the EC2, leave it running.

Then execute command #1 every 30–60 seconds.

We are specifically watching:

DesiredCapacity

1
↓
2

Once it becomes 2, we'll check command #2 and should see two instances.

So don't change Terraform or AWS configuration now. This error is just the CLI query formatting.

Run command #1 first and show me the output.

Perfect. This is exactly what we wanted to see. 🎯

Your two screenshots show the scaling event completed:

1. ASG capacity
Min       Desired       Max
 1           2           3

So the ASG changed:

Desired Capacity: 1 → 2
2. Instances

You now have:

i-01997e225911bb0a1   InService   Healthy
i-0f6041b14843fefbf   InService   Healthy

So:

                CPU Load
                   ↓
              CloudWatch
                   ↓
        Target Tracking Policy
             Target = 50%
                   ↓
          ASG: Desired 1 → 2
                   ↓
          Launch Template
                   ↓
             New EC2
✅ What we have successfully demonstrated

Our first part of the architecture is now fully working:

Launch Template
       ↓
Auto Scaling Group
       ↓
Target Tracking Scaling Policy
       ↓
CloudWatch CPU metric
       ↓
Automatic EC2 scale-out

And importantly, we didn't manually create the second EC2. The ASG did it automatically.

One important observation

Your configuration is:

min_size         = 1
desired_capacity = 1
max_size         = 3

The policy caused:

1 instance
    ↓
CPU load
    ↓
2 instances

That is the core concept we wanted to learn.

========================================================================




