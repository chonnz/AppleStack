import AppKit
import SwiftUI

private enum SettingsSection: String, CaseIterable, Identifiable {
    case general
    case cli
    case terminal
    case system
    case about

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .general: "gearshape.fill"
        case .cli: "apple.terminal.fill"
        case .terminal: "terminal.fill"
        case .system: "server.rack"
        case .about: "info.circle.fill"
        }
    }

    func title(language: AppLanguage) -> String {
        switch self {
        case .general: language.text(.general)
        case .cli: "CLI"
        case .terminal: language.text(.terminal)
        case .system: language.text(.system)
        case .about: language.text(.about)
        }
    }
}

enum AppLanguage: String, CaseIterable, Identifiable {
    case english = "en"
    case simplifiedChinese = "zh-Hans"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .english: "English"
        case .simplifiedChinese: "简体中文"
        }
    }

    var localeIdentifier: String {
        switch self {
        case .english: "en"
        case .simplifiedChinese: "zh-Hans"
        }
    }

    func text(_ key: SettingsTextKey) -> String {
        switch (self, key) {
        case (.english, .general): "General"
        case (.english, .terminal): "Terminal"
        case (.english, .system): "System"
        case (.english, .about): "About"
        case (.english, .language): "Language"
        case (.english, .interfaceLanguage): "Interface language"
        case (.english, .interfaceLanguageHint): "Used by AppleStack settings and supported views."
        case (.english, .containers): "Containers"
        case (.english, .showAllContainers): "Show all containers by default"
        case (.english, .showAllContainersHint): "New container lists include stopped containers unless you switch it off."
        case (.english, .refresh): "Refresh"
        case (.english, .listRefreshInterval): "List refresh interval"
        case (.english, .listRefreshIntervalHint): "Used by container list auto-refresh."
        case (.english, .appleContainersCLI): "Apple Containers CLI"
        case (.english, .executableFound): "Executable file found."
        case (.english, .pathNotExecutable): "Path is not executable. AppleStack will fall back to auto-discovery on relaunch."
        case (.english, .containerPath): "container path"
        case (.english, .browse): "Browse..."
        case (.english, .cliRelaunchHint): "Changing the CLI path applies after relaunch because the backend is created when AppleStack starts."
        case (.english, .fontSize): "Font size"
        case (.english, .terminalFontHint): "Used by container and machine terminal tabs."
        case (.english, .runtime): "Runtime"
        case (.english, .running): "Running"
        case (.english, .stopped): "Stopped"
        case (.english, .systemUnavailable): "System status unavailable"
        case (.english, .commands): "Commands"
        case (.english, .version): "Version"
        case (.english, .diskUsage): "Disk Usage"
        case (.english, .logs): "Logs"
        case (.english, .properties): "Properties"
        case (.english, .dns): "DNS"
        case (.english, .domain): "Domain"
        case (.english, .localhostIP): "Localhost IP (optional)"
        case (.english, .create): "Create"
        case (.english, .delete): "Delete"
        case (.english, .kernel): "Kernel"
        case (.english, .kernelPath): "Kernel path"
        case (.english, .setKernel): "Set Kernel"
        case (.english, .build): "Build"

        case (.simplifiedChinese, .general): "通用"
        case (.simplifiedChinese, .terminal): "终端"
        case (.simplifiedChinese, .system): "系统"
        case (.simplifiedChinese, .about): "关于"
        case (.simplifiedChinese, .language): "语言"
        case (.simplifiedChinese, .interfaceLanguage): "界面语言"
        case (.simplifiedChinese, .interfaceLanguageHint): "用于 AppleStack 设置页和已适配视图。"
        case (.simplifiedChinese, .containers): "容器"
        case (.simplifiedChinese, .showAllContainers): "默认显示所有容器"
        case (.simplifiedChinese, .showAllContainersHint): "新容器列表默认包含已停止的容器，可随时关闭。"
        case (.simplifiedChinese, .refresh): "刷新"
        case (.simplifiedChinese, .listRefreshInterval): "列表刷新间隔"
        case (.simplifiedChinese, .listRefreshIntervalHint): "用于容器列表自动刷新。"
        case (.simplifiedChinese, .appleContainersCLI): "Apple Containers CLI"
        case (.simplifiedChinese, .executableFound): "已找到可执行文件。"
        case (.simplifiedChinese, .pathNotExecutable): "当前路径不可执行，重启后将回退到自动查找。"
        case (.simplifiedChinese, .containerPath): "container 路径"
        case (.simplifiedChinese, .browse): "浏览..."
        case (.simplifiedChinese, .cliRelaunchHint): "CLI 路径会在 AppleStack 下次启动时生效。"
        case (.simplifiedChinese, .fontSize): "字体大小"
        case (.simplifiedChinese, .terminalFontHint): "用于容器和虚拟机的终端标签页。"
        case (.simplifiedChinese, .runtime): "运行状态"
        case (.simplifiedChinese, .running): "运行中"
        case (.simplifiedChinese, .stopped): "已停止"
        case (.simplifiedChinese, .systemUnavailable): "系统状态不可用"
        case (.simplifiedChinese, .commands): "命令"
        case (.simplifiedChinese, .version): "版本"
        case (.simplifiedChinese, .diskUsage): "磁盘占用"
        case (.simplifiedChinese, .logs): "日志"
        case (.simplifiedChinese, .properties): "属性"
        case (.simplifiedChinese, .dns): "DNS"
        case (.simplifiedChinese, .domain): "域名"
        case (.simplifiedChinese, .localhostIP): "本机 IP（可选）"
        case (.simplifiedChinese, .create): "创建"
        case (.simplifiedChinese, .delete): "删除"
        case (.simplifiedChinese, .kernel): "内核"
        case (.simplifiedChinese, .kernelPath): "内核路径"
        case (.simplifiedChinese, .setKernel): "设置内核"
        case (.simplifiedChinese, .build): "构建"
        }
    }

    func localized(_ value: String) -> String {
        guard self == .simplifiedChinese else { return value }
        switch value {
        case "Getting Started": return "开始"
        case "Quick Start": return "快速开始"
        case "Start using Apple containers in a few clicks.": return "用几次点击开始使用 Apple containers。"
        case "What do you want to do?": return "你想做什么？"
        case "Manage containers without memorizing commands.": return "不用记命令，也能管理容器。"
        case "Start the runtime, create what you need, then watch usage from one place.": return "启动运行时，创建所需资源，再在同一处查看占用。"
        case "Observe": return "观察"
        case "Start the system": return "启动系统"
        case "Turn on Apple Containers before creating or running anything.": return "创建或运行任何内容前，先启动 Apple Containers。"
        case "Create a container": return "创建容器"
        case "Run an app from an image with only a name and image.": return "只需名称和镜像即可从镜像运行应用。"
        case "Create a virtual machine": return "创建虚拟机"
        case "Create a Linux machine from a preset image.": return "从预设镜像创建 Linux 虚拟机。"
        case "Open Activity Monitor": return "打开活动监视器"
        case "See CPU, memory, network, and disk usage.": return "查看 CPU、内存、网络和磁盘占用。"
        case "Advanced Options": return "高级选项"
        case "Show advanced options": return "显示高级选项"
        case "Containers": return "容器"
        case "Images": return "镜像"
        case "Volumes": return "卷"
        case "Networks": return "网络"
        case "Machines": return "虚拟机"
        case "Linux": return "Linux"
        case "General": return "通用"
        case "Registry": return "镜像仓库"
        case "Activity Monitor": return "活动监视器"
        case "Commands": return "命令"
        case "Builder": return "构建器"
        case "Management": return "管理"
        case "Details": return "详情"
        case "Select an item": return "请选择项目"
        case "No Selection": return "未选择"
        case "Select an item from the list": return "请从列表中选择一个项目"
        case "Info": return "信息"
        case "Runtime": return "运行时"
        case "Network": return "网络"
        case "Logs": return "日志"
        case "Terminal": return "终端"
        case "Files": return "文件"
        case "Stats": return "统计"
        case "Inspect": return "检查"
        case "Resources": return "资源"
        case "Config": return "配置"
        case "History": return "历史"
        case "Labels": return "标签"
        case "Options": return "选项"
        case "Overview": return "概览"
        case "Actions": return "操作"
        case "Environment": return "环境变量"
        case "Exposed Ports": return "暴露端口"
        case "Layers": return "层"
        case "Key": return "键"
        case "Value": return "值"
        case "No containers": return "暂无容器"
        case "No images": return "暂无镜像"
        case "No volumes": return "暂无卷"
        case "No networks": return "暂无网络"
        case "No machines": return "暂无虚拟机"
        case "No matching volumes": return "没有匹配的卷"
        case "No matching networks": return "没有匹配的网络"
        case "No matching machines": return "没有匹配的虚拟机"
        case "running": return "运行中"
        case "networks": return "网络"
        case "volumes": return "卷"
        case "machines": return "虚拟机"
        case "local images": return "本地镜像"
        case "Search": return "搜索"
        case "Refresh": return "刷新"
        case "Retry": return "重试"
        case "Cancel": return "取消"
        case "Delete": return "删除"
        case "Create": return "创建"
        case "OK": return "确定"
        case "Done": return "完成"
        case "Copy": return "复制"
        case "Clear Search": return "清除搜索"
        case "Start System": return "启动系统"
        case "This action cannot be undone.": return "此操作无法撤销。"
        case "New Container": return "新建容器"
        case "New Volume": return "新建卷"
        case "New Network": return "新建网络"
        case "New Machine": return "新建虚拟机"
        case "More actions": return "更多操作"
        case "Prune volumes": return "清理卷"
        case "Prune networks": return "清理网络"
        case "Prune Volumes": return "清理卷"
        case "Prune Networks": return "清理网络"
        case "Build image": return "构建镜像"
        case "Load image archive": return "加载镜像归档"
        case "Pull Image": return "拉取镜像"
        case "Build Image": return "构建镜像"
        case "Load Image Archive": return "加载镜像归档"
        case "Image Inspect": return "镜像检查"
        case "Container Inspect": return "容器检查"
        case "Registries": return "镜像仓库"
        case "No registries": return "暂无镜像仓库"
        case "Login to a container registry": return "登录容器镜像仓库"
        case "Login": return "登录"
        case "Logout": return "退出登录"
        case "Live resource usage": return "实时资源占用"
        case "Update Frequency": return "更新频率"
        case "Name": return "名称"
        case "Engine": return "引擎"
        case "Memory:": return "内存："
        case "Network:": return "网络："
        case "Disk:": return "磁盘："
        case "CPU %": return "CPU %"
        case "Memory": return "内存"
        case "Disk": return "磁盘"
        case "Total": return "总计"
        case "Selected": return "已选择"
        case "Hide Search": return "隐藏搜索"
        case "Start": return "启动"
        case "Stop": return "停止"
        case "Set": return "设置"
        case "Pull": return "拉取"
        case "Tag": return "标签"
        case "Push": return "推送"
        case "Save": return "保存"
        case "Remove": return "移除"
        case "Export": return "导出"
        case "Kill": return "强制停止"
        case "Restart": return "重启"
        case "Pull Latest": return "拉取最新"
        case "Copy Files": return "复制文件"
        case "Volume Inspect": return "卷检查"
        case "Network Inspect": return "网络检查"
        case "Create Volume": return "创建卷"
        case "Volume name": return "卷名称"
        case "Create Network": return "创建网络"
        case "Basic Settings": return "基本设置"
        case "Network Name": return "网络名称"
        case "Driver": return "驱动"
        case "IPAM Configuration": return "IPAM 配置"
        case "Subnet (e.g., 172.20.0.0/16)": return "子网（例如 172.20.0.0/16）"
        case "Gateway (e.g., 172.20.0.1)": return "网关（例如 172.20.0.1）"
        case "Internal network": return "内部网络"
        case "Inspect volume": return "检查卷"
        case "Delete volume": return "删除卷"
        case "Inspect network": return "检查网络"
        case "Delete network": return "删除网络"
        case "login": return "个登录"
        case "logins": return "个登录"
        case "Logged in as": return "登录用户"
        case "Registry Login": return "镜像仓库登录"
        case "Server": return "服务器"
        case "Username": return "用户名"
        case "Scheme": return "协议"
        case "Password input is handled by the container CLI when required.": return "需要密码时由 container CLI 处理输入。"
        case "Working...": return "处理中..."
        case "Get started": return "开始使用"
        case "Storage & Network": return "存储与网络"
        case "Machines & Builder": return "虚拟机与构建器"
        case "Apple container commands": return "Apple container 命令"
        case "Use Apple container commands directly from macOS.": return "直接在 macOS 中使用 Apple container 命令。"
        case "System status": return "系统状态"
        case "Check whether the container system is running.": return "检查容器系统是否正在运行。"
        case "Start system": return "启动系统"
        case "Start Apple Containers when commands cannot connect.": return "命令无法连接时启动 Apple Containers。"
        case "Create, run, inspect, and debug containers.": return "创建、运行、检查和调试容器。"
        case "Run a web server": return "运行 Web 服务"
        case "Start a detached container and publish port 8080.": return "启动后台容器并发布 8080 端口。"
        case "Create without starting": return "仅创建不启动"
        case "Prepare a container with CPU and memory limits.": return "创建带 CPU 和内存限制的容器。"
        case "List containers": return "列出容器"
        case "Show all containers in JSON for scripting.": return "以 JSON 输出所有容器，便于脚本处理。"
        case "Open a shell": return "打开 Shell"
        case "Run an interactive shell inside a container.": return "在容器中运行交互式 Shell。"
        case "Follow logs": return "跟踪日志"
        case "Stream the latest container logs.": return "持续查看最新容器日志。"
        case "Copy files": return "复制文件"
        case "Copy files between the container and macOS.": return "在容器和 macOS 之间复制文件。"
        case "Export filesystem": return "导出文件系统"
        case "Save a container filesystem as an archive.": return "将容器文件系统保存为归档。"
        case "Pull, build, tag, move, and publish images.": return "拉取、构建、标记、移动和发布镜像。"
        case "Pull image": return "拉取镜像"
        case "Download an image from a registry.": return "从镜像仓库下载镜像。"
        case "Build from a Containerfile in the current directory.": return "使用当前目录中的 Containerfile 构建。"
        case "Tag image": return "标记镜像"
        case "Create a new reference for an existing image.": return "为已有镜像创建新引用。"
        case "Push image": return "推送镜像"
        case "Upload an image to a registry.": return "上传镜像到仓库。"
        case "Save image": return "保存镜像"
        case "Export an image archive.": return "导出镜像归档。"
        case "Load image": return "加载镜像"
        case "Import an image archive.": return "导入镜像归档。"
        case "Manage volumes, networks, DNS, and socket publishing.": return "管理卷、网络、DNS 和套接字发布。"
        case "Create volume": return "创建卷"
        case "Create a persistent data volume.": return "创建持久化数据卷。"
        case "Create network": return "创建网络"
        case "Create an isolated development network.": return "创建隔离的开发网络。"
        case "List DNS entries": return "列出 DNS 项"
        case "Inspect system DNS configuration.": return "检查系统 DNS 配置。"
        case "Publish socket": return "发布套接字"
        case "Expose a Unix socket into the container.": return "将 Unix 套接字暴露到容器中。"
        case "Create Linux machines and manage the image builder.": return "创建 Linux 虚拟机并管理镜像构建器。"
        case "Create machine": return "创建虚拟机"
        case "Create an Ubuntu machine with resources and home mount.": return "创建带资源限制和主目录挂载的 Ubuntu 虚拟机。"
        case "Machine shell": return "虚拟机 Shell"
        case "Open a machine shell.": return "打开虚拟机 Shell。"
        case "Builder status": return "构建器状态"
        case "Inspect builder availability.": return "检查构建器是否可用。"
        case "Start builder": return "启动构建器"
        case "Start the image builder.": return "启动镜像构建器。"
        case "Disk usage": return "磁盘占用"
        case "Inspect system disk usage.": return "检查系统磁盘占用。"
        case "List system properties.": return "列出系统属性。"
        case "1 second": return "1 秒"
        case "2 seconds": return "2 秒"
        case "5 seconds": return "5 秒"
        case "Loading system status...": return "正在加载系统状态..."
        case "OS": return "操作系统"
        case "Architecture": return "架构"
        case "Reference": return "引用"
        case "Digest": return "摘要"
        case "Created": return "创建时间"
        case "Size": return "大小"
        case "Media Type": return "媒体类型"
        case "Variant Digest": return "变体摘要"
        case "Layer": return "层"
        case "No inspect output available": return "暂无检查输出"
        case "Save this image as an OCI-compatible archive": return "将此镜像保存为 OCI 兼容归档"
        case "items": return "项"
        case "total": return "总计"
        case "In Use": return "使用中"
        case "Unused": return "未使用"
        case "Dangling": return "悬空"
        case "Tag Image": return "标记镜像"
        case "Target reference": return "目标引用"
        case "Push Image": return "推送镜像"
        case "Platform (optional, e.g. linux/arm64)": return "平台（可选，例如 linux/arm64）"
        case "Image": return "镜像"
        case "Image name (e.g., nginx:latest)": return "镜像名称（例如 nginx:latest）"
        case "Enter the full image name including tag (e.g., nginx:latest)": return "输入包含标签的完整镜像名称（例如 nginx:latest）"
        case "Context directory": return "上下文目录"
        case "Dockerfile/Containerfile path": return "Dockerfile/Containerfile 路径"
        case "Platform": return "平台"
        case "Platform (optional)": return "平台（可选）"
        case "DNS nameserver": return "DNS 服务器"
        case "DNS nameserver (optional)": return "DNS 服务器（可选）"
        case "For `container machine`, prefer building a custom image instead of using a generic distro tag directly.": return "用于 `container machine` 时，建议先构建自定义镜像，而不是直接使用通用发行版标签。"
        case "The image should provide `/sbin/init` at the root. If your build installs packages with `apt` or similar tools, configuring DNS can help avoid network resolution failures during build.": return "镜像根目录应提供 `/sbin/init`。如果构建过程使用 `apt` 等工具安装软件包，配置 DNS 可减少构建时的解析失败。"
        case "Use Machine Build Defaults": return "使用虚拟机构建默认值"
        case "Machine-Compatible Images": return "虚拟机兼容镜像"
        case "Recommended workflow from the tutorial: build a machine-oriented image first, then use that resulting image reference in the Machines view.": return "推荐流程：先构建面向虚拟机的镜像，再在虚拟机页面使用生成的镜像引用。"
        case "Starter Containerfile": return "起始 Containerfile"
        case "Starter example based on the tutorial's machine-image requirements: use a base image with `/sbin/init`, reset machine-id files, and boot to a non-GUI target. Save this as `Containerfile`, then build it from the Images view.": return "基于虚拟机镜像要求的起始示例：使用包含 `/sbin/init` 的基础镜像，重置 machine-id 文件，并启动到非图形目标。保存为 `Containerfile` 后可在镜像页面构建。"
        case "Build machine image": return "构建虚拟机镜像"
        case "Build Machine Image": return "构建虚拟机镜像"
        case "Build Machine Image...": return "构建虚拟机镜像..."
        case "Inspect Selected Machine": return "检查选中虚拟机"
        case "Show Selected Machine Logs": return "显示选中虚拟机日志"
        case "Configure Selected Machine": return "配置选中虚拟机"
        case "Set Selected as Default": return "设为默认虚拟机"
        case "Machine": return "虚拟机"
        case "Machine name": return "虚拟机名称"
        case "Recent build": return "最近构建"
        case "Use Recent Build": return "使用最近构建"
        case "Distribution": return "发行版"
        case "Custom": return "自定义"
        case "Preset": return "预设"
        case "Description": return "描述"
        case "Image reference": return "镜像引用"
        case "Choose a preset image or enter any OCI reference supported by Apple container. Generic distro images may still fail to boot as machines if they do not provide the init process expected by Apple container, such as `/sbin/init`. A safer workflow is to build a machine-compatible image first from Images > Build image, then paste that image reference here.": return "选择预设镜像，或输入 Apple container 支持的任意 OCI 引用。通用发行版镜像如果不提供 `/sbin/init` 等 Apple container 期望的 init 进程，仍可能无法作为虚拟机启动。更稳妥的流程是先从镜像页构建虚拟机兼容镜像，再把生成的引用粘贴到这里。"
        case "Memory (e.g., 2G, 4G)": return "内存（例如 2G、4G）"
        case "cores": return "核"
        case "The current `container machine create` CLI exposes CPU and memory settings only. Disk size is managed by the current machine/image defaults.": return "当前 `container machine create` CLI 仅暴露 CPU 和内存设置，磁盘大小由当前虚拟机/镜像默认值管理。"
        case "Target": return "目标"
        case "Selection": return "选择"
        case "Default platform": return "默认平台"
        case "Apple container supports `--arch`, `--os`, and `--platform` for `machine create`. This view currently uses the default `linux/arm64` target until explicit platform controls are wired into the form.": return "Apple container 的 `machine create` 支持 `--arch`、`--os` 和 `--platform`。在显式平台控件接入表单前，此页面默认使用 `linux/arm64`。"
        case "Home folder mount": return "主目录挂载"
        case "Set as default machine": return "设为默认虚拟机"
        case "Create without booting": return "创建后不启动"
        case "Advanced": return "高级"
        case "Advanced options map directly to `--home-mount`, `--set-default`, and `--no-boot`.": return "高级选项直接对应 `--home-mount`、`--set-default` 和 `--no-boot`。"
        case "Progress": return "进度"
        case "Waiting for output...": return "等待输出..."
        case "Copy Template": return "复制模板"
        case "Write Template File": return "写入模板文件"
        case "This follows the tutorial workflow: build a machine-oriented image first, then create a machine from the resulting tag.": return "这遵循教程流程：先构建面向虚拟机的镜像，再使用生成的标签创建虚拟机。"
        case "Use a base image that provides `/sbin/init`, reset machine-id files, and boot into a non-GUI target.": return "使用提供 `/sbin/init` 的基础镜像，重置 machine-id 文件，并启动到非图形目标。"
        case "Build Status": return "构建状态"
        case "Machine Configuration": return "虚拟机配置"
        case "Home Mount": return "主目录挂载"
        case "Read/Write": return "读写"
        case "Read Only": return "只读"
        case "None": return "无"
        case "Apply": return "应用"
        case "Delete builder?": return "删除构建器？"
        case "This removes the current builder instance. Existing images are not deleted.": return "这会移除当前构建器实例，不会删除已有镜像。"
        case "Start the builder to begin building images": return "启动构建器后即可开始构建镜像"
        case "No builder instance": return "暂无构建器实例"
        case "Start the builder before building images.": return "构建镜像前请先启动构建器。"
        case "Nodes": return "节点"
        case "selected": return "已选择"
        case "Start all selected": return "启动全部选中项"
        case "Stop all selected": return "停止全部选中项"
        case "Remove all selected": return "移除全部选中项"
        case "Container Name": return "容器名称"
        case "Image (e.g., nginx:latest)": return "镜像（例如 nginx:latest）"
        case "Memory (e.g., 512m, 2g)": return "内存（例如 512m、2g）"
        case "Port Mapping (e.g., 8080:80)": return "端口映射（例如 8080:80）"
        case "Network (name[,mac=...,mtu=...])": return "网络（name[,mac=...,mtu=...]）"
        case "DNS (e.g., 8.8.8.8)": return "DNS（例如 8.8.8.8）"
        case "DNS Domain": return "DNS 域名"
        case "DNS Search Domain": return "DNS 搜索域"
        case "DNS Option": return "DNS 选项"
        case "Do not configure DNS (--no-dns)": return "不配置 DNS（--no-dns）"
        case "Environment Variables": return "环境变量"
        case "Env file path": return "环境变量文件路径"
        case "Mount spec (type=bind,source=...,target=...,readonly)": return "挂载规则（type=bind,source=...,target=...,readonly）"
        case "tmpfs path": return "tmpfs 路径"
        case "Shared memory size (e.g., 1G)": return "共享内存大小（例如 1G）"
        case "Run in background (--detach)": return "后台运行（--detach）"
        case "Interactive mode (-i)": return "交互模式（-i）"
        case "Allocate TTY (-t)": return "分配 TTY（-t）"
        case "Auto-remove (--rm)": return "自动移除（--rm）"
        case "Process": return "进程"
        case "Entrypoint": return "入口点"
        case "Working directory": return "工作目录"
        case "User (name|uid[:gid])": return "用户（name|uid[:gid]）"
        case "Use init process (--init)": return "使用 init 进程（--init）"
        case "Init image": return "Init 镜像"
        case "Ulimit (type=soft[:hard])": return "Ulimit（type=soft[:hard]）"
        case "Platform & Runtime": return "平台与运行时"
        case "Platform (e.g., linux/arm64)": return "平台（例如 linux/arm64）"
        case "Runtime handler": return "运行时处理器"
        case "Registry scheme (auto/http/https)": return "镜像仓库协议（auto/http/https）"
        case "Max concurrent downloads": return "最大并发下载数"
        case "Capabilities & VM": return "能力与虚拟机"
        case "Read-only root filesystem": return "只读根文件系统"
        case "Enable Rosetta": return "启用 Rosetta"
        case "Forward SSH agent": return "转发 SSH agent"
        case "Expose nested virtualization": return "暴露嵌套虚拟化"
        case "Label (key=value)": return "标签（key=value）"
        case "Capability to add": return "要添加的能力"
        case "Capability to drop": return "要移除的能力"
        case "Create Container": return "创建容器"
        case "Host Path": return "宿主机路径"
        case "Container Path": return "容器路径"
        case "Published Ports": return "发布端口"
        case "Mounts": return "挂载"
        case "No network information": return "暂无网络信息"
        case "Loading logs...": return "正在加载日志..."
        case "No logs": return "暂无日志"
        case "No matching logs": return "没有匹配的日志"
        case "Refresh logs": return "刷新日志"
        case "Stop following logs": return "停止跟踪日志"
        case "Toggle auto-scroll": return "切换自动滚动"
        case "Copy logs": return "复制日志"
        case "Clear logs": return "清空日志"
        case "Container Terminal": return "容器终端"
        case "Enter shell command": return "输入 Shell 命令"
        case "Container is not running": return "容器未运行"
        case "Start the container to open a shell session.": return "启动容器后即可打开 Shell 会话。"
        case "Direction": return "方向"
        case "Container to Mac": return "容器到 Mac"
        case "Mac to Container": return "Mac 到容器"
        case "Container path": return "容器路径"
        case "Mac path": return "Mac 路径"
        case "Choose output folder": return "选择输出文件夹"
        case "Choose local file or folder": return "选择本地文件或文件夹"
        case "Export Filesystem": return "导出文件系统"
        case "Path Format": return "路径格式"
        case "Container path uses `%@:/path`. Mac path is an absolute local path.": return "容器路径使用 `%@:/path`。Mac 路径是绝对本地路径。"
        case "Apple container currently exposes copy/export operations through CLI. This view avoids pretending that random-access file browsing is available.": return "Apple container 当前通过 CLI 暴露复制/导出操作，因此此页面不会伪装成支持随机访问的文件浏览器。"
        case "Auto-refresh": return "自动刷新"
        case "Updated": return "已更新"
        case "Peak": return "峰值"
        case "Receive": return "接收"
        case "Transmit": return "发送"
        case "Read": return "读取"
        case "Write": return "写入"
        case "No stats available": return "暂无统计数据"
        case "Dashboard": return "概览"
        case "Recent Containers": return "最近容器"
        case "No data yet": return "暂无数据"
        case "Open AppleStack": return "打开 AppleStack"
        case "Stop System": return "停止系统"
        case "Quit": return "退出"
        case "Connect": return "连接"
        case "Clear terminal": return "清空终端"
        case "Copy terminal output": return "复制终端输出"
        case "Open in macOS Terminal": return "在 macOS 终端中打开"
        case "Unavailable": return "不可用"
        case "Connecting...": return "连接中..."
        case "Connected": return "已连接"
        case "Disconnected": return "未连接"
        case "Filesystem": return "文件系统"
        case "Parent folder": return "上级文件夹"
        case "Start the container to browse files.": return "启动容器后即可浏览文件。"
        case "Loading files...": return "正在加载文件..."
        case "Cannot load files": return "无法加载文件"
        case "Empty folder": return "空文件夹"
        case "No files in this directory.": return "此目录没有文件。"
        case "Modified": return "修改时间"
        case "Directory browsing uses a shell listing inside the running container. Copy and export still use Apple Containers CLI operations.": return "目录浏览会在运行中的容器内执行 Shell 列表命令；复制和导出仍使用 Apple Containers CLI 操作。"
        default: return value
        }
    }
}

enum SettingsTextKey {
    case general
    case terminal
    case system
    case about
    case language
    case interfaceLanguage
    case interfaceLanguageHint
    case containers
    case showAllContainers
    case showAllContainersHint
    case refresh
    case listRefreshInterval
    case listRefreshIntervalHint
    case appleContainersCLI
    case executableFound
    case pathNotExecutable
    case containerPath
    case browse
    case cliRelaunchHint
    case fontSize
    case terminalFontHint
    case runtime
    case running
    case stopped
    case systemUnavailable
    case commands
    case version
    case diskUsage
    case logs
    case properties
    case dns
    case domain
    case localhostIP
    case create
    case delete
    case kernel
    case kernelPath
    case setKernel
    case build
}

struct SettingsView: View {
    @Environment(\.cliBackend) private var cliBackend

    @AppStorage("cliPath") private var cliPath = "/usr/local/bin/container"
    @AppStorage("refreshInterval") private var refreshInterval = 10.0
    @AppStorage("showAllContainers") private var showAllContainers = true
    @AppStorage("terminalFontSize") private var terminalFontSize = 12.0
    @AppStorage("appLanguage") private var appLanguageRaw = AppLanguage.english.rawValue

    @State private var selectedSection: SettingsSection = .general
    @State private var systemViewModel: SystemStatusViewModel?

    private let settingsContentWidth: CGFloat = 520

    private var language: AppLanguage {
        AppLanguage(rawValue: appLanguageRaw) ?? .english
    }

    private var languageBinding: Binding<AppLanguage> {
        Binding(
            get: { language },
            set: { appLanguageRaw = $0.rawValue }
        )
    }

    var body: some View {
        HStack(spacing: 0) {
            settingsSidebar
                .frame(width: 168)

            Divider()

            settingsDetail
        }
        .frame(width: 700, height: 500)
        .background(SettingsWindowAccessor())
        .environment(\.locale, Locale(identifier: language.localeIdentifier))
        .onAppear {
            normalizeDefaults()
            if systemViewModel == nil {
                systemViewModel = SystemStatusViewModel(service: cliBackend)
            }
        }
    }

    private var settingsSidebar: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(SettingsSection.allCases) { section in
                Button {
                    selectedSection = section
                } label: {
                    Label(section.title(language: language), systemImage: section.icon)
                        .font(.system(size: 12.5, weight: selectedSection == section ? .semibold : .regular))
                        .foregroundStyle(selectedSection == section ? .white : .primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 11)
                        .padding(.vertical, 7)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(selectedSection == section ? AppTheme.accentColor : Color.clear)
                        )
                        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
                .focusEffectDisabled()
            }
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.top, 42)
        .background(AppTheme.chromeBackground)
        .ignoresSafeArea(.container, edges: .top)
    }

    private var settingsDetail: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Text(selectedSection.title(language: language))
                    .font(.system(size: 17, weight: .semibold))
                    .padding(.top, 0)

                switch selectedSection {
                case .general:
                    generalSettings
                case .cli:
                    cliSettings
                case .terminal:
                    terminalSettings
                case .system:
                    if let systemViewModel {
                        RuntimeSettingsPane(viewModel: systemViewModel, language: language)
                    }
                case .about:
                    aboutSettings
                }
            }
            .padding(.horizontal, 28)
            .padding(.top, 20)
            .padding(.bottom, 24)
            .frame(maxWidth: settingsContentWidth, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(AppTheme.chromeBackground)
        .ignoresSafeArea(.container, edges: .top)
    }

    private var generalSettings: some View {
        VStack(alignment: .leading, spacing: 16) {
            settingsGroup(language.text(.language)) {
                settingsPickerRow(
                    title: language.text(.interfaceLanguage),
                    subtitle: language.text(.interfaceLanguageHint)
                ) {
                    Picker("", selection: languageBinding) {
                        ForEach(AppLanguage.allCases) { language in
                            Text(language.displayName).tag(language)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                }
            }

            settingsGroup(language.text(.containers)) {
                settingsToggleRow(
                    title: language.text(.showAllContainers),
                    subtitle: language.text(.showAllContainersHint),
                    isOn: $showAllContainers
                )
            }

            settingsGroup(language.text(.refresh)) {
                settingsSliderRow(
                    title: language.text(.listRefreshInterval),
                    subtitle: language.text(.listRefreshIntervalHint),
                    valueText: "\(Int(refreshInterval))s"
                ) {
                    Slider(value: $refreshInterval, in: 5...60, step: 5)
                }
            }
        }
    }

    private var cliSettings: some View {
        settingsGroup(language.text(.appleContainersCLI), subtitle: cliExecutableMessage) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    TextField(language.text(.containerPath), text: $cliPath)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 12, design: .monospaced))

                    Button(language.text(.browse)) {
                        chooseCLIPath()
                    }
                    .controlSize(.small)
                }

                Text(language.text(.cliRelaunchHint))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var terminalSettings: some View {
        settingsGroup(language.text(.terminal)) {
            settingsSliderRow(
                title: language.text(.fontSize),
                subtitle: language.text(.terminalFontHint),
                valueText: String(format: "%.0f pt", terminalFontSize)
            ) {
                Slider(value: $terminalFontSize, in: 8...24, step: 1)
            }
        }
    }

    private var aboutSettings: some View {
        settingsGroup("AppleStack") {
            settingsValueRow(title: language.text(.version), value: "1.0.0")
            Divider()
            settingsValueRow(title: language.text(.build), value: "2024.1")
        }
    }

    private var cliExecutableMessage: String {
        FileManager.default.isExecutableFile(atPath: cliPath)
            ? language.text(.executableFound)
            : language.text(.pathNotExecutable)
    }

    private func settingsGroup<Content: View>(
        _ title: String,
        subtitle: String? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12.5, weight: .semibold))
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 10.5))
                        .foregroundStyle(.secondary)
                }
            }

            VStack(spacing: 0) {
                content()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(settingsCardBackground)
            .overlay(settingsCardBorder)
        }
    }

    private func settingsToggleRow(
        title: String,
        subtitle: String,
        isOn: Binding<Bool>
    ) -> some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12.5, weight: .medium))
                Text(subtitle)
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
            }
            .fixedSize(horizontal: false, vertical: true)
            Spacer()
            Toggle("", isOn: isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
        }
        .padding(.vertical, 3)
    }

    private func settingsPickerRow<Control: View>(
        title: String,
        subtitle: String,
        @ViewBuilder control: () -> Control
    ) -> some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12.5, weight: .medium))
                Text(subtitle)
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
            }
            .fixedSize(horizontal: false, vertical: true)
            Spacer()
            control()
                .frame(width: 160)
        }
        .padding(.vertical, 3)
    }

    private func settingsSliderRow<Control: View>(
        title: String,
        subtitle: String,
        valueText: String,
        @ViewBuilder control: () -> Control
    ) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 12.5, weight: .medium))
                    Text(subtitle)
                        .font(.system(size: 10.5))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(valueText)
                    .font(.system(size: 11.5, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            control()
                .controlSize(.small)
        }
        .padding(.vertical, 3)
    }

    private func settingsValueRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 12.5))
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 12.5, weight: .medium))
        }
        .padding(.vertical, 5)
    }

    private var settingsCardBackground: some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(Color(nsColor: .controlBackgroundColor).opacity(0.82))
    }

    private var settingsCardBorder: some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .stroke(AppTheme.subtleBorder.opacity(0.42), lineWidth: 0.5)
    }

    private func chooseCLIPath() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            cliPath = url.path
        }
    }

    private func normalizeDefaults() {
        refreshInterval = min(max(refreshInterval, 5), 60)
        terminalFontSize = min(max(terminalFontSize, 8), 24)
    }
}

private struct SettingsWindowAccessor: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        DispatchQueue.main.async {
            configure(window: view.window)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            configure(window: nsView.window)
        }
    }

    private func configure(window: NSWindow?) {
        guard let window else { return }
        // 设置窗口里已有页面标题，隐藏系统标题能减少顶部噪声，更接近 OrbStack 的 Preferences。
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.toolbarStyle = .unifiedCompact
        window.styleMask.insert(.fullSizeContentView)
    }
}

private struct RuntimeSettingsPane: View {
    @Bindable var viewModel: SystemStatusViewModel
    let language: AppLanguage

    private let commandColumns = [
        GridItem(.adaptive(minimum: 104), spacing: 8),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            settingsGroup(language.text(.runtime)) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 10) {
                        Circle()
                            .fill(viewModel.isRunning ? .green : .red)
                            .frame(width: 8, height: 8)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(viewModel.isRunning ? language.text(.running) : language.text(.stopped))
                                .font(.system(size: 12.5, weight: .semibold))
                            Text(viewModel.osInfo == "Unknown" ? language.text(.systemUnavailable) : viewModel.osInfo)
                                .font(.system(size: 10.5))
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        runtimeButton(viewModel.isLoading ? "hourglass" : "arrow.clockwise", help: "Refresh") {
                            Task { await viewModel.loadStatus(showLoading: false) }
                        }
                        .disabled(viewModel.isLoading || viewModel.isActionRunning)

                        runtimeButton(viewModel.isActionRunning ? "hourglass" : "play.fill", help: "Start") {
                            Task { await viewModel.startSystem() }
                        }
                        .disabled(viewModel.isRunning || viewModel.isActionRunning)

                        runtimeButton(viewModel.isActionRunning ? "hourglass" : "stop.fill", help: "Stop") {
                            Task { await viewModel.stopSystem() }
                        }
                        .disabled(!viewModel.isRunning || viewModel.isActionRunning)
                    }

                    if let errorMessage = viewModel.errorMessage {
                        Text(errorMessage)
                            .font(.system(size: 10.5))
                            .foregroundStyle(.orange)
                            .textSelection(.enabled)
                    }
                }
            }

            settingsGroup(language.text(.commands)) {
                LazyVGrid(columns: commandColumns, alignment: .leading, spacing: 8) {
                    runtimeCommand(language.text(.version), icon: "number") {
                        Task { await viewModel.showVersion() }
                    }
                    runtimeCommand(language.text(.diskUsage), icon: "internaldrive") {
                        Task { await viewModel.showDiskUsage() }
                    }
                    runtimeCommand(language.text(.logs), icon: "doc.text") {
                        Task { await viewModel.showLogs() }
                    }
                    runtimeCommand(language.text(.properties), icon: "list.bullet.rectangle") {
                        Task { await viewModel.showProperties() }
                    }
                    runtimeCommand(language.text(.dns), icon: "network") {
                        Task { await viewModel.showDNS() }
                    }
                }
            }

            settingsGroup(language.text(.dns)) {
                VStack(alignment: .leading, spacing: 8) {
                    TextField(language.text(.domain), text: $viewModel.dnsDomain)
                        .textFieldStyle(.roundedBorder)
                        .controlSize(.small)
                    TextField(language.text(.localhostIP), text: $viewModel.dnsLocalhost)
                        .textFieldStyle(.roundedBorder)
                        .controlSize(.small)
                    HStack {
                        Button(language.text(.create)) {
                            Task { await viewModel.createDNS() }
                        }
                        .disabled(viewModel.dnsDomain.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isActionRunning)

                        Button(language.text(.delete)) {
                            Task { await viewModel.deleteDNS() }
                        }
                        .disabled(viewModel.dnsDomain.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isActionRunning)
                    }
                    .controlSize(.small)
                }
            }

            settingsGroup(language.text(.kernel)) {
                VStack(alignment: .leading, spacing: 8) {
                    TextField(language.text(.kernelPath), text: $viewModel.kernelPath)
                        .textFieldStyle(.roundedBorder)
                        .controlSize(.small)
                    Button(language.text(.setKernel)) {
                        Task { await viewModel.setKernel() }
                    }
                    .controlSize(.small)
                    .disabled(viewModel.kernelPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isActionRunning)
                }
            }
        }
        .task {
            await viewModel.loadStatus(showLoading: viewModel.systemInfo == nil)
        }
        .sheet(isPresented: $viewModel.showOutputSheet) {
            InspectOutputSheet(title: viewModel.outputTitle, output: viewModel.outputText)
        }
    }

    private func settingsGroup<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(.system(size: 12.5, weight: .semibold))

            VStack(spacing: 0) {
                content()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor).opacity(0.82))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(AppTheme.subtleBorder.opacity(0.42), lineWidth: 0.5)
            )
        }
    }

    private func runtimeButton(_ icon: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            SwiftUI.Image(systemName: icon)
                .font(.system(size: 12, weight: .medium))
                .frame(width: 24, height: 24)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focusEffectDisabled()
        .help(help)
    }

    private func runtimeCommand(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.system(size: 11.5, weight: .medium))
                .frame(maxWidth: .infinity, minHeight: 26)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
    }
}

#Preview {
    SettingsView()
        .environment(\.cliBackend, ContainerServiceFactory.create())
}
