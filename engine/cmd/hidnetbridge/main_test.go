package main

import "testing"

func TestRejectsNilConfiguration(t *testing.T) {
	HidnetStop()
	if code := HidnetStart(nil); code != 1 {
		t.Fatalf("nil config returned %d", code)
	}
	if device != nil {
		t.Fatal("invalid configuration created an interface")
	}
}

func TestVPNInterfaceIsNotReportedAsAReadyTransport(t *testing.T) {
	stateMu.Lock()
	status = snapshot{State: "connecting"}
	stateMu.Unlock()
	callback{}.OnStatus("connected")
	stateMu.RLock()
	state := status.State
	stateMu.RUnlock()
	if state != "connecting" {
		t.Fatal("VPN readiness was mistaken for transport readiness")
	}
	callback{}.OnLogEvent("connected", "https://private.example/secret")
	stateMu.RLock()
	defer stateMu.RUnlock()
	if status.State != "connected" || status.Issue != "" {
		t.Fatal("handshake event was not reflected, or secret detail was retained")
	}
}

func TestCaptchaAndRetryEventsDoNotRetainSecretDetails(t *testing.T) {
	callback{}.OnLogEvent("captcha_required", "https://private.example/secret")
	stateMu.RLock()
	state, issue := status.State, status.Issue
	stateMu.RUnlock()
	if state != "captcha" || issue != "captcha_required" {
		t.Fatal("CAPTCHA detail escaped the event boundary")
	}
	callback{}.OnLogEvent("retrying", "secret=private")
	stateMu.RLock()
	defer stateMu.RUnlock()
	if status.State != "connecting" {
		t.Fatal("retry did not return the channel to connecting")
	}
}
