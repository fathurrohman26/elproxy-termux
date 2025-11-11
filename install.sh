#!/data/data/com.termux/files/usr/bin/bash
# Maintainer: The Void (@thevoidifnotnil)
# Maintainer: Fathurrohman (@fathurrohman26)

# Update and upgrade packages
color_green='\033[0;32m'
color_yellow='\033[1;33m'
color_reset='\033[0m'

echo -e "${color_green}Updating and upgrading packages...${color_reset}"
command -v apt >/dev/null 2>&1 && pkg_manager="apt" || pkg_manager="pkg"
$pkg_manager update -y && $pkg_manager upgrade -y
echo -e "${color_green}Packages updated and upgraded successfully.${color_reset}"

echo -e "${color_green}Installing required packages...${color_reset}"
$pkg_manager install uuid-utils git -y

# Clone the source code repository

echo -e "${color_green}Cloning the source code repository...${color_reset}"

# Ensure tmp directory exists and TMPDIR is set
if [ -z "$TMPDIR" ]; then
    export TMPDIR="/data/data/com.termux/files/usr/tmp"
fi

mkdir -p "$TMPDIR"
if [ $? -ne 0 ]; then
    echo -e "${color_yellow}Failed to create TMPDIR directory.${color_reset}"
    exit 1
fi

rm -rf $TMPDIR/elproxy
git clone https://github.com/fathurrohman26/elproxy.git $TMPDIR/elproxy
if [ $? -ne 0 ]; then
    echo -e "${color_yellow}Failed to clone repository. Please check your internet connection and try again.${color_reset}"
    exit 1
fi
echo -e "${color_green}Repository cloned successfully.${color_reset}"

# Navigate to the cloned directory
cd $TMPDIR/elproxy || { echo -e "${color_yellow}Failed to navigate to the cloned directory.${color_reset}"; exit 1; }

# Ensure PREFIX directory exists
PREFIX="/data/data/com.termux/files/usr/opt/elproxy"
rm -rf $PREFIX
mkdir -p "$PREFIX"
if [ $? -ne 0 ]; then
    echo -e "${color_yellow}Failed to create PREFIX directory.${color_reset}"
    exit 1
fi

# Create necessary directories
echo -e "${color_green}Creating necessary directories...${color_reset}"

mkdir -p "$PREFIX/bin"
mkdir -p "$PREFIX/conf"
mkdir -p "$PREFIX/logs"

# Copy files to the PREFIX directory
echo -e "${color_green}Copying files to the PREFIX directory...${color_reset}"

ARCH=$(uname -m)

if [ "$ARCH" = "aarch64" ]; then
    cp "bin/3proxy-arm64" "$PREFIX/bin/3proxy"
    cp "bin/frpc-arm64" "$PREFIX/bin/frpc"
elif [ "$ARCH" = "armv7l" ] || [ "$ARCH" = "armv8l" ]; then
    cp "bin/3proxy-arm32" "$PREFIX/bin/3proxy"
    cp "bin/frpc-arm32" "$PREFIX/bin/frpc"
elif [ "$ARCH" = "x86_64" ]; then
    cp "bin/3proxy-x86_64" "$PREFIX/bin/3proxy"
    cp "bin/frpc-x86_64" "$PREFIX/bin/frpc"
elif [ "$ARCH" = "i686" ] || [ "$ARCH" = "i386" ]; then
    cp "bin/3proxy-x86" "$PREFIX/bin/3proxy"
    cp "bin/frpc-x86" "$PREFIX/bin/frpc"
else
    echo -e "${color_yellow}Unsupported architecture: $ARCH${color_reset}"
    exit 1
fi

cp "conf/3proxy.conf" "$PREFIX/conf/3proxy.conf"
cp "conf/frpc.toml" "$PREFIX/conf/frpc.toml"

# Setup Device ID
DEVICE_ID=$(uuidgen)
sed -i "s/@@DEVICE_ID@@/$DEVICE_ID/g" "$PREFIX/conf/frpc.toml"

# Ensure files were copied successfully
if [ test ! -f "$PREFIX/bin/3proxy" ] || [ test ! -f "$PREFIX/bin/frpc" ] || [ test ! -f "$PREFIX/conf/3proxy.conf" ] || [ test ! -f "$PREFIX/conf/frpc.toml" ]; then
    echo -e "${color_yellow}Failed to copy necessary files to PREFIX directory.${color_reset}"
    exit 1
fi
echo -e "${color_green}Files copied successfully.${color_reset}"

# Set executable permissions
echo -e "${color_green}Setting executable permissions...${color_reset}"
chmod +x "$PREFIX/bin/3proxy"
chmod +x "$PREFIX/bin/frpc"

if [ $? -ne 0 ]; then
    echo -e "${color_yellow}Failed to set executable permissions.${color_reset}"
    exit 1
fi
echo -e "${color_green}Executable permissions set successfully.${color_reset}"

# Elproxy script wrapper
echo -e "${color_green}Creating elproxy script wrapper...${color_reset}"
ELPROXY_SCRIPT="/data/data/com.termux/files/usr/bin/elproxy"
cp "bin/elproxy" "$ELPROXY_SCRIPT"
chmod +x "$ELPROXY_SCRIPT"

if [ $? -ne 0 ]; then
    echo -e "${color_yellow}Failed to create elproxy script wrapper.${color_reset}"
    exit 1
fi
echo -e "${color_green}Elproxy script wrapper created successfully.${color_reset}"

# Cleanup
echo -e "${color_green}Cleaning up...${color_reset}"
rm -rf $TMPDIR/elproxy
echo -e "${color_green}Installation completed successfully! You can now use elproxy command.${color_reset}"
