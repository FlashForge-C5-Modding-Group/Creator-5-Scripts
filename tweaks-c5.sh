#!/bin/sh

VERSION="2.0.1"

show_menu() {
    clear
    echo "==============================================="
    echo "                Tweaks for FF C5"
    echo "              discord.gg/7nJUB9dq4F"
    echo "                 Version $VERSION"
    echo "==============================================="
    echo "1) Enable loop script & Mainsail"
    echo "2) Enable Legacy NAN [EXPERIMENTAL]"
    echo "3) Add Entware [EXPERIMENTAL]"
    echo "4) Update Mainsail"
    echo "5) Update Moonraker (INDEV)"
    echo "6) Optimize Nginx [EXPERIMENTAL]"
    echo "7) Exit"
    echo ""
    echo "98) Credits"
    echo "99) Release Notes"
    echo "================================================ "
}

enable_loop() {
    clear
    echo "[*] Enabling loop script"
    TARGET_FILE="/usr/prog/app_startup.sh"
    MATCH_LINE="/usr/prog/PROGRAM/software/firmwareExe &"
    NEW_LINE="/usr/prog/scripts/loop/loop.sh &"

    # Ensure the target file exists
    if [ ! -f "$TARGET_FILE" ]; then
        echo "Error: $TARGET_FILE does not exist." >&2
        printf "Press Enter to return to the main menu..."
        stty -echo
        read -r _
        stty echo
        return 0
    fi

    # Check if the line is already present to avoid duplicate insertions
    if ! grep -Fq "$NEW_LINE" "$TARGET_FILE"; then
        # Verify the target line exists before modifying
        if grep -Fq "$MATCH_LINE" "$TARGET_FILE"; then
            TMP_FILE="${TARGET_FILE}.tmp"

            # Insert NEW_LINE directly above MATCH_LINE
            awk -v ins="$NEW_LINE" -v match="$MATCH_LINE" \
                'index($0, match) && !done { print ins; done=1 } { print }' \
                "$TARGET_FILE" > "$TMP_FILE" && mv "$TMP_FILE" "$TARGET_FILE"

            echo "[*] Inserted loop script above target command."
        else
            echo "[!] Warning: Match line not found in $TARGET_FILE." >&2
        fi
    else
        echo "Line already exists in $TARGET_FILE, skipping."
    fi
    mkdir "/usr/prog/scripts/loop/"
    mkdir "/usr/prog/scripts/scripts/"
    echo "[+] Created folders required"
    cp -np scripts/loop/loop.sh /usr/prog/scripts/loop/loop.sh
    echo "[+] Copied loop script."
    cp -np scripts/scripts/enable-msmr.sh /usr/prog/scripts/scripts/enable-msmr.sh
    echo "[*] Setting permissions..."
    chmod +xwr /usr/prog/scripts/loop/loop.sh
    chmod +xwr /usr/prog/scripts/scripts/enable-msmr.sh
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
    echo "                   Release Notes"
    echo "                  Version $VERSION"
    echo ""
    echo "            Adds Optimization of NGINX"
    echo "             New script is by pappicio"
    echo "Updates the rest, any new scripts are EXPERIMENTAL"
    echo "=================================================="
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

    # Find highest version directory/file in kernel folder
    HIGHEST_VER=$(ls /usr/prog/PROGRAM/kernel/ | sort -V | tail -n 1)

    if [ -z "$HIGHEST_VER" ]; then
        echo "[-] Error: Could not determine kernel package version."
        printf "Press Enter to return..."
        read -r _
        return 1
    fi

    echo "[+] Detected highest kernel version: $HIGHEST_VER"

    # Map version to offset
    OFFSET=""
    case "$HIGHEST_VER" in
        "2.0.1"* | "2.0.5"*)
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

    # Read current state (read-only verification)
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

    # Apply live memory write
    echo "[*] Writing 1 to $OFFSET..."
    busybox devmem "$OFFSET" 8 1

    # Verify loop.sh exists before deploying script
    LOOP_FILE="/usr/prog/scripts/loop/loop.sh"
    if [ ! -f "$LOOP_FILE" ]; then
        echo "[-] Error: $LOOP_FILE does not exist!"
        printf "Press Enter to return..."
        read -r _
        return 1
    fi

    # Deploy script from 2 directories up
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
    chmod +w "$DEST_FILE"
    echo "[+] File successfully copied to $DEST_FILE and set to writable."

    echo "[+] Legacy NaN MIPS binaries enablement complete!"
    printf "Press Enter to return..."
    read -r _
}


install_entware() {
    clear
    echo "[*] Checking for NaN Binaries enablement..."

    # Ensure $OFFSET is set if it wasn't run previously in Option 1
    if [ -z "$OFFSET" ]; then
        if [ -d "/usr/prog/PROGRAM/kernel/" ]; then
            HIGHEST_VER=$(ls /usr/prog/PROGRAM/kernel/ | sort -V | tail -n 1)
            case "$HIGHEST_VER" in
                "2.0.1"* | "2.0.5"*) OFFSET="0x00a130d1" ;;
            esac
        fi
    fi

    # Fallback safety if offset still couldn't be determined
    if [ -z "$OFFSET" ]; then
        echo "[-] Error: Could not determine kernel offset to verify NaN support."
        printf "Press Enter to return..."
        read -r _
        return 1
    fi

    # Read current state
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

    # 1. Create directories and mount
    mkdir -p /usr/data/bin/opt
    mount --bind /usr/data/bin/opt /opt

    # 2. Download and run generic Entware installer
    echo "[*] Downloading and executing Entware setup script..."
    wget -O - http://bin.entware.net/mipselsf-k3.4/installer/generic.sh | sh

    # 3. Add to PATH persistently in /etc/profile
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

    # Export PATH for current session immediately
    export PATH=/opt/bin:/opt/sbin:$PATH

    # 4. Verify loop.sh exists before deploying script
    LOOP_FILE="/usr/prog/scripts/loop/loop.sh"
    if [ ! -f "$LOOP_FILE" ]; then
        echo "[-] Error: $LOOP_FILE does not exist!"
        printf "Press Enter to return..."
        read -r _
        return 1
    fi

    # Deploy entware script from 2 directories up
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
    chmod +w "$DEST_FILE"
    echo "[+] File successfully copied to $DEST_FILE and set to writable."

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
        mkdir /usr/data/mainsail && cd /usr/data/mainsail
        echo "[+] Downloading new Mainsail..."
        curl -LO --output-dir /usr/data/ https://github.com/mainsail-crew/mainsail/releases/download/v2.18.2/mainsail.zip
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

update_moonraker () {
    echo "Updating Moonraker isn't supported yet..."
    echo "Check back for updates!"
    printf "Press Enter to return..."
    read -r _
}

set_nginx_two_instances() {
    clear
    local nginx_conf="" nginx_bin=""
    
    local conf_paths=(
        "/usr/prog/nginx/conf/nginx.conf"
        "/usr/data/nginx/conf/nginx.conf"
    )
    
    local bin_paths=(
        "/usr/prog/nginx/sbin/nginx"
        "/usr/data/nginx/sbin/nginx"
        "$(command -v nginx 2>/dev/null)"
    )

    # 1. Determine Nginx config path
    echo "[*] Checking for Nginx configuration file..."
    for path in "${conf_paths[@]}"; do
        if [ -f "$path" ]; then
            nginx_conf="$path"
            break
        fi
    done

    if [ -z "$nginx_conf" ]; then
        echo "[-] Error: Could not locate nginx.conf in known directories."
        read -rp "Press Enter to return..." _
        return 1
    fi
    echo "[+] Found Nginx config at: $nginx_conf"

    # 2. Determine Nginx binary path
    for bin in "${bin_paths[@]}"; do
        if [ -x "$bin" ]; then
            nginx_bin="$bin"
            break
        fi
    done

    # 3. Check if worker_processes 1 is already set
    if grep -qE '^[[:space:]]*worker_processes[[:space:]]+1;' "$nginx_conf"; then
        echo "[!] Nginx is ALREADY configured for 1 worker process."
        echo "[!] No changes needed."
        read -rp "Press Enter to return..." _
        return 0
    fi

    # 4. Create a safety backup
    cp "$nginx_conf" "${nginx_conf}.bak"
    echo "[*] Backup created at ${nginx_conf}.bak"

    # 5. Modify or insert worker_processes directive
    if grep -qE '^[[:space:]]*worker_processes[[:space:]]+' "$nginx_conf"; then
        echo "[*] Modifying existing worker_processes directive..."
        sed -i -E 's/^[[:space:]]*worker_processes[[:space:]]+[^;]+;/worker_processes 1;/' "$nginx_conf"
    else
        echo "[*] worker_processes directive not found. Adding to top of file..."
        sed -i '1i worker_processes 1;' "$nginx_conf"
    fi

    # 6. Test syntax before reloading
    if [ -n "$nginx_bin" ]; then
        echo "[*] Validating Nginx configuration syntax..."
        if ! "$nginx_bin" -t -c "$nginx_conf" >/dev/null 2>&1; then
            echo "[-] Error: Nginx configuration test failed! Restoring original file..."
            cp "${nginx_conf}.bak" "$nginx_conf"
            read -rp "Press Enter to return..." _
            return 1
        fi
    fi

    # 7. Reload Nginx
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
credits () {
    echo "================================================================"
    echo "                          Credits for"
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
