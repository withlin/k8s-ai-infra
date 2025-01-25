package main

import (
	"flag"
	"fmt"
	"log"
	"net/http"
	"os"

	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promhttp"
	"github.com/withlin/llm/k8s-ai-infra/monitoring/hbox-dcgm-exporter/pkg/collector"
)

var (
	listenAddress = flag.String("web.listen-address", ":9401", "Address on which to expose metrics and web interface")
	metricsPath   = flag.String("web.telemetry-path", "/metrics", "Path under which to expose metrics")
)

func main() {
	flag.Parse()

	// 获取节点名称
	nodeName := os.Getenv("NODE_NAME")
	if nodeName == "" {
		log.Fatal("NODE_NAME environment variable not set")
	}

	// 获取 Prism 端点
	prismEndpoint := os.Getenv("PRISM_ENDPOINT")
	if prismEndpoint == "" {
		log.Fatal("PRISM_ENDPOINT environment variable not set")
	}

	// 创建收集器
	collector := collector.NewDCGMCollector(nodeName, prismEndpoint)
	prometheus.MustRegister(collector)

	// 设置 HTTP 处理器
	http.Handle(*metricsPath, promhttp.Handler())
	http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		w.Write([]byte(`<html>
			<head><title>HBOX DCGM Exporter</title></head>
			<body>
			<h1>HBOX DCGM Exporter</h1>
			<p><a href="` + *metricsPath + `">Metrics</a></p>
			</body>
			</html>`))
	})

	// 启动服务器
	fmt.Printf("Starting HBOX DCGM exporter on %s\n", *listenAddress)
	log.Fatal(http.ListenAndServe(*listenAddress, nil))
} 