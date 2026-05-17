import 'package:alembic/domain/spike_app_state.dart';
import 'package:rxdart/subjects.dart';

class SpikeAppStateStore {
  SpikeAppStateStore() : _subject = BehaviorSubject<SpikeAppState>.seeded(
          SpikeAppState.initial(),
        );

  final BehaviorSubject<SpikeAppState> _subject;

  Stream<SpikeAppState> get stream => _subject.stream;

  SpikeAppState get value => _subject.value;

  void mutate(SpikeAppState Function(SpikeAppState current) update) {
    _subject.add(update(_subject.value));
  }

  void emit(SpikeAppState next) {
    _subject.add(next);
  }

  Future<void> close() {
    return _subject.close();
  }
}
