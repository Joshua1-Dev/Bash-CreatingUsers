#!/bin/bash

# Define paths and files
USER_FILE="users.txt"
LOG_FILE="/var/log/user_management.log"
PASSWORD_FILE="/var/secure/user_passwords.txt"

# Check if root is executing the script
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root"
    exit 1
fi

# Function to log messages
log_message() {
    local log_content="$1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $log_content" >> "$LOG_FILE"
}

# Function to create user and groups
create_user_and_groups() {
    local username="$1"
    local groups="$2"

    # Create user if it does not exist
    if id "$username" &>/dev/null; then
        log_message "User $username already exists. Skipping."
    else
        useradd -m -s /bin/bash "$username"
        log_message "User $username created."
    fi

    # Create groups if they do not exist
    IFS=',' read -ra group_list <<< "$groups"
    for group in "${group_list[@]}"; do
        if grep -q "^$group:" /etc/group; then
            log_message "Group $group already exists. Skipping."
        else
            groupadd "$group"
            log_message "Group $group created."
        fi
        # Add user to group
        usermod -a -G "$group" "$username"
        log_message "User $username added to group $group."
    done

    # Set group for the user's personal group
    usermod -g "$username" "$username"

    # Generate random password
    password=$(openssl rand -base64 12)
    echo "$username:$password" | chpasswd

    # Log password to secure file
    echo "$username:$password" >> "$PASSWORD_FILE"
    log_message "Password for $username saved to $PASSWORD_FILE."

    # Set ownership and permissions for home directory
    chown -R "$username:$username" "/home/$username" &>> "$LOG_FILE"
    chmod 700 /home/"$username"
    log_message "Permissions set for $username's home directory."
}

# Main script execution starts here
while IFS=';' read -r username user_groups; do
    create_user_and_groups "$username" "$user_groups"
done < "$USER_FILE"
