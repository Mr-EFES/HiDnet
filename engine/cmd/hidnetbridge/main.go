package main

/*
#include <stdlib.h>
*/
import "C"

import (
	"encoding/json"
	"os"
	"runtime/debug"
	"sync"
	"syscall"
	"unsafe"

	"github.com/Mr-EFES/HiDnet/engine/internal/packetpipe"
	mobile "github.com/p1neappleXpress/OpenFlux/bridge"
	"github.com/p1neappleXpress/OpenFlux/transport"
)

type snapshot struct {
	State         string `json:"state"`
	BytesSent     int64  `json:"bytesSent"`
	BytesReceived int64  `json:"bytesReceived"`
	Issue         string `json:"issue"`
}

type callback struct{}

var lifecycle sync.Mutex
var stateMu sync.RWMutex
var device *os.File
var status = snapshot{State: "stopped"}

func (callback) OnStatus(value string) {
	stateMu.Lock()
	defer stateMu.Unlock()
	if value == "connecting" || value == "stopped" {
		status.State = value
	}
}

func (callback) OnStats(sent, received int64) {
	stateMu.Lock()
	status.BytesSent, status.BytesReceived = sent, received
	stateMu.Unlock()
}

func (callback) OnLogEvent(code, _ string) {
	stateMu.Lock()
	defer stateMu.Unlock()
	switch code {
	case "connected":
		status.State, status.Issue = "connected", ""
	case "connecting", "retrying":
		status.State = "connecting"
	case "captcha_required":
		status.State, status.Issue = "captcha", "captcha_required"
	}
}

func (callback) OnRawLog(string) {}

//export HidnetStart
func HidnetStart(config *C.char) C.int {
	lifecycle.Lock()
	defer lifecycle.Unlock()
	if config == nil {
		return 1
	}
	stateMu.RLock()
	running := device != nil
	stateMu.RUnlock()
	if running {
		return 2
	}
	configJSON := C.GoString(config)
	var cfg mobile.Config
	if len(configJSON) > 65_536 || json.Unmarshal([]byte(configJSON), &cfg) != nil ||
		cfg.Mode != "manual" || cfg.MTU < 1280 || cfg.MTU > 1500 || cfg.VerboseLogging {
		return 1
	}
	debug.SetMemoryLimit(24 << 20)
	debug.SetGCPercent(50)
	local, gateway, err := packetpipe.OpenDescriptor()
	if err != nil {
		return 3
	}
	stateMu.Lock()
	status = snapshot{State: "connecting"}
	stateMu.Unlock()
	if cfg.ForceBootstrapDNS != "" {
		transport.SetBootstrapDNSServers([]string{cfg.ForceBootstrapDNS})
	}
	if err := mobile.StartTunnel(gateway, configJSON, nil, callback{}); err != nil {
		syscall.Close(gateway)
		local.Close()
		transport.SetBootstrapDNSServers(nil)
		stateMu.Lock()
		status.State, status.Issue = "error", "start_failed"
		stateMu.Unlock()
		return 4
	}
	stateMu.Lock()
	device = local
	stateMu.Unlock()
	return 0
}

//export HidnetStop
func HidnetStop() {
	lifecycle.Lock()
	defer lifecycle.Unlock()
	stateMu.Lock()
	local := device
	device = nil
	stateMu.Unlock()
	if local != nil {
		local.Close()
	}
	mobile.StopTunnel()
	stateMu.Lock()
	status.State = "stopped"
	stateMu.Unlock()
}

//export HidnetWritePacket
func HidnetWritePacket(buffer *C.char, length C.int) C.int {
	if buffer == nil || length < 20 || length > 1500 {
		return -1
	}
	stateMu.RLock()
	local := device
	stateMu.RUnlock()
	if local == nil {
		return -1
	}
	data := C.GoBytes(unsafe.Pointer(buffer), length)
	n, err := packetpipe.Write(local, data)
	if err != nil {
		return -1
	}
	return C.int(n)
}

//export HidnetReadPacket
func HidnetReadPacket(buffer *C.char, capacity C.int) C.int {
	if buffer == nil || capacity < 1500 || capacity > 65_535 {
		return -1
	}
	stateMu.RLock()
	local := device
	stateMu.RUnlock()
	if local == nil {
		return -1
	}
	data := make([]byte, int(capacity))
	n, err := packetpipe.Read(local, data)
	if err != nil {
		return -1
	}
	copy(unsafe.Slice((*byte)(unsafe.Pointer(buffer)), int(capacity)), data[:n])
	return C.int(n)
}

//export HidnetStatusJSON
func HidnetStatusJSON() *C.char {
	stateMu.RLock()
	data, _ := json.Marshal(status)
	stateMu.RUnlock()
	return C.CString(string(data))
}

//export HidnetFree
func HidnetFree(pointer *C.char) {
	C.free(unsafe.Pointer(pointer))
}

//export HidnetNetworkChanged
func HidnetNetworkChanged() {
	lifecycle.Lock()
	defer lifecycle.Unlock()
	mobile.NetworkChanged()
}

func main() {}
