{{/*
Create the deployment, service, ingress, and pod disruption budget for a hauler server.
*/}}
{{- define "hauler.server" -}}
{{- $root := .root }}
{{- $cfg := .cfg }}
{{- $component := .component }}
{{- $app := printf "%s-%s" (include "hauler.fullname" $root) $component }}
{{- $rwo := eq (include "hauler.accessMode" $root) "ReadWriteOnce" }}
{{- $replicas := int (include "hauler.replicas" (dict "root" $root "cfg" $cfg)) }}
{{- $args := concat (list "store" "serve" $component "--port" (toString $cfg.port) "--directory" (include "hauler.serveDir" (dict "root" $root "component" $component)) (include "hauler.serve.skipCopyFlag" $root)) .args }}
{{- $tlsSecret := dig "tls" "secretName" "" $cfg }}
{{- $basicAuthSecret := dig "basicAuth" "secretName" "" $cfg }}
{{- if $tlsSecret }}
{{- $args = concat $args (list "--tls-cert" "/etc/hauler/tls/tls.crt" "--tls-key" "/etc/hauler/tls/tls.key") }}
{{- end }}
{{- if $basicAuthSecret }}
{{- $args = concat $args (list "--basic-auth" "/etc/hauler/auth/htpasswd") }}
{{- with (dig "basicAuth" "realm" "" $cfg) }}
{{- $args = concat $args (list (printf "--basic-auth-realm=%s" .)) }}
{{- end }}
{{- end }}
{{- range ($cfg.serveArgs | default list) }}
{{- $args = append $args (toString .) }}
{{- end }}
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ $app }}
  namespace: {{ $root.Release.Namespace }}
  labels:
    {{- include "hauler.labels" $root | nindent 4 }}
  {{- include "hauler.annotations" (dict "root" $root) | nindent 2 }}
spec:
  replicas: {{ $replicas }}
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
  selector:
    matchLabels:
      app: {{ $app }}
      {{- include "hauler.selectorLabels" $root | nindent 6 }}
  template:
    metadata:
      labels:
        app: {{ $app }}
        {{- include "hauler.selectorLabels" $root | nindent 8 }}
      annotations:
        checksum/hauler-jobs: {{ include "hauler.jobs.checksum" $root | quote }}
    spec:
      {{- include "hauler.imagePullSecrets" $root | nindent 6 }}
      serviceAccountName: {{ include "hauler.fullname" $root }}-service-account
      automountServiceAccountToken: false
      {{- include "hauler.podSecurityContext" $root | nindent 6 }}
      {{- include "hauler.scheduling" (dict "root" $root "nodeSelector" $cfg.nodeSelector "tolerations" $cfg.tolerations) | nindent 6 }}
      {{- if and (gt $replicas 1) (not $rwo) }}
      topologySpreadConstraints:
        - maxSkew: 1
          topologyKey: kubernetes.io/hostname
          whenUnsatisfiable: ScheduleAnyway
          labelSelector:
            matchLabels:
              app: {{ $app }}
      {{- end }}
      initContainers:
        {{- include "hauler.jobs.wait" $root | nindent 8 }}
      containers:
        - name: {{ $app }}
          image: {{ include "hauler.image" (dict "root" $root "image" $root.Values.hauler.image) }}
          imagePullPolicy: {{ include "hauler.imagePullPolicy" $root }}
          args:
            {{- toYaml $args | nindent 12 }}
          workingDir: /work
          env:
            {{- include "hauler.env" $root | nindent 12 }}
          ports:
            - name: http
              containerPort: {{ $cfg.port }}
          startupProbe:
            tcpSocket:
              port: http
            initialDelaySeconds: 15
            periodSeconds: 15
            failureThreshold: {{ max 3 (int ($cfg.delayStart | default 0)) }}
          readinessProbe:
            tcpSocket:
              port: http
            periodSeconds: 10
            failureThreshold: 3
          livenessProbe:
            tcpSocket:
              port: http
            periodSeconds: 15
            failureThreshold: 5
          {{- with $cfg.resources }}
          resources:
            {{- toYaml . | nindent 12 }}
          {{- end }}
          {{- include "hauler.containerSecurityContext" $root | nindent 10 }}
          volumeMounts:
            {{- include "hauler.mounts" $root | nindent 12 }}
            {{- if $tlsSecret }}
            - name: tls
              mountPath: /etc/hauler/tls
              readOnly: true
            {{- end }}
            {{- if $basicAuthSecret }}
            - name: basic-auth
              mountPath: /etc/hauler/auth
              readOnly: true
            {{- end }}
      restartPolicy: Always
      volumes:
        - name: hauler-data
          persistentVolumeClaim:
            claimName: {{ include "hauler.storeClaimName" $root }}
        - name: work
          {{- toYaml $root.Values.hauler.work | nindent 10 }}
        {{- with $tlsSecret }}
        - name: tls
          secret:
            secretName: {{ . }}
        {{- end }}
        {{- with $basicAuthSecret }}
        - name: basic-auth
          secret:
            secretName: {{ . }}
            items:
              - key: htpasswd
                path: htpasswd
        {{- end }}
{{- if $cfg.service.enabled }}
---
apiVersion: v1
kind: Service
metadata:
  name: {{ $app }}
  namespace: {{ $root.Release.Namespace }}
  labels:
    {{- include "hauler.labels" $root | nindent 4 }}
  {{- include "hauler.annotations" (dict "root" $root) | nindent 2 }}
spec:
  selector:
    app: {{ $app }}
    {{- include "hauler.selectorLabels" $root | nindent 4 }}
  ports:
    - name: {{ $app }}
      protocol: {{ $cfg.service.ports.protocol }}
      port: {{ $cfg.service.ports.port }}
      targetPort: {{ $cfg.service.ports.targetPort }}
  type: {{ $cfg.service.type }}
{{- end }}
{{- if $cfg.ingress.enabled }}
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: {{ $app }}
  namespace: {{ $root.Release.Namespace }}
  labels:
    {{- include "hauler.labels" $root | nindent 4 }}
    {{- with $cfg.ingress.labels }}
    {{- toYaml . | nindent 4 }}
    {{- end }}
  {{- include "hauler.annotations" (dict "root" $root "extra" $cfg.ingress.annotations) | nindent 2 }}
spec:
  {{- with $cfg.ingress.ingressClassName }}
  ingressClassName: {{ . }}
  {{- end }}
  rules:
  - host: {{ $cfg.ingress.hostname }}
    http:
      paths:
      - backend:
          service:
            name: {{ $app }}
            port:
              number: {{ $cfg.service.ports.port }}
        path: /
        pathType: Prefix
  {{- if $cfg.ingress.tls.enabled }}
  tls:
  - hosts:
    - {{ $cfg.ingress.hostname }}
    secretName: {{ $cfg.ingress.tls.secretName }}
  {{- end }}
{{- end }}
{{- if gt $replicas 1 }}
---
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: {{ $app }}
  namespace: {{ $root.Release.Namespace }}
  labels:
    {{- include "hauler.labels" $root | nindent 4 }}
spec:
  maxUnavailable: 1
  selector:
    matchLabels:
      app: {{ $app }}
      {{- include "hauler.selectorLabels" $root | nindent 6 }}
{{- end }}
{{- end }}
