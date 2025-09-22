#!/bin/bash

# 添加入参说明和检测
if [ $# -lt 13 ]; then
  echo "Usage: $0 <userName> <password> <hostName> <httpPort> <owner> <tableNames> <maxFilterRatio> <separator> <ignoreLines> <timeOut> <fieldEncloseCharacter> <columnsString> <files>"
  exit 1
fi

# 从入参数获取参数
userName=${1:-"root"}
password=${2:-""}
hostName=${3:-""}
httpPort=${4:-8030}
owner=${5:-""}
tableNames=${6:-""}
maxFilterRatio=${7:-0}
separator=${8:-"|#|"}
ignoreLines=${9:-0}
timeOut=${10:-30000}
fieldEncloseCharacter=${11:-"'"}
columnsString=${12:-""}
files=${13:-""}

# 检测columnsString是否为空
if [ -z "$columnsString" ] || [ -z "$tableNames" ] || [ -z "$owner" ]; then
  echo "错误: columnsString, tableNames, owner 不能为空"
  exit 1
fi
# 检测文件是否存在
if [ ! -f "$files" ]; then
  echo "错误: 文件 '$files' 不存在"
  exit 1
fi
echo "最大错误比例: $maxFilterRatio"
echo "超时: $timeOut"
echo "分隔符: $separator,字段包裹字符: $fieldEncloseCharacter"

#协议类型
if [[ $hostName == *"181"* || $hostName == *"244"* ]]; then
  protocol="http"
  apiPort=${httpPort:-8030}
else
  protocol="https"
  apiPort=${httpPort:-29991}
fi

# 执行curl命令并捕获结果
doris_res=$(curl -s -k --location-trusted \
  -u "${userName}:${password}" \
  -H "Expect:100-continue" \
  -H "max_filter_ratio:${maxFilterRatio}" \
  -H "column_separator:${separator}" \
  -H "skip_lines:${ignoreLines}" \
  -H "timeout:${timeOut}" \
  -H "enclose:${fieldEncloseCharacter}" \
  -H "escape:${fieldEncloseCharacter}" \
  -H "columns:${columnsString}" \
  -T ${files} \
  -XPUT \
  ${protocol}://${hostName}:${apiPort}/api/${owner}/${tableNames}/_stream_load
)

# 检查curl命令是否成功执行
if [ $? -ne 0 ]; then
  echo "错误: curl命令执行失败"
  exit 1
fi

# 打印完整响应
echo "完整响应:"
echo "$doris_res"

# 解析并处理响应状态
status=$(echo "$doris_res" | jq -r '.Status')

# 检查jq命令是否成功执行
if [ $? -ne 0 ]; then
  echo "错误: 无法解析响应内容"
  echo "原始响应: $doris_res"
  exit 1
fi

# 根据状态处理结果
if [ "$status" == "Fail" ]; then
  echo "请求失败，状态: $status"
  # 输出详细错误信息
  error_msg=$(echo "$doris_res" | jq -r '.Message')
  echo "错误信息: $error_msg"
  exit 1
else
  echo "请求成功，状态: $status"
  # 可选：输出成功详情
  if [ "$status" == "Success" ]; then
    load_bytes=$(echo "$doris_res" | jq -r '.NumberTotalRows')
    echo "加载行数: $load_bytes"
  fi
  exit 0
fi

 # 示例用法：
 # ./doris_stream_load.sh root "root" 192.168.1.181 8030 doris_test doris_test_table 0.5 "|#|" 0 30000 "'" "column1,column2,column3" doris_test_table.csv