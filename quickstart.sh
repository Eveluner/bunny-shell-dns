#!/bin/bash
# 快速开始指南 - Bunny DNS 管理脚本

echo "╔═══════════════════════════════════════════════════╗"
echo "║   Bunny DNS 管理脚本 - 快速开始检查              ║"
echo "╚═══════════════════════════════════════════════════╝"
echo ""

# 1. 检查系统要求
echo "📋 步骤 1: 检查系统要求"
echo "━━━━━━━━━━━━━━━━━━━━━━━"

if command -v bash &>/dev/null; then
    bash_version=$(bash --version | head -1)
    echo "✅ Bash 已安装: $bash_version"
else
    echo "❌ Bash 未安装"
    exit 1
fi

if command -v curl &>/dev/null; then
    echo "✅ curl 已安装"
else
    echo "❌ curl 未安装，尝试安装..."
    sudo apt update && sudo apt install -y curl
fi

if command -v jq &>/dev/null; then
    echo "✅ jq 已安装（推荐）"
else
    echo "⚠️ jq 未安装（可选但推荐）"
    read -p "是否要安装 jq? (y/n): " install_jq
    if [[ "$install_jq" == "y" ]]; then
        sudo apt install -y jq
    fi
fi

echo ""
echo "📋 步骤 2: 配置 API Key"
echo "━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "您需要从 Bunny.net 控制面板获取 API Key："
echo "  1. 访问 https://panel.bunny.net"
echo "  2. 登录您的账户"
echo "  3. 进入 Account -> Settings"
echo "  4. 找到 API Key 部分"
echo "  5. 复制您的 API Key"
echo ""

# 检查是否已设置 API Key
if [[ -n "$BUNNY_API_KEY" ]]; then
    echo "✅ 已检测到环境变量 BUNNY_API_KEY"
else
    echo "⚠️ 未设置环境变量 BUNNY_API_KEY"
    echo ""
    echo "设置方法："
    echo "  方法 1 (临时): export BUNNY_API_KEY='your-key-here'"
    echo "  方法 2 (永久): 添加到 ~/.bashrc 或 ~/.zshrc"
    echo ""
    read -p "是否现在输入 API Key? (y/n): " set_key
    if [[ "$set_key" == "y" ]]; then
        read -p "请输入 API Key: " api_key
        export BUNNY_API_KEY="$api_key"
        echo "✅ 临时设置完成（仅本会话有效）"
    fi
fi

echo ""
echo "📋 步骤 3: 验证脚本"
echo "━━━━━━━━━━━━━━━━━━━━━━━"

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
script_file="$script_dir/bunnydns.sh"

if [[ -f "$script_file" ]]; then
    echo "✅ 找到脚本: $script_file"
    
    # 检查语法
    if bash -n "$script_file" 2>/dev/null; then
        echo "✅ Bash 语法检查通过"
    else
        echo "❌ Bash 语法检查失败"
        exit 1
    fi
    
    # 检查执行权限
    if [[ -x "$script_file" ]]; then
        echo "✅ 脚本有执行权限"
    else
        echo "⚠️ 脚本没有执行权限，正在修复..."
        chmod +x "$script_file"
        echo "✅ 已设置执行权限"
    fi
else
    echo "❌ 找不到脚本文件: $script_file"
    exit 1
fi

echo ""
echo "╔═══════════════════════════════════════════════════╗"
echo "║          快速开始检查完成！✨                     ║"
echo "╚═══════════════════════════════════════════════════╝"
echo ""
echo "现在您可以运行脚本了："
echo ""
echo "  # 方法 1: 直接运行"
echo "  ./bunnydns.sh"
echo ""
echo "  # 方法 2: 使用环境变量"
echo "  BUNNY_API_KEY='your-key' ./bunnydns.sh"
echo ""
echo "  # 方法 3: 导出环境变量后运行"
echo "  export BUNNY_API_KEY='your-key'"
echo "  ./bunnydns.sh"
echo ""
echo "需要帮助? 查看:"
echo "  - README.md       - 完整文档"
echo "  - IMPROVEMENTS.md - 改进记录"
echo ""
