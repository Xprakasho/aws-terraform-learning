
📘 Module 07 – AWS Identity & Secrets

Q1. Why shouldn't we store AWS Access Keys on EC2?

Answer:
Because permanent credentials are a security risk. AWS recommends attaching an IAM Role so the instance receives temporary credentials automatically.

Q2. What is an IAM Role?

Answer:
An IAM Role is an AWS identity that contains permissions and can be assumed by AWS services such as EC2, Lambda, or EKS. It does not have permanent credentials.

Q3. What is STS?

Answer:
STS (Security Token Service) issues temporary security credentials that AWS services and users can use to access AWS resources securely.

Q4. What is the Instance Metadata Service?

Answer:
The Instance Metadata Service (IMDS) is available inside every EC2 instance and provides instance information and temporary IAM credentials associated with the attached IAM Role.

Key Takeaways (Remember These)
IAM User → Human identity with long-term credentials (when needed).
IAM Role → Identity with permissions that AWS services can assume.
STS → Issues temporary credentials.
IMDS → Delivers those temporary credentials to the EC2 instance.
Best Practice → Use IAM Roles for EC2 instead of storing Access Keys.

Interview Questions
Q1. What is the difference between an IAM User and an IAM Role?

Answer:
An IAM User represents a human identity with long-term credentials. An IAM Role is an AWS identity with permissions that is assumed by AWS services or users and typically uses temporary credentials.

Q2. What is an Instance Profile?

Answer:
An Instance Profile is the mechanism that allows an IAM Role to be attached to an EC2 instance. EC2 instances receive IAM Role permissions through the Instance Profile.

Q3. Does an IAM Policy authenticate anyone?

Answer:
No. An IAM Policy only defines permissions. Authentication is handled by IAM Users, IAM Roles, or federated identities.

Q4. Why does AWS use STS?

Answer:
STS issues temporary security credentials, reducing the risks associated with long-term access keys and enabling secure access to AWS services.

Engineering Perspective

For the type of platform engineering you're targeting, remember these three rules:

Humans authenticate with IAM Users (or modern identity systems such as IAM Identity Center).
AWS resources authenticate with IAM Roles.
Permissions are always defined by IAM Policies.

Everything else—Instance Profiles, STS, and the Instance Metadata Service—exists to make those three principles work securely.

Interview Questions
Q1. Why shouldn't secrets be stored in Git?

Answer:
Git repositories are widely accessible within teams and preserve history. Once a secret is committed, it may remain recoverable even after deletion.

Q2. What is the difference between Parameter Store and Secrets Manager?

Answer:
Parameter Store is commonly used for configuration values and can also store encrypted values. Secrets Manager is purpose-built for sensitive credentials and supports features such as automatic rotation.

Q3. Does KMS store passwords?

Answer:
No. KMS manages encryption keys. Services like Secrets Manager and Parameter Store use KMS to encrypt and decrypt stored values.

Q4. How does an EC2 access Secrets Manager?

Answer:
The EC2 uses its IAM Role to obtain temporary credentials via STS. With the appropriate IAM permissions, it requests the secret from Secrets Manager, which uses KMS to decrypt the stored value before returning it.

Engineering Mindset

Whenever you're working on a cloud platform, ask yourself these four questions:

Who is requesting the secret? (EC2, Pod, Lambda, etc.)
How is it authenticated? (IAM Role + STS)
Where is the secret stored? (Secrets Manager or Parameter Store)
How is it protected? (KMS)

QNS. Why do we prefer an IAM Role over hardcoded AWS Access Keys on an EC2 instance?
What is the purpose of STS?
When would you choose Secrets Manager instead of Parameter Store?
Does KMS store secrets, or does it perform a different role?

ANS. We use IAM Roles because they eliminate the need for permanent AWS Access Keys on EC2 instances. The instance automatically receives temporary credentials through STS, reducing the risk of credential leakage. Temporary credentials expire automatically and are managed by AWS, making them much more secure than long-lived access keys.

use Secrets Manager for sensitive credentials such as database passwords, API keys, and certificates, especially when automatic rotation is required. Parameter Store is better suited for application configuration values and simple encrypted parameters.

Q. Does STS know my database password?

Correct answer:

A. No. STS has no knowledge of application secrets. Its only job is to issue temporary AWS security credentials. Secrets are stored in services like AWS Secrets Manager and are typically encrypted using AWS KMS.

Interview Questions
Q1. What is the difference between Authentication and Authorization?

Answer:

Authentication verifies the identity of the user or service.
Authorization determines what actions that identity is permitted to perform.
Q2. What are the three main parts of an IAM Policy?

Answer:

Effect – Allow or Deny.
Action – The AWS API operation.
Resource – The AWS resource the action applies to.
Q3. What is the Principle of Least Privilege?

Answer:

Grant only the minimum permissions required for a user, role, or application to perform its tasks.

Architecture Summary.

Who are you?
        │
        ▼
IAM Role
        │
        ▼
What can you do?
        │
        ▼
IAM Policy
        │
        ▼
Access AWS Service

Interview Question

What is the difference between Trust Policy and Permission Policy?

Excellent answer:

A Trust Policy defines who can assume an IAM Role. A Permission Policy defines what actions are allowed after the role has been assumed.

What does sts:AssumeRole mean?

Answer:

It allows a trusted identity, such as an EC2 instance or Lambda function, to temporarily assume an IAM Role and receive temporary security credentials from AWS STS.

✅ Q1. What is the purpose of the Trust Policy?
The Trust Policy defines which AWS service, user, role, or AWS account is allowed to assume (use) the IAM Role.

✅ Q2. Why do we specify ec2.amazonaws.com instead of just EC2?
AWS identifies trusted services using Service Principals. ec2.amazonaws.com is the Service Principal for Amazon EC2.

✅ Q3. What does Action = "sts:AssumeRole" mean?
The trusted principal (EC2) is allowed to call the AWS STS AssumeRole API to obtain temporary credentials for this IAM Role.

Q4. If we change ec2.amazonaws.com to lambda.amazonaws.com, can EC2 assume the role?
No. The Trust Policy now trusts only Lambda. Since EC2 is no longer a trusted principal, AWS STS will not allow the EC2 instance to assume the role or receive temporary credentials.

✅ Q1. Why can't an EC2 instance use an IAM Role directly?
An EC2 instance cannot attach an IAM Role directly because AWS requires an Instance Profile as the container that associates the IAM Role with the EC2 instance. The Instance Profile acts as the bridge between EC2 and the IAM Role.

Q2. What is the purpose of an Instance Profile?
The Instance Profile allows an EC2 instance to assume and use an IAM Role. It connects the EC2 instance to the IAM Role.

Q1. Where are the AWS credentials stored on the EC2?

Correct answer:

They are not permanently stored. The application or AWS CLI retrieves temporary credentials from the Instance Metadata Service (IMDSv2), which receives them from AWS STS after the EC2 assumes its IAM Role via the attached Instance Profile.

Q2. Why did the Access Key start with ASIA instead of AKIA?

Correct answer:

ASIA indicates temporary credentials issued by AWS STS, while AKIA is typically associated with long-lived IAM User access keys.

3."If the JWT signature is valid, why does AWS still check the exp claim?"

A strong answer would be:

"A valid signature proves that the token was issued by the trusted identity provider and hasn't been modified. However, it does not limit how long the token can be used. The exp claim limits the token's lifetime, reducing the risk of replay attacks if the token is intercepted or stolen."

4."Is a JWT encrypted?"

A strong answer is:

"Not normally. A standard JWT is Base64URL encoded, which makes it transport-safe but does not provide confidentiality. The security comes from the digital signature, which ensures authenticity and integrity. Confidentiality during transmission is provided by HTTPS/TLS."

5. "Why doesn't JWT simply encrypt everything?"

Answer:

"Because the receiving system needs to inspect the claims. The goal is not to hide the repository, branch, or workflow. The goal is to ensure those claims were issued by a trusted identity provider and have not been modified."