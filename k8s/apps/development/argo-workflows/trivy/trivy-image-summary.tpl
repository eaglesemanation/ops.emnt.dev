{{- $critical := 0 -}}
{{- $high := 0 -}}
{{- $medium := 0 -}}
{{- $low := 0 -}}
{{- $unknown := 0 -}}

{{- range . -}}
  {{- range .Vulnerabilities -}}
    {{- if eq .Severity "CRITICAL" -}}
      {{- $critical = add $critical 1 -}}
    {{- else if eq .Severity "HIGH" -}}
      {{- $high = add $high 1 -}}
    {{- else if eq .Severity "MEDIUM" -}}
      {{- $medium = add $medium 1 -}}
    {{- else if eq .Severity "LOW" -}}
      {{- $low = add $low 1 -}}
    {{- else -}}
      {{- $unknown = add $unknown 1 -}}
    {{- end -}}
  {{- end -}}
{{- end -}}

{{ $critical }} {{ $high }} {{ $medium }} {{ $low }} {{ $unknown }}
