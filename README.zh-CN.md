# 这是什么文件

[English](README.md)

**这是什么文件**帮助你直接在 Finder 中理解陌生文件：选中一个文件或文件夹，运行附带的快捷指令，即可获得它是什么、可能属于什么、如何打开、删除是否有风险，以及结论依据的清晰说明。

它适合查看陌生下载文件、项目文件、压缩包、媒体附属文件、研究资料、医学影像样本等。它不会修改你选中的项目。

![简体中文 DICOM 分析结果](docs/images/dicom-result-zh-Hans.png)

## 安装

1. 从发布页下载 `What File Is This.dmg`。
2. 打开它，将 **What File Is This** 拖入 **Applications（应用程序）**。
3. 先打开 App 一次；如果 macOS 询问确认，请选择“打开”。
4. 在“快捷指令”App 中导入 `What file is this?.shortcut`。

需要 macOS 27 或更高版本。

## 在 Finder 中使用

1. 在 Finder 中选中一个文件或文件夹。
2. 按住 Control 点击，选择“快速操作”，再选择“这是什么文件？”。
3. 结果窗口会立即显示，快捷指令继续准备分析。
4. 阅读分析结果、复制文本、在访达中显示原文件，或在完成后关闭窗口。

每次运行都有独立窗口。关闭最后一个窗口会退出 App。

## 调整语言

### App 界面语言

选择 **What File Is This → 设置… → Language**，然后选择 **English** 或 **简体中文**。退出并重新打开 App 后，界面和标准 macOS 菜单会统一切换。

### 分析结果语言

快捷指令的分析提示前面有一个可编辑的语言值。打开快捷指令，找到内容为 `$language$ = Chinese` 的“文本”动作，将 `Chinese` 换成所需的输出语言。

## 隐私与注意事项

- App 仅在本地显示结果，不会修改选中的文件。
- 快捷指令收集有限的本地信息并进行分析；处理敏感文件前，请先检查快捷指令中的动作。
- 分析仅供参考。医学、法律、安全和删除建议不应替代专业判断或备份。

## 构建与发布说明

项目使用原生 SwiftUI/AppKit。Finder 快捷指令通过 `whatfileisthis` URL Scheme 立即启动加载窗口，并通过仅限当前用户的本机 Unix socket 发送完成后的分析；结果仅存在内存中，不创建 `.wfitresult` 桥接文件。

### 从源码构建

```bash
swift build -c release
./Build\ \&\ Install.command
```

`Build & Install.command` 会创建 `build/What File Is This.app`、安装到 `~/Applications`、注册 URL Scheme，并为本地应用进行 ad hoc 签名。

### 制作 DMG

本项目使用配套的 [Dmg Maker](../Dmg%20Maker) 项目及其现有背景图。请在本仓库中运行：

```bash
mkdir -p dist
cd dist
../../Dmg\ Maker/dmg.sh ../build/What\ File\ Is\ This.app ../../Dmg\ Maker/Background.png
```

生成的 `What File Is This.dmg` 位于 `dist/`。

### 开发相关

- App 源码：`Sources/WhatFileIsThis/`
- 快捷指令示例与结果解析：`Samples/Example.wfitresult`、`ResultParser.swift`
- 本机结果传输端点：`/private/tmp/what-file-is-this-<uid>.sock`
- App 支持英文和简体中文。
