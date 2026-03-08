# Bunny DNS 脚本 - 使用技巧和最佳实践

## 📚 目录
1. [基础使用](#基础使用)
2. [高级用法](#高级用法)
3. [自动化脚本](#自动化脚本)
4. [故障排除](#故障排除)
5. [安全最佳实践](#安全最佳实践)

## 基础使用

### 首次使用

```bash
# 1. 克隆或下载项目
cd bunny-shell-dns

# 2. 运行快速开始检查
./quickstart.sh

# 3. 启动脚本
./bunnydns.sh
```

### 菜单导航

```
主菜单 → 选择操作 → 输入必要信息 → 确认 → 操作完成
```

## 高级用法

### 1. 环境变量配置

**临时设置**（仅当前终端）：
```bash
export BUNNY_API_KEY="your-api-key"
./bunnydns.sh
```

**永久设置**（所有终端）：

编辑 `~/.bashrc` 或 `~/.zshrc`：
```bash
echo 'export BUNNY_API_KEY="your-api-key"' >> ~/.bashrc
source ~/.bashrc
```

### 2. 非交互模式

使用标准输入（stdin）提供输入：

```bash
# 添加 A 记录
./bunnydns.sh <<EOF
5
12345
A
www
192.0.2.1
3600
EOF
```

### 3. 输出重定向

保存操作输出：
```bash
# 将结果保存到文件
./bunnydns.sh > dns_operations.log

# 追加到日志文件
./bunnydns.sh >> dns_operations.log 2>&1
```

### 4. 后台运行

```bash
# 在后台运行
nohup ./bunnydns.sh > dns.log 2>&1 &

# 查看后台任务
jobs
```

## 自动化脚本

### 示例 1: 批量添加 A 记录

```bash
#!/bin/bash
# 批量添加多个 A 记录

API_KEY="your-api-key"
ZONE_ID="12345"

# 定义记录列表
declare -A records=(
    ["www"]="192.0.2.1"
    ["mail"]="192.0.2.2"
    ["ftp"]="192.0.2.3"
)

for name in "${!records[@]}"; do
    echo "添加 $name -> ${records[$name]}"
    BUNNY_API_KEY="$API_KEY" ./bunnydns.sh <<EOF
5
$ZONE_ID
A
$name
${records[$name]}
3600
EOF
done
```

### 示例 2: 备份所有 DNS 记录

```bash
#!/bin/bash
# 备份所有 DNS 记录到 JSON 文件

API_KEY="your-api-key"
BACKUP_DIR="dns_backups"
BACKUP_FILE="$BACKUP_DIR/backup_$(date +%Y%m%d_%H%M%S).json"

mkdir -p "$BACKUP_DIR"

# 使用 API 直接备份
curl -s -H "AccessKey: $API_KEY" \
    https://api.bunny.net/dnszone | \
    jq '.' > "$BACKUP_FILE"

echo "✅ 备份完成: $BACKUP_FILE"
```

### 示例 3: 定期检查 DNS 记录

```bash
#!/bin/bash
# 每天检查一次 DNS 记录

API_KEY="your-api-key"
ZONE_ID="12345"
LOG_FILE="dns_check.log"

# 从 Cron 运行（每天早上 9 点）
# 0 9 * * * ~/bunny-shell-dns/check_dns.sh

echo "检查时间: $(date)" >> "$LOG_FILE"
curl -s -H "AccessKey: $API_KEY" \
    https://api.bunny.net/dnszone/$ZONE_ID | \
    jq '.Records[] | "\(.Name) -> \(.Value)"' >> "$LOG_FILE"
echo "" >> "$LOG_FILE"
```

### 示例 4: DNS 记录同步

```bash
#!/bin/bash
# 将配置文件中的记录同步到 API

API_KEY="your-api-key"
ZONE_ID="12345"
CONFIG_FILE="dns_records.conf"

# dns_records.conf 格式:
# A www 192.0.2.1 3600
# AAAA www 2001:db8::1 3600
# MX @ mail.example.com 3600 10

while IFS= read -r type name value ttl priority; do
    [[ "$type" == "#" ]] && continue  # 跳过注释
    [[ -z "$type" ]] && continue      # 跳过空行
    
    if [[ "$type" == "MX" ]]; then
        echo "添加 MX 记录: $name -> $value (优先级: $priority)"
        # 实现添加逻辑
    else
        echo "添加 $type 记录: $name -> $value"
        # 实现添加逻辑
    fi
done < "$CONFIG_FILE"
```

## 故障排除

### 问题 1: "curl 未安装"

**解决方案**：
```bash
# 自动安装（脚本会提示）
# 或手动安装
sudo apt update && sudo apt install -y curl
```

### 问题 2: "API 请求失败"

**检查清单**：
```bash
# 1. 验证 API Key
echo $BUNNY_API_KEY

# 2. 测试网络连接
curl -I https://api.bunny.net

# 3. 验证 API Key 权限
curl -H "AccessKey: YOUR_KEY" \
    https://api.bunny.net/dnszone
```

### 问题 3: "401 未授权"

**解决方案**：
```bash
# API Key 可能错误或过期
# 1. 重新从控制面板复制 API Key
# 2. 确保没有空格或多余的换行符
# 3. 重新设置环境变量

unset BUNNY_API_KEY
export BUNNY_API_KEY="new-key"
```

### 问题 4: "IPv4 地址不合法"

**检查**：
- 确保地址格式正确：`x.x.x.x`
- 每个八位组范围：0-255
- 没有空格或特殊字符

**示例**：
```
❌ 错误: 192.0.2.256 （超出范围）
❌ 错误: 192.0.2 （不完整）
✅ 正确: 192.0.2.1
```

## 安全最佳实践

### 1. API Key 保护

❌ **不要做**：
```bash
# 不要在脚本中硬编码 API Key
API_KEY="your-actual-key"

# 不要公开分享包含 API Key 的配置文件
./bunnydns.sh > output.txt  # 可能包含敏感信息
```

✅ **应该做**：
```bash
# 使用环境变量
export BUNNY_API_KEY="key"

# 设置文件权限
chmod 600 ~/.bunny_api_key

# 从文件安全读取
export BUNNY_API_KEY=$(cat ~/.bunny_api_key)

# 使用 .gitignore 排除敏感文件
echo "*.env" >> .gitignore
echo ".bunny_api_key" >> .gitignore
```

### 2. 操作安全

- 总是确认删除操作（需要输入 'yes'）
- 定期备份 DNS 配置
- 在修改前查看当前记录
- 使用测试区域进行试验

### 3. 日志和审计

```bash
# 记录所有操作
./bunnydns.sh 2>&1 | tee -a bunny_dns.log

# 定期检查日志
tail -100 bunny_dns.log | grep "❌"  # 查看错误
```

### 4. 权限管理

```bash
# 脚本文件权限
chmod 755 bunnydns.sh      # 可执行脚本

# 日志文件权限
chmod 640 bunny_dns.log    # 只有用户和组可读

# 配置文件权限
chmod 600 ~/.bunny_api_key # 只有用户可读
```

## 性能优化

### 1. 减少 API 调用

```bash
# 使用批量操作而非逐个添加
# 一次性添加多个记录

# 缓存 Zone ID
ZONE_IDS_CACHE=$(mktemp)
./bunnydns.sh > "$ZONE_IDS_CACHE" <<EOF
1
0
EOF

# 从缓存读取而不是重复查询
```

### 2. 并行处理

```bash
#!/bin/bash
# 同时处理多个 Zone

zones=("id1" "id2" "id3")

for zone in "${zones[@]}"; do
    (
        # 在后台处理
        ./bunnydns.sh <<EOF
4
$zone
0
EOF
    ) &
done

wait  # 等待所有后台任务完成
```

## 常用场景速查

### 快速添加记录
```bash
# 菜单流程：选 5 → 输入 Zone ID → 选择类型 → 输入信息
./bunnydns.sh
```

### 快速查看记录
```bash
# 菜单流程：选 4 → 输入 Zone ID
./bunnydns.sh
```

### 快速删除记录
```bash
# 菜单流程：选 7 → 输入 Zone ID → 输入 Record ID
./bunnydns.sh
```

### 快速创建新区域
```bash
# 菜单流程：选 2 → 输入域名
./bunnydns.sh
```

## 扩展和集成

### 与 cron 集成

```bash
# 编辑 crontab
crontab -e

# 添加定时任务（每日备份）
0 2 * * * cd /path/to/bunny-shell-dns && \
    BUNNY_API_KEY=$API_KEY ./bunnydns.sh > backup_$(date +\%Y\%m\%d).log 2>&1
```

### 与 webhook 集成

```bash
# 接收 webhook 触发的 DNS 更新
# 在 webhook 处理脚本中调用 bunnydns.sh

#!/bin/bash
DATA=$(curl -s $WEBHOOK_URL)
ZONE_ID=$(echo "$DATA" | jq -r '.zone_id')
RECORD_TYPE=$(echo "$DATA" | jq -r '.type')

BUNNY_API_KEY="key" ./bunnydns.sh <<EOF
5
$ZONE_ID
$RECORD_TYPE
...
EOF
```

## 资源链接

- [官方 API 文档](https://docs.bunny.net/api-reference)
- [Bunny.net 控制面板](https://panel.bunny.net)
- [Bash 参考手册](https://www.gnu.org/software/bash/manual/)
- [jq 手册](https://stedolan.github.io/jq/)

---

**更新时间**: 2026-03-08  
**脚本版本**: 2.0
