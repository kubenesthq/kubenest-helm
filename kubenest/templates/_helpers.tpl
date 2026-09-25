{{/*
Expand the name of the chart.
*/}}
{{- define "kubenest.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Fully qualified app name, truncated to 63 chars.
*/}}
{{- define "kubenest.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Chart label.
*/}}
{{- define "kubenest.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels.
*/}}
{{- define "kubenest.labels" -}}
helm.sh/chart: {{ include "kubenest.chart" . }}
app.kubernetes.io/part-of: kubenest
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Backend hostname, published by the chart's Gateway.
*/}}
{{- define "kubenest.backend.host" -}}
{{- printf "api.%s" .Values.domain }}
{{- end }}

{{/*
Hub hostname, published by the chart's Gateway.
*/}}
{{- define "kubenest.hub.host" -}}
{{- printf "hub.%s" .Values.domain }}
{{- end }}

{{/*
UI hostname, published by the chart's Gateway.
*/}}
{{- define "kubenest.ui.host" -}}
{{- printf "app.%s" .Values.domain }}
{{- end }}

{{/*
PostgreSQL host.
*/}}
{{- define "kubenest.postgresql.host" -}}
{{- printf "%s-postgresql" .Release.Name }}
{{- end }}

{{/*
Redis host.
*/}}
{{- define "kubenest.redis.host" -}}
{{- printf "%s-redis-master" .Release.Name }}
{{- end }}

{{/*
Database URL.
*/}}
{{- define "kubenest.database.url" -}}
{{- printf "postgresql+asyncpg://%s:%s@%s:5432/%s" .Values.postgresql.auth.username .Values.postgresql.auth.password (include "kubenest.postgresql.host" .) .Values.postgresql.auth.database }}
{{- end }}

{{/*
Resolve a component image reference, preferring an immutable digest.

WHY A DIGEST PATH EXISTS AT ALL. Until this was added the chart could render
only `repository:tag`, so "which build is this control plane running" was
unanswerable BY CONSTRUCTION rather than by omission — there was no field in
which the answer could be written, whatever anyone set. That is a different
defect from a bad default, and replacing `latest` with a version tag would not
have fixed it: tags are mutable, and this project has been bitten by that three
times (the provisioner's mutable operator tag, the hub image carrying no source
revision, and this chart).

Digest WINS over tag when both are set. Keep both anyway: the tag is what a
human reads, the digest is what Kubernetes resolves. They must move together —
a tag that disagrees with its digest is a comment that lies.

Usage: {{ include "kubenest.image" .Values.backend.image }}
*/}}
{{- define "kubenest.image" -}}
{{- if .digest -}}
{{- printf "%s@%s" .repository .digest -}}
{{- else -}}
{{- printf "%s:%s" .repository .tag -}}
{{- end -}}
{{- end }}

{{/*
The environment every control-plane checkpoint container gets: the database,
the object store, the recipient, and the stamps the backend puts on a Job it
derives from this CronJob (kn-t47).

ONE DEFINITION because the backend creates a Job from THIS pod template. If the
env were written per container, a Job the backend created could differ from a
Job the schedule created, and the difference would only show up during a
recovery.

EVERY CONTAINER GETS ALL OF IT because every stage of the entrypoint
(app/services/checkpoint_runner.py) resolves the same request from the
environment: the fetch stage needs the bucket and the object store, the
restore stage needs the database, and the verify stage needs the namespace it
publishes the drill's result into.
*/}}
{{- define "kubenest.checkpoint.env" -}}
- name: POSTGRES_SERVER
  value: {{ include "kubenest.postgresql.host" . | quote }}
- name: POSTGRES_USER
  value: {{ .Values.postgresql.auth.username | quote }}
- name: POSTGRES_DB
  value: {{ .Values.postgresql.auth.database | quote }}
- name: POSTGRES_PORT
  value: "5432"
- name: PGPASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ .Release.Name }}-postgresql
      key: password
# The SERVER image, recorded in every checkpoint's manifest: a restore into a
# different Postgres major is refused rather than attempted (T4.8), and the
# client in the backend image that dumped it must be this major's too.
- name: POSTGRES_IMAGE
  value: {{ include "kubenest.image" .Values.postgresql.image | quote }}
# The checkpoint Job must never write to the schema it is dumping. `command`
# on every checkpoint container replaces the image's entrypoint, so this is
# already true; it is set here because the one thing this Job must not do is
# migrate a database that is being restored from, and a belt is cheaper than
# an explanation of why the braces were unnecessary.
- name: MIGRATE_ON_START
  value: "false"
# REQUIRED, and here rather than on one container: the recipient is the PUBLIC
# half of the fleet key, so every stage may hold it, and every stage builds a
# request from this environment.
- name: CHECKPOINT_RECIPIENT
  value: {{ required "checkpoint.recipient is required: it is the fleet recipient's age public key, and a checkpoint nobody can open is not a recovery point" .Values.checkpoint.recipient | quote }}
- name: KUBENEST_NAMESPACE
  valueFrom:
    fieldRef:
      fieldPath: metadata.namespace
- name: KUBENEST_MANAGEMENT_CLUSTER_ID
  value: {{ .Values.backend.managementClusterId | quote }}
- name: CONTROL_PLANE_VERSION
  value: {{ .Chart.AppVersion | quote }}
- name: CHECKPOINT_BUCKET
  value: {{ required "checkpoint.bucket is required: the control-plane checkpoints need their own bucket" .Values.checkpoint.bucket | quote }}
- name: CHECKPOINT_PREFIX
  value: {{ .Values.checkpoint.prefix | quote }}
# The two stamps the backend overrides on a Job it creates. The scheduled run
# uses these: a nightly checkpoint covers security changes only as far as its
# own manifest says, and it claims none.
- name: CHECKPOINT_REASON
  value: "nightly"
- name: CHECKPOINT_RETENTION_SECONDS
  value: {{ mul .Values.checkpoint.retentionHours 3600 | quote }}
- name: CHECKPOINT_SECURITY_CHANGE_AT
  value: ""
- name: AWS_ACCESS_KEY_ID
  valueFrom:
    secretKeyRef:
      name: {{ .Values.checkpoint.credentialsSecret }}
      key: AWS_ACCESS_KEY_ID
- name: AWS_SECRET_ACCESS_KEY
  valueFrom:
    secretKeyRef:
      name: {{ .Values.checkpoint.credentialsSecret }}
      key: AWS_SECRET_ACCESS_KEY
- name: AWS_DEFAULT_REGION
  valueFrom:
    secretKeyRef:
      name: {{ .Values.checkpoint.credentialsSecret }}
      key: AWS_DEFAULT_REGION
      optional: true
- name: AWS_ENDPOINT_URL
  valueFrom:
    secretKeyRef:
      name: {{ .Values.checkpoint.credentialsSecret }}
      key: AWS_ENDPOINT_URL
      optional: true
{{- end }}

{{/*
Where a checkpoint container keeps its scratch space. The script and scratch
volumes are the SAME everywhere, so this is shared even though the claim name
differs per CronJob.
*/}}
{{- define "kubenest.checkpoint.mounts" -}}
- name: scripts
  mountPath: /scripts
  readOnly: true
- name: scratch
  mountPath: /scratch
{{- end }}
