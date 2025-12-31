# Prometheus Query Examples

## Basic Cluster Metrics

### 1. CPU Usage per Node
```promql
100 - (avg by(instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)
```

### 2. Memory Usage per Node
```promql
(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100
```

### 3. Disk Usage per Node
```promql
100 - ((node_filesystem_avail_bytes{mountpoint="/"} * 100) / node_filesystem_size_bytes{mountpoint="/"})
```

### 4. Network Traffic (Bytes received per second)
```promql
rate(node_network_receive_bytes_total[5m])
```

### 5. Network Traffic (Bytes transmitted per second)
```promql
rate(node_network_transmit_bytes_total[5m])
```

## Pod Metrics

### 6. CPU Usage by Pod
```promql
sum(rate(container_cpu_usage_seconds_total{container!="POD",container!=""}[5m])) by (pod, namespace)
```

### 7. Memory Usage by Pod
```promql
sum(container_memory_working_set_bytes{container!="POD",container!=""}) by (pod, namespace)
```

### 8. Pod Count by Namespace
```promql
count by(namespace) (kube_pod_info)
```

### 9. Pod Restarts
```promql
rate(kube_pod_container_status_restarts_total[5m])
```

## Application-Specific (Meo Stationery)

### 10. Backend Pod CPU Usage
```promql
sum(rate(container_cpu_usage_seconds_total{namespace="meo-stationery",pod=~"backend-.*"}[5m])) by (pod)
```

### 11. Backend Pod Memory Usage
```promql
sum(container_memory_working_set_bytes{namespace="meo-stationery",pod=~"backend-.*"}) by (pod)
```

### 12. PostgreSQL Pod CPU Usage
```promql
sum(rate(container_cpu_usage_seconds_total{namespace="meo-stationery",pod=~"postgres-.*"}[5m])) by (pod)
```

### 13. PostgreSQL Pod Memory Usage
```promql
sum(container_memory_working_set_bytes{namespace="meo-stationery",pod=~"postgres-.*"}) by (pod)
```

## Kubernetes Metrics

### 14. Number of Nodes
```promql
count(kube_node_info)
```

### 15. Node Status (1 = Ready, 0 = Not Ready)
```promql
kube_node_status_condition{condition="Ready",status="true"}
```

### 16. Available CPU Cores per Node
```promql
kube_node_status_allocatable{resource="cpu"}
```

### 17. Available Memory per Node
```promql
kube_node_status_allocatable{resource="memory"}
```

### 18. Container Restarts (Last 1 hour)
```promql
increase(kube_pod_container_status_restarts_total[1h])
```

## Network & Service Metrics

### 19. HTTP Requests per Second (if available)
```promql
rate(http_requests_total[5m])
```

### 20. Request Duration (if available)
```promql
histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))
```

## Useful Built-in Queries

### 21. All Available Metrics (just to see what's available)
```promql
{__name__=~".+"}
```

### 22. Up Status (1 = up, 0 = down)
```promql
up
```

### 23. Targets Status
```promql
up{job="kubernetes-nodes"}
```

## Quick Health Checks

### 24. Cluster Health Score (simplified)
```promql
avg(up{job=~"kubernetes.*"}) * 100
```

### 25. Total Pods Running
```promql
count(kube_pod_status_phase{phase="Running"})
```

### 26. Pending Pods
```promql
count(kube_pod_status_phase{phase="Pending"})
```

### 27. Failed Pods
```promql
count(kube_pod_status_phase{phase="Failed"})
```

## Storage Metrics

### 28. Persistent Volume Claims Usage
```promql
kubelet_volume_stats_used_bytes / kubelet_volume_stats_capacity_bytes * 100
```

### 29. EBS Volume I/O Operations
```promql
rate(aws_ebs_volume_io_ops_total[5m])
```

## Alerting Examples

### 30. High CPU Usage (above 80%)
```promql
100 - (avg by(instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) > 80
```

### 31. Low Memory (below 20% available)
```promql
(node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes) * 100 < 20
```

### 32. High Disk Usage (above 85%)
```promql
((node_filesystem_size_bytes{mountpoint="/"} - node_filesystem_avail_bytes{mountpoint="/"}) / node_filesystem_size_bytes{mountpoint="/"}) * 100 > 85
```

---

## Tips:
- Press **Shift+Enter** for newlines in queries
- Click **Execute** or press **Enter** to run
- Use **Graph** tab to visualize time-series data
- Use **Table** tab for instant values
- Hover over results to see exact values
- Click on labels to filter/group by them


