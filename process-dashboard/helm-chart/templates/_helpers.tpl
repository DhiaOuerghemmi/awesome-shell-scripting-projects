{{/*
Return the chart name (short)
*/}}
{{- define "process-dashboard.name" -}}
process-dashboard
{{- end -}}

{{/*
Return the full release name (e.g., "<release>-process-dashboard")
*/}}
{{- define "process-dashboard.fullname" -}}
{{ include "process-dashboard.name" . }}-{{ .Release.Name }}
{{- end -}}

{{/*
ServiceAccountName (optional; not used yet)
*/}}
{{- define "process-dashboard.serviceAccountName" -}}
{{ include "process-dashboard.fullname" . }}-sa
{{- end -}}
