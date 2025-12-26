# Meo Stationery - E-Commerce Platform

A modern, full-stack e-commerce platform for stationery products, built with Next.js and deployed on a Kubernetes cluster using Infrastructure as Code practices.

## 📋 Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Technology Stack](#technology-stack)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Project Structure](#project-structure)
- [Deployment](#deployment)
- [Access URLs](#access-urls)
- [Configuration](#configuration)
- [Monitoring](#monitoring)
- [Troubleshooting](#troubleshooting)
- [Development](#development)

## 🎯 Overview

Meo Stationery is an e-commerce web application featuring:
- Product catalog and search functionality
- Shopping cart and checkout system
- Order management system
- Admin dashboard for product and order management
- User authentication and authorization
- Payment integration (VNPay)

The application is fully containerized and deployed on a self-managed Kubernetes cluster on AWS EC2, with automated infrastructure provisioning using Terraform and configuration management using Ansible.

## 🏗️ Architecture

### Infrastructure Components

```
┌─────────────────────────────────────────────────────────────┐
│                    AWS Cloud (ap-southeast-2)               │
├─────────────────────────────────────────────────────────────┤
│  VPC (10.0.0.0/16)                                          │
│  ├── Public Subnet A (10.0.1.0/24)                         │
│  │   └── Master Node (Kubernetes Control Plane)            │
│  ├── Public Subnet B (10.0.2.0/24)                         │
│  │   ├── Worker Node 1                                      │
│  │   └── Worker Node 2                                      │
│  └── Internet Gateway                                       │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│              Kubernetes Cluster (Kubeadm)                   │
├─────────────────────────────────────────────────────────────┤
│  Namespace: meo-stationery                                  │
│  ├── PostgreSQL (StatefulSet)                               │
│  │   └── PersistentVolumeClaim (EBS CSI Driver)            │
│  ├── Backend (Deployment) - Next.js                         │
│  │   └── Replicas: 2                                        │
│  └── NGINX Ingress Controller                               │
│                                                              │
│  Namespace: argocd                                          │
│  └── ArgoCD (GitOps)                                        │
│                                                              │
│  Namespace: monitoring                                      │
│  ├── Prometheus                                             │
│  └── Grafana                                                │
└─────────────────────────────────────────────────────────────┘
```

### Data Flow

1. **External Traffic** → NGINX Ingress Controller → Backend Service
2. **Backend** → PostgreSQL Service (ClusterIP)
3. **Database** → Persistent Storage (EBS Volume)

## 🛠️ Technology Stack

### Frontend & Backend
- **Framework**: Next.js 15.2.4
- **Language**: TypeScript
- **Database ORM**: Prisma
- **Authentication**: NextAuth.js
- **UI Components**: shadcn/ui, Tailwind CSS

### Infrastructure & DevOps
- **IaC**: Terraform
- **Configuration Management**: Ansible
- **Container Orchestration**: Kubernetes (kubeadm)
- **Package Manager**: Helm
- **GitOps**: ArgoCD
- **Container Runtime**: containerd
- **Networking**: Calico CNI

### Cloud Services (AWS)
- **Compute**: EC2 (t3.medium instances)
- **Storage**: EBS (via EBS CSI Driver)
- **Networking**: VPC, Subnets, Internet Gateway
- **Monitoring**: CloudWatch

### Monitoring & Observability
- **Metrics Collection**: Prometheus
- **Visualization**: Grafana
- **Infrastructure Monitoring**: AWS CloudWatch
- **Logging**: Kubernetes native logging

### Database
- **Database**: PostgreSQL 13
- **Storage**: Kubernetes PersistentVolumeClaim with EBS backend

## 📦 Prerequisites

Before deploying, ensure you have:

- **AWS Account** with appropriate IAM permissions
- **Terraform** >= 1.0
- **Ansible** >= 2.19
- **kubectl** (for local cluster access, optional)
- **Helm** >= 3.13.3
- **SSH access** to EC2 instances
- **Git** for cloning the repository

### AWS Requirements
- AWS CLI configured with credentials
- Permissions to create: VPC, EC2, IAM roles, CloudWatch
- Default region: `ap-southeast-2` (configurable)

## 🚀 Quick Start

### Automated Deployment (Recommended)

1. **Clone the repository**
   ```bash
   git clone https://github.com/minhtri1612/meo_station.git
   cd meo_stationery-master
   ```

2. **Configure AWS credentials**
   ```bash
   aws configure
   ```

3. **Deploy everything**
   ```bash
   ./deploy.sh
   ```

   This single command will:
   - Create AWS infrastructure (VPC, EC2 instances)
   - Initialize Kubernetes cluster
   - Deploy database and backend application
   - Configure ingress and monitoring

4. **Access the application**
   ```
   http://meo-stationery.local
   ```

### Manual Deployment

See [DEPLOYMENT_GUIDE.md](./DEPLOYMENT_GUIDE.md) for step-by-step manual deployment instructions.

## 📁 Project Structure

```
meo_stationery-master/
├── terraform-infra/          # Infrastructure as Code
│   ├── main.tf               # Main Terraform configuration
│   ├── variables.tf          # Variable definitions
│   ├── outputs.tf            # Output values
│   └── cloudwatch.tf         # CloudWatch dashboards and alarms
│
├── k8s-ansible/              # Ansible playbooks for K8s setup
│   ├── all.yaml              # Prepare all nodes
│   ├── master.yml            # Initialize master node
│   ├── worker.yml            # Join worker nodes
│   ├── install-storage.yaml  # EBS CSI Driver installation
│   ├── install-ingress.yaml  # NGINX Ingress installation
│   ├── install-argocd.yaml   # ArgoCD installation
│   └── install-monitoring.yaml # Prometheus/Grafana setup
│
├── k8s_helm/                 # Helm charts
│   ├── database/             # PostgreSQL chart
│   │   ├── values.yaml
│   │   └── templates/
│   └── backend/              # Backend application chart
│       ├── values.yaml
│       └── templates/
│
├── argocd/                   # ArgoCD application manifests
│   ├── data-application.yaml
│   └── be-application.yaml
│
├── src/                      # Next.js application source
│   ├── app/                  # Next.js app directory
│   ├── components/           # React components
│   ├── lib/                  # Utilities and Prisma client
│   └── hooks/                # Custom React hooks
│
├── prisma/                   # Database schema and migrations
│   ├── schema.prisma
│   └── migrations/
│
├── deploy.sh                 # Automated deployment script
└── docker-compose.yaml       # Local development setup
```

## 🔧 Deployment

### Infrastructure Deployment

1. **Initialize Terraform**
   ```bash
   cd terraform-infra
   terraform init
   ```

2. **Plan and Apply**
   ```bash
   terraform plan
   terraform apply
   ```

3. **Get Outputs**
   ```bash
   terraform output
   ```

### Kubernetes Cluster Setup

The `deploy.sh` script automatically runs all Ansible playbooks in sequence:

1. `all.yaml` - Prepares all nodes (Docker, containerd, kubelet, kubeadm)
2. `master.yml` - Initializes Kubernetes master
3. `worker.yml` - Joins worker nodes to cluster
4. `install-storage.yaml` - Sets up EBS CSI Driver
5. `install-ingress.yaml` - Installs NGINX Ingress Controller
6. `install-argocd.yaml` - Deploys ArgoCD for GitOps
7. `install-monitoring.yaml` - Sets up Prometheus and Grafana

### Application Deployment

Applications are deployed via Helm charts:

```bash
# Database
helm install postgres k8s_helm/database -n meo-stationery --create-namespace

# Backend
helm install backend k8s_helm/backend -n meo-stationery
```

Or use ArgoCD for GitOps-based deployment (automated sync enabled).

## 🌐 Access URLs

After deployment, access the following services:

- **Main Application**: http://meo-stationery.local
- **ArgoCD**: http://argocd.local
  - Username: `admin`
  - Password: Get with: `kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d`
- **Grafana**: http://grafana.local (if monitoring is installed)
  - Username: `admin`
  - Password: `admin`
- **Prometheus**: http://prometheus.local (if monitoring is installed)
- **CloudWatch Dashboard**: https://console.aws.amazon.com/cloudwatch/home?region=ap-southeast-2#dashboards:name=K8s-Cluster-Dashboard

## ⚙️ Configuration

### Terraform Variables

Edit `terraform-infra/variables.tf` to customize:

```hcl
variable "region" {
  default = "ap-southeast-2"  # AWS region
}

variable "instance_type" {
  default = "t3.medium"       # EC2 instance type
}

variable "master_count" {
  default = 1                 # Number of master nodes
}

variable "worker_count" {
  default = 2                 # Number of worker nodes
}
```

### Helm Values

#### Database Configuration
Edit `k8s_helm/database/values.yaml`:

```yaml
auth:
  username: "meo_admin"
  password: "MeoStationery2025!"
  database: "meo_stationery"

persistence:
  size: 1Gi
```

#### Backend Configuration
Edit `k8s_helm/backend/values.yaml`:

```yaml
workload:
  image: minhtri1612/meo-stationery-backend:vcl
  resources:
    requests:
      memory: "256Mi"
      cpu: "128m"
    limits:
      memory: "2Gi"
      cpu: "1000m"

replicaCount: 2
```

### Environment Variables

Backend environment variables are managed through Kubernetes Secrets and ConfigMaps (defined in Helm templates).

## 📊 Monitoring

### CloudWatch
- **Dashboard**: K8s-Cluster-Dashboard
- **Metrics**: EC2 CPU utilization, network I/O, status checks
- **Alarms**: High CPU (>80%), status check failures

### Prometheus & Grafana
- **Metrics**: Kubernetes cluster metrics, pod metrics, custom application metrics
- **Dashboards**: Pre-configured dashboards for cluster monitoring
- **Retention**: 2 days (configurable)
- **Storage**: 2Gi PVC for Prometheus data

### Accessing Logs

```bash
# Backend logs
kubectl logs -n meo-stationery -l app.kubernetes.io/name=backend --tail=50

# Database logs
kubectl logs -n meo-stationery postgres-0 --tail=50

# All pods in namespace
kubectl get pods -n meo-stationery
```

## 🔍 Troubleshooting

### Common Issues

#### Pods Not Starting
```bash
# Check pod status
kubectl get pods -n meo-stationery

# Describe pod for details
kubectl describe pod <pod-name> -n meo-stationery

# Check events
kubectl get events -n meo-stationery --sort-by='.lastTimestamp'
```

#### Database Connection Issues
```bash
# Verify database pod is running
kubectl get pods -n meo-stationery | grep postgres

# Check database service
kubectl get svc postgres -n meo-stationery

# Test connection from backend pod
kubectl exec -n meo-stationery deployment/backend -- nc -zv postgres.meo-stationery.svc.cluster.local 5432
```

#### Ingress Not Working
```bash
# Check ingress controller
kubectl get pods -n ingress-nginx

# Verify ingress configuration
kubectl get ingress -n meo-stationery
kubectl describe ingress backend -n meo-stationery

# Check /etc/hosts on local machine
cat /etc/hosts | grep meo-stationery
```

#### ArgoCD Sync Issues
```bash
# Check ArgoCD application status
kubectl get application -n argocd

# View sync status
kubectl get application meo-station-database -n argocd -o yaml

# Manual sync (if needed)
# Use ArgoCD UI or CLI
```

### SSH Access

```bash
# Master node
ssh -i terraform-infra/k8s-key.pem ubuntu@<MASTER_IP>

# Worker node
ssh -i terraform-infra/k8s-key.pem ubuntu@<WORKER_IP>
```

### Cleanup

```bash
# Destroy infrastructure
cd terraform-infra
terraform destroy

# Or use deploy script
./deploy.sh destroy
```

## 💻 Development

### Local Development

1. **Start database with Docker Compose**
   ```bash
   docker-compose up -d postgres
   ```

2. **Set environment variables**
   ```bash
   cp .env.example .env
   # Edit .env with your database URL
   ```

3. **Install dependencies**
   ```bash
   npm install
   ```

4. **Run database migrations**
   ```bash
   npx prisma migrate dev
   ```

5. **Start development server**
   ```bash
   npm run dev
   ```

### Building Docker Image

```bash
docker build -t meo-stationery-backend:latest .
docker tag meo-stationery-backend:latest <your-registry>/meo-stationery-backend:v1
docker push <your-registry>/meo-stationery-backend:v1
```

### Updating Helm Charts

After making changes to Helm charts:

```bash
# Copy charts to master node
scp -r k8s_helm ubuntu@<MASTER_IP>:~/

# Upgrade release
ssh -i terraform-infra/k8s-key.pem ubuntu@<MASTER_IP>
helm upgrade postgres ~/k8s_helm/database -n meo-stationery
helm upgrade backend ~/k8s_helm/backend -n meo-stationery
```

## 📝 Notes

- **Database**: Currently deployed as Kubernetes StatefulSet with EBS storage. Consider AWS RDS for production workloads requiring high availability.
- **Secrets**: Database passwords and secrets are in Helm values files. Use Kubernetes Secrets or external secret management (e.g., AWS Secrets Manager) in production.
- **SSL/TLS**: Currently using HTTP. Configure TLS certificates (e.g., Let's Encrypt with cert-manager) for production.
- **Backups**: Implement regular database backups for production deployments.

## 📄 License

[Add your license here]

## 👥 Contributors

[Add contributors here]

## 🔗 Links

- **GitHub Repository**: https://github.com/minhtri1612/meo_station.git
- **Documentation**: See [DEPLOYMENT_GUIDE.md](./DEPLOYMENT_GUIDE.md)

