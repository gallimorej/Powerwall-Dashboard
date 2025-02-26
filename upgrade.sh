#!/bin/bash

# Stop on Errors
set -e

# Set Globals
VERSION="3.0.2"
CURRENT="Unknown"
COMPOSE_ENV_FILE="compose.env"
TELEGRAF_LOCAL="telegraf.local"
PW_ENV_FILE="pypowerwall.env"
GF_ENV_FILE="grafana.env"
PROFILE="none"
if [ -f VERSION ]; then
    CURRENT=`cat VERSION`
fi

# Verify not running as root
if [ "$EUID" -eq 0 ]; then
    echo "ERROR: Running this as root will cause permission issues."
    echo ""
    echo "Please ensure your local user is in the docker group and run without sudo."
    echo "   sudo usermod -aG docker \$USER"
    echo "   $0"
    echo ""
    exit 1
fi

# Windows Git Bash docker exec compatibility fix
if type winpty > /dev/null 2>&1; then
    shopt -s expand_aliases
    alias docker="winpty -Xallow-non-tty -Xplain docker"
fi

# Service Running Helper Function
running() {
    local url=${1:-http://localhost:80}
    local code=${2:-200}
    local status=$(curl --head --location --connect-timeout 5 --write-out %{http_code} --silent --output /dev/null ${url})
    [[ $status == ${code} ]]
}

# Compose Profiles Helper Functions
get_profile() {
    if [ ! -f ${COMPOSE_ENV_FILE} ]; then
        return 1
    else
        unset COMPOSE_PROFILES
        . "${COMPOSE_ENV_FILE}"
    fi
    # Check COMPOSE_PROFILES for profile
    IFS=',' read -a PROFILES <<< ${COMPOSE_PROFILES}
    for p in "${PROFILES[@]}"; do
        if [ "${p}" == "${1}" ]; then
            return 0
        fi
    done
    return 1
}

add_profile() {
    # Create default docker compose env file if needed.
    if [ ! -f ${COMPOSE_ENV_FILE} ]; then
        cp "${COMPOSE_ENV_FILE}.sample" "${COMPOSE_ENV_FILE}"
    fi
    if ! get_profile "${1}"; then
        # Add profile to COMPOSE_PROFILES and save to env file
        PROFILES+=("${1}")
        if [ -z "${COMPOSE_PROFILES}" ]; then
            if grep -q "^#COMPOSE_PROFILES=" "${COMPOSE_ENV_FILE}"; then
                sed -i.bak "s@^#COMPOSE_PROFILES=.*@COMPOSE_PROFILES=$(IFS=,; echo "${PROFILES[*]}")@g" "${COMPOSE_ENV_FILE}"
            else
                echo -e "\nCOMPOSE_PROFILES=$(IFS=,; echo "${PROFILES[*]}")" >> "${COMPOSE_ENV_FILE}"
            fi
        else
            sed -i.bak "s@^COMPOSE_PROFILES=.*@COMPOSE_PROFILES=$(IFS=,; echo "${PROFILES[*]}")@g" "${COMPOSE_ENV_FILE}"
        fi
    fi
}

# Because this file can be upgraded, don't use it to run the upgrade
if [ "$0" != "tmp.sh" ]; then
    # Grab latest upgrade script from GitHub and run it
    curl -sL --output tmp.sh https://raw.githubusercontent.com/jasonacox/Powerwall-Dashboard/main/upgrade.sh
    exec bash tmp.sh upgrade
fi

# Check to see if an upgrade is available
if [ "$VERSION" == "$CURRENT" ]; then
    echo "WARNING: You already have the latest version (v${VERSION})."
    echo ""
fi

echo "Upgrade Powerwall-Dashboard from ${CURRENT} to ${VERSION}"
echo "---------------------------------------------------------------------"
echo "This script will attempt to upgrade you to the latest version without"
echo "removing existing data. A backup is still recommended."
echo ""

# Check for existing solar-only installation
if [ -f tools/solar-only/compose.env ] && [ ! -f ${COMPOSE_ENV_FILE} ]; then
    echo "NOTE: Your existing 'solar-only' installation will be migrated to:"
    echo "      ${PWD}"
    echo ""
    PROFILE="solar-only"
fi

# Check COMPOSE_PROFILES for existing configuration profile
if get_profile "default"; then
    PROFILE="default"
elif get_profile "solar-only"; then
    PROFILE="solar-only"
fi

# Stop upgrade if the installation is missing key files
if [ ! -f ${PW_ENV_FILE} ] && [ "${PROFILE}" != "solar-only" ]; then
    echo "ERROR: Missing ${PW_ENV_FILE} - This means you have not run 'setup.sh' or"
    echo "       you have an older version that cannot be updated automatically."
    echo "       Run 'git pull' and resolve any conflicts then run the 'setup.sh'"
    echo "       script to re-enter your Powerwall credentials."
    echo ""
    echo "Exiting"
    rm -f tmp.sh
    exit 1
fi

# Verify Upgrade
read -r -p "Upgrade - Proceed? [y/N] " response
if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]
then
    echo ""
else
    echo "Cancel"
    rm -f tmp.sh
    exit
fi

# Migrate existing solar-only installation if found
if [ -f tools/solar-only/compose.env ] && [ ! -f ${COMPOSE_ENV_FILE} ]; then
    cd tools/solar-only

    if [ -f tz ]; then
        cp tz ../../tz
        ./tz.sh "America/Los_Angeles" > /dev/null 2>&1
    else
        # Files missing due to user manually pulling latest changes
        CURR_TZ=`cat ../../tz`
        echo "Timezone used for solar-only install (leave blank for ${CURR_TZ})"
        read -p 'Enter Timezone: ' TZ
        echo ""
        if [ -z "${TZ}" ]; then
            echo "Using ${CURR_TZ} timezone..."
            echo "${CURR_TZ}" > tz
        else
            echo "Setting ${TZ} timezone..."
            echo "${TZ}" > tz
        fi
        echo ""
        cp tz ../../tz
        ../../tz.sh "America/Los_Angeles" > /dev/null 2>&1
    fi

    echo "Migrating solar-only installation..."

    if [ -f powerwall.yml ]; then
        ./compose-dash.sh down
    else
        # Files missing due to user manually pulling latest changes
        docker stop $(docker ps -aq) > /dev/null 2>&1
        docker rm $(docker ps -aq) > /dev/null 2>&1
    fi
    mv compose.env ../../${COMPOSE_ENV_FILE}
    mv grafana.env ../../${GF_ENV_FILE}
    mv ../../grafana ../../grafana.bak
    mv grafana ../..
    mv ../../influxdb ../../influxdb.bak
    mv influxdb ../..
    mv tesla-history/tesla-history.auth ../tesla-history/tesla-history.auth
    mv tesla-history/tesla-history.conf ../tesla-history/tesla-history.conf
    if [ -f weather/weather411.conf ]; then
        mv weather/weather411.conf ../../weather/weather411.conf
    fi
    rm -rf tz tesla-history weather dashboard.json.bak
    cd ../..

    # Add solar-only and weather411 (if configured) to COMPOSE_PROFILES
    PROFILE="solar-only"
    add_profile "solar-only"
    if [ -f weather/weather411.conf ]; then
        add_profile "weather411"
    fi
    echo ""
fi

# Remember Timezone and Reset to Default
echo "Resetting Timezone to Default..."
DEFAULT="America/Los_Angeles"
TZ=`cat tz`
if [ -z "${TZ}" ]; then
    TZ="America/Los_Angeles"
fi
./tz.sh "${DEFAULT}" > /dev/null 2>&1

# Pull from GitHub
echo ""
echo "Pull influxdb.sql, dashboard.json, telegraf.conf, and other changes..."
echo ""
git stash
git pull --rebase
echo ""

# Create Grafana Settings if missing (required in 2.4.0)
if [ ! -f ${GF_ENV_FILE} ]; then
    cp "${GF_ENV_FILE}.sample" "${GF_ENV_FILE}"
fi

# Check for latest Grafana settings (required in 2.6.2)
if ! grep -q "yesoreyeram-boomtable-panel-1.5.0-alpha.3.zip" "${GF_ENV_FILE}"; then
    echo "Your Grafana environmental settings are outdated."
    read -r -p "Upgrade ${GF_ENV_FILE}? [y/N] " response
    if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]
    then
        cp "${GF_ENV_FILE}" "${GF_ENV_FILE}.bak"
        cp "${GF_ENV_FILE}.sample" "${GF_ENV_FILE}"
        echo "Updated"
        docker stop grafana
        docker rm grafana
    else
        echo "No Change"
    fi
fi

# Silently create default docker compose env file if needed.
if [ ! -f ${COMPOSE_ENV_FILE} ]; then
    cp "${COMPOSE_ENV_FILE}.sample" "${COMPOSE_ENV_FILE}"
else
    # Convert GRAFANAUSER to PWD_USER in existing compose env file (required in 2.10.0)
    sed -i.bak "s@GRAFANAUSER@PWD_USER@g" "${COMPOSE_ENV_FILE}"
    if grep -q "^PWD_USER=\"1000:1000\"" "${COMPOSE_ENV_FILE}"; then
        sed -i.bak "s@^PWD_USER=\"1000:1000\"@#PWD_USER=\"1000:1000\"@g" "${COMPOSE_ENV_FILE}"
    fi
fi

# Check for COMPOSE_PROFILES and add if missing (required in 3.0.0)
if get_profile "default"; then
    PROFILE="default"
elif get_profile "solar-only"; then
    PROFILE="solar-only"
else
    # Missing - Add default and weather411 (if configured) to COMPOSE_PROFILES
    PROFILE="default"
    add_profile "default"
    if [ -f weather/weather411.conf ]; then
        add_profile "weather411"
    fi
fi

if [ "${PROFILE}" == "default" ]
then
    # Create default telegraf local file if needed.
    if [ ! -f ${TELEGRAF_LOCAL} ]; then
        cp "${TELEGRAF_LOCAL}.sample" "${TELEGRAF_LOCAL}"
    fi

    # Check for PW_STYLE setting and add if missing
    if ! grep -q "PW_STYLE" ${PW_ENV_FILE}; then
        echo "Your pypowerwall environmental settings are missing PW_STYLE."
        echo "Adding..."
        echo "PW_STYLE=grafana-dark" >> ${PW_ENV_FILE}
    fi

    # Check to see that TZ is set in pypowerwall
    if ! grep -q "TZ=" ${PW_ENV_FILE}; then
        echo "Your pypowerwall environmental settings are missing TZ."
        echo "Adding..."
        echo "TZ=America/Los_Angeles" >> ${PW_ENV_FILE}
    fi
fi

# Check to see if Weather Data is Available
if [ ! -f weather/weather411.conf ]; then
    echo "This version (${VERSION}) allows you to add local weather data."
    echo ""
    # Optional - Setup Weather Data
    if [ -f weather.sh ]; then
        ./weather.sh setup
    else
        echo "However, you are missing the weather.sh setup file. Skipping..."
        echo ""
    fi
fi

# Set Timezone
echo ""
echo "Setting Timezone back to ${TZ}..."
./tz.sh "${TZ}"

# Update Powerwall-Dashboard stack
echo ""
echo "Updating Powerwall-Dashboard stack..."
./compose-dash.sh up -d

# Update InfluxDB
echo ""
echo "Waiting for InfluxDB to start..."
until running http://localhost:8086/ping 204 2>/dev/null; do
    printf '.'
    sleep 5
done
echo " up!"
sleep 2
echo ""
echo "Add downsample continuous queries to InfluxDB..."
docker exec --tty influxdb sh -c "influx -import -path=/var/lib/influxdb/influxdb.sql"
cd influxdb
for f in run-once*.sql; do
    if [ ! -f "${f}.done" ]; then
        echo "Executing single run query $f file..."
        docker exec --tty influxdb sh -c "influx -import -path=/var/lib/influxdb/${f}"
        echo "OK" > "${f}.done"
    fi
done
cd ..

if [ ! -z "$(docker ps -aq -f name=^pypowerwall$)" ]; then
    # Delete pyPowerwall
    echo ""
    echo "Deleting old pyPowerwall..."
    docker stop pypowerwall
    docker rm pypowerwall
fi

if [ ! -z "$(docker ps -aq -f name=^telegraf$)" ]; then
    # Delete telegraf
    echo ""
    echo "Deleting old telegraf..."
    docker stop telegraf
    docker rm telegraf
fi

if [ ! -z "$(docker ps -aq -f name=^weather411$)" ]; then
    # Delete weather411
    echo ""
    echo "Deleting old weather411..."
    docker stop weather411
    docker rm weather411
fi

if [ ! -z "$(docker ps -aq -f name=^tesla-history$)" ]; then
    # Delete tesla-history
    echo ""
    echo "Deleting old tesla-history..."
    docker stop tesla-history
    docker rm tesla-history
fi

# Restart Stack and Rebuild containers
echo ""
echo "Restarting Powerwall-Dashboard stack..."
./compose-dash.sh up -d

# Display Final Instructions
if [ "${PROFILE}" == "solar-only" ]
then
    DASHBOARD="dashboard-solar-only.json"
else
    DASHBOARD="dashboard.json"
fi
cat << EOF

---------------[ Update Dashboard ]---------------
Open Grafana at http://localhost:9000/

From 'Dashboard/Browse', select 'New/Import', and
upload '${DASHBOARD}' located in the folder
${PWD}/dashboards/

Please note, you may need to select data sources
for 'InfluxDB' and 'Sun and Moon' via the
dropdowns and use 'Import (Overwrite)' button.

EOF

# Clean up temporary upgrade script
rm -f tmp.sh
