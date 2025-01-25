FROM golang:1.21-alpine AS builder

WORKDIR /app

# 复制 Go 模块文件
COPY go.mod go.sum ./
RUN go mod download

# 复制源代码
COPY . .

# 构建应用
RUN CGO_ENABLED=0 GOOS=linux go build -o hbox-dcgm-exporter ./cmd/main.go

# 使用精简的基础镜像
FROM alpine:3.19

WORKDIR /app

# 从构建阶段复制二进制文件
COPY --from=builder /app/hbox-dcgm-exporter .

# 设置环境变量
ENV NODE_NAME=""
ENV PRISM_ENDPOINT=""

# 暴露端口
EXPOSE 9401

# 运行应用
ENTRYPOINT ["/app/hbox-dcgm-exporter"] 