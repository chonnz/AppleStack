# AppleStack

[English](README.md)

AppleStack 是一款原生 macOS 桌面应用，用于以可视化方式管理 Apple 开源 [`container`](https://github.com/apple/container) CLI。它保留命令行能力，但把日常容器、镜像、卷、网络、Linux 虚拟机、镜像仓库、资源监控和诊断操作变成更直观的 macOS 界面。

AppleStack 不是 Apple 官方产品，而是一个基于 Apple `container` 命令行工具构建的独立开源客户端。

## 它能做什么

- **管理容器**：创建、启动、停止、重启、强制停止、删除、检查、查看日志、打开终端、复制文件和导出文件系统。
- **管理镜像**：拉取、构建、加载、标记、推送、保存、检查、按使用状态分组和删除本地镜像。
- **管理卷和网络**：创建、检查、搜索、清理和删除卷与网络。
- **创建 Linux 虚拟机**：从预设系统创建可用的 Linux 虚拟机，配置 CPU、内存、主目录访问，并查看日志、文件、终端和 inspect 输出。
- **使用镜像仓库**：查看登录状态，登录或退出镜像仓库。
- **监控资源占用**：实时查看容器和虚拟机的 CPU、内存、网络和磁盘占用。
- **更快执行常用命令**：在内置命令参考中复制常用 `container` 命令。
- **从 macOS 控制运行时**：通过主窗口或菜单栏工具查看状态，启动或停止 Apple container 系统。

## 适合哪些人

- 正在使用 Apple `container`，希望提升本地开发效率的开发者。
- 在 macOS 和 Apple silicon 上评估 Apple container 栈的团队。
- 熟悉 Docker Desktop 或 OrbStack 操作方式，希望 Apple `container` 也有类似桌面体验的工程师。
- 能使用命令行，但更偏好可视化状态、表单和安全确认的人。
- 需要帮助非技术同事使用本地容器，而不是先教完整 CLI 子命令的人。

## 亮点

- **原生 macOS 体验**：SwiftUI 应用，包含侧边栏导航、紧凑工具栏、菜单栏入口、键盘快捷键、系统表单和浅色/深色模式。
- **新手友好的路径**：快速开始页引导用户检查 CLI 路径、启动运行时、创建第一个容器或 Linux 虚拟机，并进入资源监控。
- **操作更安全**：删除等破坏性操作有确认弹窗，镜像和虚拟机长任务有进度提示，运行时连接错误提供重试和启动系统入口。
- **虚拟机能力更完整**：Linux 虚拟机创建包含系统预设、资源预设、默认虚拟机选项、日志、文件、终端和 inspect 视图。
- **贴近官方 CLI**：AppleStack 调用本机 `container` 可执行文件，行为更接近官方 CLI，也更容易测试。
- **双语界面**：可在设置中切换英文和简体中文。

## 系统要求

- macOS 15 或更高版本。
- Xcode Command Line Tools 或带 Swift 6 支持的 Xcode。
- 已安装 Apple [`container`](https://github.com/apple/container) CLI。
- 推荐使用 Apple silicon，因为 Apple container 栈针对 Apple silicon 优化。

## 安装 Apple Container

请从 Apple 官方项目安装 `container` CLI：

- GitHub：<https://github.com/apple/container>
- 文档：<https://apple.github.io/container/documentation/>

安装后可用以下命令验证：

```bash
container system status
```

如果 `container` 没有安装在 shell 的 `PATH` 中，可以在 AppleStack 设置页手动配置 CLI 路径。

## 本地部署

克隆仓库：

```bash
git clone <repo-url>
cd AppleStack
```

构建 Swift Package：

```bash
swift build
```

生成可运行的 macOS 应用包：

```bash
scripts/build-app.sh
```

打开应用：

```bash
open build/AppleStack.app
```

运行测试：

```bash
swift test
```

## 如何使用

1. 打开 AppleStack；如果没有自动找到 `container`，先进入 **设置 > CLI** 配置可执行文件路径。
2. 在 **快速开始** 中启动 Apple container 运行时。
3. 通过侧边栏或快速开始卡片创建容器、拉取镜像或创建 Linux 虚拟机。
4. 在列表中选择资源，查看详情、日志、文件、终端、统计和原始 CLI 输出。
5. 打开 **活动监视器** 查看实时资源占用。
6. 使用菜单栏入口快速查看状态，或执行运行时和容器控制。

## 项目结构

```text
Sources/AppleStack/
  Models/          容器、镜像、网络、虚拟机、统计和配置等数据模型
  Services/        CLI 执行、后端协议、终端会话和共享环境键
  ViewModels/      容器、镜像、系统状态和日志等可观察状态
  Views/           按功能划分的 SwiftUI 页面
Tests/             Swift Testing 测试套件
Resources/         应用包元数据
scripts/           本地构建脚本
```

## 开发说明

AppleStack 通过本地 `container` CLI 工作，而不是直接链接 Apple container 内部实现。修改时优先保持 SwiftUI 页面小而清晰，并用测试验证准确的 CLI 参数、输出解析和用户可见工作流。

常用开发命令：

```bash
swift test
scripts/build-app.sh
open build/AppleStack.app
```

当前发布范围、验证清单和已知限制请见 [RELEASE_NOTES.md](RELEASE_NOTES.md)。

## 许可证

AppleStack 使用 MIT License 发布。详情见 [LICENSE](LICENSE)。
