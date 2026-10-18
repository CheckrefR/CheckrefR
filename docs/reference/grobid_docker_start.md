# Start the GROBID container via Docker

Launches a GROBID container in the background after checking that Docker
is installed and operational. If the Docker daemon is not started, an
automatic startup attempt is performed. The function then waits for the
service to be ready via an HTTP health check.

## Usage

``` r
grobid_docker_start(
  docker_image = .checkrefr_env$docker_image,
  grobid_version = .checkrefr_env$grobid_version,
  model_type = .checkrefr_env$grobid_model_type,
  port = .checkrefr_env$docker_port,
  max_ram = "4g",
  pull = FALSE,
  timeout_ready = .checkrefr_env$timeout,
  verbose = TRUE
)
```

## Arguments

- docker_image:

  `character(1)` Base of the Docker image to use. Default: value of
  `.checkrefr_env$docker_image`. Default: "lfoppiano/grobid:"

- grobid_version:

  `character(1)` GROBID version. Default: value of
  `.checkrefr_env$grobid_version`. Default: "0.9.0".

- model_type:

  `character(1)` or `NULL`. GROBID model variant:

  - `NULL` or `""` (default) – no variant specified, the image is used
    without a suffix (`{version}`), historical behavior.

  - `"full"` – image including the Deep Learning and CRF models. Docker
    tag convention: `{version}-full`.

  - `"crf"` – CRF-only image. Docker tag convention: `{version}-crf`.

  See <https://grobid.readthedocs.io/en/latest/Grobid-docker/>. Default:
  `.checkrefr_env$grobid_model_type`.

- port:

  `integer(1)` Local port to expose. Default: `8070`.

- max_ram:

  `character(1)` Memory limit for the container. Default: `"4g"`.

- pull:

  `logical(1)` Force downloading of the image. Default: `FALSE`.

- timeout_ready:

  `integer(1)` Max seconds to wait for GROBID. Default: `120`.

- verbose:

  `logical(1)` Display progress messages. Default: `TRUE`.

## Value

`invisible(TRUE)` if the container started and GROBID is responding.

## Details

The function performs the following steps in order:

1.  Checking that Docker is installed on the system.

2.  Checking that the Docker daemon is running. If not, an automatic
    startup attempt is performed via `.start_docker()`.

3.  Checking that the requested port is free.

4.  Optional download of the Docker image (`pull = TRUE`).

5.  Launching the container in the background.

6.  Waiting for the GROBID service to respond (HTTP health check).

7.  Updating the package's internal environment variables.

## See also

[`grobid_docker_check()`](https://CheckrefR.github.io/CheckrefR/reference/grobid_docker_check.md)
for a simple Docker diagnostic,
[`grobid_remote_connect()`](https://CheckrefR.github.io/CheckrefR/reference/grobid_remote_connect.md)
to connect to a remote server.

## Examples

``` r
if (FALSE) { # \dontrun{
grobid_docker_start()
grobid_docker_start(grobid_version = "0.8.1", port = 8080)
grobid_docker_start(pull = TRUE, max_ram = "8g")
} # }
```
