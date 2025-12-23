#!/bin/bash
set -e

echo "=== Installing EBS CSI Driver and Fixing Storage ==="

# Add Helm repo
echo "Adding EBS CSI Driver Helm repository..."
helm repo add aws-ebs-csi-driver https://kubernetes-sigs.github.io/aws-ebs-csi-driver || true
helm repo update

# Install EBS CSI Driver
echo "Installing AWS EBS CSI Driver..."
helm upgrade --install aws-ebs-csi-driver aws-ebs-csi-driver/aws-ebs-csi-driver \
  --namespace kube-system \
  --set controller.serviceAccount.create=true \
  --set controller.serviceAccount.name=ebs-csi-controller-sa \
  --set node.serviceAccount.create=true \
  --set node.serviceAccount.name=ebs-csi-node-sa \
  --set enableVolumeResizing=true \
  --set enableVolumeSnapshot=true || true

echo "Waiting for EBS CSI Driver to be ready..."
kubectl wait --for=condition=ready pod -l app=ebs-csi-controller -n kube-system --timeout=300s || true

# Create default storage class
echo "Creating default GP3 storage class..."
kubectl apply -f - <<EOF
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: gp3
  annotations:
    storageclass.kubernetes.io/is-default-class: "true"
provisioner: ebs.csi.aws.com
volumeBindingMode: WaitForFirstConsumer
parameters:
  type: gp3
  fsType: ext4
EOF

echo "Waiting for storage class to be created..."
sleep 5

# Delete existing postgres resources
echo "Deleting existing postgres StatefulSet and PVC..."
kubectl delete statefulset postgres -n meo-stationery --ignore-not-found=true
kubectl delete pvc postgres-storage-postgres-0 -n meo-stationery --ignore-not-found=true

echo "Waiting for cleanup..."
sleep 10

# Redeploy postgres
echo "Redeploying postgres..."
cd ~/k8s_helm
helm upgrade postgres database \
  --namespace meo-stationery \
  --values database/values.yaml \
  --install

echo "Waiting for postgres to start..."
sleep 10

# Check status
echo "=== Postgres Status ==="
kubectl get pods -n meo-stationery -l app.kubernetes.io/name=postgres
kubectl get pvc -n meo-stationery
kubectl get storageclass

echo "=== Done ==="

