import 'dart:io';
import 'package:delivery_note_app/services/app_logger.dart';
import 'package:delivery_note_app/services/telegram_logger.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

const Color _brandYellow = Color.fromRGBO(255, 213, 3, 1.0);

class LogListScreen extends StatefulWidget {
  const LogListScreen({super.key});

  @override
  State<LogListScreen> createState() => _LogListScreenState();
}

class _LogListScreenState extends State<LogListScreen> {
  List<FileSystemEntity> _logFiles = [];
  List<FileSystemEntity> _filteredLogFiles = [];
  DateTime? _selectedDate;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLogFiles();
  }

  Future<void> _loadLogFiles() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final logsDirectory = await AppLogger.logsDirectory();

      final allItems = await logsDirectory.list().toList();
      final logFiles = allItems.where((f) => f.path.endsWith('.log')).toList();
      logFiles.sort((a, b) => b.path.compareTo(a.path));

      setState(() {
        _logFiles = logFiles;
        _applyFilter();
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading logs: $e');
      setState(() {
        _logFiles = [];
        _filteredLogFiles = [];
        _isLoading = false;
      });
    }
  }

  void _applyFilter() {
    if (_selectedDate == null) {
      _filteredLogFiles = _logFiles;
    } else {
      _filteredLogFiles = _logFiles.where((file) {
        final fileName = file.path.split('/').last;
        final dateStr = fileName.replaceAll('.log', '');
        try {
          final fileDate = DateFormat('ddMMyyyy').parse(dateStr);
          return _isSameDay(fileDate, _selectedDate!);
        } catch (e) {
          return false;
        }
      }).toList();
    }
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: _brandYellow,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _applyFilter();
      });
    }
  }

  void _clearFilter() {
    setState(() {
      _selectedDate = null;
      _applyFilter();
    });
  }

  void _viewLogFile(FileSystemEntity file) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => LogDetailScreen(file: file)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: _brandYellow,
        title: const Text('App Logs', style: TextStyle(color: Colors.black)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black),
            onPressed: _loadLogFiles,
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: _selectDate,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.calendar_today,
                              size: 18, color: Colors.grey.shade600),
                          const SizedBox(width: 8),
                          Text(
                            _selectedDate != null
                                ? DateFormat('dd-MM-yyyy')
                                    .format(_selectedDate!)
                                : 'Filter by date',
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                if (_selectedDate != null)
                  IconButton(
                    icon: Icon(Icons.clear, color: Colors.red.shade700),
                    onPressed: _clearFilter,
                  ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredLogFiles.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.folder_open,
                                size: 64, color: Colors.grey.shade400),
                            const SizedBox(height: 16),
                            Text(
                              'No log files found',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: _filteredLogFiles.length,
                        itemBuilder: (context, index) {
                          final file = _filteredLogFiles[index];
                          final fileName = file.path.split('/').last;

                          return Card(
                            margin: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 4),
                            child: ListTile(
                              leading: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: _brandYellow.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.description,
                                  color: _brandYellow,
                                ),
                              ),
                              title: Text(
                                fileName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                              subtitle: FutureBuilder<FileStat>(
                                future: File(file.path).stat(),
                                builder: (context, snapshot) {
                                  if (snapshot.hasData) {
                                    return Text(
                                      DateFormat('dd-MM-yyyy hh:mm a')
                                          .format(snapshot.data!.modified),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade600,
                                      ),
                                    );
                                  }
                                  return const SizedBox.shrink();
                                },
                              ),
                              trailing: Icon(
                                Icons.arrow_forward_ios,
                                size: 16,
                                color: Colors.grey.shade400,
                              ),
                              onTap: () => _viewLogFile(file),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

class LogDetailScreen extends StatefulWidget {
  final FileSystemEntity file;

  const LogDetailScreen({super.key, required this.file});

  @override
  State<LogDetailScreen> createState() => _LogDetailScreenState();
}

class _LogDetailScreenState extends State<LogDetailScreen> {
  List<_LogRecord> _records = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRecords();
  }

  Future<void> _loadRecords() async {
    final content = await File(widget.file.path).readAsString();
    final records = content
        .split('\n')
        .where((line) => line.trim().isNotEmpty)
        .map(_LogRecord.fromLine)
        .toList()
        .reversed
        .toList();

    if (mounted) {
      setState(() {
        _records = records;
        _isLoading = false;
      });
    }
  }

  void _showUploadDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _UploadLogDialog(file: widget.file),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fileName = widget.file.path.split('/').last;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: _brandYellow,
        title: Text(fileName, style: const TextStyle(color: Colors.black)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.send, color: Colors.black),
            onPressed: _showUploadDialog,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  color: Colors.grey.shade100,
                  child: Text(
                    '${_records.length} record${_records.length == 1 ? '' : 's'}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ),
                Expanded(
                  child: _records.isEmpty
                      ? Center(
                          child: Text(
                            'No records in this file',
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          itemCount: _records.length,
                          itemBuilder: (context, index) =>
                              _LogRecordCard(record: _records[index]),
                        ),
                ),
              ],
            ),
    );
  }
}

/// A single parsed line from a log file, written as tab-delimited fields by
/// [AppLogger]: timestamp, level, provider, screen, function, action, details.
class _LogRecord {
  final String timestamp;
  final String level;
  final String provider;
  final String screen;
  final String function;
  final String action;
  final String details;

  _LogRecord({
    required this.timestamp,
    required this.level,
    required this.provider,
    required this.screen,
    required this.function,
    required this.action,
    required this.details,
  });

  factory _LogRecord.fromLine(String line) {
    final parts = line.split('\t');
    String field(int i) => parts.length > i ? parts[i] : '';
    return _LogRecord(
      timestamp: field(0),
      level: field(1).isEmpty ? 'INFO' : field(1),
      provider: field(2),
      screen: field(3),
      function: field(4),
      action: field(5),
      details: parts.length > 6 ? parts.sublist(6).join('\t') : '',
    );
  }

  bool get isError => level.toUpperCase() == 'ERROR';

  bool get isSuccess =>
      !isError &&
      (action.toLowerCase().contains('success') ||
          details.toLowerCase().contains('success'));
}

class _LogRecordCard extends StatelessWidget {
  final _LogRecord record;

  const _LogRecordCard({required this.record});

  Color get _statusColor {
    if (record.isError) return Colors.red.shade600;
    if (record.isSuccess) return Colors.green.shade600;
    return Colors.blueGrey.shade500;
  }

  String get _statusLabel {
    if (record.isError) return 'ERROR';
    if (record.isSuccess) return 'SUCCESS';
    return 'INFO';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(10),
        border: Border(left: BorderSide(color: _statusColor, width: 4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  record.action,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 14),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: _statusColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _statusLabel,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: _statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Provider: ${record.provider} | Screen: ${record.screen} | Function: ${record.function}',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          ),
          if (record.details.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(6),
              ),
              child: SelectableText(
                record.details,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
              ),
            ),
          ],
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              record.timestamp,
              style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
            ),
          ),
        ],
      ),
    );
  }
}

class _UploadLogDialog extends StatefulWidget {
  final FileSystemEntity file;

  const _UploadLogDialog({required this.file});

  @override
  State<_UploadLogDialog> createState() => _UploadLogDialogState();
}

class _UploadLogDialogState extends State<_UploadLogDialog> {
  double _progress = 0;
  bool _isUploading = true;
  bool _isComplete = false;
  String _status = 'Preparing...';

  @override
  void initState() {
    super.initState();
    _uploadFile();
  }

  Future<void> _uploadFile() async {
    try {
      await TelegramLogger.sendFile(
        File(widget.file.path),
        onProgress: (progress) {
          if (mounted) {
            setState(() {
              _progress = progress;
              _status = 'Uploading: ${progress.toStringAsFixed(0)}%';
            });
          }
        },
      );

      if (mounted) {
        setState(() {
          _isComplete = true;
          _isUploading = false;
          _status = 'Upload complete!';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isComplete = false;
          _isUploading = false;
          _status = 'Upload failed: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _isComplete ? 'Success!' : 'Uploading Log',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: _isComplete ? Colors.green : Colors.black,
              ),
            ),
            const SizedBox(height: 24),
            if (_isUploading) ...[
              SizedBox(
                width: 100,
                height: 100,
                child: CircularProgressIndicator(
                  value: _progress / 100,
                  strokeWidth: 8,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    _brandYellow,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '${_progress.toStringAsFixed(0)}%',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ] else ...[
              Icon(
                _isComplete ? Icons.check_circle : Icons.error,
                size: 64,
                color: _isComplete ? Colors.green : Colors.red,
              ),
            ],
            const SizedBox(height: 16),
            Text(
              _status,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _brandYellow,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(_isComplete ? 'Done' : 'Close'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
