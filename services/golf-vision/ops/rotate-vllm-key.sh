#!/bin/bash
# Xoay khoá vLLM trên máy A100 — một lượt, có backup và kiểm chứng.
#
#   bash rotate-vllm-key.sh --dry-run   # chỉ liệt kê file giữ khoá, không đụng gì
#   bash rotate-vllm-key.sh             # xoay thật
#
# Khoá cũ nằm rải trong compose của vnpt-iplace, config LiteLLM và
# /root/golfseg/.gemma.env. Trình tự: thay khoá trong file trước, rồi dựng lại
# vLLM với khoá mới (~6 phút nạp model 26B), rồi khởi động lại các consumer.
# Trong 6 phút đó mọi lời gọi LLM của iplace sẽ lỗi — không cách xoay nào tránh
# được khoảng này vì vLLM phải nạp lại model.
#
# Danh sách file được TÌM chứ không chép cứng. Bản đầu tiên của script này chép
# cứng bảy đường dẫn, trong đó có `docker-compose.override.example.yaml` mà
# không có `docker-compose.override.yaml` — đúng file mà bước 3 truyền cho
# `docker compose up -d`. Xoay theo danh sách đó sẽ dựng lại fleet iplace bằng
# một file vẫn giữ khoá cũ: cả tám container lên với khoá đã bị thu hồi, và
# triệu chứng (401 hàng loạt) trông y hệt một lần xoay hỏng. Máy tự tìm thì
# không quên file nào.
#
# Đường lùi: mọi file sửa đều có bản .bak-rotate-<ngày> bên cạnh, khoá cũ ghi ở
# /root/golfseg/.vllm-key.old (600). Muốn lùi: đảo từng file từ .bak rồi chạy
# lại bước 2 và 3 bên dưới.
set -euo pipefail

MODE="${1:-}"
STAMP="bak-rotate-$(date +%Y%m%d)"
IPLACE=/data/vnpt-iplace-mt
# Nơi khoá từng được tìm thấy, cộng thư mục của golfseg. Thêm đường dẫn vào đây
# nếu một consumer mới xuất hiện.
SEARCH_ROOTS="$IPLACE /root/litellm /opt/litellm /opt/litllm /root/golfseg"

OLD=$(grep -oE 'POrie29a[A-Za-z0-9]+' /root/golfseg/.gemma.env | head -1)
[ -n "$OLD" ] || { echo "Không tìm thấy khoá cũ trong .gemma.env — dừng."; exit 1; }

# -I bỏ qua file nhị phân, --exclude bỏ qua chính các bản backup của lần trước.
find_holders() {
  grep -rlIF --exclude="*.bak-rotate-*" --exclude-dir=.git -- "$OLD" \
    $SEARCH_ROOTS 2>/dev/null | sort -u || true
}

# Các file compose dùng cho `up -d` ở bước 3 — chỉ những file thật sự có mặt.
compose_args() {
  local args=""
  local f
  for f in docker-compose.microservices.yaml docker-compose.override.yaml; do
    [ -f "$IPLACE/$f" ] && args="$args -f $f"
  done
  echo "$args"
}

FILES=$(find_holders)
COMPOSE_ARGS=$(compose_args)

if [ -z "$FILES" ]; then
  echo "Không file nào chứa khoá cũ — có thể đã xoay rồi. Dừng."
  exit 1
fi

echo "== File đang giữ khoá cũ (${#OLD} ký tự, không in ra):"
echo "$FILES" | sed 's/^/   /'
echo "== Bước 3 sẽ chạy: docker compose$COMPOSE_ARGS up -d  (trong $IPLACE)"

if [ "$MODE" = "--dry-run" ]; then
  echo "== DRY RUN: không sửa file, không đụng container."
  exit 0
fi

NEW=$(openssl rand -hex 20)
umask 077
echo "$OLD" > /root/golfseg/.vllm-key.old

echo "== 1. Thay khoá trong các file trên"
while IFS= read -r f; do
  [ -n "$f" ] || continue
  cp -p "$f" "$f.$STAMP"
  sed -i "s/$OLD/$NEW/g" "$f"
  echo "   đã thay: $f"
done <<< "$FILES"

REMAINING=$(find_holders)
if [ -n "$REMAINING" ]; then
  echo "!! Khoá cũ vẫn còn trong:"
  echo "$REMAINING" | sed 's/^/   /'
  echo "!! Dừng trước khi đụng container."
  exit 1
fi

echo "== 2. Dựng lại vLLM với khoá mới (nạp model ~6 phút)"
docker rm -f gemma4-awq-vllm
bash /root/golfseg/gemma-run.original.sh
code=""
for i in $(seq 1 60); do
  code=$(curl -s -o /dev/null -w '%{http_code}' -m 5 \
    -H "Authorization: Bearer $NEW" http://127.0.0.1:8000/v1/models || true)
  [ "$code" = 200 ] && { echo "   vLLM sống với khoá mới sau ~$((i*10))s"; break; }
  sleep 10
done
[ "$code" = 200 ] || { echo "!! vLLM không lên sau 10 phút — xem docker logs gemma4-awq-vllm"; exit 1; }
oldcode=$(curl -s -o /dev/null -w '%{http_code}' -m 5 \
  -H "Authorization: Bearer $OLD" http://127.0.0.1:8000/v1/models || true)
echo "   khoá cũ giờ trả: HTTP $oldcode (mong đợi 401)"

echo "== 3. Khởi động lại các consumer"
docker restart litellm
cd "$IPLACE" && docker compose $COMPOSE_ARGS up -d
sleep 20

echo "== 4. Trạng thái consumer"
docker ps --format '{{.Names}} {{.Status}}' | grep -E 'iplace|litellm' | head -12

echo "== XONG. Khoá mới nằm trong các file trên và .gemma.env."
echo "   Khoá cũ lưu ở /root/golfseg/.vllm-key.old — xoá sau khi mọi thứ chạy ổn vài ngày."
