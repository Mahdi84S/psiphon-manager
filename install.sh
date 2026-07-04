#!/bin/bash

GREEN='\033[0;32m'
CYAN='\033[0;36m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

clear

echo -e "${CYAN}***************************************************${NC}"
echo -e "${CYAN}*                                                 *${NC}"
echo -e "${CYAN}*  MAHDI - VPN MANAGER SETUP                      *${NC}"
echo -e "${CYAN}*  Created by Mahdi                               *${NC}"
echo -e "${CYAN}*                                                 *${NC}"
echo -e "${CYAN}***************************************************${NC}"
echo -e "${YELLOW}    >>> Starting Installation <<<    ${NC}"
echo ""

if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}❌ Please run with root privileges (sudo su)${NC}"
    exit 1
fi

echo -e "${GREEN}[?] Please enter your Telegram Bot Token:${NC}"
read -p "Token: " BOT_TOKEN

echo -e "${GREEN}[?] Please enter your Admin Numeric ID:${NC}"
read -p "Admin ID: " ADMIN_ID

if [[ -z "$BOT_TOKEN" || -z "$ADMIN_ID" ]]; then
    echo -e "${RED}❌ Error: Token and Admin ID cannot be empty!${NC}"
    exit 1
fi

# 1. Dependencies
echo -e "${CYAN}[1/5] Installing Dependencies...${NC}"
apt update -q -y
apt install -q -y wget curl nano python3 python3-pip unzip jq

rm /usr/lib/python3.*/EXTERNALLY-MANAGED 2>/dev/null
pip3 install pyTelegramBotAPI requests pysocks --break-system-packages 2>/dev/null || pip3 install pyTelegramBotAPI requests pysocks

# 2. Directories & Core Engine
echo -e "${CYAN}[2/5] Setting up Core Engine...${NC}"
mkdir -p /etc/vpncore-multi
mkdir -p /usr/local/bin

wget -qO /usr/local/bin/vpncore https://github.com/Psiphon-Labs/psiphon-tunnel-core-binaries/raw/master/linux/psiphon-tunnel-core-x86_64
chmod +x /usr/local/bin/vpncore

if [ ! -f /etc/vpncore-multi/instances.json ]; then
cat <<EOF > /etc/vpncore-multi/instances.json
{
    "2080": "US"
}
EOF
fi

# 3. Dynamic Configuration Engine
cat <<'EOF' > /etc/vpncore-multi/template.sh
#!/bin/bash
PORT=$1
REGION=$2
cat <<EON > /etc/vpncore-multi/config-$PORT.json
{
    "LocalSocksProxyPort": $PORT,
    "EgressRegion": "$REGION",
    "PropagationChannelId": "FFFFFFFFFFFFFFFF",
    "SponsorId": "FFFFFFFFFFFFFFFF",
    "RemoteServerListUrl": "https://s3.amazonaws.com//psiphon/web/mjr4-p23r-puwl/server_list_compressed",
    "RemoteServerListSignaturePublicKey": "MIICIDANBgkqhkiG9w0BAQEFAAOCAg0AMIICCAKCAgEAt7Ls+/39r+T6zNW7GiVpJfzq/xvL9SBH5rIFnk0RXYEYavax3WS6HOD35eTAqn8AniOwiH+DOkvgSKF2caqk/y1dfq47Pdymtwzp9ikpB1C5OfAysXzBiwVJlCdajBKvBZDerV1cMvRzCKvKwRmvDmHgphQQ7WfXIGbRbmmk6opMBh3roE42KcotLFtqp0RRwLtcBRNtCdsrVsjiI1Lqz/lH+T61sGjSjQ3CHMuZYSQJZo/KrvzgQXpkaCTdbObxHqb6/+i1qaVOfEsvjoiyzTxJADvSytVtcTjijhPEV6XskJVHE1Zgl+7rATr/pDQkw6DPCNBS1+Y6fy7GstZALQXwEDN/qhQI9kWkHijT8ns+i1vGg00Mk/6J75arLhqcodWsdeG/M/moWgqQAnlZAGVtJI1OgeF5fsPpXu4kctOfuZlGjVZXQNW34aOzm8r8S0eVZitPlbhcPiR4gT/aSMz/wd8lZlzZYsje/Jr8u/YtlwjjreZrGRmG8KMOzukV3lLmMppXFMvl4bxv6YFEmIuTsOhbLTwFgh7KYNjodLj/LsqRVfwz31PgWQFTEPICV7GCvgVlPRxnofqKSjgTWI4mxDhBpVcATvaoBl1L/6WLbFvBsoAUBItWwctO2xalKxF5szhGm8lccoc5MZr8kfE0uxMgsxz4er68iCID+rsCAQM=",
    "RemoteServerListDownloadFilename": "remote_server_list",
    "FetchRemoteServerListRetryIntervalMilliseconds": 1000
}
EON
EOF
chmod +x /etc/vpncore-multi/template.sh

# 4. Create Telegram Bot Manager
echo -e "${CYAN}[3/5] Creating Telegram Bot Manager...${NC}"
cat <<EOF > /etc/vpncore-multi/manager_bot.py
import telebot
import subprocess
import json
import time
import os
import requests
from telebot import types

BOT_TOKEN = "${BOT_TOKEN}"
ADMIN_ID = ${ADMIN_ID}
DATA_DIR = "/etc/vpncore-multi"
INSTANCES_FILE = os.path.join(DATA_DIR, "instances.json")

bot = telebot.TeleBot(BOT_TOKEN)

ALL_REGIONS = {
    "🇺🇸 US - America": "US", "🇩🇪 DE - Germany": "DE", "🇬🇧 GB - United Kingdom": "GB",
    "🇫🇷 FR - France": "FR", "🇨🇦 CA - Canada": "CA", "🇳🇱 NL - Netherlands": "NL",
    "🇨🇭 CH - Switzerland": "CH", "🇸🇪 SE - Sweden": "SE", "🇫🇮 FI - Finland": "FI"
}

user_states = {}

def load_instances():
    if os.path.exists(INSTANCES_FILE):
        try:
            with open(INSTANCES_FILE, 'r') as f: return json.load(f)
        except: pass
    return {"2080": "US"}

def save_instances(data):
    with open(INSTANCES_FILE, 'w') as f: json.dump(data, f, indent=4)

def manage_service(port, region, action="start"):
    service_name = f"vpncore-{port}"
    service_file = f"/etc/systemd/system/{service_name}.service"
    
    # Force Stop & Kill to prevent hanging
    subprocess.run(f"systemctl stop {service_name}", shell=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    subprocess.run(f"pkill -f 'config-{port}.json'", shell=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    
    if action == "stop":
        subprocess.run(f"systemctl disable {service_name}", shell=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        if os.path.exists(service_file): os.remove(service_file)
        if os.path.exists(f"{DATA_DIR}/config-{port}.json"): os.remove(f"{DATA_DIR}/config-{port}.json")
        subprocess.run("systemctl daemon-reload", shell=True)
        return

    # Create config and systemd unit
    subprocess.run(f"{DATA_DIR}/template.sh {port} {region}", shell=True)
    with open(service_file, 'w') as f:
        f.write(f"""[Unit]\nDescription=VPN Core Port {port}\nAfter=network.target\n\n[Service]\nType=simple\nUser=root\nWorkingDirectory={DATA_DIR}\nExecStart=/usr/local/bin/vpncore -config {DATA_DIR}/config-{port}.json\nRestart=always\nRestartSec=3\n\n[Install]\nWantedBy=multi-user.target\n""")
        
    subprocess.run("systemctl daemon-reload", shell=True)
    subprocess.run(f"systemctl enable {service_name}", shell=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    subprocess.run(f"systemctl start {service_name}", shell=True)

def get_current_ip(port):
    try:
        r = requests.get('https://api.ipify.org', proxies={'http': f'socks5h://127.0.0.1:{port}', 'https': f'socks5h://127.0.0.1:{port}'}, timeout=3)
        return r.text if r.status_code == 200 else None
    except: return None

def main_menu():
    markup = types.ReplyKeyboardMarkup(row_width=2, resize_keyboard=True)
    markup.add("📊 Status / وضعیت پورت‌ها", "🌍 Add Location / لوکیشن جدید", "🔄 Change Location/Port / تغییر پورت و لوکیشن", "🗑 Delete Service / حذف سرویس")
    return markup

@bot.message_handler(commands=['start', 'help'])
def welcome(message):
    if message.from_user.id != ADMIN_ID: return
    bot.reply_to(message, "👋 Welcome to VPN Manager Dashboard\n\n`Created by Mahdi`", reply_markup=main_menu(), parse_mode="Markdown")

@bot.message_handler(func=lambda message: message.from_user.id == ADMIN_ID)
def handle_text(message):
    msg = message.text
    cid = message.chat.id
    
    if msg == "📊 Status / وضعیت پورت‌ها":
        bot.send_message(cid, "⏳ Checking core instances...")
        instances = load_instances()
        res = "📋 **Active Proxy Instances:**\n\n"
        for port, reg in instances.items():
            status = subprocess.run(f"systemctl is-active vpncore-{port}", shell=True, capture_output=True, text=True).stdout.strip()
            icon = "✅" if status == "active" else "🔴"
            ip = get_current_ip(port) or "No IP (Connecting...)"
            res += f"{icon} **Port:** `{port}` | **Region:** `{reg}`\n🌐 **IP:** `{ip}`\n───────────────────\n"
        res += "\n`Created by Mahdi`"
        bot.send_message(cid, res, parse_mode="Markdown")
        
    elif msg == "🌍 Add Location / لوکیشن جدید":
        markup = types.InlineKeyboardMarkup(row_width=3)
        buttons = [types.InlineKeyboardButton(name, callback_data=f"add_{code}") for name, code in ALL_REGIONS.items()]
        markup.add(*buttons)
        bot.send_message(cid, "🗺 Select Target Region:", reply_markup=markup)
        
    elif msg == "🔄 Change Location/Port / تغییر پورت و لوکیشن":
        instances = load_instances()
        markup = types.InlineKeyboardMarkup(row_width=2)
        for port, reg in instances.items():
            markup.add(types.InlineKeyboardButton(f"⚙️ Port {port} ({reg})", callback_data=f"modselect_{port}"))
        bot.send_message(cid, "📍 Select which instance you want to modify:", reply_markup=markup)
        
    elif msg == "🗑 Delete Service / حذف سرویس":
        instances = load_instances()
        if len(instances) <= 1:
            bot.send_message(cid, "⚠️ Cannot delete the last remaining instance.")
            return
        markup = types.InlineKeyboardMarkup(row_width=2)
        for port, reg in instances.items():
            markup.add(types.InlineKeyboardButton(f"🗑 Remove {port} ({reg})", callback_data=f"del_{port}"))
        bot.send_message(cid, "🗑 Select the instance to completely delete:", reply_markup=markup)

@bot.callback_query_handler(func=lambda call: call.data.startswith('add_'))
def cb_add(call):
    reg = call.data.split("_")[1]
    user_states[call.message.chat.id] = {"action": "adding", "region": reg}
    bot.edit_message_text(f"Selected Region: **{reg}**\n\nEnter SOCKS5 Custom Port (1024-65535):", call.message.chat.id, call.message.message_id, parse_mode="Markdown")

@bot.callback_query_handler(func=lambda call: call.data.startswith('modselect_'))
def cb_mod(call):
    port = call.data.split("_")[1]
    markup = types.InlineKeyboardMarkup(row_width=2)
    markup.add(types.InlineKeyboardButton("🌍 Change Only Region", callback_data=f"modreg_{port}"),
               types.InlineKeyboardButton("🔢 Change Only Port", callback_data=f"modport_{port}"))
    bot.edit_message_text(f"Modifying Instance on Port **{port}**:", call.message.chat.id, call.message.message_id, reply_markup=markup, parse_mode="Markdown")

@bot.callback_query_handler(func=lambda call: call.data.startswith('modreg_'))
def cb_modreg(call):
    port = call.data.split("_")[1]
    markup = types.InlineKeyboardMarkup(row_width=3)
    for name, code in ALL_REGIONS.items():
        markup.add(types.InlineKeyboardButton(name, callback_data=f"setreg_{port}_{code}"))
    bot.edit_message_text(f"Select New Region for Port **{port}**:", call.message.chat.id, call.message.message_id, reply_markup=markup, parse_mode="Markdown")

@bot.callback_query_handler(func=lambda call: call.data.startswith('setreg_'))
def cb_setreg(call):
    _, port, new_reg = call.data.split("_")
    instances = load_instances()
    instances[port] = new_reg
    save_instances(instances)
    bot.edit_message_text(f"⏳ Rebuilding Port {port} to Region {new_reg}...", call.message.chat.id, call.message.message_id)
    manage_service(port, new_reg, "start")
    bot.send_message(call.message.chat.id, f"✅ Region successfully changed to `{new_reg}`!", parse_mode="Markdown")

@bot.callback_query_handler(func=lambda call: call.data.startswith('modport_'))
def cb_modport(call):
    port = call.data.split("_")[1]
    user_states[call.message.chat.id] = {"action": "modifying_port", "old_port": port}
    bot.edit_message_text(f"Enter New Port number for old Port **{port}**:", call.message.chat.id, call.message.message_id, parse_mode="Markdown")

@bot.callback_query_handler(func=lambda call: call.data.startswith('del_'))
def cb_del(call):
    port = call.data.split("_")[1]
    instances = load_instances()
    if port in instances:
        manage_service(port, None, "stop")
        instances.pop(port)
        save_instances(instances)
        bot.edit_message_text(f"🗑 Instance on Port `{port}` has been totally removed.", call.message.chat.id, call.message.message_id, parse_mode="Markdown")

@bot.message_handler(func=lambda message: message.from_user.id == ADMIN_ID and message.chat.id in user_states)
def process_inputs(message):
    cid = message.chat.id
    state = user_states[cid]
    val = message.text.strip()
    
    if not val.isdigit() or not (1024 <= int(val) <= 65535):
        bot.send_message(cid, "❌ Invalid Port. Enter a digit between 1024 and 65535:")
        return

    instances = load_instances()
    
    if state["action"] == "adding":
        if val in instances:
            bot.send_message(cid, "❌ Port already in use! Try another one:")
            return
        reg = state["region"]
        instances[val] = reg
        save_instances(instances)
        bot.send_message(cid, f"⏳ Provisioning Core proxy on Port {val} ({reg})...")
        manage_service(val, reg, "start")
        bot.send_message(cid, f"✅ Configured and started on port `{val}`!", parse_mode="Markdown", reply_markup=main_menu())
        user_states.pop(cid)
        
    elif state["action"] == "modifying_port":
        if val in instances:
            bot.send_message(cid, "❌ Target Port already in use! Try another one:")
            return
        old_port = state["old_port"]
        reg = instances.pop(old_port)
        manage_service(old_port, None, "stop")
        
        instances[val] = reg
        save_instances(instances)
        manage_service(val, reg, "start")
        bot.send_message(cid, f"✅ Port altered from `{old_port}` to `{val}`!", parse_mode="Markdown", reply_markup=main_menu())
        user_states.pop(cid)

bot.infinity_polling()
EOF

# 5. Create Terminal Interactive Menu Script (/usr/local/bin/vpn-menu)
echo -e "${CYAN}[4/5] Creating CLI Engine Terminal Menu...${NC}"
cat <<'EOF' > /usr/local/bin/vpn-menu
#!/bin/bash
DATA_DIR="/etc/vpncore-multi"
INSTANCES_FILE="$DATA_DIR/instances.json"

show_menu() {
    clear
    echo -e "\033[0;36m***************************************************\033[0m"
    echo -e "\033[0;36m*                                                 *\033[0m"
    echo -e "\033[0;36m*  MAHDI - TERMINAL VPN MANAGER INFRASTRUCTURE    *\033[0m"
    echo -e "\033[0;36m*  Created by Mahdi                               *\033[0m"
    echo -e "\033[0;36m*                                                 *\033[0m"
    echo -e "\033[0;36m***************************************************\033[0m"
    echo -e "1) 📊 View Service Instances Status"
    echo -e "2) 🌍 Add New Multi-Location Proxy Instance"
    echo -e "3) 🔄 Modify Existing Instance (Port/Region)"
    echo -e "4) 🗑 Delete/Purge Instance"
    echo -e "5) ❌ Exit Terminal Menu"
    echo -ne "\nSelect Option: "
}

manage_core() {
    port=$1; region=$2; action=$3
    service_name="vpncore-$port"
    systemctl stop $service_name &>/dev/null
    pkill -f "config-$port.json" &>/dev/null
    if [ "$action" == "stop" ]; then
        systemctl disable $service_name &>/dev/null
        rm -f "/etc/systemd/system/$service_name.service"
        rm -f "$DATA_DIR/config-$port.json"
        systemctl daemon-reload
        return
    fi
    $DATA_DIR/template.sh $port $region
    cat <<EON > /etc/systemd/system/$service_name.service
[Unit]
Description=VPN Core Port $port
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=$DATA_DIR
ExecStart=/usr/local/bin/vpncore -config $DATA_DIR/config-$port.json
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EON
    systemctl daemon-reload
    systemctl enable $service_name &>/dev/null
    systemctl start $service_name
}

while true; do
    show_menu
    read opt
    case $opt in
        1)
            echo -e "\n--- Running Services ---"
            jq -r 'to_entries[] | "\(.key) \(.value)"' $INSTANCES_FILE | while read p r; do
                stat=$(systemctl is-active vpncore-$p)
                echo -e "Port: \033[0;32m$p\033[0m | Region: \033[0;33m$r\033[0m | Active: $stat"
            done
            echo -e "\nPress enter to go back..."; read
            ;;
        2)
            echo -ne "Enter New Port: " && read nport
            echo -ne "Enter Region (e.g. US, DE, GB, FR): " && read nreg
            if jq -e ".\"$nport\"" $INSTANCES_FILE &>/dev/null; then
                echo "Error: Port already exists."
            else
                jq ".\"$nport\"=\"${nreg^^}\"" $INSTANCES_FILE > tmp.json && mv tmp.json $INSTANCES_FILE
                manage_core $nport ${nreg^^} "start"
                echo "Successfully Added!"
            fi
            sleep 2
            ;;
        3)
            echo -ne "Enter Existing Port to Modify: " && read mport
            if ! jq -e ".\"$mport\"" $INSTANCES_FILE &>/dev/null; then
                echo "Port not found."
            else
                echo "1) Change Region Only"
                echo "2) Change Port Only"
                read mopt
                if [ "$mopt" == "1" ]; then
                    echo -ne "Enter New Region: " && read mreg
                    jq ".\"$mport\"=\"${mreg^^}\"" $INSTANCES_FILE > tmp.json && mv tmp.json $INSTANCES_FILE
                    manage_core $mport ${mreg^^} "start"
                elif [ "$mopt" == "2" ]; then
                    echo -ne "Enter New Port number: " && read mnewport
                    reg=$(jq -r ".\"$mport\"" $INSTANCES_FILE)
                    manage_core $mport "" "stop"
                    jq "del(.\"$mport\") | .\"$mnewport\"=\"$reg\"" $INSTANCES_FILE > tmp.json && mv tmp.json $INSTANCES_FILE
                    manage_core $mnewport $reg "start"
                fi
                echo "Modified Successfully!"
            fi
            sleep 2
            ;;
        4)
            echo -ne "Enter Port to Delete: " && read dport
            if [ $(jq 'length' $INSTANCES_FILE) -le 1 ]; then
                echo "Cannot remove the last active instance."
            else
                manage_core $dport "" "stop"
                jq "del(.\"$dport\")" $INSTANCES_FILE > tmp.json && mv tmp.json $INSTANCES_FILE
                echo "Instance Purged."
            fi
            sleep 2
            ;;
        5)
            exit 0
            ;;
    esac
done
EOF
chmod +x /usr/local/bin/vpn-menu

# Initialize base instance
/etc/vpncore-multi/template.sh 2080 US

# Systemd Bot Daemon Setup
cat <<EOF > /etc/systemd/system/vpncore-bot.service
[Unit]
Description=Telegram Multi-Port Management Bot Engine Daemon
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/etc/vpncore-multi
ExecStart=/usr/bin/python3 /etc/vpncore-multi/manager_bot.py
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

echo -e "${CYAN}[5/5] Activating system services...${NC}"
systemctl daemon-reload

# Setup unit for default port 2080
cat <<EOF > /etc/systemd/system/vpncore-2080.service
[Unit]
Description=VPN Core Port 2080
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/etc/vpncore-multi
ExecStart=/usr/local/bin/vpncore -config /etc/vpncore-multi/config-2080.json
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable vpncore-2080 &>/dev/null
systemctl enable vpncore-bot &>/dev/null
systemctl restart vpncore-2080
systemctl restart vpncore-bot

echo -e "${GREEN}**************************************************${NC}"
echo -e "${GREEN}* INSTALLATION COMPLETE 🎉                       *${NC}"
echo -e "${GREEN}* Created by Mahdi                               *${NC}"
echo -e "${GREEN}**************************************************${NC}"
echo -e "⚡ Type \033[1;33mvpn-menu\033[0m anywhere inside your terminal to launch the menu."
echo -e "⚡ Or use your Telegram bot to control instances dynamically."
echo ""
