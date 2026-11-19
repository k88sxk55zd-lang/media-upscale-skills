# 交接文档 · 媒体放大技能包（给其他 AI 工具）

> 面向：任意 AI 编码工具（Claude Code / Codex / WorkBuddy / Qoder / Cursor 等）或新电脑。
> 目标：读完本文即可完成部署、验证、调用，不需要问原作者。
> 事实等级：本文所有「固定值」与「踩坑」均为原机 2026-07 ~ 2026-09 实跑验证，非网上推测。

---

## 0. 一句话结论

两套纯命令行放大能力，包里只有脚本+文档（<100KB）。**软件本体和 AI 模型不随包分发**——部署机必须先装好 Upscayl 桌面版和 Topaz Video AI，脚本负责调用它们。脚本已做「环境变量 → 自动探测 → 默认路径」三级路径解析，换机器一般零改动。

---

## 1. 依赖清单（部署机必须满足）

| 依赖 | 用途 | 自检方式 |
|---|---|---|
| Windows + PowerShell 5.1 或 7 | 跑 `.ps1` | `powershell $PSVersionTable.PSVersion` |
| Upscayl 桌面版（含 `upscayl-bin.exe` 和 `resources/models`） | 图片放大 | 自检脚本第 1 段 |
| Topaz Video AI 6.x（自带 `ffmpeg.exe`/`ffprobe.exe` + `prob-4` 模型） | 视频放大 | 自检脚本第 2 段 |
| NVIDIA 显卡 + 驱动（原机 RTX 3070 Ti） | 两者都用 GPU（Vulkan / NVENC） | `nvidia-smi` |

**没有这些软件时**：先装软件，不要试图用脚本本身替代——脚本只是 CLI 封装，不含推理引擎和模型权重。

---

## 2. 部署步骤（5 步）

1. 下载本包并解压到任意目录（建议无中文、无空格路径，如 `C:\tools\media-upscale-skills`）。
2. 运行自检：
   ```powershell
   cd C:\tools\media-upscale-skills
   powershell -ExecutionPolicy Bypass -File check-env.ps1
   ```
   目标：Upscayl 段、Topaz 段、GPU 段全部 `OK`。
3. 若有 `MISS`：
   - 软件装在非标准盘 → 复制 `set-env.example.ps1` 为 `set-env.ps1`，按注释取消需要行的注释、填真实路径，每次开新 shell 先 `. .\set-env.ps1`（或在系统环境变量里永久设置）。
   - 模型缺失 → 在对应软件里确认模型已下载（Topaz 的 `prob-4.json`、Upscayl 的 `ultrasharp-4x`）。
4. 接入 AI 工具：把 `upscayl-batch/` 和 `topaz-video-x4/` 整个文件夹复制到该工具的技能目录（各工具不同，通常是 `~/.claude/skills`、`~/.codex/skills` 或工作区 `skills/`）。每个技能靠自身 `SKILL.md` 的 frontmatter（`name` / `description`）被识别和触发。
5. 冒烟测试：图片用一个只有 1 张小图的文件夹跑一次；视频用一段几秒的短视频跑 `-Preset 1080p`，确认按固定分辨率出片。

---

## 3. 两套技能的调用契约

### 3.1 upscayl-batch（图片）

```powershell
powershell -ExecutionPolicy Bypass -File upscayl-batch\upscayl-batch.ps1 `
  -InputDir "输入文件夹" [-OutputDir "输出文件夹"] [-Workers 2]
```
- 支持 png/jpg/jpeg/webp 输入，统一输出 `.png`。
- 默认输出到 `输入文件夹\upscaled_2x`；输出目录不存在会自动建。
- **断点续跑**：输出里已有同名 png 就跳过，中断后重跑不重复劳动。
- `-Workers N` 并行张数（默认 2）。
- 路径解析优先级：`-Exe`/`-Models` 参数 > 环境变量 `UPSCAYL_EXE`/`UPSCAYL_MODELS` > 自动探测常见盘符和默认安装路径。
- Git Bash 用户可用 `.sh` 版：`bash upscayl-batch.sh "输入" ["输出"]`，同样读上述环境变量。

### 3.2 topaz-video-x4（视频）

```powershell
powershell -ExecutionPolicy Bypass -File topaz-video-x4\topaz-video-x4.ps1 `
  -Preset all|1080p|2k|4k|x4 "视频1.mp4" "视频2.mp4"
```
- `-Preset all`（默认）= 一次出 1080P + 2K + 4K 三份；单档用对应名字；`x4` = 源宽高各乘 4。
- 输出落在源视频同目录，文件名加后缀 `_1080p` / `_2k` / `_4k` / `_x4`。
- AI 自动调用**不要**加 `-WaitAtEnd`（会卡住等回车）；只有 `.bat` 拖拽入口才加。
- 路径解析优先级：环境变量 `TOPAZ_HOME`/`TOPAZ_MODEL_DIR`/`TOPAZ_MODEL` > 自动探测默认安装路径。
- 人手动使用：把视频拖到 `topaz-video-x4.bat` 上即可出三档。
- 成功判据：脚本打印 `RESULT_PATH=...`，且用 ffprobe 读回的宽高与期望档位完全一致。

---

## 4. 固定规则（不可擅自改，已实测）

**图片**：2 倍 / PNG 压缩 0（无损）/ `ultrasharp-4x` / TTA 关 / GPU id 0。单张循环调用比 `-i 文件夹` 整目录喂更快（原机实测 63s vs 98s，同 3 张图）。

**视频**：
- 三档分辨率 **1890×1080、2520×1440、3780×2160**（按源片 7:4 比例定，**不是** 1920/2560/3840）。
- 模型 `prob-4`（Topaz 自带 Proteus）；`download=0`（只用本机权重）。
- 环境变量名必须是 **`TVAI_MODEL_DIR`**（脚本内部已设好）；写成 `TOPAZ_VIDEO_AI_MODELS`/`TOPAZ_MODELS_DIR` 会报 `Model not found: prob-4`。
- 编码：输出宽或高 ≤4096 用 `h264_nvenc -profile:v high`；4097~8192 用 `hevc_nvenc -profile:v main`（HEVC 不能写 `high`）；>8192 跳过。
- 声音 `-c:a copy` 原样拷贝。

---

## 5. 踩坑清单（按命中频率排序，接手前必读）

**图片线**
1. **盘符搞混**：Upscayl 常在 F 盘，图片在 C 盘，传路径时确认盘符。
2. **中文/空格/括号路径必须加双引号**，否则 shell 解析失败。
3. **别重装、别从 GitHub 下 Upscayl**：复用本机已装桌面版的 `upscayl-bin.exe` 即可。
4. **参数名版本差异**：`--help` 里倍数可能显示 `-z`，实际用 `-s` 正常，以本地 `--help` 为准。
5. **PowerShell .ps1 编码**：含中文的脚本必须 UTF-8 **带 BOM**，否则 5.1 按 GBK 解码乱码甚至报错。本包脚本源码刻意保持纯 ASCII（中文目录名用 `[char]` 码点拼），对编码零依赖——改动时请保持这一点。
6. **PowerShell job 传参**：`Start-Job` 里用 `$using:` 传对象集合取 `.BaseName` 会取空，输出变 `.png` 互相覆盖。本包改为传**字符串路径数组** + `[IO.Path]::GetFileNameWithoutExtension()`，已规避。
7. **估时长前先测显存占用**：`nvidia-smi --query-gpu=utilization.gpu,memory.used`。GPU 空闲约 18s/张（2752×1536→2x），显存被挤占会劣化到 42→109s/张，差 6 倍。
8. **整批喂目录前先筛源尺寸**：目标 2 倍时，目录里已达标的图会被二次放大成 4 倍，既慢又废。脚本断点续跑只看输出目录，不认源目录里的达标文件，需预先筛掉。

**视频线**
9. **环境变量名写错 = 找不到模型**（最高频），只认 `TVAI_MODEL_DIR`。
10. 必须用 **Topaz 自带 ffmpeg**，系统 ffmpeg 没有 `tvai_up` 滤镜。
11. 指定分辨率用 `scale=0` + 写死宽高；4 倍用 `scale=4` + 写死 4 倍宽高。
12. HEVC 误写 `-profile:v high` 会先报错，容易误判成模型坏。
13. 三档是 1890/2520/3780，别"顺手"改成整数 1920/2560/3840。

---

## 6. 已验证记录（原机基线，供回归对照）

- 日期：2026-07-24（图片）、2026-09-01（视频）。
- 图片：3 张同批，单张循环 63s vs 目录批量 98s；单张 2400×1792→4800×3584 约 21s（RTX 3070 Ti）；2752×1536→2x 空闲 16.9~18.1s/张。
- 视频源片 1344×768 / 24fps / 10.14s：1080P 1890×1080 约 20MB；2K 2520×1440 约 34MB；4K 3780×2160 约 78MB；4 倍 5376×3072 HEVC 约 137MB；时长均 10.144s。
- 交接日期：2026-11-19。本包脚本相对原机版本唯一改动 = 路径解析通用化（三级解析）+ 源码纯 ASCII 化 + bat 路径改相对；核心调用参数与执行循环保持原样，本机自检与冒烟测试通过。

## 7. 不要做的事

- 不要把软件本体、模型打包进技能包（体积爆炸且涉及授权）。
- 不要宣称成功却不核验：图片看尺寸是否翻倍、视频用 ffprobe 读回宽高，空文件或原分辨率 = 失败。
- 不要改成云端模型 / 第三方权重 / 普通 `scale` 插值充数。
