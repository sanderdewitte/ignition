# Ignition

Human readable Butane Configs that can be translated into machine readable Ignition Configs using make and the coreos/butane Docker container. In addition, the mikefarah/yq YAML processor Docker container is used for merging specified Butane Configs into one before translating into an Ignition Config.

## Requirements
- make (tested with GNU Make 4.2.1)
- awk (tested with GNU Awk 5.0.1)
- docker (tested with Docker 20.10.12)

## How to use

1. `git clone https://github.com/sanderdewitte/ignition.git`
1. `cd ./ignition`
1. `make BUTANE=<BUTANE file name>`
1. Put resulting Ignition file (.ign) to `Ignition config-data / user-data` property or serve it with an HTTP server
1. `make clean BUTANE=<BUTANE file name>`
