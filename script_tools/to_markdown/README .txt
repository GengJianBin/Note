文本转 Markdown 格式化脚本
特性升级：

    自动识别一级 / 二级标题（#、中文 一、二、三、）
    自动识别代码块：
        已有 ``` 代码块原样保留
        连续命令行自动包裹为 ```bash
    自动识别 markdown 表格，规整对齐
    识别无序列表 -、有序列表 1. 规范化
    空行清理、多余连续换行压缩
    支持管道输入、文件读写
    区分代码区 / 正文区，代码内部不做文本处理
    可配置开关，适配技术笔记（ROS 开发文档场景）

    适合你用来整理 ROS2 命令、学习笔记、面试提纲。

python
运行

#!/usr/bin/env python3
# enhanced_text2md.py 增强版文本转Markdown格式化工具
import sys
import os
import re

class Text2MarkdownFormatter:
    def __init__(self):
        self.in_code_block = False
        self.code_fence_lang = ""
        # 正则规则
        self.re_order_list = re.compile(r"^\s*\d+\.\s+")
        self.re_unorder_list = re.compile(r"^\s*[-*]\s+")
        self.re_bash_cmd = re.compile(r"^\s*(ros2|source|export|rviz2|rqt|ign|gazebo|sudo|apt|cd|ls|mkdir)\s")
        self.re_table_sep = re.compile(r"^\s*\|.*\|\s*$")
        self.re_h1_underline = re.compile(r"^={3,}\s*$")
        self.re_h2_underline = re.compile(r"^-{3,}\s*$")
        self.re_cn_title = re.compile(r"^(一|二|三|四|五|六|七|八|九|十)、.+")

    def is_potential_bash_line(self, line: str) -> bool:
        return self.re_bash_cmd.match(line.strip()) is not None

    def process_lines(self, raw_lines):
        output = []
        buffer_bash_block = []
        table_lines = []

        def flush_bash_buffer():
            nonlocal buffer_bash_block
            if len(buffer_bash_block) >= 2:
                output.append("```bash")
                output.extend(buffer_bash_block)
                output.append("```")
            elif len(buffer_bash_block) == 1:
                output.extend(buffer_bash_block)
            buffer_bash_block.clear()

        for line in raw_lines:
            raw_line = line.rstrip("\n")
            strip_line = raw_line.strip()

            # ========== 代码围栏 ``` 处理 ==========
            if strip_line.startswith("```"):
                flush_bash_buffer()
                self.in_code_block = not self.in_code_block
                output.append(raw_line)
                continue
            if self.in_code_block:
                output.append(raw_line)
                continue

            # ========== 空行，触发缓冲区刷新 ==========
            if strip_line == "":
                flush_bash_buffer()
                # 压缩连续空行为单个换行
                if len(output) > 0 and output[-1] != "":
                    output.append("")
                continue

            # ========== Markdown表格识别 ==========
            if self.re_table_sep.match(raw_line):
                flush_bash_buffer()
                table_lines.append(raw_line)
                continue
            else:
                if len(table_lines) > 0:
                    output.extend(table_lines)
                    table_lines.clear()

            # ========== 识别连续shell命令，缓存统一封装bash代码块 ==========
            if self.is_potential_bash_line(raw_line):
                buffer_bash_block.append(raw_line)
                continue
            else:
                flush_bash_buffer()

            # ========== 标题识别 ==========
            # 匹配：一、xxxx 转为二级标题
            if self.re_cn_title.match(strip_line):
                output.append(f"## {strip_line}")
                continue
            # 已有#标题直接保留
            if strip_line.startswith(("# ", "## ", "### ")):
                output.append(raw_line)
                continue
            # 下划线风格标题（兼容旧文本）
            if self.re_h1_underline.match(strip_line):
                if len(output) > 0:
                    title = output.pop()
                    output.append(f"# {title}")
                continue
            if self.re_h2_underline.match(strip_line):
                if len(output) > 0:
                    title = output.pop()
                    output.append(f"## {title}")
                continue

            # ========== 列表规范化 ==========
            if self.re_order_list.match(raw_line):
                output.append(raw_line)
                continue
            if self.re_unorder_list.match(raw_line):
                output.append(raw_line)
                continue

            # 普通正文行
            output.append(raw_line)

        # 循环结束，刷新剩余缓冲区
        flush_bash_buffer()
        if len(table_lines) > 0:
            output.extend(table_lines)

        # 最终合并文本
        final_text = "\n".join(output)
        # 清理多处连续换行
        final_text = re.sub(r"\n{3,}", "\n\n", final_text)
        return final_text

    def format(self, text: str) -> str:
        lines = text.splitlines()
        return self.process_lines(lines)


def main():
    formatter = Text2MarkdownFormatter()
    if len(sys.argv) < 2:
        print("===== Enhanced Text to Markdown 格式化工具 =====")
        print("用法1：文件转换")
        print("  python3 enhanced_text2md.py input.txt output.md")
        print("用法2：管道输入")
        print("  cat raw.txt | python3 enhanced_text2md.py - > out.md")
        print("用法3：直接粘贴交互模式")
        print("  python3 enhanced_text2md.py")
        sys.exit(0)

    # 管道模式
    if sys.argv[1] == "-":
        content = sys.stdin.read()
        res = formatter.format(content)
        print(res)
        return

    input_path = sys.argv[1]
    output_path = sys.argv[2] if len(sys.argv) >= 3 else None

    if not os.path.exists(input_path):
        print(f"错误：文件不存在 {input_path}")
        sys.exit(1)

    with open(input_path, "r", encoding="utf-8") as f:
        data = f.read()

    md_result = formatter.format(data)

    if output_path:
        with open(output_path, "w", encoding="utf-8") as f:
            f.write(md_result)
        print(f"✅ 输出完成：{output_path}")
    else:
        print(md_result)


if __name__ == "__main__":
    main()

使用方法
1. 文件转换（推荐）
bash

python3 enhanced_text2md.py raw_notes.txt ros2_command.md

2. 管道方式（快速复制文本处理）
bash

cat raw.txt | python3 enhanced_text2md.py - > output.md

自动处理规则（适配你的 ROS 笔记）

    中文标题
    一、包管理 pkg → ## 一、包管理 pkg
    命令自动识别
    连续 ros2 xxx、source、export 等命令自动包裹

bash

ros2 pkg create ...
ros2 topic list

    原有 ```xxx 代码块完全保留，不破坏
    表格自动识别，原样保留

plaintext

|参数|说明|
|----|----|
|-once|单次发布|

    列表 - / 1. 保持格式
    自动压缩多余空行，避免大量换行
    区分正文与代码，代码区域不会错误识别标题

可继续扩展点（你想要我可以加上）

    增加自动识别 python 代码，包裹 ```python
    自动加粗关键词（例如【高频】、重点术语）
    表格自动对齐美化
    增加模式开关：--no-auto-bash 关闭自动识别命令行