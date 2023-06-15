# Odoo Server Setup

## Odoo Install Scripts

This scripts automates the configuration of an odoo instance, including:

- Updating and upgrading the system.
- Install common packages such as dpkg, unzip, zip, and wget.
- Install and enables PostgreSQL 14.
- Install Python 3.10 along with its requirements, including various development libraries.
- Install Python 3 Certbot for Nginx.
- Install wkhtmltopdf version 0.12.6.1-2.
- Create a user named "deploy" with restricted privileges and sets up SSH key-based authentication for the user.

There is multiple scripts for different version of Odoo and Ubuntu:

- odoo-11-20.04
- odoo-15-20.04
- odoo-16-20.04

### One-line Commands

One-line command for the latest release:

```sh
sudo su -c "bash <(wget -qO- https://github.com/VictorHachard/odoo-server-setup/releases/latest/download/odoo-16-22.04.sh) -y" root
```

One-line command for the latest version:

```sh
sudo su -c "bash <(wget -qO- https://raw.githubusercontent.com/VictorHachard/odoo-server-setup/main/odoo-16-22.04.sh) -y" root
```

## Odoo Add Environment Scripts

This script sets up an Odoo instance environment. Creates an Odoo user, a PostgreSQL user, a service and configures Nginx. 

Here's a recap of the script:

- Creates an Odoo user and sets up the necessary directories and permissions.
- Creates an Odoo user in PostgreSQL.
- Creates an Odoo service unit file in /etc/systemd/system.
- Enables the Odoo service.
- Creates an Nginx server block configuration file for the Odoo instance. If the environment is not the production, it adds the location = /robots.txt block to the Nginx configuration file to block indexing.
- Moves the Nginx configuration file to the appropriate directory and creates a symbolic link. You should provide the correct paths for ssl_certificate and ssl_certificate_key in the configuration file.

### Usage

./odoo_env_setup.sh [OPTIONS]

Options:

| Command | Description |
| --- | --- |
| y | Automatically run the script without confirmation. |
| e ENVIRONMENT | Specify the environment (p - Production, c - Certification, d - Test). |
| o USERNAME | Specify the Odoo username (without the 'odoo-' prefix). |
| p PORT | Specify the Odoo port number. |
| lp PORT | Specify the Long Polling port number. 
| w WEBSITE_NAME | Specify the website name for the Nginx server. |

Note:

- During the script execution, you will be prompted for confirmation before certain steps.
- If the '-y' option is used, run the script automatically without confirmation.
- The Odoo username provided with the '-o' option will have the 'odoo-' prefix automatically added.
- Ensure that Nginx and PostgreSQL are already installed on the system before running this script.
- Make sure to provide valid values for each option.

Example Usage:

```sh
./odoo_env_setup.sh -y -e p -o prod -p 8069 -lp 8072 -w example.com
```

### One-line Commands

One-line command for the latest release:

```sh
sudo su -c "bash <(wget -qO- https://github.com/VictorHachard/odoo-server-setup/releases/latest/download/odoo-instance.sh) -y -e p -a" root
```

One-line command for the latest version:

```sh
sudo su -c "bash <(wget -qO- https://raw.githubusercontent.com/VictorHachard/odoo-server-setup/main/odoo-instance.sh) -y -e p -a" root
```

## Usage

1. Download the script:

   - Latest release:
      ```
      wget https://github.com/VictorHachard/odoo-server-setup/releases/latest/download/<script>.sh
      ```
   - Latest version:
      ```
      wget https://raw.githubusercontent.com/VictorHachard/odoo-server-setup/main/<script>.sh
      ```

2. Make the script executable:

   ```
   chmod +x <script>.sh
   ```

3. Run the script with elevated privileges:

   ```
   sudo ./<script>.sh
   ```

One-line solution for the latest release:

```sh
sudo su -c "bash <(wget -qO- https://github.com/VictorHachard/ubuntu-server-setup/releases/latest/download/<script>.sh)" root
```

One-line solution for the latest version:

```sh
sudo su -c "bash <(wget -qO- https://raw.githubusercontent.com/VictorHachard/ubuntu-server-setup/main/<script>.sh)" root
```

## Disclaimer

Use this script at your own risk. While it has been tested on Ubuntu 22.04, it may not work on other distributions or configurations. It is highly recommended to review and understand the script code before running it, and to take backups or snapshots of your instance before applying any changes.
