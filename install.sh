#!/data/data/com.termux/files/usr/bin/bash
# Maintainer: The Void (@thevoidifnotnil)
# Maintainer: Fathurrohman (@fathurrohman26)
# Enhanced installation script with better error handling and validation

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
    if ! ping -c 1 github.com >/dev/null 2>&1; then
        log_error "No internet connection. Please check your network."
        return 1
    fi
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
    if command -v apt >/dev/null 2>&1; then
        echo "apt"
    elif command -v pkg >/dev/null 2>&1; then
        echo "pkg"
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
    fi

    if [[ -f "$TB_PREFIX/start-elproxy" ]]; then
        rm -rf "$TB_PREFIX/start-elproxy"
    fi

    log_success "Temporary files cleaned up"
}

trap cleanup EXIT

# Main installation process
main() {
    local pkg_manager
    local arch
    local device_id
    
    log_step "Starting ElProxy installation..."
     
    # Detect package manager
    pkg_manager=$(get_package_manager) || exit 1
    log_info "Using package manager: $pkg_manager"

    # Update and upgrade packages
    log_step "Updating system packages..."
    if ! $pkg_manager update -y; then
        log_error "Failed to update packages"
        exit 1
    fi
    
    if ! $pkg_manager upgrade -y; then
        log_warning "Package upgrade had some issues, but continuing..."
    fi
    log_success "Packages updated successfully"

       
    # Install required packages
    log_step "Installing required packages..."
    if ! $pkg_manager install -y uuid-utils git; then
        log_error "Failed to install required packages"
        exit 1
    fi
    log_success "Required packages installed"
    
    # Check prerequisites
    log_step "Checking prerequisites..."
    check_command "git" || exit 1
    check_command "uuidgen" || exit 1
    check_internet_connection || exit 1
    
    # Detect architecture
    arch=$(detect_architecture) || exit 1
    log_info "Detected architecture: $arch"
    
    # Prepare temporary directory
    log_step "Preparing temporary directory..."
    if ! mkdir -p "$TMPDIR"; then
        log_error "Failed to create TMPDIR: $TMPDIR"
        exit 1
    fi
    
    # Clone repository
    log_step "Cloning repository..."
    if [[ -d "$CLONE_DIR" ]]; then
        rm -rf "$CLONE_DIR"
    fi
    
    if ! git clone "$REPO_URL" "$CLONE_DIR"; then
        log_error "Failed to clone repository from $REPO_URL"
        exit 1
    fi
    log_success "Repository cloned successfully"
    
    # Navigate to cloned directory
    if ! cd "$CLONE_DIR"; then
        log_error "Failed to navigate to: $CLONE_DIR"
        exit 1
    fi
    
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
    log_success "Directory structure created"
    
    # Copy binaries based on architecture
    log_step "Installing binaries..."
    local proxy_bin_src="bin/3proxy-$arch"
    local frpc_bin_src="bin/frpc-$arch"
    local proxy_bin_dst="$PREFIX/bin/3proxy"
    local frpc_bin_dst="$PREFIX/bin/frpc"
    
    # Validate source binaries exist
    if ! validate_files "$proxy_bin_src" "$frpc_bin_src"; then
        log_error "Required binaries not found for architecture: $arch"
        exit 1
    fi
    
    # Copy binaries
    if ! cp "$proxy_bin_src" "$proxy_bin_dst"; then
        log_error "Failed to copy 3proxy binary"
        exit 1
    fi
    
    if ! cp "$frpc_bin_src" "$frpc_bin_dst"; then
        log_error "Failed to copy frpc binary"
        exit 1
    fi
    log_success "Binaries installed"
    
    # Copy configuration files
    log_step "Installing configuration files..."
    local conf_files=("conf/3proxy.conf" "conf/frpc.toml")
    
    if ! validate_files "${conf_files[@]}"; then
        log_error "Required configuration files not found"
        exit 1
    fi
    
    for conf_file in "${conf_files[@]}"; do
        local dst_file="$PREFIX/conf/$(basename "$conf_file")"
        if ! cp "$conf_file" "$dst_file"; then
            log_error "Failed to copy configuration file: $conf_file"
            exit 1
        fi
    done
    log_success "Configuration files installed"
    
    # Generate and set device ID
    log_step "Generating device ID..."
    device_id=$(generate_device_id)
    if [[ -z "$device_id" ]]; then
        log_error "Failed to generate device ID"
        exit 1
    fi
    
    local frpc_config="$PREFIX/conf/frpc.toml"
    if ! sed -i "s/@@DEVICE_ID@@/$device_id/g" "$frpc_config"; then
        log_error "Failed to set device ID in configuration"
        exit 1
    fi
    log_info "Device ID generated: $device_id"
    log_success "Device ID configured"

    log_step "Creating boot-auto-start script..."
    mkdir -p $TB_PREFIX
    if ! cp scripts/start-elproxy "$TB_PREFIX"; then
        log_error "Failed to copy boot-auto-start script: scripts/start-elproxy"
        exit 1
    fi

    log_success "Script boot-auto-start created at $TB_PREFIX/start-elproxy"
    
    # Set executable permissions
    log_step "Setting executable permissions..."
    if ! chmod +x "$PREFIX/bin/3proxy" "$PREFIX/bin/frpc" "$TB_PREFIX/start-elproxy"; then
        log_error "Failed to set executable permissions"
        exit 1
    fi
    log_success "Permissions set"
    
    # Validate installation
    log_step "Validating installation..."
    local required_files=(
        "$PREFIX/bin/3proxy"
        "$PREFIX/bin/frpc"
        "$PREFIX/conf/3proxy.conf"
        "$PREFIX/conf/frpc.toml"
        "$TB_PREFIX/start-elproxy"
    )
    
    if ! validate_files "${required_files[@]}"; then
        log_error "Installation validation failed"
        exit 1
    fi
    
    # Check if binaries are executable
    if [[ ! -x "$PREFIX/bin/3proxy" || ! -x "$PREFIX/bin/frpc" ]]; then
        log_error "Binaries are not executable"
        exit 1
    fi
    log_success "Installation validated"
    
    # Install elproxy wrapper script
    log_step "Installing elproxy wrapper script..."
    local wrapper_src="bin/elproxy"
    
    if [[ ! -f "$wrapper_src" ]]; then
        log_error "Wrapper script not found: $wrapper_src"
        exit 1
    fi
    
    if ! cp "$wrapper_src" "$ELPROXY_SCRIPT"; then
        log_error "Failed to copy wrapper script to $ELPROXY_SCRIPT"
        exit 1
    fi
    
    if ! chmod +x "$ELPROXY_SCRIPT"; then
        log_error "Failed to set executable permission on wrapper script"
        exit 1
    fi
    log_success "Wrapper script installed"
    
    # Final validation
    log_step "Performing final checks..."
    if command -v elproxy >/dev/null 2>&1; then
        log_success "elproxy command is available in PATH"
    else
        log_warning "elproxy command may not be in PATH. You may need to restart your shell."
    fi
    
    # Display installation summary
    echo
    log_success "=== Installation Completed Successfully ==="
    log_info "Installation directory: $PREFIX"
    log_info "Configuration files: $PREFIX/conf/"
    log_info "Binary files: $PREFIX/bin/"
    log_info "Log directory: $PREFIX/logs/"
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
    echo
}

# Run main function
main "$@"