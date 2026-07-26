import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model

BarWidget {
  id: root
  moduleName: "local.airvpn"

  property bool opened: false
  property bool connected: false
  property bool busy: false
  property string statusText: "Checking..."
  property string errorText: ""
  property string currentServer: ""
  property string mode: "auto"
  property string filter: "auto"
  property string selectedCountry: ""
  property string selectedServer: ""
  property var countries: []
  property var servers: []
  property string focusSection: "mode"
  property int modeIndex: 0
  property int filterIndex: 0
  property int listIndex: 0
  property bool cursorActive: false

  readonly property string helper: Quickshell.env("HOME") + "/.config/omarchy/plugins/local.airvpn/bin/omarchy-airvpn"
  readonly property var modes: ["auto", "country", "server"]
  readonly property var filters: ["auto", "2gbit", "20gbit"]
  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color dim: Qt.darker(foreground, 1.55)
  readonly property color urgent: bar ? bar.urgent : Color.urgent
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property color hoverFill: bar ? Style.hoverFillFor(bar.foreground, Color.accent) : "transparent"
  readonly property color selectedFill: bar ? Style.selectedFillFor(bar.foreground, Color.accent) : "transparent"

  width: barSize
  height: barSize

  function refresh() {
    if (!statusProc.running) {
      statusOut.text = ""
      statusProc.command = [helper, "status"]
      statusProc.running = true
    }
    loadList()
  }

  function loadList() {
    if (listProc.running) return
    listOut.text = ""
    if (mode === "country") listProc.command = [helper, "countries", "--filter", filter]
    else listProc.command = [helper, "servers", "--filter", filter, "--country", mode === "server" ? selectedCountry : ""]
    listProc.running = true
  }

  function applyStatus(raw) {
    var data = Model.parseJson(raw, { ok: false, error: "Invalid status" })
    if (!data.ok) { errorText = data.error || "Status unavailable"; statusText = "Not Connected"; connected = false; return }
    errorText = ""
    connected = !!data.connected
    currentServer = data.server || data.activeConnection || ""
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

  function setMode(next) {
    mode = next
    modeIndex = modes.indexOf(next)
    listIndex = 0
    loadList()
  }

  function setFilter(next) {
    filter = next
    filterIndex = filters.indexOf(next)
    listIndex = 0
    loadList()
  }

  function connectSelection() {
    if (busy) return
    var cmd = [helper, "connect", "--mode", mode, "--filter", filter]
    if (mode === "country") {
      var c = countries[listIndex]
      if (!c) return
      selectedCountry = c.code || c.name
      cmd.push("--country", selectedCountry)
    } else if (mode === "server") {
      var s = servers[listIndex]
      if (!s) return
      selectedServer = s.name
      cmd.push("--server", selectedServer)
    }
    actionOut.text = ""
    actionProc.command = cmd
    busy = true
    actionProc.running = true
  }

  function disconnect() {
    if (busy) return
    actionOut.text = ""
    actionProc.command = [helper, "disconnect"]
    busy = true
    actionProc.running = true
  }

  function toggle() { connected ? disconnect() : connectSelection() }

  Component.onCompleted: refresh()

  Timer { interval: 30000; running: true; repeat: true; onTriggered: root.refresh() }

  Process { id: statusProc; stdout: StdioCollector { id: statusOut }; onExited: function() { root.applyStatus(statusOut.text) } }
  Process { id: listProc; stdout: StdioCollector { id: listOut }; onExited: function() { root.applyList(listOut.text) } }
  Process { id: actionProc; stdout: StdioCollector { id: actionOut }; onExited: function() { busy = false; root.applyStatus(actionOut.text); root.refresh() } }

  BarIconButton {
    anchors.fill: parent
    bar: root.bar
    text: connected ? "󰖂" : "󰦝"
    foreground: connected ? root.foreground : root.dim
    fontFamily: root.fontFamily
    onPressed: function(button) {
      if (button === Qt.RightButton) root.toggle()
      else root.opened = !root.opened
    }
  }

  Panel {
    id: panel
    moduleName: root.moduleName
    bar: root.bar
    opened: root.opened
    onOpenedChanged: if (opened) root.refresh()

    implicitWidth: Style.space(420)

    ColumnLayout {
      anchors.fill: parent
      anchors.margins: Style.space(14)
      spacing: Style.space(12)

      RowLayout {
        Layout.fillWidth: true
        spacing: Style.space(12)

        Button {
          text: root.connected ? "󰖂" : "󰦝"
          fontSize: Style.font.titleLarge
          foreground: root.foreground
          fontFamily: root.fontFamily
          bordered: true
          active: root.connected
          onClicked: root.toggle()
        }

        ColumnLayout {
          Layout.fillWidth: true
          spacing: Style.space(2)
          Text { Layout.fillWidth: true; text: root.statusText; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.body; elide: Text.ElideRight }
          Text { Layout.fillWidth: true; text: root.currentServer || (root.connected ? "AirVPN" : "Select a route"); color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.bodySmall; elide: Text.ElideRight }
        }
      }

      Text { visible: root.errorText !== ""; Layout.fillWidth: true; text: root.errorText; color: root.urgent; font.family: root.fontFamily; font.pixelSize: Style.font.bodySmall; wrapMode: Text.WordWrap }

      PanelSeparator { Layout.fillWidth: true; foreground: root.foreground }
      PanelSectionHeader { text: "MODE"; foreground: root.foreground; fontFamily: root.fontFamily }
      RowLayout {
        Layout.fillWidth: true
        spacing: Style.space(6)
        Repeater {
          model: root.modes
          Button { Layout.fillWidth: true; text: Model.modeLabel(modelData); bordered: true; active: root.mode === modelData; foreground: root.foreground; fontFamily: root.fontFamily; onClicked: root.setMode(modelData) }
        }
      }

      PanelSectionHeader { text: "FILTER"; foreground: root.foreground; fontFamily: root.fontFamily }
      RowLayout {
        Layout.fillWidth: true
        spacing: Style.space(6)
        Repeater {
          model: root.filters
          Button { Layout.fillWidth: true; text: Model.filterLabel(modelData); bordered: true; active: root.filter === modelData; foreground: root.foreground; fontFamily: root.fontFamily; onClicked: root.setFilter(modelData) }
        }
      }

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
          hasCursor: false
          MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: { root.listIndex = index; root.connectSelection() }
          }
          RowLayout {
            id: row
            anchors.fill: parent
            anchors.leftMargin: Style.space(10)
            anchors.rightMargin: Style.space(10)
            spacing: Style.space(10)
            Text { Layout.fillWidth: true; text: root.mode === "country" ? modelData.name : modelData.name; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.body; elide: Text.ElideRight }
            Text { text: root.mode === "country" ? Model.countrySubtitle(modelData) : Model.serverSubtitle(modelData); color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.bodySmall; elide: Text.ElideRight }
          }
        }
      }

      Button { Layout.fillWidth: true; text: root.connected ? "Disconnect" : "Connect"; bordered: true; active: root.connected; foreground: root.foreground; fontFamily: root.fontFamily; onClicked: root.toggle() }
    }
  }
}
