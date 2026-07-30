#!/usr/bin/env python3
# text_to_md.py 普通文本转标准Markdown格式化脚本
import sys
import os

def format_to_markdown(input_text: str) -> str:
    lines = input_text.splitlines()
    output = []
    in_code_block = False

    for line in lines:
        stripped = line.strip()

        # 识别代码块标记 ```
        if stripped.startswith("```"):
            in_code_block = not in_code_block
            output.append(line)
            continue

        # 代码块内部原样保留，不处理
        if in_code_block:
            output.append(line)
            continue

        # 一级标题匹配：xxx ==== / # xxx 兼容
        if stripped and stripped.endswith("====") and len(stripped) > 5:
            title = stripped.rsplit("=", 1)[0].strip()
            output.append(f"# {title}")
            continue
        # 二级标题
        if stripped and stripped.endswith("----") and len(stripped) > 5:
            title = stripped.rsplit("-", 1)[0].strip()
            output.append(f"## {title}")
            continue

        # 检测以【一、二、三】作为章节，自动转为二级标题（适配中文笔记）
        if stripped.startswith(("一、", "二、", "三、", "四、", "五、", "六、", "七、", "八、", "九、", "十、")):
            output.append(f"## {stripped}")
        else:
            output.append(line)

    return "\n".join(output)


def main():
    if len(sys.argv) < 2:
        print("用法：")
        print("  python3 text_to_md.py input.txt output.md")
        print("  或者管道方式：cat raw.txt | python3 text_to_md.py > out.md")
        sys.exit(1)

    # 管道输入模式
    if sys.argv[1] == "-":
        raw_data = sys.stdin.read()
        md_result = format_to_markdown(raw_data)
        print(md_result)
        return

    input_path = sys.argv[1]
    output_path = sys.argv[2] if len(sys.argv) >= 3 else None

    if not os.path.exists(input_path):
        print(f"文件不存在: {input_path}")
        sys.exit(1)

    with open(input_path, "r", encoding="utf-8") as f:
        content = f.read()

    md_content = format_to_markdown(content)

    if output_path:
        with open(output_path, "w", encoding="utf-8") as f:
            f.write(md_content)
        print(f"已输出Markdown至: {output_path}")
    else:
        print(md_content)


if __name__ == "__main__":
    main()
