---
name: "upscayl-batch"
description: "用 Upscayl（阿普升图）批量放大图片，固定 2 倍 PNG 无损，调用本机 RTX 3070 Ti + ultrasharp-4x 模型，通过命令行脚本批量处理"
---

# Upscayl 批量放大（阿普升图）

## 何时使用
- 用户说「放大图片」「批量放大」「Upscayl」「阿普升图」「图片放大 2 倍」等。
- 需要把一批 PNG/JPG 图片用 AI 超分模型放大，固定 2 倍，PNG 无损输出。

## 工具形式
**没有 MCP 接口**，只能用命令行调用 `upscayl-bin.exe`（Upscayl 桌面版自带的 CLI）。通过 PowerShell 脚本 `upscayl-batch.ps1` 批量处理。

## 环境事实（本机已实测验证）

| 项目 | 值 |
|------|-----|
| Upscayl 安装目录 | `F:\阿普升图\` |
| CLI 可执行文件 | `F:\阿普升图\resources\bin\upscayl-bin.exe` |
| 模型目录 | `F:\阿普升图\resources\models\` |
| 显卡 | NVIDIA GeForce RTX 3070 Ti（Vulkan，GPU id=0） |
| 可用模型 | ultrasharp-4x / upscayl-standard-4x / upscayl-lite-4x / remacri-4x / high-fidelity-4x / digital-art-4x / ultramix-balanced-4x |

## 硬规定（用户习惯，不可擅自改）

| 参数 | 固定值 | 说明 |
|------|--------|------|
| 倍数 | **2** | 固定 2 倍 |
| 格式 | **png** | 固定 PNG |
| 压缩 | **0** | 无损 |
| 模型 | **ultrasharp-4x** | 画质优先 |
| TTA | **关** | 开了速度慢一倍 |

## 标准工作流

1. 确认 CLI 还在：`Test-Path "F:\阿普升图\resources\bin\upscayl-bin.exe"`。如果软件重装或换盘，需要改脚本顶部的 `$UPSCAYL_EXE` 和 `$MODEL_PATH`。
2. 直接用本技能目录下的优化版脚本批量跑（支持断点续跑、并行、任意输入输出目录）：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "C:\Users\Administrator\.zcode\skills\upscayl-batch\upscayl-batch.ps1" -InputDir "输入文件夹" -OutputDir "输出文件夹" [-Workers 2]
```

3. **先单张测试**：把一张图单独放进临时输入文件夹，跑通确认链路正常。
4. 确认无误后批量跑，等待完成。
5. 重跑安全：输出目录已有同名 png 的自动跳过，中断续跑不浪费。

## 优化版脚本 upscayl-batch.ps1

本技能目录内置 `upscayl-batch.ps1`（2026-08 实测修订版），功能：
- 断点续跑：输出目录已有同名输出自动跳过，重跑/续跑零浪费。
- 可选并行：`-Workers 2` 起 2 个后台 job 分摊图片（参数可调）。
- 线程 `-j 2:4:4`。
- 结束时报告总数与耗时。

## 性能实测结论

### 单张耗时基准（2026-09 重测，2752×1536 源图 → ultrasharp-4x / 2x / 无损 png / RTX 3070 Ti）

| 显卡状态 | 实测单张耗时 |
|---|---|
| GPU 空闲（无其他程序占显存） | **16.9–18.1 秒**，52 张串行批次前段稳定 18 秒 |
| 显存被挤占（其他程序占约 7.4 / 8 GB） | **42 → 93 → 109 秒**，同一批次内劣化约 6 倍 |

**关键更正：之前记录的「单张 16.4s / 13 张 210s / 双开无提速」不可信**，那批数字是在并发显存争用下测的，却被当成了冷启动与算力见顶来解释。真实驱动因素是整机显存占用，不是初始化开销——证据：同一次串行批次里前 37 张稳定 18 秒，第 38、39 张突然 42.4s 和 93s；冷启动只可能影响第一张，不可能中途劣化。

**估时长前先测负载**：`nvidia-smi --query-gpu=utilization.gpu,memory.used --format=csv,noheader`。显存接近占满时，单张耗时按 60–110 秒算，别按 18 秒算。

| 手段 | 结论 |
|------|---------|
| 断点续跑 | 实打实收益：重跑跳过已完成部分 |
| 双实例并行 | **旧「无提升」结论作废**，需在 GPU 空闲下重测才有效 |
| `-j 2:4:4` vs 默认 | 旧 AB 测试同样受争用污染，未重测 |
| upscayl-lite-4x 模型 | 明显提速但画质略降，违反画质优先硬规定，不采用 |


## 踩坑要点（必读）

1. **盘符搞混（最高频）**：Upscayl 装在 F 盘，用户图片通常在 C 盘。两个盘路径不能混，给脚本传路径时确认盘符正确。
2. **中文+空格+括号路径必须加双引号**：所有含中文/空格/括号的路径，命令里一律加双引号，否则 shell 解析失败。
3. **别重装，先找本机已装的**：用户已装 Upscayl 桌面版，直接复用 `resources\bin\upscayl-bin.exe`，不要从 GitHub 下载。
4. **联网受限时用本地 --help**：`upscayl-bin.exe --help` 可获取参数列表，不依赖网络。
5. **参数名版本差异**：`--help` 里倍数可能显示 `-z`，但实际用 `-s` 正常。以本地 `--help` 实际输出为准。
6. **TTA 开关**：`-x` 开启后质量略好但速度慢约一倍，默认关。
7. **渐进式迭代**：先单张测 → 确认再批量，不要一步到位。
8. **单文件模式 `-o` 要完整输出文件路径**；文件夹模式 `-o` 目录必须已存在，否则静默失败不产出。
9. **PowerShell 5.1 编码**：.ps1 含中文必须存成 UTF-8 **带 BOM**，否则中文乱码甚至解析报错。
10. **PowerShell job 变量坑**：Start-Job 里用 `$using:` 传来的对象集合，取 `.BaseName`/`.FullName` 可能取空导致输出变成 `.png`、多进程互相覆盖。传**字符串路径数组**，用 `[IO.Path]::GetFileNameWithoutExtension()` 取名最稳。
11. **输出目录被沙箱权限拦截**：若 `-o` 输出目录在会话可写范围之外（如 D 盘桌面 vs 仅 I:\DeepSeek 工作区），脚本 New-Item 会报 `Access to the path '...' is denied` + `CreateDirectoryUnauthorizedAccessError` 直接失败。此时需把输出放到许可范围内，或申请 `danger-full-access` 后再跑，否则连目录都建不出来。
12. **所有 pwsh 命令崩溃（exit 3221225794）先设 workdir**：偶发整个会话的 PowerShell 每条命令都返回 `exit code 3221225794` 且无输出，疑似工作目录不可访问。排查后把命令加 `workdir` 指向当前会话工作区（如 `I:\DeepSeek`）即恢复正常。遇到整批命令全崩先试这个，别逐条瞎排查。
13. **AI 现写的 .ps1 里别放中文字面量路径**（2026-09 实测，整批 53 张秒失败）：AI 用编辑工具落盘的脚本通常是 UTF-8 **无 BOM**，PowerShell 5.1 的 `-File` 会按 GBK 解码，于是 `F:\阿普升图\...` 变成乱码路径，报 `CommandNotFoundException`，而错误信息再经 GBK 回显到 UTF-8 终端时看着却是正常中文——**症状具有欺骗性，光看报错文字查不出来**。第 9 条说的「补 BOM」能治，但更稳的是让脚本源码保持纯 ASCII，中文目录名用码点拼：
    ```powershell
    $appDir = "F:\" + [char]0x963F + [char]0x666E + [char]0x5347 + [char]0x56FE   # 阿普升图
    $exe    = Join-Path $appDir "resources\bin\upscayl-bin.exe"
    ```
    这样对文件编码零依赖。配套做法：批量循环开头一定先 `Test-Path $exe` 不通过就 `exit 1`，否则一张失败会变成整批失败并刷屏。
14. **整批喂目录前先筛源尺寸**（2026-09 实测）：目标是固定倍数（如 2 倍到 5504×3072）时，目录里混进已达标或尺寸不符的图会出事——已 5504×3072 的会被二次放大成 11008×6144，既慢又废。脚本的断点续跑只看**输出目录**有无同名 png，不认源目录里现成的达标文件。做法：用 `System.Drawing` 读出每张 W×H，只把 `W*倍数==目标` 的挑出来跑；已达标的直接复制进输出目录占位，下一轮就被跳过逻辑认掉。

## 单张测试命令参考

```powershell
& "F:\阿普升图\resources\bin\upscayl-bin.exe" -i "输入图片路径" -o "输出图片路径" -m "F:/阿普升图/resources/models" -n "ultrasharp-4x" -s 2 -f png -g 0
```

成功标志：输出中出现 `NVIDIA GeForce RTX 3070 Ti` 和逐步增长的百分比（如 `98.15%` → `99.54%`）。

## 经验包位置

完整文档、调用记录、脚本源码在 `J:\workbuddy\2026-07-13-18-17-32\upscayl-batch-experience-pack\`：
- `README.md` — 经验踩坑主文档
- `HANDOFF.md` — 速查卡片
- `调用记录.md` — 真实命令与输出原文
- `upscayl-batch.ps1` — 脚本源码
