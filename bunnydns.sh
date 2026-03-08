#!/bin/bash
# Bunny DNS 管理脚本
# 功能：通过 API 管理 Bunny DNS 区域和记录
# API 文档: https://docs.bunny.net/api-reference/core/dns-zone/list-dns-zones

# ==========================
# 检查 curl & jq
# ==========================
if ! command -v curl &>/dev/null; then
    echo "⚠️ curl 未安装，正在安装..."
    sudo apt update && sudo apt install -y curl
    if ! command -v curl &>/dev/null; then
        echo "❌ 安装 curl 失败，请手动安装"
        exit 1
    fi
fi

USE_JQ=0
if command -v jq &>/dev/null; then
    USE_JQ=1
else
    echo "⚠️ 建议安装 jq 用于更好解析 JSON：sudo apt install -y jq"
fi

# ==========================
# 配置（支持环境变量）
# ==========================
BASE_URL="https://api.bunny.net"
API_KEY="${BUNNY_API_KEY:-}"
if [[ -z "$API_KEY" ]]; then
    read -p "请输入 Bunny API Key: " API_KEY
fi
[[ -z "$API_KEY" ]] && echo "❌ 必须提供 API Key（可通过环境变量 BUNNY_API_KEY 提供）" && exit 1

# ==========================
# API 请求函数（返回 body + 状态码）
# ==========================
api_request() {
    local method=$1
    local endpoint=$2
    local data=$3
    local resp

    if [[ -n "$data" ]]; then
        resp=$(curl -s -X "$method" "$BASE_URL$endpoint" \
            -H "AccessKey: $API_KEY" \
            -H "Content-Type: application/json" \
            -d "$data" -w "\n%{http_code}")
    else
        resp=$(curl -s -X "$method" "$BASE_URL$endpoint" \
            -H "AccessKey: $API_KEY" \
            -H "Content-Type: application/json" \
            -w "\n%{http_code}")
    fi

    # 输出 body 和 status（status 为最后一行）
    echo "$resp"
}

check_api_response() {
    local resp="$1"
    local status=$(echo "$resp" | tail -n1 | tr -d '\r')
    local body=$(echo "$resp" | sed '$d' | tr -d '\r')

    # 成功的常见状态码：200, 201, 204
    if [[ "$status" =~ ^(200|201|204)$ ]]; then
        echo "✅ 操作成功 (HTTP $status)"
        return 0
    fi

    # 尝试解析错误信息
    local msg=""
    if [[ $USE_JQ -eq 1 ]]; then
        msg=$(echo "$body" | jq -r '.Message // .message // empty')
    fi
    if [[ -z "$msg" ]]; then
        msg=$(echo "$body" | grep -o '"Message":[^,}]*' | sed 's/"Message"://;s/^\"//;s/\"$//' || true)
    fi
    msg=${msg:-"HTTP $status"}
    echo "❌ 操作失败: $msg"
    return 1
}

get_json_field() {
    # 兼顾 jq 与简单正则解析（仅在无法使用 jq 时）
    local body="$1"
    local field="$2"
    if [[ $USE_JQ -eq 1 ]]; then
        echo "$body" | jq -r --arg f "$field" 'if type=="array" then .[0][$f] // empty else .[$f] // empty end' 2>/dev/null
    else
        echo "$body" | grep -o "\"$field\"[[:space:]]*:[^,}]*" | sed "s/\"$field\"[[:space:]]*:[[:space:]]*//;s/^\"//;s/\"$//"
    fi
}

# ==========================
# IP / Name 校验函数
# ==========================
is_valid_ipv4() {
    local ip=$1
    [[ $ip =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] || return 1
    for octet in $(echo $ip | tr '.' ' '); do
        ((octet>=0 && octet<=255)) || return 1
    done
    return 0
}

is_valid_ipv6() {
    local ip=$1
    [[ $ip =~ ^([0-9a-fA-F]{1,4}:){1,7}[0-9a-fA-F]{1,4}$ ]] && return 0
    return 1
}

is_valid_name() {
    local name=$(echo "$1" | tr -d '\r' | xargs)
    # 记录名不能为空
    [[ -z "$name" ]] && { echo "❌ 记录名不能为空"; return 1; }
    # 记录名只能包含字母、数字、-、_、@ 或 *（不能包含点号 .）
    # 这里不要给字符类中的符号加反斜杠，反而会让模式失效
    [[ "$name" =~ ^[a-zA-Z0-9@*_\-]+$ ]] || { echo "❌ 记录名只能包含字母、数字、-、_、@ 或 *（不能包含点号 .）"; return 1; }
    return 0
}

is_valid_domain() {
    local domain=$(echo "$1" | tr -d '\r' | xargs)
    [[ -z "$domain" ]] && { echo "❌ 值不能为空"; return 1; }
    # 完整域名验证（用于 CNAME、MX、NS 等）
    [[ "$domain" =~ ^[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?)*$ ]] || { echo "❌ 无效的域名格式"; return 1; }
    return 0
}

# ==========================
# DNS 记录类型选择菜单
# ==========================
select_dns_type() {
    # 持续显示菜单直到用户输入有效选项或手动取消
    declare -A type_menu=(
        [1]="A" [2]="AAAA" [3]="CNAME" [4]="MX"
        [5]="TXT" [6]="NS" [7]="SRV" [8]="CAA"
    )

    while true; do
        echo "请选择记录类型:" >&2
        echo "  1. A       - IPv4 地址" >&2
        echo "  2. AAAA    - IPv6 地址" >&2
        echo "  3. CNAME   - 规范名称" >&2
        echo "  4. MX      - 邮件交换" >&2
        echo "  5. TXT     - 文本记录" >&2
        echo "  6. NS      - 名字服务器" >&2
        echo "  7. SRV     - 服务记录" >&2
        echo "  8. CAA     - 证书颁发机构" >&2
        echo >&2
        read -p "请输入选择 (1-8，q 取消): " choice
        choice=$(echo "$choice" | tr -d '\r' | xargs)

        [[ "$choice" == "q" || "$choice" == "Q" ]] && return 1

        if [[ -n "${type_menu[$choice]}" ]]; then
            echo "${type_menu[$choice]}"
            return 0
        fi

        echo "❌ 无效的选择，请输入 1-8" >&2
        # 循环继续，会重新显示菜单
    done
}
# ...existing code...

# ==========================
# 区域管理（使用更可靠的 JSON 解析）
# ==========================
list_zones() {
    local resp=$(api_request GET "/dnszone")
    local status=$(echo "$resp" | tail -n1 | tr -d '\r')
    local body=$(echo "$resp" | sed '$d' | tr -d '\r')

    if [[ ! "$status" =~ ^(200|201)$ ]]; then
        check_api_response "$resp" || return
    fi

    if [[ -z "$body" ]] || [[ "$body" == "null" ]] || [[ "$body" == "{}" ]] || [[ "$body" == '{"Items":[]}' ]]; then
        echo "❌ 没有找到任何 DNS 区域"
        return
    fi

    echo "=== DNS 区域列表 ==="
    echo "$(printf '%-30s %s\n' '域名' 'Zone ID')"
    echo "$(printf '%-30s %s\n' '-----' '-----')"
    
    if [[ $USE_JQ -eq 1 ]]; then
        # 尝试使用 jq 解析
        if echo "$body" | jq -r '.Items[]? | "\(.Domain | ascii_downcase) \(.Id)"' 2>/dev/null | grep -q .; then
            # jq 解析成功，重新执行并输出
            echo "$body" | jq -r '.Items[]? | "\(.Domain | ascii_downcase) \(.Id)"' 2>/dev/null | while read -r domain id; do
                printf '%-30s %s\n' "$domain" "$id"
            done
        else
            # jq 解析失败，回退到正则解析
            echo "⚠️ jq 解析失败，使用兼容模式..."
            local parsed_data=$(echo "$body" | grep -o '"Items":[^}]*' | sed 's/"Items"://' | tr '[' '\n' | tr '{' '\n')
            if [[ -n "$parsed_data" ]]; then
                echo "$parsed_data" | while read -r line; do
                    id=$(echo "$line" | grep -o "\"Id\"[[:space:]]*:[^,}]*" | sed 's/"Id"[[:space:]]*:[[:space:]]*//;s/^\"//;s/\"$//')
                    domain=$(echo "$line" | grep -o "\"Domain\"[[:space:]]*:[^,}]*" | sed 's/"Domain"[[:space:]]*:[[:space:]]*//;s/^\"//;s/\"$//')
                    [[ -n "$id" && -n "$domain" ]] && printf '%-30s %s\n' "${domain,,}" "$id"
                done
            else
                echo "❌ 解析区域列表失败"
            fi
        fi
    else
        # 不使用 jq，直接使用正则解析
        local parsed_data=$(echo "$body" | grep -o '"Items":[^}]*' | sed 's/"Items"://' | tr '[' '\n' | tr '{' '\n')
        if [[ -n "$parsed_data" ]]; then
            echo "$parsed_data" | while read -r line; do
                id=$(echo "$line" | grep -o "\"Id\"[[:space:]]*:[^,}]*" | sed 's/"Id"[[:space:]]*:[[:space:]]*//;s/^\"//;s/\"$//')
                domain=$(echo "$line" | grep -o "\"Domain\"[[:space:]]*:[^,}]*" | sed 's/"Domain"[[:space:]]*:[[:space:]]*//;s/^\"//;s/\"$//')
                [[ -n "$id" && -n "$domain" ]] && printf '%-30s %s\n' "${domain,,}" "$id"
            done
        else
            echo "❌ 解析区域列表失败"
        fi
    fi
}

add_zone() {
    read -p "请输入要添加的域名: " domain
    domain=$(echo "$domain" | tr -d '\r' | xargs)
    
    is_valid_domain "$domain" || return
    
    echo "正在添加域名 $domain..."
    resp=$(api_request POST "/dnszone" "{\"Domain\":\"$domain\"}")
    
    if check_api_response "$resp"; then
        local body=$(echo "$resp" | sed '$d' | tr -d '\r')
        if [[ $USE_JQ -eq 1 ]]; then
            local zone_id=$(echo "$body" | jq -r '.Id // empty' 2>/dev/null)
        else
            local zone_id=$(echo "$body" | grep -o "\"Id\"[[:space:]]*:[^,}]*" | sed 's/"Id"[[:space:]]*:[[:space:]]*//;s/^\"//;s/\"$//' | head -1)
        fi
        [[ -n "$zone_id" ]] && echo "✅ 区域已创建，Zone ID: $zone_id"
    fi
}

delete_zone() {
    read -p "请输入要删除的 Zone ID: " zone_id
    zone_id=$(echo "$zone_id" | tr -d '\r' | xargs)
    [[ -z "$zone_id" ]] && echo "❌ Zone ID 不能为空" && return
    
    echo "⚠️ 警告：删除区域将删除其中的所有 DNS 记录！"
    read -p "确认删除 Zone $zone_id? (输入 'yes' 确认): " confirm
    [[ "$confirm" != "yes" ]] && echo "❌ 操作取消" && return
    
    echo "正在删除 Zone $zone_id..."
    resp=$(api_request DELETE "/dnszone/$zone_id")
    check_api_response "$resp"
}

# ==========================
# 记录管理（list 使用 jq 或回退解析）
# ==========================
add_record() {
    local zone_id=$1
    [[ -z "$zone_id" ]] && echo "❌ Zone ID 缺失" && return
    
    echo
    echo "=== 添加 DNS 记录 ==="
    # 直接列出类型选项供参考（重复一遍以防看不见菜单）
    echo "可选类型："
    echo " 1. A     - IPv4 地址"
    echo " 2. AAAA  - IPv6 地址"
    echo " 3. CNAME - 规范名称"
    echo " 4. MX    - 邮件交换"
    echo " 5. TXT   - 文本记录"
    echo " 6. NS    - 名字服务器"
    echo " 7. SRV   - 服务记录"
    echo " 8. CAA   - 证书颁发机构"
    echo
    # 使用菜单选择记录类型
    type=$(select_dns_type) || return
    
    read -p "请输入记录名 (@, www, api 等子域): " name
    name=$(echo "$name" | tr -d '\r' | xargs)
    is_valid_name "$name" || return
    
    # 根据记录类型，提供相应的提示和验证
    case "$type" in
        A)
            read -p "请输入 IPv4 地址 (如 192.0.2.1): " value
            value=$(echo "$value" | tr -d '\r' | xargs)
            is_valid_ipv4 "$value" || return
            ;;
        AAAA)
            read -p "请输入 IPv6 地址: " value
            value=$(echo "$value" | tr -d '\r' | xargs)
            is_valid_ipv6 "$value" || return
            ;;
        CNAME|MX|NS)
            read -p "请输入记录值 (完整域名，如 example.com): " value
            value=$(echo "$value" | tr -d '\r' | xargs)
            is_valid_domain "$value" || return
            ;;
        TXT)
            read -p "请输入 TXT 记录值: " value
            value=$(echo "$value" | tr -d '\r' | xargs)
            [[ -z "$value" ]] && echo "❌ 记录值不能为空" && return
            ;;
        SRV|CAA)
            read -p "请输入记录值: " value
            value=$(echo "$value" | tr -d '\r' | xargs)
            [[ -z "$value" ]] && echo "❌ 记录值不能为空" && return
            ;;
        *)
            echo "❌ 不支持的记录类型"
            return 1
            ;;
    esac
    
    read -p "请输入 TTL (默认 3600): " ttl
    ttl=${ttl:-3600}
    [[ ! "$ttl" =~ ^[0-9]+$ ]] && echo "❌ TTL 必须是数字" && return

    # 记录类型映射
    declare -A type_map=([A]=0 [AAAA]=1 [CNAME]=2 [MX]=4 [TXT]=3 [NS]=12 [SRV]=8 [CAA]=9)
    type_num=${type_map[$type]}

    # MX 记录需要优先级
    if [[ "$type" == "MX" ]]; then
        read -p "请输入 MX 优先级 (默认 10): " priority
        priority=${priority:-10}
        [[ ! "$priority" =~ ^[0-9]+$ ]] && echo "❌ 优先级必须是数字" && return
        data="{\"Type\":$type_num,\"Name\":\"$name\",\"Value\":\"$value\",\"Ttl\":$ttl,\"Priority\":$priority}"
    else
        data="{\"Type\":$type_num,\"Name\":\"$name\",\"Value\":\"$value\",\"Ttl\":$ttl}"
    fi

    echo "正在添加 $type 记录..."
    resp=$(api_request PUT "/dnszone/$zone_id/records" "$data")
    check_api_response "$resp"
}

update_record() {
    local zone_id=$1
    [[ -z "$zone_id" ]] && echo "❌ Zone ID 缺失" && return
    
    echo
    echo "=== 更新 DNS 记录 ==="
    # 提示可选类型方便参考
    echo "可选类型："
    echo " 1. A     - IPv4 地址"
    echo " 2. AAAA  - IPv6 地址"
    echo " 3. CNAME - 规范名称"
    echo " 4. MX    - 邮件交换"
    echo " 5. TXT   - 文本记录"
    echo " 6. NS    - 名字服务器"
    echo " 7. SRV   - 服务记录"
    echo " 8. CAA   - 证书颁发机构"
    echo
    read -p "请输入记录 ID: " record_id
    record_id=$(echo "$record_id" | tr -d '\r' | xargs)
    [[ -z "$record_id" ]] && echo "❌ 记录 ID 不能为空" && return
    
    # 使用菜单选择记录类型
    type=$(select_dns_type) || return
    
    read -p "请输入记录名 (@, www, api 等子域): " name
    name=$(echo "$name" | tr -d '\r' | xargs)
    is_valid_name "$name" || return
    
    # 根据记录类型，提供相应的提示和验证
    case "$type" in
        A)
            read -p "请输入 IPv4 地址 (如 192.0.2.1): " value
            value=$(echo "$value" | tr -d '\r' | xargs)
            is_valid_ipv4 "$value" || return
            ;;
        AAAA)
            read -p "请输入 IPv6 地址: " value
            value=$(echo "$value" | tr -d '\r' | xargs)
            is_valid_ipv6 "$value" || return
            ;;
        CNAME|MX|NS)
            read -p "请输入记录值 (完整域名，如 example.com): " value
            value=$(echo "$value" | tr -d '\r' | xargs)
            is_valid_domain "$value" || return
            ;;
        TXT)
            read -p "请输入 TXT 记录值: " value
            value=$(echo "$value" | tr -d '\r' | xargs)
            [[ -z "$value" ]] && echo "❌ 记录值不能为空" && return
            ;;
        SRV|CAA)
            read -p "请输入记录值: " value
            value=$(echo "$value" | tr -d '\r' | xargs)
            [[ -z "$value" ]] && echo "❌ 记录值不能为空" && return
            ;;
        *)
            echo "❌ 不支持的记录类型"
            return 1
            ;;
    esac
    
    read -p "请输入 TTL (默认 3600): " ttl
    ttl=${ttl:-3600}
    [[ ! "$ttl" =~ ^[0-9]+$ ]] && echo "❌ TTL 必须是数字" && return

    # 记录类型映射
    declare -A type_map=([A]=0 [AAAA]=1 [CNAME]=2 [MX]=4 [TXT]=3 [NS]=12 [SRV]=8 [CAA]=9)
    type_num=${type_map[$type]}

    # MX 记录需要优先级
    if [[ "$type" == "MX" ]]; then
        read -p "请输入 MX 优先级 (默认 10): " priority
        priority=${priority:-10}
        [[ ! "$priority" =~ ^[0-9]+$ ]] && echo "❌ 优先级必须是数字" && return
        data="{\"Type\":$type_num,\"Name\":\"$name\",\"Value\":\"$value\",\"Ttl\":$ttl,\"Priority\":$priority}"
    else
        data="{\"Type\":$type_num,\"Name\":\"$name\",\"Value\":\"$value\",\"Ttl\":$ttl}"
    fi

    echo "正在更新 $type 记录..."
    resp=$(api_request POST "/dnszone/$zone_id/records/$record_id" "$data")
    check_api_response "$resp"
}

delete_record() {
    local zone_id=$1
    [[ -z "$zone_id" ]] && echo "❌ Zone ID 缺失" && return
    
    read -p "请输入要删除的记录 ID: " record_id
    record_id=$(echo "$record_id" | tr -d '\r' | xargs)
    [[ -z "$record_id" ]] && echo "❌ 记录 ID 不能为空" && return
    
    read -p "确认删除记录 ID $record_id? (输入 'yes' 确认): " confirm
    [[ "$confirm" != "yes" ]] && echo "❌ 操作取消" && return
    
    echo "正在删除记录..."
    resp=$(api_request DELETE "/dnszone/$zone_id/records/$record_id")
    check_api_response "$resp"
}

list_records() {
    local zone_id=$1
    if [[ -z "$zone_id" ]]; then
        echo "❌ Zone ID 不能为空"
        return 1
    fi
    
    echo "正在获取 Zone $zone_id 的记录..."
    local resp=$(api_request GET "/dnszone/$zone_id")
    local status=$(echo "$resp" | tail -n1 | tr -d '\r')
    local body=$(echo "$resp" | sed '$d' | tr -d '\r')

    if [[ ! "$status" =~ ^(200|201)$ ]]; then
        check_api_response "$resp"
        return 1
    fi

    if [[ -z "$body" ]] || [[ "$body" == "null" ]] || [[ "$body" == "{}" ]]; then
        echo "❌ 未找到 Zone $zone_id 的记录或 Zone 不存在"
        return 1
    fi

    echo ""
    echo "=== Zone $zone_id 的 DNS 记录 ==="
    echo "$(printf '%-8s %-5s %-20s %s\n' 'ID' 'Type' 'Name' 'Value | Data')"
    echo "$(printf '%-8s %-5s %-20s %s\n' '----' '----' '----' '----')"
    
    # 使用局部变量避免管道子进程导致计数失效
    if [[ $USE_JQ -eq 1 ]]; then
        local records
        records=$(echo "$body" | jq -r '.Records[]? // .[]? | select(type=="object") | "\(.Id) \(.Type) \(.Name // "@") \(.Value // .Data // "")"' 2>/dev/null)
        if [[ -z "$records" ]]; then
            echo "❌ 该 Zone 没有 DNS 记录"
        else
            echo "$records" | while read -r id type name value; do
                printf '%-8s %-5s %-20s %s\n' "$id" "$type" "$name" "$value"
            done
        fi
    else
        local records
        records=$(echo "$body" | tr '{' '\n' | while read -r line; do
            rid=$(echo "$line" | grep -o "\"Id\"[[:space:]]*:[^,}]*" | sed 's/"Id"[[:space:]]*:[[:space:]]*//;s/^\"//;s/\"$//')
            type=$(echo "$line" | grep -o "\"Type\"[[:space:]]*:[^,}]*" | sed 's/"Type"[[:space:]]*:[[:space:]]*//;s/^\"//;s/\"$//')
            name=$(echo "$line" | grep -o "\"Name\"[[:space:]]*:[^,}]*" | sed 's/"Name"[[:space:]]*:[[:space:]]*//;s/^\"//;s/\"$//')
            value=$(echo "$line" | grep -o "\"Value\"[[:space:]]*:[^,}]*" | sed 's/"Value"[[:space:]]*:[[:space:]]*//;s/^\"//;s/\"$//')
            if [[ -n "$rid" && -n "$type" ]]; then
                printf '%-8s %-5s %-20s %s\n' "$rid" "$type" "${name:-@}" "$value"
            fi
        done)
        if [[ -z "$records" ]]; then
            echo "❌ 该 Zone 没有 DNS 记录"
        else
            echo "$records"
        fi
    fi
}

# ==========================
# Zone 管理菜单
# ==========================
zone_menu() {
    read -p "请输入要管理的 Zone ID: " zone_id
    zone_id=$(echo "$zone_id" | tr -d '\r' | xargs)
    
    if [[ -z "$zone_id" ]]; then
        echo "❌ Zone ID 不能为空"
        return
    fi
    
    while true; do
        echo
        echo "=== Zone $zone_id 管理菜单 ==="
        echo "1. 查看记录"
        echo "2. 添加记录"
        echo "3. 更新记录"
        echo "4. 删除记录"
        echo "0. 返回主菜单"
        read -p "请选择操作: " choice
        choice=$(echo "$choice" | tr -d '\r' | xargs)
        
        case "$choice" in
            1) list_records "$zone_id" ;;
            2) add_record "$zone_id" ;;
            3) update_record "$zone_id" ;;
            4) delete_record "$zone_id" ;;
            0) break ;;
            *) echo "❌ 无效输入" ;;
        esac
    done
}

# ==========================
# 帮助信息
# ==========================
show_help() {
    cat << 'EOF'
=== Bunny DNS 管理脚本帮助 ===

本脚本用于管理 Bunny DNS 服务的区域和记录。

功能：
  1. 查看 DNS 区域并管理记录 - 列出所有区域，选择区域后管理其记录
  2. 添加 DNS 区域         - 为新域名创建 DNS 区域
  3. 删除 DNS 区域         - 删除指定的 DNS 区域及其所有记录
  4. 单独查看记录          - 直接查看特定 Zone ID 的所有记录
  5. 单独添加记录          - 直接向特定 Zone ID 添加记录
  6. 单独更新记录          - 直接修改特定 Zone ID 中的记录
  7. 单独删除记录          - 直接删除特定 Zone ID 中的记录
  h. 显示此帮助            - 显示帮助信息
  0. 退出                 - 退出程序

支持的 DNS 记录类型：
  A       - IPv4 地址
  AAAA    - IPv6 地址
  CNAME   - 规范名记录
  MX      - 邮件交换记录
  TXT     - 文本记录
  NS      - 名字服务器记录
  SRV     - 服务记录
  CAA     - 证书颁发机构授权记录

关键信息：
  - API Key 可通过 BUNNY_API_KEY 环境变量设置
  - 推荐安装 jq 以获得更好的 JSON 解析体验
  - 所有 Zone ID 和记录 ID 都可从列表输出中获取

API 文档：
  https://docs.bunny.net/api-reference/core/dns-zone/list-dns-zones

EOF
}

# ==========================
# 主菜单
# ==========================
while true; do
    echo
    echo "╔════════════════════════════════════╗"
    echo "║    Bunny DNS 管理系统              ║"
    echo "╚════════════════════════════════════╝"
    echo
    echo "1. 查看 DNS 区域并管理记录"
    echo "2. 添加 DNS 区域"
    echo "3. 删除 DNS 区域"
    echo "4. 单独查看记录"
    echo "5. 单独添加记录"
    echo "6. 单独更新记录"
    echo "7. 单独删除记录"
    echo "h. 帮助信息"
    echo "0. 退出"
    echo
    read -p "请选择操作 [0-7,h]: " choice
    choice=$(echo "$choice" | tr -d '\r' | xargs)

    case "$choice" in
        1) list_zones; zone_menu ;;
        2) add_zone ;;
        3) delete_zone ;;
        4) 
            read -p "请输入 Zone ID: " zid
            zid=$(echo "$zid" | tr -d '\r' | xargs)
            if [[ -z "$zid" ]]; then
                echo "❌ Zone ID 不能为空"
            else
                list_records "$zid"
            fi
            ;;
        5) 
            read -p "请输入 Zone ID: " zid
            zid=$(echo "$zid" | tr -d '\r' | xargs)
            if [[ -z "$zid" ]]; then
                echo "❌ Zone ID 不能为空"
            else
                add_record "$zid"
            fi
            ;;
        6) 
            read -p "请输入 Zone ID: " zid
            zid=$(echo "$zid" | tr -d '\r' | xargs)
            if [[ -z "$zid" ]]; then
                echo "❌ Zone ID 不能为空"
            else
                update_record "$zid"
            fi
            ;;
        7) 
            read -p "请输入 Zone ID: " zid
            zid=$(echo "$zid" | tr -d '\r' | xargs)
            if [[ -z "$zid" ]]; then
                echo "❌ Zone ID 不能为空"
            else
                delete_record "$zid"
            fi
            ;;
        h) show_help ;;
        0) echo "👋 感谢使用！再见"; exit 0 ;;
        *) echo "❌ 无效输入，请重新选择" ;;
    esac
done