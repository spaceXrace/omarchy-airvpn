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
  property bool busy: false
  property bool depsInstalled: false
  property bool hasApiKey: false
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
  property var countries: []
  property var servers: []
  property var devices: []
  property int listIndex: 0

  readonly property string helper: Quickshell.env("HOME") + "/.config/omarchy/plugins/local.airvpn/bin/omarchy-airvpn"
  readonly property var modes: ["auto", "country", "server"]
  readonly property var filters: ["auto", "2gbit", "20gbit"]
  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color barIconColor: connected ? barForeground : Qt.darker(barForeground, 1.55)
  readonly property color dim: Qt.darker(foreground, 1.55)
  readonly property color urgent: bar ? bar.urgent : Color.urgent
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property color hoverFill: bar ? Style.hoverFillFor(bar.foreground, Color.accent) : "transparent"
  readonly property color selectedFill: bar ? Style.selectedFillFor(bar.foreground, Color.accent) : "transparent"

  function refresh() {
    if (!depsProc.running) { depsOut.text = ""; depsProc.command = [helper, "deps"]; depsProc.running = true }
    if (!statusProc.running) { statusOut.text = ""; statusProc.command = [helper, "status"]; statusProc.running = true }
    loadList()
  }

  function loadList() {
    if (listProc.running) return
    listOut.text = ""
    if (mode === "country") listProc.command = [helper, "countries", "--filter", filter]
    else listProc.command = [helper, "servers", "--filter", filter, "--country", mode === "server" ? selectedCountry : ""]
    listProc.running = true
  }

  function applyDeps(raw) {
    var data = Model.parseJson(raw, { ok: false, installed: false })
    depsInstalled = !!data.installed
  }

  function applyStatus(raw) {
    var data = Model.parseJson(raw, { ok: false, error: "Invalid status" })
    if (!data.ok) { errorText = data.error || "Status unavailable"; statusText = "Not Connected"; connected = false; return }
    errorText = ""
    connected = !!data.connected
    hasApiKey = !!data.hasApiKey
    currentServer = data.server || data.activeConnection || ""
    currentDevice = data.device || ""
    if (deviceText === "") deviceText = currentDevice
    statusText = connected ? "Connected" : "Not Connected"
  }

  function applyList(raw) {
    var data = Model.parseJson(raw, { ok: false, error: "Invalid AirVPN data" })
    if (!data.ok) { errorText = data.error || "AirVPN data unavailable"; return }
    if (data.countries) countries = data.countries
    if (data.servers) servers = data.servers
    if (listIndex >= currentList().length) listIndex = Math.max(0, currentList().length - 1)
  }

  function currentList() { return mode === "country" ? countries : servers }
  function setMode(next) { mode = next; listIndex = 0; loadList() }
  function setFilter(next) { filter = next; listIndex = 0; loadList() }

  function connectSelection() {
    if (busy || !depsInstalled || !hasApiKey) return
    var cmd = [helper, "connect", "--mode", mode, "--filter", filter]
    if (currentDevice !== "") cmd.push("--device", currentDevice)
    if (mode === "country") { var c = countries[listIndex]; if (!c) return; selectedCountry = c.code || c.name; cmd.push("--country", selectedCountry) }
    if (mode === "server") { var s = servers[listIndex]; if (!s) return; cmd.push("--server", s.name) }
    actionOut.text = ""; actionProc.command = cmd; busy = true; actionProc.running = true
  }

  function disconnect() {
    if (busy) return
    actionOut.text = ""; actionProc.command = [helper, "disconnect"]; busy = true; actionProc.running = true
  }

  function toggleVpn() { connected ? disconnect() : connectSelection() }
  function openApiSettings() { Quickshell.execDetached(["xdg-open", "https://airvpn.org/apisettings/"]) }
  function openDevices() { Quickshell.execDetached(["xdg-open", "https://airvpn.org/devices/"]) }
  function installDeps() { Quickshell.execDetached(["alacritty", "-e", "bash", "-lc", "omarchy pkg aur add networkmanager-airvpn-core; read -rp 'Press enter to close...'"]) }
  function saveSettings() {
    if (busy) return
    actionOut.text = ""; actionProc.command = [helper, "save-settings", "--api-key", apiKeyText, "--device", deviceText]; busy = true; actionProc.running = true
  }

  Component.onCompleted: refresh()
  Timer { interval: 30000; running: true; repeat: true; onTriggered: root.refresh() }

  Process { id: depsProc; stdout: StdioCollector { id: depsOut }; onExited: root.applyDeps(depsOut.text) }
  Process { id: statusProc; stdout: StdioCollector { id: statusOut }; onExited: root.applyStatus(statusOut.text) }
  Process { id: listProc; stdout: StdioCollector { id: listOut }; onExited: root.applyList(listOut.text) }
  Process { id: actionProc; stdout: StdioCollector { id: actionOut }; onExited: function() { busy = false; root.applyStatus(actionOut.text); root.refresh() } }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: connected ? "󰖂" : "󰦝"
    foreground: root.barIconColor
    fontFamily: root.fontFamily
    tooltipText: "AirVPN"
    onPressed: function(buttonCode) { if (buttonCode === Qt.RightButton) root.toggleVpn(); else root.toggle() }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    contentWidth: panel.fittedContentWidth(Style.space(430))
    contentHeight: panel.fittedContentHeight(column.implicitHeight, Style.space(620))

    Flickable {
      anchors.fill: parent
      contentWidth: width
      contentHeight: column.implicitHeight
      clip: true

      ColumnLayout {
        id: column
        width: parent.width
        spacing: Style.space(12)

        RowLayout {
          Layout.fillWidth: true
          spacing: Style.space(12)
          Button { text: root.connected ? "󰖂" : "󰦝"; fontSize: Style.font.titleLarge; foreground: root.foreground; fontFamily: root.fontFamily; bordered: true; active: root.connected; onClicked: root.toggleVpn() }
          ColumnLayout {
            Layout.fillWidth: true
            spacing: Style.space(2)
            Text { Layout.fillWidth: true; text: root.statusText; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.body; elide: Text.ElideRight }
            Text { Layout.fillWidth: true; text: root.currentServer || (root.depsInstalled ? (root.hasApiKey ? "Select a route" : "Add API key") : "Install networkmanager-airvpn-core"); color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.bodySmall; elide: Text.ElideRight }
          }
          Button { text: root.showSettings ? "Back" : "Settings"; bordered: true; foreground: root.foreground; fontFamily: root.fontFamily; onClicked: root.showSettings = !root.showSettings }
        }

        Text { visible: root.errorText !== ""; Layout.fillWidth: true; text: root.errorText; color: root.urgent; font.family: root.fontFamily; font.pixelSize: Style.font.bodySmall; wrapMode: Text.WordWrap }

        ColumnLayout {
          visible: !root.depsInstalled
          Layout.fillWidth: true
          spacing: Style.space(8)
          PanelSeparator { Layout.fillWidth: true; foreground: root.foreground }
          PanelSectionHeader { text: "DEPENDENCY"; foreground: root.foreground; fontFamily: root.fontFamily }
          Text { Layout.fillWidth: true; text: "Install networkmanager-airvpn-core from AUR. It provides NetworkManager's AirVPN service without the GNOME editor."; color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.bodySmall; wrapMode: Text.WordWrap }
          Button { Layout.fillWidth: true; text: "Install in terminal"; bordered: true; foreground: root.foreground; fontFamily: root.fontFamily; onClicked: root.installDeps() }
        }

        ColumnLayout {
          visible: root.showSettings || (root.depsInstalled && !root.hasApiKey)
          Layout.fillWidth: true
          spacing: Style.space(8)
          PanelSeparator { Layout.fillWidth: true; foreground: root.foreground }
          PanelSectionHeader { text: "AIRVPN SETTINGS"; foreground: root.foreground; fontFamily: root.fontFamily }
          RowLayout { Layout.fillWidth: true; spacing: Style.space(6); Button { Layout.fillWidth: true; text: "Open API settings"; bordered: true; foreground: root.foreground; fontFamily: root.fontFamily; onClicked: root.openApiSettings() }; Button { Layout.fillWidth: true; text: "Open devices"; bordered: true; foreground: root.foreground; fontFamily: root.fontFamily; onClicked: root.openDevices() } }
          TextField { id: apiInput; Layout.fillWidth: true; placeholderText: root.hasApiKey ? "API key is saved" : "AirVPN API key"; text: root.apiKeyText; echoMode: TextInput.Password; onTextChanged: root.apiKeyText = text }
          TextField { id: deviceInput; Layout.fillWidth: true; placeholderText: "Device name (optional)"; text: root.deviceText; onTextChanged: root.deviceText = text }
          Button { Layout.fillWidth: true; text: root.busy ? "Saving..." : "Save settings"; bordered: true; foreground: root.foreground; fontFamily: root.fontFamily; onClicked: root.saveSettings() }
        }

        ColumnLayout {
          visible: root.depsInstalled && root.hasApiKey && !root.showSettings
          Layout.fillWidth: true
          spacing: Style.space(10)
          PanelSeparator { Layout.fillWidth: true; foreground: root.foreground }
          PanelSectionHeader { text: "MODE"; foreground: root.foreground; fontFamily: root.fontFamily }
          RowLayout { Layout.fillWidth: true; spacing: Style.space(6); Repeater { model: root.modes; Button { Layout.fillWidth: true; text: Model.modeLabel(modelData); bordered: true; active: root.mode === modelData; foreground: root.foreground; fontFamily: root.fontFamily; onClicked: root.setMode(modelData) } } }
          PanelSectionHeader { text: "FILTER"; foreground: root.foreground; fontFamily: root.fontFamily }
          RowLayout { Layout.fillWidth: true; spacing: Style.space(6); Repeater { model: root.filters; Button { Layout.fillWidth: true; text: Model.filterLabel(modelData); bordered: true; active: root.filter === modelData; foreground: root.foreground; fontFamily: root.fontFamily; onClicked: root.setFilter(modelData) } } }
          PanelSeparator { Layout.fillWidth: true; foreground: root.foreground }
          PanelSectionHeader { text: root.mode === "country" ? "COUNTRIES" : "SERVERS"; foreground: root.foreground; fontFamily: root.fontFamily }
          ListView {
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(contentHeight, Style.space(260))
            clip: true
            spacing: Style.space(4)
            model: root.currentList()
            delegate: CursorSurface {
              required property var modelData
              required property int index
              width: ListView.view.width
              height: row.implicitHeight + Style.space(14)
              foreground: root.foreground
              fill: root.hoverFill
              currentFill: root.selectedFill
              current: root.mode === "country" ? (root.selectedCountry === (modelData.code || modelData.name)) : (root.currentServer === modelData.name)
              MouseArea { anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { root.listIndex = index; root.connectSelection() } }
              RowLayout { id: row; anchors.fill: parent; anchors.leftMargin: Style.space(10); anchors.rightMargin: Style.space(10); spacing: Style.space(10); Text { Layout.fillWidth: true; text: modelData.name; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.body; elide: Text.ElideRight }; Text { text: root.mode === "country" ? Model.countrySubtitle(modelData) : Model.serverSubtitle(modelData); color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.bodySmall; elide: Text.ElideRight } }
            }
          }
          Button { Layout.fillWidth: true; text: root.connected ? "Disconnect" : "Connect"; bordered: true; active: root.connected; foreground: root.foreground; fontFamily: root.fontFamily; onClicked: root.toggleVpn() }
        }
      }
    }
  }
}
