import 'package:delivery_note_app/models/serial_search_model.dart';

class SerialSearchGroup {
  final String serialNo;
  final List<SerialSearchRecord> entries;

  const SerialSearchGroup({
    required this.serialNo,
    required this.entries,
  });
}

List<SerialSearchGroup> groupSerialSearchRecords(
    List<SerialSearchRecord> records) {
  final map = <String, List<SerialSearchRecord>>{};
  for (final record in records) {
    final key = record.serialNo.toUpperCase();
    map.putIfAbsent(key, () => []).add(record);
  }

  final groups = map.entries.map((e) {
    final entries = List<SerialSearchRecord>.from(e.value)
      ..sort((a, b) {
        final aDate = a.dates;
        final bDate = b.dates;
        if (aDate == null && bDate == null) return 0;
        if (aDate == null) return -1;
        if (bDate == null) return 1;
        return aDate.compareTo(bDate);
      });
    return SerialSearchGroup(serialNo: e.key, entries: entries);
  }).toList();

  groups.sort((a, b) {
    final aDate = _oldestDate(a.entries);
    final bDate = _oldestDate(b.entries);
    if (aDate == null && bDate == null) {
      return a.serialNo.compareTo(b.serialNo);
    }
    if (aDate == null) return -1;
    if (bDate == null) return 1;
    return aDate.compareTo(bDate);
  });

  return groups;
}

DateTime? _oldestDate(List<SerialSearchRecord> entries) {
  DateTime? oldest;
  for (final entry in entries) {
    final date = entry.dates;
    if (date == null) continue;
    if (oldest == null || date.isBefore(oldest)) {
      oldest = date;
    }
  }
  return oldest;
}
