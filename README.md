# What File Is This

[简体中文](README.zh-CN.md)

A native macOS SwiftUI viewer for AI file-analysis results created by the “What file is this?” Finder Shortcut. It displays results, file metadata, evidence, and copy/reveal actions.

## Build and install

Run `Build & Install.command`. The app is installed at `~/Applications/What File Is This.app`.

The Shortcut starts the app with `--wfit-result`; the app does not perform AI analysis itself.

## Result bridge

The preferred input is a `.wfitresult` file passed as `--wfit-result /path/to/result.wfitresult`. It can also read JSON, plist, and Chinese segmented-text results. The `Samples/Example.wfitresult` file lets you test the UI without the Shortcut.

## Features

- Displays identity, ownership, purpose, opening guidance, deletion advice, confidence, and evidence.
- Shows real Finder file icons, metadata, Markdown emphasis, Copy Result, and Reveal in Finder.
- Supports English and Simplified Chinese in the standard Settings window.

## Privacy and limitations

The app only renders results locally and makes no network request. The Finder Shortcut or its AI service performs the analysis and determines what data is sent to the app.
