function parseJson(raw, fallback) {
  try { return JSON.parse(String(raw || "")) } catch (e) { return fallback }
}

function formatBandwidth(value) {
  var n = parseInt(value || 0, 10)
  if (!n) return ""
  if (n >= 1000) return (n / 1000).toFixed(n % 1000 === 0 ? 0 : 1) + " Gbit"
  return n + " Mbit"
}

function formatLoad(value) {
  var n = parseFloat(value || 0)
  if (!isFinite(n) || n <= 0) return ""
  return n.toFixed(n < 10 ? 1 : 0) + "%"
}

function modeLabel(mode) {
  if (mode === "country") return "Country"
  if (mode === "server") return "Server"
  return "Auto"
}

function filterLabel(filter) {
  if (filter === "2gbit") return "2 Gbit"
  if (filter === "20gbit") return "20 Gbit"
  return "Auto"
}

function serverSubtitle(row) {
  if (!row) return ""
  var parts = []
  if (row.country) parts.push(row.country)
  var bw = formatBandwidth(row.bandwidth)
  if (bw) parts.push(bw)
  if (row.users) parts.push(row.users + " users")
  var load = formatLoad(row.load)
  if (load) parts.push(load + " load")
  if (row.ping) parts.push(row.ping + " ms")
  return parts.join(" · ")
}

function countrySubtitle(row) {
  if (!row) return ""
  var parts = []
  if (row.servers) parts.push(row.servers + " servers")
  var bw = formatBandwidth(row.bandwidth)
  if (bw) parts.push(bw)
  if (row.users) parts.push(row.users + " users")
  var load = formatLoad(row.load)
  if (load) parts.push(load + " load")
  return parts.join(" · ")
}
