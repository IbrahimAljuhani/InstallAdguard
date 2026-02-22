<div align="center">

# 🛡️ AdGuard Home Installer
### Professional Edition — by Ibrahim Aljuhani

<br>

[![Shell](https://img.shields.io/badge/Shell-Bash-4EAA25?style=for-the-badge&logo=gnubash&logoColor=white)](https://www.gnu.org/software/bash/)
[![Ubuntu](https://img.shields.io/badge/Ubuntu-22.04%2B-E95420?style=for-the-badge&logo=ubuntu&logoColor=white)](https://ubuntu.com/)
[![License](https://img.shields.io/badge/License-MIT-blue?style=for-the-badge)](LICENSE)
[![Version](https://img.shields.io/badge/Version-1.0.0-68BC71?style=for-the-badge)](https://github.com/IbrahimAljuhani/InstallAdguard)

<br>

> **Production-grade Bash installer for AdGuard Home**  
> Built on the *Configuration-First Pattern* → **Gather · Validate · Execute**

<br>

---

</div>

## 🌟 Features

- **3-Phase Pattern** — Gather → Validate → Execute
- **3 Modes** — Interactive · Non-Interactive · Dry-Run
- **Color-coded output** with clear status indicators (`✔ DONE`, `⚠ WARN`, `✖ ERROR`)
- **Pre-flight validation** — ports, conflicts, OS version, architecture detection
- **Auto-detects & frees port 53** — disables `systemd-resolved` stub listener if needed
- **Pre-configured blocklists** — 3 popular lists enabled out of the box
- **Upstream DoH resolvers** — Quad9 · Cloudflare · Google
- **Nginx reverse proxy** support
- **Let's Encrypt SSL** via Certbot
- **UFW firewall rules** applied automatically
- **Credentials saved** to `/root/adguard-secrets.txt` (`chmod 600`)
- **JSON manifest** generated for every installation
- **Hardening checklist** printed after a successful install
- **Quick-command reference** shown at the end of every run
- **Backup before reinstall** — optional config backup when reinstalling

---

## 📋 Requirements

| Component | Requirement |
|-----------|-------------|
| **OS** | Ubuntu 22.04+ (or any Debian-based distro) |
| **RAM** | 512 MB minimum |
| **Disk** | 1 GB free |
| **Architecture** | `x86_64` · `arm64` · `armv7` |
| **Privileges** | Must run as root (`sudo`) |
| **Port 53** | Must be available (handled automatically) |

---

## ⚡ Quick Start

```bash
# Download the script
wget https://raw.githubusercontent.com/IbrahimAljuhani/InstallAdguard/main/install_adguard.sh

# Make it executable
chmod +x install_adguard.sh

# Run (interactive mode — recommended for first time)
sudo bash install_adguard.sh
```

---

## 🚀 Usage

### Interactive *(recommended)*
```bash
sudo bash install_adguard.sh
```
The script will guide you step-by-step through all configuration options.

---

### Non-Interactive
```bash
sudo bash install_adguard.sh --non-interactive \
  --web-port 3000 \
  --dns-port 53 \
  --admin-user admin \
  --nginx \
  --domain adguard.example.com \
  --ssl \
  --email you@example.com
```

---

### Dry-Run *(simulate without making any changes)*
```bash
sudo bash install_adguard.sh --dry-run \
  --web-port 3000 \
  --dns-port 53
```

---

## 🔧 CLI Options

| Option | Description | Default |
|--------|-------------|---------|
| `--web-port <port>` | Web UI port | `3000` |
| `--dns-port <port>` | DNS listening port | `53` |
| `--admin-user <n>` | Admin username | `admin` |
| `--nginx` | Enable Nginx reverse proxy | off |
| `--domain <domain>` | Domain name for Nginx | — |
| `--ssl` | Enable Let's Encrypt SSL | off |
| `--email <email>` | Email for SSL certificate notifications | — |
| `--non-interactive` | Skip all prompts | off |
| `--dry-run` | Simulate without making any changes | off |
| `--help`, `-h` | Show this help message | — |

---

## 📦 What Gets Installed

| Component | Details |
|-----------|---------|
| **AdGuard Home** | Latest release, auto-matched to your CPU architecture |
| **Blocklist: AdGuard DNS Filter** | Comprehensive ads & trackers list |
| **Blocklist: AdAway** | Mobile-focused blocklist |
| **Blocklist: MalwareDomainList** | Malware & phishing domains |
| **Upstream DNS** | Quad9 DoH · Cloudflare DoH · Google DoH |
| **Nginx** | Reverse proxy for Web UI *(optional)* |
| **Certbot** | Let's Encrypt SSL *(optional)* |
| **systemd service** | Auto-start & auto-restart on failure |
| **UFW rules** | DNS (TCP/UDP) + Web UI ports |

---

## 📁 Installation Layout

```
/
├── opt/AdGuardHome/
│   ├── AdGuardHome              # Binary
│   └── AdGuardHome.yaml         # Configuration file
│
├── var/lib/AdGuardHome/         # Data directory (query logs, stats, leases)
│
├── var/log/AdGuardHome/         # Log files (auto-rotated, max 100 MB × 3)
│
└── root/
    ├── adguard-secrets.txt      # Admin credentials — chmod 600
    └── adguard-installs/        # JSON installation manifests
```

---

## 🌐 Using AdGuard as Your Network-Wide DNS

After installation, point your **router's primary DNS** to your server IP.  
Every device on the network is protected — no per-device configuration needed.

```
Primary DNS   →  <your-server-ip>
Secondary DNS →  9.9.9.9          (Quad9 fallback)
```

> You can also configure individual devices to point directly to the server IP  
> if you prefer per-device control instead of router-level configuration.

---

## 🖥️ Post-Install Commands

```bash
# Check service status
sudo systemctl status AdGuardHome

# Restart the service
sudo systemctl restart AdGuardHome

# Follow live logs
sudo journalctl -u AdGuardHome -f

# Edit configuration
sudo nano /opt/AdGuardHome/AdGuardHome.yaml

# View saved credentials
sudo cat /root/adguard-secrets.txt
```

---

## 🔐 Security Notes

- Admin credentials are saved in `/root/adguard-secrets.txt` with `chmod 600` (root-only access).
- After installation, **clear your terminal history** to remove any sensitive output:
  ```bash
  history -c && history -w
  ```
- Review open firewall ports at any time:
  ```bash
  sudo ufw status verbose
  ```
- Enable automatic OS security updates:
  ```bash
  sudo dpkg-reconfigure unattended-upgrades
  ```
- Enable **DNSSEC** and **Encrypted DNS (DoH/DoT)** from the Web UI under  
  *Settings → DNS Settings* and *Settings → Encryption* for maximum protection.

---

## 📸 Installation Flow

```
╔══════════════════════════════════════════════════════════════════╗
║        AdGuard Home Installer - Professional Edition            ║
║                        Version 1.0.0                            ║
╚══════════════════════════════════════════════════════════════════╝

▶ System Preparation
──────────────────────────────────────────────────────────────────
[  ==>  ] Checking required tools...
[✔ DONE ] Checking required tools
[  ==>  ] Updating system packages...
[✔ DONE ] Updating system packages
[  ==>  ] Freeing port 53 if needed...
[✔ DONE ] Freeing port 53 if needed

▶ User & Directories
──────────────────────────────────────────────────────────────────
[✔ DONE ] Creating system user
[✔ DONE ] Creating directories

▶ AdGuard Home
──────────────────────────────────────────────────────────────────
[✔ DONE ] Downloading AdGuard Home
[✔ DONE ] Writing configuration

▶ Service Setup
──────────────────────────────────────────────────────────────────
[✔ DONE ] Installing systemd service
[✔ DONE ] Starting AdGuard Home
[✔ DONE ] Configuring UFW firewall

▶ Finalization
──────────────────────────────────────────────────────────────────
[✔ DONE ] Saving credentials
[✔ DONE ] Generating manifest

╔══════════════════════════════════════════════════════════════════╗
║                   ✅  Installation Complete!                    ║
╚══════════════════════════════════════════════════════════════════╝
```

---

## 🤝 Contributing

Contributions, issues, and feature requests are welcome.  
Feel free to open an [issue](https://github.com/IbrahimAljuhani/InstallAdguard/issues) or submit a pull request.

---

## 📄 License

This project is licensed under the **MIT License** — see the [LICENSE](LICENSE) file for details.

---

<div align="center">

Made with ❤️ by **Ibrahim Aljuhani**

[![GitHub](https://img.shields.io/badge/GitHub-IbrahimAljuhani-181717?style=for-the-badge&logo=github)](https://github.com/IbrahimAljuhani/InstallAdguard)

</div>