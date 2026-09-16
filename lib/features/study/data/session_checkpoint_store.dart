import 'package:shared_preferences/shared_preferences.dart';

import '../domain/session_checkpoint.dart';

class SessionCheckpointStore {
  static const storageKey = 'study_session_checkpoint_v1';
  final SharedPreferences preferences;

  const SessionCheckpointStore(this.preferences);

  SessionCheckpoint? load() =>
      SessionCheckpoint.tryDecode(preferences.getString(storageKey));

  Future<bool> save(SessionCheckpoint checkpoint) =>
      preferences.setString(storageKey, checkpoint.encode());

  Future<bool> clear() => preferences.remove(storageKey);
}
