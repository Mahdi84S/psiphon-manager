#!/bin/bash

GREEN='\033[0;32m'
CYAN='\033[0;36m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

clear

echo -e "${CYAN}***************************************************${NC}"
echo -e "${CYAN}*                                                 *${NC}"
echo -e "${CYAN}*  MAHDI - VPN MANAGER SETUP                      *${NC}"
echo -e "${CYAN}*  Created by Mahdi                               *${NC}"
echo -e "${CYAN}*                                                 *${NC}"
echo -e "${CYAN}***************************************************${NC}"
echo -e "${YELLOW}    >>> Starting Installation <<<    ${NC}"
echo ""

# 1. Check Root Privileges
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}❌ Please run with root privileges (sudo su)${NC}"
    exit 1
fi

# 2. Get Telegram Bot Token and Admin ID
echo -e "${GREEN}[?] Please enter your Telegram Bot Token:${NC}"
read -p "Token: " BOT_TOKEN

echo -e "${GREEN}[?] Please enter your Admin Numeric ID:${NC}"
read -p "Admin ID: " ADMIN_ID

if [[ -z "$BOT_TOKEN" || -z "$ADMIN_ID" ]]; then
    echo -e "${RED}❌ Error: Token and Admin ID cannot be empty!${NC}"
    exit 1
fi

# 3. Install Dependencies
echo -e "${CYAN}[1/6] Updating System & Installing Dependencies...${NC}"
apt update -q -y
apt install -q -y wget curl nano python3 python3-pip unzip

# Install Python Libraries
echo -e "${CYAN}[2/6] Installing Python Libraries...${NC}"
rm /usr/lib/python3.*/EXTERNALLY-MANAGED 2>/dev/null
pip3 install pyTelegramBotAPI requests pysocks --break-system-packages 2>/dev/null || pip3 install pyTelegramBotAPI requests pysocks

# 4. Install Core Binary & Setup Directories
echo -e "${CYAN}[3/6] Installing Core VPN Engine...${NC}"
wget -qO /usr/local/bin/vpncore https://github.com/Psiphon-Labs/psiphon-tunnel-core-binaries/raw/master/linux/psiphon-tunnel-core-x86_64
chmod +x /usr/local/bin/vpncore
mkdir -p /etc/vpncore-multi

# Setup Multi-Config Tracker System
cat <<EOF > /etc/vpncore-multi/instances.json
{
    "2080": "US"
}
EOF

# Template generator helper function for dynamic instances
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

# Initial execution to create default instance
/etc/vpncore-multi/template.sh 2080 US

# 5. Create Telegram Bot Script with Multi-Location and Custom Ports Manage System
echo -e "${CYAN}[4/6] Creating Dynamic Telegram Bot Interface...${NC}"
cat <<EOF > /root/manager_bot.py
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
    "🇺🇸 US - آمریکا": "US", "🇩🇪 DE - آلمان": "DE", "🇬🇧 GB - انگلیس": "GB",
    "🇫🇷 FR - فرانسه": "FR", "🇨🇦 CA - کانادا": "CA", "🇳🇱 NL - هلند": "NL",
    "🇨🇭 CH - سوئیس": "CH", "🇸🇪 SE - سوئد": "SE", "🇫🇮 FI - فنلاند": "FI",
    "🇦🇹 AT - اتریش": "AT", "🇧🇪 BE - بلژیک": "BE", "🇩🇰 DK - دانمارک": "DK",
    "🇪🇸 ES - اسپانیا": "ES", "🇮🇹 IT - ایتالیا": "IT", "🇮🇪 IE - ایرلند": "IE",
    "🇳🇴 NO - نروژ": "NO", "🇵🇱 PL - لهستان": "PL", "🇹睿 TR - ترکیه": "TR",
    "🇧🇬 BG - بلغارستان": "BG", "🇨🇿 CZ - چک": "CZ", "🇪🇪 EE - استونی": "EE",
    "🇭🇷 HR - کرواسی": "HR", "🇭🇺 HU - مجارستان": "HU","🇮🇳 IN - هند": "IN",
    "🇯🇵 JP - ژاپن": "JP", "🇱🇻 LV - لتونی": "LV", "🇵🇹 PT - پرتغال": "PT",
    "🇷🇴 RO - رومانی": "RO", "🇷🇸 RS - صربستان": "RS", "🇸🇬 SG - سنگاپور": "SG",
    "🇸↖ SK - اسلواکی": "SK"
}

user_states = {}

def is_admin(user_id):
    return user_id == ADMIN_ID

def load_instances():
    if os.path.exists(INSTANCES_FILE):
        with open(INSTANCES_FILE, 'r') as f:
            return json.load(f)
    return {"2080": "US"}

def save_instances(data):
    with open(INSTANCES_FILE, 'w') as f:
        json.dump(data, f, indent=4)

def update_systemd_and_restart(port, region, action="start"):
    service_name = f"vpncore-{port}"
    service_file = f"/etc/systemd/system/{service_name}.service"
    
    if action == "stop":
        subprocess.run(f"systemctl stop {service_name}", shell=True)
        subprocess.run(f"systemctl disable {service_name}", shell=True)
        if os.path.exists(service_file):
            os.remove(service_file)
        subprocess.run("systemctl daemon-reload", shell=True)
        config_path = f"{DATA_DIR}/config-{port}.json"
        if os.path.exists(config_path):
            os.remove(config_path)
        return

    # Generate Config and Service
    subprocess.run(f"{DATA_DIR}/template.sh {port} {region}", shell=True)
    
    service_content = f"""[Unit]
Description=Core VPN Tunnel Service on Port {port}
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory={DATA_DIR}
ExecStart=/usr/local/bin/vpncore -config {DATA_DIR}/config-{port}.json
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
"""
    with open(service_file, 'w') as f:
        f.write(service_content)
        
    subprocess.run("systemctl daemon-reload", shell=True)
    subprocess.run(f"systemctl enable {service_name}", shell=True)
    subprocess.run(f"systemctl restart {service_name}", shell=True)

def get_current_ip(port):
    proxies = {'http': f'socks5h://127.0.0.1:{port}', 'https': f'socks5h://127.0.0.1:{port}'}
    try:
        r = requests.get('https://api.ipify.org', proxies=proxies, timeout=4)
        if r.status_code == 200: return r.text
    except: pass
    return None

def main_menu():
    markup = types.ReplyKeyboardMarkup(row_width=2, resize_keyboard=True)
    markup.add("📊 وضعیت پورت‌ها و سرویس‌ها", "🌍 مدیریت لوکیشن و پورت جدید", "❌ حذف یک لوکیشن/پورت")
    return markup

@bot.message_handler(commands=['start', 'help'])
def send_welcome(message):
    if is_admin(message.from_user.id):
        bot.reply_to(message, "👋 سلام!\n🔹 به پنل مدیریت چند پورت خوش آمدید.\n\n`Created by Mahdi`", reply_markup=main_menu(), parse_mode="Markdown")
    else:
        bot.reply_to(message, "⛔️ دسترسی غیرمجاز است.")

@bot.message_handler(commands=['info'])
def send_info(message):
    bot.reply_to(message, "ℹ️ VPN Manager Script\n`Created by Mahdi`", parse_mode="Markdown")

@bot.message_handler(func=lambda message: True)
def handle_messages(message):
    if not is_admin(message.from_user.id): return
    msg = message.text
    cid = message.chat.id
    
    if msg == "📊 وضعیت پورت‌ها و سرویس‌ها":
        bot.send_message(cid, "⏳ در حال بررسی تمام پورت‌های فعال...")
        instances = load_instances()
        response = "📋 **لیست لوکیشن‌ها و پورت‌های فعال:**\n\n"
        for port, region in instances.items():
            status = subprocess.run(f"systemctl is-active vpncore-{port}", shell=True, capture_output=True, text=True).stdout.strip()
            icon = "✅" if status == "active" else "🔴"
            ip = get_current_ip(port) or "❌ عدم دریافت آی‌پی"
            response += f"{icon} **پورت:** `{port}` | **منطقه:** `{region}`\n🌐 **آی‌پی:** {ip}\n───────────────────\n"
        response += "\n`Created by Mahdi`"
        bot.send_message(cid, response, parse_mode="Markdown")
        
    elif msg == "🌍 مدیریت لوکیشن و پورت جدید":
        markup = types.InlineKeyboardMarkup(row_width=3)
        buttons = []
        for name, code in ALL_REGIONS.items():
            buttons.append(types.InlineKeyboardButton(name, callback_data=f"addloc_{code}"))
        markup.add(*buttons)
        bot.send_message(cid, "🗺 لطفاً کشور مورد نظر را انتخاب کنید:", reply_markup=markup)
        
    elif msg == "❌ حذف یک لوکیشن/پورت":
        instances = load_instances()
        if len(instances) <= 1:
            bot.send_message(cid, "⚠️ حداقل یک لوکیشن فعال باید روی سرور باقی بماند و حذف کل پورت‌ها امکان‌پذیر نیست.")
            return
        markup = types.InlineKeyboardMarkup(row_width=2)
        for port, region in instances.items():
            markup.add(types.InlineKeyboardButton(f"🗑 پورت {port} ({region})", callback_data=f"delport_{port}"))
        bot.send_message(cid, "📍 پورتی که قصد حذف کامل آن را دارید انتخاب کنید:", reply_markup=markup)

@bot.callback_query_handler(func=lambda call: call.data.startswith('addloc_'))
def handle_add_location(call):
    if not is_admin(call.from_user.id): return
    region_code = call.data.split("_")[1]
    cid = call.message.chat.id
    
    user_states[cid] = {"action": "wait_port", "region": region_code}
    bot.edit_message_text(f"⚙️ لوکیشن انتخاب شده: **{region_code}**\n\n🔢 لطفاً پورت اختصاصی مورد نظر خود را ارسال کنید (مثلاً 2081 یا 8080):", cid, call.message.message_id, parse_mode="Markdown")

@bot.message_handler(func=lambda message: user_states.get(message.chat.id, {}).get("action") == "wait_port")
def process_port_input(message):
    if not is_admin(message.from_user.id): return
    cid = message.chat.id
    port_input = message.text.strip()
    
    if not port_input.isdigit() or not (1024 <= int(port_input) <= 65535):
        bot.send_message(cid, "❌ خطا: لطفاً یک عدد معتبر بین 1024 تا 65535 وارد کنید:")
        return
        
    instances = load_instances()
    region = user_states[cid]["region"]
    
    bot.send_message(cid, f"⏳ در حال راه‌اندازی لوکیشن {region} روی پورت {port_input}...")
    
    instances[port_input] = region
    save_instances(instances)
    update_systemd_and_restart(port_input, region, "start")
    
    time.sleep(3)
    ip_check = get_current_ip(port_input) or "⚠️ سرویس متصل شد اما آی‌پی شناسایی نشد"
    
    bot.send_message(cid, f"✅ **سرویس جدید با موفقیت اضافه و اجرا شد!**\n\n🌍 منطقه: `{region}`\n🔢 پورت اختصاصی: `{port_input}`\n🌐 آی‌پی تونل: `{ip_check}`\n\n`Created by Mahdi`", parse_mode="Markdown", reply_markup=main_menu())
    user_states.pop(cid, None)

@bot.callback_query_handler(func=lambda call: call.data.startswith('delport_'))
def handle_delete_port(call):
    if not is_admin(call.from_user.id): return
    port_to_del = call.data.split("_")[1]
    cid = call.message.chat.id
    
    instances = load_instances()
    if port_to_del in instances:
        bot.edit_message_text(f"⚙️ در حال حذف کامل سرویس روی پورت {port_to_del}...", cid, call.message.message_id)
        update_systemd_and_restart(port_to_del, None, "stop")
        instances.pop(port_to_del)
        save_instances(instances)
        bot.send_message(cid, f"🗑 پورت `{port_to_del}` و کلیه فایل‌های کانفیگ آن با موفقیت حذف شدند.", parse_mode="Markdown", reply_markup=main_menu())
    else:
        bot.send_message(cid, "❌ این پورت یافت نشد.")

bot.infinity_polling()
EOF

# Create Systemd Bot Manager Daemon
cat <<EOF > /etc/systemd/system/vpncore-bot.service
[Unit]
Description=Telegram Multi-Port Management Bot
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/root
ExecStart=/usr/bin/python3 /root/manager_bot.py
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# 6. Completely Launch Default Port Service and Bot Controller
echo -e "${CYAN}[5/6] Activating Multi-Tunnel Infrastructure...${NC}"
systemctl daemon-reload

# Trigger base deployment for port 2080
service_name="vpncore-2080"
cat <<EOF > /etc/systemd/system/$service_name.service
[Unit]
Description=Core VPN Tunnel Service on Port 2080
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
systemctl enable vpncore-2080
systemctl enable vpncore-bot
systemctl restart vpncore-2080
systemctl restart vpncore-bot

echo ""
echo -e "${GREEN}**************************************************${NC}"
echo -e "${GREEN}* INSTALLATION COMPLETE! 🎉                      *${NC}"
echo -e "${GREEN}* Created by Mahdi                               *${NC}"
echo -e "${GREEN}**************************************************${NC}"
echo -e "1. Initial Socks5 Port: 2080 [Region: US]"
echo -e "2. Multi-Location Telegram Dashboard: ACTIVE"
echo -e "3. Management: Open Telegram and send /start to add more locations on separate custom ports."
echo ""
