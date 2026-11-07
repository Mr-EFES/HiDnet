# Third-party software

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

The repository originally contains a GPLv2 `LICENSE`. It has not been relicensed
as part of implementing this development version. A GPLv2-only application
license is not compatible with linking this GPLv3 core. The owner must resolve
licensing before distributing a combined binary, including compatibility with
the chosen iOS distribution terms. No App Store distribution approval or
license compatibility determination is implied by this prototype.
