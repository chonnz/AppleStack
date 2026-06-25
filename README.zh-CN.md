# AppleStack

[English](README.md)

AppleStack 是一款原生 macOS 桌面应用，用于以可视化方式管理 Apple 开源 [`container`](https://github.com/apple/container) CLI。它的使用体验参考 OrbStack，覆盖容器、镜像、卷、网络、Linux 虚拟机、镜像仓库、实时资源监控和常用 Apple container 命令。

AppleStack 不是 Apple 官方产品，而是一个基于 Apple `container` 命令行工具构建的独立开源客户端。

## 功能特性

- **容器**：列表、创建、启动、停止、重启、强制停止、删除、检查、日志、终端、文件复制和文件系统导出。
- **镜像**：拉取、构建、加载、标记、推送、保存、检查、按使用状态分组和删除。
- **卷和网络**：创建、检查、删除、清理和搜索本地资源。
- **Linux 虚拟机**：创建、启动、停止、删除、检查、日志、CPU/内存/主目录挂载配置，以及构建面向虚拟机的镜像。
- **镜像仓库**：查看登录信息、登录和退出登录。
- **活动监视器**：按容器和虚拟机展示资源行，并提供实时 CPU、内存、网络和磁盘图表。
- **系统面板**：查看运行时状态、磁盘占用、日志、DNS、属性、内核设置和构建器状态。
- **命令参考**：提供常用 `container` 命令示例，并支持一键复制。
- **菜单栏工具**：查看运行时状态，并快速启动/停止容器或 Apple container 系统。
- **国际化**：支持英文和简体中文，可在设置中切换。

## 系统要求

- macOS 15 或更高版本。
- Xcode Command Line Tools 或带 Swift 6 支持的 Xcode。
- 已安装 Apple [`container`](https://github.com/apple/container) CLI。
- 推荐使用 Apple silicon，因为 Apple container 栈针对 Apple silicon 优化。

## 安装 Apple container

请从 Apple 官方项目安装 `container` CLI：

- GitHub：<https://github.com/apple/container>
- 文档：<https://apple.github.io/container/documentation/>

安装后可用以下命令验证：

```bash
container system status
```

如果 `container` 没有安装在 shell 的 `PATH` 中，可以在 AppleStack 设置页中手动配置 CLI 路径。

## 构建和运行

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

## 设置项

AppleStack 当前支持以下设置：

- 界面语言：英文或简体中文。
- Apple Containers CLI 路径。
- 容器列表行为，包括是否默认显示已停止容器。
- 列表刷新间隔。
- 终端字体大小。
- 系统控制，包括运行时状态、DNS、内核路径、日志、属性和构建器状态。

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

AppleStack 通过本地 `container` CLI 工作，而不是直接链接 Apple container 的内部实现。这样可以保持应用结构简单，也便于测试 CLI 兼容性。多数功能由轻量 SwiftUI 页面和后端命令构建器组成，测试覆盖了命令参数生成和输出解析行为。

常用开发命令：

```bash
swift test
scripts/build-app.sh
open build/AppleStack.app
```

当前发布范围、验证清单和已知限制请见 [RELEASE_NOTES.md](RELEASE_NOTES.md)。

## 路线图

- 更完整覆盖 `container` CLI 的所有子命令。
- 完善虚拟机和构建器工作流。
- 优化 Apple container 系统未运行时的诊断提示。
- 增加应用设置导入/导出能力。
- 补充更多本地化文本和语言。
- 提供签名和公证后的发布版本。

## 贡献

欢迎提交 Issue 和 Pull Request。UI 改动请保持原生、紧凑，并符合 macOS 桌面应用习惯。后端改动请优先补充或更新测试，验证准确的 `container` CLI 参数和输出解析行为。

## 许可证

AppleStack 使用 MIT License 发布。详情见 [LICENSE](LICENSE)。
