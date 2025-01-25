package collector

import (
	"encoding/json"
	"fmt"
	"io/ioutil"
	"net/http"

	"github.com/prometheus/client_golang/prometheus"
	"k8s.io/client-go/kubernetes"
	"k8s.io/client-go/rest"
)

type DCGMCollector struct {
	nodeName      string
	prismEndpoint string
	client        *kubernetes.Clientset

	// GPU 指标
	gpuUtilization *prometheus.GaugeVec
	gpuMemoryUsed  *prometheus.GaugeVec
	gpuTemperature *prometheus.GaugeVec
	gpuPowerUsage  *prometheus.GaugeVec

	// Pod 信息
	podLabels      map[string]map[string]string
	podAnnotations map[string]map[string]string
}

func NewDCGMCollector(nodeName, prismEndpoint string) *DCGMCollector {
	// 创建 Kubernetes 客户端
	config, err := rest.InClusterConfig()
	if err != nil {
		panic(err)
	}
	clientset, err := kubernetes.NewForConfig(config)
	if err != nil {
		panic(err)
	}

	return &DCGMCollector{
		nodeName:      nodeName,
		prismEndpoint: prismEndpoint,
		client:        clientset,

		gpuUtilization: prometheus.NewGaugeVec(
			prometheus.GaugeOpts{
				Name: "dcgm_gpu_utilization",
				Help: "GPU utilization with pod metadata",
			},
			[]string{"gpu", "pod", "namespace", "container", "label_app", "annotation_owner"},
		),
		gpuMemoryUsed: prometheus.NewGaugeVec(
			prometheus.GaugeOpts{
				Name: "dcgm_gpu_memory_used",
				Help: "GPU memory used with pod metadata",
			},
			[]string{"gpu", "pod", "namespace", "container", "label_app", "annotation_owner"},
		),
		gpuTemperature: prometheus.NewGaugeVec(
			prometheus.GaugeOpts{
				Name: "dcgm_gpu_temperature",
				Help: "GPU temperature with pod metadata",
			},
			[]string{"gpu", "pod", "namespace", "container", "label_app", "annotation_owner"},
		),
		gpuPowerUsage: prometheus.NewGaugeVec(
			prometheus.GaugeOpts{
				Name: "dcgm_gpu_power_usage",
				Help: "GPU power usage with pod metadata",
			},
			[]string{"gpu", "pod", "namespace", "container", "label_app", "annotation_owner"},
		),

		podLabels:      make(map[string]map[string]string),
		podAnnotations: make(map[string]map[string]string),
	}
}

func (c *DCGMCollector) Describe(ch chan<- *prometheus.Desc) {
	c.gpuUtilization.Describe(ch)
	c.gpuMemoryUsed.Describe(ch)
	c.gpuTemperature.Describe(ch)
	c.gpuPowerUsage.Describe(ch)
}

func (c *DCGMCollector) Collect(ch chan<- prometheus.Metric) {
	// 更新 Pod 元数据
	c.updatePodMetadata()

	// 获取 DCGM 指标
	metrics, err := c.getDCGMMetrics()
	if err != nil {
		fmt.Printf("Error getting DCGM metrics: %v\n", err)
		return
	}

	// 处理指标
	for _, metric := range metrics {
		labels := prometheus.Labels{
			"gpu":       metric.GPU,
			"pod":       metric.Pod,
			"namespace": metric.Namespace,
			"container": metric.Container,
		}

		// 添加 Pod 标签和注解
		if podLabels, ok := c.podLabels[metric.Pod]; ok {
			labels["label_app"] = podLabels["app"]
		}
		if podAnnotations, ok := c.podAnnotations[metric.Pod]; ok {
			labels["annotation_owner"] = podAnnotations["owner"]
		}

		c.gpuUtilization.With(labels).Set(metric.Utilization)
		c.gpuMemoryUsed.With(labels).Set(metric.MemoryUsed)
		c.gpuTemperature.With(labels).Set(metric.Temperature)
		c.gpuPowerUsage.With(labels).Set(metric.PowerUsage)
	}

	c.gpuUtilization.Collect(ch)
	c.gpuMemoryUsed.Collect(ch)
	c.gpuTemperature.Collect(ch)
	c.gpuPowerUsage.Collect(ch)
}

type DCGMMetric struct {
	GPU         string
	Pod         string
	Namespace   string
	Container   string
	Utilization float64
	MemoryUsed  float64
	Temperature float64
	PowerUsage  float64
}

func (c *DCGMCollector) getDCGMMetrics() ([]DCGMMetric, error) {
	// 从 nvidia-dcgm-exporter 获取原始指标
	resp, err := http.Get(fmt.Sprintf("http://localhost:9400/metrics"))
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	body, err := ioutil.ReadAll(resp.Body)
	if err != nil {
		return nil, err
	}

	// 解析指标并添加 Pod 信息
	// 这里需要实现具体的解析逻辑
	// ...

	return []DCGMMetric{}, nil
}

func (c *DCGMCollector) updatePodMetadata() {
	// 从 Prism 服务获取 Pod 信息
	resp, err := http.Get(fmt.Sprintf("%s/api/v1/pods?node=%s", c.prismEndpoint, c.nodeName))
	if err != nil {
		fmt.Printf("Error getting pod metadata from Prism: %v\n", err)
		return
	}
	defer resp.Body.Close()

	var pods []struct {
		Metadata struct {
			Name        string            `json:"name"`
			Namespace   string            `json:"namespace"`
			Labels      map[string]string `json:"labels"`
			Annotations map[string]string `json:"annotations"`
		} `json:"metadata"`
	}

	if err := json.NewDecoder(resp.Body).Decode(&pods); err != nil {
		fmt.Printf("Error decoding pod metadata: %v\n", err)
		return
	}

	// 更新缓存
	newPodLabels := make(map[string]map[string]string)
	newPodAnnotations := make(map[string]map[string]string)

	for _, pod := range pods {
		newPodLabels[pod.Metadata.Name] = pod.Metadata.Labels
		newPodAnnotations[pod.Metadata.Name] = pod.Metadata.Annotations
	}

	c.podLabels = newPodLabels
	c.podAnnotations = newPodAnnotations
} 