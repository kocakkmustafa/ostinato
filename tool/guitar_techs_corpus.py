#!/usr/bin/env python3
"""Bounded CC BY4.0 Guitar-TECHS corpus, with annotation-only selection.

Long ZIP entries are decompressed in bounded blocks, never retained whole.
Only exact8192-frame WAV crops and their MIDI references enter task scratch.
No video, resampling, gain change, quantization or model tuning is involved.
"""
import hashlib
import io
import json
import math
from pathlib import Path
import struct
import urllib.request
import zipfile

APP = Path(__file__).resolve().parents[1]
SCRATCH = APP.parents[2] / 'scratch/2026-09-26-motion-device-release/note-corpus'
LIMIT = 64 * 1024 * 1024
RECORD = 'https://zenodo.org/records/14963133'
MIDI_NOTES = [40, 43, 45, 48, 50, 52, 55, 57, 59, 60, 64, 69, 72, 76, 79, 81, 83]
SELECTION = {
    'positiveMidi': MIDI_NOTES, 'windowFrames': 8192,
    'afterOnsetSeconds': .25, 'beforeOffsetSeconds': .15,
    'audioMidiAlignmentAllowanceSeconds': .10,
    'positive': 'first eligible event per listed MIDI; no overlapping MIDI event',
    'negative': 'first12 distinct eligible simultaneously active MIDI triads',
    'channels': 'micamp only; original channels averaged by replay when stereo',
    'changes': 'time crop only; original PCM format/rate preserved',
}
SPECS = [('P1', 'singlenotes', 'allsinglenotes', 'positive'),
         ('P2', 'singlenotes', 'allsinglenotes', 'positive'),
         ('P1', 'chords', 'Set1_maj', 'polyphonicNegative')]


def sha(data):
    return hashlib.sha256(data).hexdigest()


def save(path, value):
    path.write_text(json.dumps(value, indent=2, ensure_ascii=False) + '\n')


class Budget:
    def __init__(self, journal_path=None):
        self.network = 0
        self.retained = 0
        self.peak = 0
        self.requests = []
        self.journal_path = journal_path

    def journal(self):
        if self.journal_path is not None:
            save(self.journal_path, {'requestedBytes': self.network, 'requests': self.requests})

    def network_add(self, n):
        if self.network + n > LIMIT:
            raise RuntimeError('64MiB cumulative range-byte budget exceeded')
        self.network += n

    def retained_add(self, n):
        self.retained += n
        self.peak = max(self.peak, self.retained)
        if self.retained > LIMIT:
            raise RuntimeError('64MiB retained-file budget exceeded')


class StrictRangeFile(io.RawIOBase):
    def __init__(self, url, size, budget, opener=urllib.request.urlopen):
        self.url, self.size, self.budget, self.opener = url, size, budget, opener
        self.pos, self.fetched = 0, 0
        self.cache_start, self.cache = 0, b''
        self.prefetch_end = 0

    def readable(self): return True
    def seekable(self): return True
    def tell(self): return self.pos
    def seek(self, offset, whence=0):
        self.pos = offset if whence == 0 else self.pos + offset if whence == 1 else self.size + offset
        if self.pos < 0: raise ValueError('Negative seek')
        return self.pos

    def readinto(self, target):
        if not target or self.pos >= self.size: return 0
        count = min(len(target), self.size - self.pos)
        cached_end = self.cache_start + len(self.cache)
        if self.cache_start <= self.pos < cached_end:
            count = min(count, cached_end - self.pos)
            start = self.pos - self.cache_start
            target[:count] = self.cache[start:start + count]
            self.pos += count
            return count
        length = count
        if self.pos < self.prefetch_end:
            length = min(max(count, 1024 * 1024), self.prefetch_end - self.pos)
        count = min(count, length)
        end = self.pos + length - 1
        data = b''
        for attempt in range(3):
            self.budget.network_add(length)
            item = {'url': self.url, 'start': self.pos, 'end': end, 'requestedBytes': length, 'attempt': attempt + 1}
            self.budget.requests.append(item); self.budget.journal()
            request = urllib.request.Request(self.url, headers={'Range': f'bytes={self.pos}-{end}', 'Accept-Encoding': 'identity'})
            with self.opener(request, timeout=30) as response:
                item['status'], item['contentRange'] = response.status, response.headers.get('Content-Range')
                # Refuse HTTP200 before reading a possibly gigabyte-size body.
                if response.status != 206 or response.headers.get('Content-Range') != f'bytes {self.pos}-{end}/{self.size}':
                    self.budget.journal()
                    raise RuntimeError('Exact HTTP206 Content-Range required')
                data = response.read(length + 1)
            item['actualBodyBytes'] = len(data); self.budget.journal()
            if len(data) == length: break
            if attempt == 2:
                raise RuntimeError(f'Range body mismatch at{self.pos}: expected{length}, actual{len(data)}')
        self.fetched += length
        self.cache_start, self.cache = self.pos, data
        target[:count] = data[:count]
        self.pos += count
        return count


def midi_events(data):
    """Standard MIDI notes/tempo; MIDI labels are never inferred from audio."""
    if data[:4] != b'MThd': raise ValueError('Missing MIDI header')
    header_size = int.from_bytes(data[4:8], 'big')
    fmt, tracks, division = struct.unpack('>HHH', data[8:14])
    if fmt not in (0, 1) or division & 0x8000: raise ValueError('Unsupported MIDI timing')
    tempos, notes = [(0, 500000)], []
    pos = 8 + header_size
    for track in range(tracks):
        if data[pos:pos+4] != b'MTrk': raise ValueError('Missing MIDI track')
        size = int.from_bytes(data[pos+4:pos+8], 'big')
        body = data[pos+8:pos+8+size]; pos += 8 + size
        i, tick, running, active = 0, 0, None, {}
        def varlen():
            nonlocal i
            value = 0
            for _ in range(4):
                byte = body[i]; i += 1; value = (value << 7) | (byte & 127)
                if byte < 128: return value
            raise ValueError('Invalid MIDI variable length')
        while i < len(body):
            tick += varlen()
            if body[i] >= 128:
                status = body[i]; i += 1
                if status < 240: running = status
            elif running is not None: status = running
            else: raise ValueError('Missing MIDI running status')
            if status == 255:
                kind = body[i]; i += 1; length = varlen()
                value = body[i:i+length]; i += length
                if kind == 81:
                    if len(value) != 3: raise ValueError('Invalid MIDI tempo')
                    tempos.append((tick, int.from_bytes(value, 'big')))
                continue
            if status in (240, 247):
                length = varlen(); i += length; running = None; continue
            kind, channel = status >> 4, status & 15
            if kind not in range(8, 15): raise ValueError('Unsupported MIDI event')
            one = body[i]; i += 1
            two = 0 if kind in (12, 13) else body[i]
            if kind not in (12, 13): i += 1
            key = channel, one
            if kind == 9 and two:
                if key in active: raise ValueError('Overlapping same MIDI key')
                active[key] = tick
            elif kind == 8 or (kind == 9 and not two):
                start = active.pop(key, None)
                if start is not None:
                    notes.append({'track': track, 'channel': channel, 'midi': one,
                                  'onTick': start, 'offTick': tick})
        if active: raise ValueError('Unclosed MIDI notes')
    tempo_map = sorted(dict(tempos).items())
    def seconds(ticks):
        value, previous, tempo = 0., 0, 500000
        for change, next_tempo in tempo_map:
            if change > ticks: break
            value += (change - previous) * tempo / division / 1e6
            previous, tempo = change, next_tempo
        return value + (ticks - previous) * tempo / division / 1e6
    for note in notes:
        note['onsetS'], note['offsetS'] = seconds(note['onTick']), seconds(note['offTick'])
    return sorted(notes, key=lambda n: (n['onsetS'], n['midi'], n['track']))


def select(events, rate, frames, kind):
    window = SELECTION['windowFrames'] / rate
    chosen, used = [], set()
    for event in events:
        start = event['onsetS'] + .25
        end = start + window
        if end + .15 > event['offsetS'] or end > frames / rate: continue
        active = [n for n in events if n['onsetS'] <= start - .10 and n['offsetS'] >= end + .15]
        neighbors = [n for n in events if n['onsetS'] < end + .10 and n['offsetS'] > start - .10]
        pitches = tuple(sorted(n['midi'] for n in active))
        if kind == 'positive':
            if len(active) != 1 or len(neighbors) != 1 or event['midi'] not in MIDI_NOTES: continue
            key = event['midi']
        else:
            if len(active) != 3 or len(neighbors) != 3 or len(set(pitches)) != 3: continue
            key = pitches
        if key in used: continue
        used.add(key)
        chosen.append({'startFrame': round(start * rate), 'referenceMidi': list(pitches),
                       'onsetS': max(n['onsetS'] for n in active),
                       'offsetS': min(n['offsetS'] for n in active),
                       'referenceTracks': [n['track'] for n in active]})
        if kind != 'positive' and len(chosen) == 12: break
    return sorted(chosen, key=lambda c: c['startFrame'])


def stream_crops(stream, selected, budget, crop_prefix, on_crop=None):
    """Hash full original entry but retain only annotation-selected sample spans."""
    digest, full_bytes = hashlib.sha256(), 0
    def read(n):
        nonlocal full_bytes
        result = stream.read(n); digest.update(result); full_bytes += len(result); return result
    header = read(12)
    if header[:4] != b'RIFF' or header[8:] != b'WAVE': raise ValueError('Not RIFF WAV')
    fmt = None; crops = []; rate = channels = bits = block = format_tag = None
    floor_levels = []
    while True:
        chunk = read(8)
        if not chunk: break
        if len(chunk) != 8: raise ValueError('Truncated WAV chunk')
        kind, size = chunk[:4], int.from_bytes(chunk[4:], 'little')
        if kind == b'fmt ':
            fmt = read(size)
            format_tag, channels, rate, _, block, bits = struct.unpack('<HHIIHH', fmt[:16])
            if format_tag == 65534:
                if len(fmt) < 40: raise ValueError('Invalid extensible WAV')
                format_tag = int.from_bytes(fmt[24:26], 'little')
            if format_tag not in (1, 3) or bits not in (16, 24, 32, 64) or channels not in (1, 2) or rate not in (44100, 48000):
                raise ValueError(f'Unsupported WAV format {format_tag}/{channels}/{rate}/{bits}')
        elif kind == b'data':
            if fmt is None: raise ValueError('WAV data before fmt')
            frames = size // block
            candidates = select(selected['events'], rate, frames, selected['kind'])
            spans = [(c['startFrame'] * block, (c['startFrame'] + 8192) * block, bytearray()) for c in candidates]
            position = 0; pending = b''; count = 0; energy = 0.
            floor_chunk_frames = round(rate * .05)
            def frames_from_bytes(raw):
                if format_tag == 3:
                    code = 'f' if bits == 32 else 'd'
                    for values in struct.iter_unpack('<' + code * channels, raw):
                        yield sum(values) / channels
                elif bits in (16, 32, 64):
                    code = {16: 'h', 32: 'i', 64: 'q'}[bits]
                    scale = float(2 ** (bits - 1))
                    for values in struct.iter_unpack('<' + code * channels, raw):
                        yield sum(values) / channels / scale
                else:
                    for offset in range(0, len(raw), block):
                        yield sum(int.from_bytes(raw[offset+c*3:offset+c*3+3], 'little', signed=True)
                                  for c in range(channels)) / channels / 8388608.
            while position < size:
                data = read(min(65536, size - position))
                if not data: raise ValueError('Truncated WAV data')
                packed = pending + data
                complete = len(packed) // block * block
                pending = packed[complete:]
                for sample in frames_from_bytes(packed[:complete]):
                    if not math.isfinite(sample): raise ValueError('Nonfinite original WAV sample')
                    energy += sample * sample; count += 1
                    if count == floor_chunk_frames:
                        floor_levels.append(20 * math.log10(max(math.sqrt(energy / count), 1e-9)))
                        count, energy = 0, 0.
                for left, right, target in spans:
                    a, b = max(left, position), min(right, position + len(data))
                    if a < b: target.extend(data[a-position:b-position])
                position += len(data)
            for index, (candidate, (_, _, data)) in enumerate(zip(candidates, spans)):
                if len(data) != 8192 * block: raise ValueError('Incomplete crop')
                fmt_chunk = b'fmt ' + struct.pack('<I', len(fmt)) + fmt + (b'\0' if len(fmt) % 2 else b'')
                payload = fmt_chunk + b'data' + struct.pack('<I', len(data)) + data
                wav = b'RIFF' + struct.pack('<I', len(payload) + 4) + b'WAVE' + payload
                path = SCRATCH / f'{crop_prefix}-{index:02d}.wav'
                if path.exists(): raise RuntimeError(f'Will not overwrite {path}')
                budget.retained_add(len(wav)); path.write_bytes(wav)
                crops.append({**candidate, 'path': str(path), 'bytes': len(wav), 'sha256': sha(wav),
                              'sampleRate': rate, 'channels': channels, 'bitsPerSample': bits,
                              'audioFormat': format_tag, 'windowFrames': 8192})
                if on_crop is not None: on_crop(crops[-1])
        else:
            remaining = size
            while remaining:
                data = read(min(65536, remaining))
                if not data: raise ValueError('Truncated WAV metadata')
                remaining -= len(data)
        if size % 2: read(1)
    floor_levels.sort()
    floor = floor_levels[round(.1 * (len(floor_levels) - 1))] if floor_levels else None
    if floor is None: raise ValueError('No source floor frames')
    return crops, full_bytes, digest.hexdigest(), floor


def main():
    SCRATCH.mkdir(parents=True, exist_ok=True)
    if (SCRATCH / 'manifest.json').exists(): raise RuntimeError('Existing corpus preserved; use its receipt')
    with urllib.request.urlopen(RECORD.replace('/records/', '/api/records/'), timeout=30) as r:
        record = json.load(r)
    if record['metadata']['license']['id'] != 'cc-by-4.0': raise RuntimeError('Unverified commercial-use data license')
    files = {f['key']: f for f in record['files']}
    review = json.loads((APP.parents[2] / 'scratch/2026-09-26-motion-courses/quality-review/ostinato-audio-review-receipt.json').read_text())
    for name, expected in review['files'].items():
        if sha((APP / name).read_bytes()) != expected: raise RuntimeError(f'Frozen review changed: {name}')
    freeze = {'record': RECORD, 'license': record['metadata']['license'],
              'authors': record['metadata']['creators'], 'selection': SELECTION,
              'selectedRecordings': SPECS,
              'configSha256': sha((APP / 'assets/config/guitar-observation.v1.json').read_bytes()),
              'reviewedFiles': review['files'], 'selectionFrozenBeforeAudioReplay': True,
              'candidateSourceSha256': {name: sha((APP / name).read_bytes()) for name in
                  ['packages/ostinato_audio/lib/src/pitch/guitar_pitch_observer.dart',
                   'packages/ostinato_audio/lib/src/pitch/guitar_single_note_evaluator.dart',
                   'packages/ostinato_audio/lib/src/pitch/yin.dart',
                   'packages/ostinato_audio/lib/src/gate/audio_confidence_gate.dart']},
              'toolSha256': {name: sha((APP / name).read_bytes()) for name in
                  ['tool/guitar_techs_corpus.py', 'tool/guitar_techs_replay.dart',
                   'tools/test_guitar_techs_corpus.py']},
              'tuningOnThisCorpus': False, 'training': False}
    if (SCRATCH / 'freeze.attempt-1.json').exists():
        freeze['loaderAmendmentBeforeAnyReplay'] = 'identity encoding and bounded same-range retry/network journal after truncated transport; observer/config/annotation selection unchanged'
    save(SCRATCH / 'freeze.json', freeze)
    receipt = {'source': RECORD, 'license': 'cc-by-4.0', 'authors': record['metadata']['creators'],
               'archiveMetadata': [], 'streams': [], 'downloaded': [], 'cleanup': {'state': 'pending'}}
    budget = Budget(SCRATCH / 'network-ranges.json'); recordings = []
    save(SCRATCH / 'download-receipt.json', receipt)
    for player, category, clip, kind in SPECS:
        archive_name = f'{player}_{category}.zip'; metadata = files[archive_name]
        reader = StrictRangeFile(f'{RECORD}/files/{archive_name}', metadata['size'], budget)
        with zipfile.ZipFile(reader) as archive:
            midi_name = f'{player}_{category}/midi/midi_{clip}.mid'
            audio_name = f'{player}_{category}/audio/micamp/micamp_{clip}.wav'
            midi = archive.read(midi_name)
            path = SCRATCH / f'{player}-{category}-{clip}.mid'
            if path.exists(): raise RuntimeError(f'Will not overwrite {path}')
            budget.retained_add(len(midi)); path.write_bytes(midi)
            receipt['downloaded'].append({'path': str(path), 'entry': midi_name, 'sourceZip': reader.url,
                                          'bytes': len(midi), 'sha256': sha(midi), 'kind': 'originalMidi', 'license': 'cc-by-4.0'})
            save(SCRATCH / 'download-receipt.json', receipt)
            events = midi_events(midi)
            info = archive.getinfo(audio_name)
            def on_crop(crop):
                receipt['downloaded'].append({k: crop[k] for k in ('path', 'bytes', 'sha256')} |
                                             {'entry': audio_name, 'sourceZip': reader.url, 'kind': 'originalFormatTimeCrop',
                                              'license': 'cc-by-4.0', 'startFrame': crop['startFrame']})
                save(SCRATCH / 'download-receipt.json', receipt)
            with archive.open(info) as stream:
                reader.prefetch_end = reader.tell() + info.compress_size
                crops, full_size, full_hash, floor = stream_crops(stream, {'events': events, 'kind': kind}, budget,
                                                           f'{player}-{category}-{clip}', on_crop)
            if full_size != info.file_size: raise ValueError('Original streamed entry size mismatch')
            receipt['streams'].append({'entry': audio_name, 'sourceZip': reader.url,
                                       'originalBytes': full_size, 'sha256': full_hash, 'zipCRC32': f'{info.CRC:08x}',
                                       'compressedBytes': info.compress_size, 'wholeEntryPersisted': False,
                                       'transformation': '8192-frame time crops; original rate/format; other RIFF metadata omitted'})
            receipt['archiveMetadata'].append({'name': archive_name, 'size': metadata['size'],
                                               'checksum': metadata['checksum'], 'rangeBytesFetched': reader.fetched})
            recordings.append({'player': player, 'recording': f'{player}-{category}-{clip}', 'kind': kind,
                               'input': 'amplifierMicrophone', 'midiEventCount': len(events),
                               'roomFloorDbfs': floor,
                               'floorMethod': '10th percentile of50ms mono RMS over full original entry; matches GuitarSet offline replay, not device quiet calibration',
                               'midiPath': str(path), 'windows': crops})
            receipt['networkRangeBytes'], receipt['retainedPeakBytes'] = budget.network, budget.peak
            save(SCRATCH / 'download-receipt.json', receipt)
            print(recordings[-1]['recording'], 'MIDIevents', len(events), 'windows', len(crops),
                  'rangeBytes', reader.fetched, 'retained', budget.retained, flush=True)
    save(SCRATCH / 'manifest.json', {'source': RECORD, 'license': 'cc-by-4.0',
                                    'selection': SELECTION, 'recordings': recordings})
    print('network', budget.network, 'peakDisk', budget.peak, 'limit', LIMIT)


if __name__ == '__main__':
    main()
