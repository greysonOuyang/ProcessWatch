# ProcessWatch

> 1.1.4 目录修正版：工程根目录与源码目录不再同名，内部源码统一放在 `Sources/`。

一个轻量级 macOS 菜单栏异常进程监控工具。重点不是复制“活动监视器”，而是回答：哪个进程组异常、实例为何不断增加、是否存在孤儿进程，以及它属于哪个开发工具链。

## 最简单的构建方式

解压后进入包含 `ProcessWatch.xcodeproj` 的目录，直接运行：

```bash
./build.sh --clean --run
```

也可以运行 `./run.sh`。正确的项目根目录会同时包含 `build.sh`、`ProcessWatch.xcodeproj`、`Sources/` 和 `scripts/`。源码目录只有一层，名称为 `Sources`。


## 当前功能

### 进程诊断

- 按可执行文件路径聚合同名进程，例如 `bun × 58`
- 聚合展示 CPU、内存、磁盘读写、孤儿进程数量和最长运行时间
- 展开进程组后展示每个实例的：
  - PID / PPID
  - 完整命令行
  - 工作目录
  - 启动时间与运行时长
  - 父进程名称
  - 是否为孤儿进程
  - 是否属于 repo-harness / Codex 调用链
- 支持按名称、PID、PPID、命令、目录、父进程和归属搜索
- 支持按 CPU、内存、写盘、实例数和孤儿进程数排序

### 异常检测

- 持续高 CPU
- 时间窗口内持续内存增长
- 持续高磁盘写入
- 进程风暴：同一可执行文件实例数超过阈值并持续一段时间
- repo-harness 疑似进程泄漏：进程风暴中存在 PPID=1、属于 repo-harness 调用链且长时间运行的孤儿进程
- 同类异常恢复前不重复通知，并带 30 分钟冷却时间

### 系统状态

- 系统 CPU 使用率
- 内存压力
- Swap 使用量
- 压缩内存
- 可回收缓存估算
- 相邻采样间的系统内存增长速度
- macOS 热状态及与等级一致的性能限制文案

### 其他

- macOS 本地通知
- 异常历史记录
- 进程忽略列表
- 登录时启动
- 在 Finder 中定位可执行文件
- 向指定 PID 发送 `SIGTERM`

## 系统要求

- macOS 13 Ventura 或更高版本
- Xcode 15 或更高版本

## 命令行构建

```bash
# Release 构建，产物位于 dist/ProcessWatch.app
./scripts/build_app.sh

# 清理后重新构建并直接运行
./scripts/build_app.sh --clean --run

# Debug 构建
./scripts/build_app.sh --debug
```

也可以使用 Makefile：

```bash
make build      # Release
make run        # Debug 并启动
make dmg        # 生成 dist/ProcessWatch.dmg
make install    # 构建并安装到 /Applications
make clean
```

脚本默认会对 `dist/ProcessWatch.app` 进行本机 ad-hoc 签名，适合本地运行。需要使用正式开发者证书时，可以指定：

```bash
SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" \
  ./scripts/build_app.sh --release
```

正式对外分发还需要使用自己的 Developer ID 执行公证。当前脚本不会上传证书或自动公证。

## Xcode 运行

1. 解压源码。
2. 双击 `ProcessWatch.xcodeproj`。
3. 在 Xcode 中选择 `ProcessWatch` scheme 和 `My Mac`。
4. 点击 Run。
5. 第一次启动时允许通知权限。

应用是 `LSUIElement` 菜单栏程序，默认不会出现在 Dock。点击菜单栏图标可打开浮窗和主界面。

## 默认异常规则

- 进程风暴：同一可执行文件实例数 `> 10`，持续 120 秒
- repo-harness 孤儿判断：PPID 为 1、属于 repo-harness 调用链、运行超过 600 秒，并且所在进程组已构成进程风暴
- CPU：单进程超过 80%，持续 120 秒
- 内存：10 分钟增长超过 1024 MB
- 磁盘：写入超过 30 MB/s，持续 120 秒

所有规则都可以在设置页修改。进程 CPU 允许超过 100%，因为多线程进程可以同时占用多个逻辑核心。

## 实现说明

采样层不依赖 `top` 或 `ps`，而是通过 C Bridge 调用 macOS 原生接口：

- `proc_listpids`
- `proc_pid_rusage`
- `proc_pidinfo`
- `proc_name`
- `proc_pidpath`
- `KERN_PROCARGS2`
- `host_statistics`
- `host_statistics64`
- `vm.swapusage`

进程组优先使用完整可执行文件路径作为聚合键；读取不到路径时退化为进程名称。

“可回收缓存”由 inactive、speculative 和 purgeable 页合计估算，可能与活动监视器的专有口径不同。内存压力优先读取系统 pressure level；系统不提供该值时，会根据可用页和 Swap 使用情况进行估算，并在界面中标注“估算”。

完整命令行只保存在当前内存并显示在本机界面，不写入异常历史；但命令参数本身可能包含敏感信息，截图或共享诊断信息前应检查内容。

## 当前限制

- 未读取精确 CPU/GPU 温度或风扇转速
- 未定位进程具体写入了哪个文件
- 系统或其他用户的部分进程可能因权限限制无法读取完整命令和工作目录
- PPID=1 代表进程已由 `launchd` 接管，但不必然等于泄漏，因此 repo-harness 报警同时要求实例风暴和运行时长条件
- `SIGTERM` 不能结束无权限操作的进程
- 当前工程未启用 App Sandbox；若要上架 Mac App Store，需要重新评估跨进程监控能力和权限模型

## 退出应用

关闭主窗口只会关闭窗口，菜单栏监控仍会继续。要完全退出：

- 点击菜单栏 ProcessWatch 面板中的“退出 ProcessWatch”；
- 在“设置 → 应用”中点击“退出 ProcessWatch”；
- 或按 `Command-Q`。

## 构建失败诊断

构建脚本会把完整日志保存到：

```text
build/xcodebuild.log
```

重新构建：

```bash
./scripts/build_app.sh --clean --run
```
## 1.1.3 编译兼容修复

1.1.3 不再从 Swift 直接访问 `PWProcessSample` 等 C 结构体中的下划线字段或定长字符数组。不同 Xcode/Clang 版本对这些字段的导入名称可能不同，之前可能报：

```text
value of type 'PWProcessSample' has no member 'command_line'
```

现在统一通过稳定的 C accessor API 读取，避免后续继续在 `working_directory`、CPU ticks 或内存字段上出现同类错误。升级后建议先执行：

```bash
./build.sh --clean --run
```

