# 这个脚本将在 Android 系统启动完毕后以服务模式运行
#!/bin/sh
# boot-completed.sh
#
# 这个脚本会在 Android 系统完全启动并发送 ACTION_BOOT_COMPLETED 广播后执行。
# 它在 late_start 服务模式下运行，这意味着它与启动过程的其余部分并行操作。
#
# 用法:
# - 将此脚本放置在模块的目录中，以便在系统启动完成后自动执行。
# - 通过运行 `chmod +x boot-completed.sh` 确保脚本是可执行的。
#
# 环境变量:
# - MODDIR: 模块的基本目录路径。使用此变量引用模块的文件。
# - KSU: 表示脚本在 KernelSU 环境中运行。此值设置为 `true`。
#
# 示例:
# - 使用此脚本执行系统完全启动后需要执行的任务，例如启动服务或执行清理任务。
#
# 注意:
# - 避免使用可能阻塞或显著延迟启动过程的命令。
# - 确保此脚本启动的任何后台任务都得到妥善管理，以避免资源泄漏。
#
# 有关更多信息，请参阅 KernelSU 文档中的启动脚本部分。


# 注意这个sh文件是ksu新增的,因此不支持magisk(apu的系统模块功能借鉴的ksu)

MODDIR=${0%/*}

if [ -f "$MODDIR/magisk" ]; then
    # 等待开机完毕
    while [ "$(getprop sys.boot_completed)" != "1" ]; do
        sleep 1
    done
else
    # 其他的root管理器使用boot-complete.sh
    if [ -f "$MODDIR/service.sh" ]; then
        mv "$MODDIR/service.sh" "$MODDIR/boot-completed.sh"
    fi
fi

# 函数：检查并下载 sub_store 最新版 JS 文件
check_and_download_sub_store() {
    local github_repo="sub-store-org/Sub-Store"
    local official_url="https://api.github.com/repos/${github_repo}/releases/latest"
    local proxy_url="https://mirror.ghproxy.com/https://github.com/${github_repo}/releases/latest/download/sub-store.bundle.js"
    local version_file="$MODDIR/version"
    local js_file="$MODDIR/sub-store.bundle.js"
    local latest_version
    local download_url

    # 获取最新版本号和下载链接
    if ! latest_version=$(curl -sL "$official_url" | grep -o '"tag_name": ".*"' | cut -d'"' -f4); then
        echo "无法从 GitHub 获取最新版本号"
        latest_version=$(curl -sL "https://mirror.ghproxy.com/${official_url}" | grep -o '"tag_name": ".*"' | cut -d'"' -f4)
    fi

    # 如果仍然无法获取版本号，退出函数
    if [ -z "$latest_version" ]; then
        echo "无法获取最新版本号"
        return 1
    fi

    # 读取本地版本号
    local current_version=""
    if [ -f "$version_file" ]; then
        current_version=$(cat "$version_file")
    fi

    # 比较版本号，如果不同则下载最新版本
    if [ "$latest_version" != "$current_version" ] || [ ! -f "$js_file" ]; then
        echo "检测到新版本或文件不存在：$latest_version，开始下载..."

        # 尝试从 GitHub 直接下载
        if ! curl -L -o "$js_file" "https://github.com/${github_repo}/releases/download/${latest_version}/sub-store.bundle.js"; then
            echo "从 GitHub 下载失败，尝试从代理链接下载..."
            if ! curl -L -o "$js_file" "$proxy_url"; then
                echo "从代理链接下载失败" > readme.log
                return 1
            fi
        fi

        # 更新版本文件
        echo "$latest_version" > "$version_file"
        echo "下载完成，版本已更新到：$latest_version"
    else
        echo "当前已是最新版本：$current_version"
    fi
}

# 函数：检查端口是否被占用
check_port() {
    local port=$1
    if nc -z 127.0.0.1 "$port" >/dev/null 2>&1; then
        return 1
    fi
    return 0
}

# 函数：检查服务是否运行
check_service() {
    local port=$1
    if curl -s "http://127.0.0.1:${port}/" >/dev/null 2>&1; then
        return 0
    fi
    return 1
}

# 函数：操作 module.prop 文件
handle_module_prop() {
    local action=$1    # 操作类型：read 或 write
    local key=$2       # 键名
    local value=$3     # 新值（写入时使用）
    local prop_file="$MODDIR/module.prop"

    # 检查文件是否存在
    if [ ! -f "$prop_file" ]; then
        echo "错误: module.prop 文件不存在"
        return 1
    fi

    case "$action" in
        "read")
            # 读取值
            sed -n "s/^${key}=//p" "$prop_file"
            ;;
        "write")
            # 检查是否提供了值
            if [ -z "$value" ]; then
                echo "错误: 写入操作需要提供值"
                return 1
            fi
            # 写入值
            sed -i "s/^${key}=.*/${key}=${value}/" "$prop_file"
            ;;
        *)
            echo "错误: 无效的操作类型，请使用 read 或 write"
            return 1
            ;;
    esac
}

# 使用示例：
# 读取版本
# version=$(handle_module_prop "read" "version")
# 
# 修改版本
# handle_module_prop "write" "version" "1.0.0"
# main

# 调用函数
check_and_download_sub_store

# 检查 node 是否安装
if ! command -v node >/dev/null 2>&1; then
    echo "未找到 node 命令，请安装 Node.js" > "$MODDIR/readme.log"
    exit 1
fi



# 设置 Sub-Store 服务配置
# 好像没用 默认3000端口
HOST="127.0.0.1"
PORT="3000"
MAX_PORT="3010"  # 最大尝试端口号

# 检查文件是否存在并运行
if [ -f "$MODDIR/sub-store.bundle.js" ]; then
    current_port=$PORT
    while [ "$current_port" -le "$MAX_PORT" ]; do
        if check_port "$current_port"; then
            PORT=$current_port
            break
        fi
        current_port=$((current_port + 1))
    done

    if [ "$current_port" -gt "$MAX_PORT" ]; then
        echo "未找到可用端口 (3000-3010)" > "$MODDIR/readme.log"
        exit 1
    fi
    # 这个...
    SUB_STORE_HOST="$HOST" SUB_STORE_PORT="$PORT"
    # 后台运行服务
    node "$MODDIR/sub-store.bundle.js" >> "$MODDIR/sub-store.log" 2>&1 &

    # 记录进程 ID
    echo $! > "$MODDIR/sub-store.pid"
    
    # 等待服务启动
    sleep 2
    
    # 检查服务是否成功启动
    if check_service "$PORT"; then
        echo "Sub-Store 服务已启动于 http://${HOST}:${PORT}" > "$MODDIR/readme.log"
        handle_module_prop "write" "desciption" "Sub-Store 服务已启动于 http://${HOST}:${PORT}"
    else
        echo "Sub-Store 服务启动失败" > "$MODDIR/readme.log"
        handle_module_prop "write" "desciption" "Sub-Store 服务启动失败"
        exit 1
    fi
else
    echo "sub-store.bundle.js 文件不存在" > "$MODDIR/readme.log"
fi

