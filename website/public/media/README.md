# Marla 官网素材目录

这个目录只存放已经审核通过、可以直接用于 Marla 官网的成品素材。原始录屏、剪辑工程、淘汰片段和私下审核用的导出文件必须保留在仓库外。

## 目录结构

```text
desktop/          审核通过的桌面版 MP4
mobile/           审核通过的 1:1 移动版 MP4
posters/desktop/  桌面版 WebP 封面
posters/mobile/   移动版 WebP 封面
```

## 正式素材命名规则

```text
marla-{scene}--{variant}-{ratio}.{ext}
```

允许使用的场景名称：

- `hero-in-place`：Hero 原地翻译。
- `selection`：划词翻译。
- `screenshot`：截图翻译。
- `quick-input`：快速输入。
- `structured-markdown`：仅在未来拆分独立 Markdown 素材时使用；当前 Markdown 展示位复用 `hero-in-place`。
- `shortcut-settings`：快捷键设置动画。

允许使用的版本和比例：

- `desktop-5x4`
- `desktop-7x5`
- `mobile-1x1`

允许使用的扩展名：

- `mp4`：视频。
- `webp`：封面。

示例：

```text
desktop/marla-hero-in-place--desktop-5x4.mp4
desktop/marla-shortcut-settings--desktop-7x5.mp4
mobile/marla-selection--mobile-1x1.mp4
posters/desktop/marla-shortcut-settings--desktop-7x5.webp
posters/mobile/marla-selection--mobile-1x1.webp
```

每个 MP4 必须有一个主文件名完全相同的 WebP 封面，并放入对应版本的 `posters/` 目录。

## 当前桌面成品

```text
desktop/marla-hero-in-place--desktop-5x4.mp4
desktop/marla-selection--desktop-7x5.mp4
desktop/marla-screenshot--desktop-7x5.mp4
desktop/marla-quick-input--desktop-7x5.mp4
desktop/marla-shortcut-settings--desktop-7x5.mp4
```

对应的 5 个同名 WebP 位于 `posters/desktop/`。Hero 和结构化 Markdown 两个展示位共用 `marla-hero-in-place--desktop-5x4`，因此没有重复的 Markdown 成品文件。

## 原始录屏命名规则

正式备份中的原始录屏必须保留在本目录和 Git 仓库之外。本轮用于转换的本机母版暂存在 Git 忽略的 `website/.recording-masters/`，不会进入网页构建或提交：

```text
marla-{scene}--raw-{YYYYMMDD}-take-{NN}.mov
```

示例：`marla-shortcut-settings--raw-20260901-take-03.mov`。

正式素材文件名不要使用空格、中文、`final`、`new`、`latest` 或随意的版本后缀。完整分镜、录制步骤和导出规格见 [`website/DEMO_ASSETS.md`](../../DEMO_ASSETS.md)。
