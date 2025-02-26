# Ecowitt Local Weather Server

![Docker Pulls](https://img.shields.io/docker/pulls/jasonacox/ecowitt)

This server pulls current weather data from [Ecowitt.net Weather API](https://api.ecowitt.net/api/v3/device/real_time), makes it available via local API calls and stores the data in InfluxDB for graphing.

This service was built to easily add weather data graphs to the [Powerwall-Dashboard](https://github.com/jasonacox/Powerwall-Dashboard) project.

Docker: docker pull [jasonacox/ecowitt](https://hub.docker.com/r/jasonacox/ecowitt)

## Quick Start


1. Create a `ecowitt.conf` file in /weather/contrib/ecowitt (`cp ecowitt.conf.sample ecowitt.conf`) and update with your specific device / API details:

    * Enter your Ecowitt API Key (APIKEY and APPLICATION KEY). Set up your APIKEY and APPLICATION_KEY on your [Ecowitt User Page](https://www.ecowitt.net/user/index). 
    * Enter your Device MAC Address (MAC).

    ```python
    [LocalWeather]
    DEBUG = no

    [API]
    # Port to listen on for requests (default 8686)
    ENABLE = yes
    # Different Port to Weather 411 so they can co-exist
    PORT = 8686

    [Ecowitt]
    # Set your APIKEY and APPLICATION_KEY from https://www.ecowitt.net/user/index
    APIKEY = xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
    APPLICATION_KEY = XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX

    # Set the MAC address for the specific station you want to query
    MAC = 01:23:45:67:89:AB

    WAIT = 1
    TIMEOUT = 10

    # standard, metric or imperial 
    UNITS = metric

    [InfluxDB]
    # Record data in InfluxDB server 
    ENABLE = yes
    HOST = influxdb
    PORT = 8086
    DB = powerwall
    FIELD = localweather
    # Auth - Leave blank if not used
    USERNAME =
    PASSWORD =
    # Influx 2.x - Leave blank if not used
    TOKEN =
    ORG =
    URL =

2. Run the Docker Container to listen on port 8686.

    ```bash
    docker run \
    -d \
    -p 8686:8686 \
    -e WEATHERCONF='/var/lib/weather/ecowitt.conf' \
    -v ${PWD}:/var/lib/weather \
    --name ecowitt \
    --restart unless-stopped \
    jasonacox/ecowitt
    ```

3. Test the API Service

    Website of Current Weather: http://localhost:8686/

    ```bash
    # Get Current Weather Data
    curl -i http://localhost:8686/temp
    curl -i http://localhost:8686/all
    curl -i http://localhost:8686/conditions

    # Get Proxy Stats
    curl -i http://localhost:8686/stats

    # Clear Proxy Stats
    curl -i http://localhost:8686/stats/clear
    ```

4. Incorporate into Powerwall-Dashboard

    Save the following into a file called powerwall.extend.yml in your Powerwall-Dashboard folder

    ```yaml
    version: "3.5"

    services:
        ecowitt:
            # Uncomment next line to build locally
            # build: ./weather/contrib/ecowitt
            image: jasonacox/ecowitt:latest
            container_name: ecowitt
            hostname: ecowitt
            restart: always
            user: "1000:1000"
            volumes:
                - type: bind
                  source: ./weather/contrib/ecowitt
                  target: /var/lib/ecowitt
                  read_only: true
            ports:
                - target: 8686
                  published: 8686
                  mode: host
            environment:
                - WEATHERCONF=/var/lib/ecowitt/ecowitt.conf
            depends_on:
                - influxdb
    ```

    Then restart the services using compose-dash.sh and the new component will be picked up:

    ```bash
    ./compose-dash.sh stop
    ./compose-dash.sh up -d
    ```


## Build Your Own

This folder contains the `server.py` script that runs a multi-threaded python based API webserver.  

The `Dockerfile` here will allow you to containerize the proxy server for clean installation and running.

1. Build the Docker Container

    ```bash
    # Build for local architecture  
    docker build -t jasonacox/ecowitt:latest .

    # Build for all architectures - requires Docker experimental 
    docker buildx build --platform linux/amd64,linux/arm64,linux/arm/v7 -t jasonacox/ecowitt:latest . 

    ```

2. Setup the Docker Container to listen on port 8686.

    ```bash
    docker run \
    -d \
    -p 8686:8686 \
    -e WEATHERCONF='/var/lib/weather/ecowitt.conf' \
    --name ecowitt \
    -v ${PWD}:/var/lib/weather \
    --restart unless-stopped \
    jasonacox/ecowitt
    ```

3. Test the API

    ```bash
    curl -i http://localhost:8686/temp
    curl -i http://localhost:8686/stats
    ```

    Browse to http://localhost:8686/ to see current weather conditions.


## Troubleshooting Help

If you see python errors, make sure you entered your credentials correctly in `docker run`.

```bash
# See the logs
docker logs ecowitt

# Stop the server
docker stop ecowitt

# Start the server
docker start ecowitt
```

## Release Notes

### 0.2.2 - Bug Fix for User/Pass

* Fix access to InfluxDB where username and password and configured and required.  Impacts by InfluxDB v1 and v2. Issue reported by @sumnerboy12 in #199.

### 0.2.1 - Upgrade InfluxDB Client 

* Upgrade end of life `influxdb` client library to `influxdb-client`, providing support for InfluxDB 1.8 and 2.x.  Add Verify Support.

### 0.2.0 - Upgrade InfluxDB Client 

* Upgrade end of life `influxdb` client library to `influxdb-client`, providing support for InfluxDB 1.8 and 2.x.

### 0.0.4.1 

* Change to docker compose instructions to work with modified compose-dash

### 0.0.4 - Third Release 

* Fix to Rainfall Data
* Fix to Humidity Data
* Add Dew Point to Weather Data
* Change default name of conf file
* Correct Name of config file comment in server.py
* Fix Build Your Own instructions in README (incorrect container name)
* Remove redundant data

### 0.0.3 - Second Release 

* Rename Container to ecowitt
* Rename Configuration to ecowitt.conf
* Rename Docker Hub Image to jasoncox/ecowitt
* Add in instructions for modifying powerwall.yml
* Change instructions to run under /weather/contrib/ecowitt structure

### 0.0.2 - First Release 

* Made as similar as possible to Weather411

### 0.0.1 - Initial Build

* Initial Release
