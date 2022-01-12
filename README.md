# Ignition

Ignition files, for instance for Fedore CoreOS

## How to use

1. `git clone https://github.com/sanderdewitte/ignition.git`
1. `cd ./ignition`
1. `make FCC=<FCC file name>`
1. Put `ignition.ign.b64` to `Ignition config-data / user-data` property or serve `ignition.ign` with a HTTP server
