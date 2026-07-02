# Interaction

## Goal

Make the user feel like they are describing a product outcome, not operating an embedded toolchain.

The skill should absorb:
- framework choice
- path syntax
- flashing flow
- serial-tool vocabulary
- board-specific hardware facts

The user should mostly express:
- what they want the board to do
- whether the board is connected
- whether they can press physical buttons when needed

## Default Tone

- Use plain language first.
- Prefer short explanations that describe intent and outcome.
- Mention technical terms only when they unblock the user.
- Avoid sounding like setup documentation unless the user explicitly asks for the low-level steps.

Good:
- "我先帮你把这台电脑需要的环境补齐，然后检查这块屏幕模组能不能直接烧进去。"
- "我先确认板子现在能不能正常连接，如果可以，再把界面改成你想要的样子。"
- "这一步需要你碰一下板子上的按键，我会告诉你按哪两个键、按什么顺序。"

Bad:
- "请先安装 ESP-IDF、esptool、Python 模块，再手动执行脚本。"
- "进入 repo 根目录运行 doctor.py。"
- "请确认 GT911、ST7701S、PSRAM 和串口状态。"

## What To Ask

Ask only if the answer materially changes the next action.

Usually acceptable:
- board is physically connected or not
- user can press `Boot` and `Reset` or not
- target behavior if the request is ambiguous, such as "做个界面"

Usually not acceptable:
- asking for pin assignments
- asking which framework they want unless there is a real conflict
- asking for path syntax preferences
- asking them to locate the correct flashing tool

## Intent Mapping

Map natural language into hidden execution paths.

- "帮我配环境"
  - inspect and reuse an existing environment when possible, bootstrap only if genuinely missing, then immediately flash the first-boot image without waiting for another request
- "帮我点亮"
  - verify connection, then flash the fixed `image.png` first-boot test
- "改成时钟/仪表盘/按钮页"
  - keep the existing startup flow, edit LVGL UI layer
- "做成键盘/HID"
  - warn about manual Boot/Reset reflashing before changing firmware behavior
- "烧不进去/找不到串口/刷完没反应"
  - enter troubleshooting mode

## How To Report Progress

Prefer user-centered progress updates.

Good:
- "我已经确认这台电脑现在缺少开发环境，下一步我会先把缺的部分补齐。"
- "板子还没有出现在可烧录设备列表里，我先排查连接和下载模式。"
- "默认测试固件已经能作为第一步验证使用，接下来我可以把界面换成你想要的版本。"
- "屏幕正确显示了测试图片，方向和颜色也正常，说明基础显示链路已经可用。"
- "环境已经就绪，我现在直接把测试图片刷到屏幕上，不需要你再发下一条指令。"

Bad:
- "doctor.py returned null for idf.py."
- "esptool path unresolved."
- "环境已经配置完成，你接下来想做什么？"
- "我先复制工程并做一次源码编译来验证环境。"

## Setup Completion Contract

An environment-setup request is not complete when packages finish installing or when source code compiles.

Continue autonomously in the same turn:

1. detect the connected board
2. flash the bundled first-boot image binary directly
3. verify the flash operation and startup stability
4. ask only whether the expected image is visible with correct direction and colors

Stop earlier only when a concrete blocker requires the user, such as reconnecting the USB cable or pressing hardware buttons.

## When Technical Detail Becomes Necessary

Expose technical detail only in these cases:
- asking for approval to install or download dependencies
- asking the user to press physical hardware buttons
- explaining why a normal automatic flashing loop no longer works after switching to HID behavior
- summarizing what changed in the repository after implementation

When you must expose it, translate it:
- "这一步会安装开发环境" first
- technical tool names second

## HID Interaction Rule

If the firmware will emulate a keyboard or any HID-like USB device:
- warn before the user reaches that state
- explain that reflashing becomes manual
- instruct the user to hold `Boot`, then press `Reset`, to re-enter download mode
- do not present the normal serial flash flow as if it still works automatically
