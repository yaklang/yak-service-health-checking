#!/bin/bash

# =============================================================================
# YAK Health Checking Service 部署脚本
# 功能: 自动部署和配置 YAK 健康检查服务
# 用途: 检查仓库、安装引擎、配置 systemd 服务
# =============================================================================

set -e  # 遇到错误立即退出

echo "============================================"
echo "YAK Health Checking Service Deployment"
echo "============================================"

# 配置变量
REPO_URL="https://github.com/yaklang/yak-service-health-checking"
REPO_DIR="/root/yak-service-health-checking"
YAK_ENGINE_PATH="/usr/local/bin/yak"
REQUIRED_VERSION="1.4.4-alpha1027"
SERVICE_NAME="yak-health-checking"
SERVICE_PORT="9901"

echo "=== Step 1: 验证代码仓库 ==="

# 检查是否存在仓库目录（CI 应该已经处理了代码更新）
if [ -d "$REPO_DIR" ]; then
    echo "Repository directory exists: $REPO_DIR"
    cd "$REPO_DIR"
    
    # 验证是否是正确的仓库
    if [ -f "health-checking.yak" ]; then
        echo "✓ Health checking script found"
    else
        echo "ERROR: health-checking.yak not found in $REPO_DIR"
        exit 1
    fi
    
    # 显示当前版本信息
    if [ -d ".git" ] && command -v git >/dev/null 2>&1; then
        CURRENT_COMMIT=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
        echo "Current commit: $CURRENT_COMMIT"
    fi
else
    echo "ERROR: Repository directory $REPO_DIR does not exist"
    echo "This should have been handled by CI. Attempting fallback..."
    
    # 备用方案：尝试克隆仓库
    cd /root
    if command -v git >/dev/null 2>&1; then
        git clone "$REPO_URL" "$REPO_DIR"
        echo "✓ Repository cloned as fallback"
    else
        echo "ERROR: Git not available and repository not found"
        exit 1
    fi
    cd "$REPO_DIR"
fi

echo "✓ Repository verification completed"

echo ""
echo "=== Step 2: 检查和安装 YAK 引擎 ==="

# 检查是否存在 yak 引擎
if [ -f "$YAK_ENGINE_PATH" ]; then
    echo "YAK engine found at: $YAK_ENGINE_PATH"
    
    # 检查版本
    CURRENT_VERSION=$($YAK_ENGINE_PATH version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+-[a-zA-Z0-9]+' | head -1 || echo "unknown")
    echo "Current version: $CURRENT_VERSION"
    echo "Required version: $REQUIRED_VERSION"
    
    # 简单的版本比较 (这里假设需要的版本更新)
    if [[ "$CURRENT_VERSION" == "$REQUIRED_VERSION" ]]; then
        echo "✓ YAK engine version is up to date"
    else
        echo "YAK engine version needs update, downloading..."
        NEED_DOWNLOAD=true
    fi
else
    echo "YAK engine not found, downloading..."
    NEED_DOWNLOAD=true
fi

# 下载 YAK 引擎
if [[ "$NEED_DOWNLOAD" == "true" ]]; then
    YAK_URL="https://yaklang.oss-accelerate.aliyuncs.com/yak/${REQUIRED_VERSION}/yak_linux_amd64"
    
    echo "Downloading YAK engine from: $YAK_URL"
    
    # 创建临时文件
    TEMP_YAK="/tmp/yak_download"
    
    # 下载文件
    if wget -q --show-progress -O "$TEMP_YAK" "$YAK_URL"; then
        echo "Download completed successfully"
        
        # 验证下载的文件
        if [ -f "$TEMP_YAK" ] && [ -s "$TEMP_YAK" ]; then
            # 移动到目标位置
            sudo mv "$TEMP_YAK" "$YAK_ENGINE_PATH"
            sudo chmod +x "$YAK_ENGINE_PATH"
            
            echo "✓ YAK engine installed successfully to $YAK_ENGINE_PATH"
            
            # 验证安装
            if $YAK_ENGINE_PATH version >/dev/null 2>&1; then
                echo "✓ YAK engine verification passed"
            else
                echo "⚠ YAK engine verification failed, but continuing..."
            fi
        else
            echo "ERROR: Downloaded file is empty or invalid"
            exit 1
        fi
    else
        echo "ERROR: Failed to download YAK engine"
        exit 1
    fi
fi

echo ""
echo "=== Step 3: 停止现有服务 (如果存在) ==="

# 检查服务是否存在并停止
if systemctl list-units --full -all | grep -Fq "$SERVICE_NAME.service"; then
    echo "Stopping existing service: $SERVICE_NAME"
    sudo systemctl stop "$SERVICE_NAME" || echo "Service was not running"
    sudo systemctl disable "$SERVICE_NAME" || echo "Service was not enabled"
    echo "✓ Existing service stopped"
else
    echo "No existing service found"
fi

echo ""
echo "=== Step 4: 安装和配置 systemd 服务 ==="

# 确保在正确的目录
cd "$REPO_DIR"

# 使用 yak 安装 systemd 服务
echo "Installing systemd service..."

# 构建脚本参数
SCRIPT_ARGS="--port $SERVICE_PORT --html-dir $REPO_DIR"

# 如果设置了 LARK_BOT_NOTIFY_WEBHOOK 环境变量，添加到脚本参数中
if [ -n "$LARK_BOT_NOTIFY_WEBHOOK" ]; then
    echo "Adding bot webhook to service arguments..."
    SCRIPT_ARGS="$SCRIPT_ARGS --bot-webhook '$LARK_BOT_NOTIFY_WEBHOOK'"
else
    echo "No bot webhook configured for service"
fi

sudo $YAK_ENGINE_PATH install-to-systemd \
    --service-name "$SERVICE_NAME" \
    --script-path "./health-checking.yak" \
    --script-args "$SCRIPT_ARGS"

if [ $? -eq 0 ]; then
    echo "✓ Systemd service installed successfully"
else
    echo "ERROR: Failed to install systemd service"
    exit 1
fi

echo ""
echo "=== Step 5: 启动和启用服务 ==="

# 重新加载 systemd 配置
sudo systemctl daemon-reload

# 启用服务 (开机自启)
sudo systemctl enable "$SERVICE_NAME"

# 启动服务
sudo systemctl start "$SERVICE_NAME"

# 等待服务启动
echo "Waiting for service to start..."
sleep 5

# 检查服务状态
if sudo systemctl is-active --quiet "$SERVICE_NAME"; then
    echo "✓ Service is running"
else
    echo "ERROR: Service failed to start"
    echo "Service status:"
    sudo systemctl status "$SERVICE_NAME" --no-pager
    exit 1
fi

echo ""
echo "=== Step 6: 验证服务可访问性 ==="

# 等待端口可用
echo "Waiting for port $SERVICE_PORT to be available..."
for i in {1..30}; do
    if curl -f "http://127.0.0.1:$SERVICE_PORT" >/dev/null 2>&1; then
        echo "✓ Service is accessible on port $SERVICE_PORT"
        break
    fi
    
    if [ $i -eq 30 ]; then
        echo "ERROR: Service is not accessible on port $SERVICE_PORT after 30 attempts"
        echo "Service status:"
        sudo systemctl status "$SERVICE_NAME" --no-pager
        echo "Service logs:"
        sudo journalctl -u "$SERVICE_NAME" --no-pager -n 20
        exit 1
    fi
    
    echo "Attempt $i/30: Service not yet accessible, waiting..."
    sleep 2
done

# 测试 HTTP 响应
echo "Testing HTTP response..."
HTTP_RESPONSE=$(curl -s "http://127.0.0.1:$SERVICE_PORT" | head -c 100)
if [ -n "$HTTP_RESPONSE" ]; then
    echo "✓ Service is responding with data"
    echo "Response preview: ${HTTP_RESPONSE}..."
else
    echo "WARNING: Service is accessible but not returning data"
fi

echo ""
echo "============================================"
echo "✅ Deployment Completed Successfully!"
echo "============================================"
echo ""
echo "Service Details:"
echo "  - Name: $SERVICE_NAME"
echo "  - Port: $SERVICE_PORT"
echo "  - Status: $(sudo systemctl is-active $SERVICE_NAME)"
echo "  - Enabled: $(sudo systemctl is-enabled $SERVICE_NAME)"
echo "  - Repository: $REPO_DIR"
echo "  - YAK Engine: $YAK_ENGINE_PATH"
echo ""
echo "Service Management Commands:"
echo "  - Check status: sudo systemctl status $SERVICE_NAME"
echo "  - View logs: sudo journalctl -u $SERVICE_NAME -f"
echo "  - Restart: sudo systemctl restart $SERVICE_NAME"
echo "  - Stop: sudo systemctl stop $SERVICE_NAME"
echo ""
echo "Access URL: http://127.0.0.1:$SERVICE_PORT"
echo "============================================"
