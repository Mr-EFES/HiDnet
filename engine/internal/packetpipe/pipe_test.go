package packetpipe

import (
	"bytes"
	"errors"
	"os"
	"testing"
	"time"
)

func TestDatagramsPreservePacketBoundaries(t *testing.T) {
	device, gateway, err := Open()
	if err != nil {
		t.Fatal(err)
	}
	defer device.Close()
	defer gateway.Close()
	first := make([]byte, 40)
	first[0], first[39] = 0x45, 17
	second := make([]byte, 28)
	second[0], second[27] = 0x45, 31
	for _, packet := range [][]byte{first, second} {
		if _, err := Write(device, packet); err != nil {
			t.Fatal(err)
		}
	}
	buffer := make([]byte, 1500)
	for _, want := range [][]byte{first, second} {
		n, err := Read(gateway, buffer)
		if err != nil || !bytes.Equal(buffer[:n], want) {
			t.Fatalf("packet mismatch: n=%d, error=%v", n, err)
		}
	}
	if _, err := gateway.Write(first); err != nil {
		t.Fatal(err)
	}
	n, err := Read(device, buffer)
	if err != nil || !bytes.Equal(buffer[:n], first) {
		t.Fatalf("return packet mismatch: %v", err)
	}
}

func TestIdleReadTimesOutWithoutClosingPipe(t *testing.T) {
	device, gateway, err := Open()
	if err != nil {
		t.Fatal(err)
	}
	defer device.Close()
	defer gateway.Close()
	buffer := make([]byte, 1500)
	n, err := Read(device, buffer)
	if n != 0 || err != nil {
		t.Fatalf("idle read: %d, %v", n, err)
	}
	packet := make([]byte, 20)
	packet[0] = 0x45
	if _, err := gateway.Write(packet); err != nil {
		t.Fatal(err)
	}
	if n, err := Read(device, buffer); n != 20 || err != nil {
		t.Fatalf("pipe unusable after timeout: %d, %v", n, err)
	}
}

func TestCloseUnblocksRead(t *testing.T) {
	device, gateway, err := Open()
	if err != nil {
		t.Fatal(err)
	}
	defer gateway.Close()
	done := make(chan error, 1)
	go func() {
		_, err := device.Read(make([]byte, 1500))
		done <- err
	}()
	device.Close()
	select {
	case err := <-done:
		if !errors.Is(err, os.ErrClosed) {
			t.Fatalf("unexpected close result: %v", err)
		}
	case <-time.After(time.Second):
		t.Fatal("read remained blocked after close")
	}
}

func TestRejectsMalformedPacketsAndDropsIPv6(t *testing.T) {
	device, gateway, err := Open()
	if err != nil {
		t.Fatal(err)
	}
	defer device.Close()
	defer gateway.Close()
	for _, packet := range [][]byte{nil, make([]byte, 19), make([]byte, 1501), make([]byte, 20)} {
		if _, err := Write(device, packet); err == nil {
			t.Fatal("malformed packet accepted")
		}
	}
	packet := make([]byte, 40)
	packet[0] = 0x60
	if n, err := Write(device, packet); n != 40 || err != nil {
		t.Fatalf("IPv6 drop: %d, %v", n, err)
	}
	if n, err := Read(gateway, make([]byte, 1500)); n != 0 || err != nil {
		t.Fatalf("IPv6 reached IPv4 gateway: %d, %v", n, err)
	}
}
