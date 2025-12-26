# Deployment Guide - Step by Step

## Quick Start (Automated - Recommended)

After `terraform destroy`, simply run:

```bash
./deploy.sh
```

This single command will:
1. ✅ Apply Terraform (create infrastructure)
2. ✅ Update `inventory.ini` with new IPs
3. ✅ Update `/etc/hosts` automatically
4. ✅ Run all Ansible playbooks
5. ✅ Deploy database and backend with Helm
6. ✅ Verify everything is working

Then access your site at: **http://meo-stationery.local**

---

## Manual Steps (If you prefer step-by-step)

### Step 1: Destroy Infrastructure (if needed)
```bash
cd terraform-infra
terraform destroy -auto-approve
```

Or use the script:
```bash
./deploy.sh destroy
```

### Step 2: Create Infrastructure
```bash
cd terraform-infra
terraform apply -auto-approve
```

**Note the master IP** from the output (e.g., `3.27.70.53`)

### Step 3: Deploy Everything (Automated)
```bash
cd ..
./deploy.sh
```

This will:
- ✅ Get IPs from Terraform automatically
- ✅ Update `k8s-ansible/inventory.ini` automatically
- ✅ Update `/etc/hosts` automatically (may prompt for sudo password)
- ✅ Run all Ansible playbooks:
  - `all.yaml` - Prepare all nodes
  - `master.yml` - Initialize Kubernetes master
  - `worker.yml` - Join worker nodes
  - `install-storage.yaml` - Install EBS CSI Driver
  - `install-ingress.yaml` - Install NGINX Ingress
- ✅ Copy Helm charts to master
- ✅ Install database
- ✅ Install backend (with migration)
- ✅ Verify deployment

### Step 4: Access Your Website
Open in browser: **http://meo-stationery.local**

---

## Troubleshooting

### Check Migration Job Logs
```bash
./check-migration-logs.sh
```

### Update Helm Charts (if you made changes)
```bash
./update-helm-charts.sh
```

### Manual Cleanup and Retry
```bash
ssh -i terraform-infra/k8s-key.pem ubuntu@<MASTER_IP>
kubectl delete jobs -n meo-stationery backend-migration
helm upgrade backend ~/k8s_helm/backend -n meo-stationery --wait --timeout=15m
```

### Check Pod Status
```bash
ssh -i terraform-infra/k8s-key.pem ubuntu@<MASTER_IP>
kubectl get pods -n meo-stationery
kubectl get svc -n meo-stationery
kubectl get ingress -n meo-stationery
```

### Check Backend Logs
```bash
ssh -i terraform-infra/k8s-key.pem ubuntu@<MASTER_IP>
kubectl logs -n meo-stationery -l app.kubernetes.io/name=backend --tail=50
```

---

## What Gets Updated Automatically

1. **`k8s-ansible/inventory.ini`** - Master and worker IPs from Terraform
2. **`/etc/hosts`** - Domain mapping: `MASTER_IP meo-stationery.local grafana.local prometheus.local`
3. **Helm charts** - Copied to master node automatically
4. **Database** - Installed/upgraded automatically
5. **Backend** - Installed/upgraded with migration automatically

---

## Summary

**After `terraform destroy`, just run:**
```bash
./deploy.sh
```

**Then open:** http://meo-stationery.local

That's it! 🎉

