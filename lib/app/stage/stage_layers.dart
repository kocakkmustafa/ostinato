import 'package:flutter/foundation.dart';

/// OST-UX-05c: the layers a handle can open (05d "path" and 05f "setup" bring
/// their own content; the manager already knows all three).
enum StageLayer { other, path, setup }

/// Holds which stage layer is open. Opening a layer first closes the one that
/// is open (one at a time, so glass items stay within the budget of two), and
/// while [locked] (a run is going) nothing opens and nothing stays open.
class StageLayerManager extends ChangeNotifier {
  final List<StageLayer> _open = <StageLayer>[];
  bool _locked = false;

  /// Open layers, oldest first.
  List<StageLayer> get open => List<StageLayer>.unmodifiable(_open);
  bool get isOpen => _open.isNotEmpty;
  StageLayer? get top => _open.isEmpty ? null : _open.last;
  bool get locked => _locked;

  set locked(bool value) {
    if (_locked == value) return;
    _locked = value;
    if (value && _open.isNotEmpty) _open.clear();
    notifyListeners();
  }

  /// False while locked. Opening the open layer again changes nothing.
  bool openLayer(StageLayer layer) {
    if (_locked) return false;
    if (_open.length == 1 && _open.first == layer) return true;
    _open.clear(); // the one that was open closes
    _open.add(layer);
    notifyListeners();
    return true;
  }

  void close() {
    if (_open.isEmpty) return;
    _open.clear();
    notifyListeners();
  }
}
