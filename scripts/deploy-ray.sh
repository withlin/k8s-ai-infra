#!/bin/bash

# Install Ray Operator
echo "Installing Ray Operator..."
helm repo add ray https://ray-project.github.io/kuberay-helm/
helm repo update

# Create namespace
kubectl create namespace ray-system

# Install KubeRay Operator
helm install kuberay-operator ray/kuberay-operator -n ray-system

# Wait for Operator to be ready
echo "Waiting for Ray Operator to be ready..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=kuberay-operator -n ray-system --timeout=300s

# Deploy Ray cluster
echo "Deploying Ray cluster..."
kubectl apply -f ../ray/ray-operator.yaml

# Wait for Ray cluster to be ready
echo "Waiting for Ray cluster to be ready..."
kubectl wait --for=condition=ready pod -l ray.io/cluster=ray-cluster -n ray-system --timeout=300s

# Configure monitoring integration
echo "Configuring Ray monitoring..."
kubectl apply -f ../monitoring/ray-monitor.yaml

# Display cluster information
echo -e "\nRay cluster information:"
kubectl get pods -n ray-system
kubectl get svc -n ray-system

# Get Dashboard access information
DASHBOARD_PORT=$(kubectl get svc ray-dashboard -n ray-system -o jsonpath='{.spec.ports[0].nodePort}')
echo -e "\nRay Dashboard access URL:"
echo "http://localhost:${DASHBOARD_PORT}"

# Display usage instructions
echo -e "\nUsage instructions:"
echo "1. Access Ray Dashboard: kubectl port-forward svc/ray-dashboard 8265:8265 -n ray-system"
echo "2. Connect to Ray cluster:"
echo "   Python example code:"
echo '   import ray'
echo '   ray.init("ray://ray-cluster-head-svc.ray-system:10001")'

# Display environment variables
echo -e "\nEnvironment variables:"
echo "export RAY_ADDRESS=ray://ray-cluster-head-svc.ray-system:10001"
echo "export NCCL_IB_ENABLE=1"
echo "export NCCL_DEBUG=INFO" 