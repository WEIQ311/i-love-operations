#!/bin/bash

# 功能：从文件中过滤包含特定关键词的行，并将这些行提取到新文件中
# 作者：技术专家
# 日期：2025-10

# 设置脚本执行选项：遇到错误时退出，显示执行的命令
set -euo pipefail

# 帮助信息函数
show_help() {
    echo "用法: $0 [选项] 关键词 输入文件 输出文件"
    echo ""
    echo "选项:"
    echo "  -i, --ignore-case   忽略大小写"
    echo "  -v, --invert        反转匹配，即提取不包含关键词的行"
    echo "  -h, --help          显示帮助信息"
    echo ""
    echo "示例:"
    echo "  $0 ERROR logfile.txt error_lines.txt      # 提取包含ERROR的行"
    echo "  $0 -i warning logfile.txt warning_lines.txt # 忽略大小写提取包含warning的行"
    echo "  $0 -v DEBUG logfile.txt non_debug_lines.txt # 提取不包含DEBUG的行"
}

# 处理命令行选项
ignore_case=false
invert_match=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        -i|--ignore-case)
            ignore_case=true
            shift
            ;;
        -v|--invert)
            invert_match=true
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            break
            ;;
    esac
done

# 检查参数数量
if [[ $# -ne 3 ]]; then
    echo "错误：参数数量不正确"
    echo ""
    show_help
    exit 1
fi

# 提取参数
keyword="$1"
input_file="$2"
output_file="$3"

# 检查输入文件是否存在
if [[ ! -f "$input_file" ]]; then
    echo "错误：输入文件 '$input_file' 不存在"
    exit 1
fi

# 构建grep命令选项
grep_options=""
if $ignore_case; then
    grep_options="$grep_options -i"
fi
if $invert_match; then
    grep_options="$grep_options -v"
fi

# 执行过滤操作
echo "正在从 '$input_file' 中过滤包含关键词 '$keyword' 的行..."
grep $grep_options "$keyword" "$input_file" > "$output_file"

# 检查命令执行结果
if [[ $? -eq 0 ]]; then
    matched_lines=$(wc -l < "$output_file")
    echo "成功：已将 $matched_lines 行提取到 '$output_file'"
else
    echo "警告：未找到匹配的行，已创建空的输出文件"
fi

# 恢复默认的shell行为
sed -i "" 's/set -euo pipefail//g' "$output_file" || true