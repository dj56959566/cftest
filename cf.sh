#!/bin/bash
# ====================================================
# VPS Cloudflare IPv4 优选 - HKG, SIN 数据中心
# 作者: ChatGPT
# ====================================================

WORK_DIR="/opt/cf_auto"
CFST="$WORK_DIR/cfst"
IPV4_FILE="$WORK_DIR/ip.txt"
RESULT_CSV="$WORK_DIR/result_ipv4.csv"

CF_API_TOKEN="xxxx"       # 按实际填写cfapi
CF_ZONE_ID="xxxxx"        # 按实际填写区域id
CF_RECORD_NAME="xx.xx.kg"    # 按实际填写要邦定的解释域或

CF_COLO="SIN"
LOG="$WORK_DIR/log.txt"

mkdir -p "$WORK_DIR"

# ====================================================
# IPv4 HTTPing 测速（HKG, SIN）
# ====================================================
echo "$(date '+%F %T') 开始 IPv4 HTTPing 测速（${CF_COLO}）..." | tee -a "$LOG"

$CFST -f "$IPV4_FILE" -dn 5 -t 3 -httping \
      -url https://cf.xiu2.xyz/url \
      -cfcolo "$CF_COLO" -o "$RESULT_CSV"

if [ ! -f "$RESULT_CSV" ]; then
    echo "IPv4 测速失败: 未生成结果文件" | tee -a "$LOG"
    exit 1
fi

# ====================================================
# 显示前5个节点及平均延迟
# ====================================================
echo "前5个 IPv4 节点:" | tee -a "$LOG"
awk -F, 'NR>1 && NR<=6 {print $1 " (" $2 ") 延迟:" $5 "ms"}' "$RESULT_CSV" | tee -a "$LOG"

# 提取前5个 IP
BEST_IPV4_ARRAY=($(awk -F, 'NR>1 && NR<=6 {print $1}' "$RESULT_CSV"))

# ====================================================
# 删除已有同名 A 记录
# ====================================================
old_ids=$(curl -s -X GET \
    "https://api.cloudflare.com/client/v4/zones/${CF_ZONE_ID}/dns_records?type=A&name=${CF_RECORD_NAME}" \
    -H "Authorization: Bearer ${CF_API_TOKEN}" \
    -H "Content-Type: application/json" | jq -r '.result[].id')

for id in $old_ids; do
    curl -s -X DELETE \
        "https://api.cloudflare.com/client/v4/zones/${CF_ZONE_ID}/dns_records/$id" \
        -H "Authorization: Bearer ${CF_API_TOKEN}" \
        -H "Content-Type: application/json" >/dev/null 2>&1
done

# ====================================================
# 添加同名多条 A 记录
# ====================================================
for ip in "${BEST_IPV4_ARRAY[@]}"; do
    curl -s -X POST \
        "https://api.cloudflare.com/client/v4/zones/${CF_ZONE_ID}/dns_records" \
        -H "Authorization: Bearer ${CF_API_TOKEN}" \
        -H "Content-Type: application/json" \
        --data "{
            \"type\": \"A\",
            \"name\": \"${CF_RECORD_NAME}\",
            \"content\": \"${ip}\",
            \"ttl\": 1,
            \"proxied\": false
        }" >/dev/null 2>&1

    echo "✅ 已添加 A 记录: ${CF_RECORD_NAME} -> $ip" | tee -a "$LOG"
done

# ====================================================
# 结束
# ====================================================
echo "$(date '+%F %T') VPS IPv4 优选完成" | tee -a "$LOG"

