# Terraform + EKS Application Deployment + GitOps

## 1. Session Objective

This session connected the Terraform infrastructure track with practical
application deployment on EKS.

The focus was to understand how Terraform-provisioned EKS can be used as
the platform for application deployment, packaging, service exposure,
release lifecycle, GitOps reconciliation, and operational automation.

Core flow:

``` text
Terraform
   ↓
AWS Infrastructure / EKS
   ↓
Kubernetes
   ↓
Application
   ↓
Service
   ↓
Helm
   ↓
Git / GitHub
   ↓
Argo CD
   ↓
Reconciliation
   ↓
Kubernetes application state
```

------------------------------------------------------------------------

## 2. Responsibility Boundaries

  Component      Primary responsibility
  -------------- -----------------------------------------------------
  Terraform      Infrastructure and platform provisioning
  AWS / EKS      Managed Kubernetes platform
  Kubernetes     Application runtime
  Helm           Application packaging and templating
  Git / GitHub   Desired application configuration / source of truth
  Argo CD        GitOps reconciliation
  Deployment     Maintains application replicas
  Service        Stable application networking

Important boundary:

``` text
Terraform
→ Infrastructure / EKS / platform foundation

Git + Helm + Argo CD
→ Application desired state and deployment lifecycle

Kubernetes
→ Actual application runtime
```

------------------------------------------------------------------------

## 3. Kubernetes Application Deployment

The application used in the lab was `agent01` in namespace `agent01`.

The Deployment controlled the desired number of replicas.

``` bash
kubectl get deployment -n agent01
kubectl get rs -n agent01
kubectl get pods -n agent01 -o wide
```

Relationship:

``` text
Deployment
    ↓
ReplicaSet
    ↓
Pods
```

The application was exposed internally with a ClusterIP Service:

``` bash
kubectl get svc -n agent01
kubectl get endpoints -n agent01
```

Observed service:

``` text
Type: ClusterIP
Port: 80/TCP
```

The lab also showed the Kubernetes warning that the older `Endpoints`
API is deprecated in favor of EndpointSlice.

------------------------------------------------------------------------

## 4. Helm Application Packaging

A Helm chart was created:

``` text
agent01-chart/
├── Chart.yaml
├── values.yaml
└── templates/
    ├── NOTES.txt
    ├── _helpers.tpl
    ├── deployment.yaml
    ├── hpa.yaml
    ├── httproute.yaml
    ├── ingress.yaml
    ├── service.yaml
    ├── serviceaccount.yaml
    └── tests/
        └── test-connection.yaml
```

`Chart.yaml` defined an application chart:

``` yaml
apiVersion: v2
type: application
version: 0.1.0
appVersion: "1.0.0"
```

The important Helm model was:

``` text
values.yaml
      ↓
Helm templates
      ↓
Rendered Kubernetes manifests
```

Example:

``` yaml
replicaCount: 2

image:
  repository: nginx
  tag: latest
  pullPolicy: IfNotPresent

service:
  type: ClusterIP
  port: 80
```

The Deployment template consumed values such as:

``` yaml
replicas: {{ .Values.replicaCount }}
```

and:

``` yaml
image: "{{ .Values.image.repository }}:{{ .Values.image.tag | default .Chart.AppVersion }}"
```

The `_helpers.tpl` file provided reusable naming and label logic.

------------------------------------------------------------------------

## 5. Helm Rendering and Validation

The chart was rendered locally:

``` bash
helm template agent01 agent01-chart
```

This demonstrated:

``` text
Helm values + templates
        ↓
Rendered Kubernetes YAML
```

The chart was validated:

``` bash
helm lint agent01-chart
```

Result:

``` text
1 chart(s) linted, 0 chart(s) failed
```

------------------------------------------------------------------------

## 6. Helm Release Lifecycle

Install:

``` bash
helm install agent01 agent01-chart -n agent01
```

Check:

``` bash
helm list -n agent01
helm status agent01 -n agent01
```

Upgrade:

``` bash
helm upgrade agent01 agent01-chart -n agent01
```

History:

``` bash
helm history agent01 -n agent01
```

The lab demonstrated:

``` text
Revision 1 → Install complete
Revision 2 → Upgrade complete
```

Rollback:

``` bash
helm rollback agent01 1 -n agent01
```

Important concept:

``` text
Install  → Revision 1
Upgrade  → Revision 2
Rollback → Revision 3
```

Rollback does not erase history; the rollback itself becomes a new
revision.

Useful inspection commands:

``` bash
helm status agent01 -n agent01
helm get manifest agent01 -n agent01
helm get values agent01 -n agent01
```

A syntax mistake was encountered:

``` bash
helm get values.yaml agent01 -n agent01
```

Correct syntax:

``` bash
helm get values agent01 -n agent01
```

When no user-supplied values were passed, Helm showed:

``` text
USER-SUPPLIED VALUES:
null
```

This does not mean the chart has no `values.yaml`; it means no
release-specific user values were supplied.

------------------------------------------------------------------------

## 7. Argo CD and GitOps

Argo CD was already installed in the EKS cluster and verified:

``` bash
kubectl get svc -n argocd
kubectl get pods -n argocd
```

The Argo CD UI was accessed through local port forwarding.

The application created for the lab was:

``` text
Application: agent01-gitops
Project: default
Repository: https://github.com/Xprakasho/aws-terraform-learning.git
Path: labs/terraform-modules/k8s/agent01/agent01-chart
Revision: HEAD
Destination: in-cluster
Namespace: agent01
```

The application initially appeared as:

``` text
Missing / OutOfSync
```

After synchronization:

``` text
Healthy / Synced
```

------------------------------------------------------------------------

## 8. GitOps Reconciliation Experiment

This was the main experiment of the session.

### Initial desired state

The chart had:

``` yaml
replicaCount: 4
```

After synchronization:

``` bash
kubectl get deployment agent01-gitops -n agent01
```

showed:

``` text
agent01-gitops   4/4   4   4
```

Four Pods were running.

### Change desired state in Git

The value was changed:

``` text
replicaCount: 4
```

to:

``` text
replicaCount: 2
```

The change was committed and pushed:

``` bash
git add labs/terraform-modules/k8s/agent01/agent01-chart/values.yaml
git commit -m "scale agent01 gitops deployment to 2 replicas"
git push origin main
```

### Argo CD detects drift

Argo CD then showed:

``` text
Healthy + OutOfSync
```

Meaning:

-   **Healthy** → the currently running workload was operational.
-   **OutOfSync** → the live cluster state differed from the Git desired
    state.

Conceptually:

``` text
Git desired state       Cluster actual state
replicas: 2             replicas: 4
       │                       │
       └──────── mismatch ─────┘
                    ↓
                OutOfSync
```

### Argo CD Sync

After clicking Sync in Argo CD, reconciliation changed the Deployment:

``` bash
kubectl get deployment agent01-gitops -n agent01
```

Result:

``` text
agent01-gitops   2/2   2   2
```

Pod verification:

``` bash
kubectl get pods -n agent01 \
  -l app.kubernetes.io/instance=agent01-gitops
```

Result: two Pods, both `1/1 Running`.

Argo CD returned to:

``` text
Healthy + Synced
```

Complete flow:

``` text
values.yaml
replicaCount: 4
       │
       ▼
Git commit + push
       │
       ▼
GitHub
       │
       ▼
Argo CD detects difference
       │
       ▼
Healthy + OutOfSync
       │
       ▼
Argo CD Sync
       │
       ▼
Kubernetes Deployment
       │
       ▼
4 replicas → 2 replicas
       │
       ▼
Healthy + Synced
```

This demonstrated GitOps reconciliation without manually applying the
Deployment or performing a Helm upgrade for the GitOps-managed
application change.

------------------------------------------------------------------------

## 9. Healthy vs Synced

These are different concepts:

  State       Meaning
  ----------- -------------------------------------------
  Healthy     The live workload is functioning
  OutOfSync   Live state differs from Git desired state
  Synced      Live state matches Git desired state

Therefore:

``` text
Healthy + OutOfSync
```

is valid.

A workload can be operational while still being different from the
desired configuration stored in Git.

------------------------------------------------------------------------

## 10. Terraform vs Helm vs Argo CD

### Terraform

Primary role:

-   AWS infrastructure
-   VPC and networking
-   EKS
-   IAM
-   EKS add-ons / platform components
-   Supporting infrastructure

### Helm

Primary role:

-   Kubernetes application packaging
-   Reusable templates
-   Values-based configuration
-   Application release packaging

### Git

Primary role:

-   Desired application configuration
-   Version history
-   Reviewable changes
-   Audit trail

### Argo CD

Primary role:

-   GitOps reconciliation
-   Drift detection
-   Synchronization
-   Application deployment lifecycle

### Kubernetes

Primary role:

-   Running the application
-   Scheduling Pods
-   Maintaining replicas
-   Service discovery and networking
-   Runtime health

------------------------------------------------------------------------

## 11. Practical Command Reference

### Kubernetes

``` bash
kubectl get deployment -n agent01
kubectl get rs -n agent01
kubectl get pods -n agent01 -o wide
kubectl get svc -n agent01
kubectl get endpoints -n agent01
kubectl get all -n agent01
```

### Helm

``` bash
helm create agent01-chart
helm lint agent01-chart
helm template agent01 agent01-chart
helm install agent01 agent01-chart -n agent01
helm list -n agent01
helm status agent01 -n agent01
helm upgrade agent01 agent01-chart -n agent01
helm history agent01 -n agent01
helm rollback agent01 1 -n agent01
helm get manifest agent01 -n agent01
helm get values agent01 -n agent01
helm delete agent01 -n agent01
```

### Git

``` bash
git status
git add <file>
git commit -m "message"
git push origin main
```

### Argo CD

``` bash
kubectl get pods -n argocd
kubectl get svc -n argocd
kubectl get applications -n argocd
```

------------------------------------------------------------------------

## 12. Cleanup and Verification

The lab was cleaned up after the experiment.

Terraform state:

``` bash
terraform state list
```

Result:

``` text
empty
```

Terraform state inspection:

``` bash
terraform show
```

Result:

``` text
The state file is empty. No resources are represented.
```

EKS verification:

``` bash
aws eks list-clusters --region us-east-1
```

Result:

``` json
{
  "clusters": []
}
```

The VPC check showed only the AWS default VPC:

``` text
IsDefault: true
CIDR: 172.31.0.0/16
```

The default VPC was preserved.

Final state:

``` text
Terraform-managed resources → 0
EKS clusters                → 0
Lab infrastructure          → Clean
AWS default VPC             → Preserved
```

------------------------------------------------------------------------

## 13. Key Lessons

1.  Terraform provides the infrastructure foundation; it does not need
    to own every application deployment object.
2.  EKS provides the Kubernetes platform on which the application runs.
3.  Helm packages Kubernetes applications and separates configuration
    from templates.
4.  `helm template` shows the manifests Helm will render.
5.  Helm revisions provide release history and rollback capability.
6.  Git provides version-controlled desired state for GitOps-managed
    applications.
7.  Argo CD compares Git desired state with Kubernetes live state.
8.  `Healthy` and `Synced` answer different questions.
9.  `Healthy + OutOfSync` means the application may be functioning while
    differing from Git.
10. Argo CD synchronization reconciles Kubernetes with Git.
11. Terraform and Argo CD are separate control planes for different
    layers.
12. The final architecture combines infrastructure automation with
    application GitOps.

------------------------------------------------------------------------

## 14. Final Mental Model

``` text
                INFRASTRUCTURE LAYER

                    Terraform
                        │
                        ▼
                AWS / VPC / EKS
                        │
                        ▼
                PLATFORM LAYER
                        │
                        ▼
                   Kubernetes
                        │
          ┌─────────────┴─────────────┐
          │                           │
          ▼                           ▼
        Helm                       Argo CD
          │                           │
          │                           ▼
          │                         Git
          │                           │
          └──── Application ──────────┘
                        │
                        ▼
                   Deployment
                        │
                        ▼
                       Pods
```

### One-line summary

> **Terraform builds the platform, Helm packages the application, Git
> stores the desired state, Argo CD reconciles it, and Kubernetes runs
> it.**
