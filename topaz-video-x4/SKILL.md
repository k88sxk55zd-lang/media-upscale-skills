---
name: "topaz-video-x4"
description: "用本机 Topaz Video AI 6.0.3 把视频 AI 放大。用户说「Topaz放大」「视频超分」「1080P」「2K」「4K」即调用。V2.0 默认出三档：1080P 1890x1080、2K 2520x1440、4K 3780x2160；也可 4 倍。必须设 TVAI_MODEL_DIR。"
---

# Topaz Video AI 放大（V2.0）

把本机已装的 Topaz Video AI（Proteus / `prob-4`）接到命令行。不走云、不用第三方模型、不是普通插值。

## 何时使用

- 用户说「Topaz 放大」「视频超分」「出 1080P / 2K / 4K」「视频 4 倍」。
- 已经有本地 mp4，需要用 Topaz 自带模型出更高清成片。

## 本机环境（2026-09-01 实测）

| 项 | 值 |
|---|---|
| Topaz | `C:\Program Files\Topaz Labs LLC\Topaz Video AI\`（6.0.3） |
| 模型目录 | `C:\ProgramData\Topaz Labs LLC\Topaz Video AI\models` |
| 模型 | Proteus `prob-4`（权重已在本机） |
| 显卡 | NVIDIA RTX 3070 Ti，`device=0` |
| 实测源片 | 1344×768，24fps，10.14 秒 |

## V2.0 三档分辨率（硬规定，不要改数字）

这三档是按源片 7:4 比例定的，不要改成 1920×1080 / 2560×1440 / 3840×2160。

| 档位 | 分辨率 | 输出后缀 | 编码 |
|---|---|---|---|
| 1080P | **1890×1080** | `_1080p.mp4` | H.264 |
| 2K | **2520×1440** | `_2k.mp4` | H.264 |
| 4K | **3780×2160** | `_4k.mp4` | H.264 |
| 4 倍（可选） | 源宽×4 × 源高×4 | `_x4.mp4` | 超 4096 用 HEVC |

实测样本（同一源片）：

| 档位 | 结果 |
|---|---|
| 1080P | 1890×1080，约 20MB |
| 2K | 2520×1440，约 34MB |
| 4K | 3780×2160，约 78MB |
| 4 倍 | 5376×3072 HEVC，约 137MB |

## 其他硬规定

| 参数 | 固定值 | 原因 |
|---|---|---|
| 模型 | **prob-4** | Topaz 自带 Proteus |
| 环境变量 | **TVAI_MODEL_DIR** | 写错就报 `Model not found: prob-4` |
| 下载 | **download=0** | 只用本机已有权重 |
| 声音 | **原样拷贝** | `-c:a copy` |
| 默认档位 | **all**（1080P+2K+4K） | V2.0；用户没说档位就出三份 |

## 标准工作流

1. 确认输入视频存在。
2. 用户没指定档位，或说「三个分辨率 / 1080 2K 4K 都要」：用 `-Preset all`。
3. 只要其中一档：`-Preset 1080p` / `-Preset 2k` / `-Preset 4k`。
4. 明确要「4 倍」才用 `-Preset x4`。
5. AI 调用时不要加 `-WaitAtEnd`：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "C:\Users\Administrator\.zcode\skills\topaz-video-x4\topaz-video-x4.ps1" -Preset all "视频完整路径.mp4"
```

单档：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "C:\Users\Administrator\.zcode\skills\topaz-video-x4\topaz-video-x4.ps1" -Preset 4k "视频完整路径.mp4"
```

4 倍：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "C:\Users\Administrator\.zcode\skills\topaz-video-x4\topaz-video-x4.ps1" -Preset x4 "视频完整路径.mp4"
```

6. 脚本会打印 `RESULT_PATH=完整路径`（多档会打多行）。用 ffprobe 核验宽高、时长，对上了才能说「做好了」。
7. 人用手拖：桌面「Topaz视频4倍放大.bat」或技能目录 `topaz-video-x4.bat`，默认出三档。

## 滤镜怎么写

| 模式 | 滤镜要点 |
|---|---|
| 指定分辨率 | `tvai_up=model=prob-4:scale=0:w=<宽>:h=<高>:...:download=0`，后面再 `scale=w=<宽>:h=<高>:flags=lanczos` |
| 4 倍 | `scale=4` 同时写死 `w=<源宽*4>:h=<源高*4>` |

## 编码怎么选（脚本已自动判断）

| 输出宽或高 | 编码 | 注意 |
|---|---|---|
| ≤ 4096 | `h264_nvenc -profile:v high` | 三档都走这条 |
| 4097–8192 | `hevc_nvenc -profile:v main` | HEVC **不能**写 `high` |
| > 8192 | 跳过 | 超出 HEVC 上限 |

## 踩坑（必读）

1. **环境变量名字写错 = 找不到模型**。CLI 只认 `TVAI_MODEL_DIR`（可同时设 `TVAI_MODEL_DATA_DIR`）。`TOPAZ_VIDEO_AI_MODELS` / `TOPAZ_MODELS_DIR` 无效。
2. 必须用 Topaz 自带的 `ffmpeg.exe`，系统 ffmpeg 没有 `tvai_up`。
3. 指定分辨率用 `scale=0` + 写死宽高；4 倍用 `scale=4` + 写死 4 倍宽高。
4. HEVC 误加 `-profile:v high` 会先报错，容易误判成模型坏了。
5. 这三档数字是 1890 / 2520 / 3780，不是常见的 1920 / 2560 / 3840。
6. PowerShell 5.1：本目录 `.ps1` 必须 UTF-8 **带 BOM**。
7. 不要在 AI 会话里给脚本加 `-WaitAtEnd`。

## 不要做的事

- 不要改成云端模型、第三方权重、普通 `scale` 插值充数。
- 不要擅自改三档分辨率数字。
- 不要宣称成功却不核验分辨率。空文件或仍是源分辨率 = 失败。
