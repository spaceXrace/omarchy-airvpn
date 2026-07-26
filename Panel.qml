import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model

Panel {
  id: root
  moduleName: "local.airvpn"
  ipcTarget: "local.airvpn"

  property bool connected: false
  property bool depsInstalled: false
  property bool hasApiKey: false
  property bool busy: false
  property bool showSettings: false
  property string statusText: "Checking..."
  property string errorText: ""
  property string currentServer: ""
  property string currentDevice: ""
  property string apiKeyText: ""
  property string deviceText: ""
  property string mode: "auto"
  property string filter: "auto"
  property string selectedCountry: ""
  property string selectedCountryName: ""
  property string selectedServer: ""
  property var countries: []
  property var servers: []
  property int listIndex: 0

  readonly property string helper: Quickshell.env("HOME") + "/.config/omarchy/plugins/local.airvpn/bin/omarchy-airvpn"
  readonly property var modes: ["auto", "country", "server"]
  readonly property var filters: ["auto", "2gbit", "20gbit"]
  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color dim: Qt.darker(foreground, 1.55)
  readonly property color urgent: bar ? bar.urgent : Color.urgent
  readonly property color iconColor: connected ? barForeground : Qt.darker(barForeground, 1.55)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  function serverInfoByName(name) {
    if (!name) return null
    for (var i = 0; i < servers.length; i++) {
      if (servers[i] && servers[i].name === name) return servers[i]
    }
    return null
  }

  function selectedServerInfo() {
    return serverInfoByName(selectedServer)
  }

  function activeServerInfo() {
    return connected ? serverInfoByName(currentServer) : null
  }

  function countryNameFor(value) {
    var key = String(value || "").toLowerCase()
    for (var i = 0; i < countries.length; i++) {
      var c = countries[i]
      if (!c) continue
      if (String(c.code || "").toLowerCase() === key || String(c.name || "").toLowerCase() === key) return c.name
    }
    return value
  }

  function selectedCountryLabel() {
    if (mode === "country") return selectedCountryName || selectedCountry || "country"
    var server = selectedServerInfo()
    if (mode === "server" && server) return server.name
    if (mode === "server" && selectedServer) return selectedServer
    if (mode === "auto") return "the best server"
    return "AirVPN"
  }

  function heroStatusText() {
    if (!connected) return "Connect to " + selectedCountryLabel()
    var server = activeServerInfo()
    if (server) return "Connected to " + server.name
    if (currentServer && currentServer !== "earth") return "Connected to " + countryNameFor(currentServer)
    return "Connected to AirVPN"
  }

  function routeDetailText() {
    if (!connected) return "AirVPN"
    var server = activeServerInfo()
    if (server) {
      var bw = Model.formatBandwidth(server.bandwidth)
      return server.name + (bw ? " · " + bw : "")
    }
    if (currentServer && currentServer !== "earth") return countryNameFor(currentServer)
    return "AirVPN"
  }

  function barLabel() {
    return "VPN"
  }

  function countryRows() {
    var rows = countries.slice()
    if (!selectedCountry) return rows
    rows.sort(function(a, b) {
      var ak = a && (a.code || a.name) === selectedCountry ? 0 : 1
      var bk = b && (b.code || b.name) === selectedCountry ? 0 : 1
      if (ak !== bk) return ak - bk
      return String(a.name || "").localeCompare(String(b.name || ""))
    })
    return rows
  }

  function serverSectionTitle(index) {
    if (mode !== "server") return ""
    if (index <= 0 || index >= servers.length) return index === 0 && servers.length > 0 ? servers[0].country : ""
    var current = servers[index] ? servers[index].country : ""
    var previous = servers[index - 1] ? servers[index - 1].country : ""
    return current !== previous ? current : ""
  }

  function refresh() {
    if (!depsProc.running) {
      depsProc.command = [helper, "deps"]
      depsProc.running = true
    }
    if (!statusProc.running) {
      statusProc.command = [helper, "status"]
      statusProc.running = true
    }
    loadList()
  }

  function loadList() {
    if (listProc.running) return
    if (mode === "country") {
      listProc.command = [helper, "countries", "--filter", filter]
    } else {
      listProc.command = [helper, "servers", "--filter", filter, "--country", mode === "server" ? selectedCountry : ""]
    }
    listProc.running = true
  }

  function currentList() {
    return mode === "country" ? countryRows() : servers
  }

  function applyDeps(raw) {
    var data = Model.parseJson(raw, { ok: false, installed: false })
    depsInstalled = data.installed === true
  }

  function applyStatus(raw) {
    var data = Model.parseJson(raw, { ok: false, error: "Invalid status" })
    if (!data.ok) {
      errorText = data.error || "Status unavailable"
      statusText = "Not Connected"
      connected = false
      return
    }
    errorText = ""
    connected = data.connected === true
    hasApiKey = data.hasApiKey === true
    currentServer = data.server || data.activeConnection || ""
    currentDevice = data.device || ""
    if (deviceText === "") deviceText = currentDevice
    statusText = connected ? "Connected" : "Not Connected"
  }

  function applyList(raw) {
    var data = Model.parseJson(raw, { ok: false })
    if (!data.ok) return
    if (data.countries) countries = data.countries
    if (data.servers) servers = data.servers
    if (listIndex >= currentList().length) listIndex = Math.max(0, currentList().length - 1)
  }

  function selectMode(next) {
    mode = next
    listIndex = 0
    if (mode !== "server") selectedServer = ""
    loadList()
  }

  function selectFilter(next) {
    filter = next
    listIndex = 0
    loadList()
  }

  function connectSelection() {
    if (busy || !depsInstalled || !hasApiKey) return
    var cmd = [helper, "connect", "--mode", mode, "--filter", filter]
    if (currentDevice !== "") cmd.push("--device", currentDevice)
    if (mode === "country") {
      var c = currentList()[listIndex]
      if (!c) return
      selectedCountry = c.code || c.name
      selectedCountryName = c.name || selectedCountry
      selectedServer = ""
      cmd.push("--country", selectedCountry)
    }
    if (mode === "server") {
      var s = currentList()[listIndex]
      if (!s) return
      selectedServer = s.name
      cmd.push("--server", s.name)
    }
    actionProc.command = cmd
    busy = true
    actionProc.running = true
  }

  function selectRow(index) {
    listIndex = index
    var row = currentList()[index]
    if (!row) return
    if (mode === "country") {
      selectedCountry = row.code || row.name
      selectedCountryName = row.name || selectedCountry
      loadList()
    } else if (mode === "server") {
      selectedServer = row.name
      selectedCountry = row.countryCode || selectedCountry
      selectedCountryName = row.country || selectedCountryName
    }
  }

  function disconnect() {
    if (busy) return
    actionProc.command = [helper, "disconnect"]
    busy = true
    actionProc.running = true
  }

  function toggleVpn() {
    if (connected) disconnect()
    else connectSelection()
  }

  function saveSettings() {
    if (busy) return
    actionProc.command = [helper, "save-settings", "--api-key", apiKeyText, "--device", deviceText]
    busy = true
    actionProc.running = true
  }

  function installDeps() {
    Quickshell.execDetached(["alacritty", "-e", "bash", "-lc", "omarchy pkg aur add networkmanager-airvpn-core; read -rp 'Press enter to close...'"])
  }

  function openApiSettings() {
    Quickshell.execDetached(["xdg-open", "https://airvpn.org/apisettings/"])
  }

  function openDevices() {
    Quickshell.execDetached(["xdg-open", "https://airvpn.org/devices/"])
  }

  Component.onCompleted: refresh()

  Timer {
    interval: 30000
    running: true
    repeat: true
    onTriggered: root.refresh()
  }

  Process {
    id: depsProc
    stdout: StdioCollector { id: depsOut }
    onExited: root.applyDeps(depsOut.text)
  }

  Process {
    id: statusProc
    stdout: StdioCollector { id: statusOut }
    onExited: root.applyStatus(statusOut.text)
  }

  Process {
    id: listProc
    stdout: StdioCollector { id: listOut }
    onExited: root.applyList(listOut.text)
  }

  Process {
    id: actionProc
    stdout: StdioCollector { id: actionOut }
    onExited: function() {
      busy = false
      root.applyStatus(actionOut.text)
      root.refresh()
    }
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.barLabel()
    foreground: root.iconColor
    fontFamily: root.fontFamily
    fontSize: Style.font.bodySmall
    tooltipText: "AirVPN"
    onPressed: function(buttonCode) {
      if (buttonCode === Qt.RightButton) root.toggleVpn()
      else root.toggle()
    }
  }

  KeyboardPanel {
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    contentWidth: fittedContentWidth(Style.space(520))
    contentHeight: fittedContentHeight(contentColumn.implicitHeight, Style.space(620))

    Flickable {
      anchors.fill: parent
      contentWidth: width
      contentHeight: contentColumn.implicitHeight
      clip: true

      ColumnLayout {
        id: contentColumn
        width: parent.width
        spacing: Style.space(12)

        RowLayout {
          Layout.fillWidth: true
          spacing: Style.space(10)

          Button {
            text: "VPN"
            bordered: true
            active: root.connected
            foreground: root.foreground
            fontFamily: root.fontFamily
            onClicked: root.toggleVpn()
          }

          ColumnLayout {
            Layout.fillWidth: true
            Text {
              Layout.fillWidth: true
              text: root.heroStatusText()
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.body
              elide: Text.ElideRight
            }
            Text {
              Layout.fillWidth: true
              text: root.routeDetailText()
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
              elide: Text.ElideRight
            }
          }

          Button {
            text: root.showSettings ? "Back" : "Settings"
            bordered: true
            foreground: root.foreground
            fontFamily: root.fontFamily
            onClicked: root.showSettings = !root.showSettings
          }
        }

        Text {
          visible: root.errorText !== ""
          Layout.fillWidth: true
          text: root.errorText
          color: root.urgent
          font.family: root.fontFamily
          font.pixelSize: Style.font.bodySmall
          wrapMode: Text.WordWrap
        }

        ColumnLayout {
          visible: !root.depsInstalled
          Layout.fillWidth: true
          spacing: Style.space(8)

          PanelSeparator { Layout.fillWidth: true; foreground: root.foreground }
          PanelSectionHeader { text: "DEPENDENCY"; foreground: root.foreground; fontFamily: root.fontFamily }
          Text {
            Layout.fillWidth: true
            text: "Install networkmanager-airvpn-core from AUR."
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
            wrapMode: Text.WordWrap
          }
          Button {
            Layout.fillWidth: true
            text: "Install networkmanager-airvpn-core"
            bordered: true
            foreground: root.foreground
            fontFamily: root.fontFamily
            onClicked: root.installDeps()
          }
        }

        ColumnLayout {
          visible: root.showSettings || (root.depsInstalled && !root.hasApiKey)
          Layout.fillWidth: true
          spacing: Style.space(8)

          PanelSeparator { Layout.fillWidth: true; foreground: root.foreground }
          PanelSectionHeader { text: "AIRVPN SETTINGS"; foreground: root.foreground; fontFamily: root.fontFamily }

          RowLayout {
            Layout.fillWidth: true
            spacing: Style.space(6)
            Button { Layout.fillWidth: true; text: "Get API key"; bordered: true; foreground: root.foreground; fontFamily: root.fontFamily; onClicked: root.openApiSettings() }
            Button { Layout.fillWidth: true; text: "VPN Devices"; bordered: true; foreground: root.foreground; fontFamily: root.fontFamily; onClicked: root.openDevices() }
          }

          TextField {
            Layout.fillWidth: true
            placeholderText: root.hasApiKey ? "API key is saved" : "AirVPN API key"
            text: root.apiKeyText
            password: true
            onTextChanged: root.apiKeyText = text
          }

          TextField {
            Layout.fillWidth: true
            placeholderText: "Device name (optional)"
            text: root.deviceText
            onTextChanged: root.deviceText = text
          }

          Button {
            Layout.fillWidth: true
            text: root.busy ? "Saving..." : "Save settings"
            bordered: true
            foreground: root.foreground
            fontFamily: root.fontFamily
            onClicked: root.saveSettings()
          }
        }

        ColumnLayout {
          visible: root.depsInstalled && root.hasApiKey && !root.showSettings
          Layout.fillWidth: true
          spacing: Style.space(10)

          PanelSeparator { Layout.fillWidth: true; foreground: root.foreground }
          PanelSectionHeader { text: "MODE"; foreground: root.foreground; fontFamily: root.fontFamily }
          RowLayout {
            Layout.fillWidth: true
            spacing: Style.space(6)
            Repeater {
              model: root.modes
              Button {
                Layout.fillWidth: true
                text: Model.modeLabel(modelData)
                bordered: true
                active: root.mode === modelData
                foreground: root.foreground
                fontFamily: root.fontFamily
                onClicked: root.selectMode(modelData)
              }
            }
          }

          PanelSectionHeader { text: "FILTER"; foreground: root.foreground; fontFamily: root.fontFamily }
          RowLayout {
            Layout.fillWidth: true
            spacing: Style.space(6)
            Repeater {
              model: root.filters
              Button {
                Layout.fillWidth: true
                text: Model.filterLabel(modelData)
                bordered: true
                active: root.filter === modelData
                foreground: root.foreground
                fontFamily: root.fontFamily
                onClicked: root.selectFilter(modelData)
              }
            }
          }

          PanelSeparator { visible: root.mode !== "auto"; Layout.fillWidth: true; foreground: root.foreground }
          PanelSectionHeader { visible: root.mode !== "auto"; text: root.mode === "country" ? "COUNTRIES" : "SERVERS"; foreground: root.foreground; fontFamily: root.fontFamily }

          ListView {
            visible: root.mode !== "auto"
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(contentHeight, Style.space(260))
            clip: true
            spacing: Style.space(4)
            model: root.currentList()

            delegate: CursorSurface {
              required property var modelData
              required property int index
              width: ListView.view.width
              height: delegateColumn.implicitHeight
              foreground: root.foreground
              current: root.mode === "country" ? (root.selectedCountry === (modelData.code || modelData.name)) : (root.selectedServer === modelData.name || root.currentServer === modelData.name)

              MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  root.selectRow(index)
                }
              }

              Column {
                id: delegateColumn
                anchors.fill: parent
                spacing: Style.space(4)

                PanelSectionHeader {
                  visible: root.serverSectionTitle(index) !== ""
                  text: root.serverSectionTitle(index)
                  foreground: root.foreground
                  fontFamily: root.fontFamily
                  height: visible ? implicitHeight : 0
                }

                RowLayout {
                  id: row
                  width: parent.width
                  height: implicitHeight + Style.space(14)
                  anchors.leftMargin: Style.space(10)
                  anchors.rightMargin: Style.space(10)
                  spacing: Style.space(10)

                  Text {
                    Layout.fillWidth: true
                    text: modelData.name
                    color: root.foreground
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.body
                    elide: Text.ElideRight
                  }
                  Text {
                    text: root.mode === "country" ? Model.countrySubtitle(modelData) : Model.serverSubtitle(modelData)
                    color: root.dim
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.bodySmall
                    elide: Text.ElideRight
                  }
                }
              }
            }
          }

          Button {
            Layout.fillWidth: true
            text: root.connected ? "Disconnect" : "Connect"
            bordered: true
            active: root.connected
            foreground: root.foreground
            fontFamily: root.fontFamily
            onClicked: root.toggleVpn()
          }
        }
      }
    }
  }
}
