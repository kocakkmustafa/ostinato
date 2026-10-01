#!/usr/bin/env python3
"""Fetch a small, player-disjoint GuitarSet solo-note replay corpus.

Only the selected ZIP entries are downloaded. All WAV/JAMS bytes stay in the
task scratch directory and are removed after replay; the receipt survives.
GuitarSet 1.1.0 data: CC BY 4.0, https://zenodo.org/records/3371780.
"""

import hashlib
import json
from pathlib import Path
import urllib.request
import wave
import zipfile

from fetch_guitarset_fixtures import (  # existing HTTP Range ZIP reader
    ANNOTATION_ZIP_URL,
    AUDIO_ZIP_URL,
    HttpRangeFile,
)

APP_ROOT = Path(__file__).resolve().parents[1]
SCRATCH = APP_ROOT.parents[2] / "scratch/2026-09-26-motion-courses/ostinato"
RECEIPT = SCRATCH / "download-receipt.json"
MANIFEST = SCRATCH / "single-note-manifest.json"
MAX_BYTES = 1_000_000_000
TRACKS = ("BN1-129-Eb", "SS3-98-C")
PLAYERS = {"development": ("00", "01"), "holdout": ("02", "03")}
WINDOW_SAMPLES = 8192  # three 4096-sample YIN windows at 2048-sample hops
AFTER_ONSET_S = 0.11  # beyond the existing 100 ms no-verdict attack gate
EDGE_S = 0.04


def sha256(data):
    return hashlib.sha256(data).hexdigest()


def save_json(path, value):
    path.write_text(json.dumps(value, indent=2, ensure_ascii=False) + "\n")


def assert_license():
    req = urllib.request.Request("https://zenodo.org/api/records/3371780")
    with urllib.request.urlopen(req, timeout=30) as response:
        record = json.load(response)
    license_id = record["metadata"]["license"]["id"]
    if license_id != "cc-by-4.0":
        raise RuntimeError(f"Unexpected GuitarSet data license: {license_id}")
    return license_id


def note_candidates(jams, sample_rate, frame_count):
    events = []
    for annotation in jams["annotations"]:
        if annotation["namespace"] == "note_midi":
            events.extend(annotation["data"])
    events.sort(key=lambda event: event["time"])
    excluded = {
        "short_or_boundary": 0,
        "overlap_or_near_neighbor": 0,
        "outside_guitar_range": 0,
        "bent_or_ambiguous_label": 0,
    }
    candidates = []
    window_s = WINDOW_SAMPLES / sample_rate
    for index, event in enumerate(events):
        onset = float(event["time"])
        duration = float(event["duration"])
        start_s = onset + AFTER_ONSET_S
        end_s = start_s + window_s
        if duration < AFTER_ONSET_S + window_s + EDGE_S or end_s > frame_count / sample_rate:
            excluded["short_or_boundary"] += 1
            continue
        midi_float = float(event["value"])
        midi = round(midi_float)
        if not 40 <= midi <= 84:
            excluded["outside_guitar_range"] += 1
            continue
        if abs(midi_float - midi) > 0.35:
            excluded["bent_or_ambiguous_label"] += 1
            continue
        if any(
            other is not event
            and float(other["time"]) < end_s + EDGE_S
            and float(other["time"]) + float(other["duration"]) > start_s - EDGE_S
            for other in events
        ):
            excluded["overlap_or_near_neighbor"] += 1
            continue
        candidates.append(
            {
                "eventIndex": index,
                "startFrame": round(start_s * sample_rate),
                "targetMidi": midi,
                "annotatedMidi": midi_float,
                "onsetS": onset,
                "durationS": duration,
            }
        )
    return candidates, excluded, len(events)


def main():
    global RECEIPT, MANIFEST, PLAYERS
    import sys
    if '--observation' in sys.argv:
        RECEIPT = SCRATCH / 'observation-download-receipt.json'
        MANIFEST = SCRATCH / 'observation-manifest.json'
        PLAYERS = {'development': ('00', '01'), 'holdout': ('04', '05')}
        config = APP_ROOT / 'assets/config/guitar-observation.v1.json'
        save_json(SCRATCH / 'observation-freeze.json', {
          'configSha256': sha256(config.read_bytes()),
          'developmentPlayers': PLAYERS['development'],
          'holdoutPlayers': PLAYERS['holdout'],
          'tunedOnTheseRecordings': False,
          'freezeBeforeDownload': True,
          'guardIsAdditionalAndNotPartOfOriginal47of49Holdout': True,
        })
    SCRATCH.mkdir(parents=True, exist_ok=True)
    license_id = assert_license()
    receipt = {
        "source": "https://zenodo.org/records/3371780",
        "license": license_id,
        "downloaded": [],
        "cleanup": "pending",
    }
    save_json(RECEIPT, receipt)
    sources = []
    downloaded_bytes = 0
    readers = {}
    try:
        for zip_url in (ANNOTATION_ZIP_URL, AUDIO_ZIP_URL):
            reader = HttpRangeFile(zip_url)
            readers[zip_url] = (reader, zipfile.ZipFile(reader))
        for split, player_ids in PLAYERS.items():
            for player in player_ids:
                for track in TRACKS:
                    recording = f"{player}_{track}_solo"
                    names = (
                        (ANNOTATION_ZIP_URL, f"{recording}.jams"),
                        (AUDIO_ZIP_URL, f"{recording}_mic.wav"),
                    )
                    paths = {}
                    for zip_url, entry in names:
                        reader, archive = readers[zip_url]
                        data = archive.read(entry)
                        downloaded_bytes += len(data)
                        if downloaded_bytes > MAX_BYTES:
                            raise RuntimeError("Task download budget exceeded")
                        path = SCRATCH / entry
                        path.write_bytes(data)
                        paths[path.suffix] = path
                        receipt["downloaded"].append(
                            {
                                "path": str(path),
                                "sourceZip": zip_url,
                                "entry": entry,
                                "bytes": len(data),
                                "sha256": sha256(data),
                                "license": license_id,
                            }
                        )
                        save_json(RECEIPT, receipt)
                    with wave.open(str(paths[".wav"]), "rb") as wav:
                        if wav.getnchannels() != 1 or wav.getsampwidth() != 2:
                            raise RuntimeError(f"Unsupported WAV format: {paths['.wav']}")
                        sample_rate = wav.getframerate()
                        frame_count = wav.getnframes()
                    jams = json.loads(paths[".jams"].read_text())
                    candidates, excluded, event_count = note_candidates(
                        jams, sample_rate, frame_count
                    )
                    sources.append(
                        {
                            "split": split,
                            "player": player,
                            "recording": recording,
                            "audioPath": str(paths[".wav"]),
                            "jamsPath": str(paths[".jams"]),
                            "sampleRate": sample_rate,
                            "eventCount": event_count,
                            "candidates": candidates,
                            "excluded": excluded,
                        }
                    )
                    print(recording, split, len(candidates), excluded)
    finally:
        for _, archive in readers.values():
            archive.close()
    assert len({s["recording"] for s in sources}) == len(sources)
    assert set(s["player"] for s in sources if s["split"] == "development").isdisjoint(
        s["player"] for s in sources if s["split"] == "holdout"
    )
    save_json(
        MANIFEST,
        {
            "source": receipt["source"],
            "license": license_id,
            "selection": {
                "tracks": TRACKS,
                "developmentPlayers": PLAYERS["development"],
                "holdoutPlayers": PLAYERS["holdout"],
                "windowSamples": WINDOW_SAMPLES,
                "afterOnsetS": AFTER_ONSET_S,
                "edgeS": EDGE_S,
                "method": "one note_midi event overlaps full window, with neighbor margin",
            },
            "sources": sources,
        },
    )
    print("manifest", MANIFEST, "downloaded_bytes", downloaded_bytes)


if __name__ == "__main__":
    main()
