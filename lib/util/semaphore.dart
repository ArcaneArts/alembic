extension XFutureListSem on Iterable<Future Function()> {
  Future<List<T>> waitSemaphore<T>(
    int maxSimultaneous, {
    void Function(double)? progress,
  }) async {
    List<Future Function()> tasks = toList();
    int total = tasks.length;
    if (total == 0) {
      progress?.call(1);
      return <T>[];
    }

    int cursor = 0;
    int completed = 0;
    List<T> results = <T>[];

    progress?.call(0);

    Future<void> worker() async {
      while (true) {
        Future Function()? task;
        if (cursor < total) {
          task = tasks[cursor];
          cursor++;
        } else {
          return;
        }

        T result = await task() as T;
        results.add(result);
        completed++;
        progress?.call(completed / total);
      }
    }

    int workers = maxSimultaneous < 1 ? 1 : maxSimultaneous;
    await Future.wait(
      List<Future<void>>.generate(workers, (_) => worker()),
    );

    progress?.call(1);
    return results;
  }
}
