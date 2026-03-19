#!/bin/bash
# 强制 OpenSSL 全局使用 TLS1.2 (禁用 TLS1.3)，幂等脚本
# 适配 Kylin V10 / RHEL8 系环境

set -e

CONF_FILE="/etc/pki/tls/openssl.cnf"
BACKUP_FILE="${CONF_FILE}.bak.$(date +%F-%H%M)"

if [[ ! -f "$CONF_FILE" ]]; then
  echo "未找到 $CONF_FILE，退出。"
  exit 1
fi

if grep -q '^openssl_conf *= *default_conf' "$CONF_FILE"; then
  echo "已经配置过 openssl_conf，无需重复修改。"
else
  echo "备份原文件到 $BACKUP_FILE"
  cp -av "$CONF_FILE" "$BACKUP_FILE"

  echo "追加 TLS1.2 配置到 $CONF_FILE"
  cat <<'EOF' | cat - "$CONF_FILE" > "${CONF_FILE}.new" && mv "${CONF_FILE}.new" "$CONF_FILE"
openssl_conf = default_conf

[default_conf]
ssl_conf = ssl_sect

[ssl_sect]
system_default = system_default_sect

[system_default_sect]
MinProtocol = TLSv1.2
MaxProtocol = TLSv1.2

EOF
  echo "配置已写入。"
fi

echo "验证 OpenSSL 协议版本..."
openssl s_client -connect pypi.org:443 -servername pypi.org </dev/null 2>&1 | grep Protocol || true