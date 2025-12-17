# Hauler Helm Chart

---

| Type        | Chart Version | App Version |
| ----------- | ------------- | ----------- |
| application | `2.1.2`       | `1.3.2`     |

## Installing the Chart

### Helm Install via Repository

```bash
helm repo add hauler-helm https://hauler-dev.github.io/hauler-helm
helm upgrade -i hauler hauler-helm/hauler -n hauler-system -f values.yaml
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

## Helm Chart Deployment Status

```bash
helm status hauler -n hauler-system
```

## Uninstalling the Chart

```bash
helm delete hauler -n hauler-system
```
