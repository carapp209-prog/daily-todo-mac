# 每日待办 · Daily Todo for Mac

一个用 SwiftUI 做的 macOS 桌面应用。可以快速添加今天的任务，提前规划明天，以及按日期回顾完成记录。

- 勾选完成后，任务文字会出现荧光笔效果。
- 输入 `9:00-9:30`，应用会算出并显示 `9:00-9:30 30min`。
- 「今天」右上角可以自由书写。任务与文字均保存在本机。

## 项目过程

从网页版开始试用，随后改为独立的 Mac 应用。根据实际使用调整了添加临时任务的入口、用时记录方式和自由书写区。我负责定义需求、比较交互方案和实际试用，与 Codex 协作实现。

## 在 Mac 上构建

在装有 Xcode 命令行工具的 Mac 上，从仓库目录执行以下命令。

```sh
mkdir -p 'build/每日待办.app/Contents/MacOS'
cp Info.plist 'build/每日待办.app/Contents/'
swiftc -parse-as-library main.swift -o 'build/每日待办.app/Contents/MacOS/DailyTodo'
codesign --force --sign - 'build/每日待办.app'
open 'build/每日待办.app'
```
