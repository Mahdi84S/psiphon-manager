#!/bin/bash

GREEN='\033;32m'
CYAN='\033;36m'
RED='\033;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

clear

echo -e "${CYAN}***************************************************${NC}"
echo -e "${CYAN}*                                                 *${NC}"
echo -e "${CYAN}* MAHDI - VPN MANAGER SETUP                       *${NC}"
echo -e "${CYAN}*                                                 *${NC}"
echo -e "${CYAN}***************************************************${NC}"
echo -e "${YELLOW}    >>> Starting Installation <<<    ${NC}"
echo ""

# ۱. چک کردن دسترسی روت
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}❌ لطفاً با دسترسی روت اجرا کنید (sudo su)${NC}"
    exit
fi

# ۲. دریافت توکن و آیدی
echo -e "${GREEN}[?] Please enter your Telegram Bot Token:${NC}"
read -p "Token: " BOT_TOKEN

echo -e "${GREEN}[?] Please enter your Admin Numeric ID:${NC}"
read -p "Admin ID: " ADMIN_ID

if [[ -z "$BOT_TOKEN" || -z "$ADMIN_ID" ]]; then
    echo -e "${RED}❌ Error: Token and Admin ID cannot be empty!${NC}"
    exit 1
fi

# ۳. نصب پیش‌نیازها
echo -e "${CYAN}[1/7] Updating System & Installing Dependencies...${NC}"
apt update -q -y
apt install -q -y wget curl nano python3 python3-pip unzip

# نصب کتابخانه‌های پایتون
echo -e "${CYAN}[2/7] Installing Python Libraries...${NC}"
rm /usr/lib/python3.*/EXTERNALLY-MANAGED 2>/dev/null
pip3 install pyTelegramBotAPI requests pysocks --break-system-packages 2>/dev/null || pip3 install pyTelegramBotAPI requests pysocks

# ۴. دانلود و نصب هسته سایفون
echo -e "${CYAN}[3/7] Installing Psiphon Core...${NC}"
wget -qO /usr/local/bin/psiphon https://github.com/Psiphon-Labs/psiphon-tunnel-core-binaries/raw/master/linux/psiphon-tunnel-core-x86_64
chmod +x /usr/local/bin/psiphon
mkdir -p /etc/psiphon-data

# ۵. ساخت فایل کانفیگ اولیه
echo -e "${CYAN}[4/7] Generating Config File...${NC}"
cat <<EOF > /etc/psiphon-config.json
{
    "LocalSocksProxyPort": 2080,
    "EgressRegion": "US",
    "PropagationChannelId": "FFFFFFFFFFFFFFFF",
    "SponsorId": "FFFFFFFFFFFFFFFF",
    "RemoteServerListUrl": "https://s3.amazonaws.com//psiphon/web/mjr4-p23r-puwl/server_list_compressed",
    "RemoteServerListSignaturePublicKey": "MIICIDANBgkqhkiG9w0BAQEFAAOCAg0AMIICCAKCAgEAt7Ls+/39r+T6zNW7GiVpJfzq/xvL9SBH5rIFnk0RXYEYavax3WS6HOD35eTAqn8AniOwiH+DOkvgSKF2caqk/y1dfq47Pdymtwzp9ikpB1C5OfAysXzBiwVJlCdajBKvBZDerV1cMvRzCKvKwRmvDmHgphQQ7WfXIGbRbmmk6opMBh3roE42KcotLFtqp0RRwLtcBRNtCdsrVsjiI1Lqz/lH+T61sGjSjQ3CHMuZYSQJZo/KrvzgQXpkaCTdbObxHqb6/+i1qaVOfEsvjoiyzTxJADvSytVtcTjijhPEV6XskJVHE1Zgl+7rATr/pDQkw6DPCNBS1+Y6fy7GstZALQXwEDN/qhQI9kWkHijT8ns+i1vGg00Mk/6J75arLhqcodWsdeG/M/moWgqQAnlZAGVtJI1OgeF5fsPpXu4kctOfuZlGjVZXQNW34aOzm8r8S0eVZitPlbhcPiR4gT/aSMz/wd8lZlzZYsje/Jr8u/YtlwjjreZrGRmG8KMOzukV3lLmMppXFMvl4bxv6YFEmIuTsOhbLTwFgh7KYNjodLj/LsqRVfwz31PgWQFTEPICV7GCvgVlPRxnofqKSjgTWI4mxDhBpVcATvaoBl1L/6WLbFvBsoAUBItWwctO2xalKxF5szhGm8lccoc5MZr8kfE0uxMgsxz4er68iCID+rsCAQM=",
    "RemoteServerListDownloadFilename": "remote_server_list",
    "FetchRemoteServerListRetryIntervalMilliseconds": 1000
}
EOF

# ساخت سرویس سیستمی سایفون
cat <<EOF > /etc/systemd/system/psiphon.service
[Unit]
Description=Psiphon Tunnel Service
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/etc/psiphon-data
ExecStart=/usr/local/bin/psiphon -config /etc/psiphon-config.json
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

# ۶. ساخت ربات تلگرام با قابلیت پورت پویا و اختصاصی
echo -e "${CYAN}[5/7] Creating Bot...${NC}"
cat <<EOF > /root/manager_bot.py
import telebot
import subprocess
import json
import time
import requests
from telebot import types

BOT_TOKEN = "${BOT_TOKEN}"
ADMIN_ID = ${ADMIN_ID}

CONFIG_FILE = "/etc/psiphon-config.json"
SERVICE_NAME = "psiphon"

bot = telebot.TeleBot(BOT_TOKEN)

ALL_REGIONS = {
    "🇺🇸 US - آمریکا": "US", "🇩🇪 DE - آلمان": "DE", "🇬🇧 GB - انگلیس": "GB",
    "🇫🇷 FR - فرانسه": "FR", "🇨🇦 CA - کانادا": "CA", "🇳🇱 NL - هلند": "NL",
    "🇨🇭 CH - سوئیس": "CH", "🇸🇪 SE - سوئد": "SE", "🇫🇮 FI - فنلاند": "FI",
    "🇦🇹 AT - اتریش": "AT", "🇧🇪 BE - بلژیک": "BE", "🇩👑 DK - دانمارک": "DK",
    "🇪🇸 ES - اسپانیا": "ES", "🇮🇹 IT - ایتالیا": "IT", "🇮🇪 IE - ایرلند": "IE",
    "🇳🇴 NO - نروژ": "NO", "🇵🇱 PL - لهستان": "PL", "🇹🇷 TR - ترکیه": "TR",
    "🇧🇬 BG - بلغارستان": "BG", "🇨🇿 CZ - چک": "CZ", "🇪🇪 EE - استونی": "EE",
    "🇭🇷 HR - کرواسی": "HR", "🇭🇺 HU - مجارستان": "HU","🇮🇳 IN - هند": "IN",
    "🇯🇵 JP - ژاپن": "JP", "🇱🇻 LV - لتونی": "LV", "🇵🇹 PT - پرتغال": "PT",
    "🇷🇴 RO - رومانی": "RO", "🇷🇸 RS - صربستان": "RS", "🇸🇬 SG - سنگاپور": "SG",
    "🇸🇰 SK - اسلواکی": "SK"
}

# دیکشنری موقت برای نگهداری مراحل تغییر لوکیشن کاربران
user_steps = {}

def is_admin(user_id):
    return user_id == ADMIN_ID

def run_command(command):
    try:
        result = subprocess.run(command, shell=True, capture_output=True, text=True)
        return result.stdout.strip()
    except Exception as e:
        return str(e)

def get_current_port():
    try:
        with open(CONFIG_FILE, 'r') as f: data = json.load(f)
        return data.get("LocalSocksProxyPort", 2080)
    except: return 2080

def get_current_ip():
    port = get_current_port()
    proxies = {'http': f'socks5h://127.0.0.1:{port}', 'https': f'socks5h://127.0.0.1:{port}'}
    try:
        r = requests.get('https://api.ipify.org', proxies=proxies, timeout=5)
        if r.status_code == 200: return r.text
    except: pass
    return None

def get_current_region():
    try:
        with open(CONFIG_FILE, 'r') as f: data = json.load(f)
        return data.get("EgressRegion", "نامشخص")
    except: return "Error"

def update_config(new_region, new_port):
    try:
        with open(CONFIG_FILE, 'r') as f: data = json.load(f)
        data['EgressRegion'] = new_region
        data['LocalSocksProxyPort'] = int(new_port)
        with open(CONFIG_FILE, 'w') as f: json.dump(data, f, indent=4)
        return True
    except: return False

def main_menu():
    markup = types.ReplyKeyboardMarkup(row_width=2, resize_keyboard=True)
    markup.add("📊 وضعیت سرویس", "🌍 تغییر لوکیشن", "▶️ استارت", "⏹ استاپ", "🔄 ریستارت")
    return markup

@bot.message_handler(commands=['start', 'help'])
def send_welcome(message):
    if is_admin(message.from_user.id):
        bot.reply_to(message, "👋 سلام قربان!\n🌹 به پنل مدیریت اختصاصی **Mahdi** خوش آمدید.", reply_markup=main_menu(), parse_mode="Markdown")
    else:
        bot.reply_to(message, "⛔️ دسترسی غیرمجاز است.")

@bot.message_handler(func=lambda message: True)
def handle_messages(message):
    if not is_admin(message.from_user.id): return
    msg = message.text
    cid = message.chat.id
    
    if msg == "📊 وضعیت سرویس":
        bot.send_message(cid, "⏳ در حال بررسی...")
        status = run_command(f"systemctl is-active {SERVICE_NAME}")
        region = get_current_region()
        port = get_current_port()
        ip = get_current_ip() or "❌ در حال اتصال..."
        icon = "✅" if status == "active" else "🔴"
        bot.send_message(cid, f"{icon} **وضعیت:** {status}\n🌍 **کشور:** {region}\n🔌 **پورت:** `{port}`\n🌐 **آی‌پی:** {ip}", parse_mode="Markdown")
    elif msg == "▶️ استارت":
        run_command(f"systemctl start {SERVICE_NAME}")
        bot.send_message(cid, "🚀 استارت شد.")
    elif msg == "⏹ استاپ":
        run_command(f"systemctl stop {SERVICE_NAME}")
        bot.send_message(cid, "🛑 متوقف شد.")
    elif msg == "🔄 ریستارت":
        bot.send_message(cid, "♻️ ریستارت سرویس...")
        run_command(f"systemctl restart {SERVICE_NAME}")
        time.sleep(2)
        bot.send_message(cid, "✅ دستور اجرا شد.")
    elif msg == "🌍 تغییر لوکیشن":
        markup = types.InlineKeyboardMarkup(row_width=3)
        buttons = []
        for name, code in ALL_REGIONS.items():
            buttons.append(types.InlineKeyboardButton(name, callback_data=f"setloc_{code}"))
        markup.add(*buttons)
        bot.send_message(cid, "🗺 کشور جدید را انتخاب کنید:", reply_markup=markup)

@bot.callback_query_handler(func=lambda call: call.data.startswith('setloc_'))
def callback_query(call):
    if not is_admin(call.from_user.id): return
    region_code = call.data.split("_")[1]
    cid = call.message.chat.id
    
    bot.answer_callback_query(call.id)
    user_steps[cid] = {'region': region_code}
    
    # پرسش پورت اختصاصی از کاربر
    msg = bot.send_message(cid, f"تنظیم لوکیشن روی **{region_code}** انتخاب شد.\n🔢 لطفاً پورت مد نظر خود را برای این لوکیشن ارسال کنید (مثلاً: 2080):", parse_mode="Markdown")
    bot.register_next_step_handler(msg, process_port_input)

def process_port_input(message):
    cid = message.chat.id
    if cid not in user_steps: return
    
    port_text = message.text.strip()
    if not port_text.isdigit():
        msg = bot.send_message(cid, "❌ خطا: پورت باید عدد باشد. لطفاً مجدداً پورت را وارد کنید:")
        bot.register_next_step_handler(msg, process_port_input)
        return

    region_code = user_steps[cid]['region']
    full_name = region_code
    for name, code in ALL_REGIONS.items():
        if code == region_code: full_name = name; break

    bot.send_message(cid, f"⚙️ تنظیم روی **{full_name}** و پورت **{port_text}**...\n⏳ لطفاً صبر کنید...", parse_mode="Markdown")
    
    if update_config(region_code, port_text):
        run_command(f"systemctl restart {SERVICE_NAME}")
        found_ip = None
        for i in range(10): 
            time.sleep(2)
            check_ip = get_current_ip()
            if check_ip: found_ip = check_ip; break
        if found_ip: 
            bot.send_message(cid, f"✅ **وصل شد!**\n\n🌍 منطقه: {full_name}\n🔌 پورت خروجی: `{port_text}`\n🌐 آی‌پی: {found_ip}", parse_mode="Markdown")
        else: 
            bot.send_message(cid, f"⚠️ سرویس ریستارت شد اما پورت `{port_text}` هنوز آی‌پی نگرفته است.", parse_mode="Markdown")
    else: 
        bot.send_message(cid, "❌ خطا در ویرایش فایل کانفیگ.")
        
    del user_steps[cid]

bot.infinity_polling()
EOF

# ساخت سرویس سیستمی ربات مدیریت
cat <<EOF > /etc/systemd/system/psiphon-bot.service
[Unit]
Description=Telegram Bot for Mahdi Manager
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

# ٧. نصب و ارتقای دستور changeloc در ترمینال با پورت پویا و لیست جامع
echo -e "${CYAN}[6/7] Installing 'changeloc' Command...${NC}"
cat <<EOF > /usr/local/bin/changeloc
#!/bin/bash
CONFIG_FILE="/etc/psiphon-config.json"
SERVICE_NAME="psiphon"
GREEN='\033[0;32m'; CYAN='\033[0;36m'; RED='\033[0;31m'; YELLOW='\033[1;33m'; NC='\033[0m'
clear

echo -e "\${CYAN}=============================================\${NC}"
echo -e "\${CYAN}          MAHDI REGION CHANGER (CLI)         \${NC}"
echo -e "\${CYAN}=============================================\${NC}"
echo ""

if [ -f "\$CONFIG_FILE" ]; then 
    CURRENT_REG=\$(grep "EgressRegion" \$CONFIG_FILE | cut -d '"' -f 4)
    CURRENT_PORT=\$(grep "LocalSocksProxyPort" \$CONFIG_FILE | tr -dc '0-9')
else 
    CURRENT_REG="Unknown"
    CURRENT_PORT="Unknown"
fi

echo -e "Current Region: \${YELLOW}\$CURRENT_REG\${NC}"
echo -e "Current Port:   \${YELLOW}\$CURRENT_PORT\${NC}\n"

echo -e "\${GREEN}All Supported Countries:\${NC}"
echo -e "US, DE, GB, FR, CA, NL, CH, SE, FI, AT, BE, DK, ES, IT, IE"
echo -e "NO, PL, TR, BG, CZ, EE, HR, HU, IN, JP, LV, PT, RO, RS, SG, SK\n"

read -p "Enter Country Code (Default: US): " REGION
REGION=\${REGION:-US}; REGION=\${REGION^^}

read -p "Enter Target Port (Default: 2080): " PORT_INPUT
PORT_INPUT=\${PORT_INPUT:-2080}

echo -e "\n\${CYAN}Setting region to \$REGION on port \$PORT_INPUT ...\${NC}"

# اعمال تغییرات ساختاری در فایل جیسون کانفیگ
if [ -f "\$CONFIG_FILE" ]; then
    sed -i "s/\"EgressRegion\": \"[A-Z]*\"/\"EgressRegion\": \"\$REGION\"/g" \$CONFIG_FILE
    sed -i "s/\"LocalSocksProxyPort\": [0-9]*/\"LocalSocksProxyPort\": \$PORT_INPUT/g" \$CONFIG_FILE
fi

systemctl restart \$SERVICE_NAME
echo -e "\${YELLOW}Waiting for connection...\${NC}"
FOUND_IP=""; MAX_RETRIES=15; COUNT=0
while [ \$COUNT -lt \$MAX_RETRIES ]; do
    CHECK_IP=\$(curl -s --socks5 127.0.0.1:\$PORT_INPUT https://api.ipify.org --max-time 2)
    if [ ! -z "\$CHECK_IP" ]; then FOUND_IP=\$CHECK_IP; break; fi
    echo -ne "."; sleep 2; COUNT=\$((COUNT+1))
done
echo ""
if [ ! -z "\$FOUND_IP" ]; then 
    echo -e "\${GREEN}✔ CONNECTED! Region: \$REGION\${NC}"
    echo -e "\${GREEN}✔ Port: \$PORT_INPUT\${NC}"
    echo -e "\${GREEN}✔ IP: \$FOUND_IP\${NC}\n"
else 
    echo -e "\${RED}✘ Connection timed out or wrong configuration.\${NC}\n"
fi
EOF
chmod +x /usr/local/bin/changeloc

# ٨. راه‌اندازی نهایی سرویس‌ها
echo -e "${CYAN}[7/7] Starting Services...${NC}"
systemctl daemon-reload
systemctl enable psiphon
systemctl enable psiphon-bot
systemctl restart psiphon
systemctl restart psiphon-bot

echo ""
echo -e "${GREEN}**************************************************${NC}"
echo -e "${GREEN}* INSTALLATION COMPLETE! 🎉                      *${NC}"
echo -e "${GREEN}* Designed for: MAHDI                            *${NC}"
echo -e "${GREEN}**************************************************${NC}"
echo -e "1. Default Psiphon Port: 2080 (Dynamic)"
echo -e "2. Bot Status: STARTED"
echo -e "3. CLI Command: type 'changeloc' in terminal"
echo ""
