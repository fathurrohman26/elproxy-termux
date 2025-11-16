# EL Proxy Node (Termux Version)

## Installation

- Download Termux App [Download Termux 0.118.3 F-Droid](https://f-droid.org/repo/com.termux_1002.apk)

- Download Termux Boot [Download Termux 0.8.1 F-Droid](https://f-droid.org/repo/com.termux.boot_1000.apk)

```bash
curl -fsSL https://raw.githubusercontent.com/elproxy-cloud/elproxy-termux/refs/heads/main/install.sh | bash && elproxy start
```

## Usage

```bash
elproxy start|stop|status|restart
```

## Troubleshooting
- Update error (Mirror connections errors)
```bash
termux-change-repo
```
