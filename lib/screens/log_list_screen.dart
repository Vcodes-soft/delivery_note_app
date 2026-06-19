import 'dart:io';
import 'package:delivery_note_app/services/telegram_logger.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

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
      // Logs stored in device storage: /storage/emulated/0/Android/data/<package>/files/Logs/Logs/<date>/
      final logsPath =
          '/storage/emulated/0/Android/data/com.example.delivery_note_app/files/Logs/Logs';

      final logsDirectory = Directory(logsPath);

      debugPrint('=== LOG DEBUG ===');
      debugPrint('Checking: $logsPath');
      debugPrint('Exists: ${await logsDirectory.exists()}');

      if (await logsDirectory.exists()) {
        final allItems = await logsDirectory.list(recursive: true).toList();
        debugPrint('Total items found: ${allItems.length}');
        for (var item in allItems) {
          debugPrint('  - ${item.path}');
        }

        final logFiles =
            allItems.where((f) => f.path.endsWith('.log')).toList();
        debugPrint('Log files: ${logFiles.length}');

        setState(() {
          _logFiles = logFiles;
          _applyFilter();
          _isLoading = false;
        });
      } else {
        debugPrint('Directory does not exist!');
        setState(() {
          _logFiles = [];
          _filteredLogFiles = [];
          _isLoading = false;
        });
      }
    } catch (e, stack) {
      debugPrint('Error loading logs: $e');
      debugPrint('Stack: $stack');
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
        final dateStr = fileName.replaceAll('log_', '').replaceAll('.log', '');
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
            colorScheme: ColorScheme.light(
              primary: Color.fromRGBO(255, 213, 3, 1.0),
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

  Future<void> _viewLogFile(FileSystemEntity file) async {
    final content = await File(file.path).readAsString();

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color.fromRGBO(255, 213, 3, 1.0),
                    Color.fromRGBO(253, 215, 64, 1.0),
                  ],
                ),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.black),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: Text(
                      file.path.split('/').last,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.send, color: Colors.black),
                    onPressed: () {
                      Navigator.pop(context);
                      _showUploadDialog(file);
                    },
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: SelectableText(
                  content,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showUploadDialog(FileSystemEntity file) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _UploadLogDialog(file: file),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Color.fromRGBO(255, 213, 3, 1.0),
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
                                  color: Color.fromRGBO(255, 213, 3, 0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.description,
                                  color: Color.fromRGBO(255, 213, 3, 1.0),
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
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Color.fromRGBO(255, 213, 3, 1.0),
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
                  backgroundColor: Color.fromRGBO(255, 213, 3, 1.0),
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
