{{/*
Chart name, truncated to 63 chars.
*/}}
{{- define "devops-api.name" -}}
{{- .Chart.Name | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Fully qualified app name: release-chart, truncated to 63 chars.
*/}}
{{- define "devops-api.fullname" -}}
{{- printf "%s-%s" .Release.Name .Chart.Name | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels applied to every resource.
*/}}
{{- define "devops-api.labels" -}}
app: {{ include "devops-api.name" . }}
app.kubernetes.io/name: {{ include "devops-api.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Values.image.tag | default .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" }}
{{- end }}

{{/*
Selector labels used by Deployments and Services.
*/}}
{{- define "devops-api.selectorLabels" -}}
app: {{ include "devops-api.name" . }}
app.kubernetes.io/name: {{ include "devops-api.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}
