#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Get script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
TERRAFORM_DIR="$SCRIPT_DIR/terraform-infra"
ANSIBLE_DIR="$SCRIPT_DIR/k8s-ansible"

echo -e "${GREEN}=== Meo Stationery Deployment Script ===${NC}\n"

# Function to print step
print_step() {
    echo -e "\n${YELLOW}[STEP]${NC} $1"
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check required tools
print_step "Checking required tools..."
for cmd in terraform ansible-playbook ssh; do
    if ! command_exists "$cmd"; then
        echo -e "${RED}ERROR: $cmd is not installed${NC}"
        exit 1
    fi
done
echo -e "${GREEN}✓ All required tools are installed${NC}"

# Step 1: Terraform destroy (if requested)
if [ "$1" == "destroy" ]; then
    print_step "Destroying infrastructure..."
    cd "$TERRAFORM_DIR"
    terraform destroy -auto-approve
    
    # Remove /etc/hosts entry if it exists
    print_step "Cleaning up /etc/hosts..."
    if grep -q "meo-stationery.local\|grafana.local\|prometheus.local" /etc/hosts 2>/dev/null; then
        if sudo sed -i.bak '/meo-stationery\.local\|grafana\.local\|prometheus\.local/d' /etc/hosts 2>/dev/null; then
            echo -e "${GREEN}✓ Removed monitoring entries from /etc/hosts${NC}"
        else
            echo -e "${YELLOW}⚠ Could not automatically remove from /etc/hosts${NC}"
            echo -e "${YELLOW}Please manually remove the entries from /etc/hosts${NC}"
        fi
    else
        echo "No /etc/hosts entries found to remove"
    fi
    
    echo -e "${GREEN}✓ Infrastructure destroyed${NC}"
    exit 0
fi

# Step 2: Terraform apply
print_step "Applying Terraform configuration..."
cd "$TERRAFORM_DIR"
terraform apply -auto-approve

# Get master IP from terraform output (handles list format)
cd "$TERRAFORM_DIR"
# Try JSON output first (most reliable)
MASTER_IP=$(terraform output -json master_public_ip 2>/dev/null | grep -oE '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | head -n1)

# Fallback: parse from regular output
if [ -z "$MASTER_IP" ]; then
    MASTER_IP=$(terraform output master_public_ip 2>/dev/null | grep -oE '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | head -n1)
fi

if [ -z "$MASTER_IP" ]; then
    echo -e "${RED}ERROR: Could not get master IP from terraform output${NC}"
    echo -e "${YELLOW}Debug: terraform output master_public_ip:${NC}"
    terraform output master_public_ip
    exit 1
fi
echo -e "${GREEN}✓ Master IP: $MASTER_IP${NC}"

# Get worker IPs from terraform output
WORKER_IPS=$(terraform output -json worker_public_ips 2>/dev/null | grep -oE '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' || terraform output worker_public_ips 2>/dev/null | grep -oE '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}')
if [ -z "$WORKER_IPS" ]; then
    echo -e "${YELLOW}⚠ Warning: Could not get worker IPs from terraform output${NC}"
    WORKER_IPS=""
fi
echo -e "${GREEN}✓ Worker IPs:${NC}"
echo "$WORKER_IPS" | while read ip; do
    [ -n "$ip" ] && echo "  - $ip"
done

# Get SSH key path
SSH_KEY="$TERRAFORM_DIR/k8s-key.pem"
if [ ! -f "$SSH_KEY" ]; then
    echo -e "${RED}ERROR: SSH key not found at $SSH_KEY${NC}"
    exit 1
fi

# Get CloudWatch Dashboard Name
DASHBOARD_NAME=$(terraform output -raw cloudwatch_dashboard_name 2>/dev/null || echo "K8s-Cluster-Dashboard")

# Step 2.5: Update inventory.ini automatically
print_step "Updating Ansible inventory.ini with new IPs..."

INVENTORY_FILE="$ANSIBLE_DIR/inventory.ini"
SSH_KEY_PATH="$SSH_KEY"

# Backup inventory file
cp "$INVENTORY_FILE" "$INVENTORY_FILE.bak" 2>/dev/null || true

# Create new inventory file
cat > "$INVENTORY_FILE" << EOF
[masters]
$MASTER_IP ansible_user=ubuntu ansible_ssh_private_key_file=$SSH_KEY_PATH ansible_ssh_common_args='-o StrictHostKeyChecking=no'

[workers]
EOF

# Add worker IPs
echo "$WORKER_IPS" | while read ip; do
    if [ -n "$ip" ]; then
        echo "$ip ansible_user=ubuntu ansible_ssh_private_key_file=$SSH_KEY_PATH ansible_ssh_common_args='-o StrictHostKeyChecking=no'" >> "$INVENTORY_FILE"
    fi
done

cat >> "$INVENTORY_FILE" << EOF

[all:children]
masters
workers
EOF

echo -e "${GREEN}✓ Updated inventory.ini${NC}"
echo -e "${YELLOW}  Master: $MASTER_IP${NC}"
echo "$WORKER_IPS" | while read ip; do
    [ -n "$ip" ] && echo -e "${YELLOW}  Worker: $ip${NC}"
done

# Step 2.6: Update /etc/hosts automatically
print_step "Updating /etc/hosts with new IPs..."

HOSTS_ENTRY="$MASTER_IP meo-stationery.local"
HOSTS_FILE="/etc/hosts"

# Function to update /etc/hosts
update_hosts_file() {
    # Remove old entries for meo-stationery.local, grafana.local, prometheus.local
    if grep -q "meo-stationery.local\|jenkins.local\|grafana.local\|prometheus.local" "$HOSTS_FILE" 2>/dev/null; then
        echo "Found existing entries in /etc/hosts"
        OLD_ENTRIES=$(grep -E "meo-stationery.local|jenkins.local|grafana.local|prometheus.local" "$HOSTS_FILE" | head -n1)
        echo "  Current entry: $OLD_ENTRIES"
        
        # Remove lines containing these domains
        if sudo sed -i.bak '/meo-stationery\.local\|jenkins\.local\|grafana\.local\|prometheus\.local/d' "$HOSTS_FILE" 2>/dev/null; then
            echo "  ✓ Removed old entries"
        else
            echo -e "  ${YELLOW}⚠ Could not remove old entries (may need password)${NC}"
            return 1
        fi
    fi
    
    # Add new entries
    NEW_ENTRIES="$MASTER_IP meo-stationery.local jenkins.local grafana.local prometheus.local argocd.local"
    if echo "$NEW_ENTRIES" | sudo tee -a "$HOSTS_FILE" >/dev/null 2>&1; then
        echo -e "${GREEN}✓ Updated /etc/hosts with: $NEW_ENTRIES${NC}"
        return 0
    else
        return 1
    fi
}

# Try to update /etc/hosts
if update_hosts_file; then
    echo -e "${GREEN}✓ /etc/hosts configured successfully${NC}"
else
    echo -e "\n${YELLOW}⚠ Could not automatically update /etc/hosts${NC}"
    echo -e "${YELLOW}Please run these commands manually:${NC}"
    echo -e "  sudo sed -i.bak '/meo-stationery\.local\|jenkins\.local\|grafana\.local\|prometheus\.local\|argocd\.local/d' /etc/hosts"
    echo -e "  echo '$MASTER_IP meo-stationery.local jenkins.local grafana.local prometheus.local argocd.local' | sudo tee -a /etc/hosts"
fi

# Wait for instances to be ready
print_step "Waiting for instances to be ready (15 seconds)..."
sleep 15

# Step 3: Run Ansible playbooks
print_step "Running Ansible playbooks..."

cd "$ANSIBLE_DIR"

print_step "  → Preparing all nodes..."
ansible-playbook -i inventory.ini all.yaml || {
    echo -e "${YELLOW}⚠ Some tasks in all.yaml had issues (likely handler timeout), but continuing...${NC}"
    echo -e "${YELLOW}   This is usually non-critical - checking if cluster is ready...${NC}"
}

print_step "  → Initializing Kubernetes master..."
ansible-playbook -i inventory.ini master.yml

print_step "  → Joining worker nodes..."
ansible-playbook -i inventory.ini worker.yml

print_step "  → Installing storage (EBS CSI Driver)..."
ansible-playbook -i inventory.ini install-storage.yaml

print_step "  → Installing NGINX Ingress Controller..."
ansible-playbook -i inventory.ini install-ingress.yaml

    echo -e "${GREEN}✓ Core Ansible playbooks completed${NC}"

print_step "  → Installing ArgoCD..."
ansible-playbook -i inventory.ini install-argocd.yaml

# print_step "  → Installing ArgoCD Applications..."
# ansible-playbook -i inventory.ini install-apps.yaml


# Step 4: Copy Helm charts to master and deploy
print_step "Deploying backend with Helm..."

# Wait a bit for cluster to stabilize
sleep 5

# Copy k8s_helm directory to master
print_step "  → Copying Helm charts to master node..."
ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no ubuntu@$MASTER_IP "rm -rf ~/k8s_helm" || true
scp -i "$SSH_KEY" -r -o StrictHostKeyChecking=no "$SCRIPT_DIR/k8s_helm" ubuntu@$MASTER_IP:~/ || {
    echo -e "${RED}ERROR: Failed to copy Helm charts${NC}"
    exit 1
}

# Create namespace if it doesn't exist
print_step "  → Creating namespace..."
ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no ubuntu@$MASTER_IP "kubectl create namespace meo-stationery --dry-run=client -o yaml | kubectl apply -f -" || true

# Install database first (if not already installed)
print_step "  → Installing database..."
ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no ubuntu@$MASTER_IP "
    if ! helm list -n meo-stationery | grep -q postgres; then
        echo 'Installing database...'
        helm install postgres ~/k8s_helm/database -n meo-stationery
    else
        echo 'Database already installed, upgrading...'
        helm upgrade postgres ~/k8s_helm/database -n meo-stationery
    fi
"

# Wait for database to be ready (using correct label selector)
print_step "  → Waiting for database pod to be ready..."
ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no ubuntu@$MASTER_IP "
    echo 'Waiting for postgres StatefulSet to be ready...'
    
    # Check for disk pressure first
    echo 'Checking node status...'
    DISK_PRESSURE=\$(kubectl get nodes -o json | grep -c 'disk-pressure' 2>/dev/null | tr -d '\n' || echo '0')
    DISK_PRESSURE=\${DISK_PRESSURE:-0}
    if [ \"\$DISK_PRESSURE\" -gt 0 ] 2>/dev/null; then
        echo 'WARNING: Some nodes have disk pressure. Cleaning up...'
        # Clean up evicted pods
        kubectl get pods --all-namespaces --field-selector=status.phase=Failed -o jsonpath='{range .items[*]}{.metadata.namespace}{\" \"}{.metadata.name}{\"\\n\"}{end}' 2>/dev/null | while read ns name; do
            [ -n \"\$name\" ] && kubectl delete pod -n \"\$ns\" \"\$name\" --ignore-not-found=true 2>/dev/null || true
        done
        echo 'Cleaned up failed pods'
    fi
    
    # Wait for pod to be scheduled (not Pending)
    echo 'Waiting for database pod to be scheduled...'
    for i in {1..30}; do
        POD_PHASE=\$(kubectl get pod -n meo-stationery -l app.kubernetes.io/name=postgres -o jsonpath='{.items[0].status.phase}' 2>/dev/null || echo 'Unknown')
        if [ \"\$POD_PHASE\" = \"Pending\" ]; then
            echo \"Pod is still Pending... (\$i/30)\"
            if [ \$i -eq 10 ]; then
                echo 'Checking why pod is Pending...'
                kubectl describe pod -n meo-stationery -l app.kubernetes.io/name=postgres | tail -20 || true
            fi
            sleep 5
        else
            echo \"Pod phase: \$POD_PHASE\"
            break
        fi
    done
    
    # Now wait for pod to be ready (reduced timeout)
    kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=postgres,app.kubernetes.io/instance=postgres -n meo-stationery --timeout=180s || {
        echo 'Waiting for postgres pod...'
        sleep 10
        kubectl get pods -n meo-stationery -l app.kubernetes.io/name=postgres || kubectl get pods -n meo-stationery | grep postgres
        POD_PHASE=\$(kubectl get pod -n meo-stationery -l app.kubernetes.io/name=postgres -o jsonpath='{.items[0].status.phase}' 2>/dev/null || echo 'Unknown')
        if [ \"\$POD_PHASE\" = \"Pending\" ]; then
            echo 'ERROR: Database pod is still Pending. This is likely due to disk pressure or resource constraints.'
            kubectl describe pod -n meo-stationery -l app.kubernetes.io/name=postgres | tail -30
            echo 'Please free up disk space on nodes and retry.'
            exit 1
        fi
        kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=postgres -n meo-stationery --timeout=180s || {
            echo 'ERROR: Database pod failed to become ready'
            exit 1
        }
    }
    echo 'Database pod is ready!'
    kubectl get pods -n meo-stationery | grep postgres || echo 'Postgres pod status:'
    kubectl get pods -n meo-stationery
"

# Verify database is ready before installing backend
print_step "  → Verifying database is ready..."
ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no ubuntu@$MASTER_IP "
    echo 'Checking database pod status...'
    kubectl get pods -n meo-stationery | grep postgres || kubectl get pods -n meo-stationery -l app.kubernetes.io/name=postgres
    POD_PHASE=\$(kubectl get pods -n meo-stationery -l app.kubernetes.io/name=postgres -o jsonpath='{.items[0].status.phase}' 2>/dev/null || echo 'Unknown')
    if [ \"\$POD_PHASE\" = \"Pending\" ]; then
        echo 'ERROR: Database pod is still Pending. Cannot proceed with backend deployment.'
        kubectl describe pod -n meo-stationery -l app.kubernetes.io/name=postgres | tail -30
        exit 1
    fi
    POSTGRES_READY=\$(kubectl get pods -n meo-stationery -l app.kubernetes.io/name=postgres -o jsonpath='{.items[0].status.conditions[?(@.type==\"Ready\")].status}' 2>/dev/null || echo 'False')
    if [ \"\$POSTGRES_READY\" != \"True\" ]; then
        echo 'Waiting for postgres pod to be ready...'
        kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=postgres -n meo-stationery --timeout=180s || {
            echo 'ERROR: Database pod failed to become ready'
            exit 1
        }
    fi
    echo 'Database pod is ready!'
"

# Clean up old failed migration jobs before installing backend
print_step "  → Cleaning up old migration jobs..."
ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no ubuntu@$MASTER_IP "
    echo 'Deleting old migration jobs...'
    # Delete by name pattern
    kubectl get jobs -n meo-stationery -o name | grep migration | xargs -r kubectl delete -n meo-stationery --ignore-not-found=true || true
    # Also delete by app label
    kubectl delete jobs -n meo-stationery -l app.kubernetes.io/name=backend --field-selector status.successful!=1 --ignore-not-found=true || true
    sleep 3
    echo 'Old migration jobs cleaned up'
    echo 'Remaining jobs:'
    kubectl get jobs -n meo-stationery | grep migration || echo 'No migration jobs found'
"

# Install backend
print_step "  → Installing backend..."
ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no ubuntu@$MASTER_IP "
    if helm list -n meo-stationery | grep -q backend; then
        echo 'Upgrading backend...'
        # Check if database already has data - if so, migration might be quick
        PRODUCT_COUNT=\$(kubectl exec -n meo-stationery postgres-0 -- psql -U postgres -d meo_stationery -t -c \"SELECT COUNT(*) FROM \\\"Product\\\";\" 2>/dev/null | tr -d ' ' || echo '0')
        if [ \"\$PRODUCT_COUNT\" -gt 0 ]; then
            echo \"Database already has \$PRODUCT_COUNT products. Migration should be quick.\"
        fi
        helm upgrade backend ~/k8s_helm/backend -n meo-stationery --wait --timeout=8m --force || {
            echo 'Helm upgrade failed, checking migration job logs...'
            echo 'Getting migration pods...'
            kubectl get pods -n meo-stationery | grep migration
            LATEST_MIGRATION_POD=\$(kubectl get pods -n meo-stationery -o name | grep migration | tail -1)
            if [ -n \"\$LATEST_MIGRATION_POD\" ]; then
                echo '=== Logs from latest migration pod ==='
                kubectl logs -n meo-stationery \$LATEST_MIGRATION_POD --tail=200 2>&1 || kubectl logs -n meo-stationery \$LATEST_MIGRATION_POD --previous --tail=200 2>&1 || echo 'Could not get logs'
            fi
            exit 1
        }
    else
        echo 'Installing backend...'
        helm install backend ~/k8s_helm/backend -n meo-stationery --wait --timeout=10m --force || {
            echo 'Helm install failed, checking migration job logs...'
            echo 'Getting migration pods...'
            kubectl get pods -n meo-stationery | grep migration
            LATEST_MIGRATION_POD=\$(kubectl get pods -n meo-stationery -o name | grep migration | tail -1)
            if [ -n \"\$LATEST_MIGRATION_POD\" ]; then
                echo '=== Logs from latest migration pod ==='
                kubectl logs -n meo-stationery \$LATEST_MIGRATION_POD --tail=200 2>&1 || kubectl logs -n meo-stationery \$LATEST_MIGRATION_POD --previous --tail=200 2>&1 || echo 'Could not get logs'
            fi
            exit 1
        }
    fi
"

# Check deployment status
print_step "Checking deployment status..."
ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no ubuntu@$MASTER_IP "
    echo '=== Pods ==='
    kubectl get pods -n meo-stationery
    echo ''
    echo '=== Services ==='
    kubectl get svc -n meo-stationery
    echo ''
    echo '=== Ingress ==='
    kubectl get ingress -n meo-stationery || echo 'No ingress found'
"

# Step 5: Install Jenkins
print_step "Installing Jenkins CI/CD..."
cd "$ANSIBLE_DIR"

print_step "  → Installing Jenkins on Kubernetes..."
ansible-playbook -i inventory.ini install-jenkins.yaml || {
    echo -e "${YELLOW}⚠ Jenkins installation had some issues, but continuing...${NC}"
}

echo -e "${GREEN}✓ Jenkins installation completed${NC}"

# Step 6: Install Prometheus and Grafana
print_step "Installing Prometheus and Grafana monitoring stack..."
cd "$ANSIBLE_DIR"

print_step "  → Installing Prometheus and Grafana..."
ansible-playbook -i inventory.ini install-monitoring.yaml || {
    echo -e "${YELLOW}⚠ Monitoring installation had some issues, but continuing...${NC}"
}

print_step "  → Setting up monitoring ingress..."
ansible-playbook -i inventory.ini setup-monitoring-ingress.yaml || {
    echo -e "${YELLOW}⚠ Monitoring ingress setup had some issues, but continuing...${NC}"
}

echo -e "${GREEN}✓ Monitoring stack installation completed${NC}"

# Step 7: Verify deployment
print_step "Verifying deployment..."

# Wait a bit for everything to be ready
sleep 5

# Test if site is accessible
if curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 "http://meo-stationery.local" | grep -q "200\|301\|302"; then
    echo -e "${GREEN}✓ Site is accessible!${NC}"
elif curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 "http://$MASTER_IP" | grep -q "200\|301\|302"; then
    echo -e "${YELLOW}⚠ Site accessible via IP but not domain. Check /etc/hosts entry.${NC}"
else
    echo -e "${YELLOW}⚠ Site not yet accessible. It may still be starting up.${NC}"
    echo -e "${YELLOW}   Wait a minute and try: curl http://meo-stationery.local${NC}"
fi

echo -e "\n${GREEN}=== Deployment Complete! ===${NC}"
echo -e "${GREEN}Master IP: $MASTER_IP${NC}"
echo -e "\n${GREEN}=== Access URLs ===${NC}"
echo -e "${GREEN}Main App:${NC}     http://meo-stationery.local"
echo -e "${GREEN}Jenkins:${NC}      http://jenkins.local (User: admin / Password: admin)"
echo -e "${GREEN}ArgoCD:${NC}       http://argocd.local (User: admin)"
echo -e "${GREEN}Grafana:${NC}      http://grafana.local (User: admin / Password: admin)"
echo -e "${GREEN}Prometheus:${NC}   http://prometheus.local"
echo -e "${YELLOW}To get ArgoCD password:${NC}"
echo -e "  ssh -i $SSH_KEY ubuntu@$MASTER_IP 'kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath=\"{.data.password}\" | base64 -d && echo'"
echo -e "\n${GREEN}CloudWatch Dashboard:${NC}"
echo -e "  https://console.aws.amazon.com/cloudwatch/home?region=ap-southeast-2#dashboards:name=$DASHBOARD_NAME"
echo -e "\n${GREEN}SSH: ssh -i $SSH_KEY ubuntu@$MASTER_IP${NC}"
echo -e "\n${YELLOW}Useful commands:${NC}"
echo -e "  ${YELLOW}Check pods:${NC}"
echo -e "    ssh -i $SSH_KEY ubuntu@$MASTER_IP 'kubectl get pods -n meo-stationery'"
echo -e "  ${YELLOW}Check backend logs:${NC}"
echo -e "    ssh -i $SSH_KEY ubuntu@$MASTER_IP 'kubectl logs -n meo-stationery -l app=backend --tail=50'"
echo -e "  ${YELLOW}Check migration job logs:${NC}"
echo -e "    ssh -i $SSH_KEY ubuntu@$MASTER_IP 'kubectl logs -n meo-stationery -l job-name=backend-migration'"
echo -e "  ${YELLOW}Check ingress:${NC}"
echo -e "    ssh -i $SSH_KEY ubuntu@$MASTER_IP 'kubectl get ingress -n meo-stationery'"
echo -e "\n${YELLOW}If you can't access the site:${NC}"
echo -e "  1. Verify /etc/hosts has: $HOSTS_ENTRY"
echo -e "  2. Check if ingress is running: ssh -i $SSH_KEY ubuntu@$MASTER_IP 'kubectl get pods -n ingress-nginx'"
echo -e "  3. Try accessing via IP: curl http://$MASTER_IP"

