import Testing
@testable import AppleStack

struct AppLanguageTests {
    @Test func simplifiedChineseCoversPrimaryVisibleLabels() {
        let language = AppLanguage.simplifiedChinese

        let requiredTranslations = [
            "Quick Start": "快速开始",
            "Start using Apple containers in a few clicks.": "用几次点击开始使用 Apple containers。",
            "Create a container": "创建容器",
            "Create a virtual machine": "创建虚拟机",
            "Open Activity Monitor": "打开活动监视器",
            "Advanced Options": "高级选项",
            "Show advanced options": "显示高级选项",
            "Commands": "命令",
            "Use Apple container commands directly from macOS.": "直接在 macOS 中使用 Apple container 命令。",
            "System status": "系统状态",
            "Run a web server": "运行 Web 服务",
            "Registry Login": "镜像仓库登录",
            "Logged in as": "登录用户",
            "Activity Monitor": "活动监视器",
            "Live resource usage": "实时资源占用",
            "Name": "名称",
            "Total": "总计",
            "Selected": "已选择",
            "Hide Search": "隐藏搜索",
            "Create Volume": "创建卷",
            "Create Network": "创建网络",
            "Kill container?": "强制停止容器？",
            "This immediately stops the running process inside the container.": "这会立即停止容器内正在运行的进程。",
            "Prune unused volumes?": "清理未使用的卷？",
            "This removes unused local volumes. Existing containers are not deleted.": "这会移除未使用的本地卷，不会删除已有容器。",
            "Prune unused networks?": "清理未使用的网络？",
            "This removes unused local networks. Existing containers are not deleted.": "这会移除未使用的本地网络，不会删除已有容器。",
            "System template": "系统模板",
            "Choose a system": "选择系统",
            "AppleStack prepares the selected Linux system automatically.": "AppleStack 会自动准备选中的 Linux 系统。",
            "Best for": "适合",
            "Best choice for daily development": "适合日常开发的默认选择",
            "Standard": "标准",
            "Configuration": "配置",
            "Home folder access": "主目录访问",
            "Create but do not start yet": "创建后暂不启动",
            "Preparing system template...": "正在准备系统模板...",
            "Creating virtual machine...": "正在创建虚拟机...",
            "Virtual machine is ready": "虚拟机已可用",
            "Please enter a machine name.": "请先填写虚拟机名称。",
        ]

        for (source, expected) in requiredTranslations {
            #expect(language.localized(source) == expected)
        }
    }

    @Test func quickStartIsTheDefaultSection() {
        #expect(AppSection.quickStart.rawValue == "Quick Start")
    }
}
