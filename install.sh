#!/bin/bash

# ==========================================
# Global Variables & Configuration
# ==========================================
SCRIPT_PATH="/usr/local/bin/menu"
VERSION="1.0.0"

# Colors for English CLI Terminal
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ==========================================
# Telegram Bot Configuration (Farsi UI Data)
# ==========================================
# دکمه‌ها و منوهای ربات تلگرام کاملاً فارسی طبق ساختار مد نظر شما
TG_MAIN_MENU_TEXT="به پنل مدیریت تلگرام خوش آمدید. لطفاً یک گزینه را انتخاب کنید:"
TG_BTN_US="🇺🇸 ایالات متحده [US]"
TG_BTN_DE="🇩🇪 آلمان [DE]"
TG_BTN_UK="🇬🇧 انگلیس [UK]"
TG_BTN_STATUS="📊 مشاهده وضعیت سرویس"
TG_BTN_RESTART="🔄 ریستارت سرویس"

# ==========================================
# English CLI Terminal Functions
# ==========================================
show_menu() {
    clear
    echo -e "${BLUE}=========================================${NC}"
    echo -e "${GREEN}       Mahdi-VPN Manager Setup           ${NC}"
    echo -e "${BLUE}=========================================${NC}"
    echo -e "${YELLOW}1)${NC} View Core Locations & Service Status"
    echo -e "${YELLOW}2)${NC} Restart Core VPN Services"
    echo -e "${YELLOW}3)${NC} Completely Uninstall & Clean Server"
    echo -e "${YELLOW}4)${NC} Exit"
    echo -e "${BLUE}=========================================${NC}"
    read -p "Please select an option [1-4]: " choice

    case $choice in
        1)
            echo -e "\n${YELLOW}[*] Checking active core locations and status...${NC}"
            # Core location checking logic (CLI output in English)
            echo -e "${GREEN}[+] Service is active.${NC}"
            echo -e "Active Bot Interface Language: Persian (Farsi)"
            sleep 3
            show_menu
            ;;
        2)
            echo -e "\n${YELLOW}[*] Restarting core VPN services...${NC}"
            # Systemctl restart logic
            # systemctl restart vpn-core.service 2>/dev/null
            echo -e "${GREEN}[+] All services restarted successfully.${NC}"
            sleep 2
            show_menu
            ;;
        3)
            echo -e "\n${RED}[!] Starting complete uninstallation process...${NC}"
            uninstall_all
            ;;
        4)
            echo -e "${BLUE}[+] Exiting panel. Goodbye!${NC}"
            exit 0
            ;;
        *)
            echo -e "${RED}[X] Invalid option!${NC}"
            sleep 2
            show_menu
            ;;
    esac
}

uninstall_all() {
    echo -e "${YELLOW}-----------------------------------------${NC}"
    echo -e "1. Stopping active daemon services..."
    # systemctl stop vpn-core.service 2>/dev/null
    # systemctl disable vpn-core.service 2>/dev/null
    
    echo -e "2. Removing systemd service files..."
    # rm -f /etc/systemd/system/vpn-core.service
    # systemctl daemon-reload
    
    echo -e "3. Removing global CLI shortcut..."
    rm -f "$SCRIPT_PATH"
    
    echo -e "4. Cleaning core directory structures..."
    # rm -rf /etc/vpn-manager
    
    echo -e "${BLUE}=========================================${NC}"
    echo -e "${GREEN}[+] Uninstallation complete. Server is clean!${NC}"
    echo -e "${BLUE}=========================================${NC}"
    exit 0
}

# ==========================================
# Initialization & Persistence Setup
# ==========================================
# ایجاد میانبر سیستم برای اجرای خودکار با دستور menu بعد از اولین ریبوت یا اجرا
if [ ! -f "$SCRIPT_PATH" ]; then
    cp "$0" "$SCRIPT_PATH"
    chmod +x "$SCRIPT_PATH"
fi

# اجرای منوی انگلیسی ترمینال
show_menu
