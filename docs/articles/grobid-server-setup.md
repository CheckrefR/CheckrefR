# GROBID Server Setup and Administration

## Introduction

The [Get
started](https://CheckrefR.github.io/CheckrefR/articles/get-started.md)
page presents the quick start for GROBID. This page goes further: it
details **how to configure, control and monitor the GROBID server** used
by CheckrefR, whether it runs on your machine (local mode, via Docker)
or elsewhere (remote mode).

It follows the logical order of a working session:

1.  **Choose a model**: `crf` or `full`;
2.  **Choose where GROBID runs**: locally with
    [`grobid_docker_start()`](https://CheckrefR.github.io/CheckrefR/reference/grobid_docker_start.md)
    (after optionally checking the available versions with
    [`grobid_docker_list_versions()`](https://CheckrefR.github.io/CheckrefR/reference/grobid_docker_list_versions.md)),
    or remotely with
    [`grobid_remote_connect()`](https://CheckrefR.github.io/CheckrefR/reference/grobid_remote_connect.md);
3.  **Check the server status** with
    [`grobid_server_info()`](https://CheckrefR.github.io/CheckrefR/reference/grobid_server_info.md);
4.  **Stop the local server** with
    [`grobid_docker_stop()`](https://CheckrefR.github.io/CheckrefR/reference/grobid_docker_stop.md);
5.  **Save your settings for the session** with
    [`checkrefr_set_defaults()`](https://CheckrefR.github.io/CheckrefR/reference/checkrefr_set_defaults.md),
    and **reset** them with
    [`checkrefr_env_reset()`](https://CheckrefR.github.io/CheckrefR/reference/checkrefr_env_reset.md).

**Reminder.** These functions are not required for everyday use:
[`grobid_process_file()`](https://CheckrefR.github.io/CheckrefR/reference/grobid_process_file.md)
and
[`grobid_process_files()`](https://CheckrefR.github.io/CheckrefR/reference/grobid_process_files.md)
automatically start or join a server based on the `mode` and
`model_type` arguments. The functions on this page are meant to
**fine-tune** the configuration and to **control** the server status.

## Choosing a model: `crf` or `full`

GROBID is distributed in two main variants, which differ in the machine
learning technique used to analyze documents.

| Model | Principle | Advantages | Constraints |
|:---|:---|:---|:---|
| `crf` | Classical statistical model (*Conditional Random Fields*) | **Faster** and **lighter** | Generally **less accurate** |
| `full` | Combines the CRF model and neural models (*deep learning*) | Generally **more accurate** | **Slower** and **more resource-intensive** (memory, computing time) |

The choice is made with the `model_type` argument (`"crf"` or `"full"`),
available in
[`grobid_docker_start()`](https://CheckrefR.github.io/CheckrefR/reference/grobid_docker_start.md),
[`grobid_remote_connect()`](https://CheckrefR.github.io/CheckrefR/reference/grobid_remote_connect.md),
[`grobid_process_file()`](https://CheckrefR.github.io/CheckrefR/reference/grobid_process_file.md)
and
[`grobid_process_files()`](https://CheckrefR.github.io/CheckrefR/reference/grobid_process_files.md).
If you do not set it, the behavior depends on the mode:

- **locally**, the standard Docker image (without suffix) is used;
- **remotely**, the `crf` demo server is used.

**Learn more.** The differences between models, and how to configure
them on the GROBID side, are described in the official documentation:

- [GROBID with
  Docker](https://grobid.readthedocs.io/en/latest/Grobid-docker/);
- [Configuration via YAML
  file](https://grobid.readthedocs.io/en/latest/Grobid-docker/#configure-using-the-yaml-config-file);
- [GROBID
  service](https://grobid.readthedocs.io/en/latest/Grobid-service/).

## Local mode: Docker

### Listing available versions: `grobid_docker_list_versions()`

Before choosing a GROBID version, you can list the ones published on
**Docker Hub**, the platform that hosts the images. This function does
**not** require Docker to be installed: it simply queries the website
over the Internet.

``` r

versions <- grobid_docker_list_versions(verbose = TRUE)
#> ℹ Retrieving tags for "lfoppiano/grobid"...
#> 
#> ── Available GROBID Docker versions ────────────────────────────────────────────
#> ℹ Repository: "lfoppiano/grobid"
#> • latest-crf | 518 MB | 2026-10-18
#> • latest-develop | 518 MB | 2026-10-18
#> • buildcache | 16365 MB | 2026-10-16
#> • latest-full | 11058 MB | 2026-10-16
#> • dev-footnotes-refs | 11071 MB | 2026-09-30
#> • latest-full-pytorch | 9448 MB | 2026-08-24
#> • 0.9.1-full | 14823 MB | 2026-08-04
#> • 0.9.1-crf | 510 MB | 2026-08-04
#> • 0.9.0-full | 10323 MB | 2026-04-12
#> • 0.9.0 | 10322 MB | 2026-04-07
#> • 0.9.0-crf | 501 MB | 2026-04-07
#> • latest-crf-grobid-align-ignore-area | 446 MB | 2026-03-16
#> • latest-onnx | 4627 MB | 2026-02-04
#> • 0.8.2.1-full | 9483 MB | 2025-12-01
#> • 0.8.2.1-crf | 410 MB | 2025-12-01
#> • dev-monographs | 423 MB | 2025-11-25
#> • 0.8.2-crf | 537 MB | 2025-08-08
#> • latest-crf-cjk | 396 MB | 2025-07-09
#> • 0.8.2-full | 9534 MB | 2025-05-12
#> • 0.8.2 | 537 MB | 2025-05-12
#> ℹ ... and 30 additional tag(s). See the return value for the full list.
#> ℹ Use `grobid_docker_start()` with `grobid_version` to choose a version.
```

The result is a table, sorted from the most recent update to the oldest:

``` r

versions |>
  head(10) |>
  kable_site(caption = "The ten most recent image versions on Docker Hub")
```

#### Data returned by the function

| Column         | Content                                           |
|:---------------|:--------------------------------------------------|
| `name`         | Tag name, for example `0.9.0-crf` or `0.9.0-full` |
| `full_size`    | Image size, in bytes                              |
| `last_updated` | Date of last update                               |
| `digest`       | Unique fingerprint of the image                   |

#### Function arguments

| Argument | Role | Default value |
|:---|:---|:---|
| `repository` | Repository to query (`namespace/image`) | Repository derived from the configured image (`lfoppiano/grobid`) |
| `page_size` | Number of tags requested per page | `100` |
| `max_pages` | Maximum number of pages retrieved | `10` |
| `verbose` | Displays a preview of the first 20 tags | `TRUE` |

``` r

# Query another repository
grobid_docker_list_versions(repository = "grobid/grobid")
```

**Reading a tag name.** Tags follow the form `{version}`,
`{version}-crf` or `{version}-full`. The suffix corresponds to the
chosen model (see the previous section). The name of the version you
select is then passed to the `grobid_version` argument of
[`grobid_docker_start()`](https://CheckrefR.github.io/CheckrefR/reference/grobid_docker_start.md).

### Starting GROBID locally: `grobid_docker_start()`

This function launches GROBID in a Docker container on your machine. It
accepts the following settings:

| Argument | Role | Default value |
|:---|:---|:---|
| `model_type` | Model: `"crf"` or `"full"` (see above) | not set (standard image) |
| `grobid_version` | GROBID version | `"0.9.0"` |
| `docker_image` | Base of the Docker image name | `"lfoppiano/grobid:"` |
| `port` | Port on your machine on which the service is available | `8070` |
| `max_ram` | Maximum memory allocated to the container (e.g. `"4g"`, `"8g"`, `"512m"`) | `"4g"` |
| `pull` | Forces the image download before launching | `FALSE` |
| `timeout_ready` | Maximum wait time (seconds) until GROBID is ready | `120` |
| `verbose` | Progress messages | `TRUE` |

``` r

# Start with default settings
grobid_docker_start()
```

``` r

# Full model, more memory
grobid_docker_start(model_type = "full", max_ram = "8g")

# Specific GROBID version, on another port
grobid_docker_start(grobid_version = "0.8.1", port = 8080)

# Force the image update
grobid_docker_start(pull = TRUE)
```

**First launch: image download.** The first time, the image matching the
requested version and model must be downloaded. This can take a while
(several GB for the `full` model). The download is **automatic** if the
image is absent from your machine, even with `pull = FALSE`. The same
download happens for **each new version/model combination** never used
before. The `pull = TRUE` argument is used to force an update of an
image that is already present.

**What the function checks and does for you**

- it checks that Docker is installed and tries to start it if it is not
  running;
- it **reuses** the already active GROBID container if its configuration
  matches (same image, version, model, port); otherwise, it **stops and
  replaces** it;
- it checks that the requested port is free;
- it waits for GROBID to respond before returning;
- it saves the configuration (address, port, version, model) for the
  session, so that the other functions use it.

**Choosing `max_ram`.** The `full` model requires more memory. If GROBID
stops or fails to start, increase this value, within the limits of what
your machine and the Docker configuration (Docker Desktop on Windows and
macOS) allow.

### Stopping GROBID locally: `grobid_docker_stop()`

When you no longer need the local server, stop it to free up memory and
the port.

``` r

grobid_docker_stop()
```

| Argument | Role |
|:---|:---|
| `container_id` | Identifier of a specific container. By default, the one started by [`grobid_docker_start()`](https://CheckrefR.github.io/CheckrefR/reference/grobid_docker_start.md); failing that, the function looks for an active GROBID container. |
| `verbose` | Progress messages. |

Since the container is launched in “disposable” mode, it is
**automatically removed** when stopped. The function returns `TRUE`
(invisibly) if the container is stopped or was already inactive, and
`FALSE` if no container was identified or if Docker is not running.

**Remote connection preserved.** If you are connected to a remote
server, stopping a leftover local container **does not remove** that
remote connection: only the configuration related to local mode is
reset.

## Remote mode: `grobid_remote_connect()`

This function tests and then stores the address of a GROBID server
accessible over the Internet. It tries the candidate addresses in order
and **keeps the first one that responds**.

**Demo servers.** If no address (`url`) is provided, CheckrefR uses
**demo** servers hosted on Hugging Face. They are shared, sometimes slow
or unavailable, and are not suitable for sensitive or large documents.
For regular use, prefer **local mode** or **your own server** (`url`).

| Argument | Role | Default value |
|:---|:---|:---|
| `url` | Address of **your own server**. If provided, it is used alone and the demo servers are ignored. | `NULL` |
| `model_type` | `"crf"` or `"full"`: selects the list of demo servers to test. | not set (treated as `crf`) |
| `timeout` | Connection timeout in seconds. Each candidate server is tested for at most 120 seconds. | `120` |
| `verbose` | Displays the tested addresses and the result. | `TRUE` |

``` r

# Demo servers, crf model
grobid_remote_connect()

# Demo servers, full model
grobid_remote_connect(model_type = "full")
```

``` r

# Your own server (recommended without Docker)
grobid_remote_connect(url = "https://my-grobid-server.example.org")
```

The demo servers tested by default are:

``` r

urls <- CheckrefR:::.checkrefr_defaults$remote_default_url

data.frame(
  Model  = rep(names(urls), lengths(urls)),
  Server = unlist(urls, use.names = FALSE)
) |>
  kable_site(caption = "Default demo servers")
```

| Model | Server                                    |
|:------|:------------------------------------------|
| crf   | <https://grobidorg-grobid.hf.space>       |
| crf   | <https://grobidorg-grobid2.hf.space>      |
| full  | <https://grobidorg-grobid-full.hf.space>  |
| full  | <https://grobidOrg-grobid-full2.hf.space> |

Default demo servers {.table .table .table-striped .table-hover
.table-condensed .table-responsive
style="font-size: 13px; width: auto !important; margin-left: auto; margin-right: auto;"}

The function returns `TRUE` (invisibly) on success, and stops with an
error listing the tested addresses if no server responds. If you are
already connected to a remote server that responds, with the same model,
the existing connection is simply reused.

**Your own server.** You can durably replace (for the session) the demo
servers with your own using
`checkrefr_set_defaults(remote_default_url = ...)` (see below). That
way,
[`grobid_remote_connect()`](https://CheckrefR.github.io/CheckrefR/reference/grobid_remote_connect.md)
and the processing functions will use your servers without having to
repeat the address.

## Monitoring the server: `grobid_server_info()`

This function displays the status of the currently configured server:
mode, address, reachability and version.

``` r

info <- grobid_server_info()
#> 
#> ── GROBID Server ───────────────────────────────────────────────────────────────
#> Mode: not configured
#> URL: -
#> Reachable: no
#> Version: unknown
#> Timeout: -
```

The result is also returned (invisibly) as a list:

| Element          | Content                                               |
|:-----------------|:------------------------------------------------------|
| `mode`           | `"docker"`, `"remote"` or `"not configured"`          |
| `url`            | Server address, or `NA`                               |
| `api_reachable`  | `TRUE` if the server responds                         |
| `grobid_version` | GROBID version returned by the server, otherwise `NA` |
| `timeout`        | Timeout used for the test, otherwise `NA`             |

``` r

str(info)
#> List of 5
#>  $ mode          : chr "not configured"
#>  $ url           : chr NA
#>  $ api_reachable : logi FALSE
#>  $ grobid_version: chr NA
#>  $ timeout       : int NA
```

**No server configured.** If no server has been started or joined yet,
the function makes no connection and returns `mode = "not configured"`.
This is the normal case at the start of a session, before any call to
[`grobid_docker_start()`](https://CheckrefR.github.io/CheckrefR/reference/grobid_docker_start.md),
[`grobid_remote_connect()`](https://CheckrefR.github.io/CheckrefR/reference/grobid_remote_connect.md)
or the processing functions.

An example of a complete sequence, in local mode:

``` r

grobid_docker_start(model_type = "crf")
grobid_server_info()   # "docker" mode, server reachable
grobid_docker_stop()
grobid_server_info()   # back to "not configured"
```

## Configuring your settings: `checkrefr_set_defaults()`

Rather than repeating the same arguments in every call,
[`checkrefr_set_defaults()`](https://CheckrefR.github.io/CheckrefR/reference/checkrefr_set_defaults.md)
lets you **change the package’s default values** for the current
session: GROBID version, port, timeouts, number of parallel processes,
validation thresholds and weights, remote server addresses, etc.

**Scope of the settings.** They are kept **only for the current R
session**. They are not saved to disk: when R is restarted, the original
values are restored. To keep your settings from one session to the next,
place the calls to
[`checkrefr_set_defaults()`](https://CheckrefR.github.io/CheckrefR/reference/checkrefr_set_defaults.md)
in your startup script (or in your `.Rprofile` file).

``` r

# A single default GROBID version, a shorter timeout
# and two parallel processes
checkrefr_set_defaults(
  grobid_version = "0.8.1",
  timeout        = 60L,
  max_workers    = 2L
)
```

The function displays the modified parameters. Called without arguments,
it applies no change and invites you to check the current state.

### Modifiable parameters

#### Connection and GROBID server

| Parameter | Role | Initial value |
|:---|:---|:---|
| `docker_image` | Base of the Docker image name | `"lfoppiano/grobid:"` |
| `grobid_version` | GROBID version | `"0.9.0"` |
| `grobid_model_type` | Default model (`"crf"`, `"full"` or `NA`) | `NA` |
| `docker_port` | Local port used in Docker mode | `"8070"` |
| `remote_default_url` | Default remote servers (`crf` and `full` lists) | demo servers |
| `timeout` | Connection timeout, in seconds | `120` |
| `max_workers` | Number of parallel processes for [`grobid_process_files()`](https://CheckrefR.github.io/CheckrefR/reference/grobid_process_files.md) | `4` |
| `grobid_email` | E-mail address associated with requests | `NA` |

**Protected parameters.** The elements that describe the **current
state** of the server (`mode`, `server_url`, `docker_container_id`) and
the identity of the package (`pkg_name`, `pkg_repo`) cannot be modified
with this function. They are managed automatically by
[`grobid_docker_start()`](https://CheckrefR.github.io/CheckrefR/reference/grobid_docker_start.md),
[`grobid_remote_connect()`](https://CheckrefR.github.io/CheckrefR/reference/grobid_remote_connect.md)
and
[`grobid_docker_stop()`](https://CheckrefR.github.io/CheckrefR/reference/grobid_docker_stop.md).

``` r

# Credentials for OpenAlex and DOI services
checkrefr_set_defaults(
  oa_api_key = "my_api_key",
  doi_email  = "me@example.com"
)
```

### Declaring your own remote servers

For `remote_default_url`, you provide a named list with the keys `crf`
and/or `full`. The addresses provided are **merged** with the existing
list (duplicates are removed):

- a simple vector of addresses **appends them to the end** of the list;
- a list named by ranks (`"1"`, `"2"`, …) **inserts them at the
  indicated position**; rank `1` places the address first, so it is
  tested before the demo servers.

``` r

# Your server tested first for the full model
checkrefr_set_defaults(
  remote_default_url = list(
    full = list("1" = "https://my-server.example.com")
  )
)

# Append to the end of the crf model list
checkrefr_set_defaults(
  remote_default_url = list(
    crf = "https://my-other-server.example.com"
  )
)
```

## Resetting your settings: `checkrefr_env_reset()`

To return to the package’s original values, use
[`checkrefr_env_reset()`](https://CheckrefR.github.io/CheckrefR/reference/checkrefr_env_reset.md).

| Argument | Role | Default value |
|:---|:---|:---|
| `fields` | Names of the parameters to reset. `NULL`: full reset. | `NULL` |
| `verbose` | Displays messages. | `TRUE` |

**Partial reset**: only the named parameters return to their original
value.

``` r

checkrefr_set_defaults(timeout = 30L, oa_min_threshold = 0.55)
#> ✔ Variable(s) updated: "timeout" and "oa_min_threshold"

checkrefr_env_reset(fields = c("timeout", "oa_min_threshold"))
#> ✔ Parameter(s) reset: "timeout" and "oa_min_threshold"
```

An unknown parameter name is ignored with a warning, while the other
names are still reset:

``` r

checkrefr_env_reset(fields = c("timeout", "nonexistent_variable"))
```

**Full reset**: all parameters return to their original value.

``` r

checkrefr_env_reset()
```

**Full reset and server state.** The full reset also clears the **server
state** (mode, address, container identifier). If a local GROBID
container is still active, the package no longer “knows” about it: stop
it **beforehand** with
[`grobid_docker_stop()`](https://CheckrefR.github.io/CheckrefR/reference/grobid_docker_stop.md),
otherwise it will keep running in the background. However,
[`grobid_docker_stop()`](https://CheckrefR.github.io/CheckrefR/reference/grobid_docker_stop.md)
is able to find an active GROBID container even without a stored
identifier.

The function invisibly returns the package’s internal environment; its
normal use is limited to the messages displayed.

## Summary

| Need | Function |
|:---|:---|
| Find out which image versions are available | [`grobid_docker_list_versions()`](https://CheckrefR.github.io/CheckrefR/reference/grobid_docker_list_versions.md) |
| Start GROBID locally and set version, model, port, memory | [`grobid_docker_start()`](https://CheckrefR.github.io/CheckrefR/reference/grobid_docker_start.md) |
| Connect to a remote server, or to your own server | [`grobid_remote_connect()`](https://CheckrefR.github.io/CheckrefR/reference/grobid_remote_connect.md) |
| Check the status of the configured server | [`grobid_server_info()`](https://CheckrefR.github.io/CheckrefR/reference/grobid_server_info.md) |
| Stop the local server | [`grobid_docker_stop()`](https://CheckrefR.github.io/CheckrefR/reference/grobid_docker_stop.md) |
| Change the default values for the session | [`checkrefr_set_defaults()`](https://CheckrefR.github.io/CheckrefR/reference/checkrefr_set_defaults.md) |
| Return to the original values | [`checkrefr_env_reset()`](https://CheckrefR.github.io/CheckrefR/reference/checkrefr_env_reset.md) |
