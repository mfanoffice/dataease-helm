{{/* Allow KubeVersion to be overridden. */}}
{{- define "dataease.kubeVersion" -}}
  {{- default .Capabilities.KubeVersion.Version .Values.kubeVersionOverride -}}
{{- end -}}
{{/* Get Ingress API Version */}}
{{- define "dataease.ingress.apiVersion" -}}
  {{- if .Capabilities.APIVersions.Has "networking.k8s.io/v1" -}}
    {{- print "networking.k8s.io/v1" -}}
  {{- else -}}
    {{- print "extensions/v1beta1" -}}
  {{- end -}}
{{- end -}}
