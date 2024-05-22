# Cloudflare DDNS Updater

This Bash script is designed to automatically update Cloudflare DNS A records for specified subdomains with your current external IP address. It checks your IP address periodically and updates Cloudflare if it has changed.

## Features

*   Regularly checks for IP changes
*   Supports multiple subdomains
*   Logs updates to a file
*   Sends optional notifications to Slack and/or Discord
*   Securely stores API credentials and settings in a `.env` file

## Prerequisites

*   A Cloudflare account with API token
*   Bash environment
*   `curl` and `jq` installed
*   (Optional) Slack and Discord webhooks for notifications

## Setup

1.  **Clone the repository:**
    ```bash
    git clone <repository-url>
    cd cloudflare-ddns
    ```

2.  **Create and configure `.env` file:**
    ```bash
    cp .env.example .env
    ```
    Fill in the following details in the `.env` file:
    *   `CLOUDFLARE_API_TOKEN`
    *   `ZONE_ID`
    *   `DOMAIN`
    *   `SUBDOMAINS` (comma-separated list, e.g., "home,blog")
    *   `LOG_FILE`
    *   (Optional) `SLACK_URI`, `SLACK_CHANNEL`
    *   (Optional) `DISCORD_URI`

3.  **Make the script executable:**
    ```bash
    chmod +x cloudflare-ddns.sh
    ```

## Usage

You can run the script manually:

```bash
./cloudflare-ddns.sh
