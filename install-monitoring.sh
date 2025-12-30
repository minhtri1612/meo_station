#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== Installing Prometheus and Grafana ===${NC}\n"

# Add Prometheus Community Helm repository
echo -e "${YELLOW}[1/7]${NC} Adding Prometheus Community Helm repository..."
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts 2>/dev/null || echo "Repository already exists"
helm repo update

# Create monitoring namespace
echo -e "${YELLOW}[2/7]${NC} Creating monitoring namespace..."
kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -

# Clean up evicted pods
echo -e "${YELLOW}[3/7]${NC} Cleaning up evicted pods..."
kubectl get pods --all-namespaces -o json 2>/dev/null | grep -A 5 '"reason":"Evicted"' | grep '"name"' | sed 's/.*"name":"\([^"]*\)".*/\1/' | while read name; do
  kubectl delete pod "$name" --all-namespaces --ignore-not-found=true 2>/dev/null || true
done || true

# Install kube-prometheus-stack
echo -e "${YELLOW}[4/7]${NC} Installing kube-prometheus-stack (Prometheus + Grafana)..."
helm upgrade --install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false \
  --set prometheus.prometheusSpec.podMonitorSelectorNilUsesHelmValues=false \
  --set prometheus.prometheusSpec.ruleSelectorNilUsesHelmValues=false \
  --set grafana.adminPassword=admin \
  --set grafana.replicas=1 \
  --set grafana.service.type=ClusterIP \
  --set grafana.resources.requests.memory=128Mi \
  --set grafana.resources.requests.cpu=100m \
  --set grafana.resources.limits.memory=512Mi \
  --set grafana.resources.limits.cpu=500m \
  --set prometheus.service.type=ClusterIP \
  --set prometheus.prometheusSpec.retention=2d \
  --set prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.resources.requests.storage=2Gi \
  --set prometheus.prometheusSpec.resources.requests.memory=512Mi \
  --set prometheus.prometheusSpec.resources.requests.cpu=200m \
  --set prometheus.prometheusSpec.resources.limits.memory=2Gi \
  --set prometheus.prometheusSpec.resources.limits.cpu=1000m \
  --wait --timeout=10m

# Wait for pods to be ready
echo -e "${YELLOW}[5/7]${NC} Waiting for Prometheus to be ready..."
for i in {1..60}; do
  POD_PHASE=$(kubectl get pods -n monitoring -l app.kubernetes.io/name=prometheus -o jsonpath='{.items[0].status.phase}' 2>/dev/null || echo 'Unknown')
  if [ "$POD_PHASE" = "Running" ]; then
    READY=$(kubectl get pods -n monitoring -l app.kubernetes.io/name=prometheus -o jsonpath='{.items[0].status.containerStatuses[0].ready}' 2>/dev/null || echo 'false')
    if [ "$READY" = "true" ]; then
      echo -e "${GREEN}✓ Prometheus is ready${NC}"
      break
    fi
  fi
  if [ $((i % 10)) -eq 0 ]; then
    echo "  Waiting... ($i/60) - Phase: $POD_PHASE"
  fi
  sleep 5
done

echo -e "${YELLOW}[6/7]${NC} Waiting for Grafana to be ready..."
for i in {1..60}; do
  READY_PODS=$(kubectl get pods -n monitoring -l app.kubernetes.io/name=grafana --field-selector=status.phase=Running -o jsonpath='{.items[*].status.containerStatuses[?(@.ready==true)]}' 2>/dev/null | wc -l)
  if [ "$READY_PODS" -gt 0 ] 2>/dev/null; then
    echo -e "${GREEN}✓ Grafana is ready${NC}"
    break
  fi
  if [ $((i % 10)) -eq 0 ]; then
    echo "  Waiting... ($i/60)"
  fi
  sleep 5
done

# Get service names
GRAFANA_SVC=$(kubectl get svc -n monitoring -l app.kubernetes.io/name=grafana -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "prometheus-grafana")
PROMETHEUS_SVC=$(kubectl get svc -n monitoring -l app=kube-prometheus-stack-prometheus -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || kubectl get svc -n monitoring -l app.kubernetes.io/name=prometheus -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "prometheus-kube-prometheus-prometheus")

echo -e "${YELLOW}[7/7]${NC} Setting up ingress..."

# Apply ingress configurations
if [ -f "k8s_helm/grafana-ingress.yaml" ]; then
  # Update service name in ingress if needed
  sed "s/name: prometheus-grafana/name: ${GRAFANA_SVC}/" k8s_helm/grafana-ingress.yaml | kubectl apply -f - || kubectl apply -f k8s_helm/grafana-ingress.yaml
fi

if [ -f "k8s_helm/prometheus-ingress.yaml" ]; then
  # Update service name in ingress if needed
  sed "s/name: prometheus-kube-prometheus-prometheus/name: ${PROMETHEUS_SVC}/" k8s_helm/prometheus-ingress.yaml | kubectl apply -f - || kubectl apply -f k8s_helm/prometheus-ingress.yaml
fi

# Display status
echo -e "\n${GREEN}=== Installation Complete! ===${NC}\n"
echo -e "${GREEN}Monitoring Stack Status:${NC}"
kubectl get pods -n monitoring
echo ""
echo -e "${GREEN}Services:${NC}"
kubectl get svc -n monitoring
echo ""
echo -e "${GREEN}Access Information:${NC}"
echo -e "  Grafana Service: ${GRAFANA_SVC}"
echo -e "  Prometheus Service: ${PROMETHEUS_SVC}"
echo -e "  Grafana Admin Password: ${YELLOW}admin${NC}"
echo ""
echo -e "${YELLOW}To access via port-forward:${NC}"
echo -e "  Grafana:   kubectl port-forward -n monitoring svc/${GRAFANA_SVC} 3000:80"
echo -e "  Prometheus: kubectl port-forward -n monitoring svc/${PROMETHEUS_SVC} 9090:9090"
echo ""
echo -e "${YELLOW}Or access via ingress (if configured):${NC}"
echo -e "  Grafana:   http://grafana.local"
echo -e "  Prometheus: http://prometheus.local"

