import 'dart:async';
import 'dart:io';

/// Coordinates the app's account files within its one Flutter isolate. Reads
/// join writes before directory resolution, so returning to a course cannot
/// read an older snapshot while that store still has a pending save.
final class AccountDataOperations {
  AccountDataOperations(this._resolveDirectory);

  final Future<Directory> Function() _resolveDirectory;
  final _SerialOperations _local = _SerialOperations();
  static final Map<String, _DirectoryOperations> _directories = {};

  static _DirectoryOperations _owner(Directory directory) =>
      _directories.putIfAbsent(
        directory.absolute.uri.normalizePath().toFilePath()
            .replaceAll(RegExp(r'/+'), '/'),
        _DirectoryOperations.new,
      );

  Future<T> run<T>(
    Future<T> Function(Directory directory) operation, {
    bool writing = false,
  }) => _local.run(() async {
    final directory = await _resolveDirectory();
    final owner = _owner(directory);
    // A media prerequisite may hold the erase queue. New writers must reject
    // before joining that queue, while the inner check covers a later retire.
    if (writing && owner.retired) {
      throw StateError('This local account has been deleted');
    }
    return owner.queue.run(() {
      if (writing && owner.retired) {
        throw StateError('This local account has been deleted');
      }
      return operation(directory);
    });
  });

  /// Call only after common-account deletion has been verified. Retirement
  /// is synchronous, including when a writer is still resolving its path.
  /// An admitted write can finish; cleanup then follows it on the same queue.
  /// Keep the retirement marker for this isolate's lifetime even if cleanup
  /// fails, so a receipt retry cannot race with another account-file write.
  static Future<void> delete(
    Directory directory, {
    Future<void>? beforeErase,
  }) {
    final owner = _owner(directory)..retired = true;
    final existing = owner.eraseAttempt;
    if (existing != null && !existing.failed) return existing.future;

    // Publish the attempt before queue/callback work. Repeated cleanup calls
    // join its exact Future and cannot bypass its original media prerequisite.
    final attempt = _EraseAttempt();
    owner.eraseAttempt = attempt;
    final prerequisite = _ErasePrerequisite(beforeErase);
    owner.queue.run(() async {
      await prerequisite.wait();
      if (await directory.exists()) await directory.delete(recursive: true);
    }).then<void>(
      (_) => attempt.completion.complete(),
      onError: (Object error, StackTrace stack) {
        attempt.failed = true;
        attempt.completion.completeError(error, stack);
      },
    );
    return attempt.future;
  }
}

final class _DirectoryOperations {
  final _SerialOperations queue = _SerialOperations();
  bool retired = false;
  _EraseAttempt? eraseAttempt;
}

final class _EraseAttempt {
  final Completer<void> completion = Completer<void>();
  bool failed = false;

  Future<void> get future => completion.future;
}

final class _ErasePrerequisite {
  _ErasePrerequisite(Future<void>? prerequisite)
    : _settled = prerequisite == null
          ? Future<_PrerequisiteOutcome>.value(const _PrerequisiteOutcome())
          : prerequisite.then<_PrerequisiteOutcome>(
              (_) => const _PrerequisiteOutcome(),
              onError: (Object error, StackTrace stack) =>
                  _PrerequisiteOutcome(error: error, stack: stack),
            );

  // The observed Future settles to a value even if the media prerequisite
  // fails while an admitted writer is held. No derived error is left unjoined.
  final Future<_PrerequisiteOutcome> _settled;

  Future<void> wait() async {
    final outcome = await _settled;
    final error = outcome.error;
    if (error != null) Error.throwWithStackTrace(error, outcome.stack!);
  }
}

final class _PrerequisiteOutcome {
  const _PrerequisiteOutcome({this.error, this.stack});

  final Object? error;
  final StackTrace? stack;
}

final class _SerialOperations {
  Future<void>? _pending;

  Future<T> run<T>(Future<T> Function() operation) {
    final pending = _pending;
    final result = pending == null
        ? Future<T>.sync(operation)
        : pending.then((_) => operation());
    // The caller still receives its error. Later reads, writes, and cleanup
    // must remain possible after an I/O failure or rejected progress action.
    _pending = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }
}
