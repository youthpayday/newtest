#!/usr/bin/bash
plain='\033[0m'
yellow='\033[0;33m'
green='\033[0;32m'
blue='\033[1;34m'
red='\033[0;31m'
pink='\033[1;35m'
set -euo pipefail
#mkdir -p /opt/Goose
#CONSTANTS
GOOSE_PATH="/opt/Goose"

DOWNLAOD_PATH=$GOOSE_PATH

SERVICE_FILE_PATH="/etc/systemd/system/goose-relay.service"
PORT=8449
CONFIG_TEXT="{
  \"server_host\": \"0.0.0.0\",
  \"server_port\": 8449,
  \"tunnel_key\":  \"5dd9409f23ed6b7873f07fbe470c2cb52f09254f4d6d81d841b4a02d90f72062\"
}"

if [[ "$(uname -s)" != "Linux" ]]; then
  error "This installer only supports Linux. Detected: $(uname -s)"
  exit 1
fi

if [[ $EUID -ne 0 ]]; then
  error "Please run as root or with sudo:"
  echo "  sudo bash $0"
  exit 1
fi

write_config() {
  local text="$1"
  local config_file="$2"

  # Write the text to the config file
  printf "%s\n" "$text" > "$config_file"
}
#install some common utils
install_base() {
    if [[ ${OS_RELEASE} == "ubuntu" || ${OS_RELEASE} == "debian" ]]; then
        apt install wget tar -y
    elif [[ ${OS_RELEASE} == "centos" ]]; then
        yum install wget tar -y
    fi
}
function LOGE() {
    echo -e "${red}[ERR] $* ${plain}"
}
function LOGI() {
    echo -e "${green}[INF] $* ${plain}"
}
function LOGD() {
    echo -e "${yellow}[DEG] $* ${plain}"
}
install_systemd_service() {
    LOGD "Starting to install the goose systemd service..."
    if [ -f "${SERVICE_FILE_PATH}" ]; then
        rm -rf ${SERVICE_FILE_PATH}
    fi
    #create service file
    touch ${SERVICE_FILE_PATH}
    if [ $? -ne 0 ]; then
        LOGE "create service file failed,exit"
        exit 1
    else
        LOGI "create service file success..."
    fi
    cat >${SERVICE_FILE_PATH} <<EOF
[Unit]
Description=GooseRelayVPN exit server
After=network.target

[Service]
Type=simple
WorkingDirectory=${DOWNLAOD_PATH}/GooseRelayVPN-server-${GOOSEVPN_VERSION}-linux-${OS_ARCH}
ExecStart=${BINARY_FILE_PATH} -config ${CONFIG_FILE_PATH}
Restart=always
RestartSec=3
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF
    chmod 644 ${SERVICE_FILE_PATH}
    systemctl daemon-reload
    LOGD "Install goose systemd service success"
}
#for cert issue
ssl_cert_issue(){
    bash <(curl -Ls https://raw.githubusercontent.com/FranzKafkaYu/BashScripts/main/SSLAutoInstall/SSLAutoInstall.sh)
}
#installation path create & delete,1->create,0->delete
create_or_delete_path() {

    if [[ $# -ne 1 ]]; then
        LOGE "invalid input,should be one paremete,and can be 0 or 1"
        exit 1
    fi
    CONFIG_FILE_PATH="oldtext"
    if [[ "$1" == "1" ]]; then
        LOGI "Will create ${DOWNLAOD_PATH} and ${CONFIG_FILE_PATH} for GOOSE.."
        rm -rf ${DOWNLAOD_PATH}
        mkdir -p ${DOWNLAOD_PATH}

        if [[ $? -ne 0 ]]; then
            LOGE "create ${DOWNLAOD_PATH} and  for sGOOSE failed"
            exit 1
        else
            LOGI "create ${DOWNLAOD_PATH} adn ${CONFIG_FILE_PATH} for sGOOSE success"
        fi
    elif [[ "$1" == "0" ]]; then
        LOGI "Will delete ${DOWNLAOD_PATH} and ${CONFIG_FILE_PATH}..."
        rm -rf ${DOWNLAOD_PATH} ${CONFIG_FILE_PATH}
        if [[ $? -ne 0 ]]; then
            LOGE "delete ${DOWNLAOD_PATH} and ${CONFIG_FILE_PATH} failed"
            exit 1
        else
            LOGI "delete ${DOWNLAOD_PATH} and ${CONFIG_FILE_PATH} success"
        fi
    fi

}
clear_GOOSE() {
    LOGD "Starting to clear the GOOSE..."
    create_or_delete_path 0 && rm -rf ${SERVICE_FILE_PATH} && rm -rf ${BINARY_FILE_PATH}
    LOGD "Completed clearing sing-box"
}

arch_check() {
    LOGI "Detect current system architecture in..."
    OS_ARCH=$(arch)
    LOGI "The current system architecture is ${OS_ARCH}"

    if [[ ${OS_ARCH} == "x86_64" || ${OS_ARCH} == "x64" || ${OS_ARCH} == "amd64" ]]; then
        OS_ARCH="amd64"
    elif [[ ${OS_ARCH} == "aarch64" || ${OS_ARCH} == "arm64" ]]; then
        OS_ARCH="arm64"
    else
        OS_ARCH="amd64"
        LOGE "Failed to detect system architecture, use default architecture: ${OS_ARCH}"
    fi
    LOGI "After the system architecture detection is completed, the current system architecture is:${OS_ARCH}"
}
os_check() {
    LOGI "Detect current system..."
    if [[ -f /etc/redhat-release ]]; then
        OS_RELEASE="centos"
    elif cat /etc/issue | grep -Eqi "debian"; then
        OS_RELEASE="debian"
    elif cat /etc/issue | grep -Eqi "ubuntu"; then
        OS_RELEASE="ubuntu"
    elif cat /etc/issue | grep -Eqi "centos|red hat|redhat"; then
        OS_RELEASE="centos"
    elif cat /proc/version | grep -Eqi "debian"; then
        OS_RELEASE="debian"
    elif cat /proc/version | grep -Eqi "ubuntu"; then
        OS_RELEASE="ubuntu"
    elif cat /proc/version | grep -Eqi "centos|red hat|redhat"; then
        OS_RELEASE="centos"
    else
        LOGE "System detection error, please contact the script author!" && exit 1
    fi
    LOGI "The system detection is completed, the current system is: ${OS_RELEASE}"
}

enable_Goose() {
    local service_name="$1"
    systemctl enable "$service_name"
    if [[ $? == 0 ]]; then
        LOGI "Set the servicex to start automatically at boot"
    else
        LOGE "Failed to set the servicex to boot automatically"
    fi
}
check_service_status() {
  local service_name="$1"
  
  # Start the service
  sudo systemctl start "$service_name"
  enable_Goose "$service_name"
  # Check if the service started successfully
  if systemctl is-active --quiet "$service_name"; then
    echo "The $service_name service is running successfully."
  else
    echo "Failed to start the $service_name service."
    # Optionally check the service logs
    sudo journalctl -u "$service_name" --since "5 minutes ago"
  fi
}
download_goosevpn() {
    echo "Start downloading goose-relayvpn..."
    os_check && arch_check && install_base
    if [[ $# -gt 1 ]]; then
        echo -e "${red}invalid input,plz check your input: $* ${plain}"
        exit 1
    elif [[ $# -eq 1 ]]; then
        GOOSEVPN_VERSION=$1
        local GOOSEVPN_VERSION_TEMP="v${GOOSEVPN_VERSION}"
    else
        local GOOSEVPN_VERSION_TEMP=$(curl -Ls "https://api.github.com/repos/kianmhz/GooseRelayVPN/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
        GOOSEVPN_VERSION=${GOOSEVPN_VERSION_TEMP:1}
    fi
    LOGI "Will choose to use version: ${GOOSEVPN_VERSION}"

    local DOWANLOAD_URL="https://github.com/kianmhz/GooseRelayVPN/releases/latest/download/GooseRelayVPN-server-v${GOOSEVPN_VERSION}-linux-${OS_ARCH}.tar.gz"

    #here we need create directory for GOOSE
    create_or_delete_path 1
    wget -N --no-check-certificate -O ${GOOSE_PATH}/GooseRelayVPN-server-${GOOSEVPN_VERSION}-linux-${OS_ARCH}.tar.gz ${DOWANLOAD_URL}

    if [[ $? -ne 0 ]]; then
        LOGE "Download GOOSE failed,plz be sure that your network work properly and can access github"
        create_or_delete_path 0
        exit 1
    else
        LOGI "Download sing-box success"
    fi
}

install_GOOSE-box() {
    
    LOGD "Start installing goosevpn..."
    if [[ $# -ne 0 ]]; then
        download_goosevpn $1
    else
        download_goosevpn
    fi
    BINARY_FILE_PATH="${DOWNLAOD_PATH}/GooseRelayVPN-server-v${GOOSEVPN_VERSION}-linux-${OS_ARCH}/goose-server"
    CONFIG_FILE_PATH="${DOWNLAOD_PATH}/GooseRelayVPN-server-v${GOOSEVPN_VERSION}-linux-${OS_ARCH}/config.json"
    if [[ ! -f "${DOWNLAOD_PATH}/GooseRelayVPN-server-v${GOOSEVPN_VERSION}-linux-${OS_ARCH}.tar.gz" ]]; then
        clear_GOOSE
        LOGE "could not find GOOSE packages,plz check dowanload GOOSE whether suceess"
        exit 1
    fi
    cd ${DOWNLAOD_PATH}
    #decompress sing-box packages
    tar -xvf "GooseRelayVPN-server-v${GOOSEVPN_VERSION}-linux-${OS_ARCH}.tar.gz" && cd "GooseRelayVPN-server-v${GOOSEVPN_VERSION}-linux-${OS_ARCH}"
    
    if [[ $? -ne 0 ]]; then
        clear_GOOSE
        LOGE "Failed to decompress the GOOSE installation package, the script exited"
        exit 1
    else
        LOGI "Unzip the GOOSE installation package success"
    fi
    write_config "$CONFIG_TEXT" "config.json"
    #install sing-box
    #install -m 755 sing-box ${BINARY_FILE_PATH}
    if [[ ! -f "${DOWNLAOD_PATH}/GooseRelayVPN-server-v${GOOSEVPN_VERSION}-linux-{$OS_ARCH)/goose-server" ]]; then
        clear_GOOSE
        LOGE "could not find GOOSE packages,plz check dowanload GOOSE whether suceess"
        exit 1
    fi
    install_systemd_service
    check_service_status "goose-relay"
    LOGI "GOOSE installed success and started success"
}



if command -v ufw &>/dev/null; then
  ufw allow "$PORT"/tcp comment "exit-node" || true
  info "ufw rule added for port $PORT/tcp"
elif command -v firewall-cmd &>/dev/null; then
  firewall-cmd --permanent --add-port="$PORT"/tcp || true
  firewall-cmd --reload || true
  info "firewalld rule added for port $PORT/tcp"
else
  warn "No ufw or firewalld found. Make sure port $PORT/tcp is open in your VPS firewall panel."
fi
echo "Download GOOSE VPN started on your os "
install_GOOSE-box

HEALTH_URL="http://127.0.0.1:${PORT}/healthz"
if command -v curl &>/dev/null; then
  HEALTH=$(curl -sf --max-time 5 "$HEALTH_URL" 2>/dev/null || echo "")
  if echo "$HEALTH" | grep -q '"ok"'; then
    info "Health check OK: $HEALTH"
  else
    warn "Health check returned unexpected response. Check: journalctl -u exit-node -n 30"
  fi
else
  warn "curl not found — skipping health check. You can test manually:"
  echo "  curl http://127.0.0.1:${PORT}/healthz"
fi
PUBLIC_IP=$(curl -sf --max-time 5 https://ifconfig.me 2>/dev/null || echo "YOUR-VPS-IP")
echo "your public is $PUBLIC_IP"
