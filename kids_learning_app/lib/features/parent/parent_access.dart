/// Remembers that a grown-up passed the parent gate.
/// The parent area stays open for a few minutes, then asks again.
class ParentAccess {
  ParentAccess._();

  static DateTime? _openedAt;
  static const _openFor = Duration(minutes: 5);

  static bool get isOpen {
    final at = _openedAt;
    return at != null && DateTime.now().difference(at) < _openFor;
  }

  static void open() => _openedAt = DateTime.now();

  static void close() => _openedAt = null;
}
