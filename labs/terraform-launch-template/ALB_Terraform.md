ext: ALB

Our target architecture is:

                    ┌── EC2 #1
                    │
Client → ALB → Target Group
                    │
                    └── EC2 #2
                         ↑
                        ASG
                         ↑
                  Launch Template

Before writing Terraform, let's understand the three ALB components we'll create:

1. Application Load Balancer

The ALB provides the entry point:

Internet
   ↓
ALB

It needs to be placed in at least two subnets/AZs for a proper multi-AZ design.

2. Target Group

The Target Group defines:

"Which EC2 instances should receive traffic, and how do I know they're healthy?"

For example:

Target Group
   ├── EC2 #1 : port 80
   └── EC2 #2 : port 80
3. ALB Listener

The listener defines:

ALB :80
   ↓
Target Group

So the complete request flow becomes:

Client
  ↓
ALB :80
  ↓
Listener
  ↓
Target Group :80
  ↓
EC2 instances
One important change from our previous exercise

Previously we accessed the EC2 directly:

Internet → Public IP → EC2

Now we want:

Internet → ALB → EC2

The ALB becomes the public entry point.

Our next step

Before creating anything, let's inspect what subnets we currently have because your ASG is already using:

vpc_zone_identifier = data.aws_subnets.default.ids

Run:

aws ec2 describe-subnets \
  --region us-east-1 \
  --filters "Name=vpc-id,Values=vpc-0dc7156d13d263648" \
  --query 'Subnets[*].[SubnetId,AvailabilityZone,CidrBlock,MapPublicIpOnLaunch]' \
  --output table

===================================================================

Step 1 — Let's inspect the existing security groups

Before Terraform creates anything, let's see what SGs already exist in this VPC.

Run:

aws ec2 describe-security-groups \
  --region us-east-1 \
  --filters "Name=vpc-id,Values=vpc-0dc7156d13d263648" \
  --query 'SecurityGroups[*].[GroupId,GroupName,Description]' \
  --output table

We need to identify whether we already have a suitable SG for the ALB.

Then we'll create the ALB architecture:

Internet
    │
    ▼
 Internet Gateway
    │
    ▼
   ALB
    │
    ▼
Target Group
    │
    ├── EC2 instance 1
    ├── EC2 instance 2
    └── EC2 instance 3

And importantly, we'll connect the ASG to the Target Group so that when ASG creates or terminates instances, the backend membership follows automatically.

We already have a working EC2/ASG setup, so don't change the existing infrastructure unnecessarily.

For the ALB, we'll create:

Internet
   |
   | HTTP :80
   ↓
ALB
   |
   | HTTP :80
   ↓
ASG instances

And eventually the security model will be:

Internet
   |
   ↓
ALB-SG
  :80
   |
   ↓
EC2-SG
  :80 only from ALB-SG

But since we're doing this as a learning lab, let's build it one component at a time.

Step 1 — Create the ALB Security Group

Let's first check whether an appropriate ALB SG already exists.

Run:

aws ec2 describe-security-groups \
  --region us-east-1 \
  --filters "Name=vpc-id,Values=vpc-0dc7156d13d263648" \
  --query 'SecurityGroups[*].[GroupId,GroupName,Description]' \
  --output table

You already showed us that the existing groups are:

launch-wizard-1
default

Neither is specifically an ALB SG.

So let's create one:

aws ec2 create-security-group \
  --region us-east-1 \
  --group-name terraform-alb-sg \
  --description "Security group for Terraform ALB" \
  --vpc-id vpc-0dc7156d13d263648

Then give the ALB HTTP access:

aws ec2 authorize-security-group-ingress \
  --region us-east-1 \
  --group-id <ALB_SG_ID> \
  --protocol tcp \
  --port 80 \
  --cidr 0.0.0.0/0

Replace <ALB_SG_ID> with the ID returned by the first command.

========================================

Step 2 — Create the ALB

Run:

aws elbv2 create-load-balancer \
  --region us-east-1 \
  --name terraform-web-alb \
  --subnets \
    subnet-0a31b4f8ad97a7713 \
    subnet-01c1066ae2f727bb \
  --security-groups sg-065eedbe3aa20d644 \
  --scheme internet-facing \
  --type application \
  --query 'LoadBalancers[0].[LoadBalancerArn,DNSName,State.Code]' \
  --output table

I'm deliberately using two public subnets in different AZs for the ALB.

You should get something similar to:

LoadBalancerArn     ...
DNSName             terraform-web-alb-xxxxx.us-east-1.elb.amazonaws.com
State.Code          provisioning

Once the command completes, send me the output. Then we'll create the Target Group, register the ASG/instances, and finally create the listener:

Internet
   ↓
ALB :80
   ↓
Target Group :80
   ↓
ASG instances

=============================================================

Perfect. ALB creation succeeded. ✅

We now have:

Internet
   ↓
Internet-facing ALB
   ↓
[Target Group]       ← NEXT
   ↓
ASG instances

Your ALB:

Name: terraform-web-alb
DNS: terraform-web-alb-186510565.us-east-1.elb.amazonaws.com
State: provisioning
Subnets: us-east-1f + us-east-1c
Security Group: sg-065eedbe3aa20d644
Next: Create Target Group

We'll create a target group for HTTP port 80:

aws elbv2 create-target-group \
  --region us-east-1 \
  --name terraform-web-tg \
  --protocol HTTP \
  --port 80 \
  --vpc-id vpc-0dc7156d13d263648 \
  --target-type instance \
  --health-check-protocol HTTP \
  --health-check-path / \
  --query 'TargetGroups[0].[TargetGroupArn,TargetGroupName,Protocol,Port]' \
  --output table

This is an important concept:

ALB does not directly point to the ASG.

The relationship is:

             ASG
              |
              | instances
              ↓
        ┌─────────────┐
        │ Target Group│
        │    :80      │
        └──────┬──────┘
               ↑
               |
              ALB

Run the command and send me the output. Then we'll connect the ASG instances → Target Group and create the ALB listener.

Excellent. Target Group creation succeeded. ✅

We now have:

Internet
   ↓
ALB :80
   ↓
Target Group :80       ✅
   ↓
ASG instances          ← NEXT

Target Group:

Name     : terraform-web-tg
Protocol : HTTP
Port     : 80
Target   : instance
Health   : HTTP /
Next step — register the ASG instances

We currently have two healthy instances from the ASG. We need their IDs.

Run:

aws autoscaling describe-auto-scaling-groups \
  --region us-east-1 \
  --auto-scaling-group-names terraform-web-asg \
  --query 'AutoScalingGroups[0].Instances[*].InstanceId' \
  --output table

You should see something like:

----------------------
| DescribeInstances  |
+--------------------+
| i-xxxxxxxxxxxxxxxx |
| i-yyyyyyyyyyyyyyyy |
+--------------------+

Send me that output.

Then we'll register those instances with terraform-web-tg.

One important learning point: normally, in a production Terraform design, we'd configure the ASG with target_group_arns so instances are automatically registered/deregistered as the ASG scales. We're doing the manual AWS CLI step first so you can clearly understand the ALB → Target Group → ASG relationship.

Yes. Right now the ASG has one instance, and it is:

i-04334d1b365cf83a6

That's fine. Since the ASG desired capacity has changed back to 1, it has scaled down.

Next: register this instance with the Target Group

Use:

aws elbv2 register-targets \
  --region us-east-1 \
  --target-group-arn arn:aws:elasticloadbalancing:us-east-1:587748224379:targetgroup/terraform-web-tg/5de6b1be8b371a15 \
  --targets Id=i-04334d1b365cf83a6

Then verify:

aws elbv2 describe-target-health \
  --region us-east-1 \
  --target-group-arn arn:aws:elasticloadbalancing:us-east-1:587748224379:targetgroup/terraform-web-tg/5de6b1be8b371a15 \
  --query 'TargetHealthDescriptions[*].[Target.Id,TargetHealth.State,TargetHealth.Reason]' \
  --output table

Initially you may see:

i-04334d1b365cf83a6    initial    ...

Give it a little time. We ultimately want:

i-04334d1b365cf83a6    healthy
Then the final ALB piece

Once the target becomes healthy, we'll create:

ALB
 ↓
Listener :80
 ↓
Target Group
 ↓
EC2

============================================

This means the instance is registered, but the Target Group is not yet being used by the ALB.

We have already created:

VPC ✅
Public subnets ✅
Internet Gateway + default route ✅
Security Group with HTTP/80 ✅
ALB terraform-web-alb ✅
Target Group terraform-web-tg ✅
ASG terraform-web-asg with instance i-04334d1b365cf83a6 ✅
Step 1 — Attach Target Group to ASG

Run:

aws autoscaling attach-load-balancer-target-groups \
  --region us-east-1 \
  --auto-scaling-group-name terraform-web-asg \
  --target-group-arns arn:aws:elasticloadbalancing:us-east-1:587748224379:targetgroup/terraform-web-tg/5de6b1be8b371a15

Then verify:

aws autoscaling describe-auto-scaling-groups \
  --region us-east-1 \
  --auto-scaling-group-names terraform-web-asg \
  --query 'AutoScalingGroups[0].TargetGroupARNs' \
  --output table

You should see the terraform-web-tg ARN.

Step 2 — Create ALB Listener

Our ALB ARN is:

arn:aws:elasticloadbalancing:us-east-1:587748224379:loadbalancer/app/terraform-web-alb/157a36a5fd69dd0f

Create an HTTP listener forwarding traffic to the target group:

aws elbv2 create-listener \
  --region us-east-1 \
  --load-balancer-arn arn:aws:elasticloadbalancing:us-east-1:587748224379:loadbalancer/app/terraform-web-alb/157a36a5fd69dd0f \
  --protocol HTTP \
  --port 80 \
  --default-actions Type=forward,TargetGroupArn=arn:aws:elasticloadbalancing:us-east-1:587748224379:targetgroup/terraform-web-tg/5de6b1be8b371a15 \
  --query 'Listeners[0].[ListenerArn,Port,Protocol,DefaultActions[0].TargetGroupArn]' \
  --output table

This is the missing ALB → Target Group connection.

Step 3 — Wait a little and check target health

After ~20–30 seconds:

aws elbv2 describe-target-health \
  --region us-east-1 \
  --target-group-arn arn:aws:elasticloadbalancing:us-east-1:587748224379:targetgroup/terraform-web-tg/5de6b1be8b371a15 \
  --query 'TargetHealthDescriptions[*].[Target.Id,TargetHealth.State,TargetHealth.Reason]' \
  --output table

Initially you may see:

initial

Then hopefully:

i-04334d1b365cf83a6   healthy   -
Step 4 — Test the ALB

Once the target becomes healthy, use the ALB DNS name you already got:

terraform-web-alb-186510565.us-east-1.elb.amazonaws.com

Run:

curl -I http://terraform-web-alb-186510565.us-east-1.elb.amazonaws.com

If everything is correct, the request should reach the EC2 instance through:

Internet
   ↓
Internet Gateway
   ↓
ALB :80
   ↓
Listener :80
   ↓
Target Group :80
   ↓
ASG EC2 instance

===============================================================================

Your output:

ss -lntp | grep ':80'

returned nothing, and:

curl -I http://localhost:80/

returned:

Failed to connect to localhost port 80

So the EC2 instance currently has no service listening on TCP/80.

That explains:

ALB → Target
      ↓
   port 80
      ↓
   nothing listening
      ↓
Target.FailedHealthChecks
      ↓
ALB returns 504
Next step: install/start a simple web server

Since this is your Terraform + Auto Scaling + ALB lab, let's use nginx as the application.

You're on Amazon Linux 2023, so run inside the EC2:

sudo dnf install -y nginx

Then:

sudo systemctl enable --now nginx

Verify:

sudo systemctl status nginx --no-pager

Then:

ss -lntp | grep ':80'

And finally:

curl -I http://localhost:80/

We want:

HTTP/1.1 200 OK
Then check ALB health

Exit the EC2:

exit

Back on your WSL terminal:

aws elbv2 describe-target-health \
  --region us-east-1 \
  --target-group-arn arn:aws:elasticloadbalancing:us-east-1:587748224379:targetgroup/terraform-web-tg/5de6b1be8b371a15 \
  --query 'TargetHealthDescriptions[*].[Target.Id,TargetHealth.State,TargetHealth.Reason]' \
  --output table

Give it ~10–20 seconds if necessary.

We should eventually see:

i-04334d1b365cf83a6   healthy

Then test the ALB:

curl -I http://terraform-web-alb-186510565.us-east-1.elb.amazonaws.com

This is actually a useful point in the lab: we have now validated the complete chain:

Internet
   ↓
ALB
   ↓
Target Group :80
   ↓
EC2 Security Group :80
   ↓
Nginx :80

==============================================

Perfect. Target is now healthy. ✅

i-04334d1b365cf83a6 | healthy | None

So our ALB path is now working:

Internet
   ↓
ALB :80
   ↓
Target Group :80
   ↓
EC2 :80
   ↓
Nginx
Now test the ALB

Run:

curl -I http://terraform-web-alb-186510565.us-east-1.elb.amazonaws.com

We want:

HTTP/1.1 200 OK

If that returns 200, the ALB portion of the lab is complete.

Then we'll move to the main objective you mentioned earlier:

Generate load → observe Auto Scaling → verify new EC2 instances automatically join the target group.

================================================================

Now let's test Auto Scaling

Our goal is to demonstrate:

Current
ASG
 └── 1 EC2

        │
        │ generate CPU load
        ▼

CPU increases
        │
        ▼
Scaling policy triggers
        │
        ▼
ASG launches another EC2
        │
        ▼
New EC2 becomes healthy
        │
        ▼
ALB distributes traffic
Step 1 — Check the scaling policy first

From your WSL terminal, run:

aws autoscaling describe-policies \
  --region us-east-1 \
  --auto-scaling-group-name terraform-web-asg \
  --query 'ScalingPolicies[*].[PolicyName,PolicyType,TargetTrackingConfiguration.TargetValue,TargetTrackingConfiguration.PredefinedMetricSpecification.PredefinedMetricType]' \
  --output table

Also check the current ASG:

aws autoscaling describe-auto-scaling-groups \
  --region us-east-1 \
  --auto-scaling-group-names terraform-web-asg \
  --query 'AutoScalingGroups[0].[MinSize,DesiredCapacity,MaxSize,Instances[*].InstanceId]' \
  --output table

We want to know exactly what metric triggers scaling before generating load.

Don't generate the load yet

First show me those two outputs.

Then we'll deliberately generate CPU load on the EC2 and watch:

1 → 2 → possibly 3 instances

and verify that the new instances automatically appear as healthy ALB targets.

Exactly — Auto Scaling has successfully scaled out. ✅

You now have 2 healthy InService EC2 instances:

i-04334d1b365cf83a6   InService   Healthy
i-0e6df0a0d21292981   InService   Healthy

So our test has proven the complete flow:

CPU load
   ↓
CloudWatch CPU metric
   ↓
Target Tracking Policy (50%)
   ↓
ASG DesiredCapacity: 1 → 2
   ↓
New EC2 launched
   ↓
New instance: InService + Healthy
One final verification

Check the ASG capacity:

aws autoscaling describe-auto-scaling-groups \
  --region us-east-1 \
  --auto-scaling-group-names terraform-web-asg \
  --query 'AutoScalingGroups[0].[MinSize,DesiredCapacity,MaxSize]' \
  --output table

You should see:

1
2
3

Then check the ALB targets:

aws elbv2 describe-target-health \
  --region us-east-1 \
  --target-group-arn arn:aws:elasticloadbalancing:us-east-1:587748224379:targetgroup/terraform-web-tg/5de6b1be8b371a15 \
  --query 'TargetHealthDescriptions[*].[Target.Id,TargetHealth.State]' \
  --output table

Ideally:

i-04334d1b365cf83a6   healthy
i-0e6df0a0d21292981   healthy

Don't terminate anything manually yet. Once we verify the ALB has both targets, we'll test scale-in by stopping the CPU load and observing 2 → 1.
