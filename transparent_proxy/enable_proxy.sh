#!/bin/bash
# Filename: enable_proxy.sh
# Description: 透明代理一键配置脚本（支持 Docker 容器）
# Author: Fang Xiaolong
# Version: 2.1

set -e
exec 2> >(tee /var/log/enable_proxy.log) # 错误日志记录

# 颜色定义
RED='\033[31m'
GREEN='\033[32m'
YELLOW='\033[33m'
BLUE='\033[34m'
RESET='\033[0m'

# 配置参数
SOCKS_PORT=1080        # 本地 SOCKS5 代理端口
REDSOCKS_PORT=12345    # redsocks 监听端口
UPSTREAM_DNS="8.8.8.8" # 上游 DNS

# 检查 root 权限
check_root() {
  if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}✗ 必须使用 root 权限运行此脚本！${RESET}"
    exit 1
  fi
}

# 检查依赖命令
check_deps() {
  local deps=("iptables" "systemctl" "dig")
  for cmd in "${deps[@]}"; do
    if ! command -v "$cmd" &>/dev/null; then
      echo -e "${RED}✗ 缺失依赖命令: $cmd${RESET}"
      exit 1
    fi
  done
}

# 步骤打印函数
step() {
  echo -e "${BLUE}➜ $1${RESET}"
}

# 主要逻辑
main() {
  check_root
  check_deps

  step "1. 安装必要软件..."
  dnf install -y redsocks iptables socat dnsmasq || {
    echo -e "${RED}✗ 软件安装失败！${RESET}"
    exit 1
  }

  step "2. 关闭 systemd-resolved..."
  systemctl stop systemd-resolved 2>/dev/null || true
  systemctl disable systemd-resolved 2>/dev/null || true
  mv /etc/resolv.conf /etc/resolv.conf.bak 2>/dev/null || true  

  step "3. 配置内核参数..."
  sysctl -w net.ipv4.ip_forward=1
  sysctl -w net.ipv4.conf.all.route_localnet=1
  echo -e "net.ipv4.ip_forward=1\nnet.ipv4.conf.all.route_localnet=1" > /etc/sysctl.d/99-proxy.conf

  step "4. 配置 redsocks..."
  cat > /etc/redsocks.conf <<EOF
base {
    log_debug = off;
    log_info = on;
    log = "file:/var/log/redsocks.log";
    daemon = on;
    redirector = iptables;
    redsocks_conn_max = 65535;
}

redsocks {
    local_ip = 0.0.0.0;
    local_port = $REDSOCKS_PORT;
    type = socks5;
    ip = 127.0.0.1;
    port = $SOCKS_PORT;
}
EOF
  systemctl restart redsocks || {
    echo -e "${RED}✗ redsocks 启动失败！检查日志: journalctl -u redsocks${RESET}"
    exit 1
  }

  step "5. 配置 DNS 系统..."
  chattr -i /etc/resolv.conf 2>/dev/null || true
  echo -e "nameserver 127.0.0.1\noptions use-vc" > /etc/resolv.conf
  chattr +i /etc/resolv.conf

  step "6. 配置 dnsmasq..."
  cat > /etc/dnsmasq.conf <<EOF
no-resolv
server=$UPSTREAM_DNS
listen-address=127.0.0.1,172.17.0.1
proxy-dnssec
EOF
  systemctl restart dnsmasq || {
    echo -e "${RED}✗ dnsmasq 启动失败！检查日志: journalctl -u dnsmasq${RESET}"
    exit 1
  }

  step "7. 配置 iptables 规则..."
  # 清理旧规则
  iptables -t nat -F PROXY 2>/dev/null || true
  iptables -t nat -X PROXY 2>/dev/null || true

  # 创建新链
  iptables -t nat -N PROXY 2>/dev/null || true
  iptables -t nat -A OUTPUT -p tcp -j PROXY
  iptables -t nat -A OUTPUT -p udp -j PROXY
  iptables -t nat -I PREROUTING 1 -i docker0 -p tcp -j PROXY
  iptables -t nat -I PREROUTING 1 -i docker0 -p udp -j PROXY

  # 跳过保留地址
  local reserved_ips=(
    "0.0.0.0/8" "10.0.0.0/8" "127.0.0.0/8" "169.254.0.0/16"
    "172.16.0.0/12" "192.168.0.0/16" "224.0.0.0/4" "240.0.0.0/4" "23.224.152.105"
  )
  for ip in "${reserved_ips[@]}"; do
    iptables -t nat -A PROXY -d "$ip" -j RETURN
  done

  # 跳过关键端口
  iptables -t nat -A PROXY -p tcp --dport $SOCKS_PORT -j RETURN
  iptables -t nat -A PROXY -p tcp --dport $REDSOCKS_PORT -j RETURN
  iptables -t nat -A PROXY -p tcp --dport 53 -j RETURN
  iptables -t nat -A PROXY -p udp --dport 53 -j RETURN

  # 重定向其他 TCP/UDP 流量
  iptables -t nat -A PROXY -p tcp -j REDIRECT --to-port $REDSOCKS_PORT
  iptables -t nat -A PROXY -p udp -j REDIRECT --to-port $REDSOCKS_PORT

  step "8. 持久化配置..."
  iptables-save > /etc/sysconfig/iptables

  step "9. 最终检查..."
  if ! ss -tln | grep -q ":$REDSOCKS_PORT"; then
    echo -e "${RED}✗ redsocks 未监听 $REDSOCKS_PORT 端口！${RESET}"
    exit 1
  fi

  echo -e "\n${GREEN}✔ 透明代理配置成功！${RESET}"
  echo -e "测试命令:"
  echo -e "  curl -4 ifconfig.co    # 应显示代理服务器 IP"
  echo -e "  dig +short google.com  # 应返回 Google IP"
}

main "$@"
