"""Safety/annotation tests for the independent offline data tool."""
import importlib.util
import io
from pathlib import Path
import struct
import unittest

spec = importlib.util.spec_from_file_location('corpus', Path(__file__).parents[1] / 'tool/guitar_techs_corpus.py')
corpus = importlib.util.module_from_spec(spec)
spec.loader.exec_module(corpus)


class Response:
    def __init__(self, status, content_range, data):
        self.status, self.headers, self.data = status, {'Content-Range': content_range}, data
        self.reads = 0
    def __enter__(self): return self
    def __exit__(self, *_): pass
    def read(self, n): self.reads += 1; return self.data[:n]


class CorpusTest(unittest.TestCase):
    def test_ignored_range_never_reads_full_archive_body(self):
        response = Response(200, '', b'full archive')
        reader = corpus.StrictRangeFile('https://invalid.test/source', 100, corpus.Budget(), lambda *_args, **_kwargs: response)
        with self.assertRaises(RuntimeError): reader.read(4)
        self.assertEqual(response.reads, 0)

    def test_wrong_content_range_and_length_refused(self):
        for response in [Response(206, 'bytes0-3/100', b'abcd'), Response(206, 'bytes 0-3/100', b'ab')]:
            reader = corpus.StrictRangeFile('https://invalid.test/source', 100, corpus.Budget(), lambda *_args, **_kwargs: response)
            with self.assertRaises(RuntimeError): reader.read(4)

    def test_budget_stops_before_oversize_request(self):
        budget = corpus.Budget(); budget.network = corpus.LIMIT
        reader = corpus.StrictRangeFile('https://invalid.test/source', 100, budget, lambda *_args, **_kwargs: self.fail('request executed'))
        with self.assertRaises(RuntimeError): reader.read(1)

    def test_midi_tempo_and_running_status(self):
        # Quarter note at120BPM, followed by running-status note-off velocity0.
        track = bytes.fromhex('00ff510307a120009028648360280000ff2f00')
        midi = b'MThd' + struct.pack('>IHHH', 6, 0, 1, 480) + b'MTrk' + struct.pack('>I', len(track)) + track
        notes = corpus.midi_events(midi)
        self.assertEqual(len(notes), 1)
        self.assertEqual(notes[0]['midi'], 40)
        self.assertAlmostEqual(notes[0]['offsetS'], .5)

    def test_selection_uses_annotations_and_excludes_neighbors_and_short_notes(self):
        events = [{'midi': 40, 'track': 1, 'onsetS': 0., 'offsetS': 1.},
                  {'midi': 45, 'track': 2, 'onsetS': 1.5, 'offsetS': 1.7},
                  {'midi': 50, 'track': 3, 'onsetS': 2., 'offsetS': 3.},
                  {'midi': 55, 'track': 4, 'onsetS': 2.1, 'offsetS': 2.8}]
        chosen = corpus.select(events, 44100, 44100*4, 'positive')
        self.assertEqual([c['referenceMidi'] for c in chosen], [[40]])
        self.assertEqual(chosen[0]['startFrame'], round(.25*44100))

    def test_negative_requires_three_stable_distinct_midi_notes(self):
        events = [{'midi': m, 'track': i, 'onsetS': 0., 'offsetS': 1.} for i, m in enumerate([48, 52, 55])]
        self.assertEqual(corpus.select(events, 44100, 44100, 'polyphonicNegative')[0]['referenceMidi'], [48, 52, 55])
        events[2]['midi'] = 48
        self.assertEqual(corpus.select(events, 44100, 44100, 'polyphonicNegative'), [])


if __name__ == '__main__':
    unittest.main()
