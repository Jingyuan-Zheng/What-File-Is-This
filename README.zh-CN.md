# 这是什么文件

[English](README.md)

原生 macOS SwiftUI 查看器，用于展示“这是什么文件”Finder 快捷指令生成的 AI 文件分析结果。它显示结论、文件元数据、证据，并支持复制和在 Finder 中显示。

## 构建与安装

运行 `Build & Install.command`，应用会安装到 `~/Applications/What File Is This.app`。

快捷指令会使用 `--wfit-result` 启动 App；应用本身不执行 AI 分析。

## 使用方法

1. 首次运行 `Build & Install.command`。
2. 将 `What file is this?.shortcut` 导入快捷指令，并在 Finder 中对选中的文件运行它。
3. 快捷指令会写入结果桥接文件并自动打开查看器。
4. 阅读分析、复制结果或在 Finder 中显示文件。也可双击 `Samples/Example.wfitresult`，无需快捷指令即可测试 UI。

## 结果桥接格式

首选输入是通过 `--wfit-result /path/to/result.wfitresult` 传入的 `.wfitresult` 文件；应用也可读取 JSON、plist 和中文分段文本。`Samples/Example.wfitresult` 可在不运行快捷指令时测试 UI。

## 功能

- 展示文件身份、归属、用途、打开方式、删除建议、可信度和证据。
- 显示真实 Finder 图标、元数据、Markdown 强调格式，并提供复制结果和在 Finder 中显示操作。
- 标准设置窗口支持英文和简体中文。

## 隐私与限制

应用只在本地渲染结果，不发起网络请求。Finder 快捷指令或其 AI 服务负责分析，并决定传给应用的数据。
