#!/bin/bash

# Set variables
MOFED_VERSION="5.4-2.3.7.1"
OS_VERSION="rhel8.4"
ARCH="x86_64"

# Download MOFED driver
echo "Downloading MOFED driver..."
wget https://content.mellanox.com/ofed/MLNX_OFED-${MOFED_VERSION}/MLNX_OFED_LINUX-${MOFED_VERSION}-${OS_VERSION}-${ARCH}.tgz

# Extract driver package
echo "Extracting driver package..."
tar xzf MLNX_OFED_LINUX-${MOFED_VERSION}-${OS_VERSION}-${ARCH}.tgz
cd MLNX_OFED_LINUX-${MOFED_VERSION}-${OS_VERSION}-${ARCH}

# Install driver
echo "Installing MOFED driver..."
./mlnxofedinstall --add-kernel-support

# Verify installation
echo "Verifying driver installation..."
if ibstat &> /dev/null; then
    echo "MOFED driver installation successful!"
    ibstat
else
    echo "MOFED driver installation failed!"
    exit 1
fi

# Check RDMA devices
echo -e "\nChecking RDMA devices..."
rdma link show

# Configure IB card parameters
echo -e "\nConfiguring IB card parameters..."
# Enable PFC
mlnx_qos -i ib0 --pfc 0,0,0,1,0,0,0,0

# Set MTU
ip link set ib0 mtu 4096

# Enable IOMMU
echo "options vfio_iommu_type1 allow_unsafe_interrupts=1" > /etc/modprobe.d/vfio.conf

# Load required kernel modules
modprobe -r vfio_iommu_type1
modprobe -r vfio
modprobe vfio enable_unsafe_noiommu_mode=1
modprobe vfio_iommu_type1 allow_unsafe_interrupts=1

echo "MOFED driver configuration complete!"

# 添加性能监控代码
from torch.cuda.amp import autocast, GradScaler
import torch.cuda.nvtx as nvtx
import os
import ray
from ray import train
import torch.distributed as dist

def train_func(config):
    # 配置 NCCL 环境
    os.environ.update({
        "NCCL_DEBUG": "INFO",
        "NCCL_IB_ENABLE": "1",
        "NCCL_P2P_LEVEL": "NVL",
        "NCCL_NET_GDR_ENABLE": "1"
    })
    
    # 初始化分布式环境
    dist.init_process_group(backend='nccl')
    
    # 获取本地 rank
    local_rank = dist.get_rank() % torch.cuda.device_count()
    torch.cuda.set_device(local_rank)
    
    # 创建模型
    model = YourLLMModel()
    model = model.cuda()
    
    # 使用 DistributedDataParallel
    model = torch.nn.parallel.DistributedDataParallel(
        model,
        device_ids=[local_rank],
        output_device=local_rank
    )
    
    # 训练循环
    for epoch in range(config["epochs"]):
        for batch in dataloader:
            # 节点内使用 NVLink
            # 节点间使用 IB
            outputs = model(batch)
            loss = criterion(outputs, targets)
            loss.backward()
            optimizer.step()

if __name__ == "__main__":
    ray.init(address="ray://ray-cluster-head-svc.ray-system:10001")
    
    # 配置训练器
    trainer = train.Trainer(
        backend="torch",
        num_workers=16,  # 总 GPU 数量
        use_gpu=True,
        resources_per_worker={
            "GPU": 1,
            "rdma/hca_shared_devices": 0.1  # IB 设备分配
        }
    )
    
    # 创建 placement group 策略
    placement_group = ray.util.placement_group(
        bundles=[{
            "GPU": 8,  # 每节点8卡
            "rdma/hca_shared_devices": 1
        }] * 2,  # 2个节点
        strategy="STRICT_SPREAD"  # 确保跨节点分布
    )
    
    ray.get(placement_group.ready())
    
    results = trainer.run(
        train_func,
        config={
            "epochs": 10,
            "batch_size": 32,
            "placement_group": placement_group
        }
    )

apiVersion: ray.io/v1
kind: RayCluster
metadata:
  name: ray-cluster
spec:
  rayVersion: '2.9.0'
  headGroupSpec:
    rayStartParams:
      num-gpus: '1'
    template:
      spec:
        containers:
        - name: ray-head
          image: rayproject/ray:2.9.0-py39-cu118
          resources:
            limits:
              nvidia.com/gpu: "1"
              rdma/hca_shared_devices: "1"  # IB 设备
  workerGroupSpecs:
  - groupName: gpu-workers
    replicas: 2
    template:
      spec:
        containers:
        - name: ray-worker
          resources:
            limits:
              nvidia.com/gpu: "8"  # 每个节点8张卡
              rdma/hca_shared_devices: "1"
          env:
            # NCCL 配置
            - name: NCCL_DEBUG
              value: "INFO"
            - name: NCCL_IB_ENABLE
              value: "1"
            - name: NCCL_P2P_LEVEL
              value: "NVL"
            - name: NCCL_IB_HCA
              value: "mlx5_0,mlx5_1"
            - name: NCCL_NET_GDR_ENABLE
              value: "1"
            - name: NCCL_IB_GID_INDEX
              value: "3"
          volumeMounts:
            - name: rdma-devices
              mountPath: /dev/infiniband
        volumes:
        - name: rdma-devices
          hostPath:
            path: /dev/infiniband 