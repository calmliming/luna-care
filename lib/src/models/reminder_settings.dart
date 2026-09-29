/// When to be reminded that her period is coming. Kept on this phone only:
/// backups leave it out, since a new phone has to grant notifications anew.
class ReminderSettings {
  const ReminderSettings({
    this.enabled = false,
    this.daysBefore = defaultDaysBefore,
    this.minuteOfDay = defaultMinuteOfDay,
  });

  /// Reads settings written by [toJson], falling back to defaults for
  /// anything missing or out of range.
  factory ReminderSettings.fromJson(Object? json) {
    if (json is! Map) return const ReminderSettings();
    return ReminderSettings(
      enabled: json['enabled'] == true,
      daysBefore: _readInt(
        json['daysBefore'],
        daysBeforeRange,
        defaultDaysBefore,
      ),
      minuteOfDay: _readInt(
        json['minuteOfDay'],
        (min: 0, max: 24 * 60 - 1),
        defaultMinuteOfDay,
      ),
    );
  }

  static const defaultDaysBefore = 2;
  static const defaultMinuteOfDay = 9 * 60;
  static const daysBeforeRange = (min: 1, max: 7);

  final bool enabled;

  /// How many days before the predicted start the early reminder comes.
  final int daysBefore;

  /// Time of day every reminder goes off, in minutes after midnight.
  final int minuteOfDay;

  int get hour => minuteOfDay ~/ 60;
  int get minute => minuteOfDay % 60;

  ReminderSettings copyWith({
    bool? enabled,
    int? daysBefore,
    int? minuteOfDay,
  }) => ReminderSettings(
    enabled: enabled ?? this.enabled,
    daysBefore: daysBefore ?? this.daysBefore,
    minuteOfDay: minuteOfDay ?? this.minuteOfDay,
  );

  Map<String, Object?> toJson() => {
    'enabled': enabled,
    'daysBefore': daysBefore,
    'minuteOfDay': minuteOfDay,
  };
}

int _readInt(Object? value, ({int min, int max}) range, int fallback) =>
    value is num ? value.toInt().clamp(range.min, range.max) : fallback;
