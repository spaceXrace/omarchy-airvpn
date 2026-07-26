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
  property string exitServer: ""
  property string exitCountry: ""
  property string exitIp: ""
  property int exitBandwidth: 0
  property bool exitLoading: false
  property string apiKeyText: ""
  property string deviceText: ""
  property string mode: "auto"
  property string filter: "auto"
  property string selectedCountry: ""
  property string selectedCountryName: ""
  property string selectedServer: ""
  property string pendingMode: ""
  property string pendingCountry: ""
  property string pendingServer: ""
  property var countries: []
  property var servers: []
  property int listIndex: 0
  property int hoverIndex: -1
  property bool heroHover: false
  property bool selectionPulse: false
  property bool cursorActive: false
  property string focusSection: "hero"
  property int modeIndex: 0
  property int filterIndex: -1

  readonly property string helper: Quickshell.env("HOME") + "/.config/omarchy/plugins/local.airvpn/bin/omarchy-airvpn"
  readonly property var modes: ["auto", "country", "server"]
  readonly property var filters: ["2gbit", "20gbit"]
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
    if (mode === "country" && !selectedCountry) return "country"
    if (mode === "country") return selectedCountryName || selectedCountry || "country"
    var server = selectedServerInfo()
    if (mode === "server" && server) return server.name
    if (mode === "server" && selectedServer) return selectedServer
    if (mode === "auto") return "the best server"
    return "AirVPN"
  }

  function pendingRouteLabel() {
    if (pendingMode === "auto") return "the best server"
    if (pendingMode === "country") return countryNameFor(pendingCountry || selectedCountryName || selectedCountry)
    if (pendingMode === "server") return pendingServer || selectedServer || "server"
    return selectedCountryLabel()
  }

  function heroStatusText() {
    if (!connected && busy && pendingMode) return "Connecting to " + pendingRouteLabel()
    if (!connected && mode === "country" && !selectedCountry) return "Select country"
    if (!connected && mode === "server" && !selectedServer) return "Select server"
    if (!connected) return "Connect to " + selectedCountryLabel()
    if (exitLoading) return "Connected to AirVPN"
    if (exitCountry) return "Connected to " + exitCountry
    var server = activeServerInfo()
    if (server && server.country) return "Connected to " + server.country
    if (currentServer && currentServer !== "earth") return "Connected to " + countryNameFor(currentServer)
    return "Connected to AirVPN"
  }

  function heroColor() {
    return selectionPulse ? urgent : foreground
  }

  function routeDetailText() {
    if (!connected) return "AirVPN"
    if (exitLoading) return "Loading connection details..."
    if (exitServer || exitIp || exitBandwidth) {
      var parts = []
      if (exitServer) parts.push(exitServer)
      if (exitIp) parts.push(exitIp)
      var exitBw = Model.formatBandwidth(exitBandwidth)
      if (exitBw) parts.push(exitBw)
      return parts.join(" · ")
    }
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

  function canConnect() {
    if (busy || !depsInstalled || !hasApiKey) return false
    if (mode === "country" && !selectedCountry) return false
    if (mode === "server" && !selectedServer) return false
    return true
  }

  function pulseMissingSelection() {
    if (connected || mode === "auto") return false
    if ((mode === "country" && selectedCountry) || (mode === "server" && selectedServer)) return false
    selectionPulse = false
    Qt.callLater(function() {
      selectionPulse = true
      selectionPulseTimer.restart()
    })
    return true
  }

  function exitMatchesPending(data) {
    if (!pendingMode) return true
    if (pendingMode === "auto") return true
    if (pendingMode === "server") return String(data.exitServer || "").toLowerCase() === pendingServer.toLowerCase()
    if (pendingMode === "country") {
      var code = String(data.exitCountryCode || "").toLowerCase()
      var name = String(data.exitCountry || "").toLowerCase()
      var target = pendingCountry.toLowerCase()
      return code === target || name === target
    }
    return true
  }

  function countryRows() {
    return countries
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
    var activeFilter = filter || "auto"
    if (mode === "country") {
      listProc.command = [helper, "countries", "--filter", activeFilter]
    } else {
      listProc.command = [helper, "servers", "--filter", activeFilter, "--country", mode === "server" ? selectedCountry : ""]
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
    var freshExit = connected && exitMatchesPending(data)
    exitServer = freshExit ? (data.exitServer || "") : ""
    exitCountry = freshExit ? (data.exitCountry || "") : ""
    exitIp = freshExit ? (data.exitIp || "") : ""
    exitBandwidth = freshExit ? (parseInt(data.exitBandwidth || 0, 10) || 0) : 0
    exitLoading = connected && (exitServer === "" || exitIp === "")
    if (!connected || (freshExit && exitServer !== "" && exitIp !== "")) {
      pendingMode = ""
      pendingCountry = ""
      pendingServer = ""
    }
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
    modeIndex = Math.max(0, modes.indexOf(next))
    listIndex = 0
    if (mode !== "server") selectedServer = ""
    loadList()
  }

  function selectFilter(next) {
    filter = filter === next ? "" : next
    filterIndex = filter === "" ? -1 : filters.indexOf(filter)
    listIndex = 0
    loadList()
  }

  function visibleListLength() {
    return mode === "auto" ? 0 : currentList().length
  }

  function ensureFocusSection() {
    if (focusSection === "filter" && mode === "auto") focusSection = "mode"
    if (focusSection === "filter" && filterIndex < 0) filterIndex = 0
    if (focusSection === "list" && visibleListLength() === 0) focusSection = mode === "auto" ? "connect" : "filter"
    if (listIndex >= visibleListLength()) listIndex = Math.max(0, visibleListLength() - 1)
    if (modeIndex < 0) modeIndex = Math.max(0, modes.indexOf(mode))
    if (modeIndex >= modes.length) modeIndex = modes.length - 1
    if (filterIndex >= filters.length) filterIndex = filters.length - 1
  }

  function moveCursor(dx, dy) {
    cursorActive = true
    hoverIndex = -1
    heroHover = false
    ensureFocusSection()
    if (dx !== 0) {
      if (focusSection === "hero") {
        if (dx > 0) focusSection = "settings"
      } else if (focusSection === "settings") {
        if (dx < 0) focusSection = "hero"
      } else if (focusSection === "mode") {
        modeIndex = Math.max(0, Math.min(modes.length - 1, modeIndex + dx))
      } else if (focusSection === "filter") {
        var current = filterIndex >= 0 ? filterIndex : (dx > 0 ? -1 : filters.length)
        filterIndex = Math.max(0, Math.min(filters.length - 1, current + dx))
      }
      return
    }
    if (dy === 0) return
    if (focusSection === "hero") {
      if (dy > 0) focusSection = root.showSettings ? "settings" : "mode"
    } else if (focusSection === "settings") {
      if (dy < 0) focusSection = "hero"
      else if (!root.showSettings && root.depsInstalled && root.hasApiKey) focusSection = "mode"
    } else if (focusSection === "mode") {
      if (dy < 0) focusSection = "hero"
      if (dy > 0) focusSection = mode === "auto" ? "connect" : "filter"
    } else if (focusSection === "filter") {
      if (dy < 0) focusSection = "mode"
      else focusSection = visibleListLength() > 0 ? "list" : "connect"
    } else if (focusSection === "list") {
      if (dy < 0 && listIndex <= 0) focusSection = "filter"
      else if (dy > 0 && listIndex >= visibleListLength() - 1) focusSection = "connect"
      else listIndex = Math.max(0, Math.min(visibleListLength() - 1, listIndex + dy))
    } else if (focusSection === "connect") {
      if (dy < 0) focusSection = visibleListLength() > 0 ? "list" : (mode === "auto" ? "mode" : "filter")
    }
    ensureFocusSection()
  }

  function activateCursor() {
    cursorActive = true
    ensureFocusSection()
    if (focusSection === "hero") toggleVpn()
    else if (focusSection === "settings") root.showSettings = !root.showSettings
    else if (focusSection === "mode") selectMode(modes[modeIndex])
    else if (focusSection === "filter") selectFilter(filters[Math.max(0, filterIndex)])
    else if (focusSection === "list") {
      if (connected) {
        disconnect()
        return
      }
      selectRow(listIndex)
      if (mode === "country") Qt.callLater(function() { root.connectSelection() })
    }
    else if (focusSection === "connect") toggleVpn()
  }

  function connectSelection() {
    if (pulseMissingSelection()) return
    if (!canConnect()) return
    var cmd = [helper, "connect", "--mode", mode, "--filter", filter || "auto"]
    if (currentDevice !== "") cmd.push("--device", currentDevice)
    if (mode === "country") {
      if (!selectedCountry) return
      selectedServer = ""
      cmd.push("--country", selectedCountry)
    }
    if (mode === "server") {
      if (!selectedServer) return
      cmd.push("--server", selectedServer)
    }
    pendingMode = mode
    pendingCountry = selectedCountry
    pendingServer = selectedServer
    exitServer = ""
    exitCountry = ""
    exitIp = ""
    exitBandwidth = 0
    exitLoading = true
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

  Timer {
    id: selectionPulseTimer
    interval: 420
    repeat: false
    onTriggered: root.selectionPulse = false
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
    text: ""
    hasVisualContent: true
    foreground: root.iconColor
    fontFamily: root.fontFamily
    fontSize: Style.font.bodySmall
    fixedWidth: vertical ? -1 : Style.bar.iconSlot
    fixedHeight: vertical ? Style.bar.iconSlot : -1
    tooltipText: "AirVPN"
    onPressed: function(buttonCode) {
      if (buttonCode === Qt.RightButton) root.toggleVpn()
      else root.toggle()
    }

    AirCloudIcon {
      anchors.centerIn: parent
      size: Style.space(16)
      color: root.iconColor
      ring: false
    }
  }

  KeyboardPanel {
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: fittedContentWidth(Style.space(520))
    contentHeight: fittedContentHeight(contentColumn.implicitHeight, Style.space(620))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onMoveRequested: function(dx, dy) { root.moveCursor(dx, dy) }
      onActivateRequested: root.activateCursor()
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onTextKey: function(t) {
        if (t === "r" || t === "R") root.refresh()
      }

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

          Item {
            id: heroLogo
            implicitWidth: Style.space(44)
            implicitHeight: Style.space(44)

            BorderSurface {
              anchors.fill: parent
              color: "transparent"
              radius: Style.cornerRadius
              visible: root.heroHover || (root.cursorActive && root.focusSection === "hero")
              borderSpec: Border.controlSpec("hover-cursor", root.foreground, Color.accent)
            }

            AirCloudIcon {
              anchors.centerIn: parent
              size: Style.space(40)
              color: root.connected ? root.foreground : root.dim
              ring: true
            }

            MouseArea {
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onEntered: {
                root.cursorActive = false
                root.hoverIndex = -1
                root.heroHover = true
              }
              onExited: root.heroHover = false
              onClicked: root.toggleVpn()
            }
          }

          ColumnLayout {
            Layout.fillWidth: true
            Text {
              Layout.fillWidth: true
              text: root.heroStatusText()
              color: root.heroColor()
              font.family: root.fontFamily
              font.pixelSize: Style.font.body
              elide: Text.ElideRight
              SequentialAnimation on opacity {
                running: root.selectionPulse
                loops: 2
                NumberAnimation { to: 0.35; duration: 80; easing.type: Easing.OutCubic }
                NumberAnimation { to: 1.0; duration: 100; easing.type: Easing.OutCubic }
              }
              Behavior on color { ColorAnimation { duration: 90 } }
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
            hasCursor: root.cursorActive && root.focusSection === "settings"
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
            id: modeRow
            Layout.fillWidth: true
            spacing: Style.space(6)
            Repeater {
              model: root.modes
              Button {
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                text: Model.modeLabel(modelData)
                bordered: true
                active: root.mode === modelData
                hasCursor: root.cursorActive && root.focusSection === "mode" && root.modeIndex === index
                foreground: root.foreground
                fontFamily: root.fontFamily
                onClicked: root.selectMode(modelData)
              }
            }
          }

          PanelSectionHeader { visible: root.mode !== "auto"; text: "FILTER"; foreground: root.foreground; fontFamily: root.fontFamily }
          RowLayout {
            id: filterRow
            visible: root.mode !== "auto"
            Layout.fillWidth: true
            spacing: Style.space(6)
            readonly property real cellWidth: (width - spacing * (root.filters.length - 1)) / root.filters.length
            Repeater {
              model: root.filters
              Button {
                Layout.preferredWidth: filterRow.cellWidth
                text: Model.filterLabel(modelData)
                bordered: true
                active: root.filter === modelData
                hasCursor: root.cursorActive && root.focusSection === "filter" && root.filterIndex === index
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
            currentIndex: root.listIndex
            onCurrentIndexChanged: if (currentIndex >= 0) positionViewAtIndex(currentIndex, ListView.Contain)

            delegate: Item {
              required property var modelData
              required property int index
              readonly property bool rowHovered: root.hoverIndex === index || (root.cursorActive && root.focusSection === "list" && root.listIndex === index)
              width: ListView.view.width
              height: delegateColumn.implicitHeight

              Column {
                id: delegateColumn
                width: parent.width
                spacing: Style.space(4)

                PanelSectionHeader {
                  visible: root.serverSectionTitle(index) !== ""
                  text: root.serverSectionTitle(index)
                  foreground: root.foreground
                  fontFamily: root.fontFamily
                  height: visible ? implicitHeight : 0
                }

                CursorSurface {
                  id: rowSurface
                  width: parent.width - Style.space(12)
                  height: row.implicitHeight + Style.space(14)
                  anchors.horizontalCenter: parent.horizontalCenter
                  foreground: root.foreground
                  hasCursor: rowHovered
                  current: root.mode === "country" ? (root.selectedCountry === (modelData.code || modelData.name)) : (root.selectedServer === modelData.name || root.currentServer === modelData.name)

                  MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: {
                      root.cursorActive = false
                      root.heroHover = false
                      root.hoverIndex = index
                    }
                    onExited: if (root.hoverIndex === index) root.hoverIndex = -1
                    onClicked: root.selectRow(index)
                  }

                  RowLayout {
                    id: row
                    anchors.fill: parent
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
          }

          Button {
            Layout.fillWidth: true
            text: root.connected ? "Disconnect" : "Connect"
            bordered: true
            active: root.connected
            hasCursor: root.cursorActive && root.focusSection === "connect"
            opacity: root.connected || root.canConnect() ? 1 : 0.55
            foreground: root.foreground
            fontFamily: root.fontFamily
            onClicked: root.toggleVpn()
          }
        }
      }
    }
    }
  }

  component AirCloudIcon: Item {
    id: icon

    property real size: 16
    property color color: Color.foreground
    property bool ring: false

    width: size
    height: size

    readonly property real sx: width / 240
    readonly property real sy: height / 240
    readonly property real ringCloudScale: 0.82
    readonly property real cloudSx: width / 155
    readonly property real cloudSy: height / 155
    readonly property color cutColor: root.bar ? root.bar.background : Color.background

    function xFor(xValue) {
      return ring ? width / 2 + xValue * sx * ringCloudScale : (xValue + 75) * cloudSx
    }

    function yFor(yValue) {
      return ring ? height / 2 - yValue * sy * ringCloudScale : (82 - yValue) * cloudSy
    }

    function rFor(radiusValue) {
      return ring ? radiusValue * Math.min(sx, sy) * ringCloudScale : radiusValue * Math.min(cloudSx, cloudSy)
    }

    Rectangle {
      visible: icon.ring
      anchors.centerIn: parent
      width: icon.rFor(200)
      height: width
      radius: width / 2
      color: "transparent"
      border.color: icon.color
      border.width: Math.max(1, Math.min(2, icon.size / 20))
    }

    Repeater {
      model: [
        { x: 0, y: 15, r: 35 },
        { x: 35, y: 5, r: 25 },
        { x: 60, y: -12, r: 18 },
        { x: -30, y: 2, r: 22 },
        { x: -55, y: -12, r: 16 },
        { x: 30, y: -15, r: 20 },
        { x: -35, y: -15, r: 20 }
      ]

      Rectangle {
        x: icon.xFor(modelData.x) - icon.rFor(modelData.r)
        y: icon.yFor(modelData.y) - icon.rFor(modelData.r)
        width: icon.rFor(modelData.r) * 2
        height: width
        radius: width / 2
        color: icon.color
      }
    }

    Rectangle {
      x: icon.xFor(-45)
      y: icon.yFor(10)
      width: icon.ring ? 95 * icon.sx * icon.ringCloudScale : 95 * icon.cloudSx
      height: icon.ring ? 30 * icon.sy * icon.ringCloudScale : 30 * icon.cloudSy
      color: icon.color
    }

    Rectangle {
      x: icon.xFor(-18) - icon.rFor(24)
      y: icon.yFor(-10) - icon.rFor(24)
      width: icon.rFor(24) * 2
      height: width
      radius: width / 2
      color: icon.cutColor
    }

    Rectangle {
      x: icon.xFor(-5) - icon.rFor(22)
      y: icon.yFor(-18) - icon.rFor(22)
      width: icon.rFor(22) * 2
      height: width
      radius: width / 2
      color: icon.color
    }
  }
}
