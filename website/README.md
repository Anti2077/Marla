# Marla 官网首页原型

这是一个与原生 macOS App 隔离的 React + Vite 官网首页原型。它只呈现 Marla 当前的产品方向，不会修改原生 App，也不暗示产品已经公开发布。

## 本地运行

```sh
npm install
npm run dev
```

Vite 启动后会输出本地访问地址。页面使用正式的 Paper Lantern SVG 和审核通过的真实 App 桌面录屏；不会展示旧截图，也不会用网页动画模拟原生 App 行为。

## 验证

```sh
npm run lint
npm run build
```

构建产物会输出到 `website/dist/`。页面通过 `prefers-reduced-motion` 和 GSAP 媒体查询响应系统的“减弱动态效果”设置。

Hero、三个产品入口、Markdown Bento 和快捷键卡片目前均已接入桌面视频；Hero 与 Markdown 按项目决定共用同一份 5:4 素材。视频只在可见且激活时播放，播放/暂停按钮位于画面外的工具条内。三个入口使用三段式切换和单一 7:5 大舞台，说明文字不会覆盖录屏；移动端在 1:1 成品补齐前也按原始 7:5 比例完整显示桌面素材。Reduce Motion 默认显示 WebP 封面。完整分镜与导出规格见 [`DEMO_ASSETS.md`](DEMO_ASSETS.md)，成品目录与命名规则见 [`public/media/`](public/media/README.md)。
