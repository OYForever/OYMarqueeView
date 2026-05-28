# OYMarqueeView
基于Swift 5的轻量级跑马灯视图，可自定义Item，仿cell复用机制支持视图复用


## Swift Package Manager

在 Xcode 中通过 **File > Add Package Dependencies...** 添加仓库地址：

```
https://github.com/OYForever/OYMarqueeView.git
```

然后选择 `OYMarqueeView` 库即可。


## 新增控制能力（v1.2.0）

- `pause()`：暂停滚动
- `resume()`：继续滚动
- `stop()`：停止并清空当前内容
- `autoPauseWhenAppInactive`：App 进后台自动暂停，回前台自动恢复（默认 `true`）


## Swift 6 支持

- 已支持 Swift 6（同时兼容 Swift 5）。
- Swift Package Manager 通过 `Package.swift` 声明 `swift-tools-version: 6.0` 并支持 `.v5` / `.v6`。
- CocoaPods 通过 `s.swift_versions = ['5.0', '6.0']` 声明版本兼容性。


## Delegate 回调（v1.3.1）

- 新增 `delegate` 支持：
  - `marqueeView(_:didDisplayItemAt:)`
  - `marqueeView(_:didSelectItemAt:)`

可用于曝光统计与点击事件处理。
