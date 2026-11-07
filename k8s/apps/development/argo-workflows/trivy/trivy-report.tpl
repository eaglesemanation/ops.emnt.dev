{{- $critical := 0 -}}
{{- $high := 0 -}}
{{- $medium := 0 -}}
{{- $low := 0 -}}
{{- $unknown := 0 -}}
{{- $sections := 0 -}}
{{- range . -}}
  {{- if or .Vulnerabilities .Misconfigurations -}}
    {{- $sections = add $sections 1 -}}
  {{- end -}}
  {{- range .Vulnerabilities -}}
    {{- if eq .Vulnerability.Severity "CRITICAL" -}}{{- $critical = add $critical 1 -}}
    {{- else if eq .Vulnerability.Severity "HIGH" -}}{{- $high = add $high 1 -}}
    {{- else if eq .Vulnerability.Severity "MEDIUM" -}}{{- $medium = add $medium 1 -}}
    {{- else if eq .Vulnerability.Severity "LOW" -}}{{- $low = add $low 1 -}}
    {{- else -}}{{- $unknown = add $unknown 1 -}}
    {{- end -}}
  {{- end -}}
  {{- range .Misconfigurations -}}
    {{- if eq .Severity "CRITICAL" -}}{{- $critical = add $critical 1 -}}
    {{- else if eq .Severity "HIGH" -}}{{- $high = add $high 1 -}}
    {{- else if eq .Severity "MEDIUM" -}}{{- $medium = add $medium 1 -}}
    {{- else if eq .Severity "LOW" -}}{{- $low = add $low 1 -}}
    {{- else -}}{{- $unknown = add $unknown 1 -}}
    {{- end -}}
  {{- end -}}
{{- end -}}
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>@@TITLE@@</title>
  <style>
    body {
      font-family: sans-serif;
      margin: 0;
      color: #222;
    }
    .topbar {
      position: sticky;
      top: 0;
      z-index: 10;
      padding: 0.5rem 1rem;
      background: #fff;
      border-bottom: 1px solid #ddd;
    }
    .topbar a { text-decoration: none; font-weight: bold; }
    main {
      max-width: 100rem;
      margin: 0 auto;
      padding: 0 1rem 3rem;
    }
    h1 { margin-bottom: 0.25rem; }
    .meta { color: #666; margin-top: 0; }

    .chips { display: flex; flex-wrap: wrap; gap: 0.5rem; margin: 1rem 0; }
    .chip {
      border: 1px solid currentColor;
      border-radius: 0.4rem;
      padding: 0.25rem 0.7rem;
      font-weight: bold;
      font-variant-numeric: tabular-nums;
    }
    .chip.zero { color: #aaa; font-weight: normal; }

    .severity { font-weight: bold; }
    .severity-LOW, .chip-LOW { color: #398a20; }
    .severity-MEDIUM, .chip-MEDIUM { color: #a58b00; }
    .severity-HIGH, .chip-HIGH { color: #d66b00; }
    .severity-CRITICAL, .chip-CRITICAL { color: #c00; }
    .severity-UNKNOWN, .chip-UNKNOWN { color: #777; }
    .chip.zero { color: #aaa; }

    .toc { columns: 28rem; column-gap: 2rem; padding-left: 1.2rem; }
    .toc li { margin: 0.2rem 0; overflow-wrap: anywhere; break-inside: avoid; }
    .toc .count { color: #666; }

    section {
      margin: 2.5rem 0 0;
      padding-top: 0.75rem;
      border-top: 3px solid #ddd;
    }
    section h2 {
      margin: 0 0 0.4rem;
      font-size: 1.2rem;
      overflow-wrap: anywhere;
    }
    section h3 { margin: 1rem 0 0.4rem; font-size: 1rem; color: #444; }
    .badge {
      display: inline-block;
      margin-right: 0.4rem;
      padding: 0.1rem 0.5rem;
      border-radius: 0.3rem;
      background: #eee;
      color: #555;
      font-size: 0.8rem;
    }

    table {
      border-collapse: collapse;
      width: 100%;
      font-size: 0.9rem;
    }
    th, td {
      border: 1px solid #ccc;
      padding: 0.35rem 0.5rem;
      text-align: left;
      vertical-align: top;
    }
    th { background: #eee; }
    td.wrap { overflow-wrap: anywhere; }
    td.nowrap { white-space: nowrap; }
    .resolution { margin-top: 0.3rem; color: #555; font-size: 0.85em; }
    .empty { margin-top: 2rem; }
  </style>
</head>
<body>
  <nav class="topbar"><a href="index.html">&larr; Back</a></nav>
  <main>
  <h1>@@TITLE@@</h1>
  <p class="meta">{{ now.UTC.Format "2006-01-02 15:04 UTC" }}</p>

  {{- if eq $sections 0 }}
  <p class="empty">No findings.</p>
  {{- else }}

  <div class="chips">
    <span class="chip chip-CRITICAL{{ if eq $critical 0 }} zero{{ end }}">Critical: {{ $critical }}</span>
    <span class="chip chip-HIGH{{ if eq $high 0 }} zero{{ end }}">High: {{ $high }}</span>
    <span class="chip chip-MEDIUM{{ if eq $medium 0 }} zero{{ end }}">Medium: {{ $medium }}</span>
    <span class="chip chip-LOW{{ if eq $low 0 }} zero{{ end }}">Low: {{ $low }}</span>
    <span class="chip chip-UNKNOWN{{ if eq $unknown 0 }} zero{{ end }}">Unknown: {{ $unknown }}</span>
  </div>

  <h2>Files with findings ({{ $sections }})</h2>
  <ul class="toc">
    {{- range $i, $r := . }}
    {{- if or $r.Vulnerabilities $r.Misconfigurations }}
    <li><a href="#r{{ $i }}">{{ escapeXML $r.Target }}</a>
      <span class="count">({{ add (len $r.Vulnerabilities) (len $r.Misconfigurations) }})</span></li>
    {{- end }}
    {{- end }}
  </ul>

  {{- range $i, $r := . }}
  {{- if or $r.Vulnerabilities $r.Misconfigurations }}
  <section id="r{{ $i }}">
    <h2>{{ escapeXML $r.Target }}</h2>
    <div>
      {{- if $r.Type }}<span class="badge">{{ escapeXML (toString $r.Type) }}</span>{{ end }}
      {{- if $r.Class }}<span class="badge">{{ escapeXML (toString $r.Class) }}</span>{{ end }}
    </div>

    {{- if $r.Vulnerabilities }}
    <h3>Vulnerabilities ({{ len $r.Vulnerabilities }})</h3>
    <table>
      <thead>
        <tr>
          <th>Package</th>
          <th>Vulnerability</th>
          <th>Severity</th>
          <th>Installed</th>
          <th>Fixed</th>
          <th>Title</th>
        </tr>
      </thead>
      <tbody>
        {{- range $r.Vulnerabilities }}
        <tr>
          <td class="wrap">{{ escapeXML .PkgName }}</td>
          <td class="nowrap">
            {{- if .PrimaryURL }}<a href="{{ escapeXML .PrimaryURL }}" target="_blank" rel="noopener">{{ escapeXML .VulnerabilityID }}</a>
            {{- else }}{{ escapeXML .VulnerabilityID }}{{ end -}}
          </td>
          <td class="severity severity-{{ escapeXML .Vulnerability.Severity }}">{{ escapeXML .Vulnerability.Severity }}</td>
          <td class="wrap">{{ escapeXML .InstalledVersion }}</td>
          <td class="wrap">{{ escapeXML .FixedVersion }}</td>
          <td class="wrap">{{ escapeXML .Vulnerability.Title }}</td>
        </tr>
        {{- end }}
      </tbody>
    </table>
    {{- end }}

    {{- if $r.Misconfigurations }}
    <h3>Misconfigurations ({{ len $r.Misconfigurations }})</h3>
    <table>
      <thead>
        <tr>
          <th>ID</th>
          <th>Check</th>
          <th>Severity</th>
          <th>Lines</th>
          <th>Message</th>
        </tr>
      </thead>
      <tbody>
        {{- range $r.Misconfigurations }}
        <tr>
          <td class="nowrap">
            {{- if .PrimaryURL }}<a href="{{ escapeXML .PrimaryURL }}" target="_blank" rel="noopener">{{ escapeXML .ID }}</a>
            {{- else }}{{ escapeXML .ID }}{{ end -}}
          </td>
          <td class="wrap">{{ escapeXML .Title }}</td>
          <td class="severity severity-{{ escapeXML .Severity }}">{{ escapeXML .Severity }}</td>
          <td class="nowrap">
            {{- if .CauseMetadata.StartLine }}{{ .CauseMetadata.StartLine }}
              {{- if ne .CauseMetadata.EndLine .CauseMetadata.StartLine }}&ndash;{{ .CauseMetadata.EndLine }}{{ end }}
            {{- end -}}
          </td>
          <td class="wrap">
            {{ escapeXML .Message }}
            {{- if .Resolution }}
            <div class="resolution">{{ escapeXML .Resolution }}</div>
            {{- end }}
          </td>
        </tr>
        {{- end }}
      </tbody>
    </table>
    {{- end }}
  </section>
  {{- end }}
  {{- end }}
  {{- end }}
  </main>
</body>
</html>
