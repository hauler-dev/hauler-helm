# Hauler Helm Chart

| Type        | Chart Version | App Version |
| ----------- | ------------- | ----------- |
| application | `3.0.0`       | `2.2.0`     |

## Installing the Chart

### Helm Install via Repository

```bash
helm repo add hauler-helm https://hauler-dev.github.io/hauler-helm
helm upgrade -i hauler hauler-helm/hauler-helm -n hauler-system --create-namespace -f values.yaml
```

### Helm Install via Registry

#### via GitHub Container Registry

```bash
helm upgrade -i hauler oci://ghcr.io/hauler-dev/hauler-helm -n hauler-system -f values.yaml
```

#### via DockerHub Container Registry

```bash
helm upgrade -i hauler oci://docker.io/hauler/hauler-helm -n hauler-system -f values.yaml
```

## Configuration

The chart deploys the hauler store (`hauler-data`), the hauler jobs that load it from remote and local hauls and manifests, and the hauler registry, fileserver, and git servers. See the chart's README.md for examples, and values.yaml for every option.

2.x values files are still accepted, but some keys are now ignored... see "Upgrading from 2.x" in the chart's README.md for what changed in 3.0.0.

## Helm Chart Deployment Status

```bash
helm status hauler -n hauler-system
```

## Uninstalling the Chart

```bash
helm delete hauler -n hauler-system
```
