# Ignition

Human readable Butane Configs that can be translated into machine readable Ignition Configs using the coreos/butane Docker container

## Requirements
- make (GNU Make 4.2.1 or later)
- docker (Docker 20.10.12 or later)
- base64 (base64, GNU coreutils, 8.30 or later)

## How to use

1. `git clone https://github.com/sanderdewitte/ignition.git`
1. `cd ./ignition`
1. `make BUTANE=<BUTANE file name>`
1. Put `ignition.ign.b64` to `Ignition config-data / user-data` property or serve `ignition.ign` with a HTTP server
1. `make clean BUTANE=<BUTANE file name>`
