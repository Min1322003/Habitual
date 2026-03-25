import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

import 'models.dart';

/// Local persistence + domain logic.
///
/// This acts like a "backend" inside the app: UI -> repository -> Hive.
class HabitualRepository {
  HabitualRepository();

  final _uuid = const Uuid();

  late final Box plansBox;
  late final Box overridesBox;
  late final Box journalBox;

  Future<void> init() async {
    plansBox = await Hive.openBox('plans');
    overridesBox = await Hive.openBox('overrides');
    journalBox = await Hive.openBox('journal');
  }

  List<Plan> getAllPlans() {
    return plansBox.values.map((e) => Plan.fromMap(e as Map)).toList();
  }

  Plan? getPlanById(String id) {
    final v = plansBox.get(id);
    if (v == null) return null;
    return Plan.fromMap(v as Map);
  }

  List<JournalEntry> getJournalEntriesForDate(DateTime date) {
    final y = ymd(date);
    final out = <JournalEntry>[];
    for (final v in journalBox.values) {
      final m = v as Map;
      if (m['occurrenceDateYmd'] == y) {
        out.add(JournalEntry.fromMap(m));
      }
    }
    return out;
  }

  List<JournalEntry> getAllJournalEntries() {
    return journalBox.values.map((e) => JournalEntry.fromMap(e as Map)).toList();
  }

  Future<void> upsertPlan({
    required String? planId,
    required String title,
    required int durationMinutes,
    required int startTimeMinutes,
    required List<int> recurrenceWeekdays,
    required String startDateYmd,
    required String? untilDateYmd,
  }) async {
    final id = planId ?? _uuid.v4();
    final plan = Plan(
      id: id,
      title: title,
      durationMinutes: durationMinutes,
      startTimeMinutes: startTimeMinutes,
      recurrenceWeekdays: recurrenceWeekdays,
      startDateYmd: startDateYmd,
      untilDateYmd: untilDateYmd,
    );
    await plansBox.put(id, plan.toMap());
  }

  Future<void> deletePlan(String planId) async {
    await plansBox.delete(planId);

    // Cascade-ish cleanup for MVP.
    final overrideIdsToDelete = overridesBox.values
        .where((e) => (e as Map)['planId'] == planId)
        .map((e) => (e as Map)['id'] as String)
        .toList();
    for (final oid in overrideIdsToDelete) {
      await overridesBox.delete(oid);
    }

    final journalIdsToDelete = journalBox.values
        .where((e) => (e as Map)['planId'] == planId)
        .map((e) => (e as Map)['id'] as String)
        .toList();
    for (final jid in journalIdsToDelete) {
      await journalBox.delete(jid);
    }
  }

  PlanOverride? _getOverrideFor(String planId, String occurrenceDateYmd) {
    // Hive doesn't index; iterate for MVP.
    for (final v in overridesBox.values) {
      final m = v as Map;
      if (m['planId'] == planId && m['occurrenceDateYmd'] == occurrenceDateYmd) {
        return PlanOverride.fromMap(m);
      }
    }
    return null;
  }

  Future<void> setOverride({
    required String planId,
    required String occurrenceDateYmd,
    required int? overrideStartTimeMinutes,
    required bool isDeleted,
  }) async {
    final existing = _getOverrideFor(planId, occurrenceDateYmd);
    if (existing == null) {
      final id = _uuid.v4();
      final o = PlanOverride(
        id: id,
        planId: planId,
        occurrenceDateYmd: occurrenceDateYmd,
        overrideStartTimeMinutes: overrideStartTimeMinutes,
        isDeleted: isDeleted,
      );
      await overridesBox.put(id, o.toMap());
    } else {
      final o = PlanOverride(
        id: existing.id,
        planId: planId,
        occurrenceDateYmd: occurrenceDateYmd,
        overrideStartTimeMinutes: overrideStartTimeMinutes,
        isDeleted: isDeleted,
      );
      await overridesBox.put(existing.id, o.toMap());
    }
  }

  Future<void> deleteOverride(String planId, String occurrenceDateYmd) async {
    final existing = _getOverrideFor(planId, occurrenceDateYmd);
    if (existing == null) return;
    await overridesBox.delete(existing.id);
  }

  /// Occurrences are computed from [Plan] + optional overrides.
  List<PlanOccurrence> getOccurrencesForDate(DateTime date) {
    final y = ymd(date);

    final occurrences = <PlanOccurrence>[];
    for (final p in getAllPlans()) {
      final match = _planAppliesOnDate(p, date);
      if (!match) continue;

      final override = _getOverrideFor(p.id, y);
      if (override?.isDeleted == true) continue;

      final start = override?.overrideStartTimeMinutes ?? p.startTimeMinutes;
      occurrences.add(
        PlanOccurrence(
          planId: p.id,
          occurrenceDateYmd: y,
          title: p.title,
          startTimeMinutes: start,
          durationMinutes: p.durationMinutes,
        ),
      );
    }

    occurrences.sort((a, b) => a.startTimeMinutes.compareTo(b.startTimeMinutes));
    return occurrences;
  }

  bool _planAppliesOnDate(Plan p, DateTime date) {
    final start = dateFromYmd(p.startDateYmd);
    final d = DateTime(date.year, date.month, date.day);
    if (d.isBefore(start)) return false;

    if (p.untilDateYmd != null) {
      final until = dateFromYmd(p.untilDateYmd!);
      if (d.isAfter(until)) return false;
    }

    if (p.recurrenceWeekdays.isEmpty) {
      // One-off => only on the start date.
      return ymd(d) == p.startDateYmd;
    }

    final weekday = weekdayMon1Sun7(d);
    return p.recurrenceWeekdays.contains(weekday);
  }

  JournalEntry? getJournalEntry(String planId, String occurrenceDateYmd) {
    for (final v in journalBox.values) {
      final m = v as Map;
      if (m['planId'] == planId && m['occurrenceDateYmd'] == occurrenceDateYmd) {
        return JournalEntry.fromMap(m);
      }
    }
    return null;
  }

  Future<void> upsertJournalEntry({
    required String planId,
    required String occurrenceDateYmd,
    required String content,
    double? energy,
    double? rewarding,
  }) async {
    final existing = getJournalEntry(planId, occurrenceDateYmd);
    final nowMillis = DateTime.now().millisecondsSinceEpoch;
    final id = existing?.id ?? _uuid.v4();
    final entry = JournalEntry(
      id: id,
      planId: planId,
      occurrenceDateYmd: occurrenceDateYmd,
      content: content,
      energy: energy ?? existing?.energy,
      rewarding: rewarding ?? existing?.rewarding,
      createdAtMillis: existing?.createdAtMillis ?? nowMillis,
      updatedAtMillis: nowMillis,
    );
    await journalBox.put(id, entry.toMap());
  }

  /// Remove a journal entry (so the task appears again as "missed").
  Future<void> deleteJournalEntry({
    required String planId,
    required String occurrenceDateYmd,
  }) async {
    final existing = getJournalEntry(planId, occurrenceDateYmd);
    if (existing == null) return;
    await journalBox.delete(existing.id);
  }
}

/// Pick the occurrence that should be considered "current task" for the time window.
PlanOccurrence? pickCurrentOccurrence({
  required List<PlanOccurrence> occurrencesForDate,
  required DateTime now,
}) {
  final nowYmd = ymd(now);
  if (occurrencesForDate.isEmpty) return null;
  final nowMinutes = minutesOfDayFromHoursAndMinutes(now.hour, now.minute);

  // We expect all occurrences have the same occurrenceDateYmd, but keep it safe.
  final relevant = occurrencesForDate
      .where((o) => o.occurrenceDateYmd == nowYmd)
      .toList();
  if (relevant.isEmpty) return null;

  // Find first occurrence whose [start,end) contains "now".
  return relevant.firstWhere(
    (o) => nowMinutes >= o.startTimeMinutes && nowMinutes < o.endTimeMinutes,
    orElse: () => relevant.firstWhere(
      (o) => o.startTimeMinutes > nowMinutes,
      orElse: () => relevant.last,
    ),
  );
}

