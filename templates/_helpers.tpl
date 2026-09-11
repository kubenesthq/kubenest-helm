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
Backend hostname.
*/}}
{{- define "kubenest.backend.host" -}}
{{- if .Values.backend.ingress.host }}
{{- .Values.backend.ingress.host }}
{{- else }}
{{- printf "api.%s" .Values.domain }}
{{- end }}
{{- end }}

{{/*
Hub hostname.
*/}}
{{- define "kubenest.hub.host" -}}
{{- if .Values.hub.ingress.host }}
{{- .Values.hub.ingress.host }}
{{- else }}
{{- printf "hub.%s" .Values.domain }}
{{- end }}
{{- end }}

{{/*
UI hostname.
*/}}
{{- define "kubenest.ui.host" -}}
{{- if .Values.ui.ingress.host }}
{{- .Values.ui.ingress.host }}
{{- else }}
{{- printf "app.%s" .Values.domain }}
{{- end }}
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

Mirrors kubenest-operator.image in the kubenest-operator-2 chart, deliberately,
so the two charts answer the same question the same way.

Usage: {{ include "kubenest.image" .Values.backend.image }}
*/}}
{{- define "kubenest.image" -}}
{{- if .digest -}}
{{- printf "%s@%s" .repository .digest -}}
{{- else -}}
{{- printf "%s:%s" .repository .tag -}}
{{- end -}}
{{- end }}
