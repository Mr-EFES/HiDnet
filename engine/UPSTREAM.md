# OpenFlux dependency

- Android reference: `wlruscfd/openflux-app`, tag `0.0.8`, commit `50d09c4b867c7b84d3389e654fd050e7256eca92`.
- Core: `wlruscfd/openflux-server`, commit `213694537582cd8194296ad255394b06c361eaf5`.
- Go: `1.26.6`.

The adapter calls the fork's `bridge.StartTunnel`, which uses `nodetunnel` and
`gateway`, just like the referenced Android application. It does not substitute
the upstream iOS example's separate packet/session entry point. A Unix datagram
socket pair preserves packet boundaries between `NEPacketTunnelFlow` and the
gateway's reader/writer API. Upstream owns one descriptor after a successful
start; HiDnet owns the other. Stop closes both and unblocks pending reads.

The pinned core is newer than the Android tag. This establishes the same API and
packet-processing architecture, not verified interoperability with every 0.0.8
server. That requires an actual profile and an iPhone test.

The linker option `-checklinkname=0` is the upstream workaround for the MAX
transport's `github.com/wlynxg/anet` dependency. It does not change TLS or module
checksum verification.

The Go heap target is 24 MiB. This is a soft GC limit, not a process memory bound.
The two gVisor stacks and transports still need device testing against the iOS
Network Extension memory limit. IPv6 is captured and dropped; transport support
does not imply full UDP/QUIC support.
