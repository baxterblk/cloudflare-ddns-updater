#!/bin/bash

# Load environment variables from .env file
set -a
source /home/$USER/scripts/.env
set +a

# Function to get the current external IP address
get_current_ip() {
    ipv4_regex='([01]?[0-9]?[0-9]|2[0-4][0-9]|25[0-5])\.([01]?[0-9]?[0-9]|2[0-4][0-9]|25[0-5])\.([01]?[0-9]?[0-9]|2[0-4][0-9]|25[0-5])\.([01]?[0-9]?[0-9]|2[0-4][0-9]|25[0-5])'
    ip=$(curl -s -4 https://cloudflare.com/cdn-cgi/trace | grep -E '^ip'); ret=$?
    if [[ ! $ret == 0 ]]; then
        ip=$(curl -s https://api.ipify.org || curl -s https://ipv4.icanhazip.com)
    else
        ip=$(echo $ip | sed -E "s/^ip=($ipv4_regex)$/\1/")
    fi

    if [[ ! $ip =~ ^$ipv4_regex$ ]]; then
        logger -s "DDNS Updater: Failed to find a valid IP."
        exit 2
    fi
    echo $ip
}

# Function to get the Cloudflare DNS record ID for a given subdomain
get_record_id() {
    local subdomain="$1"
    curl -s -X GET "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/dns_records?type=A&name=${subdomain}.${DOMAIN}" \
        -H "Authorization: Bearer ${CLOUDFLARE_API_TOKEN}" \
        -H "Content-Type: application/json" | jq -r '.result[0].id'
}

# Function to get the Cloudflare DNS record IP for a given subdomain
get_record_ip() {
    local subdomain="$1"
    curl -s -X GET "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/dns_records?type=A&name=${subdomain}.${DOMAIN}" \
        -H "Authorization: Bearer ${CLOUDFLARE_API_TOKEN}" \
        -H "Content-Type: application/json" | jq -r '.result[0].content'
}

# Function to update the Cloudflare DNS record with the current IP
update_record() {
    local subdomain="$1"
    local ip="$2"
    local record_id
    record_id=$(get_record_id "$subdomain")

    if [ "$record_id" != "null" ]; then
        update=$(curl -s -X PATCH "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/dns_records/${record_id}" \
            -H "Authorization: Bearer ${CLOUDFLARE_API_TOKEN}" \
            -H "Content-Type: application/json" \
            --data "{\"type\":\"A\",\"name\":\"${subdomain}.${DOMAIN}\",\"content\":\"${ip}\",\"ttl\":120,\"proxied\":false}")

        if [[ $update == *"\"success\":false"* ]]; then
            logger -s "DDNS Updater: Failed to update ${subdomain}.${DOMAIN} to IP ${ip}."
            send_notification "DDNS Update Failed: ${subdomain}.${DOMAIN} to IP ${ip}."
        else
            logger "DDNS Updater: Updated ${subdomain}.${DOMAIN} to IP ${ip}."
            send_notification "${subdomain}.${DOMAIN} updated to IP ${ip}."
        fi
    else
        logger -s "DDNS Updater: Failed to update ${subdomain}.${DOMAIN}. Record ID not found."
        send_notification "Failed to update ${subdomain}.${DOMAIN}. Record ID not found."
    fi
}

# Function to send notifications to Slack and Discord
send_notification() {
    local message="$1"
    if [[ $SLACK_URI != "" ]]; then
        curl -L -X POST $SLACK_URI --data-raw "{\"channel\": \"$SLACK_CHANNEL\", \"text\": \"$message\"}"
    fi
    if [[ $DISCORD_URI != "" ]]; then
        curl -i -H "Accept: application/json" -H "Content-Type: application/json" -X POST --data-raw "{\"content\": \"$message\"}" $DISCORD_URI
    fi
}

# Main loop to continuously check and update IP
while true; do
    current_ip=$(get_current_ip)
    if [ -z "$current_ip" ]; then
        echo "$(date): Failed to get current IP" >> ${LOG_FILE}
        sleep 300
        continue
    fi

    for subdomain in $SUBDOMAINS; do
        cloudflare_ip=$(get_record_ip "$subdomain")

        if [ "$current_ip" != "$cloudflare_ip" ]; then
            update_record "$subdomain" "$current_ip"
        fi
    done

    sleep 300  # Check every 5 minutes
done
