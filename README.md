# lets-learn-how-to/create-a-cloud-native-buildpack

This repo will take you through creating cloud native buildpacks in several languages.

## Bash

The most basic language for buildpacks, you must bring your own tools with you.

Take a look at the buildpack at [template/bash](./template/bash).

This buildpack uses the following features:

- Configuration variables
- Caching
- Environment exports

It also uses the tool [`dasel`](https://github.com/TomWright/dasel) to read and write toml data used by CNB configuration files.
