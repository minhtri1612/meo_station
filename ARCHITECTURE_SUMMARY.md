# Architecture Summary - Meo Stationery K8s Setup

## Current Infrastructure Overview

### 1. Terraform Infrastructure (`terraform-infra/`)
**What it creates:**
- ✅ AWS VPC (10.0.0.0/16)
- ✅ 2 Public Subnets (10.0.1.0/24, 10.0.2.0/24)
- ✅ Internet Gateway
- ✅ Security Group (k8s-sg) with ports: 22, 6443, 80, 443, 30000-32767
- ✅ EC2 Instances:
  - 1 Master node (in subnet A)
  - 2 Worker nodes (in subnet B)
- ✅ IAM Role for EBS CSI Driver
- ✅ CloudWatch Dashboard & Alarms
- ✅ SSH Key Pair

**What's MISSING:**
- ❌ **NO DATABASE** (No RDS, no database subnet group, no database security group)
- ❌ No private subnets (only public subnets exist)

### 2. Kubernetes Setup (`k8s-ansible/`)
**Ansible Playbooks:**
- `all.yaml` - Prepares all nodes (install Docker, containerd, kubelet, kubeadm, kubectl, Helm)
- `master.yml` - Initializes Kubernetes master with `kubeadm init`
- `worker.yml` - Joins worker nodes with `kubeadm join`
- `install-storage.yaml` - Installs AWS EBS CSI Driver, creates `gp3` StorageClass
- `install-ingress.yaml` - Installs NGINX Ingress Controller
- `install-argocd.yaml` - Installs ArgoCD
- `install-apps.yaml` - Deploys ArgoCD applications

### 3. Helm Charts (`k8s_helm/`)

#### Database Chart (`k8s_helm/database/`)
**Current Setup:**
- PostgreSQL deployed as **Kubernetes StatefulSet** (NOT AWS RDS)
- Image: `postgres:13`
- Storage: Uses Kubernetes PVC with EBS CSI Driver (gp3 storage class)
- Service: ClusterIP on port 5432
- Credentials:
  - Username: `meo_admin`
  - Password: `MeoStationery2025!`
  - Database: `meo_stationery`
- Persistence: 1Gi PVC

#### Backend Chart (`k8s_helm/backend/`)
- Next.js application
- Image: `minhtri1612/meo-stationery-backend:vcl`
- Replicas: 2
- Service: ClusterIP port 80 → 3000
- Ingress: `meo-stationery.local`
- Database connection via: `postgres.meo-stationery.svc.cluster.local:5432`

### 4. Database Location - IMPORTANT!

**Current State:**
- Database is deployed **INSIDE Kubernetes** as a StatefulSet
- Database runs on one of the worker nodes
- Data stored in EBS volume attached to the worker node
- **NOT** a managed AWS RDS service

**This means:**
- Database lifecycle is managed by Kubernetes
- If you delete the StatefulSet, you might lose data (unless PVC is preserved)
- No automated backups (unless configured separately)
- Database runs on shared EC2 resources with other workloads

---

## Deployment Flow

1. **Terraform** → Creates EC2 instances (no database)
2. **Ansible `all.yaml`** → Prepares nodes for Kubernetes
3. **Ansible `master.yml`** → Initializes kubeadm master
4. **Ansible `worker.yml`** → Joins workers to cluster
5. **Ansible `install-storage.yaml`** → Sets up EBS CSI Driver
6. **Helm install database** → Deploys PostgreSQL StatefulSet in K8s
7. **Helm install backend** → Deploys backend application

---

## Options for Database

### Option 1: Keep Current Setup (PostgreSQL in Kubernetes)
**Pros:**
- Already working
- Simple, no extra AWS costs
- Full control over PostgreSQL version/config

**Cons:**
- Not highly available
- Managed by K8s (not AWS managed service)
- No automated backups
- Shares resources with other workloads

### Option 2: Add AWS RDS PostgreSQL to Terraform
**Pros:**
- AWS managed service (backups, updates, HA)
- Separate from Kubernetes cluster
- Better for production workloads
- Can have Multi-AZ for HA

**Cons:**
- Additional AWS costs (~$15-50/month for db.t3.micro)
- Need to:
  - Add private subnets (best practice for RDS)
  - Add DB subnet group
  - Add DB security group
  - Create RDS instance in Terraform
  - Update Helm chart to connect to RDS endpoint instead of K8s service

**What needs to be added to Terraform:**
- Private subnets (2 AZs)
- NAT Gateway (for private subnet outbound)
- DB Subnet Group
- DB Security Group
- RDS PostgreSQL Instance

---

## Current Configuration Files

### Database Helm Values (`k8s_helm/database/values.yaml`)
```yaml
auth:
  username: "meo_admin"
  password: "MeoStationery2025!"
  database: "meo_stationery"
persistence:
  size: 1Gi
  storageClassName: ""  # Uses default (gp3)
```

### Backend Database Connection (`k8s_helm/backend/templates/secret.yaml`)
```yaml
DATABASE_URL: "postgresql://meo_admin:MeoStationery2025!@postgres.meo-stationery.svc.cluster.local:5432/meo_stationery?schema=public"
```

---

## Recommendations

1. **For Development/Testing**: Current setup (K8s StatefulSet) is fine
2. **For Production**: Consider AWS RDS for:
   - Automated backups
   - High availability
   - Better security isolation
   - Easier scaling

---

## Next Steps (if adding RDS)

If you want to add AWS RDS to Terraform:
1. Add private subnets
2. Add NAT Gateway
3. Add DB subnet group
4. Add DB security group (allow 5432 from K8s nodes)
5. Add RDS PostgreSQL instance
6. Update backend Helm chart to use RDS endpoint
7. Update Ansible playbooks to configure backend with RDS connection

Would you like me to add RDS to your Terraform configuration?

