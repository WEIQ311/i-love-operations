#!/usr/bin/env bash
set -euo pipefail

# 用法:
#   ./dedupe_tgz.sh <父目录路径或名称>
#
# 说明:
# - 扫描 <父目录> 下所有子目录中的 .tgz 文件
# - 以文件内容哈希去重（不是按文件名）
# - 将去重后的文件复制到脚本同级目录下新建目录:
#   deduped_tgz_<父目录名>_<时间戳>

if [[ $# -ne 1 ]]; then
  echo "用法: $0 <父目录路径或名称>"
  exit 1
fi

INPUT_PARENT="$1"

# 允许传目录名或完整路径
if [[ -d "$INPUT_PARENT" ]]; then
  PARENT_DIR="$(cd "$INPUT_PARENT" && pwd)"
elif [[ -d "./$INPUT_PARENT" ]]; then
  PARENT_DIR="$(cd "./$INPUT_PARENT" && pwd)"
else
  echo "错误: 找不到父目录: $INPUT_PARENT"
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARENT_NAME="$(basename "$PARENT_DIR")"
TS="$(date +%Y%m%d_%H%M%S)"
OUT_DIR="${SCRIPT_DIR}/deduped_tgz_${PARENT_NAME}_${TS}"

mkdir -p "$OUT_DIR"

declare -A SEEN_HASH
TOTAL=0
UNIQUE=0
DUP=0

echo "开始扫描: $PARENT_DIR"
echo "输出目录: $OUT_DIR"

# 读取所有 .tgz 文件（递归）
while IFS= read -r -d '' FILE; do
  ((TOTAL+=1))

  HASH="$(sha256sum "$FILE" | awk '{print $1}')"

  if [[ -n "${SEEN_HASH[$HASH]:-}" ]]; then
    ((DUP+=1))
    continue
  fi

  SEEN_HASH["$HASH"]="$FILE"
  ((UNIQUE+=1))

  BASENAME="$(basename "$FILE")"
  TARGET="${OUT_DIR}/${BASENAME}"

  # 若同名文件已存在（但内容不同），追加短哈希避免覆盖
  if [[ -e "$TARGET" ]]; then
    TARGET="${OUT_DIR}/${HASH:0:12}_${BASENAME}"
  fi

  cp -p "$FILE" "$TARGET"
done < <(find "$PARENT_DIR" -type f -name "*.tgz" -print0)

echo "完成"
echo "总文件数: $TOTAL"
echo "去重后数量: $UNIQUE"
echo "重复数量: $DUP"
echo "结果目录: $OUT_DIR"
