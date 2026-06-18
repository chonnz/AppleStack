---
type: Inbox
---
# Apple 官方 container CLI 命令

## 一、 全局参数 (Global Options)

在输入任何子命令前，可附加的全局全局控制参数： [4]

- --debug：开启调试输出，捕获更详细的底层虚拟机/网络日志（或配置环境变量 CONTAINER_DEBUG=1）。
- --version：查看版本。
- -h, --help：显示帮助信息。 [4]

***

## 二、 容器操作子命令 (Container Management)

用于控制轻量级 Linux 虚拟机中单个应用进程的生命周期： [3, 5]

- container create：创建新容器（但不运行）。 [6]
- container run：创建并运行容器。
- -d, --detach：后台运行容器。
  - -it：开启交互式终端（-i 保持标准输入，-t 分配伪终端）。
  - --name ：为容器指定自定义名称。
  - --rm, --remove：容器退出后自动将其删除。
  - -v, --volume / --mount：挂载宿主机目录（例如：-v /src:/dst）。
  - -c, --cpus / -m, --memory：限制容器分配的 CPU 核心数和内存大小。
  - --dns ：手动为容器指定 DNS 解析服务器。 [3, 6, 7]
- container start：启动一个或多个处于停止状态的容器。 [1, 8]
- container stop：停止正在运行的容器。 [6]
- container kill：强行终止一个或多个正在运行的容器。
- -s, --signal ：发送指定信号（默认发送 KILL）。 [1, 6]
- container delete (或 container rm)：删除容器。
- -a, --all：删除所有容器。
  - -f, --force：强制删除正在运行的容器。 [1, 2, 6]
- container list (或 container ls)：列出当前容器。
- -a, --all：显示所有容器（包括已停止的）。
  - -q, --quiet：只打印容器的唯一 ID。
  - --format ：指定输出格式（支持 table, json, yaml, toml）。 [1, 2, 6, 9]
- container exec：在运行中的容器内执行新命令。 [2, 6]
- container logs：获取并查看容器的 stdout/stderr 标准输出日志。
- -f, --follow：持续跟踪并实时打印日志。
  - --boot：查看底层的虚拟机系统引导日志。 [1, 6]
- container inspect：以 JSON 格式输出容器的底层详细配置信息。 [1, 6]
- container prune：一键清理所有已停止的容器，释放 Mac 磁盘空间。 [1]
- container copy (或 container cp)：在 Mac 宿主机与容器文件系统之间互相复制文件/文件夹。 [1]

***

## 三、 镜像与仓库子命令 (Image & Registry Management)

用于管理 OCI/Docker 标准镜像文件的生命周期及远端分发： [2, 3]

- container build：基于 Dockerfile 构建容器镜像。
- -t, --tag：为生成的镜像标记名称及版本标签。 [6, 10]
- container images (或 container image)：进入二级镜像管理组。
- container image list：列出本地存储的所有镜像（可直接简写为 container images）。
  - container image pull ：从远端镜像仓库下载镜像。
  - container image push ：将本地镜像推送上传到远端仓库。
  - container image tag ：为现有镜像打新标签（别名）。
  - container image delete (或 container image rm) <image_id>：删除指定的本地镜像。
  - container image inspect：查看镜像的元数据层级、环境变量等 JSON 详细属性。
  - container image save：将镜像导出打包为 .tar 文件。
  - container image load：从外部 .tar 归档包中导入还原镜像。 [1, 2, 6]
- container registry (或简写为 container r)：配置镜像中心。
- container registry login：登录至私有或公共 OCI 镜像中心（如 Docker Hub、GHCR）。
  - container registry logout：退出当前 registry 登录状态。
  - container registry list (或 ls)：列出当前已保存的 registry 登录信息。 [2, 3, 6]

***

## 四、 完整开发环境子命令 (Container Machine)

类似 WSL2，该模式会启动完整的系统级初始化进程（如 systemd），并自动挂载 Mac 的 $HOME 目录（可简写为 container m）： [5]

- container machine create：创建一个基于完整 Linux 操作系统的独立开发环境虚拟机。
- -n, --name ：指定开发环境名称。
  - --cpus / --memory：独立配置该环境的硬件资源。
  - --home-mount <rw|ro|none>：指定 Mac 家目录的挂载权限（读写/只读/不挂载）。 [5, 11]
  - --set-default：创建后将其设为默认 machine。
  - --no-boot：仅创建 machine，不立即启动。 
- container machine run ：启动并立刻登录进入该 Linux 开发环境终端。 [5]
- container machine stop ：停止运行该开发环境虚拟机。 [5]
- container machine rm ：完全注销并删除该开发环境（清空其内部持久化状态）。 [5]
- container machine set-default ：将指定的虚拟机设为默认环境，后续只需敲 container m run 即可直接进入。 [5]

***

## 五、 系统级管理子命令 (System Management)

用于管理底层基础设施及守护进程状态： [2, 6]

- container system (或简写为 container s)：
- container system start：唤醒并启动 macOS 上的 Containerization 核心后台服务。
  - container system stop：关闭后台服务，并安全释放底层占用的虚拟化组件。
  - container system status：检查当前服务是否处于正常 Active 运行状态。 [6, 8, 10]
- container builder：
- container builder start：启动用于构建高性能镜像的 BuildKit 独立编译器容器。
  - container builder stop：停止当前处于活动状态的 BuildKit 编译器。
  - container builder status：输出当前编译引擎的状态及并发任务数。 [1, 6]
- container volume：
- container volume create ：创建持久化数据卷，避免容器删除后数据丢失。
  - container volume ls / rm：列出或删除数据卷。 [8]

***
