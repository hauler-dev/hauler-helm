{{/*
Expand the name of the chart.
*/}}
{{- define "hauler.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create the prefix for every resource name, defaults to "hauler".
*/}}
{{- define "hauler.fullname" -}}
{{- default "hauler" .Values.fullnameOverride | trunc 50 | trimSuffix "-" }}
{{- end }}

{{- define "hauler.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "hauler.selectorLabels" -}}
app.kubernetes.io/name: {{ include "hauler.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{- define "hauler.labels" -}}
helm.sh/chart: {{ include "hauler.chart" . }}
{{ include "hauler.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- with merge (deepCopy (default dict .Values.global.labels)) (deepCopy (default dict .Values.hauler.labels)) }}
{{ toYaml . }}
{{- end }}
{{- end }}

{{/*
Common annotations
*/}}
{{- define "hauler.annotations" -}}
{{- $all := merge (deepCopy (default dict .extra)) (deepCopy (default dict .root.Values.global.annotations)) (deepCopy (default dict .root.Values.hauler.annotations)) }}
{{- with $all }}
annotations:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- end }}

{{/*
Create the image reference, with the optional registry prefix.
*/}}
{{- define "hauler.image" -}}
{{- $tag := .image.tag | default .root.Chart.AppVersion | toString }}
{{- with .root.Values.global.imageRegistry }}
{{- printf "%s/%s:%s" (trimSuffix "/" .) $.image.repository $tag }}
{{- else }}
{{- printf "%s:%s" .image.repository $tag }}
{{- end }}
{{- end }}

{{- define "hauler.imagePullPolicy" -}}
{{- .Values.global.imagePullPolicy | default "IfNotPresent" }}
{{- end }}

{{- define "hauler.imagePullSecrets" -}}
{{- with .Values.global.imagePullSecrets }}
imagePullSecrets:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- end }}

{{- define "hauler.storeClaimName" -}}
{{- .Values.hauler.data.pvc.existingClaim | default (printf "%s-data" (include "hauler.fullname" .)) }}
{{- end }}

{{/*
Check if the chart is in ha mode.
*/}}
{{- define "hauler.ha" -}}
{{- if eq (.Values.global.mode | default "standalone") "ha" }}true{{- end }}
{{- end }}

{{/*
Create the access mode of the pvc, ReadWriteOnce for standalone and ReadWriteMany for ha, unless set.
*/}}
{{- define "hauler.accessMode" -}}
{{- .Values.hauler.data.pvc.accessModes | default (ternary "ReadWriteMany" "ReadWriteOnce" (eq (include "hauler.ha" .) "true")) }}
{{- end }}

{{/*
Create the number of replicas for a server, 1 for standalone and 3 for ha, unless set. Call with (dict "root" $ "cfg" $serverValues).
*/}}
{{- define "hauler.replicas" -}}
{{- if and (ne (toString .cfg.replicas) "") (ne (toString .cfg.replicas) "<nil>") }}
{{- .cfg.replicas | int }}
{{- else }}
{{- ternary 3 1 (eq (include "hauler.ha" .root) "true") }}
{{- end }}
{{- end }}

{{/*
Create the directory a server serves from, a copy of the store built by the hauler jobs and versioned by their checksum.
*/}}
{{- define "hauler.serveDir" -}}
{{- printf "/hauler/serve/%s/%s" (include "hauler.jobs.checksum" .root) .component }}
{{- end }}

{{/*
Create the directory the hauler jobs build a server's copy in, moved into place once every copy is built so a running server never sees a partial copy.
*/}}
{{- define "hauler.serveBuildDir" -}}
{{- printf "/hauler/serve/%s.partial/%s" (include "hauler.jobs.checksum" .root) .component }}
{{- end }}

{{/*
Hauler flag for serving a directory built by the hauler jobs, without copying the store again.
*/}}
{{- define "hauler.serve.skipCopyFlag" -}}--skip-copy{{- end }}

{{/*
Common security contexts
*/}}
{{- define "hauler.podSecurityContext" -}}
securityContext:
  runAsUser: 1001
  runAsGroup: 1001
  runAsNonRoot: true
  fsGroup: 1001
  fsGroupChangePolicy: OnRootMismatch
  seccompProfile:
    type: RuntimeDefault
{{- end }}

{{- define "hauler.containerSecurityContext" -}}
securityContext:
  allowPrivilegeEscalation: false
  readOnlyRootFilesystem: true
  capabilities:
    drop: ["ALL"]
{{- end }}

{{/*
Common hauler environment variables
*/}}
{{- define "hauler.env" -}}
{{- $g := .Values.global }}
- name: HAULER_STORE_DIR
  value: /hauler/store
- name: HAULER_DIR
  value: /hauler/state
- name: HOME
  value: /work
- name: TMPDIR
  value: /work
{{- with $g.logLevel }}
- name: HAULER_LOG_LEVEL
  value: {{ . | quote }}
{{- end }}
{{- with $g.auditLevel }}
- name: HAULER_AUDIT_LEVEL
  value: {{ . | quote }}
{{- end }}
{{- if $g.ignoreErrors }}
- name: HAULER_IGNORE_ERRORS
  value: "true"
{{- end }}
{{- with $g.retries }}
- name: HAULER_RETRIES
  value: {{ . | quote }}
{{- end }}
{{- with $g.concurrency }}
- name: HAULER_CONCURRENCY
  value: {{ . | quote }}
{{- end }}
{{- with $g.blobConcurrency }}
- name: HAULER_BLOB_CONCURRENCY
  value: {{ . | quote }}
{{- end }}
{{- end }}

{{/*
Hauler jobs sources
*/}}
{{- define "hauler.jobs.sources" -}}
{{- $j := .Values.haulerJobs | default dict }}
{{- toJson (dict
  "remoteManifests" (dig "remote" "manifests" list $j | default list)
  "remoteHauls" (dig "remote" "hauls" list $j | default list)
  "localManifests" (dig "local" "manifests" list $j | default list)
  "localHauls" (dig "local" "hauls" list $j | default list)
  "store" ($j.store | default "")
  "reset" ($j.reset | default false)
  "syncArgs" (include "hauler.stringList" ($j.syncArgs | default list) | fromJsonArray)
  "loadArgs" (include "hauler.stringList" ($j.loadArgs | default list) | fromJsonArray)) }}
{{- end }}

{{/*
Convert a list of args to strings, so numbers set with --set work.
*/}}
{{- define "hauler.stringList" -}}
{{- $out := list }}
{{- range . }}
{{- $out = append $out (toString .) }}
{{- end }}
{{- toJson $out }}
{{- end }}

{{- define "hauler.jobs.usesLocal" -}}
{{- $s := include "hauler.jobs.sources" . | fromJson }}
{{- if or $s.localManifests $s.localHauls $s.store }}true{{- end }}
{{- end }}

{{/*
Create a checksum of everything that renders into the hauler jobs, used to name the job and restart the servers when it changes. A job's pod template can't change in place, so every value it uses belongs here.
*/}}
{{- define "hauler.jobs.checksum" -}}
{{- $servers := dict }}
{{- range $component, $cfg := dict "registry" .Values.haulerRegistry "fileserver" .Values.haulerFileserver "git" .Values.haulerGit }}
{{- $_ := set $servers $component (dict "enabled" $cfg.enabled "port" $cfg.port) }}
{{- end }}
{{- toJson (dict
  "sources" (include "hauler.jobs.sources" . | fromJson)
  "jobs" (omit (.Values.haulerJobs | default dict) "remote" "local" "store" "reset" "syncArgs" "loadArgs")
  "global" (omit .Values.global "labels" "annotations")
  "image" (include "hauler.image" (dict "root" . "image" .Values.hauler.image))
  "claim" (include "hauler.storeClaimName" .)
  "accessMode" (include "hauler.accessMode" .)
  "servers" $servers
  "chart" .Chart.Version) | sha256sum | trunc 8 }}
{{- end }}

{{- define "hauler.jobs.name" -}}
{{- printf "%s-loader-%s" (include "hauler.fullname" .) (include "hauler.jobs.checksum" .) }}
{{- end }}

{{/*
Create the path of the file the hauler jobs write when complete, which the servers wait for before starting.
*/}}
{{- define "hauler.jobs.marker" -}}
{{- printf "/hauler/state/loader/loaded-%s" (include "hauler.jobs.checksum" .) }}
{{- end }}

{{/*
Common scheduling, keeps every pod on the same node when using ReadWriteOnce.
*/}}
{{- define "hauler.scheduling" -}}
{{- $root := .root }}
{{- $rwo := eq (include "hauler.accessMode" $root) "ReadWriteOnce" }}
{{- $nodeSelector := deepCopy (default (default dict $root.Values.global.nodeSelector) .nodeSelector) }}
{{- if and $root.Values.haulerJobs.localNode (eq (include "hauler.jobs.usesLocal" $root) "true") (or $rwo .isJob) }}
{{- $_ := set $nodeSelector "kubernetes.io/hostname" $root.Values.haulerJobs.localNode }}
{{- end }}
{{- with $nodeSelector }}
nodeSelector:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- with (default $root.Values.global.tolerations .tolerations) }}
tolerations:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- if $rwo }}
affinity:
  podAffinity:
    requiredDuringSchedulingIgnoredDuringExecution:
      - topologyKey: kubernetes.io/hostname
        labelSelector:
          matchLabels:
            {{- include "hauler.selectorLabels" $root | nindent 12 }}
{{- end }}
{{- end }}

{{/*
Common hauler jobs container settings
*/}}
{{- define "hauler.jobs.containerCommon" -}}
{{- $s := include "hauler.jobs.sources" . | fromJson }}
env:
  {{- include "hauler.env" . | nindent 2 }}
  {{- if .Values.haulerJobs.registryAuth }}
  - name: DOCKER_CONFIG
    value: /etc/hauler/docker
  {{- end }}
{{- with .Values.haulerJobs.resources }}
resources:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{ include "hauler.containerSecurityContext" . }}
workingDir: /work
volumeMounts:
  {{- include "hauler.mounts" . | nindent 2 }}
  {{- if .Values.haulerJobs.registryAuth }}
  - name: registry-auth
    mountPath: /etc/hauler/docker
    readOnly: true
  {{- end }}
{{- end }}

{{/*
Common mounts, the shared pvc at /hauler (the store and hauler's state) and the pod's own volume at /work (working directory and temp files).
*/}}
{{- define "hauler.mounts" -}}
- name: hauler-data
  mountPath: /hauler
- name: work
  mountPath: /work
{{- end }}

{{/*
Common init container that waits for the hauler jobs to complete.
*/}}
{{- define "hauler.jobs.wait" -}}
- name: wait-for-hauler-jobs
  image: {{ include "hauler.image" (dict "root" . "image" .Values.haulerJobs.image) }}
  imagePullPolicy: {{ include "hauler.imagePullPolicy" . }}
  command: ["/bin/sh", "-c"]
  args:
    - |
      echo "waiting for {{ include "hauler.jobs.name" . }} to complete"
      timeout {{ .Values.haulerJobs.timeout }} sh -c 'until [ -f {{ include "hauler.jobs.marker" . }} ]; do sleep 5; done'
  {{- include "hauler.containerSecurityContext" . | nindent 2 }}
  volumeMounts:
    - name: hauler-data
      mountPath: /hauler
      readOnly: true
{{- end }}
