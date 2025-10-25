# YAK Service Health Checking

## 项目概述

YAK Service Health Checking 是一个基于 Yaklang 开发的分布式服务健康监控系统。该系统提供实时的服务状态监控、可视化展示和自动化部署能力，专为企业级服务监控场景设计。

## 核心功能

### 服务监控
- 支持 HTTP/HTTPS 服务健康检查
- 可配置的检查间隔和超时时间
- 实时状态更新和历史记录追踪
- 并发安全的数据处理机制

### 可视化展示
- 现代化的 Web 界面展示服务状态
- 实时数据更新，无需手动刷新
- 响应式设计，支持多设备访问
- 清晰的状态指示和错误信息展示

### 自动化部署
- GitHub Actions 集成的 CI/CD 流程
- 自动化服务部署和配置管理
- 可选的 SSL 证书自动申请和配置
- systemd 服务集成，支持开机自启

## 技术架构

### 后端技术栈
- **Yaklang**: 核心运行时环境
- **HTTP Server**: 基于 Yaklang httpserver 模块
- **并发处理**: 使用 sync.Mutex 确保数据安全
- **JSON 处理**: 标准 JSON 序列化和反序列化

### 前端技术栈
- **原生 HTML/CSS/JavaScript**: 轻量级前端实现
- **实时更新**: 基于定时轮询的数据刷新
- **响应式设计**: 适配多种屏幕尺寸

### 部署技术栈
- **systemd**: Linux 系统服务管理
- **Nginx**: 反向代理和 SSL 终端
- **Let's Encrypt**: 免费 SSL 证书自动申请
- **GitHub Actions**: 持续集成和自动部署

## 安装部署

### 系统要求
- Linux 操作系统（推荐 Ubuntu 20.04+ 或 CentOS 7+）
- Yaklang 引擎 v1.4.4-alpha1025 或更高版本
- 具备 sudo 权限的用户账户
- 网络连接用于下载依赖和证书申请

### 手动部署

1. **克隆仓库**
   ```bash
   git clone https://github.com/yaklang/yak-service-health-checking.git
   cd yak-service-health-checking
   ```

2. **执行部署脚本**
   ```bash
   chmod +x deploy.sh
   ./deploy.sh
   ```

3. **配置服务参数**
   ```bash
   # 自定义端口和检查间隔
   yak health-checking.yak --port 9901 --interval 60 --html-dir /path/to/html
   ```

### 自动化部署

通过 GitHub Actions 实现自动部署：

1. **配置 GitHub Secrets**
   - `HEALTH_CHECKING_HOST_PRI`: SSH 私钥
   - `HEALTH_CHECKING_HOST_ADDR`: 目标服务器地址

2. **配置 GitHub Variables（可选 SSL）**
   - `ENABLE_SSL`: 设置为 `true` 启用 SSL
   - `SSL_DOMAIN`: SSL 证书域名
   - `SSL_EMAIL`: SSL 证书通知邮箱

3. **触发部署**
   - 推送代码到 main 分支自动触发部署
   - 或在 GitHub Actions 页面手动触发

### SSL 证书配置

使用内置的证书安装脚本：

```bash
# 交互式安装
./scripts/install-certs.sh

# 非交互式安装
./scripts/install-certs.sh --domain example.com --port 9901 --email admin@example.com -y
```

## 使用说明

### 命令行参数

| 参数 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `--port` | 整数 | 8080 | HTTP 服务监听端口 |
| `--interval` | 整数 | 60 | 健康检查间隔（秒） |
| `--timeout` | 整数 | 10 | HTTP 请求超时时间（秒） |
| `--html-dir` | 字符串 | `/root/yak-services-health-checking/` | 静态文件目录路径 |

### 服务管理

```bash
# 查看服务状态
sudo systemctl status yak-health-checking

# 启动服务
sudo systemctl start yak-health-checking

# 停止服务
sudo systemctl stop yak-health-checking

# 重启服务
sudo systemctl restart yak-health-checking

# 查看服务日志
sudo journalctl -u yak-health-checking -f
```

### SSL 证书管理

```bash
# 检查证书状态
ssl-manager status

# 手动续期证书
ssl-manager renew
```

## 配置说明

### 服务配置

服务配置通过命令行参数或环境变量进行设置。主要配置项包括：

- **监听端口**: 服务 HTTP 接口的监听端口
- **检查间隔**: 执行健康检查的时间间隔
- **超时设置**: HTTP 请求的超时时间限制
- **静态文件**: Web 界面文件的存储路径

### 监控目标配置

监控目标在 `health-checking.yak` 脚本中进行配置，支持：

- HTTP/HTTPS 端点监控
- 自定义请求头和参数
- 响应状态码验证
- 响应时间统计

## 项目意义

### 运维价值
- **提升服务可靠性**: 及时发现和响应服务异常
- **降低运维成本**: 自动化监控减少人工巡检工作量
- **优化响应时间**: 快速定位问题，缩短故障恢复时间

### 技术价值
- **Yaklang 生态**: 展示 Yaklang 在系统监控领域的应用能力
- **现代化部署**: 集成 CI/CD 最佳实践，支持自动化运维
- **安全性保障**: 内置 SSL 支持，确保监控数据传输安全

### 业务价值
- **服务质量保障**: 持续监控确保服务稳定性
- **数据驱动决策**: 提供服务性能数据支持业务优化
- **合规性支持**: 满足企业级监控和审计要求

## 许可证

本项目采用开源许可证发布，具体许可证信息请查看 LICENSE 文件。

## 贡献指南

欢迎提交 Issue 和 Pull Request 来改进项目。在贡献代码前，请确保：

1. 代码符合项目的编码规范
2. 添加必要的测试用例
3. 更新相关文档说明
4. 通过所有自动化测试

## 技术支持

如需技术支持或有任何问题，请通过以下方式联系：

- 提交 GitHub Issue
- 参与项目讨论区
- 查阅 Yaklang 官方文档

---

**注意**: 本项目依赖 Yaklang 引擎，请确保已正确安装和配置 Yaklang 运行环境。
