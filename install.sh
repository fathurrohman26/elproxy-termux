#!/data/data/com.termux/files/usr/bin/bash
# Maintainer: The Void (@thevoidifnotnil)
# Maintainer: Fathurrohman (@fathurrohman26)

set -e  # Exit on any error

# Prevent sleeping
termux-wake-lock

# Color definitions
readonly COLOR_RED='\033[0;31m'
readonly COLOR_GREEN='\033[0;32m'
readonly COLOR_YELLOW='\033[1;33m'
readonly COLOR_BLUE='\033[0;34m'
readonly COLOR_CYAN='\033[0;36m'
readonly COLOR_RESET='\033[0m'

# Constants
readonly PREFIX="/data/data/com.termux/files/usr/opt/elproxy"
readonly TB_PREFIX="$HOME/.termux/boot"
readonly TMPDIR="${TMPDIR:-/data/data/com.termux/files/usr/tmp}"
readonly REPO_URL="https://github.com/fathurrohman26/elproxy-termux.git"
readonly CLONE_DIR="$TMPDIR/elproxy"
readonly ELPROXY_SCRIPT="/data/data/com.termux/files/usr/bin/elproxy"

# Logging functions
log_info() {
    echo -e "${COLOR_BLUE}[INFO]${COLOR_RESET} $1"
}

log_success() {
    echo -e "${COLOR_GREEN}[SUCCESS]${COLOR_RESET} $1"
}

log_warning() {
    echo -e "${COLOR_YELLOW}[WARNING]${COLOR_RESET} $1"
}

log_error() {
    echo -e "${COLOR_RED}[ERROR]${COLOR_RESET} $1"
}

log_step() {
    echo -e "${COLOR_CYAN}[STEP]${COLOR_RESET} $1"
}

# Utility functions
check_command() {
    if ! command -v "$1" >/dev/null 2>&1; then
        log_error "Required command not found: $1"
        return 1
    fi
}

check_internet_connection() {
    log_info "Checking internet connection..."
    if ! ping -c 1 -W 5 github.com >/dev/null 2>&1; then
        log_error "No internet connection. Please check your network."
        return 1
    fi
    log_success "Internet connection available"
}

detect_architecture() {
    local arch
    arch=$(uname -m)
    
    case "$arch" in
        "aarch64")
            echo "arm64"
            ;;
        "armv7l"|"armv8l")
            echo "arm32"
            ;;
        "x86_64")
            echo "x86_64"
            ;;
        "i686"|"i386")
            echo "x86"
            ;;
        *)
            log_error "Unsupported architecture: $arch"
            return 1
            ;;
    esac
}

get_package_manager() {
    if command -v apt-get >/dev/null 2>&1; then
        echo "apt-get"
    else
        log_error "No compatible package manager found (apt or pkg)"
        return 1
    fi
}

validate_files() {
    local files=("$@")
    local missing_files=()
    
    for file in "${files[@]}"; do
        if [[ ! -f "$file" ]]; then
            missing_files+=("$file")
        fi
    done
    
    if [[ ${#missing_files[@]} -gt 0 ]]; then
        log_error "Missing required files:"
        for file in "${missing_files[@]}"; do
            echo "  - $file"
        done
        return 1
    fi
    return 0
}

generate_device_id() {
    if command -v uuidgen >/dev/null 2>&1; then
        uuidgen
    elif [[ -f /proc/sys/kernel/random/uuid ]]; then
        cat /proc/sys/kernel/random/uuid
    else
        # Fallback: generate random string
        date +%s | sha256sum | head -c 32
    fi
}

cleanup() {
    log_step "Performing cleanup..."
    if [[ -d "$CLONE_DIR" ]]; then
        rm -rf "$CLONE_DIR"
        log_success "Cleaned up clone directory"
    fi
}

trap cleanup EXIT

# Function to install required packages
install_required_packages() {
    local pkg_manager="$1"
    
    log_step "Installing required packages..."
    
    # Base packages
    local base_packages=("git" "curl" "uuid-utils" "util-linux" "libandroid-posix-semaphore")
    
    if ! $pkg_manager install -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" "${base_packages[@]}"; then
        log_error "Failed to install required packages"
        return 1
    fi
    
    log_success "Required packages installed successfully"
    return 0
}

# Function to setup boot directory
setup_boot_directory() {
    log_step "Setting up boot directory..."
    
    # Remove existing boot script if it exists
    if [[ -f "$TB_PREFIX/start-elproxy" ]]; then
        log_info "Removing existing boot script..."
        rm -f "$TB_PREFIX/start-elproxy"
    fi
    
    # Create boot directory if it doesn't exist
    if [[ ! -d "$TB_PREFIX" ]]; then
        log_info "Creating boot directory: $TB_PREFIX"
        if ! mkdir -p "$TB_PREFIX"; then
            log_error "Failed to create boot directory"
            return 1
        fi
    fi
    
    log_success "Boot directory setup completed"
    return 0
}

# Function to clone and prepare repository
clone_repository() {
    log_step "Cloning repository..."
    
    # Clean up existing clone directory
    if [[ -d "$CLONE_DIR" ]]; then
        log_info "Removing existing clone directory..."
        rm -rf "$CLONE_DIR"
    fi
    
    # Create temporary directory
    if ! mkdir -p "$TMPDIR"; then
        log_error "Failed to create TMPDIR: $TMPDIR"
        return 1
    fi
    
    # Clone repository
    if ! git clone "$REPO_URL" "$CLONE_DIR"; then
        log_error "Failed to clone repository from $REPO_URL"
        return 1
    fi
    
    # Navigate to cloned directory
    if ! cd "$CLONE_DIR"; then
        log_error "Failed to navigate to: $CLONE_DIR"
        return 1
    fi
    
    log_success "Repository cloned successfully"
    return 0
}

# Function to install binaries
install_binaries() {
    local arch="$1"
    
    log_step "Installing binaries for architecture: $arch"
    
    local proxy_bin_src="bin/3proxy-$arch"
    local frpc_bin_src="bin/frpc-$arch"
    local proxy_bin_dst="$PREFIX/bin/3proxy"
    local frpc_bin_dst="$PREFIX/bin/frpc"
    
    # Validate source binaries exist
    if ! validate_files "$proxy_bin_src" "$frpc_bin_src"; then
        log_error "Required binaries not found for architecture: $arch"
        return 1
    fi
    
    # Create bin directory if it doesn't exist
    if [[ ! -d "$PREFIX/bin" ]]; then
        mkdir -p "$PREFIX/bin"
    fi
    
    # Copy binaries
    if ! cp "$proxy_bin_src" "$proxy_bin_dst"; then
        log_error "Failed to copy 3proxy binary"
        return 1
    fi
    
    if ! cp "$frpc_bin_src" "$frpc_bin_dst"; then
        log_error "Failed to copy frpc binary"
        return 1
    fi
    
    # Set executable permissions
    if ! chmod +x "$proxy_bin_dst" "$frpc_bin_dst"; then
        log_error "Failed to set executable permissions on binaries"
        return 1
    fi
    
    log_success "Binaries installed successfully"
    return 0
}

# Function to install configuration files
install_configurations() {
    local device_id="$1"
    
    log_step "Installing configuration files..."
    
    local conf_files=("conf/3proxy.conf" "conf/frpc.toml")
    
    if ! validate_files "${conf_files[@]}"; then
        log_error "Required configuration files not found"
        return 1
    fi
    
    # Create conf directory if it doesn't exist
    if [[ ! -d "$PREFIX/conf" ]]; then
        mkdir -p "$PREFIX/conf"
    fi
    
    for conf_file in "${conf_files[@]}"; do
        local dst_file="$PREFIX/conf/$(basename "$conf_file")"
        if ! cp "$conf_file" "$dst_file"; then
            log_error "Failed to copy configuration file: $conf_file"
            return 1
        fi
        log_info "Copied: $conf_file -> $dst_file"
    done
    
    # Update device ID in frpc configuration
    local frpc_config="$PREFIX/conf/frpc.toml"
    if [[ -f "$frpc_config" ]]; then
        if ! sed -i "s/@@DEVICE_ID@@/$device_id/g" "$frpc_config"; then
            log_error "Failed to set device ID in configuration"
            return 1
        fi
        log_success "Device ID configured in frpc.toml"
    else
        log_error "frpc configuration file not found: $frpc_config"
        return 1
    fi
    
    log_success "Configuration files installed"
    return 0
}

# Function to install boot script
install_boot_script() {
    log_step "Installing boot script..."
    
    local boot_script_src="scripts/start-elproxy"
    local boot_script_dst="$TB_PREFIX/start-elproxy"
    
    if [[ ! -f "$boot_script_src" ]]; then
        log_error "Boot script source not found: $boot_script_src"
        return 1
    fi
    
    # Copy boot script
    if ! cp "$boot_script_src" "$boot_script_dst"; then
        log_error "Failed to copy boot script: $boot_script_src -> $boot_script_dst"
        return 1
    fi
    
    # Set executable permissions
    if ! chmod +x "$boot_script_dst"; then
        log_error "Failed to set executable permissions on boot script"
        return 1
    fi
    
    log_success "Boot script installed at $boot_script_dst"
    return 0
}

# Function to install wrapper script
install_wrapper_script() {
    log_step "Installing elproxy wrapper script..."
    
    local wrapper_src="bin/elproxy"
    
    if [[ ! -f "$wrapper_src" ]]; then
        log_error "Wrapper script not found: $wrapper_src"
        return 1
    fi
    
    # Copy wrapper script
    if ! cp "$wrapper_src" "$ELPROXY_SCRIPT"; then
        log_error "Failed to copy wrapper script to $ELPROXY_SCRIPT"
        return 1
    fi
    
    # Set executable permissions
    if ! chmod +x "$ELPROXY_SCRIPT"; then
        log_error "Failed to set executable permission on wrapper script"
        return 1
    fi
    
    log_success "Wrapper script installed at $ELPROXY_SCRIPT"
    return 0
}

# Function to validate installation
validate_installation() {
    local device_id="$1"
    
    log_step "Validating installation..."
    
    local required_files=(
        "$PREFIX/bin/3proxy"
        "$PREFIX/bin/frpc"
        "$PREFIX/conf/3proxy.conf"
        "$PREFIX/conf/frpc.toml"
        "$TB_PREFIX/start-elproxy"
        "$ELPROXY_SCRIPT"
    )
    
    if ! validate_files "${required_files[@]}"; then
        log_error "Installation validation failed - missing files"
        return 1
    fi
    
    # Check if binaries are executable
    if [[ ! -x "$PREFIX/bin/3proxy" || ! -x "$PREFIX/bin/frpc" ]]; then
        log_error "Binaries are not executable"
        return 1
    fi
    
    # Check if boot script is executable
    if [[ ! -x "$TB_PREFIX/start-elproxy" ]]; then
        log_error "Boot script is not executable"
        return 1
    fi
    
    # Check if wrapper script is executable
    if [[ ! -x "$ELPROXY_SCRIPT" ]]; then
        log_error "Wrapper script is not executable"
        return 1
    fi
    
    # Verify device ID was set in configuration
    if ! grep -q "$device_id" "$PREFIX/conf/frpc.toml"; then
        log_error "Device ID not properly set in configuration"
        return 1
    fi
    
    log_success "Installation validated successfully"
    return 0
}

# Main installation process
main() {
    local pkg_manager
    local arch
    local device_id
    
    log_step "Starting ElProxy installation..."
    
    # Check if running in Termux
    if [[ ! -d "/data/data/com.termux" ]]; then
        log_error "This script must be run in Termux environment"
        exit 1
    fi
    
    # Check prerequisites
    log_step "Checking prerequisites..."
    check_internet_connection || exit 1
    
    # Detect package manager
    pkg_manager=$(get_package_manager) || exit 1
    log_info "Using package manager: $pkg_manager"
    
    # Update and upgrade packages
    log_step "Updating system packages..."
    if ! $pkg_manager update -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold"; then
        log_error "Failed to update packages"
        exit 1
    fi
    
    if ! $pkg_manager upgrade -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold"; then
        log_warning "Package upgrade had some issues, but continuing..."
    else
        log_success "Packages updated successfully"
    fi
    
    # Install required packages
    install_required_packages "$pkg_manager" || exit 1
    
    # Check required commands
    check_command "git" || exit 1
    
    # Detect architecture
    arch=$(detect_architecture) || exit 1
    log_info "Detected architecture: $arch"
    
    # Generate device ID early to validate
    log_step "Generating device ID..."
    device_id=$(generate_device_id)
    if [[ -z "$device_id" ]]; then
        log_error "Failed to generate device ID"
        exit 1
    fi
    log_info "Device ID: $device_id"
    
    # Setup boot directory
    setup_boot_directory || exit 1
    
    # Clone repository
    clone_repository || exit 1
    
    # Create installation directory
    log_step "Creating installation directory..."
    if [[ -d "$PREFIX" ]]; then
        log_info "Removing existing installation..."
        rm -rf "$PREFIX"
    fi
    
    if ! mkdir -p "$PREFIX"/{bin,conf,logs}; then
        log_error "Failed to create PREFIX directory structure"
        exit 1
    fi
    log_success "Directory structure created at $PREFIX"
    
    # Install components
    install_binaries "$arch" || exit 1
    install_configurations "$device_id" || exit 1
    install_boot_script || exit 1
    install_wrapper_script || exit 1
    
    # Final validation
    validate_installation "$device_id" || exit 1
    
    # Display installation summary
    echo
    log_success "=== Installation Completed Successfully ==="
    log_info "Installation directory: $PREFIX"
    log_info "Configuration files: $PREFIX/conf/"
    log_info "Binary files: $PREFIX/bin/"
    log_info "Log directory: $PREFIX/logs/"
    log_info "Boot script: $TB_PREFIX/start-elproxy"
    log_info "Device ID: $device_id"
    echo
    log_info "Usage:"
    log_info "  elproxy start    - Start all services"
    log_info "  elproxy stop     - Stop all services"
    log_info "  elproxy status   - Show service status"
    log_info "  elproxy restart  - Restart all services"
    echo
    log_info "Next steps:"
    log_info "  1. Configure your proxy settings in $PREFIX/conf/"
    log_info "  2. Run 'elproxy start' to start the services"
    log_info "  3. Check status with 'elproxy status'"
    log_info "  4. The service will auto-start on boot via Termux:Boot"
    echo
}

# Run main function
main "$@"