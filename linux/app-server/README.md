# Nginx服务器监控方案

## 项目简介

本项目提供了一套完整的Nginx服务器监控方案，用于定位和解决服务器晚上访问慢的问题。通过监控系统资源、Nginx性能、网络性能和后端应用性能，帮助您快速定位性能瓶颈。

## 目录结构

```
app-server/
├── monitor.py          # 监控管理主脚本
├── scripts/            # 监控脚本目录
│   ├── system/         # 系统资源监控脚本
│   ├── nginx/          # Nginx性能监控脚本
│   ├── network/        # 网络性能监控脚本
│   ├── backend/        # 后端应用性能监控脚本
│   └── visualization/  # 数据可视化和分析脚本
├── data/               # 监控数据存储目录
├── logs/               # 日志文件存储目录
└── README.md           # 项目说明文件
```

## 监控方案

### 1. 系统资源监控

- **监控指标**：CPU使用率、内存使用情况、磁盘使用情况、磁盘I/O、系统负载
- **监控工具**：`scripts/system/system_monitor.py`
- **数据存储**：`data/system/` 目录下的JSON文件

### 2. Nginx性能监控

- **监控指标**：活跃连接数、请求处理情况、错误率、请求时间
- **监控工具**：`scripts/nginx/nginx_monitor.py`
- **数据存储**：`data/nginx/` 目录下的JSON文件

### 3. 网络性能监控

- **监控指标**：网络带宽使用情况、网络延迟、丢包率、连接数
- **监控工具**：`scripts/network/network_monitor.py`
- **数据存储**：`data/network/` 目录下的JSON文件

### 4. 后端应用性能监控

- **监控指标**：响应时间、错误率、并发请求数
- **监控工具**：`scripts/backend/backend_monitor.py`
- **数据存储**：`data/backend/` 目录下的JSON文件

## 环境依赖

- Python 3.6+
- psutil
- requests
- pandas
- matplotlib

## 安装依赖

```bash
pip install psutil requests pandas matplotlib
```

## 使用方法

### 1. 启动监控

启动所有监控脚本：

```bash
python monitor.py start
```

启动指定类型的监控脚本：

```bash
python monitor.py start nginx
```

### 2. 停止监控

停止所有监控脚本：

```bash
python monitor.py stop
```

停止指定类型的监控脚本：

```bash
python monitor.py stop nginx
```

### 3. 查看监控状态

```bash
python monitor.py status
```

### 4. 运行数据分析

```bash
python monitor.py analyze
```

分析完成后，会在 `data/visualization/` 目录下生成以下文件：
- `system_resources.png` - 系统资源使用趋势图
- `nginx_performance.png` - Nginx性能指标趋势图
- `network_performance.png` - 网络性能指标趋势图
- `backend_performance.png` - 后端应用性能指标趋势图
- `monitoring_summary.md` - 监控数据汇总报告

## 问题定位指南

### 1. 系统资源瓶颈

- **CPU使用率过高**：检查是否有进程占用过多CPU，可能需要优化代码或增加服务器资源
- **内存使用率过高**：检查是否有内存泄漏，可能需要优化代码或增加内存
- **磁盘I/O过高**：检查是否有大量磁盘读写操作，可能需要优化数据库查询或使用缓存

### 2. Nginx性能瓶颈

- **活跃连接数过高**：调整Nginx配置，增加worker_processes和worker_connections
- **错误率过高**：检查Nginx配置和后端应用是否有问题
- **请求时间过长**：检查后端应用响应时间，可能需要优化后端代码

### 3. 网络性能瓶颈

- **网络延迟过高**：检查网络连接和带宽，可能需要升级网络设备或增加带宽
- **网络丢包率过高**：检查网络连接质量，可能需要修复网络故障
- **带宽使用率过高**：检查是否有大量网络流量，可能需要优化传输内容或增加带宽

### 4. 后端应用瓶颈

- **响应时间过长**：优化后端代码，检查数据库查询性能
- **错误率过高**：修复后端应用中的错误
- **并发请求数过高**：优化后端应用的并发处理能力，可能需要使用缓存或负载均衡

## 配置说明

### 1. Nginx配置

确保Nginx启用了stub_status模块，在nginx.conf中添加以下配置：

```nginx
location /nginx_status {
    stub_status on;
    access_log off;
    allow 127.0.0.1;
    deny all;
}
```

### 2. 监控脚本配置

- **系统监控**：无需特殊配置
- **Nginx监控**：修改 `scripts/nginx/nginx_monitor.py` 中的 `stub_status_url` 和 `access_log_path`
- **网络监控**：无需特殊配置
- **后端应用监控**：修改 `scripts/backend/backend_monitor.py` 中的 `endpoints` 列表

## 最佳实践

1. **持续监控**：建议在生产环境中持续运行监控脚本，以便及时发现问题
2. **定期分析**：定期运行数据分析，了解服务器性能趋势
3. **告警机制**：可以根据监控数据设置告警阈值，当指标超过阈值时发送告警
4. **性能优化**：根据监控数据和分析报告，有针对性地进行性能优化

## 示例

### 启动所有监控

```bash
python monitor.py start
```

### 查看监控状态

```bash
python monitor.py status
```

输出示例：

```
监控脚本状态:
--------------------------------------------------
system: 运行中 (PID: 12345)
nginx: 运行中 (PID: 12346)
network: 运行中 (PID: 12347)
backend: 运行中 (PID: 12348)
--------------------------------------------------
```

### 运行数据分析

```bash
python monitor.py analyze
```

分析完成后，查看 `data/visualization/monitoring_summary.md` 文件，了解服务器性能状况和可能的瓶颈。

## 总结

本监控方案通过多维度监控服务器性能，帮助您快速定位和解决Nginx服务器晚上访问慢的问题。通过持续监控和定期分析，您可以及时发现性能瓶颈，优化服务器配置和应用代码，提高服务器的稳定性和性能。
