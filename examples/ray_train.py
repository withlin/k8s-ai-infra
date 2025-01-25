import ray
from ray import train
import torch
import torch.nn as nn
import torch.optim as optim
from torch.utils.data import DataLoader
from torchvision import datasets, transforms

def train_func(config):
    # 设置 NCCL 参数以使用 IB 网络
    torch.backends.cudnn.benchmark = True
    
    # 创建模型
    model = nn.Sequential(
        nn.Conv2d(1, 32, 3),
        nn.ReLU(),
        nn.MaxPool2d(2),
        nn.Conv2d(32, 64, 3),
        nn.ReLU(),
        nn.MaxPool2d(2),
        nn.Flatten(),
        nn.Linear(1600, 128),
        nn.ReLU(),
        nn.Linear(128, 10)
    ).cuda()
    
    # 准备数据
    transform = transforms.Compose([
        transforms.ToTensor(),
        transforms.Normalize((0.1307,), (0.3081,))
    ])
    
    dataset = datasets.MNIST('data', train=True, download=True, transform=transform)
    dataloader = DataLoader(dataset, batch_size=config["batch_size"], shuffle=True)
    
    # 优化器
    optimizer = optim.Adam(model.parameters(), lr=config["lr"])
    criterion = nn.CrossEntropyLoss()
    
    # 训练循环
    for epoch in range(config["epochs"]):
        model.train()
        for batch_idx, (data, target) in enumerate(dataloader):
            data, target = data.cuda(), target.cuda()
            optimizer.zero_grad()
            output = model(data)
            loss = criterion(output, target)
            loss.backward()
            optimizer.step()
            
            if batch_idx % 100 == 0:
                train.report({"loss": loss.item()})

if __name__ == "__main__":
    ray.init(address="ray://ray-cluster-head-svc.ray-system:10001")
    
    # 训练配置
    config = {
        "lr": 0.001,
        "batch_size": 64,
        "epochs": 10
    }
    
    # 使用 Ray Train 进行分布式训练
    trainer = train.Trainer(
        backend="torch",
        num_workers=4,
        use_gpu=True,
        resources_per_worker={
            "CPU": 2,
            "GPU": 1
        }
    )
    
    results = trainer.run(
        train_func,
        config=config
    )
    
    print("Training completed!") 