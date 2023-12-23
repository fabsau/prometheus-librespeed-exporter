# Prometheus LibreSpeed Exporter
This readme provides an in-depth guide on how to utilize the `prometheus-librespeed-exporter` project, a [Prometheus](https://prometheus.io/) exporter based on the [speedtest-cli](https://github.com/librespeed/speedtest-cli) by [librespeed](https://github.com/librespeed). The exporter tool allows you to measure network performance effectively.

This project is a fork of the one found [here](https://github.com/brendonmatheson/prometheus-librespeed-exporter), enriched with updates, additional metrics, more features, better customizability and improved error handling.


## Docker
You can easily run the Prometheus LibreSpeed Exporter using Docker. Here is how you can get up and running in no time:

### Running with Docker Run
This command will pull and start the most recent Docker container using the specified image and port.
```bash
docker run \
    --rm -it \
    -p 9469:9469 \
    -e USE_PUBLIC_TEST_SERVER=TRUE \
    ghcr.io/fabsau/prometheus-librespeed-exporter:latest
```

### Running with Docker Compose
```yaml
services:
  librespeed_exporter:
    image: "ghcr.io/fabsau/prometheus-librespeed-exporter:latest"
    ports:
      - "9469:9469"
    restart: "always"
    environment:
      - "USE_PUBLIC_TEST_SERVER=TRUE"
```


## Configuration

### Environment Variables
```
# Description: Toggle to enable the use of public servers for speed tests. For testing it will automatically pick the closest server.
# Options: TRUE or FALSE (case-insensitive)
# Default: FALSE
USE_PUBLIC_TEST_SERVER=TRUE

# Description: Specifies the file path to a custom json file containing custom server details for speed testing.
# Type: string (file path)
# Default: not set
# CUSTOM_SERVER_FILE=/your/path/to/server/file.json

# Description: This variable contains a list of specific server IDs to be used from the CUSTOM_SERVER_FILE.
# The server IDs should match those in your CUSTOM_SERVER_FILE. If no server IDs are specified, all servers listed in CUSTOM_SERVER_FILE will be used for tests.
# Type: string (comma-separated values)
# Default: not set
# SPECIFIC_SERVER_IDS=1,2,3

# Description: Holds additional command line arguments for the librespeed-cli tool.
# Refer to the librespeed-cli usage guide for information about the command line options.
# https://github.com/librespeed/speedtest-cli#usage
# Type: string
# Default: not set
# CUSTOM_ARGS=--duration 15 --no-download
```

### Using Custom Servers
With LibreSpeed, you're not limited to public servers. You can define your own custom servers for performing the speed test. Register them in a dedicated JSON file and path to it using the `CUSTOM_SERVER_FILE` environment variable. Make sure to path down the volume and create the file before starting the container.

See the [librespeed / speedtest-cli documentation](https://github.com/librespeed/speedtest-cli#use-a-custom-backend-server-list) for additional details on creating custom server.

#### librespeed-backends.json:
```json
[
  {
    "id": 1,
    "name": "server1",
    "server": "http://speedtest.example1.com/",
    "dlURL": "backend/garbage.php",
    "ulURL": "backend/empty.php",
    "pingURL": "backend/empty.php",
    "getIpURL": "backend/getIP.php"
  },
  {
    "id": 2,
    "name": "server2",
    "server": "http://speedtest.example2.com/",
    "dlURL": "backend/garbage.php",
    "ulURL": "backend/empty.php",
    "pingURL": "backend/empty.php",
    "getIpURL": "backend/getIP.php"
  }
]
```

#### docker-compose:
```yaml
services:
  librespeed_exporter:
    image: "ghcr.io/fabsau/prometheus-librespeed-exporter:latest"
    ports:
      - "9469:9469"
    restart: "always"
    environment:
      - "USE_PUBLIC_TEST_SERVER=FALSE"
      - "CUSTOM_SERVER_FILE=/librespeed-backends.json"
      - "SPECIFIC_SERVER_IDS=1"
      - "CUSTOM_ARGS=--duration 15 --no-download"
    volumes:
      - ./librespeedexporter/librespeed-backends.json:/librespeed-backends.json
```

### Testing the Exporter
You can validate the exporter's functionality by testing if it produces the expected metrics:

```bash
curl http://localhost:9469/probe?script=librespeed
```
Remember, the speed test may take up to a minute as the test performs on each load.

## Integration
### Setting Up Prometheus
Now, include a job in your Prometheus configuration:

```yaml
  - job_name: "librespeed"
    metrics_path: /probe
    params:
      script: [librespeed]
    static_configs:
      - targets:
          - myexporterhostname:9469
    scrape_interval: 60m
    scrape_timeout: 5m
```
Remember to consider the speed test duration when setting the `scrape_timeout` and `scrape_interval` parameters.

### Setting Up Alerts
Prometheus allows the configuration of alerts for notifications when speed test results drop below a chosen threshold.
The following examples serve as a guide to the potent monitoring capabilities of the exporter. Remember, these samples should be fine-tuned to align with the unique conditions of your operational environment.

```yaml
groups:
  - name: LibrespeedAlerts
    rules:
      - alert: HighPing
        expr: librespeed_ping > 100
        for: 120m
        labels:
          severity: warning
        annotations:
          description: Ping is high (above 100ms) on '{{ $labels.server }}'

      - alert: HighJitter
        expr: librespeed_jitter > 2
        for: 120m
        labels:
          severity: warning
        annotations:
          description: Jitter is high (above 2ms) on '{{ $labels.server }}'

      - alert: LowDownloadSpeedPublic
        expr: librespeed_download < 187.5 and librespeed_server_info{server_type="public"} == 1
        for: 120m
        labels:
          severity: warning
        annotations:
          description: Download speed is below 75 percent of 250Mbps (187.5Mbps) on public server '{{ $labels.server }}'

      - alert: LowUploadSpeedPublic
        expr: librespeed_upload < 37.5 and librespeed_server_info{server_type="public"} == 1
        for: 120m
        labels:
          severity: warning
        annotations:
          description: Upload speed is below 75 percent of 50Mbps (37.5Mbps) on public server '{{ $labels.server }}'

      - alert: LowDownloadSpeedCustom
        expr: librespeed_download < 500 and librespeed_server_info{server_type="custom"} == 1
        for: 120m
        labels:
          severity: warning
        annotations:
          description: Download speed is below 500Mbps on custom server '{{ $labels.server }}'

      - alert: LowUploadSpeedCustom
        expr: librespeed_upload < 100 and librespeed_server_info{server_type="custom"} == 1
        for: 120m
        labels:
          severity: warning
        annotations:
          description: Upload speed is below 100Mbps on custom server '{{ $labels.server }}'

      - alert: LowDownloadSpeedServer2
        expr: librespeed_download{server="server2"} < 750
        for: 120m
        labels:
          severity: warning
        annotations:
          description: Download speed is below 75 percent of 1Gbps (750Mbps) on server2

      - alert: LowUploadSpeedServer2
        expr: librespeed_upload{server="server2"} < 750
        for: 120m
        labels:
          severity: warning
        annotations:
          description: Upload speed is below 75 percent of 1Gbps (750Mbps) on server2
```


## Example Metrics
With `USE_PUBLIC_TEST_SERVER=TRUE` and 2 custom servers, the exporter will produce the following metrics:
```
# HELP script_success Script exit status (0 = error, 1 = success).
# TYPE script_success gauge
script_success{script="librespeed"} 1
# HELP script_duration_seconds Script execution time, in seconds.
# TYPE script_duration_seconds gauge
script_duration_seconds{script="librespeed"} 137.500992
# HELP script_exit_code The exit code of the script.
# TYPE script_exit_code gauge
script_exit_code{script="librespeed"} 0
# HELP librespeed_server_info Information about the Librespeed server.
# TYPE librespeed_server_info gauge
librespeed_server_info{server="Nuremberg, Germany (4) (Hetzner)", url="http://de5.backend.librespeed.org", server_type="public"} 1
# HELP librespeed_download Download speed in Mbps.
# TYPE librespeed_download gauge
librespeed_download{server="Nuremberg, Germany (4) (Hetzner)"} 261.42
# HELP librespeed_upload Upload speed in Mbps.
# TYPE librespeed_upload gauge
librespeed_upload{server="Nuremberg, Germany (4) (Hetzner)"} 47.94
# HELP librespeed_ping Ping in ms.
# TYPE librespeed_ping gauge
librespeed_ping{server="Nuremberg, Germany (4) (Hetzner)"} 14
# HELP librespeed_jitter Jitter in ms.
# TYPE librespeed_jitter gauge
librespeed_jitter{server="Nuremberg, Germany (4) (Hetzner)"} 0.28
# HELP librespeed_bytes_received Bytes received during the test.
# TYPE librespeed_bytes_received gauge
librespeed_bytes_received{server="Nuremberg, Germany (4) (Hetzner)"} 509796192
# HELP librespeed_bytes_sent Bytes sent during the test.
# TYPE librespeed_bytes_sent gauge
librespeed_bytes_sent{server="Nuremberg, Germany (4) (Hetzner)"} 93487104
# HELP librespeed_client_info Information about the Librespeed client.
# TYPE librespeed_client_info gauge
librespeed_client_info{server="Nuremberg, Germany (4) (Hetzner)", ip="", hostname="", org=""} 1
# HELP librespeed_client_location_info Location information about the Librespeed client.
# TYPE librespeed_client_location_info gauge
librespeed_client_location_info{server="Nuremberg, Germany (4) (Hetzner)", city="", postal="", region="", country="", loc="", timezone=""} 1
# HELP librespeed_server_info Information about the Librespeed server.
# TYPE librespeed_server_info gauge
librespeed_server_info{server="server1", url="http://speedtest.example1.com/", server_type="custom"} 1
# HELP librespeed_download Download speed in Mbps.
# TYPE librespeed_download gauge
librespeed_download{server="server1"} 255.43
# HELP librespeed_upload Upload speed in Mbps.
# TYPE librespeed_upload gauge
librespeed_upload{server="server1"} 48.71
# HELP librespeed_ping Ping in ms.
# TYPE librespeed_ping gauge
librespeed_ping{server="server1"} 13
# HELP librespeed_jitter Jitter in ms.
# TYPE librespeed_jitter gauge
librespeed_jitter{server="server1"} 2.5
# HELP librespeed_bytes_received Bytes received during the test.
# TYPE librespeed_bytes_received gauge
librespeed_bytes_received{server="server1"} 498120232
# HELP librespeed_bytes_sent Bytes sent during the test.
# TYPE librespeed_bytes_sent gauge
librespeed_bytes_sent{server="server1"} 94994432
# HELP librespeed_client_info Information about the Librespeed client.
# TYPE librespeed_client_info gauge
librespeed_client_info{server="server1", ip="123.45.67.89", hostname="myhostname.com", org="My ISP GmbH"} 1
# HELP librespeed_client_location_info Location information about the Librespeed client.
# TYPE librespeed_client_location_info gauge
librespeed_client_location_info{server="server1", city="Berlin", postal="12345", region="Berlin State", country="DE", loc="42.16802,14.4209", timezone="Europe/Berlin"} 1
# HELP librespeed_server_info Information about the Librespeed server.
# TYPE librespeed_server_info gauge
librespeed_server_info{server="server2", url="http://speedtest.example2.com/", server_type="custom"} 1
# HELP librespeed_download Download speed in Mbps.
# TYPE librespeed_download gauge
librespeed_download{server="server2"} 1762.8
# HELP librespeed_upload Upload speed in Mbps.
# TYPE librespeed_upload gauge
librespeed_upload{server="server2"} 140.58
# HELP librespeed_ping Ping in ms.
# TYPE librespeed_ping gauge
librespeed_ping{server="server2"} 0
# HELP librespeed_jitter Jitter in ms.
# TYPE librespeed_jitter gauge
librespeed_jitter{server="server2"} 0.12
# HELP librespeed_bytes_received Bytes received during the test.
# TYPE librespeed_bytes_received gauge
librespeed_bytes_received{server="server2"} 3438131088
# HELP librespeed_bytes_sent Bytes sent during the test.
# TYPE librespeed_bytes_sent gauge
librespeed_bytes_sent{server="server2"} 274169856
# HELP librespeed_client_info Information about the Librespeed client.
# TYPE librespeed_client_info gauge
librespeed_client_info{server="server2", ip="", hostname="", org=""} 1
# HELP librespeed_client_location_info Location information about the Librespeed client.
# TYPE librespeed_client_location_info gauge
librespeed_client_location_info{server="server2", city="", postal="", region="", country="", loc="", timezone=""} 1
```


## Building the Docker Image

### Docker Build

In your terminal, navigate to the project directory where the Dockerfile resides and build the Docker image with the following command:

```bash
docker build -t your_image_name:tag --platform linux/amd64,linux/arm/v7,linux/arm64 .
```

By using the `--platform` option, Docker will generate a multi-platform image.

In this command:
- `-t` tags your image.
- `your_image_name` is the name you want to give to your Docker image.
- `tag` represents the version of your Docker image.
- `.` specifies that the Dockerfile is present in the current directory.

Here's an example, say you want to tag your image as `prometheus-librespeed-exporter:1.0.0`:

```bash
docker build -t prometheus-librespeed-exporter:1.0.0 --platform linux/amd64,linux/arm/v7,linux/arm64 .
```

After the build process is complete, Docker will create an image identified by your specified image name and tag.

Please replace `your_image_name` and `tag` with the appropriate image name and tag you desire.

The building process might take a few minutes, depending on your machine's capabilities. Once the build is complete, you can confirm the creation of your image with the following command:

```bash
docker images
```

Your newly created image should appear in the listed output.