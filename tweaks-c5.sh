#!/bin/sh
STARUPFIX="/usr/prog/app_startup.sh"
VERSION="2.0.3"
set -e
set -u

trap 'chmod 755 "$STARUPFIX" 2>/dev/null || true' EXIT INT TERM

show_menu() {
    clear
    echo "==============================================="
    echo "                Tweaks for FF C5"
    echo "              discord.gg/7nJUB9dq4F"
    echo "                  Version $VERSION"
    echo "           If it shows any errors, CTRL+C!"
    echo "      Currently use the wiki pages instead!"
    echo "https://github.com/FlashForge-C5-Modding-Group/Creator-5-Mods"
    echo "==============================================="
    #echo "1) Enable loop script & Mainsail [EXPERIMENTAL]"
    #echo "2) Enable Legacy NAN [EXPERIMENTAL]"
    #echo "3) Add Entware [EXPERIMENTAL]"
    #echo "4) Update Mainsail [EXPERIMENTAL]"
    #echo "5) Update Moonraker (INDEV)"
    #echo "6) Optimize Nginx [EXPERIMENTAL]"
    echo "7) Exit"
    echo ""
    echo "98) Credits"
    echo "99) Release Notes"
    echo "================================================ "
}

enable_loop() {
    clear
    echo "[*] Enabling loop script"
    MATCH_LINE="/usr/prog/PROGRAM/software/firmwareExe &"
    NEW_LINE="/usr/prog/scripts/loop/loop.sh &"

    # Ensure the target file exists
    if [ ! -f "$STARUPFIX" ]; then
        echo "Error: $STARUPFIX does not exist." >&2
        printf "You are in serious trouble! Do not restart your printer! Please add back the file via the firmware repo as your printer WILL soft-brick without it. Press anything to return to menu, but HEED THIS WARNING!"
        stty -echo
        read -r _
        stty echo
        return 0
    fi

    # Check if the line is already present to avoid duplicate insertions
    if ! grep -Fq "$NEW_LINE" "$STARUPFIX"; then
        # Verify the target line exists before modifying
        if grep -Fq "$MATCH_LINE" "$STARUPFIX"; then
            TMP_FILE="${STARUPFIX}.tmp"

            # Insert NEW_LINE directly above MATCH_LINE
            awk -v ins="$NEW_LINE" -v match="$MATCH_LINE" \
                'index($0, match) && !done { print ins; done=1 } { print }' \
                "$STARUPFIX" > "$TMP_FILE"

            # Preserve exact permissions from the original file before moving
            chmod --reference="$STARUPFIX" "$TMP_FILE" 2>/dev/null || chmod 755 "$TMP_FILE"
            mv "$TMP_FILE" "$STARUPFIX"
            chmod 755 "$STARUPFIX"

            echo "[*] Inserted loop script above target command."
        else
            echo "[!] Warning: Match line not found in $STARUPFIX." >&2
        fi
    else
        echo "Line already exists in $STARUPFIX, skipping."
    fi

    mkdir -p "/usr/prog/scripts/loop/"
    mkdir -p "/usr/prog/scripts/scripts/"
    echo "[+] Created folders required"
    cp -f scripts/loop/loop.sh /usr/prog/scripts/loop/loop.sh
    echo "[+] Copied loop script."
    cp -f scripts/scripts/enable-msmr.sh /usr/prog/scripts/scripts/enable-msmr.sh
    echo "[*] Setting permissions..."
    chmod 755 /usr/prog/scripts/loop/loop.sh
    chmod 755 /usr/prog/scripts/scripts/enable-msmr.sh
    chmod 755 "$STARUPFIX"
    echo "[*] All done!"
    printf "Press Enter to return to the main menu..."
    stty -echo
    read -r _
    stty echo
    return 0
}

release_notes() {
    clear
    release_noting
    printf "Press Enter to return to the main menu..."
    stty -echo
    read -r _
    stty echo
    return 0
}

release_noting(){
    echo "==================================================="
    echo "                    Release Notes"
    echo "                   Version $VERSION"
    echo ""
    echo "         Hopefully fixes the script, new warning"
    echo "=================================================="
}

get_highest_kernel() {
    ls /usr/prog/PROGRAM/kernel/ 2>/dev/null | sort -n -t. -k1,1 -k2,2 -k3,3 | tail -n 1
}

enable_nan_mips() {
    clear
    echo "[*] Checking kernel package version..."

    if [ ! -d "/usr/prog/PROGRAM/kernel/" ]; then
        echo "[-] Error: /usr/prog/PROGRAM/kernel/ directory not found!"
        printf "Press Enter to return..."
        read -r _
        return 1
    fi

    HIGHEST_VER=$(get_highest_kernel)

    if [ -z "$HIGHEST_VER" ]; then
        echo "[-] Error: Could not determine kernel package version."
        printf "Press Enter to return..."
        read -r _
        return 1
    fi

    echo "[+] Detected highest kernel version: $HIGHEST_VER"

    OFFSET=""
    case "$HIGHEST_VER" in
        2.0.1* | 2.0.5*)
            OFFSET="0x00a130d1"
            ;;
        *)
            echo "[-] Error: No matching offset defined for kernel version '$HIGHEST_VER'."
            echo "    Please verify your kernel package version manually."
            echo "[-] Please manually update the script and commit back."
            printf "Press Enter to return..."
            read -r _
            return 1
            ;;
    esac

    echo "[+] Mapped Offset: $OFFSET"
    echo "[*] Verifying current memory state..."

    CURRENT_VAL=$(busybox devmem "$OFFSET" 8 2>/dev/null)
    echo "[+] Current memory value at $OFFSET: $CURRENT_VAL"

    if [ "$CURRENT_VAL" != "0x00" ]; then
        echo "[!] Warning: Expected 0x00, but read '$CURRENT_VAL'."
        printf "Do you still want to proceed enabling NaN MIPS support? (y/N): "
        read -r CONFIRM
        if [ "$CONFIRM" != "y" ] && [ "$CONFIRM" != "Y" ]; then
            echo "[*] Aborted."
            printf "Press Enter to return..."
            read -r _
            return 0
        fi
    fi

    echo "[*] Writing 1 to $OFFSET..."
    busybox devmem "$OFFSET" 8 1

    LOOP_FILE="/usr/prog/scripts/loop/loop.sh"
    if [ ! -f "$LOOP_FILE" ]; then
        echo "[-] Error: $LOOP_FILE does not exist!"
        printf "Press Enter to return..."
        read -r _
        return 1
    fi

    SRC_FILE="scripts/scripts/nan-binary.sh"
    DEST_DIR="/usr/prog/scripts/scripts"
    DEST_FILE="$DEST_DIR/nan-binary.sh"

    if [ ! -f "$SRC_FILE" ]; then
        echo "[-] Error: Source file $SRC_FILE not found!"
        printf "Press Enter to return..."
        read -r _
        return 1
    fi

    echo "[*] Deploying $SRC_FILE to $DEST_DIR..."
    mkdir -p "$DEST_DIR"
    cp "$SRC_FILE" "$DEST_FILE"
    chmod 755 "$DEST_FILE"
    echo "[+] File successfully copied to $DEST_FILE and made executable."

    echo "[+] Legacy NaN MIPS binaries enablement complete!"
    printf "Press Enter to return..."
    read -r _
}

install_entware() {
    clear
    echo "[*] Checking for NaN Binaries enablement..."

    if [ -z "${OFFSET:-}" ]; then
        if [ -d "/usr/prog/PROGRAM/kernel/" ]; then
            HIGHEST_VER=$(get_highest_kernel)
            case "$HIGHEST_VER" in
                2.0.1* | 2.0.5*) OFFSET="0x00a130d1" ;;
            esac
        fi
    fi

    if [ -z "${OFFSET:-}" ]; then
        echo "[-] Error: Could not determine kernel offset to verify NaN support."
        printf "Press Enter to return..."
        read -r _
        return 1
    fi

    CURRENT_VAL=$(busybox devmem "$OFFSET" 8 2>/dev/null)
    echo "[+] Current memory value at $OFFSET: $CURRENT_VAL"

    if [ "$CURRENT_VAL" != "0x01" ]; then
        echo ""
        echo "[!] Error: Expected memory value 0x01, but read '$CURRENT_VAL'."
        echo "    You MUST enable Legacy NaN MIPS binaries before installing Entware!"
        echo ""
        printf "Press Enter to return to main menu..."
        read -r _
        return 0
    fi

    echo "[*] Legacy NaN is enabled, can continue."
    echo ""
    echo "[*] Checking for previous installations..."
    echo ""

    if command -v opkg >/dev/null 2>&1 || [ -x "/opt/bin/opkg" ]; then
        echo "[!] Entware appears to be installed already! ('opkg' executable found)."
        echo "[!] We do not recommend running unless something is very broken."
        echo ""
        printf "Do you want to force reinstall Entware anyway? Not recommended. (y/N): "
        read -r REINSTALL
        if [ "$REINSTALL" != "y" ] && [ "$REINSTALL" != "Y" ]; then
            echo "[*] Entware installation cancelled."
            printf "Press Enter to return..."
            read -r _
            return 0
        fi
    fi

    echo "[*] Proceeding with Entware installation..."

    mkdir -p /usr/data/bin/opt
    mount --bind /usr/data/bin/opt /opt

    echo "[*] Downloading and executing Entware setup script..."
    wget -O - http://bin.entware.net/mipselsf-k3.4/installer/generic.sh | sh

    PROFILE_FILE="/etc/profile"
    EXPORT_LINE='export PATH=/opt/bin:/opt/sbin:$PATH'
    if [ -f "$PROFILE_FILE" ]; then
        if ! grep -q "/opt/bin" "$PROFILE_FILE"; then
            echo "$EXPORT_LINE" >> "$PROFILE_FILE"
            echo "[+] Added /opt paths to $PROFILE_FILE."
        else
            echo "[+] $PROFILE_FILE already contains /opt PATH export."
        fi
    fi

    export PATH=/opt/bin:/opt/sbin:$PATH

    LOOP_FILE="/usr/prog/scripts/loop/loop.sh"
    if [ ! -f "$LOOP_FILE" ]; then
        echo "[-] Error: $LOOP_FILE does not exist!"
        printf "Press Enter to return..."
        read -r _
        return 1
    fi

    SRC_FILE="scripts/scripts/entware.sh"
    DEST_DIR="/usr/prog/scripts/scripts"

    if [ -f "$SRC_FILE" ]; then
        DEST_FILE="$DEST_DIR/entware.sh"
    elif [ -f "../../scripts/scripts/entware" ]; then
        SRC_FILE="../../scripts/scripts/entware"
        DEST_FILE="$DEST_DIR/entware"
    else
        echo "[-] Error: Source entware script not found in ../../scripts/scripts/!"
        printf "Press Enter to return..."
        read -r _
        return 1
    fi

    echo "[*] Deploying $SRC_FILE to $DEST_DIR..."
    mkdir -p "$DEST_DIR"
    cp "$SRC_FILE" "$DEST_FILE"
    chmod 755 "$DEST_FILE"
    echo "[+] File successfully copied to $DEST_FILE and made executable."

    echo "[+] Running opkg update"
    opkg update

    echo "[+] Adding additional packages (Nano, Git)"
    opkg install nano git

    echo "[+] Entware installation finished!"
    printf "Press Enter to return..."
    read -r _
}

add_entware_packages() {
    clear
    echo "[*] Checking if Entware is installed..."
    if command -v opkg >/dev/null 2>&1 || [ -x "/opt/bin/opkg" ]; then
        echo "[+] Entware is detected, can continue."
        echo "[*] Getting required Entware packages, may take a moment."
        opkg update
        opkg install curl git
        echo "[+] Done installing packages."
        echo "[*] Checking for previous backups..."

        if [ -e "/usr/data/mainsailbackup" ]; then
            echo "[!] Warning: /usr/data/mainsailbackup already exists. It is recommended to move it manually if you have already updated once."
            printf "[?] Would you like to overwrite it? (y/N): "
            read -r reply
            case "$reply" in
                [Yy]*)
                    echo "[*] Removing existing mainsailbackup..."
                    rm -rf "/usr/data/mainsailbackup"
                    echo "[+] Removed. Ready to continue with mainsail update."
                    ;;
                *)
                    echo "[!] Overwrite declined. Aborting operation."
                    printf "Press Enter to return..."
                    read -r _
                    return 1
                    ;;
            esac
        fi

        echo "[+] Continuing update."
        echo "[+] Moving old Mainsail"
        mv /usr/data/mainsail /usr/data/mainsailbackup
        mkdir -p /usr/data/mainsail && cd /usr/data/mainsail
        echo "[+] Downloading new Mainsail..."
        curl -L -o /usr/data/mainsail.zip https://github.com/mainsail-crew/mainsail/releases/download/v2.18.2/mainsail.zip
        echo "[+] Unzipping Mainsail..."
        unzip /usr/data/mainsail.zip -d /usr/data/mainsail
        echo "[+] Deleting Mainsail ZIP"
        rm -rf /usr/data/mainsail.zip
        echo "[*] All finished! Ready to reboot!"
        printf "Press Enter to reboot..."
        read -r _
        echo "[*] Printer will reboot now! Goodbye."
        reboot
    else
        echo "[!] Entware doesn't seem to be installed. Please add Entware!"
        echo "[!] Entware package failure!"
    fi
    printf "Press Enter to return..."
    read -r _
}

update_moonraker() {
    echo "Updating Moonraker isn't supported yet..."
    echo "Check back for updates!"
    printf "Press Enter to return..."
    read -r _
}

set_nginx_two_instances() {
    clear
    nginx_conf=""
    nginx_bin=""

    echo "[*] Checking for Nginx configuration file..."
    for path in /usr/prog/nginx/conf/nginx.conf /usr/data/nginx/conf/nginx.conf; do
        if [ -f "$path" ]; then
            nginx_conf="$path"
            break
        fi
    done

    if [ -z "$nginx_conf" ]; then
        echo "[-] Error: Could not locate nginx.conf in known directories."
        printf "Press Enter to return..."
        read -r _
        return 1
    fi
    echo "[+] Found Nginx config at: $nginx_conf"

    SYS_NGINX=$(command -v nginx 2>/dev/null || true)
    for bin in /usr/prog/nginx/sbin/nginx /usr/data/nginx/sbin/nginx "$SYS_NGINX"; do
        if [ -n "$bin" ] && [ -x "$bin" ]; then
            nginx_bin="$bin"
            break
        fi
    done

    if grep -q 'worker_processes[ 	]*1;' "$nginx_conf"; then
        echo "[!] Nginx is ALREADY configured for 1 worker process."
        echo "[!] No changes needed."
        printf "Press Enter to return..."
        read -r _
        return 0
    fi

    cp "$nginx_conf" "${nginx_conf}.bak"
    echo "[*] Backup created at ${nginx_conf}.bak"

    if grep -q 'worker_processes' "$nginx_conf"; then
        echo "[*] Modifying existing worker_processes directive..."
        sed 's/^[ 	]*worker_processes[ 	][ 	]*[^;]*;/worker_processes 1;/' "$nginx_conf" > "${nginx_conf}.tmp"
    else
        echo "[*] worker_processes directive not found. Adding to top of file..."
        (echo "worker_processes 1;" && cat "$nginx_conf") > "${nginx_conf}.tmp"
    fi

    # Ensure permissions match original before replacing
    chmod --reference="$nginx_conf" "${nginx_conf}.tmp" 2>/dev/null || chmod 644 "${nginx_conf}.tmp"
    mv "${nginx_conf}.tmp" "$nginx_conf"

    if [ -n "$nginx_bin" ]; then
        echo "[*] Validating Nginx configuration syntax..."
        if ! "$nginx_bin" -t -c "$nginx_conf" >/dev/null 2>&1; then
            echo "[-] Error: Nginx configuration test failed! Restoring original file..."
            cp "${nginx_conf}.bak" "$nginx_conf"
            printf "Press Enter to return..."
            read -r _
            return 1
        fi
    fi

    echo "[+] Successfully updated $nginx_conf!"
    echo "[*] Reloading Nginx configuration..."

    if [ -n "$nginx_bin" ] && "$nginx_bin" -s reload -c "$nginx_conf" 2>/dev/null; then
        echo "[+] Reloaded Nginx via binary command."
    elif killall -HUP nginx 2>/dev/null || pkill -HUP -f nginx 2>/dev/null; then
        echo "[+] Sent reload signal (SIGHUP) to Nginx processes."
    else
        echo "[!] Warning: Could not reload Nginx automatically. Please reload manually."
    fi

    printf "Press Enter to return..."
    read -r _
}

credits() {
    echo "================================================================"
    echo "                         Credits for"
    echo "                        Version $VERSION"
    echo ""
    echo "Some scripts are made by Cart. Some AI assist, not written by AI."
    echo "Some scripts are now made by outside contributors, check repo!"
    echo " github/FlashForge-C5-Modding-Group/Creator-5-Written-Scripts "
    echo "================================================================"
    printf "Press Enter to return..."
    read -r _
}

# --- Main Menu Loop ---
while true; do
    chmod 755 "$STARUPFIX"
    show_menu
    printf "Enter your choice: "
    read -r CHOICE

    case "$CHOICE" in
        1)
            enable_loop
            ;;
        2)
            enable_nan_mips
            ;;
        3)
            install_entware
            ;;
        4)
            add_entware_packages
            ;;
        5)
            update_moonraker
            ;;
        6)
            set_nginx_two_instances
            ;;
        7)
            echo "Exiting..."
            exit 0
            ;;
        98)
            credits
            ;;
        99)
            release_notes
            ;;
        *)
            echo "Invalid option. Please try again."
            sleep 1
            ;;
    esac
done
