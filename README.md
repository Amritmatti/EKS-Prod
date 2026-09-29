# EKS on AWS - production-ready Terraform

Reusable `vpc` and `eks` modules composed per environment (`dev`, `staging`, `prod`).
Each environment has its own directory, state file and tfvars, so they can be
applied, versioned and access-controlled independently.

```
eks/
├── bootstrap/               # one-time: encrypted, versioned S3 bucket for remote state
├── modules/
│   ├── vpc/                 # multi-AZ VPC: public + private subnets, NAT, endpoints, flow logs
│   └── eks/                 # control plane, IAM, IRSA, managed node groups, add-ons, access entries
└── environments/
    ├── dev/                 # 2 AZs, single NAT, spot nodes, restricted public API
    ├── staging/             # 3 AZs, NAT per AZ, private API, mixed on-demand/spot
    └── prod/                # 3 AZs, NAT per AZ, private API, VPC endpoints, on-demand
```

`main.tf`, `variables.tf`, `outputs.tf`, `providers.tf` and `versions.tf` are identical
across environments; only `terraform.tfvars` and `backend.hcl` differ.

## Architecture

```
                         Internet
                            │
                    Internet Gateway
                            │
   ┌──────────── VPC 10.30.0.0/16 (3 AZs) ────────────────────────┐
   │  public  /24 x3   ── ALB/NLB (kubernetes.io/role/elb)        │
   │                   ── NAT gateway per AZ                      │
   │                            │                                 │
   │  private /19 x3   ── EKS managed nodes (no public IPs)       │
   │                   ── EKS control plane ENIs                  │
   │                   ── internal LBs (kubernetes.io/role/internal-elb)
   │                   ── VPC endpoints (ECR, STS, logs, SSM, ...)│
   └──────────────────────────────────────────────────────────────┘
```

## Security & reliability controls

| Area | Control |
|---|---|
| Network | Worker nodes and control plane ENIs only in private subnets; public subnets have `map_public_ip_on_launch = false` |
| Network | NAT gateway per AZ (prod) - one AZ outage doesn't cut egress for the others |
| Network | Default security group stripped of all rules; VPC flow logs (ALL traffic) |
| Network | S3 gateway endpoint + interface endpoints keep AWS API/ECR traffic off the internet |
| API | Private endpoint always on; public endpoint off in prod, CIDR allow-listed elsewhere (0.0.0.0/0 is rejected by validation) |
| Auth | Access entries (`authentication_mode = "API"`) - no `aws-auth` ConfigMap; creator admin off in prod |
| Encryption | Kubernetes Secrets envelope-encrypted with a rotating CMK; control plane logs encrypted with the same key |
| Encryption | Node root volumes gp3 and encrypted |
| Logging | All 5 control plane log types, with explicit retention |
| Nodes | IMDSv2 required, hop limit 1 (pods can't reach the node role); SSM Session Manager instead of SSH |
| IAM | Node role has no CNI permissions - VPC CNI and EBS CSI use IRSA roles scoped to their service accounts |
| Scaling | Managed node groups with `desired_size` ignored so Cluster Autoscaler/Karpenter own scaling; auto node repair; rolling updates at 33% max unavailable |
| Networking | VPC CNI prefix delegation (higher pod density) and NetworkPolicy enforcement enabled |
| Upgrades | Managed add-ons pinned to the EKS default version for the cluster version; `STANDARD` support type avoids surprise extended-support fees |
| Resilience | Zonal shift enabled |
| State | S3 backend: KMS encrypted, versioned, TLS-only, public access blocked, native locking (`use_lockfile`) |
| Safety | `allowed_account_ids` stops an env being applied to the wrong account |

## Usage

Requirements: Terraform >= 1.10, AWS provider ~> 6.0, AWS credentials for the target account.

```bash
# 1. One-time: state bucket
cd bootstrap
terraform init
terraform apply -var="bucket_name=myapp-terraform-state"

# 2. Fill in the CHANGE-ME values in environments/<env>/backend.hcl and terraform.tfvars
#    (bucket name, account IDs, admin role ARNs, allowed CIDRs, kubernetes_version)

# 3. Deploy an environment
cd ../environments/prod
terraform init -backend-config=backend.hcl
terraform plan -out=tfplan
terraform apply tfplan

# 4. kubectl (prod: from a network listed in api_allowed_cidrs, e.g. over VPN)
aws eks update-kubeconfig --region us-east-1 --name myapp-prod
```

Adding a new environment: copy an existing environment directory, then change
`terraform.tfvars` (use a unique `vpc_cidr`) and the `key` in `backend.hcl`.

## Notes / gotchas

- **Prod API is private-only.** Terraform itself only talks to AWS APIs, so `apply` works from
  anywhere, but `kubectl`/Helm must run from a network in `api_allowed_cidrs` (VPN, Direct Connect,
  bastion, or self-hosted CI runners in the VPC).
- **Don't lock yourself out.** With `enable_cluster_creator_admin_permissions = false`, make sure
  `access_entries` contains a role you can assume. Changing that flag later recreates the cluster.
- **IMDS hop limit 1.** Pods that call IMDS (e.g. AWS Load Balancer Controller for region/VPC ID)
  need those values passed explicitly (`--aws-region`, `--aws-vpc-id`) or use IRSA / Pod Identity.
  Set `node_metadata_hop_limit = 2` in the module call if you really need pod IMDS access.
- **Kubernetes upgrades:** bump `kubernetes_version` one minor at a time; the control plane
  upgrades first, then node groups roll, and add-ons move to the new default versions.
- **Customer-managed EBS key:** if you set `node_ebs_kms_key_arn`, its key policy must allow the
  `AWSServiceRoleForAutoScaling` service-linked role, or nodes will fail to launch.
- **VPC CIDR layout:** `/16` → private `/19` per AZ (pods use VPC IPs, so private subnets are
  large) and public `/24` per AZ taken from `x.x.240.0` upward.

## Recommended next steps (in-cluster)

These are deliberately left out so the infrastructure layer has no dependency on reaching the
Kubernetes API:

- Karpenter or Cluster Autoscaler (subnets are already tagged `karpenter.sh/discovery`)
- AWS Load Balancer Controller (IRSA role from `oidc_provider_arn`)
- A default encrypted `gp3` StorageClass
- metrics-server, external-dns, cert-manager, and an observability stack
- Pod Security Admission labels (`restricted`) on application namespaces
- GuardDuty EKS Protection / Runtime Monitoring at the account level
