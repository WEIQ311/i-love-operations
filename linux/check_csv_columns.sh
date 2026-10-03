#!/bin/bash

# 功能：解析CSV文件，检查每行是否有27列（文件分隔符是|#|，数据的包围符是'）
# 作者：技术专家
# 日期：2025-10

# 帮助信息函数
show_help() {
    echo "用法: $0 CSV文件路径"
    echo ""
    echo "示例:"
    echo "  $0 data.csv  # 检查data.csv文件中每行是否有27列"
    echo ""
    echo "说明:"
    echo "  本脚本用于检查CSV文件中每行的列数是否为27列"
    echo "  文件分隔符: |#|"
    echo "  数据包围符: '"
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

# 设置期望的列数
expected_columns=27

# 统计信息初始化
total_lines=0
error_lines=0

# 输出标题
echo "正在检查文件 '$csv_file' 中每行的列数..."
echo "错误行号列表："

# 逐行处理文件，并跟踪行号
line_number=0

while IFS= read -r line || [[ -n "$line" ]]; do
    line_number=$((line_number + 1))
    
    # 使用awk解析行，处理|#|分隔符和'包围符
    # 处理逻辑：将引号内的|#|替换为临时标记，分割后再恢复
    column_count=$(echo "$line" | awk -F"'" 'BEGIN {temp=""}
        {
            for(i=1; i<=NF; i++) {
                if(i % 2 == 1) {
                    # 在引号外，替换|#|为临时标记
                    gsub(/\|#\|/, "__TEMP_SEPARATOR__", $i)
                }
                temp = temp $i
                if(i % 2 == 1 && i < NF) temp = temp "\047"
            }
            # 现在分割处理过的行
            split(temp, parts, "__TEMP_SEPARATOR__");
            print length(parts);
        }')
    
    # 验证列数
    if [[ "$column_count" -ne "$expected_columns" ]]; then
        echo "$line_number"
        error_lines=$((error_lines + 1))
    fi
done < "$csv_file"

total_lines=$line_number

# 显示统计信息
echo -e "\n检查完成！"
echo "总行数: $total_lines"
echo "正常行数: $((total_lines - error_lines))"
echo "错误行数: $error_lines"