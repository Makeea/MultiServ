#!/bin/bash

# MultiServ Setup Script
# This script automates the installation and configuration of the MultiServ restreaming server.

# --- Configuration ---
PROJECT_DIR="/home/claire/projects/MultiServ"
ENV_FILE="$PROJECT_DIR/.env"
NGINX_CONF="/etc/nginx/nginx.conf"
RTMP_STATS_CONF="/etc/nginx/sites-available/rtmp"
STATS_SYMLINK="/etc/nginx/sites-enabled/rtmp"
STATS_XSL_DIR="/var/www/html/rtmp"
STATS_XSL_FILE="$STATS_XSL_DIR/stat.xsl"

# --- Colors ---
C_RESET='\033[0m'
C_RED='\033[0;31m'
C_GREEN='\033[0;32m'
C_YELLOW='\033[0;33m'
C_BLUE='\033[0;34m'
C_BOLD='\033[1m'

# --- Platform Definitions ---
# Format: "Name;Type;URL;Variable_Name"
declare -A PLATFORMS
PLATFORMS[1]="Twitch;RTMP;rtmp://jfk.contribute.live-video.net/app/;TWITCH_STREAM_KEY"
PLATFORMS[2]="YouTube;RTMP;rtmp://a.rtmp.youtube.com/live2/;YOUTUBE_STREAM_KEY"
PLATFORMS[3]="Kick;RTMPS;rtmps://global-contribute.live-video.net/app/;KICK_STREAM_KEY"
PLATFORMS[4]="Facebook Live;RTMPS;rtmps://live-api-s.facebook.com:443/rtmp/;FB_STREAM_KEY"
PLATFORMS[5]="Telegram;RTMPS;rtmps://dc.rtmp.t.me/s/;TELEGRAM_STREAM_KEY"
PLATFORMS[6]="Trovo;RTMP;rtmp://livepush.trovo.live/live/;TROVO_STREAM_KEY"
PLATFORMS[7]="Rumble;RTMP;rtmp://live.rumble.com/broadcast/;RUMBLE_STREAM_KEY"

# --- Helper Functions ---
function print_header() {
    echo -e "${C_BLUE}${C_BOLD}$1${C_RESET}"
}

function print_success() {
    echo -e "${C_GREEN}$1${C_RESET}"
}

function print_warning() {
    echo -e "${C_YELLOW}$1${C_RESET}"
}

function print_error() {
    echo -e "${C_RED}$1${C_RESET}"
}

# --- Main Script ---

# 1. Check for Root
if [[ $EUID -ne 0 ]]; then
   print_error "This script must be run as root. Please use 'sudo'." 
   exit 1
fi

# --- State Variables ---
declare -A selected_keys
declare -A custom_platforms
publish_rules=""
setup_stats=false
configure_firewall=false

# 2. Interactive Configuration
print_header "Welcome to the MultiServ Setup Script"
echo "This script will guide you through setting up your restreaming server."
echo

# --- Platform Selection ---
print_header "Step 1: Select Streaming Platforms"
echo "Default selection is Twitch and YouTube."
echo

for i in "${!PLATFORMS[@]}"; do
    IFS=';' read -r name type url var <<< "${PLATFORMS[$i]}"
    echo "  [$i] $name ($type)"
done
echo "  [8] Custom Platform (Enter your own)"
echo "  [9] Skip/Finish Selection"
echo

read -p "Enter the numbers for the platforms you want, separated by commas (e.g., 1,2,3): " platform_choices

# Process choices
IFS=',' read -ra choices <<< "$platform_choices"
if [ -z "$platform_choices" ]; then
    choices=(1 2) # Default
    print_warning "No selection made. Defaulting to Twitch and YouTube."
fi

for choice in "${choices[@]}"; do
    choice=$(echo "$choice" | xargs) # Trim whitespace
    if [[ -v PLATFORMS[$choice] ]]; then
        IFS=';' read -r name type url var <<< "${PLATFORMS[$choice]}"
        read -sp "Enter your stream key for ${name}: " key
        echo
        selected_keys["$var"]="$key;$type;$url"
    elif [[ "$choice" == "8" ]]; then
        read -p "Enter a name for the custom platform (e.g., MyServer): " custom_name
        read -p "Enter the full RTMP or RTMPS URL: " custom_url
        read -sp "Enter the stream key: " custom_key
        echo
        custom_platforms["$custom_name"]="$custom_url;$custom_key"
    fi
done

# --- Ingest Security ---
print_header "\nStep 2: Configure Ingest Security"
echo "Choose who can stream to this server."
echo "  [1] Localhost Only (Most Secure)"
echo "  [2] Specific IP or Domain (Recommended)"
echo "  [3] Allow Anyone (DANGEROUS)"
read -p "Enter your choice [1-3]: " security_choice

case $security_choice in
    1)
        publish_rules="allow publish 127.0.0.1;\n\t\tdeny publish all;"
        ;;
    2)
        read -p "Enter the public IP or domain you will stream from: " user_ip
        publish_rules="allow publish 127.0.0.1;\n\t\tallow publish $user_ip;\n\t\tdeny publish all;"
        ;;
    3)
        publish_rules="allow publish all;"
        print_warning "WARNING: Your server is now a public relay. This is not recommended."
        ;;
    *)
        publish_rules="allow publish 127.0.0.1;\n\t\tdeny publish all;"
        print_warning "Invalid choice. Defaulting to Localhost Only for security."
        ;;
esac

# --- Optional Features ---
print_header "\nStep 3: Optional Features"
read -p "Set up the web-based statistics page on port 8080? (y/n): " stats_choice
if [[ "$stats_choice" == "y" ]]; then
    setup_stats=true
fi

# --- Firewall ---
print_header "\nStep 4: Firewall Configuration"
read -p "Allow the script to configure UFW (firewall)? This will open ports 22, 80, 443, 1935, and 8080 (if stats enabled). (y/n): " firewall_choice
if [[ "$firewall_choice" == "y" ]]; then
    configure_firewall=true
fi

# --- Confirmation ---
print_header "\nStep 5: Confirmation"
echo "The script is ready to perform the following actions:"
echo "  - Install required system packages (nginx, ffmpeg, etc.)."
echo "  - Create a .env file at ${ENV_FILE} with your stream keys."
echo "  - Generate the Nginx configuration."
if $setup_stats; then echo "  - Set up the RTMP statistics page."; fi
if $configure_firewall; then echo "  - Apply firewall rules using UFW."; fi
echo "  - Reload the Nginx service."
echo

read -p "Proceed with these changes? (y/n): " final_confirm
if [[ "$final_confirm" != "y" ]]; then
    print_error "Aborted by user."
    exit 0
fi

# --- EXECUTION ---
print_header "\n--- Starting Setup ---"

# 1. Install Dependencies
print_success "Updating system and installing packages..."
apt-get update > /dev/null 2>&1
apt-get upgrade -y > /dev/null 2>&1
apt-get install -y build-essential libpcre3 libpcre3-dev libssl-dev zlib1g-dev git curl ffmpeg libnginx-mod-rtmp nginx > /dev/null 2>&1
print_success "Packages installed."

# 2. Create .env file
print_success "Creating .env file..."
echo "# This file stores your stream keys and is ignored by git." > "$ENV_FILE"
echo "# Do not share this file publicly." >> "$ENV_FILE"
for var_name in "${!selected_keys[@]}"; do
    IFS=';' read -r key type url <<< "${selected_keys[$var_name]}"
    echo "$var_name=\"$key\"" >> "$ENV_FILE"
done
for name in "${!custom_platforms[@]}"; do
    IFS=';' read -r url key <<< "${custom_platforms[$name]}"
    var_name="CUSTOM_${name^^}_URL"
    key_name="CUSTOM_${name^^}_KEY"
    echo "$var_name=\"$url\"" >> "$ENV_FILE"
    echo "$key_name=\"$key\"" >> "$ENV_FILE"
done
print_success ".env file created at $ENV_FILE"

# 3. Generate Nginx Config
print_success "Configuring Nginx..."
# Backup original config
if [ ! -f "${NGINX_CONF}.bak" ]; then
    cp "$NGINX_CONF" "${NGINX_CONF}.bak"
    print_success "Backed up original nginx.conf."
fi

# Add env variables to the top of nginx.conf
sed -i '/^events/i \\' "$NGINX_CONF" # Add a newline before events block
for var_name in "${!selected_keys[@]}"; do
    sed -i "/^events/i env $var_name;" "$NGINX_CONF"
done
for name in "${!custom_platforms[@]}"; do
    var_name="CUSTOM_${name^^}_URL"
    key_name="CUSTOM_${name^^}_KEY"
    sed -i "/^events/i env $var_name;" "$NGINX_CONF"
    sed -i "/^events/i env $key_name;" "$NGINX_CONF"
done

# Remove any existing rtmp block
sed -i '/^rtmp\s*{/,/^\s*}/d' "$NGINX_CONF"

# Create the new rtmp block
rtmp_block="\nrtmp {\n\tserver {\n\t\tlisten 1935;\n\t\tchunk_size 4096;\n\n\t\t# Ingest Security\n\t\t$publish_rules\n\n\t\tapplication live {\n\t\t\tlive on;\n\t\t\trecord off;\n"

# Add push directives
for var_name in "${!selected_keys[@]}"; do
    IFS=';' read -r key type url <<< "${selected_keys[$var_name]}"
    if [[ "$type" == "RTMP" ]]; then
        rtmp_block+="\n\t\t\t# Push to ${var_name%%_*}\n\t\t\tpush ${url}\$$var_name;"
    elif [[ "$type" == "RTMPS" ]]; then
        rtmp_block+="\n\t\t\t# Push to ${var_name%%_*}\n\t\t\texec_push /usr/bin/ffmpeg -re -i \"rtmp://127.0.0.1/live/\$name\" -c copy -f flv \"${url}\$$var_name\";"
    fi
done

# Add custom push directives
for name in "${!custom_platforms[@]}"; do
    url_var="CUSTOM_${name^^}_URL"
    key_var="CUSTOM_${name^^}_KEY"
    rtmp_block+="\n\t\t\t# Push to ${name}\n\t\t\texec_push /usr/bin/ffmpeg -re -i \"rtmp://127.0.0.1/live/\$name\" -c copy -f flv \"\$$url_var/\$$key_var\";"
done

rtmp_block+="\n\t\t}\n\t}\n}"

# Append the block to nginx.conf
echo -e "$rtmp_block" >> "$NGINX_CONF"
print_success "Nginx RTMP configuration generated."

# 4. Setup Stats Page
if $setup_stats; then
    print_success "Setting up RTMP stats page..."
    stats_config="server {\n\tlisten 8080;\n\tserver_name _;\n\n\tlocation /stat {\n\t\trtmp_stat all;\n\t\trtmp_stat_stylesheet stat.xsl;\n\t}\n\tlocation /stat.xsl {\n\t\troot ${STATS_XSL_DIR};\n\t}\n\tlocation /control {\n\t\trtmp_control all;\n\t}\n}"
    echo -e "$stats_config" > "$RTMP_STATS_CONF"
    
    if [ ! -L "$STATS_SYMLINK" ]; then
        ln -s "$RTMP_STATS_CONF" "$STATS_SYMLINK"
    fi

    mkdir -p "$STATS_XSL_DIR"
    curl -s -o "$STATS_XSL_FILE" https://raw.githubusercontent.com/arut/nginx-rtmp-module/master/stat.xsl
    print_success "Stats page configured."
fi

# 5. Configure Firewall
if $configure_firewall; then
    print_success "Configuring firewall (UFW)..."
    ufw allow 22/tcp > /dev/null
    ufw allow 80/tcp > /dev/null
    ufw allow 443/tcp > /dev/null
    ufw allow 1935/tcp > /dev/null
    if $setup_stats; then ufw allow 8080/tcp > /dev/null; fi
    yes | ufw enable > /dev/null
    print_success "Firewall rules applied."
fi

# 6. Validate and Reload
print_success "Validating Nginx configuration..."
nginx_test=$(nginx -t 2>&1)
if [[ "$nginx_test" =~ "successful" ]]; then
    print_success "Configuration is valid. Reloading Nginx..."
    systemctl reload nginx
    print_success "Nginx reloaded successfully."
else
    print_error "Nginx configuration test failed:"
    echo "$nginx_test"
    print_error "Restoring backup configuration. Please review the errors."
    cp "${NGINX_CONF}.bak" "$NGINX_CONF"
    exit 1
fi

print_header "\n--- Setup Complete! ---"
echo "Your restreaming server is now configured."
echo "You can stream to: ${C_BOLD}rtmp://<your_server_ip>/live${C_RESET}"
echo "Use any stream key you like for the ingest."
if $setup_stats; then
    echo "View stats at: ${C_BOLD}http://<your_server_ip>:8080/stat${C_RESET}"
fi
echo "To add or remove platforms, simply run this script again."
