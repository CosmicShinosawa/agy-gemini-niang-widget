# Antigravity 的 Gemini 娘挂件

<img src="gemini-widget.png" alt="紫发猫耳、金紫异色瞳的 Gemini 娘挂件" width="180">

Gemini 娘原角色形象由 **ZipZipPipe** 创作。挂件使用的 Q 版插画来自网络，画师和首发页面待考。[ZipZipPipe 的 B 站空间](https://space.bilibili.com/4168597) · [素材声明](ASSETS.md)

Windows 上双击 `预览挂件.cmd`。点角色打开第一页，再点气泡依次翻页、收起。第一页显示 Gemini 五小时、每周和 Gemini 4 Argon 每周额度，第二页显示 Claude/GPT 五小时和每周额度，第三页显示互动语录。挂件跟随 Antigravity 窗口，切换焦点时留在原位，最小化时一起隐藏。右键可编辑语录与气泡顺序、调节大小、导入角色图片和短 WAV，或开启音乐律动和登录自启。

## 额度从哪里来

反重力桌面版运行且已登录时，挂件直接向它的本机额度接口查询各组剩余百分比及重置时刻，每分钟自动刷新一次。打开额度气泡或点击 ↻ 也会刷新。此方式无需安装 CrossPet 或 agy CLI，设置页可以关闭。重置时刻按本机时区显示，悬停气泡可查看来源和读取时间。

如果后台读取不可用，打开 Antigravity 的 **Settings → Models** 可从页面读取百分比。此时没有精确重置时刻的项目会显示“未提供重置时间”。两种来源都不可用时，气泡保留上次快照并标注“上次”。

挂件偏好、额度快照和自定义图片保存在当前用户的 `%LOCALAPPDATA%\GeminiNiangWidget`。安装目录中的 `antigravity-plugin` 是可单独使用的 Antigravity 插件，内含只读额度 MCP 和回复结束的 Stop 钩子。按官方的本地安装方式，把该目录放入用户插件目录后，新会话即可发现组件。MCP 返回快照和观察时间。回复结束提醒另由挂件右键菜单开关控制。[Google 插件安装说明](https://antigravity.google/docs/plugins)

## 致谢与许可

- Windows 窗口、命中测试、拖动、动画、音频、图库、音乐律动、语录、颜色和 MCP 协议处理改编自 **GPT-Niang 1.3.5**。许可原文及版权声明在 `licenses/GPT-Niang-MIT.txt`。[上游项目](https://github.com/T7moris/GPT-Niang)
- 气泡顺序、加权分支、图片气泡、吸附和翻转参考 **dsh-whale-widget 0.4.2**。其代码采用 MIT，原版图片、动图、图标、音效另行授权。本项目采用新合成的按压及松开音效。[上游项目和素材说明](https://github.com/MeteorNOX/DeepSeek-Balance-Whale-Widget/blob/main/PROVENANCE.md)
- 感谢 **ZipZipPipe** 创作 Gemini 娘原形象。角色设定的许可、Q 版插画的出处情况及加工说明详见素材声明。项目代码采用 MIT 许可。[素材声明](ASSETS.md) · [代码许可证](LICENSE)

自定义气泡支持额度、语录、静态图、GIF 和逐行字体及颜色，可按顺序或组内权重播放。DeepSeek 钱包余额、峰谷计价和逐轮账单属于 DSH 的账户数据。本移植版的额度气泡显示 Antigravity 公开给当前用户的读数。多币种账单和原项目发布渠道的自动更新未接入本地版本。
