# Bunny DNS Shell 管理脚本

![Bunny](https://img.shields.io/badge/Bunny-DNS-blue) ![Bash](https://img.shields.io/badge/Bash-5.0%2B-green) ![License](https://img.shields.io/badge/License-MIT-yellow)

自建基于 Shell 的 Bunny DNS API 调用脚本，提供完整的 DNS 区域和记录管理功能。

## 功能特性

✨ **完整的DNS管理**
- ✅ 列表、添加、更新、删除 DNS 区域
- ✅ 列表、添加、更新、删除 DNS 记录
- ✅ 支持多种 DNS 记录类型 (A, AAAA, CNAME, MX, TXT, NS, SRV, CAA)
- ✅ 交互式菜单和批量操作

🛡️ **安全性与验证**
- ✅ IPv4 和 IPv6 地址验证
- ✅ 域名格式验证
- ✅ 操作确认机制（防止误删除）
- ✅ API 密钥通过环境变量管理

⚙️ **灵活的工具支持**
- ✅ 支持 jq 进行高效 JSON 解析
- ✅ 纯 Bash/正则表达式备选方案（无依赖）
- ✅ 完整的错误处理和提示

## 快速开始

### 环境要求

- Bash 4.0+
- curl
- jq（可选，提供更好的 JSON 解析）

**在 Ubuntu/Debian 上安装依赖：**

```bash
sudo apt update
sudo apt install -y curl
sudo apt install -y jq        # 可选，推荐
```

### 配置 API Key

#### 方法 1：环境变量（推荐）

```bash
export BUNNY_API_KEY="your-api-key-here"
./bunnydns.sh
```

#### 方法 2：交互式输入

```bash
./bunnydns.sh
# 脚本会提示输入 API Key
```

### 获取 API Key

1. 登录 [Bunny.net 控制面板](https://panel.bunny.net)
2. 进入 Account 设置
3. 找到 API Key 部分
4. 复制您的 API Key

## 使用指南

### 基本命令

```bash
# 使脚本可执行
chmod +x bunnydns.sh

# 运行脚本
./bunnydns.sh

# 或使用环境变量直接运行
BUNNY_API_KEY="your-key" ./bunnydns.sh
```

### 菜单选项

#### 主菜单

```
1. 查看 DNS 区域并管理记录  - 列出所有域名，交互式管理记录
2. 添加 DNS 区域          - 创建新的 DNS 区域
3. 删除 DNS 区域          - 删除指定的 DNS 区域
4. 单独查看记录           - 查看特定区域的所有记录
5. 单独添加记录           - 向特定区域添加新记录
6. 单独更新记录           - 修改特定区域的现有记录
7. 单独删除记录           - 删除特定区域的记录
h. 帮助信息              - 显示详细帮助
0. 退出                  - 退出程序
```

#### Zone 管理菜单

进入区域后可进行以下操作：

```
1. 查看记录   - 显示该区域的所有 DNS 记录
2. 添加记录   - 创建新的 DNS 记录
3. 更新记录   - 修改现有的 DNS 记录
4. 删除记录   - 删除不需要的 DNS 记录
0. 返回主菜单 - 返回到主菜单
```

## 支持的 DNS 记录类型

| 类型 | 编号 | 用途 |
|------|------|------|
| A | 1 | IPv4 地址解析 |
| AAAA | 28 | IPv6 地址解析 |
| CNAME | 5 | 规范名称记录 |
| MX | 15 | 邮件交换记录 |
| TXT | 16 | 文本记录 |
| NS | 2 | 名字服务器记录 |
| SRV | 33 | 服务记录 |
| CAA | 257 | 证书颁发机构授权 |

## 使用示例

### 示例 1：添加 A 记录

```bash
./bunnydns.sh
# 选择操作: 5（单独添加记录）
# 输入 Zone ID: 12345
# 输入记录类型: A
# 输入记录名: www
# 输入记录值: 192.0.2.1
# 输入 TTL: 3600
# ✅ 操作成功
```

### 示例 2：管理 MX 记录

```bash
./bunnydns.sh
# 选择操作: 5（单独添加记录）
# 输入 Zone ID: 12345
# 输入记录类型: MX
# 输入记录名: @
# 输入记录值: mail.example.com
# 输入 TTL: 3600
# 输入 MX 优先级: 10
# ✅ 操作成功
```

### 示例 3：查看所有区域

```bash
./bunnydns.sh
# 选择操作: 1（查看 DNS 区域）
# 
# === DNS 区域列表 ===
# 域名                          Zone ID
# -----                        -----
# example.com                  12345
# test.org                     67890
```

## 错误处理

脚本包含全面的错误处理：

- **API 错误**：显示服务器返回的原因
- **验证错误**：检查 IPv4、IPv6 和域名格式
- **输入错误**：提示用户输入的问题
- **权限错误**：提示 API Key 问题

示例错误提示：

```
❌ IPv4 地址不合法
❌ 无效的域名格式
❌ Zone ID 不能为空
❌ 操作失败: 未授权的请求
```

## 常见问题

### Q: 如何重置 API Key？
A: 编辑脚本中的 `API_KEY` 变量或使用环境变量：
```bash
export BUNNY_API_KEY=" new-key"
./bunnydns.sh
```

### Q: 支持批量操作吗？
A: 目前不支持直接批量操作，但您可以编写循环脚本来调用此脚本。

示例：
```bash
for zone_id in 12345 67890; do
    BUNNY_API_KEY="your-key" ./bunnydns.sh <<EOF
4
$zone_id
EOF
done
```

### Q: 如何导出 DNS 记录？
A: 目前脚本支持查看记录，可以通过重定向来保存输出：
```bash
./bunnydns.sh > dns_backup.txt <<EOF
1
0
EOF
```

### Q: 脚本在没有 jq 时工作吗？
A: 可以。脚本会自动检测 jq 是否存在，如果不存在会使用正则表达式解析 JSON。虽然功能相同，但安装 jq 能获得更好的性能和可靠性。

## 脚本结构

```
bunnydns.sh
├── 检查依赖 (curl, jq)
├── 配置管理
├── API 基础函数
│   ├── api_request()        # API 请求
│   ├── check_api_response() # 响应验证
│   └── get_json_field()     # JSON 解析
├── 验证函数
│   ├── is_valid_ipv4()
│   ├── is_valid_ipv6()
│   ├── is_valid_name()
│   └── is_valid_domain()
├── 区域管理
│   ├── list_zones()
│   ├── add_zone()
│   └── delete_zone()
├── 记录管理
│   ├── list_records()
│   ├── add_record()
│   ├── update_record()
│   └── delete_record()
├── UI 组件
│   ├── zone_menu()
│   └── show_help()
└── 主菜单循环
```

## API 文档参考

更多信息请参考官方 API 文档：
- [Bunny DNS API 文档](https://docs.bunny.net/api-reference/core/dns-zone/list-dns-zones)
- [Bunny 控制面板](https://panel.bunny.net)

## 许可证

MIT License

## 贡献

欢迎提交 Issue 和 Pull Request！

## 相关资源

- [Bunny.net 官网](https://bunny.net)
- [Bash 官方文档](https://www.gnu.org/software/bash/manual/)
- [jq 官方文档](https://stedolan.github.io/jq/)