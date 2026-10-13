import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vocab_flash_test/data/tts_service.dart';
import 'package:vocab_flash_test/session/base_providers.dart';

class _SlowTts implements TtsService {
  final ready = Completer<void>();
  int calls = 0;
  @override
  Future<void> init({String locale = 'en-US'}) {
    calls++;
    return ready.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('home waits for core data but not a stalled speech engine', () async {
    final core = Completer<void>();
    final tts = _SlowTts();
    final container = ProviderContainer(
      overrides: [
        coreInitializationProvider.overrideWith((ref) => core.future),
        ttsServiceProvider.overrideWithValue(tts),
      ],
    );
    addTearDown(container.dispose);
    var ready = false;
    final result = container
        .read(appReadyProvider.future)
        .then((value) => ready = value);
    await Future<void>.delayed(Duration.zero);
    expect(ready, isFalse);
    expect(tts.calls, 0);
    core.complete();
    await result.timeout(const Duration(seconds: 1));
    expect(ready, isTrue);
    expect(tts.calls, 1);
    expect(tts.ready.isCompleted, isFalse);
    tts.ready.complete();
    await container.read(ttsWarmupProvider.future);
  });
  test('failed speech warmup does not fail home readiness', () async {
    final tts = _SlowTts();
    final container = ProviderContainer(
      overrides: [
        coreInitializationProvider.overrideWith((ref) async {}),
        ttsServiceProvider.overrideWithValue(tts),
      ],
    );
    addTearDown(container.dispose);
    expect(await container.read(appReadyProvider.future), isTrue);
    tts.ready.completeError(StateError('no engine'));
    await container.read(ttsWarmupProvider.future);
    expect(await container.read(appReadyProvider.future), isTrue);
  });
  test('core failures still block readiness and can be retried', () async {
    var attempts = 0;
    final tts = _SlowTts()..ready.complete();
    final container = ProviderContainer(
      overrides: [
        coreInitializationProvider.overrideWith((ref) async {
          if (++attempts == 1) throw StateError('disk unavailable');
        }),
        ttsServiceProvider.overrideWithValue(tts),
      ],
    );
    addTearDown(container.dispose);
    await expectLater(
      container.read(appReadyProvider.future),
      throwsStateError,
    );
    container.invalidate(coreInitializationProvider);
    expect(await container.read(appReadyProvider.future), isTrue);
  });
}
