#!/bin/bash
set -e

# 恢复 systemd-resolved（如果之前被禁用）
sudo systemctl unmask systemd-resolved 2>/dev/null || true
sudo systemctl start systemd-resolved 2>/dev/null || true
sudo systemctl enable systemd-resolved 2>/dev/null || true

# 1. 停止并禁用代理相关服务
sudo systemctl stop redsocks dnsmasq 2>/dev/null || true
sudo systemctl disable redsocks dnsmasq 2>/dev/null || true

# 2. 清除 DNS 强制配置
sudo chattr -i /etc/resolv.conf 2>/dev/null || true
sudo rm -f /etc/resolv.conf
sudo ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf 2>/dev/null || true

# 3. 清理 iptables 规则
sudo iptables -t nat -F PROXY 2>/dev/null || true
sudo iptables -t nat -D OUTPUT -j PROXY 2>/dev/null || true
sudo iptables -t nat -D PREROUTING -i docker0 -j PROXY 2>/dev/null || true
sudo iptables -t nat -X PROXY 2>/dev/null || true

# 4. 恢复 Docker 的 iptables 支持
sudo rm -f /etc/docker/daemon.json
sudo systemctl restart docker 2>/dev/null || true

# 5. 恢复 firewalld
sudo systemctl unmask firewalld 2>/dev/null || true
sudo systemctl start firewalld 2>/dev/null || true
sudo systemctl enable firewalld 2>/dev/null || true

# 6. 关闭内核参数
sudo sysctl -w net.ipv4.ip_forward=0
sudo sysctl -w net.ipv4.conf.all.route_localnet=0

# 7. 清除持久化 iptables 规则
sudo rm -f /etc/sysconfig/iptables

# 8. 重启网络相关服务
sudo systemctl restart systemd-resolved NetworkManager 2>/dev/null || true

echo -e "\033[32m透明代理已禁用！\033[0m"
echo "建议执行以下操作："
echo "1. 重启系统以确保完全恢复"
echo "2. 测试网络连通性: curl -4 ifconfig.co"
