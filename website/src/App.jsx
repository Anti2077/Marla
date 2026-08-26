import { useRef, useState } from "react";
import { useGSAP } from "@gsap/react";
import gsap from "gsap";
import { ScrollTrigger } from "gsap/ScrollTrigger";
import {
  ArrowDown,
  ArrowLeft,
  ArrowRight,
  Check,
  Command,
  Languages,
  ScanText,
  ShieldCheck,
  Sparkles,
} from "lucide-react";

import logoUrl from "../../Resources/Brand/PaperLantern/logo.svg";
import resultCardUrl from "../../artifacts/ui-review/task-028/markdown-final-light-760.png";
import quickInputUrl from "../../artifacts/ui-review/quick-input-0135-light.png";
import shortcutsUrl from "../../artifacts/ui-review/task-035/shortcuts-editor-light.png";
import selectionResultUrl from "../../artifacts/ui-review/task-019/result-card-light.png";
import screenshotSelectionUrl from "../../artifacts/ui-review/task-007/screenshot-magnifier-dark.png";

gsap.registerPlugin(useGSAP, ScrollTrigger);

const capabilities = [
  "划词翻译",
  "截图翻译",
  "快速输入",
  "结构化 Markdown",
  "自选翻译服务",
  "原生 macOS",
];

const storyCards = [
  {
    title: "只在你明确需要时出现",
    copy: "选中文字或框出屏幕区域，Marla 才开始工作。翻译卡片靠近原文出现，关闭后把注意力完整还给正在使用的 App。",
    icon: ScanText,
    tone: "terracotta",
  },
  {
    title: "保留内容，而不只搬运字符",
    copy: "标题、列表、引用、代码和表格可以继续作为结构化内容流入译文。完成态仍然清楚、可选择，也可复制为 Markdown。",
    icon: Languages,
    tone: "indigo",
  },
  {
    title: "隐私边界直接写在流程里",
    copy: "本机 Vision OCR 保留截图像素在设备内；只有明确选择云端 OCR 时，选中的裁剪区域才会上传。翻译服务由你配置。",
    icon: ShieldCheck,
    tone: "gold",
  },
];

const principles = [
  {
    quote: "译文应该留在阅读现场，而不是把用户带到另一扇主窗口。",
    detail: "Stay in place",
  },
  {
    quote: "精确位置不可得时，诚实地退化到附近面板，不伪装成精准覆盖。",
    detail: "Degrade honestly",
  },
  {
    quote: "一盏小灯照亮陌生语言，但不把整页变成自己的舞台。",
    detail: "Be a quiet light",
  },
];

function scrollToId(id) {
  document.getElementById(id)?.scrollIntoView({ behavior: "smooth" });
}

function DemoMedia({ poster, videoSrc }) {
  if (videoSrc) {
    return (
      <video autoPlay loop muted playsInline poster={poster} aria-label="真实 Marla App 试机演示">
        <source src={videoSrc} type="video/mp4" />
      </video>
    );
  }

  return <img src={poster} alt="" loading="lazy" />;
}

function App() {
  const root = useRef(null);
  const [activeEntry, setActiveEntry] = useState(0);
  const [principleIndex, setPrincipleIndex] = useState(0);

  useGSAP(
    () => {
      const reduceMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;

      if (reduceMotion) {
        gsap.set(".hero-reveal, .bento-card, .story-card", {
          clearProps: "all",
          opacity: 1,
          y: 0,
          scale: 1,
        });
        return;
      }

      const intro = gsap.timeline({ defaults: { ease: "power3.out" } });
      intro
        .from(".hero-reveal", {
          opacity: 0,
          y: 32,
          duration: 0.9,
          stagger: 0.09,
        })
        .from(
          ".hero-product",
          { opacity: 0, y: 48, scale: 0.96, duration: 1.1 },
          "-=0.55",
        );

      gsap.from(".bento-card", {
        opacity: 0,
        y: 36,
        scale: 0.96,
        duration: 0.7,
        stagger: 0.08,
        ease: "power3.out",
        scrollTrigger: {
          trigger: ".bento-grid",
          start: "top 78%",
        },
      });

      const desktop = gsap.matchMedia();
      desktop.add("(min-width: 960px)", () => {
        ScrollTrigger.create({
          trigger: ".story-layout",
          start: "top 112px",
          end: "bottom bottom-=80",
          pin: ".story-copy",
          pinSpacing: false,
        });

        gsap.utils.toArray(".story-card").forEach((card, index) => {
          gsap.fromTo(
            card,
            { y: 84, scale: 0.94, opacity: 0.38 },
            {
              y: 0,
              scale: 1,
              opacity: 1,
              ease: "none",
              scrollTrigger: {
                trigger: card,
                start: "top 88%",
                end: "top 42%",
                scrub: 0.8,
              },
            },
          );

          if (index < storyCards.length - 1) {
            gsap.to(card, {
              scale: 0.96,
              opacity: 0.58,
              ease: "none",
              scrollTrigger: {
                trigger: card,
                start: "bottom 48%",
                end: "bottom 18%",
                scrub: 0.8,
              },
            });
          }
        });
      });

      return () => desktop.revert();
    },
    { scope: root },
  );

  const changePrinciple = (direction) => {
    setPrincipleIndex((current) =>
      (current + direction + principles.length) % principles.length,
    );
  };

  return (
    <main ref={root} className="site-shell">
      <header className="site-nav" aria-label="主导航">
        <a className="brand-link" href="#top" aria-label="Marla 首页">
          <img src={logoUrl} alt="" width="38" height="38" />
          <span>Marla</span>
        </a>
        <nav className="nav-links" aria-label="页面导航">
          <a href="#experience">体验</a>
          <a href="#principles">原则</a>
          <a href="#privacy">隐私</a>
        </nav>
        <button className="nav-cta" type="button" onClick={() => scrollToId("experience")}>
          看它如何工作
          <ArrowDown aria-hidden="true" size={17} />
        </button>
      </header>

      <section className="hero" id="top">
        <div className="hero-copy">
          <p className="hero-kicker hero-reveal">Native translation layer for macOS</p>
          <h1 className="hero-reveal">
            Marla，原地翻译。
            <span>为 macOS 而生。</span>
          </h1>
          <p className="hero-lede hero-reveal">
            让译文出现在原文附近。读完，关掉，继续手上的事。
            一层轻巧的原生体验，不再复制、切换窗口，再费力找回刚才读到的位置。
          </p>
          <div className="hero-actions hero-reveal">
            <button className="button button-primary" type="button" onClick={() => scrollToId("experience")}>
              <Sparkles aria-hidden="true" size={18} />
              看见 Marla 工作
            </button>
            <button className="button button-secondary" type="button" onClick={() => scrollToId("principles")}>
              了解产品原则
              <ArrowRight aria-hidden="true" size={18} />
            </button>
          </div>
        </div>

        <div className="hero-product" aria-label="Marla 结构化翻译结果的真实 App 画面">
          <div className="product-halo" aria-hidden="true" />
          <img
            className="hero-screenshot"
            src={resultCardUrl}
            alt="Marla 快速输入结果窗口，译文保留标题、列表、表格、链接和代码块"
            width="1520"
            height="1224"
          />
          <div className="product-note note-left">
            <Check aria-hidden="true" size={16} />
            靠近原文
          </div>
          <div className="product-note note-right">
            <Command aria-hidden="true" size={16} />
            随叫随到
          </div>
        </div>
        <a className="hero-scroll" href="#experience" aria-label="继续浏览 Marla 产品体验">
          <span>继续</span>
          <ArrowDown aria-hidden="true" size={18} />
        </a>
      </section>

      <div className="capability-marquee" aria-label="Marla 核心能力">
        <div className="marquee-track">
          {[...capabilities, ...capabilities].map((capability, index) => (
            <span key={`${capability}-${index}`} aria-hidden={index >= capabilities.length}>
              {capability}
              <i aria-hidden="true" />
            </span>
          ))}
        </div>
      </div>

      <section className="section experience" id="experience">
        <div className="section-heading">
          <p className="eyebrow">三种入口，同一个阅读现场</p>
          <h2>翻译意图发生在哪里，Marla 就出现在哪里。</h2>
          <p>
            不需要打开一座新的工作台。选择、框选，或在需要时快速输入，结果都回到当前任务附近。
          </p>
        </div>

        <div className="entry-accordion" role="list" aria-label="Marla 的三种翻译入口">
          {[
            {
              title: "划词",
              caption: "选中文字，按下快捷键。",
              detail: "从网页、邮件、终端或聊天里触发，完整译文在原文附近流式生长。",
              image: selectionResultUrl,
              icon: Languages,
            },
            {
              title: "截图",
              caption: "框出只需要理解的部分。",
              detail: "Vision 默认在本机识别；只有明确切换云端 OCR 时才上传选中的裁剪区域。",
              image: screenshotSelectionUrl,
              icon: ScanText,
            },
            {
              title: "输入",
              caption: "没有现成原文时，直接写。",
              detail: "Quick Input 接收普通文本与结构化 Markdown，适合临时句子和短篇内容。",
              image: quickInputUrl,
              icon: Command,
            },
          ].map((entry, index) => {
            const Icon = entry.icon;
            const active = activeEntry === index;
            return (
              <article
                className={`entry-panel ${active ? "is-active" : ""}`}
                key={entry.title}
                role="listitem"
                onMouseEnter={() => setActiveEntry(index)}
              >
                <button
                  type="button"
                  className="entry-trigger"
                  aria-expanded={active}
                  onClick={() => setActiveEntry(index)}
                  onFocus={() => setActiveEntry(index)}
                >
                  <span className="entry-title">
                    <Icon aria-hidden="true" size={20} />
                    {entry.title}
                  </span>
                  <span className="entry-caption">{entry.caption}</span>
                  <ArrowRight aria-hidden="true" size={20} />
                </button>
                <div className="entry-visual">
                  <DemoMedia poster={entry.image} videoSrc={entry.video} />
                  <p>{entry.detail}</p>
                </div>
              </article>
            );
          })}
        </div>
      </section>

      <section className="section proof" aria-labelledby="proof-title">
        <div className="section-heading compact">
          <p className="eyebrow">内容仍然是内容</p>
          <h2 id="proof-title">清楚的结构，也应该被带进译文。</h2>
        </div>
        <div className="bento-grid">
          <article className="bento-card bento-wide">
            <div className="bento-copy">
              <span className="feature-icon"><Languages aria-hidden="true" size={20} /></span>
              <h3>Markdown 不是翻译前的噪音</h3>
              <p>标题、列表、引用、表格、链接和代码，在完成态继续保留阅读层级。</p>
            </div>
            <div className="bento-media">
              <img
                src={resultCardUrl}
                alt="Marla 译文中的标题、列表、表格与代码块"
                loading="lazy"
                width="1520"
                height="1224"
              />
            </div>
          </article>
          <article className="bento-card bento-half bento-dark">
            <span className="feature-icon"><Command aria-hidden="true" size={20} /></span>
            <h3>快捷键属于你</h3>
            <p>划词、截图、快速输入各自可配置，触发路径保持原生而明确。</p>
            <img src={shortcutsUrl} alt="Marla 快捷键设置" loading="lazy" />
          </article>
          <article className="bento-card bento-half bento-warm" id="privacy">
            <span className="feature-icon"><ShieldCheck aria-hidden="true" size={20} /></span>
            <h3>本机 OCR 与云端翻译，不含糊成一句“离线”</h3>
            <p>每一段数据流向都有边界：截图默认本机识别，翻译服务由用户自行配置。</p>
            <div className="privacy-path" aria-label="隐私数据流向">
              <span>选中内容</span>
              <ArrowRight aria-hidden="true" size={16} />
              <span>明确触发</span>
              <ArrowRight aria-hidden="true" size={16} />
              <span>你的 Provider</span>
            </div>
          </article>
        </div>
      </section>

      <section className="section story" aria-labelledby="story-title">
        <div className="story-layout">
          <div className="story-copy">
            <p className="eyebrow">一层翻译，而不是另一个目的地</p>
            <h2 id="story-title">从看见陌生语言，到继续手上的事。</h2>
            <p>Marla 把一次翻译压缩成短暂、可逆、在场的动作。</p>
          </div>
          <div className="story-cards">
            {storyCards.map((card, index) => {
              const Icon = card.icon;
              return (
                <article className={`story-card story-card-${index} ${card.tone}`} key={card.title}>
                  <span className="story-icon"><Icon aria-hidden="true" size={26} /></span>
                  <div>
                    <h3>{card.title}</h3>
                    <p>{card.copy}</p>
                  </div>
                  <span className="story-index" aria-hidden="true">0{index + 1}</span>
                </article>
              );
            })}
          </div>
        </div>
      </section>

      <section className="principles" id="principles" aria-labelledby="principles-title">
        <div className="principle-mark" aria-hidden="true">
          <img src={logoUrl} alt="" width="156" height="156" />
        </div>
        <div className="principle-content">
          <p className="eyebrow light">Marla 的产品原则</p>
          <h2 id="principles-title" className="sr-only">Marla 的产品原则轮播</h2>
          <blockquote key={principleIndex} aria-live="polite">
            “{principles[principleIndex].quote}”
          </blockquote>
          <p className="principle-detail">{principles[principleIndex].detail}</p>
          <div className="carousel-controls">
            <button type="button" onClick={() => changePrinciple(-1)} aria-label="上一条产品原则">
              <ArrowLeft aria-hidden="true" size={20} />
            </button>
            <span aria-hidden="true">{principleIndex + 1} / {principles.length}</span>
            <button type="button" onClick={() => changePrinciple(1)} aria-label="下一条产品原则">
              <ArrowRight aria-hidden="true" size={20} />
            </button>
          </div>
        </div>
      </section>

      <section className="closing" aria-labelledby="closing-title">
        <img src={logoUrl} alt="" width="88" height="88" />
        <p className="eyebrow">Marla is incubating in the open</p>
        <h2 id="closing-title">一盏小灯，留在阅读旁边。</h2>
        <p>
          当前仍处于未发布的孵化阶段。这一版首页先让产品方向变得可见，不把原型写成发布承诺。
        </p>
        <div className="closing-actions">
          <button className="button button-primary" type="button" onClick={() => scrollToId("experience")}>
            回看产品体验
            <ArrowRight aria-hidden="true" size={18} />
          </button>
          <a className="text-link" href="#top">回到顶部</a>
        </div>
      </section>

      <footer className="site-footer">
        <a className="brand-link" href="#top" aria-label="Marla 首页">
          <img src={logoUrl} alt="" width="32" height="32" />
          <span>Marla</span>
        </a>
        <p>Native macOS instantaneous translation layer.</p>
        <p>Incubation prototype · 2026</p>
      </footer>
    </main>
  );
}

export default App;
