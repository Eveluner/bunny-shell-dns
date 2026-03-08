# 🔧 DNS 记录添加/更新功能优化说明

## 📝 问题描述

### 问题 1: 记录名验证错误
**症状**：
```
请输入记录名 (@, www 或其他子域): halo.aaaaa.com
❌ 记录名只能包含字母、数字、-、_、@ 或 *
```

**原因**：
标准 DNS 记录的"记录名"（Name/Label）不能包含点号（.）。
- ✅ 正确的记录名：`www`, `api`, `mail`, `@` 等
- ❌ 错误的记录名：`halo.aaaaa.com`（这是完整域名，应该作为**记录值**而非记录名）

**关键概念**：
- **记录名（Name）**: 子域名，不能有点号
  - 示例：`www`, `api`, `mail`, `@`（表示顶级域）
  
- **记录值（Value）**: 通常是：
  - 对于 A 类型：IP 地址
  - 对于 CNAME/MX/NS：完整域名（可以有点号）

### 问题 2: 交互不友好
**症状**：需要手动输入 A、AAAA、CNAME 等，容易出错

**改进**：用数字菜单（1-8）替代手输，更清晰易用

---

## ✨ 改进内容

### 1. 新增 `select_dns_type()` 菜单函数

**使用方式**：
```bash
请选择记录类型:
  1. A       - IPv4 地址
  2. AAAA    - IPv6 地址
  3. CNAME   - 规范名称
  4. MX      - 邮件交换
  5. TXT     - 文本记录
  6. NS      - 名字服务器
  7. SRV     - 服务记录
  8. CAA     - 证书颁发机构

请输入选择 (1-8): 3
# 返回 "CNAME"
```

**优势**：
- 菜单式选择，避免手输错误如输 "CNAMe" 或 "Cname"
- 清楚的记录类型说明
- 用户只需输入数字 1-8

### 2. 改进记录验证逻辑

**区分记录名和记录值的验证**：

#### 记录名验证 (`is_valid_name()`)
```bash
允许的字符：字母、数字、-、_、@、*
不允许的字符：点号 (.)

示例：
✅ www          - 有效
✅ api-v2       - 有效
✅ _dmarc       - 有效
✅ @            - 有效（表示顶级域）
✅ *.example.com - 无效，应该输入 *
❌ halo.aaaaa.com - 无效，不能有点号
```

#### 记录值验证 - 根据记录类型

**A 记录**：
```bash
要求：有效的 IPv4 地址
验证方式：检查四个八位组是否都在 0-255 范围内
示例：✅ 192.0.2.1, 10.0.0.1
```

**AAAA 记录**：
```bash
要求：有效的 IPv6 地址
验证方式：正则表达式检查
示例：✅ 2001:db8::1
```

**CNAME/MX/NS 记录**：
```bash
要求：完整域名（可以有点号）
验证方式：domain 验证器（完整 RFC 兼容性）
示例：✅ example.com, mail.example.com
```

**TXT 记录**：
```bash
要求：任文本字符串
验证方式：非空检查
示例：✅ "v=spf1 include:example.com ~all"
```

### 3. 改进的交互流程

#### 添加 CNAME 记录的正确流程：

```bash
=== 添加 DNS 记录 ===
请选择记录类型:
  1. A       - IPv4 地址
  2. AAAA    - IPv6 地址
  3. CNAME   - 规范名称
  ...
请输入选择 (1-8): 3                      # 选择 CNAME

请输入记录名 (@, www, api 等子域): blog  # 这是子域名，不能有点号
请输入记录值 (完整域名，如 example.com): blog.wordpress.com
请输入 TTL (默认 3600): 3600              # 或按 Enter 使用默认值

正在添加 CNAME 记录...
✅ 操作成功 (HTTP 201)
```

#### 添加 MX 记录的流程：

```bash
请选择记录类型 ... 选择 4 (MX)
请输入记录名 (@, www, api 等子域): @
请输入记录值 (完整域名，如 example.com): mail.example.com
请输入 TTL (默认 3600): 3600
请输入 MX 优先级 (默认 10): 10

正在添加 MX 记录...
✅ 操作成功 (HTTP 201)
```

---

## 🎯 常见场景对比

### 场景 1: 添加 A 记录

**改进前**：
```
请输入记录类型: A                    # 手输，容易打错
请输入记录值: 192.0.2.1
```

**改进后**：
```
请选择记录类型:
  1. A - IPv4 地址
  ...
请输入选择 (1-8): 1                   # 选数字，不易出错
请输入 IPv4 地址 (如 192.0.2.1): 192.0.2.1
```

### 场景 2: 添加 CNAME 记录

**改进前**：
```
请输入记录名: halo.aaaaa.com         # 错误！不能有点号
❌ 记录名只能包含字母、数字...
```

**改进后**：
```
请输入记录名 (@, www, api 等子域): halo
请输入记录值 (完整域名，如 example.com): aaaaa.com
✅ 正确！
```

---

## 📋 数据验证规则总结

| 字段 | 规则 | 示例 |
|------|------|------|
| **记录名（Name）** | 最多 63 字符，仅 `[a-zA-Z0-9\-\_@\*]`，无点号 | `www`, `@`, `api-v2`, `_dmarc` |
| **A 值** | 4 个 0-255 的十进制数，用点号分隔 | `192.0.2.1` |
| **AAAA 值** | 16 进制，用冒号分隔 | `2001:db8::1` |
| **CNAME/MX/NS 值** | 完整域名 | `mail.example.com`, `cdn.example.com` |
| **TXT 值** | 任何文本串 | `"v=spf1 include:example.com ~all"` |
| **SRV/CAA 值** | 特定格式 | 见官方文档 |
| **TTL** | 1-2147483647 的整数 | `3600`, `86400` |
| **MX 优先级** | 0-65535 的整数 | `10`, `20` |

---

## 🔍 错误诊断

### 错误：❌ 记录名只能包含...

**原因**：输入了完整域名而非子域

**解决方案**：
```bash
❌ 错误: halo.aaaaa.com
✅ 正确: halo              （然后在"值"字段输入 aaaaa.com）

❌ 错误: blog.mydomain.com
✅ 正确: blog              （然后在"值"字段输入目标）
```

### 错误：❌ 无效的域名格式

**原因**：记录值不是有效的域名

**解决方案**：
```bash
❌ 错误: 192.0.2.1         （用于 CNAME）
✅ 正确: example.com       （完整域名）

❌ 错误: mail.            （不完整）
✅ 正确: mail.example.com （完整）
```

### 错误：❌ IPv4 地址不合法

**原因**：IP 地址格式错误或超出范围

**解决方案**：
```bash
❌ 错误: 192.0.2.256  （256 超过 255）
❌ 错误: 192.0.2      （不完整）
✅ 正确: 192.0.2.1    （四个八位组，范围 0-255）
```

---

## 🛠️ 实现细节

### select_dns_type() 函数

```bash
select_dns_type() {
    echo "请选择记录类型:"
    echo "  1. A       - IPv4 地址"
    echo "  2. AAAA    - IPv6 地址"
    ...
    read -p "请输入选择 (1-8): " choice
    
    declare -A type_menu=(
        [1]="A" [2]="AAAA" [3]="CNAME" [4]="MX"
        [5]="TXT" [6]="NS" [7]="SRV" [8]="CAA"
    )
    
    # 返回选定的类型名，或返回错误
    [[ -n "${type_menu[$choice]}" ]] && echo "${type_menu[$choice]}" || return 1
}
```

### 改进的 add_record() 流程

1. 显示类型菜单（1-8）给用户选择
2. 验证记录名（不能有点号）
3. **根据记录类型选择验证方式**：
   - A/AAAA：验证 IP 地址
   - CNAME/MX/NS：验证完整域名
   - TXT/SRV/CAA：检查非空
4. 验证 TTL 是否为数字
5. 如果是 MX，额外询问优先级
6. 构建 JSON 数据并发送 API 请求

---

## 📚 相关文档

- [Bunny DNS API 文档](https://docs.bunny.net/api-reference/core/dns-zone/list-dns-zones)
- [DNS 记录类型详解](https://en.wikipedia.org/wiki/List_of_DNS_record_types)
- [RFC 1035 - DNS](https://www.rfc-editor.org/rfc/rfc1035)

---

## ✅ 测试检查清单

- [x] 语法检查通过
- [x] 菜单式选择可用
- [x] 记录名验证正确
- [x] 记录值验证根据类型
- [x] A 记录 IP 验证
- [x] AAAA 记录 IPv6 验证
- [x] CNAME/MX/NS 域名验证
- [x] MX 优先级处理
- [x] TTL 数字验证

---

**更新时间**: 2026-03-08  
**版本**: 2.1  
**相关函数**: `select_dns_type()`, `add_record()`, `update_record()`, `is_valid_name()`, `is_valid_domain()`
