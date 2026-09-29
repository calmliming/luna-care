/// Preferences behind predictions and wording.
class CycleSettings {
  const CycleSettings({
    this.partnerName = '',
    this.cycleLength = defaultCycleLength,
    this.periodLength = defaultPeriodLength,
  });

  /// Reads settings written by [toJson], falling back to defaults for
  /// anything missing or out of range.
  factory CycleSettings.fromJson(Object? json) {
    if (json is! Map) return const CycleSettings();
    final name = json['partnerName'];
    return CycleSettings(
      partnerName: name is String ? name : '',
      cycleLength: _readLength(
        json['cycleLength'],
        cycleLengthRange,
        defaultCycleLength,
      ),
      periodLength: _readLength(
        json['periodLength'],
        periodLengthRange,
        defaultPeriodLength,
      ),
    );
  }

  static const defaultCycleLength = 28;
  static const defaultPeriodLength = 5;
  static const cycleLengthRange = (min: 20, max: 45);
  static const periodLengthRange = (min: 2, max: 10);

  /// What to call her; empty means the plain pronoun.
  final String partnerName;

  /// Used until there are enough records to learn her own rhythm.
  final int cycleLength;
  final int periodLength;

  /// Her name as shown in the app.
  String get displayName =>
      partnerName.trim().isEmpty ? '她' : partnerName.trim();

  CycleSettings copyWith({
    String? partnerName,
    int? cycleLength,
    int? periodLength,
  }) => CycleSettings(
    partnerName: partnerName ?? this.partnerName,
    cycleLength: cycleLength ?? this.cycleLength,
    periodLength: periodLength ?? this.periodLength,
  );

  Map<String, Object?> toJson() => {
    'partnerName': partnerName,
    'cycleLength': cycleLength,
    'periodLength': periodLength,
  };
}

int _readLength(Object? value, ({int min, int max}) range, int fallback) =>
    value is num ? value.toInt().clamp(range.min, range.max) : fallback;
