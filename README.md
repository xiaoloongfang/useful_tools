# Transparent Proxy Manager

A powerful transparent proxy management tool that allows you to easily enable and disable system-wide proxy settings, including Docker container support.

## 🌟 Features

- **System-wide Proxy**: Automatically redirect all TCP traffic through proxy
- **Docker Support**: Seamless proxy integration with Docker containers
- **DNS Protection**: Secure DNS configuration with customizable upstream DNS
- **Easy Management**: Simple scripts to enable/disable proxy settings
- **Automatic Service Management**: Handles redsocks, dnsmasq, and other services
- **Comprehensive Logging**: Detailed logs for troubleshooting

## 🚀 Quick Start

### Prerequisites

The following packages are required:
- iptables
- redsocks
- dnsmasq
- socat
- systemd
- dig

### System Requirements

- Linux operating system
- Root privileges
- A running SOCKS5 proxy (default port: 1080)

### Usage

#### Enable Proxy

```
sudo ./transparent_proxy/enable_proxy.sh
```

This script will:
1. Stop and disable systemd-resolved
2. Install necessary software
3. Configure kernel parameters
4. Set up redsocks with SOCKS5 proxy
5. Configure DNS settings with dnsmasq
6. Set up iptables rules
7. Enable Docker support

#### Disable Proxy

```
sudo ./transparent_proxy/disable_proxy.sh
```

This script will:
1. Restore systemd-resolved
2. Stop proxy-related services
3. Clear DNS configurations
4. Clean up iptables rules
5. Restore Docker settings
6. Reset kernel parameters
7. Restart network services

## 🔧 Configuration

Default settings in `enable_proxy.sh`:

```
SOCKS_PORT=1080        # Local SOCKS5 proxy port
REDSOCKS_PORT=12345    # redsocks listening port
UPSTREAM_DNS="8.8.8.8" # Upstream DNS server
```

## 📊 How It Works

```
graph TD
    A[Client Traffic] --> B[iptables NAT rules]
    B --> C[redsocks]
    C --> D[SOCKS5 Proxy]
    E[DNS Queries] --> F[dnsmasq]
    F --> G[Upstream DNS]
```

## 🔍 Troubleshooting

### Common Issues

1. **Proxy Not Working**
   - Check redsocks service: `systemctl status redsocks`
   - Verify iptables rules: `iptables -t nat -L PROXY`
   - Check logs: `cat /var/log/enable_proxy.log`

2. **DNS Resolution Issues**
   - Check dnsmasq status: `systemctl status dnsmasq`
   - Verify DNS configuration: `cat /etc/resolv.conf`
   - Test resolution: `dig +short google.com`

3. **Docker Connection Issues**
   - Ensure docker0 interface exists
   - Check Docker service status: `systemctl status docker`

### Verification Commands

```
# Check your public IP (should show proxy IP)
curl -4 ifconfig.co

# Test DNS resolution
dig +short google.com

# Check service status
systemctl status redsocks
systemctl status dnsmasq
```

## 📝 Logging

Logs are available in:
- `/var/log/enable_proxy.log` - Script execution log
- `/var/log/redsocks.log` - Redsocks service log
- `journalctl -u redsocks` - Redsocks system log
- `journalctl -u dnsmasq` - DNS service log

## ⚠️ Important Notes

1. **Backup**: Always backup your network configuration before using these scripts
2. **Root Required**: Scripts must be run with root privileges
3. **SOCKS5 Proxy**: Ensure your SOCKS5 proxy is running before enabling
4. **System Reboot**: A reboot might be required after disabling proxy
5. **Network Changes**: Be prepared for temporary network interruption during setup

## 🛟 Recovery

If something goes wrong:

1. Run the disable script: `sudo ./transparent_proxy/disable_proxy.sh`
2. If issues persist, reboot your system

