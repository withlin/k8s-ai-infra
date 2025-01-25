#!/bin/bash

# Check bond4 status
echo "Checking bond4 status..."
cat /proc/net/bonding/bond4

# Check IB card status
echo -e "\nChecking IB card status..."
ibstat

# Check RDMA devices
echo -e "\nChecking RDMA devices..."
rdma link show

# Deploy test Pod
echo -e "\nDeploying RDMA test Pod..."
kubectl apply -f ../rdma/rdma-test-pod.yaml

# Wait for Pod to be ready
echo "Waiting for Pod to be ready..."
kubectl wait --for=condition=ready pod/rdma-test-pod --timeout=60s

# Check Pod status
echo -e "\nPod status:"
kubectl get pod rdma-test-pod -o wide

# Check Pod network interfaces
echo -e "\nPod network interfaces:"
kubectl exec rdma-test-pod -- ip addr show

# Check RDMA device status in Pod
echo -e "\nRDMA device status in Pod:"
kubectl exec rdma-test-pod -- rdma link show 