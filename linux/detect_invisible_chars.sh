#!/bin/bash

# 功能：检测文本文件中的隐藏不可见字符
# 作者：技术专家
# 日期：2025-10

# 设置LC_CTYPE为UTF-8以确保正确处理中文和其他UTF-8字符
export LC_CTYPE="zh_CN.UTF-8"
if ! locale -a | grep -q "zh_CN.UTF-8"; then
    export LC_CTYPE="C.UTF-8"
    if ! locale -a | grep -q "C.UTF-8"; then
        export LC_CTYPE="en_US.UTF-8"
    fi
fi
export LC_ALL= # 清空LC_ALL以避免覆盖LC_CTYPE设置

# 帮助信息函数
show_help() {
    echo "用法: $0 [选项] <文件路径>"
    echo "功能：检测文本文件中的隐藏不可见字符"
    echo ""
    echo "选项:"
    echo "  -h, --help          显示此帮助信息并退出"
    echo "  -d, --detailed      显示详细的检测结果，包括每个不可见字符的位置和类型"
    echo "  -r, --remove        将检测到的不可见字符移除并保存到新文件"
    echo "  -o, --output <文件> 指定移除不可见字符后的输出文件路径"
    echo ""
    echo "示例:"
    echo "  $0 file.txt         快速检测文件中的不可见字符"
    echo "  $0 -d file.txt      详细检测并显示不可见字符的位置和类型"
    echo "  $0 -r file.txt      检测并移除不可见字符，输出到原文件名加_clean后缀"
    echo "  $0 -r -o clean.txt file.txt 检测并移除不可见字符，输出到指定文件"
}

# 初始化变量
detailed_mode=false
remove_mode=false
output_file=""

# 解析命令行参数
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -d|--detailed)
            detailed_mode=true
            shift
            ;;
        -r|--remove)
            remove_mode=true
            shift
            ;;
        -o|--output)
            if [[ -n $2 ]]; then
                output_file="$2"
                shift 2
            else
                echo "错误：-o/--output 选项需要指定输出文件" >&2
                show_help >&2
                exit 1
            fi
            ;;
        -*)  
            echo "错误：未知选项 '$1'" >&2
            show_help >&2
            exit 1
            ;;
        *)
            # 处理文件参数
            file_path="$1"
            shift
            ;;
    esac

done

# 检查文件是否提供
if [[ -z "$file_path" ]]; then
    echo "错误：请提供要检测的文件路径" >&2
    show_help >&2
    exit 1
fi

# 检查文件是否存在
if [[ ! -f "$file_path" ]]; then
    echo "错误：文件 '$file_path' 不存在" >&2
    exit 2
fi

# 检查文件是否可读
if [[ ! -r "$file_path" ]]; then
    echo "错误：无法读取文件 '$file_path'" >&2
    exit 3
fi

# 定义不可见字符的描述（使用更简单的格式避免引号转义问题）
readonly INVISIBLE_CHARS_DESC=(
    "NULL字符" "SOH字符" "STX字符" "ETX字符"
    "EOT字符" "ENQ字符" "ACK字符" "BEL字符"
    "BS字符" "TAB字符" "LF字符" "VT字符"
    "FF字符" "CR字符" "SO字符" "SI字符"
    "DLE字符" "DC1字符" "DC2字符" "DC3字符"
    "DC4字符" "NAK字符" "SYN字符" "ETB字符"
    "CAN字符" "EM字符" "SUB字符" "ESC字符"
    "FS字符" "GS字符" "RS字符" "US字符"
    "空格字符" "感叹号字符" "双引号字符" "井号字符"
    "美元符字符" "百分号字符" "与号字符" "单引号字符"
    "左括号字符" "右括号字符" "星号字符" "加号字符"
    "逗号字符" "减号字符" "点号字符" "斜杠字符"
    "数字0-9" "大写字母A-Z" "左方括号字符" "反斜杠字符"
    "右方括号字符" "插入符号字符" "下划线字符" "反引号字符"
    "小写字母a-z" "左花括号字符" "竖线字符" "右花括号字符"
    "波浪号字符" "DEL字符" "扩展ASCII字符" "UTF-8控制字符"
)

# 函数：获取字符描述
get_char_desc() {
    local char_code=$1
    if (( char_code >= 0 && char_code <= 127 )); then
        echo "${INVISIBLE_CHARS_DESC[$char_code]}"
    elif (( char_code >= 128 && char_code <= 255 )); then
        echo "扩展ASCII字符(十进制:$char_code)"
    else
        echo "UTF-8控制字符(十进制:$char_code)"
    fi
}

# 函数：检测文件中的不可见字符（快速模式）
detect_invisible_chars_fast() {
    local file_path=$1
    echo "正在快速检测文件 '$file_path' 中的不可见字符..."
    
    # 使用grep检测控制字符（排除换行符、制表符和回车符）
    # 使用printf确保正确处理转义序列
    local control_chars_found=
    grep -q -e "$(printf '\x00')" -e "$(printf '\x01')" -e "$(printf '\x02')" -e "$(printf '\x03')" \
           -e "$(printf '\x04')" -e "$(printf '\x05')" -e "$(printf '\x06')" -e "$(printf '\x07')" \
           -e "$(printf '\x08')" -e "$(printf '\x0B')" -e "$(printf '\x0C')" -e "$(printf '\x0E')" \
           -e "$(printf '\x0F')" -e "$(printf '\x10')" -e "$(printf '\x11')" -e "$(printf '\x12')" \
           -e "$(printf '\x13')" -e "$(printf '\x14')" -e "$(printf '\x15')" -e "$(printf '\x16')" \
           -e "$(printf '\x17')" -e "$(printf '\x18')" -e "$(printf '\x19')" -e "$(printf '\x1A')" \
           -e "$(printf '\x1B')" -e "$(printf '\x1C')" -e "$(printf '\x1D')" -e "$(printf '\x1E')" \
           -e "$(printf '\x1F')" -e "$(printf '\x7F')" "$file_path" \
           && control_chars_found="是" || control_chars_found="否"
    
    # 检测文件是否包含BOM标记
    local temp_bom=$(mktemp)
    echo -ne "\xef\xbb\xbf" > "$temp_bom"
    local bom_found=$(head -c 3 "$file_path" | cmp -s - "$temp_bom" && echo "是" || echo "否")
    rm -f "$temp_bom"
    
    # 检测Windows风格的行结束符(CRLF)
    local crlf_found=$(grep -q "\r$" "$file_path" && echo "是" || echo "否")
    
    # 检测零宽字符 - 使用file命令和grep组合替代grep -P
    local file_info=$(file -b "$file_path")
    local zero_width_found="否"
    if [[ "$file_info" == *UTF-8* ]]; then
        # 使用xxd和grep检测零宽字符的字节序列
        if xxd -p "$file_path" | tr -d '\n' | grep -q -E '(e2808b|e2808c|e2808d|efbbbf)'; then
            zero_width_found="是"
        fi
    fi
    
    # 输出结果
    echo "\n检测结果摘要："
    echo "----------------------------------------"
    echo "是否包含控制字符: $control_chars_found"
    echo "是否包含BOM标记: $bom_found"
    echo "是否包含Windows风格行结束符(CRLF): $crlf_found"
    echo "是否包含零宽字符: $zero_width_found"
    
    # 如果任何检测为真，建议使用详细模式
    if [[ $control_chars_found == "是" || $bom_found == "是" || $crlf_found == "是" || $zero_width_found == "是" ]]; then
        echo "\n建议：使用 -d 选项运行详细检测以获取更多信息。"
    else
        echo "\n文件中未检测到明显的不可见字符。"
    fi
}

# 函数：检测文件中的不可见字符（详细模式）
detect_invisible_chars_detailed() {
    local file_path=$1
    echo "正在详细检测文件 '$file_path' 中的不可见字符..."
    
    # 创建临时文件存储检测结果
    local temp_file=$(mktemp /tmp/invisible_chars_XXXXXX)
    
    echo -e "行号\t位置\t字符编码(十六进制)\t字符描述\t上下文" > "$temp_file"
    echo -e "---\t---\t---\t---\t---" >> "$temp_file"
    
    # 初始化计数器和标志
    local has_invisible_chars=false
    local invisible_count=0
    local line_with_invisible_count=0
    local current_line=1
    local current_char_pos=1
    local current_line_text=""
    local line_has_invisible=false
    
    # 直接使用od命令读取文件的十六进制表示，以正确处理所有字符
    local file_hex=$(od -An -t x1 "$file_path" | tr -d ' \n')
    local byte_index=0
    
    # 快速检测功能暂时禁用，因为反斜杠转义在不同环境中表现不一致
    # local has_invisible_fast=false
    # 后续会重新实现一个更可靠的快速检测方法
    
    # 逐字节处理文件内容
    while (( byte_index < ${#file_hex} )); do
        local byte_hex=${file_hex:$byte_index:2}
        # 验证是否是有效的两位十六进制数字
        if [[ ! $byte_hex =~ ^[0-9a-fA-F]{2}$ ]]; then
            # 如果不是有效的十六进制数字，跳过这个字节
            ((byte_index+=2))
            continue
        fi
        local byte_dec=$((16#$byte_hex))
        
        # 检查是否是换行符，如果是，处理当前行
        if (( byte_dec == 10 )); then  # LF字符
        # 记录换行符
        echo -e "$current_line\t$current_char_pos\t0x$byte_hex\t换行符(LF)\t$current_line_text" >> "$temp_file"
        has_invisible_chars=true
        line_has_invisible=true
        ((invisible_count++))
        
        # 行结束，检查是否包含不可见字符
        if $line_has_invisible; then
            ((line_with_invisible_count++))
            line_has_invisible=false
        fi
        
        # 重置行相关变量
        ((current_line++))
        current_char_pos=1
        current_line_text=""
        else
            # 对于其他字符，先添加到当前行文本
            local char=""
            
            # 检查字符类型并处理
            if (( byte_dec < 128 )); then
                # 处理ASCII字符
                # 安全地将十六进制字符转换回实际字符，避免printf错误
                char=$(printf "\\x$byte_hex")
                current_line_text+="$char"
                
                # 检查是否是不可见字符
                if (( byte_dec < 32 )) || (( byte_dec == 127 )); then
                    # 排除特定可显示字符
                    if (( byte_dec != 35 )) && (( byte_dec != 39 )) && (( byte_dec != 124 )); then
                        echo -e "$current_line\t$current_char_pos\t0x$byte_hex\t$(get_char_desc $byte_dec)\t$current_line_text" >> "$temp_file"
                        has_invisible_chars=true
                        line_has_invisible=true
                        ((invisible_count++))
                    fi
                fi
            else
                # 处理UTF-8多字节字符
                # 尝试收集完整的UTF-8字符（最多4字节）
                local multi_byte_chars="$byte_hex"
                local multi_byte_text=""
                local valid_utf8=true
                
                # 根据UTF-8编码规则检测多字节字符
                if (( (byte_dec & 0xE0) == 0xC0 )); then  # 2字节字符
                    if (( byte_index + 2 <= ${#file_hex} )); then
                        multi_byte_chars+=${file_hex:$((byte_index+2)):2}
                        # 安全地转换2字节UTF-8字符
                        multi_byte_text=$(printf "\\x${multi_byte_chars:0:2}\\x${multi_byte_chars:2:2}")
                        byte_index=$((byte_index+2))
                    else
                        valid_utf8=false
                    fi
                elif (( (byte_dec & 0xF0) == 0xE0 )); then  # 3字节字符
                    if (( byte_index + 4 <= ${#file_hex} )); then
                        multi_byte_chars+=${file_hex:$((byte_index+2)):2}${file_hex:$((byte_index+4)):2}
                        # 安全地转换3字节UTF-8字符
                        multi_byte_text=$(printf "\\x${multi_byte_chars:0:2}\\x${multi_byte_chars:2:2}\\x${multi_byte_chars:4:2}")
                        byte_index=$((byte_index+4))
                        
                        # 检查是否是零宽字符
                        if [[ "$multi_byte_chars" == "e2808b" || "$multi_byte_chars" == "e2808c" || "$multi_byte_chars" == "e2808d" ]]; then
                            echo -e "$current_line\t$current_char_pos\tUTF-8\t零宽字符\t$current_line_text[零宽字符]" >> "$temp_file"
                            has_invisible_chars=true
                            line_has_invisible=true
                            ((invisible_count++))
                        fi
                    else
                        valid_utf8=false
                    fi
                elif (( (byte_dec & 0xF8) == 0xF0 )); then  # 4字节字符
                    if (( byte_index + 6 <= ${#file_hex} )); then
                        multi_byte_chars+=${file_hex:$((byte_index+2)):2}${file_hex:$((byte_index+4)):2}${file_hex:$((byte_index+6)):2}
                        # 安全地转换4字节UTF-8字符
                        multi_byte_text=$(printf "\\x${multi_byte_chars:0:2}\\x${multi_byte_chars:2:2}\\x${multi_byte_chars:4:2}\\x${multi_byte_chars:6:2}")
                        byte_index=$((byte_index+6))
                    else
                        valid_utf8=false
                    fi
                fi
                
                if $valid_utf8; then
                    current_line_text+="$multi_byte_text"
                else
                    # 无效的UTF-8序列，按单字节处理
                    current_line_text+="[无效UTF-8:0x$byte_hex]"
                fi
            fi
            
            ((current_char_pos++))
        fi
        
        byte_index=$((byte_index+2))
    done
    
    # 处理最后一行（如果文件不以换行符结尾）
    if [[ -n "$current_line_text" ]]; then
        ((current_line++))
    fi
    
    # 重置行是否有不可见字符的标志
    line_has_invisible=false
    
    # 输出结果
    if $has_invisible_chars; then
        echo "\n检测到不可见字符的位置和类型："
        echo "----------------------------------------"
        column -t -s $'\t' "$temp_file"
        echo "----------------------------------------"
        echo "总计找到 $invisible_count 个不可见字符，分布在 $line_with_invisible_count 行中"
    else
        echo "\n文件中未检测到不可见字符。"
    fi
    
    # 调试信息：显示文件的十六进制表示
    echo "\n调试信息：文件前100字节的十六进制表示："
    echo "$file_hex" | fold -w 40 | head -5
    
    # 清理临时文件
    rm -f "$temp_file"
}

# 函数：移除文件中的不可见字符
remove_invisible_chars() {
    local file_path=$1
    local output_path=$2
    
    echo "正在移除文件 '$file_path' 中的不可见字符..."
    
    # 创建临时文件处理中间结果
    local temp_processed=$(mktemp)
    local temp_result=$(mktemp)
    
    # 步骤1: 检测并移除BOM标记
    local has_bom=false
    local temp_bom=$(mktemp)
    echo -ne "\xef\xbb\xbf" > "$temp_bom"
    head -c 3 "$file_path" | cmp -s - "$temp_bom" && has_bom=true
    rm -f "$temp_bom"
    
    if $has_bom; then
        tail -c +4 "$file_path" > "$temp_processed"
    else
        cp "$file_path" "$temp_processed"
    fi
    
    # 步骤2: 使用tr命令移除所有不可见控制字符（包括制表符、回车符等）
    # 使用八进制表示确保兼容性，同时不会影响UTF-8多字节字符（如中文）
    tr -d '\000\001\002\003\004\005\006\007\010\011\012\013\014\015\016\017\020\021\022\023\024\025\026\027\030\031\032\033\034\035\036\037\177' < "$temp_processed" > "$temp_result"
    
    # 步骤3: 特殊处理零宽字符（多字节UTF-8字符）
    # 使用sed的二进制模式处理多字节字符，只移除特定的零宽字符，保留正常的UTF-8字符（如中文）
    LC_CTYPE=C sed -E -e 's/\xE2\x80\x8B//g' -e 's/\xE2\x80\x8C//g' -e 's/\xE2\x80\x8D//g' < "$temp_result" > "$output_path"
    
    # 检查操作是否成功
    if [[ $? -eq 0 ]]; then
        echo "成功移除不可见字符，结果保存到 '$output_path'"
        echo "原文件大小: $(du -h "$file_path" | cut -f1)"
        echo "处理后文件大小: $(du -h "$output_path" | cut -f1)"
    else
        echo "错误：移除不可见字符时发生错误" >&2
        rm -f "$temp_processed" "$temp_result"
        exit 4
    fi
    
    # 清理临时文件
    rm -f "$temp_processed" "$temp_result"
}

# 主函数
main() {
    if $detailed_mode; then
        detect_invisible_chars_detailed "$file_path"
    else
        detect_invisible_chars_fast "$file_path"
    fi
    
    if $remove_mode; then
        # 如果没有指定输出文件，使用原文件名加_clean后缀
        if [[ -z "$output_file" ]]; then
            output_file="${file_path%.txt}_clean.txt"
            # 如果原文件没有.txt后缀，直接加_clean
            if [[ "$output_file" == "${file_path}_clean.txt" ]]; then
                output_file="${file_path}_clean"
            fi
        fi
        
        remove_invisible_chars "$file_path" "$output_file"
    fi
}

# 执行主函数
main

exit 0