#!/bin/bash
# ══════════════════════════════════════════════════
# ECH-Workerd - Build & Publish Script
# 构建与发布脚本
# ══════════════════════════════════════════════════

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 配置
APP_NAME="ECH-Workerd"
APP_VERSION=$(grep '^version:' lzc-manifest.yml | awk '{print $2}')
PACKAGE_NAME="cloud.lazycat.app.ech-workerd"
OUTPUT_FILE="ech-workerd-${APP_VERSION}.lpk"
ORIGINAL_IMAGE="ghcr.io/yourorg/ech-workerd:latest"

# 打印函数
print_header() {
    echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}  $1${NC}"
    echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
}

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检查必要文件
check_files() {
    print_header "检查必要文件"

    local missing_files=()

    if [ ! -f "lzc-manifest.yml" ]; then
        missing_files+=("lzc-manifest.yml")
    fi

    if [ ! -f "lzc-deploy-params.yml" ]; then
        missing_files+=("lzc-deploy-params.yml")
    fi

    if [ ! -f "lzc-build.yml" ]; then
        missing_files+=("lzc-build.yml")
    fi

    if [ ! -f "icon.png" ]; then
        print_warning "缺少 icon.png，请确保提供 512x512 PNG 图标"
        missing_files+=("icon.png")
    fi

    if [ ${#missing_files[@]} -gt 0 ]; then
        print_error "缺少以下文件："
        for file in "${missing_files[@]}"; do
            echo "  - $file"
        done
        return 1
    fi

    print_success "所有必要文件已就绪"
    return 0
}

# 验证配置
validate_config() {
    print_header "验证配置"

    # 检查 YAML 语法
    if command -v yq &> /dev/null; then
        if yq eval '.' lzc-manifest.yml > /dev/null 2>&1; then
            print_success "lzc-manifest.yml 语法正确"
        else
            print_error "lzc-manifest.yml 语法错误"
            return 1
        fi

        if yq eval '.' lzc-deploy-params.yml > /dev/null 2>&1; then
            print_success "lzc-deploy-params.yml 语法正确"
        else
            print_error "lzc-deploy-params.yml 语法错误"
            return 1
        fi
    else
        print_warning "未安装 yq，跳过 YAML 语法检查"
    fi

    # 检查版本号
    if [[ $APP_VERSION =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        print_success "版本号格式正确: $APP_VERSION"
    else
        print_error "版本号格式错误: $APP_VERSION (应为 x.x.x)"
        return 1
    fi

    return 0
}

# 显示应用信息
show_info() {
    print_header "应用信息"

    echo -e "${CYAN}应用名称:${NC} $APP_NAME"
    echo -e "${CYAN}版本号:${NC} $APP_VERSION"
    echo -e "${CYAN}包名:${NC} $PACKAGE_NAME"
    echo -e "${CYAN}输出文件:${NC} $OUTPUT_FILE"
    echo -e "${CYAN}原始镜像:${NC} $ORIGINAL_IMAGE"
    echo ""

    echo -e "${CYAN}安装向导参数:${NC}"
    grep -E '^\s+- id:' lzc-deploy-params.yml | sed 's/^\s*- id: /  - /'
    echo ""
}

# 构建应用
build_app() {
    print_header "构建应用"

    if ! check_files; then
        return 1
    fi

    print_info "开始构建 $OUTPUT_FILE..."

    if lzc-cli project build -o "$OUTPUT_FILE"; then
        print_success "构建成功: $OUTPUT_FILE"
        ls -lh "$OUTPUT_FILE"
        return 0
    else
        print_error "构建失败"
        return 1
    fi
}

# 复制镜像到懒猫仓库
copy_image() {
    print_header "复制镜像到懒猫仓库"

    # 检查登录状态
    if ! lzc-cli appstore my-images &> /dev/null 2>&1; then
        print_warning "未登录懒猫应用商店"
        print_info "请先执行: lzc-cli appstore login"
        return 1
    fi

    print_info "正在复制镜像: $ORIGINAL_IMAGE"
    print_info "这可能需要几分钟..."

    local result
    result=$(lzc-cli appstore copy-image "$ORIGINAL_IMAGE" 2>&1)

    if echo "$result" | grep -q "uploaded:"; then
        local new_image
        new_image=$(echo "$result" | grep "^uploaded:" | awk '{print $2}')

        print_success "镜像复制成功"
        echo -e "${CYAN}新镜像地址:${NC} $new_image"

        # 更新 manifest
        print_info "更新 lzc-manifest.yml..."
        update_manifest_image "lzc-manifest.yml" "$new_image"

        print_success "manifest 更新完成"
        return 0
    else
        print_error "镜像复制失败"
        echo "$result"
        return 1
    fi
}

# 更新 manifest 中的镜像
update_manifest_image() {
    local manifest_file=$1
    local new_image=$2

    if [ -f "$manifest_file" ]; then
        # 备份原文件
        cp "$manifest_file" "${manifest_file}.bak"

        # 使用 sed 替换镜像地址，并保留原镜像作为注释
        # macOS 兼容的 sed 命令
        sed -i '' "s|image: ghcr.io/yourorg/ech-workerd:latest|    # ghcr.io/yourorg/ech-workerd:latest\n    image: $new_image|" "$manifest_file"

        print_info "已更新 $manifest_file"
    fi
}

# 发布到应用商店
publish_app() {
    print_header "发布到应用商店"

    # 检查登录状态
    if ! lzc-cli appstore my-images &> /dev/null 2>&1; then
        print_warning "未登录懒猫应用商店"
        print_info "请先执行: lzc-cli appstore login"
        return 1
    fi

    if [ ! -f "$OUTPUT_FILE" ]; then
        print_error "未找到构建文件: $OUTPUT_FILE"
        print_info "请先执行构建"
        return 1
    fi

    print_info "正在发布 $OUTPUT_FILE..."

    if lzc-cli appstore publish "$OUTPUT_FILE"; then
        print_success "发布成功！"
        print_info "请等待审核（通常 1-3 天）"
        return 0
    else
        print_error "发布失败"
        return 1
    fi
}

# 一键发布流程
one_click_publish() {
    print_header "一键发布流程"

    echo -e "${YELLOW}此流程将执行以下步骤:${NC}"
    echo "  1. 初始构建（原始镜像）"
    echo "  2. 复制镜像到懒猫仓库"
    echo "  3. 更新 manifest 并重新构建"
    echo "  4. 发布到应用商店"
    echo ""

    read -p "是否继续? (y/n): " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        print_info "已取消"
        return 1
    fi

    # 阶段 1: 初始构建
    print_header "阶段 1/4: 初始构建"
    if ! build_app; then
        return 1
    fi

    # 阶段 2: 复制镜像
    print_header "阶段 2/4: 复制镜像"
    if ! copy_image; then
        return 1
    fi

    # 阶段 3: 重新构建
    print_header "阶段 3/4: 重新构建（新镜像）"
    if ! build_app; then
        return 1
    fi

    # 阶段 4: 发布
    print_header "阶段 4/4: 发布"
    if ! publish_app; then
        return 1
    fi

    print_header "完成"
    print_success "一键发布流程完成！"
}

# 主菜单
show_menu() {
    echo ""
    print_header "$APP_NAME v$APP_VERSION - 构建发布工具"
    echo ""
    echo "  1. 📦 构建应用 (Build)"
    echo "  2. 🔧 复制镜像到懒猫仓库 (Copy Image)"
    echo "  3. 📤 发布到应用商店 (Publish)"
    echo "  4. 🚀 一键构建+镜像复制+发布 (One-Click)"
    echo "  5. 📋 查看应用信息 (Info)"
    echo "  6. ✅ 验证配置 (Validate)"
    echo "  7. ❌ 退出 (Exit)"
    echo ""
}

# 主循环
main() {
    while true; do
        show_menu
        read -p "请选择操作 [1-7]: " choice

        case $choice in
            1)
                build_app
                ;;
            2)
                copy_image
                ;;
            3)
                publish_app
                ;;
            4)
                one_click_publish
                ;;
            5)
                show_info
                ;;
            6)
                validate_config
                ;;
            7)
                print_info "再见！"
                exit 0
                ;;
            *)
                print_error "无效选择，请重试"
                ;;
        esac

        echo ""
        read -p "按回车键继续..."
    done
}

# 运行主程序
main