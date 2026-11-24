# Antigravity 的 Gemini 娘挂件

本挂件目前仅支持 **Windows 上的 Antigravity 桌面客户端**。Antigravity IDE（包括 Windows 版）及其他平台均未适配。

**[下载 Windows 安装器 · GeminiNiang-Setup.exe](https://github.com/CosmicShinosawa/agy-gemini-niang-widget/releases/latest/download/GeminiNiang-Setup.exe)**

1. 点击上方链接。如果你已经在 GitHub 正式版页面，展开 **Assets**，只下载 **`GeminiNiang-Setup.exe`** 即可。
2. 双击下载好的文件，点 **「确定」**。安装器会自动装好挂件和 Antigravity 配套插件，保留已有语录和设置。
3. 安装完成后挂件会自动启动。打开并登录 Antigravity，点击窗口右下角的 Gemini 娘即可查看额度。如果 Antigravity 已经打开，重新启动它即可加载 Customizations 中的配套插件。

从 **v0.2.4** 起，首次使用会默认开启「登录后随反重力启动」。登录 Windows 后打开 Antigravity，挂件就会跟着出现。右键点击挂件可开关此项。从 v0.2.3 或更早版本升级会保留原来的设置；之前未开启的用户，可以在右键菜单手动勾选。

安装器不会创建开始菜单快捷方式。以后手动退出挂件后，可以到安装完成提示给出的目录双击 `预览挂件.cmd`。ZIP 和 JSON 供自动更新使用。[查看正式版及全部文件](https://github.com/CosmicShinosawa/agy-gemini-niang-widget/releases/latest)

<img src="gemini-widget.png" alt="紫发猫耳、金紫异色瞳的 Gemini 娘挂件" width="180">

Gemini 娘是 **ZipZipPipe** 创作的同人角色。该角色形象及本挂件与 Google 官方无关，均未获得 Google 官方认可或授权。挂件使用的 Q 版插画来自网络，由 AI 依照该角色形象改编而成。这张图的制作者、首发页面及公开分发许可仍待确认。[ZipZipPipe 的 B 站空间](https://space.bilibili.com/4168597) · [素材声明](ASSETS.md)

点角色打开第一页，再点气泡依次翻页、收起。额度气泡按桌面客户端实际返回的模型分组和周期分页，每页最多三行。常见 Pro 账号先看 Gemini（5 小时、每周），再看 Claude/GPT（5 小时、每周）；若账号返回其他分组或周期，也会按分组自动分页显示。看完额度后进入下一项，默认是互动语录。挂件跟随 Antigravity 窗口，切换焦点时留在原位，最小化时一起隐藏。右键可编辑语录与气泡顺序、调节大小、导入角色图片和短 WAV，或开启音乐律动和登录自启。

## 额度从哪里来

我自己是 **Google AI Pro 付费用户**，目前只用自己的账号实测过额度显示。其他套餐和 Jio 等订阅渠道暂时没有账号可供实测。如果挂件少了一组额度、周期不对，或重置时间与 Antigravity 的 **Settings → Models** 不一致，欢迎说明你使用的套餐、订阅渠道，以及具体哪一项有差异。[提交 Issue](https://github.com/CosmicShinosawa/agy-gemini-niang-widget/issues/new)

反重力桌面版运行且已登录时，挂件直接向它的本机额度接口查询各组剩余百分比及重置时刻，每分钟自动刷新一次。打开额度气泡或点击 ↻ 也会刷新。此方式无需安装 agy CLI，设置页可以关闭。重置时刻按本机时区显示，悬停气泡可查看来源和读取时间。

如果后台读取不可用，打开 Antigravity 的 **Settings → Models** 可从页面读取百分比。此时没有精确重置时刻的项目会显示“未提供重置时间”。两种来源都不可用时，气泡保留上次快照并标注“上次”。

挂件偏好、额度快照和自定义图片保存在当前用户的 `%LOCALAPPDATA%\GeminiNiangWidget`。安装目录中的 `antigravity-plugin` 是可单独使用的 Antigravity 插件，内含只读额度 MCP 和回复结束的 Stop 钩子。按官方的本地安装方式，把该目录放入用户插件目录后，新会话即可发现组件。MCP 返回快照和观察时间。回复结束提醒另由挂件右键菜单开关控制。[Google 插件安装说明](https://antigravity.google/docs/plugins)

## 更新与手动安装

需要手动安装时，可下载 `gemini-niang-widget.zip`，解压到固定目录并双击 `预览挂件.cmd`，再将 `antigravity-plugin` 的内容复制到 `%USERPROFILE%\.gemini\config\plugins\gemini-niang\`。使用上方 EXE 安装器时，这些步骤会自动完成。配套插件的只读额度 MCP 和回复结束提醒需要本机有 Node.js，桌面挂件的额度气泡可直接使用。

从 0.2.0 起，右键挂件 →「版本与更新」可以检查更新，也可开启「每天自动检查并安装」。自动更新默认关闭。新版从本仓库正式发布页下载，通过 SHA-256 校验和启动自检后即可使用。从 0.2.1 起，下载就绪后可在「版本与更新」中点击「立即重启并更新」。也可以继续使用当前版本，等下次启动时切换。已安装的配套插件随挂件更新。各版本安装在个人数据目录的 `versions` 子目录。若需要回到手动下载的版本，退出挂件、移除个人数据目录的 `active-version.txt`，再启动原目录里的挂件。0.1.0 用户首次升级需要手动下载。

在「声音与点击」中可选原版加响、星铃、软弹果冻，或导入自己的 WAV。在「编辑我的语录」中点「恢复内置语录」可切换到本版的 45 条台词。

### Antigravity 兼容性

2026-11-24 在 Windows 桌面版 Antigravity **2.34.0** 上实测，Gemini 4 Argon 已并入常规 Gemini 模型额度池，本机额度接口返回 Gemini（5 小时、每周）和 Claude/GPT（5 小时、每周）共四项额度。配套插件遵循公开的插件清单格式；后台额度读取依赖桌面版的本机接口。宿主升级可能改变接口字段或窗口行为。若后台源失效，可打开 Settings → Models 后查看气泡的读取来源及时间，判断是否已切换至设置页或沿用旧快照。

## 致谢与许可

本挂件改编自 Codex 的 **GPT-Niang** 和 DeepSeek Harness 的 **dsh-whale-widget**。维护者 **CosmicShinosawa** 最初在 **GPT-6.2 Astra** 的协助下，将两款挂件的功能移植到 Antigravity，接入本机额度读取，并按模型分组展示额度；后续由 **Gemini 4 Neon** 接续维护，完成 v0.2.7 的「立即重启并更新」交接与底部边缘吸附全链路验收、正式版发布、仓库更名及新版宣传素材制作。仓库及挂件发布包均未收录 Google、OpenAI 等公司的闭源商业代码、非公开专有源码或从其产品中提取的专有二进制资产。[开发与分发声明](ASSETS.md#开发与分发声明)

- Windows 窗口、命中测试、拖动、动画、音频、图库、音乐律动、语录、颜色和 MCP 协议处理改编自 **GPT-Niang 1.3.5**。许可原文及版权声明在 `licenses/GPT-Niang-MIT.txt`。[上游项目](https://github.com/T7moris/GPT-Niang)
- 气泡顺序、加权分支、图片气泡、吸附和翻转参考 **dsh-whale-widget 0.4.2**。其代码采用 MIT，原版图片、动图、图标、音效另行授权。本项目采用新合成的按压及松开音效。[上游仓库 DeepSeek-Balance-Whale-Widget](https://github.com/MeteorNOX/DeepSeek-Balance-Whale-Widget) · [上游素材说明](https://github.com/MeteorNOX/DeepSeek-Balance-Whale-Widget/blob/main/PROVENANCE.md)
- 感谢 **ZipZipPipe** 创作 Gemini 娘原形象。角色设定的许可、Q 版插画的出处情况及加工说明详见素材声明。项目代码采用 MIT 许可。[素材声明](ASSETS.md) · [代码许可证](LICENSE)

自定义气泡支持额度、语录、静态图、GIF 和逐行字体及颜色，可按顺序或组内权重播放。DeepSeek 钱包余额、峰谷计价和逐轮账单属于 DSH 的账户数据。本移植版的额度气泡显示 Antigravity 公开给当前用户的读数。多币种账单和原项目发布渠道的自动更新未接入本地版本。
