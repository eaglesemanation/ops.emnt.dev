<!doctype html>
<html>
<head>
  <meta charset="utf-8">
  <title>Trivy Image Report</title>
  <style>
    body {
      font-family: sans-serif;
      margin: 2rem auto;
      padding: 0 1rem;
      max-width: 100rem;
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
    }
    th { background: #eee; }
    .severity { font-weight: bold; }
    .severity-LOW { color: #398a20; }
    .severity-MEDIUM { color: #a58b00; }
    .severity-HIGH { color: #d66b00; }
    .severity-CRITICAL { color: #c00; }
    .severity-UNKNOWN { color: #777; }
    td.pkg-name { overflow-wrap: anywhere; }
  </style>
</head>
<body>
  <h1>Trivy Image Report</h1>

  {{- if not . }}
  <p>No results returned.</p>
  {{- end }}

  {{- range . }}
  <h2>{{ escapeXML .Target }}</h2>

  {{- if .Vulnerabilities }}
  <table>
    <thead>
      <tr>
        <th>Package</th>
        <th>Vulnerability</th>
        <th>Severity</th>
        <th>Installed</th>
        <th>Fixed</th>
      </tr>
    </thead>
    <tbody>
      {{- range .Vulnerabilities }}
      <tr>
        <td class="pkg-name">{{ escapeXML .PkgName }}</td>
        <td>{{ escapeXML .VulnerabilityID }}</td>
        <td class="severity severity-{{ escapeXML .Vulnerability.Severity }}">
          {{ escapeXML .Vulnerability.Severity }}
        </td>
        <td>{{ escapeXML .InstalledVersion }}</td>
        <td>{{ escapeXML .FixedVersion }}</td>
      </tr>
      {{- end }}
    </tbody>
  </table>
  {{- else }}
  <p>No vulnerabilities found.</p>
  {{- end }}
  {{- end }}
</body>
</html>
