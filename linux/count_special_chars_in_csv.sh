#!/bin/bash

# 功能：统计CSV文件中的不可见字符、特殊字符以及对应的行数
# 注意：特殊字符不包含#、'、/、|
# 作者：技术专家
# 日期：2025-10

# 帮助信息函数
show_help() {
    echo "用法: $0 CSV文件路径"
    echo ""
    echo "示例:"
    echo "  $0 data.csv  # 分析data.csv文件中的特殊字符"
    echo ""
    echo "说明:"    
    echo "  本脚本会统计CSV文件中的不可见字符和特殊字符（除#、'、/、|外）以及它们出现的行数"    
    echo "  不可见字符包括：制表符、回车符、垂直制表符、换页符、空字符等"    
    echo "  特殊字符包括：除字母、数字、下划线、#、'、/、|外的所有字符"
}

# 检查参数数量
if [[ $# -ne 1 ]]; then
    echo "错误：参数数量不正确" >&2
    echo "" >&2
    show_help >&2
    exit 1
fi

# 提取参数
csv_file="$1"

# 检查输入文件是否存在
if [[ ! -f "$csv_file" ]]; then
    echo "错误：文件 '$csv_file' 不存在" >&2
    exit 2
fi

# 检查文件是否可读
if [[ ! -r "$csv_file" ]]; then
    echo "错误：无法读取文件 '$csv_file'" >&2
    exit 3
fi

# 创建临时文件用于存储结果
invisible_chars_result="$(mktemp)"
special_chars_result="$(mktemp)"

# 清理函数
trap 'rm -f "$invisible_chars_result" "$special_chars_result" 2>/dev/null' EXIT

# 统计不可见字符及其行数
echo "正在分析文件 '$csv_file' 中的不可见字符..."
# 添加标题行到结果文件
echo "字符类型,字符表示,出现行数,行号列表" > "$invisible_chars_result"

# 处理制表符（Tab）
echo "处理制表符..."
tab_lines="$(grep -n $'\t' "$csv_file" 2>/dev/null | cut -d: -f1 | tr '\n' ',')"
tab_count="$(echo "$tab_lines" | tr -cd ',' | wc -c | tr -d ' ')"
if [[ "$tab_count" -gt 0 ]]; then
    echo "制表符,\\t,$tab_count,${tab_lines%,}" >> "$invisible_chars_result"
fi

# 处理回车符（CR）
echo "处理回车符..."
cr_lines="$(grep -n $'\r' "$csv_file" 2>/dev/null | cut -d: -f1 | tr '\n' ',')"
cr_count="$(echo "$cr_lines" | tr -cd ',' | wc -c | tr -d ' ')"
if [[ "$cr_count" -gt 0 ]]; then
    echo "回车符,\\r,$cr_count,${cr_lines%,}" >> "$invisible_chars_result"
fi

# 处理垂直制表符（VT）
echo "处理垂直制表符..."
vt_lines="$(grep -n $'\v' "$csv_file" 2>/dev/null | cut -d: -f1 | tr '\n' ',')"
vt_count="$(echo "$vt_lines" | tr -cd ',' | wc -c | tr -d ' ')"
if [[ "$vt_count" -gt 0 ]]; then
    echo "垂直制表符,\\v,$vt_count,${vt_lines%,}" >> "$invisible_chars_result"
fi

# 处理换页符（FF）
echo "处理换页符..."
ff_lines="$(grep -n $'\f' "$csv_file" 2>/dev/null | cut -d: -f1 | tr '\n' ',')"
ff_count="$(echo "$ff_lines" | tr -cd ',' | wc -c | tr -d ' ')"
if [[ "$ff_count" -gt 0 ]]; then
    echo "换页符,\\f,$ff_count,${ff_lines%,}" >> "$invisible_chars_result"
fi

# 处理空字符（NUL）
echo "处理空字符..."
nul_lines="$(grep -n $'\0' "$csv_file" 2>/dev/null | cut -d: -f1 | tr '\n' ',')"
nul_count="$(echo "$nul_lines" | tr -cd ',' | wc -c | tr -d ' ')"
if [[ "$nul_count" -gt 0 ]]; then
    echo "空字符,\\0,$nul_count,${nul_lines%,}" >> "$invisible_chars_result"
fi

# 统计特殊字符（排除#、'、/）及其行数
echo "正在分析文件 '$csv_file' 中的特殊字符..."
echo "字符类型,字符表示,出现行数,行号列表" > "$special_chars_result"

# 处理各种特殊字符
special_chars='!"$%&()*+,-.:;<=>?@[\]^_`{}~'
for (( i=0; i<${#special_chars}; i++ )); do
    char="${special_chars:$i:1}"
    echo "处理字符 '$char'..."
    # 使用grep -F进行固定字符串匹配
    lines="$(grep -F -n "$char" "$csv_file" 2>/dev/null | cut -d: -f1 | tr '\n' ',')"
    count="$(echo "$lines" | tr -cd ',' | wc -c | tr -d ' ')"
    
    if [[ "$count" -gt 0 ]]; then
        echo "特殊字符,$char,$count,${lines%,}" >> "$special_chars_result"
    fi
done

# 输出结果
echo -e "\n===== 不可见字符统计结果 ====="
cat "$invisible_chars_result"
echo -e "\n===== 特殊字符统计结果（排除#、'、/）====="
cat "$special_chars_result"

# 保存结果到文件
echo -e "\n正在保存结果到文件..."
invisible_output="${csv_file%.csv}_invisible_chars.csv"
special_output="${csv_file%.csv}_special_chars.csv"

# 检查输出目录是否可写
test_dir="$(dirname "$invisible_output")"
if [[ -z "$test_dir" ]]; then
test_dir="."
fi

if ! touch "$test_dir/.test_write_permission" 2>/dev/null; then
    echo "错误：无法写入到目录 '$test_dir'" >&2
    exit 4
else
    rm -f "$test_dir/.test_write_permission" 2>/dev/null
fi

# 保存结果
cp "$invisible_chars_result" "$invisible_output" || {
    echo "错误：无法保存不可见字符统计结果到 '$invisible_output'" >&2
    exit 5
}

cp "$special_chars_result" "$special_output" || {
    echo "错误：无法保存特殊字符统计结果到 '$special_output'" >&2
    exit 6
}

# 显示成功信息
echo "统计完成！"
echo "不可见字符统计结果已保存到: $invisible_output"
echo "特殊字符统计结果已保存到: $special_output"