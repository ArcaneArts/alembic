import 'package:arcane/arcane.dart';

extension XFutureListSem on Iterable<Future Function()> {
  Future<List<T>> waitSemaphore<T>(
    int maxSimultaneous, {
    void Function(double)? progress,
  }) async {
    progress?.call(0.0);
    List<Future Function()> tx = toList();
    assert(maxSimultaneous > 0);
    int working = 0;
    List<Future<T>> t = [];
    for (int i = 0; i < length; i++) {
      while (working >= maxSimultaneous) {
        await Future.delayed(const Duration(milliseconds: 100));
      }

      if (working < maxSimultaneous) {
        working++;
        t.add(tx[i]().thenRun((result) => working--) as Future<T>);
      }

      progress?.call((i + 1) / length);
    }

    progress?.call(1.0);
    return await Future.wait(t);
  }
}
