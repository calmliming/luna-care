import '../utils/dates.dart';

/// One period, from the day it started to the day it ended, inclusive.
class PeriodRecord {
  PeriodRecord({
    required this.id,
    required DateTime start,
    DateTime? end,
    String? note,
  }) : start = dateOnly(start),
       end = end == null ? null : dateOnly(end),
       note = (note == null || note.trim().isEmpty) ? null : note.trim();

  /// Reads a record written by [toJson]; throws [FormatException] otherwise.
  factory PeriodRecord.fromJson(Object? json) {
    if (json case {'id': final String id, 'start': final String start}) {
      final end = (json as Map)['end'];
      final note = json['note'];
      return PeriodRecord(
        id: id,
        start: _parseDate(start),
        end: end is String ? _parseDate(end) : null,
        note: note is String ? note : null,
      );
    }
    throw FormatException('Not a period record', json);
  }

  final String id;
  final DateTime start;

  /// Last day of the period, or null while it is still going on (or when
  /// nobody remembers when it ended).
  final DateTime? end;

  final String? note;

  /// Length in days counting both ends, or null when [end] is unknown.
  int? get length => end == null ? null : daysBetween(start, end!) + 1;

  PeriodRecord withEnd(DateTime? end) =>
      PeriodRecord(id: id, start: start, end: end, note: note);

  Map<String, Object?> toJson() => {
    'id': id,
    'start': toIsoDate(start),
    if (end case final end?) 'end': toIsoDate(end),
    'note': ?note,
  };

  static int _counter = 0;

  /// A fresh id for a new record.
  static String newId() =>
      '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}'
      '-${(_counter++).toRadixString(36)}';

  @override
  bool operator ==(Object other) =>
      other is PeriodRecord &&
      other.id == id &&
      other.start == start &&
      other.end == end &&
      other.note == note;

  @override
  int get hashCode => Object.hash(id, start, end, note);
}

DateTime _parseDate(String value) => dateOnly(
  DateTime.tryParse(value) ?? (throw FormatException('Not a date', value)),
);
