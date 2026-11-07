# Third-party software

HiDnet's application and adapter source are licensed under the GNU General
Public License, version 3 (GPL-3.0-only); see LICENSE. Third-party components
retain their respective licenses and copyright notices.

HiDnet links the OpenFlux Go core from
<https://github.com/wlruscfd/openflux-server> at
`213694537582cd8194296ad255394b06c361eaf5`, a fork of
<https://github.com/p1neappleXpress/OpenFlux>. Its license is GNU GPL version 3;
copyright and license notices remain in the upstream source distribution.
The Android reference is `wlruscfd/openflux-app` tag `0.0.8`, also GPLv3.

HiDnet does not copy the Android UI or use its name or app icons. Its importer
implements the documented deep-link format. The bridge delegates packet
processing to upstream's exported API. The complete dependency versions and
checksums are in `engine/go.mod` and `engine/go.sum`.

Important transitive components include gVisor (Apache-2.0), gorilla/websocket
(BSD-2-Clause), pion/webrtc (MIT), pierrec/lz4 (BSD-3-Clause), and Go's x/*
libraries (BSD-3-Clause). Distributions must include the actual applicable
upstream notices and corresponding source where required; this list alone is
not a complete distribution license bundle.

The owner approved moving this HiDnet version to GPLv3 before distributing a
combined binary with the GPLv3 OpenFlux core. Earlier repository history is
unchanged. This does not relicense third-party components or imply App Store
distribution approval.

Each binary release includes HiDnet-source.tar.gz: the tagged HiDnet source,
vendored Go dependencies including their license/notice files, and the Go
standard library/toolchain source and license. SOURCE_BUILD.md in that archive
describes rebuilding with the vendored dependencies. Apple's system SDKs are
provided separately through Xcode.
