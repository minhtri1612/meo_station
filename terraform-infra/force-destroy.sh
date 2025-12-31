#!/bin/bash

# Force destroy script for stuck AWS resources

set -e

echo "Force destroying stuck AWS resources..."
echo ""

cd "$(dirname "$0")"

# Get VPC ID from terraform state
VPC_ID=$(terraform output -raw vpc_id 2>/dev/null || terraform show | grep -A 1 "aws_vpc.k8s_vpc" | grep "id" | awk '{print $3}' | tr -d '"' || echo "")

if [ -z "$VPC_ID" ]; then
    echo "Getting VPC ID from AWS..."
    VPC_ID=$(aws ec2 describe-vpcs --filters "Name=tag:Name,Values=k8s-vpc" --query 'Vpcs[0].VpcId' --output text --region ap-southeast-2 2>/dev/null || echo "")
fi

if [ -z "$VPC_ID" ]; then
    echo "Error: Could not find VPC ID"
    exit 1
fi

echo "VPC ID: $VPC_ID"
echo ""

# 1. Delete all network interfaces in the VPC
echo "Step 1: Deleting network interfaces..."
ENIS=$(aws ec2 describe-network-interfaces --filters "Name=vpc-id,Values=$VPC_ID" --query 'NetworkInterfaces[*].NetworkInterfaceId' --output text --region ap-southeast-2 2>/dev/null || echo "")

if [ -n "$ENIS" ]; then
    for ENI in $ENIS; do
        echo "  Deleting ENI: $ENI"
        # Detach if attached
        aws ec2 detach-network-interface --network-interface-id $ENI --force --region ap-southeast-2 2>/dev/null || true
        sleep 2
        # Delete
        aws ec2 delete-network-interface --network-interface-id $ENI --region ap-southeast-2 2>/dev/null || true
    done
else
    echo "  No network interfaces found"
fi

# 2. Release any Elastic IPs
echo ""
echo "Step 2: Releasing Elastic IPs..."
EIPS=$(aws ec2 describe-addresses --filters "Name=domain,Values=vpc" --query 'Addresses[?AssociationId==null].AllocationId' --output text --region ap-southeast-2 2>/dev/null || echo "")

if [ -n "$EIPS" ]; then
    for EIP in $EIPS; do
        echo "  Releasing EIP: $EIP"
        aws ec2 release-address --allocation-id $EIP --region ap-southeast-2 2>/dev/null || true
    done
else
    echo "  No unassociated Elastic IPs found"
fi

# 3. Delete any remaining instances
echo ""
echo "Step 3: Terminating any remaining instances..."
INSTANCES=$(aws ec2 describe-instances --filters "Name=vpc-id,Values=$VPC_ID" "Name=instance-state-name,Values=running,stopped,stopping" --query 'Reservations[*].Instances[*].InstanceId' --output text --region ap-southeast-2 2>/dev/null || echo "")

if [ -n "$INSTANCES" ]; then
    for INSTANCE in $INSTANCES; do
        echo "  Terminating instance: $INSTANCE"
        aws ec2 terminate-instances --instance-ids $INSTANCE --region ap-southeast-2 2>/dev/null || true
    done
    echo "  Waiting for instances to terminate..."
    sleep 30
else
    echo "  No instances found"
fi

# 4. Delete security group rules that reference other security groups
echo ""
echo "Step 4: Cleaning up security group dependencies..."
SG_ID=$(aws ec2 describe-security-groups --filters "Name=vpc-id,Values=$VPC_ID" "Name=group-name,Values=k8s-sg" --query 'SecurityGroups[0].GroupId' --output text --region ap-southeast-2 2>/dev/null || echo "")

if [ -n "$SG_ID" ] && [ "$SG_ID" != "None" ]; then
    echo "  Found security group: $SG_ID"
    # Remove ingress rules
    aws ec2 describe-security-groups --group-ids $SG_ID --query 'SecurityGroups[0].IpPermissions' --output json --region ap-southeast-2 | \
        jq -r '.[] | "\(.IpProtocol) \(.FromPort) \(.ToPort) \(.IpRanges[0].CidrIp // "0.0.0.0/0")"' 2>/dev/null || true
fi

echo ""
echo "Step 5: Running terraform destroy again..."
terraform destroy -auto-approve || {
    echo ""
    echo "If still failing, try:"
    echo "  1. Wait a few minutes for AWS to clean up"
    echo "  2. Run: terraform destroy -auto-approve"
    echo "  3. Or manually delete resources in AWS Console"
}


