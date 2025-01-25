#!/bin/bash

# Install Prometheus Operator
echo "Installing Prometheus Operator..."
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace \
  --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false

# Wait for Prometheus deployment to complete
echo "Waiting for Prometheus deployment to be ready..."
kubectl wait --for=condition=ready pod -l app=prometheus -n monitoring --timeout=300s

# Deploy GPU and IB monitoring
echo "Deploying GPU and IB monitoring..."
kubectl apply -f ../monitoring/gpu-ib-monitor.yaml

# Wait for monitoring components to be ready
echo "Waiting for monitoring components to be ready..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=gpu-ib-monitor -n monitoring --timeout=300s

# Verify monitoring status
echo "Verifying monitoring status..."
kubectl get pods -n monitoring
kubectl get servicemonitors -n monitoring
kubectl get prometheusrules -n monitoring

# Get Grafana access information
echo -e "\nGrafana access information:"
echo "Username: admin"
echo "Password: $(kubectl get secret -n monitoring prometheus-grafana -o jsonpath="{.data.admin-password}" | base64 --decode)"
echo "Access port: $(kubectl get svc -n monitoring prometheus-grafana -o jsonpath="{.spec.ports[0].port}")"

# Set up port forwarding (optional)
echo -e "\nSet up Grafana port forwarding..."
echo "kubectl port-forward svc/prometheus-grafana 3000:80 -n monitoring"

# Display monitoring metrics
echo -e "\nAvailable monitoring metrics:"
echo "GPU Metrics:"
echo "- DCGM_FI_DEV_GPU_UTIL: GPU utilization"
echo "- DCGM_FI_DEV_GPU_TEMP: GPU temperature"
echo "- DCGM_FI_DEV_FB_USED: GPU memory usage"
echo "- DCGM_FI_DEV_POWER_USAGE: GPU power consumption"

echo -e "\nIB Metrics:"
echo "- ib_port_xmit_data_bytes: IB transmit data volume"
echo "- ib_port_rcv_data_bytes: IB receive data volume"
echo "- ib_port_error_counter: IB error count"
echo "- ib_link_state: IB link status" 