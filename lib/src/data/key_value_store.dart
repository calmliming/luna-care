import 'package:shared_preferences/shared_preferences.dart';

/// The slice of a key-value store the app needs, small enough that tests can
/// swap in [MemoryKeyValueStore] for device storage.
abstract interface class KeyValueStore {
  String? getString(String key);
  Future<void> setString(String key, String value);
}

/// Device storage through shared_preferences.
class SharedPreferencesStore implements KeyValueStore {
  SharedPreferencesStore._(this._prefs);

  static Future<SharedPreferencesStore> open(Set<String> keys) async {
    final prefs = await SharedPreferencesWithCache.create(
      cacheOptions: SharedPreferencesWithCacheOptions(allowList: keys),
    );
    return SharedPreferencesStore._(prefs);
  }

  final SharedPreferencesWithCache _prefs;

  @override
  String? getString(String key) => _prefs.getString(key);

  @override
  Future<void> setString(String key, String value) =>
      _prefs.setString(key, value);
}

/// In-memory storage for tests and previews.
class MemoryKeyValueStore implements KeyValueStore {
  MemoryKeyValueStore([Map<String, String>? values]) : _values = {...?values};

  final Map<String, String> _values;

  @override
  String? getString(String key) => _values[key];

  @override
  Future<void> setString(String key, String value) async {
    _values[key] = value;
  }
}
