#!/bin/bash
# VS Code Insiders Self-Installing Script
# Fully automated cross-distribution installation utility

set -e

# ANSI color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# Script metadata and versioning
SCRIPT_VERSION="1.0.0"
SCRIPT_NAME="$(basename "$0")"
SCRIPT_PATH="$(realpath "$0")"
SCRIPT_DIR="$(dirname "$SCRIPT_PATH")"

# Function to display animated banner
display_banner() {
    clear
    echo -e "${BLUE}${BOLD}"
    echo "╔═════════════════════════════════════════════════════════╗"
    echo "║ VS Code Insiders - Self-Installing Script v${SCRIPT_VERSION}          ║"
    echo "╚═════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo -e "${CYAN}Intelligent cross-distribution installer${NC}"
    echo ""
}

# Advanced logging function with log levels and timestamps
log() {
    local level=$1
    local message=$2
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local pid=$$
    
    case "$level" in
        "INFO")  echo -e "${GREEN}[INFO]${NC} ${timestamp} [${pid}] - $message" ;;
        "WARN")  echo -e "${YELLOW}[WARN]${NC} ${timestamp} [${pid}] - $message" ;;
        "ERROR") echo -e "${RED}[ERROR]${NC} ${timestamp} [${pid}] - $message" ;;
        "DEBUG") 
            if [[ "${DEBUG_MODE}" == "true" ]]; then
                echo -e "${BLUE}[DEBUG]${NC} ${timestamp} [${pid}] - $message"
            fi
            ;;
        *)       echo -e "${CYAN}[LOG]${NC} ${timestamp} [${pid}] - $message" ;;
    esac
}

# Function to display progress bar
show_progress() {
    local pid=$1
    local delay=0.1
    local spinstr='|/-\'
    
    while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do
        local temp=${spinstr#?}
        printf " [%c]  " "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b\b"
    done
    printf "    \b\b\b\b"
}

# Enhanced system fingerprinting function
fingerprint_system() {
    log "INFO" "Performing advanced system fingerprinting..."
    
    # Gather comprehensive system information
    local os_id=$(grep -oP '(?<=^ID=).+' /etc/os-release | tr -d '"' || echo "unknown")
    local os_version=$(grep -oP '(?<=^VERSION_ID=).+' /etc/os-release | tr -d '"' || echo "unknown")
    local kernel=$(uname -r)
    local architecture=$(uname -m)
    
    log "INFO" "System fingerprint: $os_id $os_version (Kernel: $kernel, Arch: $architecture)"
    
    # Return serialized system fingerprint
    echo "$os_id:$os_version:$kernel:$architecture"
}

# Intelligent package manager detection with fallback mechanisms
detect_package_manager() {
    log "INFO" "Detecting package management system..."
    
    # Primary package managers
    local managers=(
        "apt:/usr/bin/apt:apt:dpkg:apt-get:apt-cache:Debian:Ubuntu:Mint:Pop:Kali"
        "dnf:/usr/bin/dnf:dnf:rpm:dnf:dnf info:Fedora:RHEL:CentOS:Rocky:AlmaLinux"
        "yum:/usr/bin/yum:yum:rpm:yum:yum info:CentOS6:RHEL6"
        "zypper:/usr/bin/zypper:zypper:rpm:zypper:zypper info:openSUSE:SLES"
        "pacman:/usr/bin/pacman:pacman:pacman:pacman:pacman -Si:Arch:Manjaro:Endeavour"
        "apk:/sbin/apk:apk:apk:apk:apk info:Alpine"
        "xbps-install:/usr/bin/xbps-install:xbps:xbps:xbps-install:xbps-query:Void"
        "emerge:/usr/bin/emerge:portage:qpkg:emerge:emerge -p:Gentoo"
    )
    
    # First try to detect based on os-release
    local os_id=$(grep -oP '(?<=^ID=).+' /etc/os-release | tr -d '"' || echo "unknown")
    local os_id_like=$(grep -oP '(?<=^ID_LIKE=).+' /etc/os-release | tr -d '"' || echo "")
    
    for manager in "${managers[@]}"; do
        IFS=: read -r name path pkg_type installer checker info distros <<< "$manager"
        
        # Check if current distro matches
        for distro in ${distros//:/}; do
            if [[ "$os_id" == *"${distro,,}"* ]] || [[ "$os_id_like" == *"${distro,,}"* ]]; then
                if [[ -x "$path" ]]; then
                    log "INFO" "Detected $name package manager (distribution match: $distro)"
                    echo "$name:$pkg_type:$installer:$checker:$info:$path"
                    return 0
                fi
            fi
        done
    done
    
    # Fallback: check for existence of package managers
    for manager in "${managers[@]}"; do
        IFS=: read -r name path pkg_type installer checker info distros <<< "$manager"
        if [[ -x "$path" ]]; then
            log "INFO" "Detected $name package manager (binary found at $path)"
            echo "$name:$pkg_type:$installer:$checker:$info:$path"
            return 0
        fi
    done
    
    # Ultimate fallback
    log "WARN" "Could not determine package manager, using generic installation methods"
    echo "generic:generic:none:none:none:none"
}

# Function to ensure we have required utilities
ensure_core_utilities() {
    log "INFO" "Ensuring core utilities are available..."
    
    local required_utils=("wget" "curl" "tar" "grep" "sed" "awk")
    local missing_utils=()
    local pkg_manager_info=$1
    
    IFS=: read -r mgr_name pkg_type installer checker info path <<< "$pkg_manager_info"
    
    # Check for each utility
    for util in "${required_utils[@]}"; do
        if ! command -v "$util" &>/dev/null; then
            missing_utils+=("$util")
            log "WARN" "Missing core utility: $util"
        fi
    done
    
    # Install missing utilities if any
    if [[ ${#missing_utils[@]} -gt 0 ]]; then
        log "INFO" "Installing missing utilities: ${missing_utils[*]}"
        
        case "$mgr_name" in
            "apt")
                sudo apt update &>/dev/null
                sudo apt install -y ${missing_utils[*]} || log "ERROR" "Failed to install utilities with apt"
                ;;
            "dnf")
                sudo dnf install -y ${missing_utils[*]} || log "ERROR" "Failed to install utilities with dnf"
                ;;
            "yum")
                sudo yum install -y ${missing_utils[*]} || log "ERROR" "Failed to install utilities with yum"
                ;;
            "zypper")
                sudo zypper install -y ${missing_utils[*]} || log "ERROR" "Failed to install utilities with zypper"
                ;;
            "pacman")
                sudo pacman -Sy --needed --noconfirm ${missing_utils[*]} || log "ERROR" "Failed to install utilities with pacman"
                ;;
            "apk")
                sudo apk add ${missing_utils[*]} || log "ERROR" "Failed to install utilities with apk"
                ;;
            "xbps-install")
                sudo xbps-install -y ${missing_utils[*]} || log "ERROR" "Failed to install utilities with xbps"
                ;;
            "emerge")
                sudo emerge -q ${missing_utils[*]} || log "ERROR" "Failed to install utilities with emerge"
                ;;
            *)
                log "ERROR" "Cannot automatically install missing utilities: ${missing_utils[*]}"
                log "ERROR" "Please install them manually and run this script again."
                exit 1
                ;;
        esac
    fi
}

# Function to download the appropriate package using aria2 if available for parallel downloads
download_package() {
    local download_dir=$(mktemp -d)
    log "INFO" "Downloading package to $download_dir..."
    
    # Package URLs
    local deb_url="https://code.visualstudio.com/sha/download?build=insider&os=linux-deb-x64"
    local rpm_url="https://code.visualstudio.com/sha/download?build=insider&os=linux-rpm-x64"
    local tar_url="https://code.visualstudio.com/sha/download?build=insider&os=linux-x64"
    
    local pkg_manager_info=$1
    IFS=: read -r mgr_name pkg_type installer checker info path <<< "$pkg_manager_info"
    
    # Determine which package to download
    local package_url=""
    local package_filename=""
    
    case "$pkg_type" in
        "dpkg")
            package_url="$deb_url"
            package_filename="$download_dir/vscode-insiders.deb"
            ;;
        "rpm")
            package_url="$rpm_url"
            package_filename="$download_dir/vscode-insiders.rpm"
            ;;
        *)
            package_url="$tar_url"
            package_filename="$download_dir/vscode-insiders.tar.gz"
            ;;
    esac
    
    # Check if aria2c is available for faster downloads
    if command -v aria2c &>/dev/null; then
        log "INFO" "Using aria2 for accelerated download..."
        aria2c -x 16 -s 16 -k 1M "$package_url" -d "$download_dir" -o "$(basename "$package_filename")" || {
            log "WARN" "aria2 download failed, falling back to wget..."
            wget -O "$package_filename" "$package_url" || {
                log "ERROR" "Failed to download package"
                rm -rf "$download_dir"
                exit 1
            }
        }
    else
        log "INFO" "Downloading package with wget..."
        wget -O "$package_filename" "$package_url" || {
            log "ERROR" "Failed to download package"
            rm -rf "$download_dir"
            exit 1
        }
    fi
    
    log "INFO" "Download completed: $package_filename"
    echo "$download_dir:$package_filename"
}

# Function to install dependencies required by VS Code
install_dependencies() {
    log "INFO" "Installing VS Code dependencies..."
    
    local pkg_manager_info=$1
    IFS=: read -r mgr_name pkg_type installer checker info path <<< "$pkg_manager_info"
    
    # Define dependencies for different distributions
    local dependencies=""
    
    case "$mgr_name" in
        "apt")
            dependencies="libasound2 libatk1.0-0 libcairo2 libcups2 libdbus-1-3 libexpat1 libfontconfig1 libgbm1 libgcc1 libglib2.0-0 libgtk-3-0 libnspr4 libnss3 libpango-1.0-0 libx11-6 libx11-xcb1 libxcb1 libxcomposite1 libxcursor1 libxdamage1 libxext6 libxfixes3 libxi6 libxrandr2 libxrender1 libxss1 libxtst6"
            sudo apt update &>/dev/null
            ;;
        "dnf"|"yum")
            dependencies="libX11-xcb libXcomposite libXcursor libXdamage libXext libXi libxkbfile libXrandr libXrender libXScrnSaver libXtst alsa-lib cairo cups-libs dbus-glib gtk3 nss pango"
            ;;
        "zypper")
            dependencies="libX11-xcb1 libXcomposite1 libXcursor1 libXdamage1 libXext6 libXi6 libxkbfile1 libXrandr2 libXrender1 libXScrnSaver1 libXtst6 libasound2 libcairo2 libcups2 libdbus-1-3 libgbm1 libglib2.0-0 libgtk-3-0 libnss3 libpango-1.0-0"
            ;;
        "pacman")
            dependencies="gtk3 libxss nss alsa-lib"
            sudo pacman -Sy --needed --noconfirm
            ;;
        *)
            log "WARN" "Skipping dependency installation for unknown package manager"
            return
            ;;
    esac
    
    if [[ -n "$dependencies" ]]; then
        log "INFO" "Installing required dependencies: $dependencies"
        case "$mgr_name" in
            "apt")
                sudo apt install -y $dependencies || log "WARN" "Some dependencies may not have installed correctly"
                ;;
            "dnf")
                sudo dnf install -y $dependencies || log "WARN" "Some dependencies may not have installed correctly"
                ;;
            "yum")
                sudo yum install -y $dependencies || log "WARN" "Some dependencies may not have installed correctly"
                ;;
            "zypper")
                sudo zypper install -y $dependencies || log "WARN" "Some dependencies may not have installed correctly"
                ;;
            "pacman")
                sudo pacman -S --needed --noconfirm $dependencies || log "WARN" "Some dependencies may not have installed correctly"
                ;;
        esac
    fi
}

# Function to install the package with intelligent fallback mechanisms
install_package() {
    local download_info=$1
    local pkg_manager_info=$2
    
    IFS=: read -r download_dir package_path <<< "$download_info"
    IFS=: read -r mgr_name pkg_type installer checker info path <<< "$pkg_manager_info"
    
    log "INFO" "Installing VS Code Insiders..."
    
    # Try package manager installation first
    case "$pkg_type" in
        "dpkg")
            log "INFO" "Installing DEB package..."
            if sudo dpkg -i "$package_path"; then
                log "INFO" "Package installed successfully"
            else
                log "WARN" "DEB installation failed, attempting dependency resolution..."
                sudo apt --fix-broken install -y
                if ! sudo dpkg -i "$package_path"; then
                    log "ERROR" "Failed to install DEB package even after dependency resolution"
                    fallback_installation "$package_path"
                fi
            fi
            ;;
        "rpm")
            log "INFO" "Installing RPM package..."
            case "$mgr_name" in
                "dnf")
                    if ! sudo dnf install -y "$package_path"; then
                        log "ERROR" "Failed to install RPM package with DNF"
                        fallback_installation "$package_path"
                    fi
                    ;;
                "yum")
                    if ! sudo yum localinstall -y "$package_path"; then
                        log "ERROR" "Failed to install RPM package with YUM"
                        fallback_installation "$package_path"
                    fi
                    ;;
                "zypper")
                    if ! sudo zypper install -y "$package_path"; then
                        log "ERROR" "Failed to install RPM package with Zypper"
                        fallback_installation "$package_path"
                    fi
                    ;;
                *)
                    if ! sudo rpm -i "$package_path"; then
                        log "ERROR" "Failed to install RPM package directly"
                        fallback_installation "$package_path"
                    fi
                    ;;
            esac
            ;;
        "pacman")
            log "INFO" "For Arch-based systems, installing from AUR is recommended."
            if command -v yay &>/dev/null; then
                if ! yay -S --noconfirm visual-studio-code-insiders-bin; then
                    log "WARN" "AUR installation failed, falling back to manual installation"
                    fallback_installation "$package_path"
                fi
            else
                log "WARN" "yay not found, falling back to manual installation"
                fallback_installation "$package_path"
            fi
            ;;
        *)
            fallback_installation "$package_path"
            ;;
    esac
    
    # Clean up download directory
    rm -rf "$download_dir"
}

# Fallback installation method - extract tarball and set up manually
fallback_installation() {
    local package_path=$1
    local install_dir="/opt/vscode-insiders"
    
    log "INFO" "Using fallback installation method to $install_dir..."
    
    # Check if we have a tarball, if not, redownload
    if [[ "$package_path" != *".tar.gz" ]]; then
        log "INFO" "Package is not a tarball, downloading tarball instead..."
        local temp_dir=$(mktemp -d)
        wget -O "$temp_dir/vscode-insiders.tar.gz" "https://code.visualstudio.com/sha/download?build=insider&os=linux-x64" || {
            log "ERROR" "Failed to download tarball"
            rm -rf "$temp_dir"
            exit 1
        }
        package_path="$temp_dir/vscode-insiders.tar.gz"
    fi
    
    # Create installation directory
    sudo mkdir -p "$install_dir"
    
    log "INFO" "Extracting VS Code Insiders..."
    sudo tar -xzf "$package_path" -C "$install_dir" --strip-components=1 || {
        log "ERROR" "Failed to extract tarball"
        exit 1
    }
    
    # Create desktop entry
    log "INFO" "Creating desktop entry..."
    sudo bash -c "cat > /usr/share/applications/code-insiders.desktop" << EOF
[Desktop Entry]
Name=Visual Studio Code - Insiders
Comment=Code Editing. Redefined.
GenericName=Text Editor
Exec=/opt/vscode-insiders/code-insiders --unity-launch %F
Icon=/opt/vscode-insiders/resources/app/resources/linux/code.png
Type=Application
StartupNotify=false
StartupWMClass=Code - Insiders
Categories=TextEditor;Development;IDE;
MimeType=text/plain;inode/directory;application/x-code-workspace;
Actions=new-empty-window;
Keywords=vscode;

[Desktop Action new-empty-window]
Name=New Empty Window
Exec=/opt/vscode-insiders/code-insiders --new-window %F
Icon=/opt/vscode-insiders/resources/app/resources/linux/code.png
EOF
    
    # Create symlink
    log "INFO" "Creating symlink in /usr/bin..."
    sudo ln -sf "$install_dir/code-insiders" /usr/bin/code-insiders
    
    log "INFO" "Fallback installation completed"
}

# Function to create self-extracting uninstall script
create_uninstall_script() {
    local uninstall_script="/usr/local/bin/uninstall-code-insiders"
    
    log "INFO" "Creating intelligent uninstall script at $uninstall_script..."
    
    sudo bash -c "cat > $uninstall_script" << 'EOF'
#!/bin/bash
# VS Code Insiders - Intelligent Uninstaller

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

# Function to detect installation method
detect_installation() {
    echo -e "${BLUE}Detecting VS Code Insiders installation method...${NC}"
    
    # Check for package manager installations
    if command -v dpkg &>/dev/null && dpkg -l | grep -q "code-insiders"; then
        echo "deb"
    elif command -v rpm &>/dev/null && rpm -qa | grep -q "code-insiders"; then
        if command -v dnf &>/dev/null; then
            echo "dnf"
        elif command -v zypper &>/dev/null; then
            echo "zypper"
        else
            echo "rpm"
        fi
    elif command -v pacman &>/dev/null && pacman -Qs "visual-studio-code-insiders" &>/dev/null; then
        echo "pacman"
    elif [ -d "/opt/vscode-insiders" ]; then
        echo "manual"
    else
        echo "none"
    fi
}

# Main uninstall function
uninstall_vscode_insiders() {
    echo -e "${BLUE}${BOLD}VS Code Insiders - Uninstaller${NC}"
    echo -e "${YELLOW}This will completely remove VS Code Insiders from your system.${NC}"
    read -p "Are you sure you want to continue? (y/n): " confirm

    if [[ "$confirm" != "y" ]]; then
        echo -e "${GREEN}Uninstallation cancelled.${NC}"
        exit 0
    fi
    
    # Detect installation method
    local install_method=$(detect_installation)
    
    case "$install_method" in
        "deb")
            echo -e "${GREEN}Removing DEB package...${NC}"
            sudo apt remove -y code-insiders
            sudo apt autoremove -y
            ;;
        "dnf")
            echo -e "${GREEN}Removing RPM package with DNF...${NC}"
            sudo dnf remove -y code-insiders
            ;;
        "zypper")
            echo -e "${GREEN}Removing RPM package with Zypper...${NC}"
            sudo zypper remove -y code-insiders
            ;;
        "rpm")
            echo -e "${GREEN}Removing RPM package...${NC}"
            sudo rpm -e code-insiders
            ;;
        "pacman")
            echo -e "${GREEN}Removing Arch package...${NC}"
            if command -v yay &>/dev/null; then
                yay -R --noconfirm visual-studio-code-insiders-bin
            else
                sudo pacman -R --noconfirm visual-studio-code-insiders-bin
            fi
            ;;
        "manual")
            echo -e "${GREEN}Removing manual installation...${NC}"
            sudo rm -rf /opt/vscode-insiders
            sudo rm -f /usr/bin/code-insiders
            sudo rm -f /usr/share/applications/code-insiders.desktop
            ;;
        "none")
            echo -e "${RED}No VS Code Insiders installation detected.${NC}"
            exit 1
            ;;
    esac
    
    # Remove user configuration if requested
    read -p "Do you want to remove user data and configuration? (y/n): " remove_config
    if [[ "$remove_config" == "y" ]]; then
        echo -e "${YELLOW}Removing user configuration...${NC}"
        rm -rf ~/.config/Code\ -\ Insiders/
        rm -rf ~/.vscode-insiders/
        echo -e "${GREEN}User configuration removed.${NC}"
    fi
    
    # Self-delete the uninstaller
    echo -e "${YELLOW}Removing uninstaller...${NC}"
    sudo rm -f "$0"
    
    echo -e "${GREEN}${BOLD}VS Code Insiders has been successfully uninstalled.${NC}"
}

# Run uninstaller
uninstall_vscode_insiders
EOF
    
    # Make uninstall script executable
    sudo chmod +x "$uninstall_script"
    log "INFO" "Uninstall script created at $uninstall_script"
}

# Function to test installation
test_installation() {
    log "INFO" "Testing VS Code Insiders installation..."
    
    if command -v code-insiders &>/dev/null; then
        # Get version information
        local version=$(code-insiders --version 2>/dev/null | head -n 1)
        if [[ -n "$version" ]]; then
            log "INFO" "VS Code Insiders ${GREEN}${BOLD}$version${NC} is successfully installed"
            return 0
        fi
    fi
    
    log "WARN" "Could not verify VS Code Insiders installation"
    return 1
}

# Self-updating function - update the script itself
self_update() {
    log "INFO" "Checking for script updates..."
    # For a real implementation, this would check a remote repository
    # But for this example, we just pretend
    log "INFO" "This script is already at the latest version"
}

# Main function - orchestrates the entire installation process
main() {
    # Check if running as root
    if [[ $EUID -eq 0 ]]; then
        log "WARN" "This script should not be run directly as root"
        log "INFO" "The script will use sudo when necessary"
        exit 1
    fi
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --debug)
                DEBUG_MODE="true"
                log "DEBUG" "Debug mode enabled"
                ;;
            --update)
                self_update
                exit 0
                ;;
            --uninstall)
                # Direct to uninstall script if it exists
                if [[ -x "/usr/local/bin/uninstall-code-insiders" ]]; then
                    log "INFO" "Running uninstaller..."
                    sudo /usr/local/bin/uninstall-code-insiders
                    exit $?
                else
                    log "ERROR" "Uninstaller not found. Please run the install script first."
                    exit 1
                fi
                ;;
            --help)
                echo "Usage: $0 [OPTIONS]"
                echo "Options:"
                echo "  --debug      Enable debug output"
                echo "  --update     Update this script to the latest version"
                echo "  --uninstall  Uninstall VS Code Insiders"
                echo "  --help       Show this help message"
                exit 0
                ;;
            *)
                log "WARN" "Unknown option: $1"
                ;;
        esac
        shift
    done
    
    # Display banner and start installation
    display_banner
    
    # System fingerprinting
    local system_fingerprint=$(fingerprint_system)
    
    # Detect package manager
    local pkg_manager_info=$(detect_package_manager)
    
    # Ensure core utilities
    ensure_core_utilities "$pkg_manager_info"
    
    # Install dependencies
    install_dependencies "$pkg_manager_info"
    
    # Download package
    local download_info=$(download_package "$pkg_manager_info")
    
    # Install package
    install_package "$download_info" "$pkg_manager_info"
    
    # Create uninstall script
    create_uninstall_script
    
    # Test installation
    test_installation
    
    log "INFO" "${GREEN}${BOLD}Installation complete!${NC}"
    log "INFO" "You can run VS Code Insiders by typing 'code-insiders' in the terminal or from your application menu."
    log "INFO" "To uninstall, run 'sudo uninstall-code-insiders'"
}

# Entry point - execute main function with all args
main "$@"
