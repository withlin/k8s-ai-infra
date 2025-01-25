#!/bin/bash

# Check MOFED driver status
echo "Checking MOFED driver status..."
if ! ibstat &> /dev/null; then
    echo "Error: MOFED driver not installed or not running!"
    echo "Please run ./install-mofed.sh to install the driver."
    exit 1
fi

# Check RDMA devices
echo "Checking RDMA devices..."
if ! rdma link show &> /dev/null; then
    echo "Error: RDMA devices not ready!"
    exit 1
fi

# Add Helm repository
echo "Adding Helm repository..."
helm repo add nvidia https://helm.ngc.nvidia.com/nvidia
helm repo update

# Create namespace
echo "Creating namespace..."
kubectl create namespace nvidia-network-operator

# Deploy Network Operator
echo "Deploying Network Operator..."
helm install nvidia-network-operator \
  -n nvidia-network-operator \
  -f ../network/network-operator-values.yaml \
  nvidia/network-operator

# Wait for operator to be ready
echo "Waiting for Network Operator to be ready..."
kubectl wait --for=condition=ready pod -l app=nvidia-network-operator -n nvidia-network-operator --timeout=300s

# Apply RDMA configuration
echo "Applying RDMA configuration..."
kubectl apply -f ../rdma/rdma-config.yaml

# Apply monitoring configuration
echo "Applying monitoring configuration..."
kubectl apply -f ../monitoring/network-monitor.yaml

# Verify configuration
echo "Verifying network configuration..."
kubectl get pods -n nvidia-network-operator
kubectl get rdma -A
kubectl get network-attachment-definitions -A

echo "Network Operator deployment complete!"

# Display next steps
echo -e "\nNext steps:"
echo "1. Run ./test-network.sh to verify network configuration"
echo "2. Check Grafana monitoring dashboard"
echo "3. Deploy test pod to verify RDMA functionality" 