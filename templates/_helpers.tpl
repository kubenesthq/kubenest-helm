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
