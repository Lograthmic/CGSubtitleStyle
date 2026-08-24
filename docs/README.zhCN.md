# CG 字幕样式 (CG Subtitle Style)

[![CurseForge](https://img.shields.io/badge/CurseForge-black?logo=curseforge&logoColor=white)](https://www.curseforge.com/wow/addons/cg-subtitle-style) [![GitHub](https://img.shields.io/badge/GitHub-181717?logo=github&logoColor=white)](https://github.com/Lograthmic/CGSubtitleStyle)

[English](../README.md) | 中文 | [繁體中文](README.zhCN.md)

---

自定义魔兽世界原生过场(CG)字幕的样式:说话人与字幕内容分为两行渲染,每行都可以独立定制字体、颜色、描边、阴影、背景与边框。

## 使用方法

打开设置面板:

- **ESC → 选项 → 插件 → CG Subtitle Style**,或
- 输入 `/cgs`(或 `/cgsub`)。

### 综合设置

| 设置 | 说明 |
| --- | --- |
| 语言 | 界面语言:自动(跟随客户端)、简体中文、繁體中文、English |
| 启用字幕样式 | 总开关 |
| 尊重游戏内字幕设置 | 游戏内“字幕”选项关闭时不显示字幕 |
| 整体透明度 | 整个字幕块的透明度 |
| 锚点位置 | 屏幕锚点:中央、顶部、底部、四角等 |
| 水平 / 垂直偏移 | 相对锚点的位置偏移 |
| 字幕最大宽度 | 每行字幕的最大宽度 |
| 说话人与内容间距 | 说话人行与内容行之间的间距 |

### 说话人 / 字幕内容选项卡

每行都有相同的五个选项卡:

| 选项卡 | 选项 |
| --- | --- |
| 文字 | 字体、字号、文字颜色 |
| 描边 | 样式(无 / 细 / 粗 / 自定义)、颜色、自定义宽度 |
| 阴影 | 开关、阴影颜色 |
| 背景 | 开关、颜色、不透明度 |
| 边框 | 开关、样式(实心 / 圆角提示框 / 对话框)、颜色、粗细、内边距 |

### 主题

- **保存为新主题** —— 将当前设置以指定名称保存。
- **删除主题** —— 删除当前主题(默认主题不可删除)。
- **导出主题** —— 生成描述当前主题的文本片段。
- **导入主题** —— 粘贴分享的文本片段,点击“导入主题”。
- **重置当前主题** —— 恢复默认设置。

导出的主题文本是纯文本(Base64)。可以分享给朋友,也可以直接导入他人的主题。

## 命令列表

| 命令 | 说明 |
| --- | --- |
| `/cgs` | 打开设置面板 |
| `/cgs help` | 查看命令帮助 |
| `/cgs preview` | 切换字幕预览 |
| `/cgs reset` | 重置当前主题 |
| `/cgs on` / `/cgs off` | 启用 / 停用字幕样式 |
| `/cgs theme <主题名>` | 应用已保存主题 |
| `/cgs themes` | 列出全部已保存主题 |
| `/cgs save <主题名>` | 将当前设置保存为新主题 |
| `/cgs delete <主题名>` | 删除主题 |
| `/cgs export` | 以文本导出当前主题 |
| `/cgs import <文本>` | 从文本导入主题 |
| `/cgs language <auto\|zhCN\|zhTW\|enUS>` | 设置界面语言 |

## 兼容性

- **正式服** v12.0.1 —— `## Interface: 120001`。

## 免责声明

本插件与暴雪娱乐无关,也未获得其认可。World of Warcraft 是暴雪娱乐有限公司的注册商标。