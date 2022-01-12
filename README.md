# Ignition

Human readable Butane Configs that can be translated into machine readable Ignition Configs using the coreos/butane Docker container

## How to use

1. `git clone https://github.com/sanderdewitte/ignition.git`
1. `cd ./ignition`
1. `make BUTANE=<BUTANE file name>`
1. Put `ignition.ign.b64` to `Ignition config-data / user-data` property or serve `ignition.ign` with a HTTP server
