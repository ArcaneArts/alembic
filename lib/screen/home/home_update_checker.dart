import 'dart:async';

import 'package:alembic/core/update_controller.dart';
import 'package:alembic/core/update_status.dart';
import 'package:rxdart/rxdart.dart';

class HomeUpdatesHook {
  final UpdateController controller;
  final BehaviorSubject<bool> updateAvailable;

  StreamSubscription<UpdateSnapshot>? _subscription;

  HomeUpdatesHook({required this.controller})
      : updateAvailable =
            BehaviorSubject<bool>.seeded(controller.value.updateAvailable);

  void start() {
    _subscription ??= controller.stream.listen((snapshot) {
      if (updateAvailable.isClosed) {
        return;
      }
      if (updateAvailable.value != snapshot.updateAvailable) {
        updateAvailable.add(snapshot.updateAvailable);
      }
    });
  }

  Future<void> checkNow() => controller.checkNow();

  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
    await updateAvailable.close();
  }
}
