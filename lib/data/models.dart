import 'package:flutter/foundation.dart';

/// Minutes since 00:00 (e.g. 9:15 -> 555).
int minutesOfDayFromHoursAndMinutes(int hours, int minutes) {
  return hours * 60 + minutes;
}

String ymd(DateTime date) {
  final d = DateTime(date.year, date.month, date.day);
  return '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

DateTime dateFromYmd(String v) {
  final parts = v.split('-');
  if (parts.length != 3) return DateTime.fromMillisecondsSinceEpoch(0);
  return DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
}

int weekdayMon1Sun7(DateTime date) {
  // DateTime.weekday: Mon=1 .. Sun=7
  return date.weekday;
}

class Plan {
  Plan({
    required this.id,
    required this.title,
    required this.durationMinutes,
    required this.startTimeMinutes,
    required this.recurrenceWeekdays,
    required this.startDateYmd,
    required this.untilDateYmd,
  });

  final String id;
  final String title;

  /// Default start time for the plan (time-of-day only).
  final int startTimeMinutes;
  final int durationMinutes;

  /// Mon=1 ... Sun=7. Empty => one-off.
  final List<int> recurrenceWeekdays;

  /// Date the rule starts applying (inclusive).
  final String startDateYmd;

  /// Null => no end; otherwise inclusive last date.
  final String? untilDateYmd;

  bool get isRecurring => recurrenceWeekdays.isNotEmpty;

  Map<String, Object?> toMap() => {
        'id': id,
        'title': title,
        'durationMinutes': durationMinutes,
        'startTimeMinutes': startTimeMinutes,
        'recurrenceWeekdays': recurrenceWeekdays,
        'startDateYmd': startDateYmd,
        'untilDateYmd': untilDateYmd,
      };

  static Plan fromMap(Map map) {
    return Plan(
      id: map['id'] as String,
      title: map['title'] as String,
      durationMinutes: map['durationMinutes'] as int,
      startTimeMinutes: map['startTimeMinutes'] as int,
      recurrenceWeekdays:
          (map['recurrenceWeekdays'] as List).map((e) => e as int).toList(),
      startDateYmd: map['startDateYmd'] as String,
      untilDateYmd: map['untilDateYmd'] as String?,
    );
  }
}

/// Override or cancellation for a specific occurrence (planId + occurrenceDateYmd).
class PlanOverride {
  PlanOverride({
    required this.id,
    required this.planId,
    required this.occurrenceDateYmd,
    this.overrideStartTimeMinutes,
    this.isDeleted = false,
  });

  final String id;
  final String planId;
  final String occurrenceDateYmd;

  /// If set, replaces the plan's start time for this occurrence.
  final int? overrideStartTimeMinutes;

  /// If true, the occurrence should not be shown (acts like "remove for this day").
  final bool isDeleted;

  Map<String, Object?> toMap() => {
        'id': id,
        'planId': planId,
        'occurrenceDateYmd': occurrenceDateYmd,
        'overrideStartTimeMinutes': overrideStartTimeMinutes,
        'isDeleted': isDeleted,
      };

  static PlanOverride fromMap(Map map) {
    return PlanOverride(
      id: map['id'] as String,
      planId: map['planId'] as String,
      occurrenceDateYmd: map['occurrenceDateYmd'] as String,
      overrideStartTimeMinutes: map['overrideStartTimeMinutes'] as int?,
      isDeleted: (map['isDeleted'] as bool?) ?? false,
    );
  }
}

class JournalEntry {
  JournalEntry({
    required this.id,
    required this.planId,
    required this.occurrenceDateYmd,
    required this.content,
    required this.energy,
    required this.rewarding,
    required this.createdAtMillis,
    required this.updatedAtMillis,
  });

  final String id;
  final String planId;
  final String occurrenceDateYmd;

  final String content;

  /// 0..10 (user-reported). Null if not collected.
  final double? energy;

  /// 0..10 (user-reported). Null if not collected.
  final double? rewarding;
  final int createdAtMillis;
  final int updatedAtMillis;

  DateTime get createdAt => DateTime.fromMillisecondsSinceEpoch(createdAtMillis);
  DateTime get updatedAt => DateTime.fromMillisecondsSinceEpoch(updatedAtMillis);

  Map<String, Object?> toMap() => {
        'id': id,
        'planId': planId,
        'occurrenceDateYmd': occurrenceDateYmd,
        'content': content,
        'energy': energy,
        'rewarding': rewarding,
        'createdAtMillis': createdAtMillis,
        'updatedAtMillis': updatedAtMillis,
      };

  static JournalEntry fromMap(Map map) {
    return JournalEntry(
      id: map['id'] as String,
      planId: map['planId'] as String,
      occurrenceDateYmd: map['occurrenceDateYmd'] as String,
      content: map['content'] as String? ?? '',
      energy: (map['energy'] as num?)?.toDouble(),
      rewarding: (map['rewarding'] as num?)?.toDouble(),
      createdAtMillis: map['createdAtMillis'] as int,
      updatedAtMillis: map['updatedAtMillis'] as int,
    );
  }
}

@immutable
class PlanOccurrence {
  const PlanOccurrence({
    required this.planId,
    required this.occurrenceDateYmd,
    required this.title,
    required this.startTimeMinutes,
    required this.durationMinutes,
  });

  final String planId;
  final String occurrenceDateYmd;
  final String title;
  final int startTimeMinutes;
  final int durationMinutes;

  int get endTimeMinutes => startTimeMinutes + durationMinutes;
}

