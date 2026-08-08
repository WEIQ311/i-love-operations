#!/bin/bash

# Java服务内存占用统计脚本
# 此脚本用于统计Linux系统中所有Java进程的内存占用情况和服务名称
# 特别处理：jar包显示jar名称，tomcat显示bin上层文件夹名称

# 开启调试模式（设置为true启用调试输出）
DEBUG_MODE=false

# 输出调试信息的函数
debug() {
    if [ "$DEBUG_MODE" = "true" ]; then
        echo "[DEBUG] $1" >&2
    fi
}

# 获取并显示系统总体资源使用情况
# 1. 获取内存使用情况
total_memory=$(free -m | awk '/^Mem:/ {print $2}')
used_memory=$(free -m | awk '/^Mem:/ {print $3}')
free_memory=$(free -m | awk '/^Mem:/ {print $4}')
buffer_cache=$(free -m | awk '/^Mem:/ {print $6+$7}')
memory_percent=$(echo "scale=2; $used_memory / $total_memory * 100" | bc 2>/dev/null || echo "0.00")

# 2. 获取交换空间使用情况
total_swap=$(free -m | awk '/^Swap:/ {print $2}')
used_swap=$(free -m | awk '/^Swap:/ {print $3}')
free_swap=$(free -m | awk '/^Swap:/ {print $4}')
swap_percent="0.00"
if [[ "$total_swap" =~ ^[0-9]+$ ]] && [ "$total_swap" -gt 0 ]; then
    swap_percent=$(echo "scale=2; $used_swap / $total_swap * 100" | bc 2>/dev/null || echo "0.00")
fi

# 3. 获取CPU使用率（改进版，使用多种方法确保准确性）
# 方法1: 使用top命令获取总体CPU使用率
cpu_percent_method1=$(top -bn2 -d 0.2 | grep "Cpu(s)" | tail -1 | awk -F'["%]+' '{print $2}')

# 方法2: 使用mpstat命令获取（如果系统支持）
cpu_percent_method2="0.00"
if command -v mpstat >/dev/null 2>&1; then
    cpu_percent_method2=$(mpstat 1 1 | awk '/Average:/ {print 100 - $12}' | cut -c1-5)
fi

# 选择有效的CPU使用率值
cpu_percent="0.00"
if [[ "$cpu_percent_method1" =~ ^[0-9.]+$ ]] && (( $(echo "$cpu_percent_method1 > 0" | bc -l) )); then
    cpu_percent=$cpu_percent_method1
elif [[ "$cpu_percent_method2" =~ ^[0-9.]+$ ]] && (( $(echo "$cpu_percent_method2 > 0" | bc -l) )); then
    cpu_percent=$cpu_percent_method2
fi

# 确保是有效的数值
if ! [[ "$cpu_percent" =~ ^[0-9.]+$ ]]; then
    cpu_percent="0.00"
fi

# 获取CPU核心数
cpu_cores=$(grep -c '^processor' /proc/cpuinfo 2>/dev/null || echo 1)

# 获取负载均衡情况（负载/核心数）
load_per_core="0.00"
if [ "$cpu_cores" -gt 0 ] && [[ "$system_load" =~ ^([0-9.]+), ]]; then
    one_min_load=${BASH_REMATCH[1]}
    load_per_core=$(echo "scale=2; $one_min_load / $cpu_cores" | bc 2>/dev/null || echo "0.00")
fi

# 4. 获取系统负载（1分钟、5分钟、15分钟）
system_load=$(uptime | awk -F'load average:' '{print $2}' | tr -d ' ') || echo "0.00, 0.00, 0.00"

# 5. 获取总线程数和总进程数
total_threads=$(ps -eLf | wc -l)
total_processes=$(ps -ef | wc -l)

# 6. 获取Java进程数量（提前计算）
java_process_count=$(ps -ef | grep -i java | grep -v grep | wc -l)

# 输出系统总体资源使用情况 - 表格形式输出
echo "==========================================================================================================================="
echo "|                                                    系统资源总览                                                          |"
echo "==========================================================================================================================="

# 内存信息表格
echo "| 总内存       | 已用内存     | 空闲内存     | 缓存         | 内存占比    |"
echo "|--------------|--------------|--------------|--------------|-------------|"
printf "| %-12s | %-12s | %-12s | %-12s | %-11s |\n" "$total_memory MB" "$used_memory MB" "$free_memory MB" "$buffer_cache MB" "$memory_percent%"

echo "|--------------|--------------|--------------|--------------|-------------|"
# 交换空间信息表格
echo "| 交换总量     | 已用交换     | 空闲交换     | 交换占比     | CPU使用率   |"
echo "|--------------|--------------|--------------|--------------|-------------|"
printf "| %-12s | %-12s | %-12s | %-12s | %-11s |\n" "$total_swap MB" "$used_swap MB" "$free_swap MB" "$swap_percent%" "$cpu_percent%"

echo "|--------------|--------------|--------------|--------------|--------------|---------------|"
# 系统负载和进程信息表格
echo "|    系统负载   |    总进程数  | 总线程数     | Java进程数   | CPU核心数    | 负载/核心数    |"
echo "|---------------|--------------|--------------|--------------|--------------|---------------|"
printf "| %-12s | %-12s | %-12s | %-12s | %-12s | %-13s |\n" "$system_load" "$total_processes" "$total_threads" "$java_process_count" "$cpu_cores" "$load_per_core"
echo "==========================================================================================================================="

# 设置输出格式（表头）
echo -e "PID\t\t内存占用\t\t内存占比\t\tCPU使用率\t线程数\t\t服务名称"
echo "==========================================================================================================================="

# 查找所有Java进程并统计内存占用
# 使用ps命令的不同格式，确保能捕获所有java进程
java_processes=$(ps -ef | grep -i java | grep -v grep)

# 检查是否有Java进程
if [ -z "$java_processes" ]; then
    echo -e "\t\t\t\t\t\t无Java进程运行"
    echo "==========================================================================================================================="
    echo "统计完成：共显示 0 个Java进程"
    echo "提示：内存占用基于RSS（常驻集大小）统计，不包括交换空间使用。"
    exit 0
fi

# 创建临时数组存储处理后的进程信息
declare -a process_info_array

# 逐行处理Java进程
process_count=0
while IFS= read -r line; do
    # 提取PID、RSS和内存占比信息
    pid=$(echo "$line" | awk '{print $2}')
    cmd="$line"
    
    # 单独获取RSS、%MEM和%CPU信息，使用更可靠的方式
    mem_info=$(ps -o rss,%mem,%cpu -p $pid 2>/dev/null | tail -n 1)
    rss=$(echo "$mem_info" | awk '{print $1}')
    mem_percent=$(echo "$mem_info" | awk '{print $2}')
    cpu_percent=$(echo "$mem_info" | awk '{print $3}')
    
    # 获取线程数信息
    threads=$(ps -o nlwp= -p $pid 2>/dev/null || echo 0)
    
    debug "原始命令行: $cmd"
    debug "PID: $pid, RSS: $rss, MEM_PERCENT: $mem_percent, CPU_PERCENT: $cpu_percent, THREADS: $threads"
    
    # 修复bc命令计算内存占用（转换为MB），添加防御性检查
    if [[ "$rss" =~ ^[0-9]+$ ]]; then
        mem_mb=$(echo "scale=2; $rss / 1024" | bc 2>/dev/null || echo "0.00")
    else
        mem_mb="0.00"
    fi
    
    # 修复内存占比显示，确保是有效的数值
    if ! [[ "$mem_percent" =~ ^[0-9.]+$ ]]; then
        mem_percent="0.00"
    fi
    
    # 确保CPU使用率是有效的数值
    if ! [[ "$cpu_percent" =~ ^[0-9.]+$ ]]; then
        cpu_percent="0.00"
    fi
    
    # 确保线程数是有效的数值
    if ! [[ "$threads" =~ ^[0-9]+$ ]]; then
        threads="0"
    fi
    
    # 提取服务名称（按照优先级处理）
    service_name=""
    is_tomcat=false
    is_jar=false
    
    # 1. 优先检查是否为Tomcat进程 - 增强识别逻辑
    if echo "$cmd" | grep -q -E 'catalina\.base|catalina\.home|tomcat|org\.apache\.catalina\.startup\.Bootstrap|org\.apache\.catalina|catalina\.out' || \
       [ -d "/proc/$pid/cwd/../webapps" ] || [ -d "/proc/$pid/cwd/webapps" ] || \
       ls -l "/proc/$pid/exe" 2>/dev/null | grep -q 'tomcat'; then
        is_tomcat=true
        debug "进程$pid 识别为Tomcat"
        # 提取bin上层文件夹名称 - 增强路径获取逻辑
        # 尝试从catalina.base参数获取
        catalina_base=$(echo "$cmd" | grep -oP 'catalina\.base=([^\s]+)' | cut -d'=' -f2)
        if [ -n "$catalina_base" ]; then
            # catalina.base是tomcat的安装目录
            service_name="Tomcat: $(basename "$catalina_base")"
        else
            # 尝试从catalina.home参数获取
            catalina_home=$(echo "$cmd" | grep -oP 'catalina\.home=([^\s]+)' | cut -d'=' -f2)
            if [ -n "$catalina_home" ]; then
                service_name="Tomcat: $(basename "$catalina_home")"
            else
                # 尝试从java命令的工作目录推断
                cwd=$(readlink -f "/proc/$pid/cwd" 2>/dev/null || echo "")
                if [ -n "$cwd" ]; then
                    # 检查当前目录或上层目录是否包含webapps等tomcat特征目录
                    if [[ "$cwd" == *"bin"* ]]; then
                        # 如果当前目录是bin目录，则取上层目录名
                        tomcat_dir=$(dirname "$cwd")
                        service_name="Tomcat: $(basename "$tomcat_dir")"
                    elif [ -d "$cwd/../webapps" ]; then
                        service_name="Tomcat: $(basename "$(dirname "$cwd")")"
                    elif [ -d "$cwd/webapps" ]; then
                        service_name="Tomcat: $(basename "$cwd")"
                    else
                        # 尝试从命令行中提取可能的目录路径
                        tomcat_path=$(echo "$cmd" | grep -oP '\-Dcatalina\.base=([^\s]+)|\-Dcatalina\.home=([^\s]+)' | head -1 | cut -d'=' -f2)
                        if [ -n "$tomcat_path" ]; then
                            service_name="Tomcat: $(basename "$tomcat_path")"
                        else
                            service_name="Tomcat"
                        fi
                    fi
                else
                    service_name="Tomcat"
                fi
            fi
        fi
    fi
    
    # 2. 检查是否为jar包运行的进程 - 全面增强识别逻辑（如果不是Tomcat）
    if [ "$is_tomcat" = "false" ]; then
        # 扩展jar包识别关键字，覆盖更多可能的启动方式
        if echo "$cmd" | grep -q -E '\.jar|\-jar|spring\-boot|jar\.launcher|executable\.jar|springframework\.boot\.loader|java\.util\.jar|jarfile' || \
           ls -l "/proc/$pid/fd" 2>/dev/null | grep -q '\.jar' || \
           ([ -f "/proc/$pid/cwd" ] && cwd_path="$(readlink -f "/proc/$pid/cwd")" && [ -n "$cwd_path" ] && find "$cwd_path" -maxdepth 1 -name "*.jar" | grep -q "."); then
            is_jar=true
            debug "进程$pid 识别为Jar包"
            
            # 提取jar包名称 - 全面增强jar名称提取逻辑，共12种方法
            # 方法1: 直接提取-jar参数后的jar文件名，考虑多种可能的空格和引号情况
            service_name=$(echo "$cmd" | grep -oP '(\-jar|\-cp|\-classpath)\s+["\x27]?([^"\x27\s]+\.jar)' | sed -e 's/^.*\s+//' -e 's/["\x27]$//' | xargs basename 2>/dev/null)
            debug "方法1: $service_name"
            
            # 方法2: 如果方法1失败，尝试提取任何.jar结尾的文件名（包括路径中的）
            if [ -z "$service_name" ]; then
                service_name=$(echo "$cmd" | grep -oP '[^\s"\x27]+\.jar[^\s"\x27]*' | head -1 | xargs basename 2>/dev/null)
                debug "方法2: $service_name"
            fi
            
            # 方法3: 尝试从classpath中查找jar文件
            if [ -z "$service_name" ]; then
                service_name=$(echo "$cmd" | grep -oP '\-cp\s+[^\s]*\.jar' | grep -oP '[^/\s]+\.jar' | head -1 2>/dev/null)
                debug "方法3: $service_name"
            fi
            
            # 方法4: 尝试从-classpath参数查找
            if [ -z "$service_name" ]; then
                service_name=$(echo "$cmd" | grep -oP '\-classpath\s+[^\s]*\.jar' | grep -oP '[^/\s]+\.jar' | head -1 2>/dev/null)
                debug "方法4: $service_name"
            fi
            
            # 方法5: 尝试从进程工作目录中的jar文件推断
            if [ -z "$service_name" ]; then
                cwd=$(readlink -f "/proc/$pid/cwd" 2>/dev/null || echo "")
                if [ -n "$cwd" ]; then
                    # 查找工作目录下的jar文件，按修改时间排序取最新的
                    latest_jar=$(ls -1t "$cwd"/*.jar 2>/dev/null | head -1)
                    if [ -n "$latest_jar" ]; then
                        service_name="$(basename "$latest_jar")"
                        debug "方法5: $service_name"
                    fi
                fi
            fi
            
            # 方法6: 尝试从进程打开的文件描述符中查找
            if [ -z "$service_name" ]; then
                jar_file=$(ls -l "/proc/$pid/fd" 2>/dev/null | grep -E '\.jar|java\.library\.path' | awk -F'->' '{print $2}' | grep -oP '[^/\s]+\.jar' | head -1 2>/dev/null)
                if [ -n "$jar_file" ]; then
                    service_name="$jar_file"
                    debug "方法6: $service_name"
                fi
            fi
            
            # 方法7: 尝试从java命令中提取可能的应用标识
            if [ -z "$service_name" ]; then
                app_id=$(echo "$cmd" | grep -oP '\-Dapp\.name=([^\s,]+)|\-Dapplication\.name=([^\s,]+)|\-Dspring\.application\.name=([^\s,]+)' | cut -d'=' -f2 | head -1 2>/dev/null)
                if [ -n "$app_id" ]; then
                    service_name="App: $app_id"
                    debug "方法7: $service_name"
                fi
            fi
            
            # 方法8: 尝试从Spring Boot相关参数提取
            if [ -z "$service_name" ] && echo "$cmd" | grep -q 'spring'; then
                spring_app=$(echo "$cmd" | grep -oP 'spring\.application\.name=([^,\s]+)' | cut -d'=' -f2 | head -1 2>/dev/null)
                if [ -n "$spring_app" ]; then
                    service_name="SpringBoot: $spring_app"
                else
                    service_name="Spring Boot App"
                fi
                debug "方法8: $service_name"
            fi
            
            # 方法9: 如果所有方法都失败，检查命令行中是否包含.jar并尝试提取
            if [ -z "$service_name" ] && echo "$cmd" | grep -q '\.jar'; then
                # 提取第一个.jar相关的文件名
                possible_jar=$(echo "$cmd" | grep -oP '[^\s]*\.jar[^\s]*' | head -1)
                if [ -n "$possible_jar" ]; then
                    # 清理可能的参数和引号
                    clean_jar=$(echo "$possible_jar" | sed -e 's/["\x27]//g' -e 's/\s.*$//')
                    service_name="$(basename "$clean_jar")"
                    debug "方法9: $service_name"
                fi
            fi
            
            # 方法10: 尝试从进程启动时间和工作目录匹配jar文件
            if [ -z "$service_name" ]; then
                cwd=$(readlink -f "/proc/$pid/cwd" 2>/dev/null || echo "")
                if [ -n "$cwd" ]; then
                    # 查找工作目录中最近被访问的jar文件
                    recent_jar=$(find "$cwd" -maxdepth 1 -name "*.jar" -type f -printf "%T@ %p\n" 2>/dev/null | sort -n -r | head -1 | cut -d' ' -f2-)
                    if [ -n "$recent_jar" ]; then
                        service_name="$(basename "$recent_jar")"
                        debug "方法10: $service_name"
                    fi
                fi
            fi
            
            # 方法11: 尝试从进程的cmdline文件中读取更完整的命令行
            if [ -z "$service_name" ]; then
                cmdline=$(cat "/proc/$pid/cmdline" 2>/dev/null | tr '\0' ' ')
                if [ -n "$cmdline" ]; then
                    jar_name=$(echo "$cmdline" | grep -oP '\-jar\s+["\x27]?([^"\x27\s]+\.jar)' | sed -e 's/^-jar\s\+["\x27]\?//' -e 's/["\x27]$//' | xargs basename 2>/dev/null)
                    if [ -n "$jar_name" ]; then
                        service_name="$jar_name"
                        debug "方法11: $service_name"
                    fi
                fi
            fi
            
            # 方法12: 检查是否有java -jar的启动模式
            if [ -z "$service_name" ]; then
                if echo "$cmd" | grep -q 'java' && echo "$cmd" | grep -q '\.jar'; then
                    # 尝试直接提取.jar文件名
                    jar_name=$(echo "$cmd" | grep -oP '[^/\s]+\.jar' | head -1)
                    if [ -n "$jar_name" ]; then
                        service_name="$jar_name"
                        debug "方法12: $service_name"
                    fi
                fi
            fi
            
            # 如果所有方法都失败，设置默认名称
            if [ -z "$service_name" ]; then
                service_name="Jar Application"
                debug "默认jar名称"
            fi
        fi
    fi
    
    # 3. 其他Java进程
    if [ "$is_tomcat" = "false" ] && [ "$is_jar" = "false" ]; then
        debug "进程$pid 识别为其他Java进程"
        # 尝试从main类提取
        main_class=$(echo "$cmd" | grep -oP '\-cp.*?\s+([^\s]+\.[^\s]+)' | awk '{print $NF}' | head -1)
        if [ -n "$main_class" ]; then
            service_name="Java: $main_class"
        else
            # 尝试从命令行参数提取其他标识信息
            app_name=$(echo "$cmd" | grep -oP '\-Dapp\.name=([^\s]+)|\-Dapplication\.name=([^\s]+)|\-Dspring\.application\.name=([^\s]+)' | cut -d'=' -f2 | head -1)
            if [ -n "$app_name" ]; then
                service_name="Java: $app_name"
            else
                service_name="Java Process"
                debug "无法识别的Java进程"
            fi
        fi
    fi
    
    # 限制服务名长度，避免输出混乱
    service_name=$(echo "$service_name" | cut -c1-80)
    
    # 将进程信息保存到数组中，格式: "mem_percent mem_mb PID cpu_percent threads service_name"
    # 使用mem_percent作为排序键
    process_info_array+=("$mem_percent $mem_mb $pid $cpu_percent $threads $service_name")
    process_count=$((process_count+1))
done <<< "$java_processes"

# 对进程信息按内存使用率由大到小排序并输出
printf "%s\n" "${process_info_array[@]}" | sort -k1 -nr -t ' ' | while read -r mem_percent mem_mb pid cpu_percent threads service_name; do
    echo -e "$pid\t\t${mem_mb} MB\t\t${mem_percent}%\t\t\t${cpu_percent}%\t\t$threads\t\t$service_name"
done

# 脚本结束标记
echo "==========================================================================================================================="
echo "统计完成：共显示 $process_count 个Java进程"
echo "提示：内存占用基于RSS（常驻集大小）统计，不包括交换空间使用。CPU使用率和线程数基于ps命令统计。"
# 调试信息提示
if [ "$DEBUG_MODE" = "false" ]; then
    echo "提示：如需查看详细调试信息，请将脚本中的DEBUG_MODE设置为true。"
fi