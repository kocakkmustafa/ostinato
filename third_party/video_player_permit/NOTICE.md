# Video player permit fork: upstream notices

These four source trees are local copies of the pinned Flutter packages
`video_player` 2.11.1, `video_player_android` 2.12.2,
`video_player_avfoundation` 2.12.0, and `video_player_platform_interface`
6.9.0. Each package retains its upstream `LICENSE`, `AUTHORS`, and source
copyright headers. The upstream license is the BSD 3-Clause license,
Copyright 2013 The Flutter Authors. No separate upstream `NOTICE` or
`COPYING` file was present in the four pinned cache trees.

`UPSTREAM-SHA256.json` lists every original relative file path, byte count,
and SHA-256 before local changes. Its source is the existing local pub cache;
this fork does not alter the cache. The hosted archive hashes in
`pubspec.lock` identify a different artifact and are not substituted for
extracted source hashes. Local changes must be reviewed separately from this
upstream inventory.

This directory is not a production video acceptance claim. The normal lesson
media slot and native video admission flag remain disabled pending native
permit, build, and device verification.

## Canonical source integration · 2026-10-02

The native/audio integration is based on canonical Ostinato
`1de443d7a8216574232bde2620c19d359be65df0` and the isolated V2a source.
The V2 source receipt is
`5910a130fcfdb4702046c1048b65234575de6735ccb393572245f25b394ffa60`.
All 947 V2a source paths were rehashed before copying; 945 match that receipt.
The two V2a test-harness changes are `native_video_exact_ack_channel_test.dart`
(`44360f4a0f66f2c369d04aed5055f81adf67c44a2051d967985e5a2c446f6e34`)
and `practice_video_exact_retired_ack_test.dart`
(`0f79bae53cb8748f54e19cbf658b7cdd2d9ecfd5a5c8d8ef727e5d7ae26d50a5`).

This directory imports all 328 V2a fork source files, including
`FVPTrackedInstanceChannels.m` and `FVPTrackedInstanceChannels.h`.
The older prototype archive contained 326 files and lacks those two files.
`UPSTREAM-SHA256.json` remains the original upstream inventory; it is not a
digest of this modified fork.

The V15a source receipt is
`a02f05f818a4c62b398ceb9b71766a16917e22b68ca019a271b16e64c4401e00`.
Its malformed-local-file error regression and timing-compatible helper were
added to `VideoPermitBridgeTests.swift`, preserving V2a's exact native close
regression and product `closeExactPlayer` API. The resulting source declares
41 distinct Swift Testing methods. No V15a product file replaced V2a source.

The V1b source receipt is
`5caa7fc256e5a38c5c59e833328d644b29506b440c8390d3490d300aa73085d9`.
Its app channel/vendor integration test and JVM test-harness dependency changes
are carried separately. App and vendor Android production files match V2a.

This integration has source-byte checks only. Historical standalone plugin,
Robolectric, and Dart results do not validate the combined canonical app.
Practice acquisition, native video admission, and shipping media remain closed.
