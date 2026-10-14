# Hauler Helm Chart

---

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
helm upgrade -i hauler oci://ghcr.io/hauler-dev/hauler-helm -n hauler-system --create-namespace -f values.yaml
```

#### via DockerHub Container Registry

```bash
helm upgrade -i hauler oci://docker.io/hauler/hauler-helm -n hauler-system --create-namespace -f values.yaml
```

## What Gets Deployed

| Resource            | Values             | Default  | Purpose                                                                        |
| ------------------- | ------------------ | -------- | ------------------------------------------------------------------------------ |
| `hauler-data`       | `hauler.data`      | always   | The hauler store (pvc), shared by every component                              |
| `hauler-loader-*`   | `haulerJobs`       | always   | Sets up the store and loads it from remote/local hauls and manifests           |
| `hauler-registry`   | `haulerRegistry`   | enabled  | `hauler store serve registry`                                                  |
| `hauler-fileserver` | `haulerFileserver` | enabled  | `hauler store serve fileserver`                                                |
| `hauler-git`        | `haulerGit`        | disabled | `hauler store serve git`... read-only, requires a git repository in the store  |
| `hauler-debug`      | `hauler.debug`     | disabled | A shell with hauler and the store mounted, for troubleshooting                 |

The hauler jobs load the store, then build one copy of it for each server on the pvc, and every replica serves that copy without copying the store again. When anything the hauler jobs use changes (their sources, images, settings, or the chart version), the jobs run again and the servers restart to pick up the new content. Upgrades that change none of these don't reload or restart anything... set `haulerJobs.revision` to any new value to rerun the jobs anyway, i.e. to pull updated content from the same remote URLs.

See [values.yaml](values.yaml) for every option and its default.

## Examples

### Load Remote and Local Content

```yaml
haulerJobs:
  localNode: node-1  # the node holding the local files
  remote:
    manifests:
      - path: https://raw.githubusercontent.com/hauler-dev/hauler/main/testdata/hauler-manifest.yaml
    hauls:
      - path: https://raw.githubusercontent.com/hauler-dev/hauler/main/testdata/haul.tar.zst
  local:
    hauls:
      - path: /opt/hauls/
        name: haul.tar.zst
```

Content is added to the existing store. Set `haulerJobs.reset: true` to empty it first.

### Airgapped Image Mirror

```yaml
global:
  imageRegistry: registry.example.com
  imagePullSecrets:
    - name: registry-credentials
```

### Registry with Basic Auth

```bash
htpasswd -Bc htpasswd admin
kubectl create secret generic registry-auth -n hauler-system --from-file=htpasswd
```

```yaml
haulerRegistry:
  basicAuth:
    secretName: registry-auth
  ingress:
    hostname: registry.example.com
    tls:
      enabled: true
      secretName: registry-tls
```

### Standalone and HA

`global.mode` sets the defaults for storage, replicas, and scheduling:

|                 | `standalone` (default)                 | `ha`                                               |
| --------------- | -------------------------------------- | -------------------------------------------------- |
| pvc             | `ReadWriteOnce`                        | `ReadWriteMany` (the storage class must support it) |
| server replicas | 1 each                                 | 3 each                                             |
| scheduling      | every pod on the node with the pvc     | spread across nodes, with a PodDisruptionBudget    |

`hauler.data.pvc.accessModes` and each server's `replicas` override the mode when set:

```yaml
global:
  mode: ha
haulerRegistry:
  replicas: 3
```

### Volumes

Every hauler container uses the same two paths:

| Path      | Volume                                                              | Contents                                                                  |
| --------- | ------------------------------------------------------------------- | ------------------------------------------------------------------------- |
| `/hauler` | `hauler-data`, the shared pvc                                       | `/hauler/store` (the store) and `/hauler/state` (hauler's own state)      |
| `/work`   | the pod's own ephemeral pvc, created and deleted with the pod       | the working directory and temporary files                                 |

The pvc holds the store and one copy of it for each server (`/hauler/serve/<checksum>/registry`, `fileserver`, and `git`), plus the previous copies while the servers roll over, so size `hauler.data.pvc.storageRequest` to about 3x the artifacts. The hauler jobs' `tmp` is their `/work`, 48Gi by default... size it to at least the largest haul. `hauler.work` is the `/work` of every server and the debug shell, 1Gi by default.

## Upgrading from 2.x

2.x values files are still accepted, and a release named `hauler` upgrades in place with the same resource names and selectors. Some 2.x keys are now ignored, as listed below. What changed:

- the hauler jobs no longer empty the store on every install and upgrade... set `haulerJobs.reset: true` for that (a `haulerJobs.store` still replaces the store's content)
- the hauler jobs are a regular Job named `hauler-loader-<checksum>` instead of a Helm hook... the old `hauler-loader` Job can be removed with `kubectl delete job hauler-loader -n hauler-system`
- the servers wait for the hauler jobs with a file on the pvc instead of `kubectl wait`, so the `rancher/kubectl` image, role, and role binding are no longer needed... `hauler.initContainers.timeout` is now `haulerJobs.timeout`
- the pvc now holds the store in `store/` and hauler's own state in `state/`... the hauler jobs move a 2.x store from the root of the pvc into `store/` on the first upgrade, so a rollback to 2.x needs the store moved back
- `imagePullPolicy` is set once with `global.imagePullPolicy`, now `IfNotPresent`... the per-image `imagePullPolicy` keys are ignored
- `hauler.labels` and `hauler.annotations` still work, and `global.labels` and `global.annotations` are the new home for them
- `delayStart` now defaults to `40`
- the servers serve copies built by the hauler jobs on the pvc, instead of copying the store into their own container when they start
- `hauler.data.pvc.accessModes` now follows `global.mode`, `ReadWriteOnce` by default... a pvc's access mode can't be changed, so a 2.x release that used the old `ReadWriteMany` default must set `global.mode: ha` or `accessModes: ReadWriteMany` to upgrade
- the servers run with a read-only root filesystem and their probes use tcp, so they also work with basic auth
- `hauler.debug.command` and `hauler.debug.args` are ignored... the debug pod always runs a shell that sleeps
- `haulerGit` is new and disabled by default
- `haulerRegistry.readonly: false` now requires a single registry replica

## Helm Chart Deployment Status

```bash
helm status hauler -n hauler-system
```

## Uninstalling the Chart

```bash
helm delete hauler -n hauler-system
```
