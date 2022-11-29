#!/bin/bash

rm -rf $0

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

cur_dir=$(pwd)

# check root
[[ $EUID -ne 0 ]] && echo -e "${red}Lỗi：${plain} Kịch bản này phải được chạy bằng cách sử dụng người dùng root!\n" && exit 1

# check os
if [[ -f /etc/redhat-release ]]; then
    release="centos"
elif cat /etc/issue | grep -Eqi "debian"; then
    release="debian"
elif cat /etc/issue | grep -Eqi "ubuntu"; then
    release="ubuntu"
elif cat /etc/issue | grep -Eqi "centos|red hat|redhat"; then
    release="centos"
elif cat /proc/version | grep -Eqi "debian"; then
    release="debian"
elif cat /proc/version | grep -Eqi "ubuntu"; then
    release="ubuntu"
elif cat /proc/version | grep -Eqi "centos|red hat|redhat"; then
    release="centos"
else
    echo -e "${red}Phiên bản hệ thống không được phát hiện, vui lòng liên hệ với tác giả kịch bản!${plain}\n" && exit 1
fi

arch=$(arch)

if [[ $arch == "x86_64" || $arch == "x64" || $arch == "amd64" ]]; then
  arch="64"
elif [[ $arch == "aarch64" || $arch == "arm64" ]]; then
  arch="arm64-v8a"
else
  arch="64"
  echo -e "${red}Không có lược đồ nào được phát hiện, hãy sử dụng lược đồ mặc định: ${arch}${plain}"
fi

echo "Kiến trúc: ${arch}"

if [ "$(getconf WORD_BIT)" != '32' ] && [ "$(getconf LONG_BIT)" != '64' ] ; then
    echo "Phần mềm này không hỗ trợ hệ thống 32-bit (x86), vui lòng sử dụng hệ thống 64-bit (x86_64), nếu phát hiện sai, vui lòng liên hệ với tác giả"
    exit 2
fi

os_version=""

# os version
if [[ -f /etc/os-release ]]; then
    os_version=$(awk -F'[= ."]' '/VERSION_ID/{print $3}' /etc/os-release)
fi
if [[ -z "$os_version" && -f /etc/lsb-release ]]; then
    os_version=$(awk -F'[= ."]+' '/DISTRIB_RELEASE/{print $2}' /etc/lsb-release)
fi

if [[ x"${release}" == x"centos" ]]; then
    if [[ ${os_version} -le 6 ]]; then
        echo -e "${red}Vui lòng sử dụng CentOS 7 trở lên!${plain}\n" && exit 1
    fi
elif [[ x"${release}" == x"ubuntu" ]]; then
    if [[ ${os_version} -lt 16 ]]; then
        echo -e "${red}Vui lòng sử dụng Ubuntu 16 trở lên！${plain}\n" && exit 1
    fi
elif [[ x"${release}" == x"debian" ]]; then
    if [[ ${os_version} -lt 8 ]]; then
        echo -e "${red}Vui lòng sử dụng Debian 8 trở lên！${plain}\n" && exit 1
    fi
fi

install_base() {
    if [[ x"${release}" == x"centos" ]]; then
        yum install epel-release -y
        yum install wget curl unzip tar crontabs socat -y
    else
        apt update -y
        apt install wget curl unzip tar cron socat -y
    fi
}

# 0: running, 1: not running, 2: not installed
check_status() {
    if [[ ! -f /etc/systemd/system/AikoR.service ]]; then
        return 2
    fi
    temp=$(systemctl status AikoR | grep Active | awk '{print $3}' | cut -d "(" -f2 | cut -d ")" -f1)
    if [[ x"${temp}" == x"running" ]]; then
        return 0
    else
        return 1
    fi
}

install_acme() {
    curl https://get.acme.sh | sh
}

install_AikoR() {
    if [[ -e /usr/local/AikoR/ ]]; then
        rm /usr/local/AikoR/ -rf
    fi

    mkdir /usr/local/AikoR/ -p
	cd /usr/local/AikoR/

    if  [ $# == 0 ] ;then
        last_version=$(curl -Ls "https://api.github.com/repos/AikoCute-Offical/AikoR/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
        if [[ ! -n "$last_version" ]]; then
            echo -e "${red}Không phát hiện được phiên bản AikoR, có thể đã vượt quá giới hạn Github API, vui lòng thử lại sau hoặc chỉ định cài đặt phiên bản AikoR theo cách thủ công${plain}"
            exit 1
        fi
        echo -e "Phiên bản mới nhất của AikoR đã được phát hiện：${last_version}，Bắt đầu cài đặt"
        wget -N --no-check-certificate -O /usr/local/AikoR/AikoR-linux.zip https://github.com/AikoCute-Offical/AikoR/releases/download/${last_version}/AikoR-linux-${arch}.zip
        if [[ $? -ne 0 ]]; then
            echo -e "${red}Tải xuống AikoR không thành công, hãy đảm bảo máy chủ của bạn có thể tải xuống tệp Github${plain}"
            exit 1
        fi
    else
        last_version=$1
        url="https://github.com/AikoCute-Offical/AikoR/releases/download/${last_version}/AikoR-linux-${arch}.zip"
        echo -e "Bắt đầu cài đặt AikoR v$1"
        wget -N --no-check-certificate -O /usr/local/AikoR/AikoR-linux.zip ${url}
        if [[ $? -ne 0 ]]; then
            echo -e "${red}Tải xuống AikoR v $ 1 Không thành công, hãy đảm bảo rằng phiên bản này tồn tại${plain}"
            exit 1
        fi
    fi

    unzip AikoR-linux.zip
    rm AikoR-linux.zip -f
    chmod +x AikoR
    mkdir /etc/AikoR/ -p
    rm /etc/systemd/system/AikoR.service -f
    file="https://raw.githubusercontent.com/AikoCute-Offical/AikoR-install/vi/AikoR.service"
    wget -N --no-check-certificate -O /etc/systemd/system/AikoR.service ${file}
    #cp -f AikoR.service /etc/systemd/system/
    systemctl daemon-reload
    systemctl stop AikoR
    systemctl enable AikoR
    echo -e "${green}AikoR ${last_version}${plain} Quá trình cài đặt hoàn tất, nó đã được thiết lập để bắt đầu tự động"
    cp geoip.dat /etc/AikoR/
    cp geosite.dat /etc/AikoR/ 

    if [[ ! -f /etc/AikoR/aiko.yml ]]; then
        cp aiko.yml /etc/AikoR/
        echo -e ""
        echo -e "Cài đặt mới, vui lòng tham khảo hướng dẫn trước ： https: //github.com/AikoCute-Offical/AikoR，Định cấu hình nội dung cần thiết"
    else
        systemctl start AikoR
        sleep 2
        check_status
        echo -e ""
        if [[ $? == 0 ]]; then
            echo -e "${green}AikoR khởi động lại thành công${plain}"
        else
            echo -e "${red}AikoR Có thể không khởi động, vui lòng sử dụng xem nhật ký AikoR để kiểm tra thông tin nhật ký, nếu không khởi động được, định dạng cấu hình có thể đã bị thay đổi, vui lòng vào wiki để kiểm tra ： https://github.com/AikoCute-Offical/ AikoR${plain}"
        fi
    fi

    if [[ ! -f /etc/AikoR/dns.json ]]; then
        cp dns.json /etc/AikoR/
    fi
    if [[ ! -f /etc/AikoR/route.json ]]; then
        cp route.json /etc/AikoR/
    fi
    if [[ ! -f /etc/AikoR/custom_outbound.json ]]; then
        cp custom_outbound.json /etc/AikoR/
    fi
    curl -o /usr/bin/AikoR -Ls https://raw.githubusercontent.com/Shadowdragon1997/script/main/AikoR.sh
    chmod +x /usr/bin/AikoR
    ln -s /usr/bin/AikoR /usr/bin/aikor # Chữ thường tương thích
    chmod +x /usr/bin/aikor
    
#settings CertFile và KeyFile
read -p "Vui lòng chọn config CertFile và KeyFile: " choose_node

if [ "$choose_node" == "quabnv_1" ]; then
      wget https://raw.githubusercontent.com/Shadowdragon1997/pem_key/quabnv/pem/vt1/vt1.pem -O /etc/AikoR/server.pem
      wget https://raw.githubusercontent.com/Shadowdragon1997/pem_key/quabnv/pem/vt1/vt1.privkey.pem -O /etc/AikoR/privkey.pem

elif [ "$choose_node" == "quabnv_2" ]; then
      wget https://raw.githubusercontent.com/Shadowdragon1997/pem_key/quabnv/pem/vt2/vt2.pem -O /etc/AikoR/server.pem
      wget https://raw.githubusercontent.com/Shadowdragon1997/pem_key/quabnv/pem/vt2/vt2.privkey.pem -O /etc/AikoR/privkey.pem
      
elif [ "$choose_node" == "khoa_1" ]; then
      wget https://raw.githubusercontent.com/Shadowdragon1997/pem_key/anhkhoa/pem/vt1/vt1.pem -O /etc/AikoR/server.pem
      wget https://raw.githubusercontent.com/Shadowdragon1997/pem_key/anhkhoa/pem/vt1/vt1.privkey.pem -O /etc/AikoR/privkey.pem
      
elif [ "$choose_node" == "khoa_2" ]; then
      wget https://raw.githubusercontent.com/Shadowdragon1997/pem_key/anhkhoa/pem/vt2/vt2.pem -O /etc/AikoR/server.pem
      wget https://raw.githubusercontent.com/Shadowdragon1997/pem_key/anhkhoa/pem/vt2/vt2.privkey.pem -O /etc/AikoR/privkey.pem

elif [ "$choose_node" == "khoa_3" ]; then
      wget https://raw.githubusercontent.com/Shadowdragon1997/pem_key/anhkhoa/pem/vt3/vt3.pem -O /etc/AikoR/server.pem
      wget https://raw.githubusercontent.com/Shadowdragon1997/pem_key/anhkhoa/pem/vt3/vt3.privkey.pem -O /etc/AikoR/privkey.pem

elif [ "$choose_node" == "khoa_4" ]; then
      wget https://raw.githubusercontent.com/Shadowdragon1997/pem_key/anhkhoa/pem/vt4/vt4.pem -O /etc/AikoR/server.pem
      wget https://raw.githubusercontent.com/Shadowdragon1997/pem_key/anhkhoa/pem/vt4/vt4.privkey.pem -O /etc/AikoR/privkey.pem
      
elif [ "$choose_node" == "khoa_5" ]; then
      wget https://raw.githubusercontent.com/Shadowdragon1997/pem_key/anhkhoa/pem/vt5/vt5.pem -O /etc/AikoR/server.pem
      wget https://raw.githubusercontent.com/Shadowdragon1997/pem_key/anhkhoa/pem/vt5/vt5.privkey.pem -O /etc/AikoR/privkey.pem

elif [ "$choose_node" == "khoa_6" ]; then
      wget https://raw.githubusercontent.com/Shadowdragon1997/pem_key/anhkhoa/pem/vt6/vt6.pem -O /etc/AikoR/server.pem
      wget https://raw.githubusercontent.com/Shadowdragon1997/pem_key/anhkhoa/pem/vt6/vt6.privkey.pem -O /etc/AikoR/privkey.pem
      
elif [ "$choose_node" == "khoa_7" ]; then
      wget https://raw.githubusercontent.com/Shadowdragon1997/pem_key/anhkhoa/pem/vt7/vt7.pem -O /etc/AikoR/server.pem
      wget https://raw.githubusercontent.com/Shadowdragon1997/pem_key/anhkhoa/pem/vt7/vt7.privkey.pem -O /etc/AikoR/privkey.pem
      
elif [ "$choose_node" == "khoa_gaming_1" ]; then
      wget https://raw.githubusercontent.com/Shadowdragon1997/pem_key/anhkhoa/pem/gaming1/gaming1.pem -O /etc/AikoR/server.pem
      wget https://raw.githubusercontent.com/Shadowdragon1997/pem_key/anhkhoa/pem/gaming1/gaming1.privkey.pem -O /etc/AikoR/privkey.pem

elif [ "$choose_node" == "khoa_gaming_2" ]; then
      wget https://raw.githubusercontent.com/Shadowdragon1997/pem_key/anhkhoa/pem/gaming2/gaming2.pem -O /etc/AikoR/server.pem
      wget https://raw.githubusercontent.com/Shadowdragon1997/pem_key/anhkhoa/pem/gaming2/gaming2.privkey.pem -O /etc/AikoR/privkey.pem

elif [ "$choose_node" == "khoa_gaming_3" ]; then
      wget https://raw.githubusercontent.com/Shadowdragon1997/pem_key/anhkhoa/pem/gaming3/gaming3.pem -O /etc/AikoR/server.pem
      wget https://raw.githubusercontent.com/Shadowdragon1997/pem_key/anhkhoa/pem/gaming3/gaming3.privkey.pem -O /etc/AikoR/privkey.pem

elif [ "$choose_node" == "khoa_router_1" ]; then
      wget https://raw.githubusercontent.com/Shadowdragon1997/pem_key/anhkhoa/pem/router1/router1.pem -O /etc/AikoR/server.pem
      wget https://raw.githubusercontent.com/Shadowdragon1997/pem_key/anhkhoa/pem/router1/router1.privkey.pem -O /etc/AikoR/privkey.pem

fi

#settings config file
    read -p "Số node ID Trojan: " Idtrojan
	echo "---------------"
    read -p "Số node ID Vmess: " Idvmess
	echo "---------------"
    read -p "CertDomain của bạn là (tên miền trỏ IP Server): " CertDomain
	echo "---------------"
    read -p "ApiHost của bạn là (link website): " ApiHost
        echo "---------------"
    read -p "ApiKey của bạn là: " ApiKey
        echo "---------------"
    read -p "Tốc độ mà bạn muốn giới hạn là: " Numberspeed
        echo "---------------"
    read -p "Số lượng thiết bị giới hạn có thể sử dụng là: " Numberdevice
        echo "---------------"
    read -p "Email tài khoản Cloudflare là: " EmailCloudflare
        echo "---------------"
    read -p "API Key Cloudflare là: " ApiKeyCloudflare
        echo "---------------"

	rm -f /etc/AikoR/aiko.yml
	if [[ -z $(~/.acme.sh/acme.sh -v 2>/dev/null) ]]; then
		curl https://get.acme.sh | sh -s email=script@github.com
		source ~/.bashrc
		bash ~/.acme.sh/acme.sh --upgrade --auto-upgrade
	fi
         cat <<EOF >/etc/AikoR/aiko.yml
Log:
  Level: warning # Log level: none, error, warning, info, debug 
  AccessPath: # /etc/AikoR/access.Log
  ErrorPath: # /etc/AikoR/error.log
DnsConfigPath: # /etc/AikoR/dns.json # Path to dns config, check https://xtls.github.io/config/dns.html for help
RouteConfigPath: # /etc/AikoR/route.json # Path to route config, check https://xtls.github.io/config/routing.html for help
InboundConfigPath: # /etc/AikoR/custom_inbound.json # Path to custom inbound config, check https://xtls.github.io/config/inbound.html for help
OutboundConfigPath: # /etc/AikoR/custom_outbound.json # Path to custom outbound config, check https://xtls.github.io/config/outbound.html for help
ConnetionConfig:
  Handshake: 4 # Handshake time limit, Second
  ConnIdle: 86400 # Connection idle time limit, Second
  UplinkOnly: 2 # Time limit when the connection downstream is closed, Second
  DownlinkOnly: 4 # Time limit when the connection is closed after the uplink is closed, Second
  BufferSize: 64 # The internal cache size of each connection, kB 
Nodes:
  -
    PanelType: "V2board" # Panel type: SSpanel, V2board, PMpanel, Proxypanel
    ApiConfig:
      ApiHost: "$ApiHost"
      ApiKey: "$ApiKey"
      NodeID: $Idtrojan
      NodeType: Trojan # Node type: V2ray, Trojan, Shadowsocks, Shadowsocks-Plugin
      Timeout: 30 # Timeout for the api request
      EnableVless: false # Enable Vless for V2ray Type
      EnableXTLS: false # Enable XTLS for V2ray and Trojan
      SpeedLimit: $Numberspeed # Mbps, Local settings will replace remote settings, 0 means disable
      DeviceLimit: $Numberdevice # Local settings will replace remote settings, 0 means disable
      RuleListPath: # /etc/AikoR/AikoBlock Path to local rulelist file
    ControllerConfig:
      ListenIP: 0.0.0.0 # IP address you want to listen
      SendIP: 0.0.0.0 # IP address you want to send pacakage
      UpdatePeriodic: 60 # Time to update the nodeinfo, how many sec.
      EnableDNS: false # Use custom DNS config, Please ensure that you set the dns.json well
      DNSType: AsIs # AsIs, UseIP, UseIPv4, UseIPv6, DNS strategy
      DisableUploadTraffic: false # Disable Upload Traffic to the panel
      DisableGetRule: false # Disable Get Rule from the panel
      DisableIVCheck: false # Disable the anti-reply protection for Shadowsocks
      EnableProxyProtocol: false # Only works for WebSocket and TCP
      EnableFallback: false # Only support for Trojan and Vless
      FallBackConfigs:  # Support multiple fallbacks
        -
          SNI: # TLS SNI(Server Name Indication), Empty for any
          Path: # HTTP PATH, Empty for any
          Dest: 80 # Required, Destination of fallback, check https://xtls.github.io/config/fallback/ for details.
          ProxyProtocolVer: 0 # Send PROXY protocol version, 0 for dsable
      CertConfig:
        CertMode: file # Option about how to get certificate: none, file, http, dns. Choose "none" will forcedly disable the tls config.
        CertDomain: "$CertDomain" # Domain to cert
        CertFile: /etc/AikoR/server.pem # Provided if the CertMode is file
        KeyFile: /etc/AikoR/privkey.pem
        Provider: cloudflare # DNS cert provider, Get the full support list here: https://go-acme.github.io/lego/dns/
        Email: nguyendovietkhoa@gmail.com
        DNSEnv: # DNS ENV option used by DNS provider
          CLOUDFLARE_EMAIL: "$EmailCloudflare"
          CLOUDFLARE_API_KEY: "$ApiKeyCloudflare"
  -
    PanelType: "V2board" # Panel type: SSpanel, V2board, PMpanel, Proxypanel
    ApiConfig:
      ApiHost: "$ApiHost"
      ApiKey: "$ApiKey"
      NodeID: $Idvmess
      NodeType: V2ray # Node type: V2ray, Trojan, Shadowsocks, Shadowsocks-Plugin
      Timeout: 30 # Timeout for the api request
      EnableVless: false # Enable Vless for V2ray Type
      EnableXTLS: false # Enable XTLS for V2ray and Trojan
      SpeedLimit: $Numberspeed # Mbps, Local settings will replace remote settings, 0 means disable
      DeviceLimit: $Numberdevice # Local settings will replace remote settings, 0 means disable
      RuleListPath: # /etc/AikoR/AikoBlock Path to local rulelist file
    ControllerConfig:
      ListenIP: 0.0.0.0 # IP address you want to listen
      SendIP: 0.0.0.0 # IP address you want to send pacakage
      UpdatePeriodic: 60 # Time to update the nodeinfo, how many sec.
      EnableDNS: false # Use custom DNS config, Please ensure that you set the dns.json well
      DNSType: AsIs # AsIs, UseIP, UseIPv4, UseIPv6, DNS strategy
      DisableUploadTraffic: false # Disable Upload Traffic to the panel
      DisableGetRule: false # Disable Get Rule from the panel
      DisableIVCheck: false # Disable the anti-reply protection for Shadowsocks
      EnableProxyProtocol: false # Only works for WebSocket and TCP
      EnableFallback: false # Only support for Trojan and Vless
      FallBackConfigs:  # Support multiple fallbacks
        -
          SNI: # TLS SNI(Server Name Indication), Empty for any
          Path: # HTTP PATH, Empty for any
          Dest: 80 # Required, Destination of fallback, check https://xtls.github.io/config/fallback/ for details.
          ProxyProtocolVer: 0 # Send PROXY protocol version, 0 for dsable
      CertConfig:
        CertMode: file # Option about how to get certificate: none, file, http, dns. Choose "none" will forcedly disable the tls config.
        CertDomain: "$CertDomain" # Domain to cert
        CertFile: /etc/AikoR/server.pem # Provided if the CertMode is file
        KeyFile: /etc/AikoR/privkey.pem
        Provider: cloudflare # DNS cert provider, Get the full support list here: https://go-acme.github.io/lego/dns/
        Email: nguyendovietkhoa@gmail.com
        DNSEnv: # DNS ENV option used by DNS provider
          CLOUDFLARE_EMAIL: "$EmailCloudflare"
          CLOUDFLARE_API_KEY: "$ApiKeyCloudflare"
EOF

    echo -e ""
    echo " Cách sử dụng AikoR. kịch bản quản lý     " 
    echo "------------------------------------------"
    echo "           AikoR   - Show admin menu      "
    echo "           AikoR - AikoR by AikoCute      "
    echo "------------------------------------------"
}

echo -e "${green}Bắt đầu cài đặt${plain}"
install_base
install_acme
install_AikoR $1
