
Complete Authentication Flow

Let's finally put everything together.

Application
      │
      ▼
AWS SDK
      │
      ▼
IMDS
      │
      ▼
IAM Role
      │
      ▼
Trust Policy
      │
      ▼
Can EC2 assume this role?
      │
      ▼
YES
      │
      ▼
STS
      │
      ▼
Temporary Credentials
      │
      ▼
Permission Policy
      │
      ▼
Allowed to Get Secret?
      │
      ▼
YES
      │
      ▼
Secrets Manager
      │
      ▼
KMS
      │
      ▼
Database Password

IAM Role
     │
     ├───────────────┐
     │               │
     ▼               ▼
Trust Policy    Permission Policy
     │               │
Who can use?    What can it do?

EC2 Starts
      │
      ▼
IAM Role Attached
      │
      ▼
Trust Policy
      │
      ▼
Is EC2 Trusted?
      │
      ├── No → STS denies AssumeRole
      │
      └── Yes
            │
            ▼
STS issues Temporary Credentials
            │
            ▼
Permission Policy
            │
            ▼
Can the role perform the requested AWS action?

Trust Policy answers: Who can assume the role?
STS issues temporary credentials.
Permission Policy answers: What can those credentials do?

EC2
 │
 ▼
Instance Profile
 │
 ▼
IAM Role
 │
 ├──────────────┐
 │              │
 ▼              ▼
Trust Policy    Permission Policy
 │
 ▼
STS
 │
 ▼
Temporary Credentials
 │
 ▼
IMDS
 │
 ▼
AWS SDK
 │
 ▼
Application

=================================================================================================================
Let's keep today's lab focused on IAM and finish it. We'll learn Remote State Sharing, terraform_remote_state, and cross-project dependencies on another day.
===================================================================================================================

📘 Module 07 – AWS Identity & Secrets

Lesson 1: How Does an EC2 Authenticate to AWS?
The Real Problem

Imagine you have an EC2 instance.

Your application needs to:

Read from S3
Retrieve a database password from Secrets Manager
Send logs to CloudWatch
Read parameters from Systems Manager

Question

How does the EC2 prove its identity to AWS?

❌ Option 1: Hardcode Access Keys
Application
     │
     ▼
AWS Access Key
AWS Secret Key
     │
     ▼
AWS API

Example:

AWS_ACCESS_KEY_ID=AKIAxxxxxxxx
AWS_SECRET_ACCESS_KEY=xxxxxxxx

Problems
Keys can be leaked.
Keys may never be rotated.
Anyone with the keys can use them.
If the EC2 is compromised, the attacker gets permanent credentials.

Production environments avoid this approach whenever possible.

✅ Option 2: IAM Role (Recommended)

Instead of storing credentials, the EC2 is given an IAM Role.

EC2
 │
 ▼
IAM Role
 │
 ▼
Temporary Credentials
 │
 ▼
AWS Services

No permanent Access Key.

No permanent Secret Key.

This is the standard AWS approach.

Think of It Like a Company ID Card

Imagine you work at Google.

You don't carry:

A master password for every building.
A permanent key to every room.

Instead, you receive:

Employee Badge

When you enter a building:

Security verifies your badge
        │
        ▼
Temporary access granted

AWS works the same way.

The IAM Role is your employee badge.

The AWS Authentication Flow
==========================================================================================

Let's walk through the complete sequence.

           Create EC2
                │
                ▼
      Attach IAM Role
                │
                ▼
      Launch Instance
                │
                ▼
 EC2 requests credentials
 from AWS Metadata Service
                │
                ▼
        AWS STS
(Security Token Service)
                │
                ▼
 Temporary Credentials
                │
                ▼
EC2 calls AWS Services

Everything after launch happens automatically.

What Is an IAM Role?

An IAM Role is not a user.

It is an identity that defines permissions, but it does not have:

Username
Password
Permanent Access Key

Instead:

IAM Role
       │
       ▼
Permissions

Example:

Can read S3

Can access Secrets Manager

Can write CloudWatch Logs

That's all.

Then Who Uses the Role?

Many AWS resources can use it.

Examples:

EC2

Lambda

EKS

ECS

CodeBuild

CloudFormation

These services assume the role when they need AWS access.

What Is STS?

This is one of the most important AWS services.

STS = Security Token Service

Its job is simple:

Issue Temporary Credentials

It does not create users.

It does not store passwords.

It simply generates short-lived credentials.

Why Temporary Credentials?

Imagine a permanent key.

Valid Forever

If stolen...

Big problem.

Now imagine:

Valid for 1 hour

If stolen...

The risk is much lower because the credentials expire automatically.

This is why AWS prefers temporary credentials.

The Hidden Hero: Instance Metadata Service (IMDS)

Now comes the interesting part.

Your EC2 instance asks:

"I have an IAM Role. Can I have temporary credentials?"

But where does it ask?

It asks the Instance Metadata Service (IMDS).

Think of IMDS as a small service that exists inside every EC2 instance.

EC2
 │
 ├── Operating System
 │
 └── Metadata Service

It provides information such as:

Instance ID
Region
Availability Zone
IAM Role
Temporary credentials

Your applications (or the AWS CLI/SDK) can retrieve these credentials without storing secrets.

Putting It All Together
            EC2
             │
             ▼
      Instance Metadata Service
             │
             ▼
      Security Token Service
             │
             ▼
   Temporary Access Credentials
             │
             ▼
       IAM Role Permissions
             │
             ▼
        AWS Service
     (S3, Secrets Manager,
      CloudWatch, etc.)

=============================================================================================

How This Relates to Your Current Lab

Remember the EC2 instance we've already created with Terraform?

We attached:

IAM Role

That means the instance is already using this architecture.

Tomorrow, if you install the AWS CLI on that EC2 and run a command like:

aws sts get-caller-identity

you won't need to provide an Access Key or Secret Key. The CLI automatically retrieves temporary credentials from the Instance Metadata Service and uses them to authenticate with AWS.\

===========================================================================================================================

📘 Module 07 – Lesson 2

IAM User vs IAM Role vs IAM Policy vs Instance Profile vs STS
The Big Picture
                    AWS Account
                         │
      ┌──────────────────┴──────────────────┐
      │                                     │
      ▼                                     ▼
 IAM User                              IAM Role
(Human)                            (AWS Service)
      │                                     │
      ▼                                     ▼
 IAM Policy                           IAM Policy
      │                                     │
      └──────────────┬──────────────────────┘
                     ▼
              Allowed Actions
                     │
                     ▼
                  AWS Resources

1. IAM User

Think of an IAM User as a human identity.

Examples:

Cloud Administrator
DevOps Engineer
Platform Engineer
Developer

They log in using:

Username & Password (AWS Console)
Access Key & Secret Key (AWS CLI)

Example:

Om Prakash
      │
      ▼
IAM User
      │
      ▼
AWS Console
In Our Lab

When you configured:

aws configure

you were using an IAM User (or another long-term credential source).

2. IAM Policy

A Policy simply answers:

What is this identity allowed to do?

Example:

{
  "Effect": "Allow",
  "Action": [
      "s3:GetObject"
  ],
  "Resource": "*"
}

This means:

Can Read S3 Objects

Another example:

Allow

EC2 Start

EC2 Stop

EC2 Describe

A policy never logs in.

A policy never authenticates.

It only defines permissions.

Think of a Driving License

Imagine this:

Person
     │
     ▼
Driving License

The person is the identity.

The license defines what they are allowed to drive.

The license is like an IAM Policy.

3. IAM Role

Now let's look at the service side.

EC2

Can an EC2 log in with a password?

No.

Can it own an Access Key forever?

Also no.

Instead:

EC2
 │
 ▼
IAM Role

The role gives the EC2 permissions.

Example:

Can Read S3

Can Read Secrets Manager

Can Write CloudWatch Logs

4. Instance Profile

This is the term that confuses almost everyone.

Question

Can EC2 directly attach an IAM Role?

Answer: No.

AWS uses an intermediate object called an Instance Profile.

IAM Role
      │
      ▼
Instance Profile
      │
      ▼
EC2

The Instance Profile is essentially the container that allows an IAM Role to be associated with an EC2 instance.

Why Does AWS Need It?

It's simply part of the EC2 design. When you attach a role to an EC2 instance through the console or Terraform, AWS automatically uses an Instance Profile behind the scenes.

In Terraform

Remember when we created:

resource "aws_iam_instance_profile" "ec2_profile" {
  role = aws_iam_role.ec2_role.name
}

Then:

iam_instance_profile = aws_iam_instance_profile.ec2_profile.name

Now you know why that resource exists.

================================================================================================================================

5. STS (Security Token Service)

Now the EC2 has:

An IAM Role
An Instance Profile

But it still doesn't have credentials.

So what happens?

EC2
 │
 ▼
Instance Metadata Service
 │
 ▼
STS
 │
 ▼
Temporary Credentials

STS creates credentials like:

Access Key

Secret Key

Session Token

But unlike IAM User credentials, these are temporary and expire automatically.

Complete Flow

Let's connect everything.

                 IAM Policy
                      ▲
                      │
                Attached To
                      │
                 IAM Role
                      │
                      ▼
             Instance Profile
                      │
                      ▼
                   EC2
                      │
                      ▼
Instance Metadata Service (IMDS)
                      │
                      ▼
                    STS
                      │
                      ▼
Temporary Credentials
                      │
                      ▼
                AWS Services

Real Example (Our Future Lab)

Imagine our EC2 needs to read a password from Secrets Manager.

Application
      │
      ▼
AWS SDK
      │
      ▼
IMDS
      │
      ▼
STS Credentials
      │
      ▼
Secrets Manager
      │
      ▼
Password Returned

Notice something important:

The application never stores a password for AWS itself. Authentication is handled by IAM Roles and temporary credentials.

Analogy

Imagine a company office.

AWS Component	                        Real World Analogy
IAM User	                        Employee
IAM Policy	                        Access permissions (which rooms you may enter)
IAM Role	                       Job role (Database Admin, Security Officer, etc.)
Instance Profile	               Employee ID card linked to your job role
STS	                               Security desk issuing a temporary visitor/access pass
EC2	                               Employee entering the building
Secrets Manager	                       Secure locker containing confidential information

Engineering Perspective

For the type of platform engineering you're targeting, remember these three rules:

Humans authenticate with IAM Users (or modern identity systems such as IAM Identity Center).
AWS resources authenticate with IAM Roles.
Permissions are always defined by IAM Policies.

Everything else—Instance Profiles, STS, and the Instance Metadata Service—exists to make those three principles work securely.

=========================================================================================================================

📘 Module 07 – Lesson 3

AWS Secrets Management

Today we'll answer one simple question:

"Where should an application store its secrets?"

First, What is a Secret?

A secret is any sensitive information that should not be exposed.

Examples:

Database Password

API Key

AWS Credentials

TLS Private Key

OAuth Token

JWT Signing Key

SSH Private Key

Encryption Key

Real Example

Imagine our AUSF-UDM application needs to connect to a database.

It needs:

Username = udm

Password = Nokia@123

Where should we store this password?

❌ Option 1 – Hardcode in Code

password="Nokia@123"

Never.

Why?

Because anyone with access to the code can see it.

❌ Option 2 – Store in Terraform

db_password = "Nokia@123"

Also bad.

Why?

Terraform state stores values.

Someone with access to the state file can read them.

❌ Option 3 – Store in Git

password: Nokia@123

This is one of the most common security mistakes.

Never commit secrets to Git.

So Where Should We Store Them?

AWS provides dedicated services.

                Secrets
                    │
      ┌─────────────┴──────────────┐
      │                            │
      ▼                            ▼
Parameter Store          Secrets Manager

Both store secrets securely.

But they have different purposes.

AWS Systems Manager Parameter Store

Think of it as a secure configuration storage.

It stores:

Application Name

Environment

Database Host

Port

Feature Flags

API URL

Passwords

Tokens

Example:

/database/host

/database/password

/application/version

It Supports Two Types
String
Region = us-east-1

Stored as plain text.

SecureString
Database Password

Encrypted using KMS.

AWS Secrets Manager

Secrets Manager is designed specifically for sensitive secrets.

Examples:

Database Password

Oracle Password

PostgreSQL Password

MySQL Password

MongoDB Password

API Tokens
Certificates

Biggest Feature

Automatic Rotation.

Imagine:

Today:

Password = abc123

After 30 days:

Password = x9hk82

Applications continue working because Secrets Manager updates the secret.

Nobody manually changes it.

This is extremely useful for databases and long-lived credentials.

Parameter Store vs Secrets Manager

Parameter Store	                         Secrets Manager
Configuration	                         Secrets
Can store passwords	                 Yes
Automatic rotation	                 No (not built-in)
Database integrations	                 Limited
Cost	                                 Lower
Best for	                         Configurations and simple secrets

Where Does KMS Fit?

People often confuse KMS with Secrets Manager.

It is not a secret storage service.

KMS stands for:

Key Management Service

Its job is:

Encrypt

Decrypt

Rotate Keys

Manage Encryption Keys

Think of it like this.

Secrets Manager

Stores the secret.
Password

KMS

Protects the secret.

Encrypt Password

Architecture

Application
      │
      ▼
Secrets Manager
      │
      ▼
Encrypted Secret
      │
      ▼
KMS Key

Example

Suppose the password is:

Nokia@123

Secrets Manager doesn't simply save it.

Instead:

Nokia@123
       │
       ▼
Encrypted
       │
       ▼
AH78dj8QK...

Only KMS can decrypt it.

Complete Flow

Let's see how everything works together.

EC2
 │
 ▼
IAM Role
 │
 ▼
STS Credentials
 │
 ▼
Secrets Manager
 │
 ▼
KMS
 │
 ▼
Decrypt Secret
 │
 ▼
Application Gets Password

Notice something important.

The application never stores:

Access Key
Secret Key
Database Password

Everything is retrieved securely.

How Will This Work in EKS?

Exactly the same.

Pod
 │
 ▼
IAM Role
 │
 ▼
Secrets Manager
 │
 ▼
KMS
 │
 ▼
Database Password

Only the identity changes (EC2 vs Pod). The security model stays the same.

======================================================================================

Application
      │
      ▼
Needs Database Password
      │
      ▼
AWS SDK
      │
      ▼
Instance Metadata Service (IMDS)
      │
      ▼
STS
      │
      ▼
Temporary AWS Credentials
      │
      ▼
AWS SDK calls Secrets Manager
      │
      ▼
Secrets Manager checks IAM Role permissions
      │
      ▼
Secrets Manager asks KMS to decrypt the secret
      │
      ▼
KMS decrypts the secret
      │
      ▼
Secrets Manager returns the plaintext password
      │
      ▼
Application connects to Database

Let's Understand It Like a Security Gate

Imagine this scenario.

Step 1

Application says:

"I need the database password."

Step 2

AWS SDK asks IMDS:

"Can I have AWS credentials?"

Step 3

IMDS contacts STS.

STS says:

"Here are temporary AWS credentials."

Notice:

STS did NOT give the password.

It only gave the identity to prove who you are.

Step 4

Now the application goes to Secrets Manager.

Application
      │
      ▼
Secrets Manager

Application says:

"Here are my temporary credentials. I need the secret."

Step 5

Secrets Manager checks:

IAM Role
      │
      ▼
Allowed?

If the IAM Role has permission:

secretsmanager:GetSecretValue

then access is granted.

Step 6

Secrets Manager has an encrypted value.

Encrypted Secret
        │
        ▼
KMS

KMS decrypts it.

Step 7

Secrets Manager returns:

Database Password

Finally,

Application
      │
      ▼
Connect Database
The Most Important Point

Many beginners think:

STS
     │
     ▼
Password

❌ That's incorrect.

Instead:

STS
     │
     ▼
Temporary AWS Credentials

and

Secrets Manager
     │
     ▼
Database Password

These are two completely different things.

What is AWS SDK?

SDK = Software Development Kit

Think of it as a library that AWS provides so your application can communicate with AWS services without you writing all the low-level API code yourself.

Instead of manually creating HTTP requests to AWS APIs, your application simply calls an SDK function.

Without SDK (Very Difficult)

Imagine your application wants a secret.

You would have to:

Build an HTTPS request
Sign the request using AWS Signature Version 4
Add authentication headers
Handle retries
Parse the JSON response
Handle errors

That's a lot of work.

With AWS SDK (Easy)

In Python:

import boto3

client = boto3.client("secretsmanager")

response = client.get_secret_value(
    SecretId="database-password"
)

That's all.

The SDK does everything else for you.

ifferent Languages Have Different SDKs
Programming Language	AWS SDK
Python	boto3
Java	AWS SDK for Java
Go	AWS SDK for Go
Node.js	AWS SDK for JavaScript
C#	AWS SDK for .NET

So when someone says:

"The application uses the AWS SDK"

they mean it's using one of these libraries.

In Our Terraform EC2 Lab

Right now, our EC2 instance doesn't have an application installed.

Later, imagine we deploy a Python application.

That application might contain:

import boto3

Here:

boto3 = AWS SDK for Python
boto3 automatically gets credentials from IMDS
boto3 automatically calls Secrets Manager
Your application never sees an AWS Access Key in its code
One Small Correction to Our Flow

Earlier I said:

"AWS SDK asks IMDS."

A more precise way to say it is:

Application
      │
      ▼
Calls AWS SDK
      │
      ▼
AWS SDK requests temporary credentials from IMDS
      │
      ▼
IMDS provides STS-issued temporary credentials
      │
      ▼
AWS SDK calls Secrets Manager
      │
      ▼
Secrets Manager uses KMS to decrypt the secret
      │
      ▼
AWS SDK returns the secret to the application

This is the complete and accurate flow.

=====================================================================================================================

📘 Module 07 – Lesson 4

IAM Policies (Authorization)

So far we've learned:

Application
      │
      ▼
AWS SDK
      │
      ▼
IMDS
      │
      ▼
STS
      │
      ▼
Temporary Credentials

Now let's answer:

"Once AWS knows who I am, how does it decide what I'm allowed to do?"

This is called Authorization.

Authentication vs Authorization

These are the two most important security concepts.

Authentication
Who are you?

Examples:

IAM User
IAM Role
STS
IMDS

Authentication proves identity.

Authorization
What are you allowed to do?

Examples:

Read S3
Start EC2
Read Secrets
Delete VPC

Authorization determines permissions.

AWS Security Flow

Think of AWS security like airport security.

Passport
      │
      ▼
Authentication
      │
      ▼
Security Check
      │
      ▼
Authorization
      │
      ▼
Allowed into Airport

AWS works exactly the same way.

What is an IAM Policy?

An IAM Policy is simply a permission document.

It answers questions like:

Can I read S3?

Can I create EC2?

Can I access Secrets Manager?

Can I delete EBS?

IAM Policy Structure

Every policy has a few important parts.

{
  "Effect": "Allow",

  "Action": "...",

  "Resource": "..."
}

Don't worry about JSON yet.

Let's understand each field.

1. Effect

This tells AWS whether to allow or deny.

Allow

or

Deny

Example:

Allow

means

Permission Granted

2. Action

Action answers:

What operation?

Examples:

ec2:StartInstances

ec2:StopInstances

s3:GetObject

secretsmanager:GetSecretValue

kms:Decrypt

Every AWS service has hundreds of actions.

3. Resource

Resource answers:

On which resource?

Example:

One specific S3 Bucket

One Secret

One EC2

All EC2

Example

Imagine we want our application to read a secret.

Policy:

Effect
  Allow

Action
  Get Secret

Resource
  Database Password

AWS reads it like this:

Allow

to perform

GetSecretValue

on

Database Password

Complete Flow

Now let's connect everything.

Application
      │
      ▼
IAM Role
      │
      ▼
STS Credentials
      │
      ▼
Secrets Manager
      │
      ▼
Checks IAM Policy
      │
      ▼
Allowed?
      │
 ┌────┴─────┐
 │          │
Yes         No
 │          │
 ▼          ▼
Return     Access
Secret     Denied

Notice something.

Secrets Manager doesn't decide.

It simply asks IAM:

Does this role have permission?

Example 1

Suppose our EC2 Role has:

Allow

Read Secret

Application asks:

Get Database Password

AWS checks:

Role

↓

Policy

↓

Allowed

Password returned.

Example 2

Suppose someone tries:

Delete EC2

But policy only allows:

Read Secret

AWS says:

Access Denied

Because there is no permission.

Least Privilege Principle

This is one of the most important AWS security principles.

Give only the permissions that are required.

Bad:

Administrator Access

Good:

Read one secret

Read one S3 bucket

Write CloudWatch logs

Nothing more.

Real Example (Future EKS)

Imagine:

AI Application

Needs:

Read Model
Read Database Password

Does it need permission to:

Delete EC2?

No.

Delete VPC?

No.

So its IAM Role should only include:

Read Secret

Read S3 Model

Write Logs

This limits the impact if the application is compromised.

====================================================================================================================================

📘 Module 07 – Final Lesson

IAM Trust Policy & AssumeRole

This is the last missing piece.

After this lesson, IAM should "click."

First Understand This

An IAM Role has TWO completely different policies.

               IAM Role
                  │
      ┌───────────┴───────────┐
      │                       │
      ▼                       ▼
 Trust Policy          Permission Policy

Don't confuse them.

Trust Policy

It answers:

Who is allowed to use this role?

Example:

EC2

Lambda

EKS

Another AWS Account

IAM User

Permission Policy

It answers:

Once someone has the role, what can they do?

Example

Read S3

Read Secrets Manager

Write CloudWatch Logs

Read Parameter Store

Example

Suppose we create

Role

Platform-EC2-Role

Trust Policy

Trust

EC2

Permission Policy

Read S3

Read Secrets

Read Parameter Store

Complete Authentication Flow

Let's finally put everything together.

Application
      │
      ▼
AWS SDK
      │
      ▼
IMDS
      │
      ▼
IAM Role
      │
      ▼
Trust Policy
      │
      ▼
Can EC2 assume this role?
      │
      ▼
YES
      │
      ▼
STS
      │
      ▼
Temporary Credentials
      │
      ▼
Permission Policy
      │
      ▼
Allowed to Get Secret?
      │
      ▼
YES
      │
      ▼
Secrets Manager
      │
      ▼
KMS
      │
      ▼
Database Password

Notice there are two permission checks.

First Check

Can EC2 use this role?

This is the

Trust Policy

Second Check
Can this role read Secrets Manager?

This is the

Permission Policy
This Is AssumeRole

Now let's understand the word.

People think

AssumeRole

means

Create Role

No.

It means

Temporarily become this role.

Example

EC2 boots.

It says

I want to become Platform-EC2-Role.

AWS replies

Trust Policy

↓

EC2 allowed?

↓

YES

↓

STS issues credentials

Now EC2 is operating as that role.

Why STS Needs Trust Policy

Suppose someone else tries.

Lambda

tries to use

Platform-EC2-Role

Trust Policy says

Only EC2

STS replies

No

You cannot assume this role.

No credentials issued.

Real Terraform

Remember this?

resource "aws_iam_role" "ec2_role" {

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

}

Today you finally know every line.

Principal
Who?

EC2
Action
What?

AssumeRole

Meaning

EC2

↓

May become this role
Effect
Allow

Production Example

Suppose tomorrow we deploy

AI Inference Service

on EKS.

It needs

Read Model
Read Database Password

The flow becomes

Pod

↓

IAM Role

↓

Trust Policy

↓

STS

↓

Temporary Credentials

↓

Permission Policy

↓

Secrets Manager

↓

KMS

↓

Password

↓

Database

Exactly the same architecture.

Only EC2 becomes Pod.

Everything else stays identical.

⭐ Engineering Notes (Final Cheat Sheet)
IAM User
    │
Human Identity

IAM Role
    │
AWS Identity

Trust Policy
    │
Who can use the role?

Permission Policy
    │
What can the role do?

Instance Profile
    │
Attach Role to EC2

IMDS
    │
Metadata service inside EC2

STS
    │
Issues temporary credentials

AWS SDK
    │
Uses credentials automatically

Secrets Manager
    │
Stores secrets

KMS
    │
Encrypts/Decrypts secrets

=================================================================================================================================
