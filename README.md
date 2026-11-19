# 媒体放大技能包 · Media Upscale Skills

两套本机 AI 放大能力，打包成一个小工具包，交给任意 AI 工具/新电脑即可部署使用：

| 技能 | 用途 | 触发词 |
|---|---|---|
| **upscayl-batch** | 图片放大（阿普升图），固定 2 倍 PNG 无损 | 放大图片 / Upscayl / 阿普升图 / 批量放大 |
| **topaz-video-x4** | 视频放大（Topaz），1080P / 2K / 4K 三档或 4 倍 | Topaz 放大 / 视频超分 / 出 4K / 视频 4 倍 |

> 包里**只有脚本和文档**，不含软件本体和 AI 模型（几个 GB）。部署机需要自己装好 Upscayl 桌面版和 Topaz Video AI，并用 `check-env.ps1` 自检。

---

## 1. 目录内容

```
media-upscale-skills/
├── README.md                  ← 本文件（人看的总说明）
├── HANDOFF.md                 ← 给其他 AI 工具的交接说明（部署步骤+踩坑）
├── check-env.ps1              ← 环境自检：软件/模型/显卡是否齐全
├── set-env.example.ps1        ← 非标准安装路径时，环境变量配置样例
├── upscayl-batch/
│   ├── SKILL.md               ← AI 工具读的触发说明
│   ├── upscayl-batch.ps1      ← 图片批量放大（PowerShell，推荐 Windows）
│   └── upscayl-batch.sh       ← 图片批量放大（Git Bash 版）
└── topaz-video-x4/
    ├── SKILL.md               ← AI 工具读的触发说明
    ├── topaz-video-x4.ps1     ← 视频放大主脚本
    └── topaz-video-x4.bat     ← 拖拽入口：把视频拖上去出三档
```

## 2. 三步部署

1. **装软件**：部署机安装 Upscayl 桌面版 + Topaz Video AI（含 Proteus `prob-4` 模型），并确保 NVIDIA 显卡驱动正常。
2. **自检**：在本目录运行 `powershell -ExecutionPolicy Bypass -File check-env.ps1`，四项全 `OK` 才能用；`MISS` 的按 HANDOFF.md 排查。
3. **接入 AI 工具**：把 `upscayl-batch/` 和 `topaz-video-x4/` 两个文件夹放进该工具的技能目录（如 Claude/Codex 的 `skills/`），AI 读里面的 `SKILL.md` 即会自动触发。

非标准安装路径（软件不在默认盘）不用改脚本，设环境变量即可，见 `set-env.example.ps1`。

## 3. 用法速查

图片放大（先单张测，再批量）：
```powershell
powershell -ExecutionPolicy Bypass -File upscayl-batch\upscayl-batch.ps1 -InputDir "图片文件夹"
# 指定输出目录、2 个并行：
powershell -ExecutionPolicy Bypass -File upscayl-batch\upscayl-batch.ps1 -InputDir "输入" -OutputDir "输出" -Workers 2
```

视频放大：
```powershell
powershell -ExecutionPolicy Bypass -File topaz-video-x4\topaz-video-x4.ps1 -Preset all "视频.mp4"
# 单档：-Preset 1080p / 2k / 4k；4 倍：-Preset x4
```
人手动用：直接把视频拖到 `topaz-video-x4.bat` 上，默认出三档。

## 4. 固定规则（已实测，别改）

- 图片：**2 倍 / PNG 压缩 0 无损 / ultrasharp-4x 模型 / TTA 关 / GPU 0**；单张循环比整目录喂更快。
- 视频三档：**1080P=1890×1080、2K=2520×1440、4K=3780×2160**（不是 1920/2560/3840）；模型 `prob-4`；环境变量必须是 `TVAI_MODEL_DIR`；宽或高 >4096 用 HEVC `main`，否则 H.264 `high`。

## 5. 下载 / 更新

GitHub 仓库：`https://github.com/k88sxk55zd-lang/media-upscale-skills`
- 下载整个包：仓库页面 → Code → Download ZIP
- 单文件：`https://raw.githubusercontent.com/k88sxk55zd-lang/media-upscale-skills/main/<文件路径>`

## 6. 更多

部署细节、全部踩坑、验证记录见 `HANDOFF.md`。本机实测基线见 HANDOFF 尾部「已验证记录」。
