#!/bin/bash

export FILE_PATH=${FILE_PATH:-'./.npm'}
export KEEPALIVE=${KEEPALIVE:-'0'}
export OPENSERVER=${OPENSERVER:-'1'}

export CF_IP=${CF_IP:-'try.cloudflare.com'}
export ECH_PORT=${ECH_PORT:-'8001'}
export ECH_PROTOCOL=${ECH_PROTOCOL:-'ws'}
export ECH_LISTEN=${ECH_LISTEN:-'proxy://127.0.0.1:10808'}
export ECH_DNS=${ECH_DNS:-'dns.alidns.com/dns-query'}
export ECH_URL=${ECH_URL:-'cloudflare-ech.com'}
export SUB_URL=${SUB_URL:-''}
export SUB_NAME=${SUB_NAME:-''}
export MYIP_URL=${MYIP_URL:-''}
export MY_DOMAIN=${MY_DOMAIN:-''}

export UUID=${UUID:-'7160b696-dd5e-42e3-a024-145e92cec916'}
export NEZHA_VERSION=${NEZHA_VERSION:-'V1'}
export NEZHA_SERVER=${NEZHA_SERVER:-''}
export NEZHA_KEY=${NEZHA_KEY:-''}
export NEZHA_PORT=${NEZHA_PORT:-'443'}

export ARGO_DOMAIN=${ARGO_DOMAIN:-'ag222.1.b.3.9.0.d.0.0.1.0.a.2.ip6.arpa'}
export ARGO_AUTH=${ARGO_AUTH:-'eyJhIjoiODE1MjkzMDQxNzVmM2E0YjllMWJlNTc5NTBlNWZmNzMiLCJ0IjoiYjUxOTI2YWEtMTdhZi00M2Y0LWE4MDktMTE5OTBmZmRjYTViIiwicyI6Ik1EVXhNR1F4TldJdFlUWTFZeTAwTnpZd0xUbGpaREV0WmpaaU5qTXhZVEZoWTJVNCJ9'}

hint() { echo -e "\033[33m\033[01m$*\033[0m"; }

if [ ! -d "${FILE_PATH}" ]; then
  mkdir -p "${FILE_PATH}"
fi

cleanup_files() {
  rm -rf ${FILE_PATH}/*.log ${FILE_PATH}/*.txt ${FILE_PATH}/*.yml ${FILE_PATH}/tunnel.*
}

# Download Files
download_program() {
  local program_name="$1"
  local default_url="$2"
  local x64_url="$3"

  local download_url
  case "$(uname -m)" in
    x86_64|amd64|x64)
      download_url="${x64_url}"
      ;;
    *)
      download_url="${default_url}"
      ;;
  esac

  if [ ! -f "${program_name}" ]; then
    if [ -n "${download_url}" ]; then
      echo "Downloading ${program_name}..." > /dev/null
      if command -v curl &> /dev/null; then
        curl -sSL "${download_url}" -o "${program_name}"
      elif command -v wget &> /dev/null; then
        wget -qO "${program_name}" "${download_url}"
      fi
      echo "Downloaded ${program_name}" > /dev/null
    else
      echo "Skipping download for ${program_name}" > /dev/null
    fi
  else
    echo "${program_name} already exists, skipping download" > /dev/null
  fi
}

initialize_downloads() {
  if [ -n "${NEZHA_SERVER}" ] && [ -n "${NEZHA_KEY}" ]; then
    case "${NEZHA_VERSION}" in
      "V0" )
        download_program "${FILE_PATH}/npm" "https://github.com/kahunama/myfile/releases/download/main/nezha-agent_arm" "https://github.com/kahunama/myfile/releases/download/main/nezha-agent"
        ;;
      "V1" )
        download_program "${FILE_PATH}/npm" "https://github.com/mytcgd/myfiles/releases/download/main/nezha-agentv1_arm" "https://github.com/mytcgd/myfiles/releases/download/main/nezha-agentv1"
        ;;
    esac
    sleep 3
    chmod +x ${FILE_PATH}/npm
  fi

  if [ -n "${ECH_PROTOCOL}" ] && [ -n "${ECH_PORT}" ]; then
    download_program "${FILE_PATH}/ech" "https://github.com/kahunama/myfile/releases/download/main/ech-tunnel-linux-arm64" "https://github.com/kahunama/myfile/releases/download/main/ech-tunnel-linux-amd64"
    sleep 3
    chmod +x ${FILE_PATH}/ech
  fi

  if [ "${OPENSERVER}" = "1" ]; then
    download_program "${FILE_PATH}/server" "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-arm64" "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64"
    sleep 3
    chmod +x ${FILE_PATH}/server
  fi
}

# my_config
my_config() {
  argo_type() {
    if [ -e "${FILE_PATH}/server" ] && [ -z "${ARGO_AUTH}" ] && [ -z "${ARGO_DOMAIN}" ]; then
      echo "ARGO_AUTH or ARGO_DOMAIN is empty, use Quick Tunnels" > /dev/null
      return
    fi

    if [ -e "${FILE_PATH}/server" ] && [ -n "$(echo "${ARGO_AUTH}" | grep TunnelSecret)" ]; then
      echo ${ARGO_AUTH} > ${FILE_PATH}/tunnel.json
      cat > ${FILE_PATH}/tunnel.yml << EOF
tunnel=$(echo "${ARGO_AUTH}" | cut -d\" -f12)
credentials-file: ${FILE_PATH}/tunnel.json
protocol: http2

ingress:
  - hostname: ${ARGO_DOMAIN}
    service: http://localhost: ${ECH_PORT}
    originRequest:
      noTLSVerify: true
  - service: http_status:404
EOF
    else
      echo "ARGO_AUTH Mismatch TunnelSecret" > /dev/null
    fi
  }

  args() {
    if [ -e "${FILE_PATH}/server" ]; then
      if [ -n "$(echo "${ARGO_AUTH}" | grep '^[A-Z0-9a-z=]\{120,250\}$')" ]; then
        args="tunnel --edge-ip-version auto --no-autoupdate --protocol http2 run --token ${ARGO_AUTH}"
      elif [ -n "$(echo "${ARGO_AUTH}" | grep TunnelSecret)" ]; then
        args="tunnel --edge-ip-version auto --config ${FILE_PATH}/tunnel.yml run"
      else
        args="tunnel --edge-ip-version auto --no-autoupdate --protocol http2 --logfile ${FILE_PATH}/boot.log --loglevel info --url http://localhost:${ECH_PORT}"
      fi
    fi
  }

  if [ -n "${NEZHA_SERVER}" ] && [ -n "${NEZHA_KEY}" ]; then
    nezhacfg() {
      tlsPorts=("443" "8443" "2096" "2087" "2083" "2053")
      case "${NEZHA_VERSION}" in
        "V0" )
          if [[ " ${tlsPorts[@]} " =~ " ${NEZHA_PORT} " ]]; then
            NEZHA_TLS="--tls"
          else
            NEZHA_TLS=""
          fi
          ;;
        "V1" )
          if [[ " ${tlsPorts[@]} " =~ " ${NEZHA_PORT} " ]]; then
            NEZHA_TLS="true"
          else
            NEZHA_TLS="false"
          fi
          cat > ${FILE_PATH}/config.yml << ABC
client_secret: $NEZHA_KEY
debug: false
disable_auto_update: true
disable_command_execute: false
disable_force_update: true
disable_nat: false
disable_send_query: false
gpu: false
insecure_tls: false
ip_report_period: 1800
report_delay: 4
server: $NEZHA_SERVER:$NEZHA_PORT
skip_connection_count: true
skip_procs_count: true
temperature: false
tls: $NEZHA_TLS
use_gitee_to_upgrade: false
use_ipv6_country_code: false
uuid: $UUID
ABC
          ;;
      esac
    }
    nezhacfg
  fi

  argo_type
  args
}

# run
run_server() {
  ${FILE_PATH}/server $args >/dev/null 2>&1 &
}

run_ech() {
  ${FILE_PATH}/ech -l "${ECH_PROTOCOL}://0.0.0.0:${ECH_PORT}" -token "${UUID}" >/dev/null 2>&1 &
}

run_npm() {
  case "${NEZHA_VERSION}" in
    "V0" )
      ${FILE_PATH}/npm -s ${NEZHA_SERVER}:${NEZHA_PORT} -p ${NEZHA_KEY} ${NEZHA_TLS} --report-delay=4 --skip-conn --skip-procs --disable-auto-update >/dev/null 2>&1 &
      ;;
    "V1" )
      ${FILE_PATH}/npm -c ${FILE_PATH}/config.yml >/dev/null 2>&1 &
      ;;
  esac
}

Detect_process() {
  local process_name="$1"
  local pids=""
  if command -v pidof &> /dev/null; then
    pids=$(pidof "$process_name" 2>/dev/null)
  elif command -v pgrep &> /dev/null; then
    pids=$(pgrep -x "$process_name" 2>/dev/null)
  elif command -v ps &> /dev/null; then
    pids=$(ps -eo pid,comm | awk -v name="$process_name" '$2 == name {print $1}')
  fi
  [ -n "$pids" ] && echo "$pids"
}

keep_alive() {
  while true; do
    if [ -e "${FILE_PATH}/server" ] && [ "${OPENSERVER}" = "1" ] && [ -z "$(Detect_process "server")" ]; then
      run_server
      hint "server runs again !"
    fi
    sleep 5
    if [ -e "${FILE_PATH}/ech" ] && [ -n "${ECH_PROTOCOL}" ] && [ -n "${ECH_PORT}" ] && [ -z "$(Detect_process "ech")" ]; then
      run_ech
      hint "ech runs again !"
    fi
    sleep 5
    if [ -e "${FILE_PATH}/npm" ] && [ -n "${NEZHA_SERVER}" ] && [ -n "${NEZHA_KEY}" ] && [ -z "$(Detect_process "npm")" ]; then
      run_npm
      hint "npm runs again !"
    fi
    sleep 50
  done
}

run_processes() {
  if [ "${OPENSERVER}" = "1" ] && [ -e "${FILE_PATH}/server" ] && [ -z "$(Detect_process "server")" ]; then
    run_server
    sleep 5
  fi
  if [ -n "${ECH_PROTOCOL}" ] && [ -n "${ECH_PORT}" ] && [ -e "${FILE_PATH}/ech" ] && [ -z "$(Detect_process "ech")" ]; then
    run_ech
    sleep 1
  fi
  if [ -n "${NEZHA_SERVER}" ] && [ -n "${NEZHA_KEY}" ] && [ -e "${FILE_PATH}/npm" ] && [ -z "$(Detect_process "npm")" ]; then
    run_npm
    sleep 1
  fi

  check_hostname_change && sleep 2
  if [ -n "$SUB_URL" ]; then
    upload >/dev/null 2>&1 &
  else
    build_urls
  fi

  if [ -n "${KEEPALIVE}" ] && [ "${KEEPALIVE}" = "1" ]; then
    keep_alive 2>&1 &
  elif [ -n "${KEEPALIVE}" ] && [ "${KEEPALIVE}" = "0" ]; then
    sleep 5
    rm -rf ${FILE_PATH}/server ${FILE_PATH}/ech ${FILE_PATH}/npm ${FILE_PATH}/*.yml ${FILE_PATH}/tunnel.*
  fi

  if [ -n "${OPENHTTP}" ] && [ "${OPENHTTP}" = "0" ]; then
    tail -f /dev/null
  fi
}

# check_hostname
check_hostname_change() {
  if [ -s "${FILE_PATH}/boot.log" ]; then
    export ARGO_DOMAIN=$(cat ${FILE_PATH}/boot.log | grep -o "info.*https://.*trycloudflare.com" | sed "s@.*https://@@g" | tail -n 1)
    sleep 2
  fi
  if [ "${OPENSERVER}" = "0" ] && [ -n "${MY_DOMAIN}" ]; then
    export ARGO_DOMAIN="${MY_DOMAIN}"
  fi
  export ECH_SERVER="wss://${ARGO_DOMAIN}:8443/tunnel"
  if [ -n "${ECH_PROTOCOL}" ] && [ -n "${ECH_PORT}" ]; then
    UPLOAD_DATA="ech://server=${ECH_SERVER}&listen=${ECH_LISTEN}&token=${UUID}&dns=${ECH_DNS}&ech=${ECH_URL}&ip=${CF_IP}&name=${SUB_NAME}"
  fi
  export UPLOAD_DATA
}

# build_urls
build_urls() {
  if [ -n "${UPLOAD_DATA}" ]; then
    echo -e "${UPLOAD_DATA}" | base64 | tr -d '\n' > "${FILE_PATH}/log.txt"
  fi
}

# upload
upload_subscription() {
  if command -v curl &> /dev/null; then
    response=$(curl -s -X POST -H "Content-Type: application/json" -d "{\"URL_NAME\":\"$SUB_NAME\",\"URL\":\"$UPLOAD_DATA\"}" $SUB_URL)
  elif command -v wget &> /dev/null; then
    response=$(wget -qO- --post-data="{\"URL_NAME\":\"$SUB_NAME\",\"URL\":\"$UPLOAD_DATA\"}" --header="Content-Type: application/json" $SUB_URL)
  fi
}

export previousargoDomain=""
upload() {
  if [ "${KEEPALIVE}" = "1" ] && [ "${OPENSERVER}" = "1" ] && [ -z "${ARGO_AUTH}" ]; then
    while true; do
      if [[ "$previousargoDomain" == "$ARGO_DOMAIN" ]]; then
        echo "domain name has not been updated, no need to upload" > /dev/null
      else
        upload_subscription
        build_urls
        export previousargoDomain="$ARGO_DOMAIN"
      fi
      sleep 60
      check_hostname_change && sleep 2
    done
  else
    upload_subscription
    build_urls
  fi
}

# main
main() {
  cleanup_files
  initialize_downloads
  my_config
  run_processes
}
main
