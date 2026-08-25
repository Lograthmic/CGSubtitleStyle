<div align="center">

![](assets/banner.png)

</div>

<div align="center">

[English](../README.md) | [简体中文](README.zhCN.md) | 繁體中文

</div>

<div align="center">

[![GitHub Stars](https://img.shields.io/github/stars/Lograthmic/CGSubtitleStyle?logo=github&style=flat-square)](https://github.com/Lograthmic/CGSubtitleStyle)
[![GitHub License](https://img.shields.io/github/license/Lograthmic/CGSubtitleStyle?logo=github&style=flat-square)](https://github.com/Lograthmic/CGSubtitleStyle/blob/main/LICENSE)
[![Last Commit](https://img.shields.io/github/last-commit/Lograthmic/CGSubtitleStyle?logo=github&style=flat-square)](https://github.com/Lograthmic/CGSubtitleStyle/commits/main)
[![CurseForge Version](https://img.shields.io/curseforge/v/1666199?logo=curseforge&style=flat-square)](https://www.curseforge.com/wow/addons/cg-subtitle-style)

</div>

---

自訂《魔獸世界》原生過場(CG)字幕的樣式:說話人與字幕內容分為兩行呈現,每一行都可獨立設定字體、顏色、描邊、陰影、背景與邊框。

## 使用方法

開啟設定面板:

- **ESC → 選項 → 插件 → CG Subtitle Style**,或
- 輸入 `/cgs`(或 `/cgsub`)。

### 綜合設定

| 設定 | 說明 |
| --- | --- |
| 語言 | 介面語言:自動(跟隨客戶端)、简体中文、繁體中文、English |
| 啟用字幕樣式 | 總開關 |
| 尊重遊戲內字幕設定 | 遊戲內「字幕」選項關閉時不顯示字幕 |
| 整體透明度 | 整個字幕區塊的透明度 |
| 錨點位置 | 畫面錨點:中央、頂部、底部、四角等 |
| 水平 / 垂直偏移 | 相對錨點的位置偏移 |
| 字幕最大寬度 | 每行字幕的最大寬度 |
| 說話人與內容間距 | 說話人行與內容行之間的間距 |

### 說話人 / 字幕內容索引標籤

每一行都有相同的五個索引標籤:

| 索引標籤 | 選項 |
| --- | --- |
| 文字 | 字體、字號、文字顏色 |
| 描邊 | 樣式(無 / 細 / 粗 / 自訂)、顏色、自訂寬度 |
| 陰影 | 開關、陰影顏色 |
| 背景 | 開關、顏色、不透明度 |
| 邊框 | 開關、樣式(實心 / 圓角提示框 / 對話框)、顏色、粗細、內邊距 |

### 主題

- **儲存為新主題** —— 將目前設定以指定名稱儲存。
- **刪除主題** —— 刪除目前主題(預設主題不可刪除)。
- **匯出主題** —— 產生描述目前主題的文字片段。
- **匯入主題** —— 貼上分享的文字片段,點擊「匯入主題」。
- **重設目前主題** —— 恢復預設設定。

匯出的主題文字是純文字(Base64)。可以分享給朋友,也可以直接匯入他人的主題。

## 指令清單

| 指令 | 說明 |
| --- | --- |
| `/cgs` | 開啟設定面板 |
| `/cgs help` | 查看指令說明 |
| `/cgs preview` | 切換字幕預覽 |
| `/cgs reset` | 重設目前主題 |
| `/cgs on` / `/cgs off` | 啟用 / 停用字幕樣式 |
| `/cgs theme <主題名>` | 套用已儲存主題 |
| `/cgs themes` | 列出全部已儲存主題 |
| `/cgs save <主題名>` | 將目前設定儲存為新主題 |
| `/cgs delete <主題名>` | 刪除主題 |
| `/cgs export` | 以文字匯出目前主題 |
| `/cgs import <文字>` | 從文字匯入主題 |
| `/cgs language <auto\|zhCN\|zhTW\|enUS>` | 設定介面語言 |

## 相容性

- **正式伺服器** v12.1.0 —— `## Interface: 120100`。

## 免責聲明

本插件與暴雪娛樂無關,也未獲得其認可。World of Warcraft 是暴雪娛樂有限公司的註冊商標。