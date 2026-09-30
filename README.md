# What File Is This / 这是什么文件

[English](#english) · [中文](#中文)

## English

A native macOS SwiftUI viewer for AI file-analysis results created by the “What file is this?” Finder Shortcut. It displays the result, file metadata, evidence, copy/reveal actions, and supports `.wfitresult`, JSON, plist, and Chinese segmented-text input.

### Build and install

Run `Build & Install.command`. The app is installed at `~/Applications/What File Is This.app`.

The Shortcut starts the app with `--wfit-result /path/to/result.wfitresult`; the app does not perform AI analysis itself. English and Simplified Chinese are available in the standard Settings window.

## 中文

一个轻量的原生 macOS SwiftUI 结果窗口，用来显示 “What file is this” Finder 快捷指令的 AI 文件分析结果。

- SwiftUI + AppKit，仅使用 macOS 系统框架
- SF Symbols 作为界面图标
- 使用 Finder 的真实文件图标
- 支持复制分析结果和“在访达中显示”
- 最后一个窗口关闭后自动退出，不常驻后台
- 可读取 `.wfitresult`、JSON、plist，以及中文分段文本结果

## v1.1 / App Edition v2

修复 Shortcut 运行后 App 没有收到结果、仍停留在空状态的问题。

新版不再依赖 Launch Services 把 `.wfitresult` 作为文档事件送到已经运行的 App，而是每次由 Shortcut 启动一个新的 App 实例，并通过：

```text
--wfit-result /path/to/result.wfitresult
```

直接把结果文件路径交给 App。文档打开事件仍保留作为手动双击 `.wfitresult` 的兼容入口。

## 安装

双击 `Build & Install.command`。脚本会在本机编译并安装到：

`~/Applications/What File Is This.app`

安装完成后不会自动打开空窗口。运行对应 Finder Shortcut 时才会启动 App。

## `.wfitresult` bridge 格式

```text
WFITRESULT/1
PATH_B64:<目标文件路径的 UTF-8 Base64>
RESULT_B64:<AI 最终结果的 UTF-8 Base64>
DELETE_AFTER_OPEN:1
```

App 读取完成后，仅当 `DELETE_AFTER_OPEN=1` 且结果文件位于系统临时目录时才会自动删除临时结果文件。

## 测试

安装后可以手动双击 `Samples/Example.wfitresult` 测试 UI；实际 Shortcut 使用 argv bridge，不依赖文件类型关联。
