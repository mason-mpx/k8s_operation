package services

import (
	"context"
	"database/sql"
	"fmt"
	"runtime"
	"sync"
	"time"

	"k8soperation/global"

	"go.uber.org/zap"
	corev1 "k8s.io/api/core/v1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/client-go/kubernetes"
)

// PlatformHealthService 平台健康检查服务
type PlatformHealthService struct {
	factory *ClusterClientFactory
}

func NewPlatformHealthService() *PlatformHealthService {
	return &PlatformHealthService{}
}

func NewPlatformHealthServiceWithFactory(factory *ClusterClientFactory) *PlatformHealthService {
	return &PlatformHealthService{factory: factory}
}

// ============ 数据结构 ============

// PlatformHealthStatus 平台健康状态
type PlatformHealthStatus struct {
	Status       string    `json:"status"`        // healthy / degraded / unhealthy
	LastCheck    time.Time `json:"last_check"`    // 最后检查时间
	Uptime       string    `json:"uptime"`        // 运行时间
	Version      string    `json:"version"`       // 版本号
	GoVersion    string    `json:"go_version"`    // Go版本
	NumGoroutine int       `json:"num_goroutine"` // 协程数
	NumCPU       int       `json:"num_cpu"`       // CPU核数
}

// ClusterHealthSummary 集群健康摘要
type ClusterHealthSummary struct {
	Total    int `json:"total"`    // 总集群数
	Online   int `json:"online"`   // 在线数
	Offline  int `json:"offline"`  // 离线数
	Abnormal int `json:"abnormal"` // 异常数
}

// NodeSummary 节点概览 (Rancher/KubeSphere 风格)
type NodeSummary struct {
	Total       int     `json:"total"`        // 总节点数
	Ready       int     `json:"ready"`        // 就绪节点
	NotReady    int     `json:"not_ready"`    // 未就绪节点
	Master      int     `json:"master"`       // Master 节点
	Worker      int     `json:"worker"`       // Worker 节点
	CPUUsage    float64 `json:"cpu_usage"`    // CPU 使用率 %
	MemoryUsage float64 `json:"memory_usage"` // 内存使用率 %
	PodUsage    float64 `json:"pod_usage"`    // Pod 使用率 %
}

// WorkloadSummary 工作负载概览 (Rancher/KubeSphere 风格)
type WorkloadSummary struct {
	Deployments  ResourceCount `json:"deployments"`
	StatefulSets ResourceCount `json:"statefulsets"`
	DaemonSets   ResourceCount `json:"daemonsets"`
	Jobs         ResourceCount `json:"jobs"`
	CronJobs     ResourceCount `json:"cronjobs"`
	Pods         PodSummary    `json:"pods"`
}

// ResourceCount 资源计数
type ResourceCount struct {
	Total   int `json:"total"`
	Running int `json:"running"`
	Failed  int `json:"failed"`
}

// PodSummary Pod 概览
type PodSummary struct {
	Total     int `json:"total"`
	Running   int `json:"running"`
	Pending   int `json:"pending"`
	Succeeded int `json:"succeeded"`
	Failed    int `json:"failed"`
	Unknown   int `json:"unknown"`
}

// ServiceSummary 服务概览
type ServiceSummary struct {
	Total        int `json:"total"`
	ClusterIP    int `json:"cluster_ip"`
	NodePort     int `json:"node_port"`
	LoadBalancer int `json:"load_balancer"`
	Ingresses    int `json:"ingresses"`
}

// EventSummary K8s 事件概览
type EventSummary struct {
	Total     int `json:"total"`      // 总事件数
	Warning   int `json:"warning"`    // 警告事件
	Normal    int `json:"normal"`     // 正常事件
	Today     int `json:"today"`      // 今日事件
	LastHour  int `json:"last_hour"`  // 最近一小时
}

// AlertSummary 告警摘要
type AlertSummary struct {
	Total24h     int `json:"total_24h"`    // 24小时告警数
	Critical     int `json:"critical"`     // 严重告警
	Warning      int `json:"warning"`      // 警告
	Info         int `json:"info"`         // 信息
	Acknowledged int `json:"acknowledged"` // 已确认
}

// TaskQueueStatus 任务队列状态
type TaskQueueStatus struct {
	Pending   int    `json:"pending"`   // 待处理
	Running   int    `json:"running"`   // 运行中
	Completed int    `json:"completed"` // 已完成
	Failed    int    `json:"failed"`    // 失败
	AvgDelay  string `json:"avg_delay"` // 平均延迟
}

// ComponentStatus 组件状态
type ComponentStatus struct {
	Name        string  `json:"name"`
	Status      string  `json:"status"` // ok / warning / error
	Latency     string  `json:"latency"`
	Description string  `json:"description"`
	CheckedAt   string  `json:"checked_at"`
	Uptime      string  `json:"uptime,omitempty"`
	Version     string  `json:"version,omitempty"`
	Memory      string  `json:"memory,omitempty"`
	CPU         float64 `json:"cpu,omitempty"`
}

// ClusterDetail 单个集群详情
type ClusterDetail struct {
	ID          int64           `json:"id"`
	Name        string          `json:"name"`
	Status      string          `json:"status"`       // online / offline / error
	StatusCode  int             `json:"status_code"`  // 0=在线 2=异常
	Nodes       NodeSummary     `json:"nodes"`
	Workloads   WorkloadSummary `json:"workloads"`
	Services    ServiceSummary  `json:"services"`
	Events      EventSummary    `json:"events"`
	Connectable bool            `json:"connectable"` // 是否可连接
	Latency     string          `json:"latency"`     // 连接延迟
}

// FullPlatformHealth 完整平台健康数据 (Rancher/KubeSphere 风格)
type FullPlatformHealth struct {
	Platform       PlatformHealthStatus `json:"platform"`
	Clusters       ClusterHealthSummary `json:"clusters"`
	ClusterDetails []ClusterDetail      `json:"cluster_details"` // 每个集群的详情
	Nodes          NodeSummary          `json:"nodes"`           // 汇总
	Workloads      WorkloadSummary      `json:"workloads"`       // 汇总
	Services       ServiceSummary       `json:"services"`        // 汇总
	Events         EventSummary         `json:"events"`          // 汇总
	Alerts         AlertSummary         `json:"alerts"`
	TaskQueue      TaskQueueStatus      `json:"task_queue"`
	Components     []ComponentStatus    `json:"components"`
	RefreshedAt    time.Time            `json:"refreshed_at"`
}

// ============ 服务方法 ============

var startTime = time.Now()

// GetFullHealth 获取完整平台健康状态
func (s *PlatformHealthService) GetFullHealth(ctx context.Context) (*FullPlatformHealth, error) {
	health := &FullPlatformHealth{
		RefreshedAt: time.Now(),
	}

	// 并发获取各项健康数据
	var wg sync.WaitGroup
	wg.Add(9) // 增加一个任务：获取集群详情

	go func() {
		defer wg.Done()
		health.Platform = s.getPlatformStatus()
	}()

	go func() {
		defer wg.Done()
		health.Clusters = s.getClusterSummary(ctx)
	}()

	go func() {
		defer wg.Done()
		health.ClusterDetails = s.getClusterDetails(ctx)
	}()

	go func() {
		defer wg.Done()
		health.Nodes = s.getNodeSummary(ctx)
	}()

	go func() {
		defer wg.Done()
		health.Workloads = s.getWorkloadSummary(ctx)
	}()

	go func() {
		defer wg.Done()
		health.Services = s.getServiceSummary(ctx)
	}()

	go func() {
		defer wg.Done()
		health.Events = s.getEventSummary(ctx)
	}()

	go func() {
		defer wg.Done()
		health.Alerts = s.getAlertSummary(ctx)
	}()

	go func() {
		defer wg.Done()
		health.TaskQueue = s.getTaskQueueStatus(ctx)
	}()

	wg.Wait()

	// 组件检查（串行，因为有依赖）
	health.Components = s.checkComponents(ctx)

	// 根据组件状态判断整体状态
	health.Platform.Status = s.calculateOverallStatus(health.Components)

	return health, nil
}

// getPlatformStatus 获取平台状态
func (s *PlatformHealthService) getPlatformStatus() PlatformHealthStatus {
	var m runtime.MemStats
	runtime.ReadMemStats(&m)

	uptime := time.Since(startTime)
	uptimeStr := formatDuration(uptime)

	return PlatformHealthStatus{
		Status:       "healthy",
		LastCheck:    time.Now(),
		Uptime:       uptimeStr,
		Version:      "v1.0.0",
		GoVersion:    runtime.Version(),
		NumGoroutine: runtime.NumGoroutine(),
		NumCPU:       runtime.NumCPU(),
	}
}

// getClusterSummary 获取集群摘要
func (s *PlatformHealthService) getClusterSummary(ctx context.Context) ClusterHealthSummary {
	summary := ClusterHealthSummary{}

	// 从数据库获取集群统计
	var total, online int64
	if global.DB != nil {
		global.DB.WithContext(ctx).
			Table("kube_cluster").
			Where("deleted_at = 0").
			Count(&total)

		// status=0 表示在线，status=2 表示异常
		global.DB.WithContext(ctx).
			Table("kube_cluster").
			Where("deleted_at = 0 AND status = ?", 0).
			Count(&online)
	}

	summary.Total = int(total)
	summary.Online = int(online)
	summary.Offline = summary.Total - summary.Online
	summary.Abnormal = 0

	return summary
}

// getClusterDetails 获取每个集群的详情
func (s *PlatformHealthService) getClusterDetails(ctx context.Context) []ClusterDetail {
	var details []ClusterDetail

	if global.DB == nil {
		return details
	}

	// 从数据库获取所有集群
	type clusterInfo struct {
		ID          int64  `gorm:"column:id"`
		ClusterName string `gorm:"column:cluster_name"`
		Status      int    `gorm:"column:status"`
	}
	var clusters []clusterInfo
	global.DB.Table("kube_cluster").
		Select("id, cluster_name, status").
		Where("deleted_at = 0").
		Order("id ASC").
		Find(&clusters)

	// 并发获取每个集群的详情
	var wg sync.WaitGroup
	var mu sync.Mutex

	for _, c := range clusters {
		wg.Add(1)
		go func(cluster clusterInfo) {
			defer wg.Done()

			detail := ClusterDetail{
				ID:         cluster.ID,
				Name:       cluster.ClusterName,
				StatusCode: cluster.Status,
			}

			// 设置状态文本
			if cluster.Status == 0 {
				detail.Status = "online"
			} else {
				detail.Status = "offline"
			}

			// 尝试获取 K8s 客户端
			var client *kubernetes.Clientset
			if s.factory != nil {
				start := time.Now()
				if clients, err := s.factory.GetClient(ctx, cluster.ID); err == nil && clients != nil {
					client = clients.Kube
					detail.Connectable = true
					detail.Latency = time.Since(start).String()
				} else {
					detail.Status = "error"
					detail.Connectable = false
					detail.Latency = "-"
				}
			}

			// 如果可连接，获取集群数据
			if client != nil && detail.Connectable {
				detail.Nodes = s.getClusterNodeSummary(ctx, client)
				detail.Workloads = s.getClusterWorkloadSummary(ctx, client)
				detail.Services = s.getClusterServiceSummary(ctx, client)
				detail.Events = s.getClusterEventSummary(ctx, client)
			}

			mu.Lock()
			details = append(details, detail)
			mu.Unlock()
		}(c)
	}

	wg.Wait()
	return details
}

// getClusterNodeSummary 获取单个集群的节点概览
func (s *PlatformHealthService) getClusterNodeSummary(ctx context.Context, client *kubernetes.Clientset) NodeSummary {
	summary := NodeSummary{}
	if client == nil {
		return summary
	}

	nodes, err := client.CoreV1().Nodes().List(ctx, metav1.ListOptions{})
	if err != nil {
		return summary
	}

	var totalCPU, usedCPU, totalMem, usedMem, totalPods, usedPods int64

	for _, node := range nodes.Items {
		summary.Total++

		isReady := false
		for _, cond := range node.Status.Conditions {
			if cond.Type == corev1.NodeReady && cond.Status == corev1.ConditionTrue {
				isReady = true
				break
			}
		}

		if isReady {
			summary.Ready++
		} else {
			summary.NotReady++
		}

		if _, ok := node.Labels["node-role.kubernetes.io/master"]; ok {
			summary.Master++
		} else if _, ok := node.Labels["node-role.kubernetes.io/control-plane"]; ok {
			summary.Master++
		} else {
			summary.Worker++
		}

		totalCPU += node.Status.Allocatable.Cpu().MilliValue()
		totalMem += node.Status.Allocatable.Memory().Value()
		totalPods += node.Status.Allocatable.Pods().Value()
	}

	pods, err := client.CoreV1().Pods("").List(ctx, metav1.ListOptions{FieldSelector: "status.phase=Running"})
	if err == nil {
		usedPods = int64(len(pods.Items))
		for _, pod := range pods.Items {
			for _, container := range pod.Spec.Containers {
				usedCPU += container.Resources.Requests.Cpu().MilliValue()
				usedMem += container.Resources.Requests.Memory().Value()
			}
		}
	}

	if totalCPU > 0 {
		summary.CPUUsage = float64(usedCPU) / float64(totalCPU) * 100
	}
	if totalMem > 0 {
		summary.MemoryUsage = float64(usedMem) / float64(totalMem) * 100
	}
	if totalPods > 0 {
		summary.PodUsage = float64(usedPods) / float64(totalPods) * 100
	}

	return summary
}

// getClusterWorkloadSummary 获取单个集群的工作负载概览
func (s *PlatformHealthService) getClusterWorkloadSummary(ctx context.Context, client *kubernetes.Clientset) WorkloadSummary {
	summary := WorkloadSummary{}
	if client == nil {
		return summary
	}

	// Deployments
	deps, err := client.AppsV1().Deployments("").List(ctx, metav1.ListOptions{})
	if err == nil {
		summary.Deployments.Total = len(deps.Items)
		for _, d := range deps.Items {
			if d.Status.ReadyReplicas == d.Status.Replicas && d.Status.Replicas > 0 {
				summary.Deployments.Running++
			} else if d.Status.ReadyReplicas < d.Status.Replicas {
				summary.Deployments.Failed++
			}
		}
	}

	// StatefulSets
	sts, err := client.AppsV1().StatefulSets("").List(ctx, metav1.ListOptions{})
	if err == nil {
		summary.StatefulSets.Total = len(sts.Items)
		for _, st := range sts.Items {
			if st.Status.ReadyReplicas == st.Status.Replicas && st.Status.Replicas > 0 {
				summary.StatefulSets.Running++
			} else if st.Status.ReadyReplicas < st.Status.Replicas {
				summary.StatefulSets.Failed++
			}
		}
	}

	// DaemonSets
	ds, err := client.AppsV1().DaemonSets("").List(ctx, metav1.ListOptions{})
	if err == nil {
		summary.DaemonSets.Total = len(ds.Items)
		for _, d := range ds.Items {
			if d.Status.NumberReady == d.Status.DesiredNumberScheduled {
				summary.DaemonSets.Running++
			} else {
				summary.DaemonSets.Failed++
			}
		}
	}

	// Jobs
	jobs, err := client.BatchV1().Jobs("").List(ctx, metav1.ListOptions{})
	if err == nil {
		summary.Jobs.Total = len(jobs.Items)
		for _, j := range jobs.Items {
			if j.Status.Succeeded > 0 {
				summary.Jobs.Running++
			} else if j.Status.Failed > 0 {
				summary.Jobs.Failed++
			}
		}
	}

	// CronJobs
	cronJobs, err := client.BatchV1().CronJobs("").List(ctx, metav1.ListOptions{})
	if err == nil {
		summary.CronJobs.Total = len(cronJobs.Items)
		summary.CronJobs.Running = len(cronJobs.Items)
	}

	// Pods
	pods, err := client.CoreV1().Pods("").List(ctx, metav1.ListOptions{})
	if err == nil {
		summary.Pods.Total = len(pods.Items)
		for _, p := range pods.Items {
			switch p.Status.Phase {
			case corev1.PodRunning:
				summary.Pods.Running++
			case corev1.PodPending:
				summary.Pods.Pending++
			case corev1.PodSucceeded:
				summary.Pods.Succeeded++
			case corev1.PodFailed:
				summary.Pods.Failed++
			default:
				summary.Pods.Unknown++
			}
		}
	}

	return summary
}

// getClusterServiceSummary 获取单个集群的服务概览
func (s *PlatformHealthService) getClusterServiceSummary(ctx context.Context, client *kubernetes.Clientset) ServiceSummary {
	summary := ServiceSummary{}
	if client == nil {
		return summary
	}

	svcs, err := client.CoreV1().Services("").List(ctx, metav1.ListOptions{})
	if err == nil {
		summary.Total = len(svcs.Items)
		for _, svc := range svcs.Items {
			switch svc.Spec.Type {
			case corev1.ServiceTypeClusterIP:
				summary.ClusterIP++
			case corev1.ServiceTypeNodePort:
				summary.NodePort++
			case corev1.ServiceTypeLoadBalancer:
				summary.LoadBalancer++
			}
		}
	}

	ings, err := client.NetworkingV1().Ingresses("").List(ctx, metav1.ListOptions{})
	if err == nil {
		summary.Ingresses = len(ings.Items)
	}

	return summary
}

// getClusterEventSummary 获取单个集群的事件概览
func (s *PlatformHealthService) getClusterEventSummary(ctx context.Context, client *kubernetes.Clientset) EventSummary {
	summary := EventSummary{}
	if client == nil {
		return summary
	}

	events, err := client.CoreV1().Events("").List(ctx, metav1.ListOptions{})
	if err != nil {
		return summary
	}

	now := time.Now()
	todayStart := time.Date(now.Year(), now.Month(), now.Day(), 0, 0, 0, 0, now.Location())
	lastHour := now.Add(-1 * time.Hour)

	for _, event := range events.Items {
		summary.Total++
		if event.Type == "Warning" {
			summary.Warning++
		} else {
			summary.Normal++
		}

		eventTime := event.LastTimestamp.Time
		if eventTime.IsZero() {
			eventTime = event.EventTime.Time
		}

		if eventTime.After(todayStart) {
			summary.Today++
		}
		if eventTime.After(lastHour) {
			summary.LastHour++
		}
	}

	return summary
}

// getNodeSummary 获取节点概览 (汇总所有集群)
func (s *PlatformHealthService) getNodeSummary(ctx context.Context) NodeSummary {
	summary := NodeSummary{}

	// 获取所有在线集群的客户端
	clients := s.getAllK8sClients(ctx)
	if len(clients) == 0 {
		return summary
	}

	var totalCPU, usedCPU, totalMem, usedMem, totalPods, usedPods int64

	// 遍历所有集群汇总数据
	for _, client := range clients {
		nodes, err := client.CoreV1().Nodes().List(ctx, metav1.ListOptions{})
		if err != nil {
			global.Logger.Warn("获取集群节点列表失败", zap.Error(err))
			continue
		}

		for _, node := range nodes.Items {
			summary.Total++

			// 检查节点状态
			isReady := false
			for _, cond := range node.Status.Conditions {
				if cond.Type == corev1.NodeReady && cond.Status == corev1.ConditionTrue {
					isReady = true
					break
				}
			}

			if isReady {
				summary.Ready++
			} else {
				summary.NotReady++
			}

			// 检查是否为 Master 节点
			if _, ok := node.Labels["node-role.kubernetes.io/master"]; ok {
				summary.Master++
			} else if _, ok := node.Labels["node-role.kubernetes.io/control-plane"]; ok {
				summary.Master++
			} else {
				summary.Worker++
			}

			// 资源统计
			totalCPU += node.Status.Allocatable.Cpu().MilliValue()
			totalMem += node.Status.Allocatable.Memory().Value()
			totalPods += node.Status.Allocatable.Pods().Value()
		}

		// 获取实际使用量 (从 pods 统计)
		pods, err := client.CoreV1().Pods("").List(ctx, metav1.ListOptions{
			FieldSelector: "status.phase=Running",
		})
		if err == nil {
			usedPods += int64(len(pods.Items))
			for _, pod := range pods.Items {
				for _, container := range pod.Spec.Containers {
					usedCPU += container.Resources.Requests.Cpu().MilliValue()
					usedMem += container.Resources.Requests.Memory().Value()
				}
			}
		}
	}

	// 计算使用率
	if totalCPU > 0 {
		summary.CPUUsage = float64(usedCPU) / float64(totalCPU) * 100
	}
	if totalMem > 0 {
		summary.MemoryUsage = float64(usedMem) / float64(totalMem) * 100
	}
	if totalPods > 0 {
		summary.PodUsage = float64(usedPods) / float64(totalPods) * 100
	}

	return summary
}

// getWorkloadSummary 获取工作负载概览 (汇总所有集群)
func (s *PlatformHealthService) getWorkloadSummary(ctx context.Context) WorkloadSummary {
	summary := WorkloadSummary{}

	clients := s.getAllK8sClients(ctx)
	if len(clients) == 0 {
		return summary
	}

	// 遍历所有集群汇总数据
	for _, client := range clients {
		// Deployments
		deps, err := client.AppsV1().Deployments("").List(ctx, metav1.ListOptions{})
		if err == nil {
			summary.Deployments.Total += len(deps.Items)
			for _, d := range deps.Items {
				if d.Status.ReadyReplicas == d.Status.Replicas && d.Status.Replicas > 0 {
					summary.Deployments.Running++
				} else if d.Status.ReadyReplicas < d.Status.Replicas {
					summary.Deployments.Failed++
				}
			}
		}

		// StatefulSets
		sts, err := client.AppsV1().StatefulSets("").List(ctx, metav1.ListOptions{})
		if err == nil {
			summary.StatefulSets.Total += len(sts.Items)
			for _, st := range sts.Items {
				if st.Status.ReadyReplicas == st.Status.Replicas && st.Status.Replicas > 0 {
					summary.StatefulSets.Running++
				} else if st.Status.ReadyReplicas < st.Status.Replicas {
					summary.StatefulSets.Failed++
				}
			}
		}

		// DaemonSets
		ds, err := client.AppsV1().DaemonSets("").List(ctx, metav1.ListOptions{})
		if err == nil {
			summary.DaemonSets.Total += len(ds.Items)
			for _, d := range ds.Items {
				if d.Status.NumberReady == d.Status.DesiredNumberScheduled {
					summary.DaemonSets.Running++
				} else {
					summary.DaemonSets.Failed++
				}
			}
		}

		// Jobs
		jobs, err := client.BatchV1().Jobs("").List(ctx, metav1.ListOptions{})
		if err == nil {
			summary.Jobs.Total += len(jobs.Items)
			for _, j := range jobs.Items {
				if j.Status.Succeeded > 0 {
					summary.Jobs.Running++
				} else if j.Status.Failed > 0 {
					summary.Jobs.Failed++
				}
			}
		}

		// CronJobs
		cronJobs, err := client.BatchV1().CronJobs("").List(ctx, metav1.ListOptions{})
		if err == nil {
			summary.CronJobs.Total += len(cronJobs.Items)
			summary.CronJobs.Running += len(cronJobs.Items)
		}

		// Pods
		pods, err := client.CoreV1().Pods("").List(ctx, metav1.ListOptions{})
		if err == nil {
			summary.Pods.Total += len(pods.Items)
			for _, p := range pods.Items {
				switch p.Status.Phase {
				case corev1.PodRunning:
					summary.Pods.Running++
				case corev1.PodPending:
					summary.Pods.Pending++
				case corev1.PodSucceeded:
					summary.Pods.Succeeded++
				case corev1.PodFailed:
					summary.Pods.Failed++
				default:
					summary.Pods.Unknown++
				}
			}
		}
	}

	return summary
}

// getServiceSummary 获取服务概览 (汇总所有集群)
func (s *PlatformHealthService) getServiceSummary(ctx context.Context) ServiceSummary {
	summary := ServiceSummary{}

	clients := s.getAllK8sClients(ctx)
	if len(clients) == 0 {
		return summary
	}

	for _, client := range clients {
		// Services
		svcs, err := client.CoreV1().Services("").List(ctx, metav1.ListOptions{})
		if err == nil {
			summary.Total += len(svcs.Items)
			for _, svc := range svcs.Items {
				switch svc.Spec.Type {
				case corev1.ServiceTypeClusterIP:
					summary.ClusterIP++
				case corev1.ServiceTypeNodePort:
					summary.NodePort++
				case corev1.ServiceTypeLoadBalancer:
					summary.LoadBalancer++
				}
			}
		}

		// Ingresses
		ings, err := client.NetworkingV1().Ingresses("").List(ctx, metav1.ListOptions{})
		if err == nil {
			summary.Ingresses += len(ings.Items)
		}
	}

	return summary
}

// getEventSummary 获取 K8s 事件概览 (汇总所有集群)
func (s *PlatformHealthService) getEventSummary(ctx context.Context) EventSummary {
	summary := EventSummary{}

	clients := s.getAllK8sClients(ctx)
	if len(clients) == 0 {
		return summary
	}

	now := time.Now()
	todayStart := time.Date(now.Year(), now.Month(), now.Day(), 0, 0, 0, 0, now.Location())
	lastHour := now.Add(-1 * time.Hour)

	for _, client := range clients {
		events, err := client.CoreV1().Events("").List(ctx, metav1.ListOptions{})
		if err != nil {
			continue
		}

		for _, event := range events.Items {
			summary.Total++

			if event.Type == "Warning" {
				summary.Warning++
			} else {
				summary.Normal++
			}

			// 检查事件时间
			eventTime := event.LastTimestamp.Time
			if eventTime.IsZero() {
				eventTime = event.EventTime.Time
			}

			if eventTime.After(todayStart) {
				summary.Today++
			}
			if eventTime.After(lastHour) {
				summary.LastHour++
			}
		}
	}

	return summary
}

// getAllK8sClients 获取所有在线集群的 K8s 客户端
func (s *PlatformHealthService) getAllK8sClients(ctx context.Context) []*kubernetes.Clientset {
	var clients []*kubernetes.Clientset

	// 优先从数据库获取所有在线集群
	if s.factory != nil && global.DB != nil {
		var clusterIDs []int64
		global.DB.Table("kube_cluster").
			Where("deleted_at = 0 AND status = ?", 0).
			Pluck("id", &clusterIDs)

		for _, clusterID := range clusterIDs {
			if c, err := s.factory.GetClient(ctx, clusterID); err == nil && c != nil {
				clients = append(clients, c.Kube)
			}
		}
	}

	// 如果没有从数据库获取到，回退到全局管理集群客户端
	if len(clients) == 0 && global.ManagementKubeClient != nil {
		clients = append(clients, global.ManagementKubeClient)
	}

	return clients
}

// getK8sClient 获取单个 K8s 客户端 (兼容旧代码)
func (s *PlatformHealthService) getK8sClient() *kubernetes.Clientset {
	// 优先使用 factory 获取默认集群客户端
	if s.factory != nil {
		// 从数据库获取第一个在线集群
		var clusterID int64
		if global.DB != nil {
			global.DB.Table("kube_cluster").
				Where("deleted_at = 0 AND status = ?", 0).
				Order("id ASC").
				Limit(1).
				Pluck("id", &clusterID)

			if clusterID > 0 {
				if clients, err := s.factory.GetClient(context.Background(), clusterID); err == nil && clients != nil {
					return clients.Kube
				}
			}
		}
	}

	// 回退到全局管理集群客户端
	return global.ManagementKubeClient
}

// getAlertSummary 获取告警摘要
func (s *PlatformHealthService) getAlertSummary(ctx context.Context) AlertSummary {
	// 模拟数据，实际可从告警系统获取
	return AlertSummary{
		Total24h:     0,
		Critical:     0,
		Warning:      0,
		Info:         0,
		Acknowledged: 0,
	}
}

// getTaskQueueStatus 获取任务队列状态
func (s *PlatformHealthService) getTaskQueueStatus(ctx context.Context) TaskQueueStatus {
	status := TaskQueueStatus{
		AvgDelay: "0ms",
	}

	// 从数据库获取流水线任务统计
	if global.DB != nil {
		var pending, running, completed, failed int64

		global.DB.WithContext(ctx).
			Table("pipeline_runs").
			Where("status = ?", "pending").
			Count(&pending)

		global.DB.WithContext(ctx).
			Table("pipeline_runs").
			Where("status = ?", "running").
			Count(&running)

		global.DB.WithContext(ctx).
			Table("pipeline_runs").
			Where("status = ?", "success").
			Count(&completed)

		global.DB.WithContext(ctx).
			Table("pipeline_runs").
			Where("status = ?", "failed").
			Count(&failed)

		status.Pending = int(pending)
		status.Running = int(running)
		status.Completed = int(completed)
		status.Failed = int(failed)
	}

	return status
}

// checkComponents 检查各组件状态
func (s *PlatformHealthService) checkComponents(ctx context.Context) []ComponentStatus {
	components := make([]ComponentStatus, 0)
	now := time.Now().Format("2006-01-02 15:04:05")

	// 1. API Server
	apiStatus := ComponentStatus{
		Name:      "API Server",
		Status:    "ok",
		Latency:   "< 1ms",
		CheckedAt: now,
		Uptime:    formatDuration(time.Since(startTime)),
	}
	components = append(components, apiStatus)

	// 2. Database
	dbStatus := s.checkDatabase(ctx)
	dbStatus.CheckedAt = now
	components = append(components, dbStatus)

	// 3. Redis
	redisStatus := s.checkRedis(ctx)
	redisStatus.CheckedAt = now
	components = append(components, redisStatus)

	// 4. K8s Cluster Connection
	k8sStatus := s.checkK8sConnection(ctx)
	k8sStatus.CheckedAt = now
	components = append(components, k8sStatus)

	return components
}

// checkDatabase 检查数据库连接
func (s *PlatformHealthService) checkDatabase(ctx context.Context) ComponentStatus {
	status := ComponentStatus{
		Name:   "MySQL",
		Status: "ok",
	}

	if global.DB == nil {
		status.Status = "error"
		status.Description = "数据库未初始化"
		return status
	}

	db, err := global.DB.DB()
	if err != nil {
		status.Status = "error"
		status.Description = "获取数据库连接失败"
		return status
	}

	start := time.Now()
	if err := db.PingContext(ctx); err != nil {
		status.Status = "error"
		status.Description = "数据库连接失败: " + err.Error()
		return status
	}

	latency := time.Since(start)
	status.Latency = latency.String()
	status.Description = "连接正常"

	// 获取连接池状态
	stats := db.Stats()
	status.Memory = formatConnStats(stats)

	return status
}

// checkRedis 检查 Redis 连接
func (s *PlatformHealthService) checkRedis(ctx context.Context) ComponentStatus {
	status := ComponentStatus{
		Name:   "Redis",
		Status: "ok",
	}

	if global.RedisCli == nil {
		status.Status = "warning"
		status.Description = "Redis 未配置"
		status.Latency = "-"
		return status
	}

	start := time.Now()
	if err := global.RedisCli.Ping(ctx).Err(); err != nil {
		status.Status = "error"
		status.Description = "Redis 连接失败: " + err.Error()
		return status
	}

	latency := time.Since(start)
	status.Latency = latency.String()
	status.Description = "连接正常"

	return status
}

// checkK8sConnection 检查 K8s 集群连接
func (s *PlatformHealthService) checkK8sConnection(ctx context.Context) ComponentStatus {
	status := ComponentStatus{
		Name:   "Kubernetes",
		Status: "ok",
	}

	if global.ManagementKubeClient == nil {
		status.Status = "warning"
		status.Description = "未连接到 K8s 集群"
		status.Latency = "-"
		return status
	}

	start := time.Now()
	_, err := global.ManagementKubeClient.Discovery().ServerVersion()
	if err != nil {
		status.Status = "error"
		status.Description = "K8s API 连接失败"
		global.Logger.Error("K8s health check failed", zap.Error(err))
		return status
	}

	latency := time.Since(start)
	status.Latency = latency.String()
	status.Description = "API Server 连接正常"

	return status
}

// calculateOverallStatus 计算整体状态
func (s *PlatformHealthService) calculateOverallStatus(components []ComponentStatus) string {
	hasError := false
	hasWarning := false

	for _, c := range components {
		if c.Status == "error" {
			hasError = true
		}
		if c.Status == "warning" {
			hasWarning = true
		}
	}

	if hasError {
		return "unhealthy"
	}
	if hasWarning {
		return "degraded"
	}
	return "healthy"
}

// ============ 辅助函数 ============

func formatDuration(d time.Duration) string {
	days := int(d.Hours()) / 24
	hours := int(d.Hours()) % 24
	minutes := int(d.Minutes()) % 60

	if days > 0 {
		return fmt.Sprintf("%dd %dh %dm", days, hours, minutes)
	}
	if hours > 0 {
		return fmt.Sprintf("%dh %dm", hours, minutes)
	}
	return fmt.Sprintf("%dm", minutes)
}

func formatConnStats(stats sql.DBStats) string {
	return fmt.Sprintf("Open: %d, InUse: %d, Idle: %d",
		stats.OpenConnections, stats.InUse, stats.Idle)
}

// CheckComponentHealth 单独检查某个组件
func (s *PlatformHealthService) CheckComponentHealth(ctx context.Context, component string) (*ComponentStatus, error) {
	now := time.Now().Format("2006-01-02 15:04:05")

	switch component {
	case "database":
		status := s.checkDatabase(ctx)
		status.CheckedAt = now
		return &status, nil
	case "redis":
		status := s.checkRedis(ctx)
		status.CheckedAt = now
		return &status, nil
	case "kubernetes":
		status := s.checkK8sConnection(ctx)
		status.CheckedAt = now
		return &status, nil
	default:
		return nil, fmt.Errorf("unknown component: %s", component)
	}
}

// Ping 简单健康检查
func (s *PlatformHealthService) Ping(ctx context.Context) error {
	// 检查数据库
	if global.DB != nil {
		db, err := global.DB.DB()
		if err != nil {
			return err
		}
		if err := db.PingContext(ctx); err != nil {
			return err
		}
	}
	return nil
}
