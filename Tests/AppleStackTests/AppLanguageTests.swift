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
        ]

        for (source, expected) in requiredTranslations {
            #expect(language.localized(source) == expected)
        }
    }

    @Test func quickStartIsTheDefaultSection() {
        #expect(AppSection.quickStart.rawValue == "Quick Start")
    }
}
