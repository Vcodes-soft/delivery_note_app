import 'dart:async';
import 'package:delivery_note_app/providers/order_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:delivery_note_app/providers/purchase_order_provider.dart';
import 'package:delivery_note_app/utils/app_alerts.dart';
import 'package:delivery_note_app/utils/app_constants.dart';
import 'package:delivery_note_app/services/telegram_logger.dart';
import 'package:lottie/lottie.dart';

class AddLotScreen extends StatefulWidget {
  final String soNumber;
  final String itemCode;
  final double orderedQty;
  final double availableStock;

  const AddLotScreen({
    super.key,
    required this.soNumber,
    required this.itemCode,
    required this.orderedQty,
    required this.availableStock,
  });

  @override
  State<AddLotScreen> createState() => _AddLotScreenState();
}

class _AddLotScreenState extends State<AddLotScreen> {
  final TextEditingController _serialController = TextEditingController();
  final TextEditingController _editSerialController = TextEditingController();
  final TextEditingController _keystrokeScanController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _keystrokeScanFocusNode = FocusNode();
  final FocusNode _manualEntryFocusNode = FocusNode();
  final FocusNode _editSerialFocusNode = FocusNode();
  bool _isScanning = false;
  bool _isExpanded = false;
  String? _editingSerialNo;
  Timer? _scanDebounceTimer;
  bool _isProcessingScan = false;

  @override
  void initState() {
    super.initState();
    // Ensure widget is mounted before starting scanning
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        if (AppConstants.scanningMode == 'keystroke') {
          _initializeKeystrokeScanning();
        } else {
          _startContinuousScanning();
        }
      }
    });
  }


  void _initializeKeystrokeScanning() {
    // Focus the invisible text field for keystroke scanning
    _keystrokeScanFocusNode.requestFocus();
    SystemChannels.textInput.invokeMethod('TextInput.hide');

    // Keep the field focused, but allow manual entry to take focus
    _keystrokeScanFocusNode.addListener(() {
      if (!_keystrokeScanFocusNode.hasFocus) {
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted && !_manualEntryFocusNode.hasFocus && !_editSerialFocusNode.hasFocus) {
            // Only regain focus if manual entry and edit are not being used
            _keystrokeScanFocusNode.requestFocus();
            SystemChannels.textInput.invokeMethod('TextInput.hide');
          }
        });
      }
    });

    setState(() => _isScanning = true);
  }

  void _returnFocusToScanner() {
    if (AppConstants.scanningMode == 'keystroke' && mounted) {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted && !_manualEntryFocusNode.hasFocus && !_editSerialFocusNode.hasFocus) {
          _keystrokeScanFocusNode.requestFocus();
          SystemChannels.textInput.invokeMethod('TextInput.hide');
        }
      });
    }
  }

  @override
  void dispose() {
    _scanDebounceTimer?.cancel();
    _stopContinuousScanning();
    _scrollController.dispose();
    _serialController.dispose();
    _editSerialController.dispose();
    _keystrokeScanController.dispose();
    _keystrokeScanFocusNode.dispose();
    _manualEntryFocusNode.dispose();
    _editSerialFocusNode.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients && mounted) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (AppConstants.scanningMode == 'datawedge') {
      final orderProvider = Provider.of<OrderProvider>(context, listen: false);
      // Now you can safely access Provider here
      orderProvider.addListener(_handleScanUpdate);
    }
  }

  Future<void> _startContinuousScanning() async {
    // Ensure widget is mounted before accessing Provider
    if (mounted) {
      final orderProvider = Provider.of<OrderProvider>(context, listen: false);
      try {
        setState(() => _isScanning = true);
        await orderProvider.startScanning();
        orderProvider.addListener(_handleScanUpdate);
      } catch (e, stackTrace) {
        if (mounted) {
          setState(() => _isScanning = false);
        }
        await TelegramLogger.sendLog("❌ [AddLotScreen] Failed to start continuous scanning\nError: $e\nStack: $stackTrace");
        AppAlerts.appToast(message: 'Failed to start scanner: ${e.toString()}');
      }
    }
  }

  Future<void> _stopContinuousScanning() async {
    try {
      if (AppConstants.scanningMode == 'keystroke') {
        // For keystroke mode, just unfocus the field
        _keystrokeScanFocusNode.unfocus();
        if (mounted) {
          setState(() => _isScanning = false);
        }
      } else {
        final orderProvider = Provider.of<OrderProvider>(context, listen: false);
        orderProvider.removeListener(_handleScanUpdate);
        try {
          await orderProvider.stopScanner();
        } catch (e, stackTrace) {
          debugPrint("Error stopping scanner: $e");
          await TelegramLogger.sendLog("❌ [AddLotScreen] Error stopping scanner\nError: $e\nStack: $stackTrace");
        }
        if (mounted) {
          setState(() => _isScanning = false);
        }
      }
    } catch (e, stackTrace) {
      await TelegramLogger.sendLog("❌ [AddLotScreen] Error in _stopContinuousScanning\nError: $e\nStack: $stackTrace");
    }
  }

  void _handleScanUpdate() {
    if (!mounted) return;

    final orderProvider = Provider.of<OrderProvider>(context, listen: false);
    if (orderProvider.scannedBarcode != null &&
        orderProvider.scannedBarcode!.isNotEmpty) {
      _handleScannedBarcode(context, orderProvider.scannedBarcode!);
      orderProvider.clearScannedBarcode();
    }
  }

  Future<void> _handleScannedBarcode(BuildContext context, String barcode) async {
    try {
      await _addSerial(context, barcode);
    } catch (e) {
      if (mounted) {
        AppAlerts.appToast(message: 'Error handling barcode: ${e.toString()}');
      }
    }
  }

  Future<void> _processKeystrokeScan(String scannedValue) async {
    if (_isProcessingScan || scannedValue.isEmpty) return;
    
    _isProcessingScan = true;
    _scanDebounceTimer?.cancel();
    
    try {
      await _handleScannedBarcode(context, scannedValue);
      if (mounted) {
        _keystrokeScanController.clear();
        // Ensure focus is maintained for continuous scanning
        Future.delayed(const Duration(milliseconds: 10), () {
          if (mounted && !_manualEntryFocusNode.hasFocus && !_editSerialFocusNode.hasFocus) {
            _keystrokeScanFocusNode.requestFocus();
          }
        });
      }
    } catch (e) {
      if (mounted) {
        AppAlerts.appToast(message: 'Error processing scan: ${e.toString()}');
      }
    } finally {
      _isProcessingScan = false;
    }
  }

  Future<void> _addSerial(BuildContext context, String serialNo) async {
    final orderProvider = Provider.of<OrderProvider>(context, listen: false);
    try {
      await orderProvider.addSerialToItem(
        soNumber: widget.soNumber,
        itemCode: widget.itemCode,
        serialNo: serialNo,
      );
      if (mounted) {
        _serialController.clear();
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        AppAlerts.appToast(message: e.toString());
      }
    }
  }

  void _removeSerial(BuildContext context, String serialNo) {
    final orderProvider = Provider.of<OrderProvider>(context, listen: false);
    try {
      orderProvider.removeSerialFromItem(
        soNumber: widget.soNumber,
        itemCode: widget.itemCode,
        serialNo: serialNo,
      );
    } catch (e) {
      if (mounted) {
        AppAlerts.appToast(message: e.toString());
      }
    }
  }

  void _startEditingSerial(String serialNo) {
    if (!mounted) return;
    setState(() {
      _editingSerialNo = serialNo;
      _editSerialController.text = serialNo;
    });

    // Focus on the edit field and show keyboard
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        _editSerialFocusNode.requestFocus();
        SystemChannels.textInput.invokeMethod('TextInput.show');
      }
    });
  }

  void _cancelEditing() {
    if (!mounted) return;
    setState(() {
      _editingSerialNo = null;
      _editSerialController.clear();
    });

    // Return focus to scanner field
    _returnFocusToScanner();
  }

  void _saveEditedSerial() {
    if (!mounted ||
        _editingSerialNo == null ||
        _editSerialController.text.isEmpty) return;

    final orderProvider = Provider.of<OrderProvider>(context, listen: false);
    try {
      // First remove the old serial
      orderProvider.removeSerialFromItem(
        soNumber: widget.soNumber,
        itemCode: widget.itemCode,
        serialNo: _editingSerialNo!,
      );

      // Then add the new one
      orderProvider.addSerialToItem(
        soNumber: widget.soNumber,
        itemCode: widget.itemCode,
        serialNo: _editSerialController.text,
      );

      if (mounted) {
        setState(() {
          _editingSerialNo = null;
          _editSerialController.clear();
        });

        // Return focus to scanner field
        _returnFocusToScanner();
      }
    } catch (e) {
      if (mounted) {
        AppAlerts.appToast(message: 'Failed to update serial: ${e.toString()}');
      }
    }
  }

  // Method to validate duplicates and handle navigation
  Future<bool> _validateAndNavigateBack(BuildContext context) async {
    final orderProvider = Provider.of<OrderProvider>(context, listen: false);

    // Check for duplicates before proceeding
    final hasDuplicates = orderProvider.hasDuplicateSerialsInItem(
      soNumber: widget.soNumber,
      itemCode: widget.itemCode,
    );

    if (hasDuplicates) {
      // Show alert about duplicates with positions
      final duplicatesWithPositions =
      orderProvider.getDuplicateSerialsWithPositions(
        soNumber: widget.soNumber,
        itemCode: widget.itemCode,
      );

      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Duplicate Serial Numbers'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                    'The following serial numbers are duplicated:'),
                const SizedBox(height: 10),
                ...duplicatesWithPositions.entries.map((entry) {
                  final serial = entry.key;
                  final positions = entry.value;
                  return Text(
                    '• $serial (positions: ${positions.join(', ')})',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold),
                  );
                }).toList(),
                const SizedBox(height: 10),
                const Text(
                    'Please remove duplicates before proceeding.'),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return false; // Don't allow navigation
    }

    // If no duplicates, allow navigation
    await _stopContinuousScanning();
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final orderProvider = Provider.of<OrderProvider>(context);
    final order = orderProvider.getSalesOrderById(widget.soNumber);
    final item = order?.items.firstWhere(
          (i) => i.itemCode == widget.itemCode,
      orElse: () => throw Exception('Item not found'),
    );

    return PopScope(
      canPop: false,
      onPopInvoked: (bool didPop) async {
        if (didPop) return;

        // Validate before allowing back navigation
        final canNavigate = await _validateAndNavigateBack(context);
        if (canNavigate && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Scan Serial Numbers'),
          leading: IconButton(
              onPressed: () async {
                // Validate before allowing back navigation
                final canNavigate = await _validateAndNavigateBack(context);
                if (canNavigate && context.mounted) {
                  Navigator.of(context).pop();
                }
              },
              icon: Icon(Icons.arrow_back_ios)),
          actions: [
            TextButton(
              onPressed: () async {
                // Validate before allowing back navigation
                final canNavigate = await _validateAndNavigateBack(context);
                if (canNavigate && context.mounted) {
                  Navigator.of(context).pop();
                }
              },
              child: const Text("Done"),
            ),
          ],
        ),
        body: GestureDetector(
          onTap: () {
            // When user taps anywhere on the screen, return focus to scanner
            if (AppConstants.scanningMode == 'keystroke' &&
                !_manualEntryFocusNode.hasFocus &&
                !_editSerialFocusNode.hasFocus) {
              _returnFocusToScanner();
            }
          },
          behavior: HitTestBehavior.translucent,
          child: SingleChildScrollView(
            controller: _scrollController,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [


                // Item information section
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Item Details',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 8),
                        InkWell(
                          onTap: () {
                            if (mounted) {
                              setState(() {
                                _isExpanded = !_isExpanded;
                              });
                            }
                          },
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item?.itemName ?? '',
                                maxLines: _isExpanded ? null : 2,
                                overflow: _isExpanded
                                    ? TextOverflow.clip
                                    : TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 16,
                                ),
                              ),
                              if (!_isExpanded &&
                                  (item?.itemName.length ?? 0) > 50)
                                const Text(
                                  'View more',
                                  style: TextStyle(
                                    color: Colors.blue,
                                    fontSize: 12,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Text('Item Code: ',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                            Text(item?.itemCode ?? ''),
                          ],
                        ),
                        Row(
                          children: [
                            const Text('Ordered Qty: ',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                            Text('${widget.orderedQty}'),
                          ],
                        ),
                        Row(
                          children: [
                            const Text('Available Stock: ',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                            Text('${widget.availableStock}'),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Scanner status indicator with Lottie animation
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 50,
                          height: 50,
                          child: Lottie.asset(
                            'assets/animated_icon/scanner.json',
                            animate: _isScanning,
                            repeat: _isScanning,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _isScanning
                                    ? 'Scanner is active'
                                    : 'Scanner is ready',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: _isScanning ? Colors.green : Colors.grey,
                                ),
                              ),
                              Text(
                                _isScanning
                                    ? 'Scanning for serial numbers...'
                                    : 'Tap to scan',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.blue[700],
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${item!.serials.length}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Manual entry section
                const Text(
                  'Manual Entry',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _serialController,
                  focusNode: _manualEntryFocusNode,
                  decoration: InputDecoration(
                    labelText: 'Serial Number',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.add),
                      onPressed: () {
                        if (_serialController.text.isNotEmpty) {
                          _addSerial(context, _serialController.text);
                          // Return focus to scanner field if in keystroke mode
                          if (AppConstants.scanningMode == 'keystroke') {
                            _returnFocusToScanner();
                          }
                        }
                      },
                    ),
                  ),
                  onTap: () {
                    // Allow keyboard to show for manual entry
                    if (AppConstants.scanningMode == 'keystroke') {
                      Future.delayed(const Duration(milliseconds: 50), () {
                        SystemChannels.textInput.invokeMethod('TextInput.show');
                      });
                    }
                  },
                  onSubmitted: (value) {
                    if (_serialController.text.isNotEmpty) {
                      _addSerial(context, value);
                    }
                    // Return focus to scanner field if in keystroke mode
                    if (AppConstants.scanningMode == 'keystroke') {
                      _returnFocusToScanner();
                    }
                  },
                ),

                const SizedBox(height: 20),

                // Scanned serials list
                if (item!.serials.isNotEmpty) ...[
                  const Text(
                    'Scanned Serials',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: item.serials.length,
                    itemBuilder: (context, index) {
                      final serial = item.serials[index];
                      if (_editingSerialNo == serial.serialNo) {
                        return Card(
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Column(
                              children: [
                                TextField(
                                  controller: _editSerialController,
                                  focusNode: _editSerialFocusNode,
                                  decoration: InputDecoration(
                                    labelText: 'Edit Serial',
                                    border: const OutlineInputBorder(),
                                    suffixIcon: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.check,
                                              color: Colors.green),
                                          onPressed: _saveEditedSerial,
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.close,
                                              color: Colors.red),
                                          onPressed: _cancelEditing,
                                        ),
                                      ],
                                    ),
                                  ),
                                  onSubmitted: (value) {
                                    _saveEditedSerial();
                                  },
                                ),
                              ],
                            ),
                          ),
                        );
                      } else {
                        return Card(
                          child: ListTile(
                            leading: Text('${index + 1}.'),
                            title: Text(serial.serialNo),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon:
                                  const Icon(Icons.edit, color: Colors.blue),
                                  onPressed: () =>
                                      _startEditingSerial(serial.serialNo),
                                ),
                                IconButton(
                                  icon:
                                  const Icon(Icons.delete, color: Colors.red),
                                  onPressed: () =>
                                      _removeSerial(context, serial.serialNo),
                                ),
                              ],
                            ),
                          ),
                        );
                      }
                    },
                  ),
                ],


                // Invisible TextField for keystroke scanning
                if (AppConstants.scanningMode == 'keystroke')
                  SizedBox(
                    height: 0,
                    width: 0,
                    child: Focus(
                      onFocusChange: (hasFocus) {
                        if (hasFocus) {
                          SystemChannels.textInput.invokeMethod('TextInput.hide');
                        }
                      },
                      child: TextFormField(
                        controller: _keystrokeScanController,
                        focusNode: _keystrokeScanFocusNode,
                        showCursor: false,
                        enableInteractiveSelection: false,
                        keyboardType: TextInputType.none,
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                        ),
                        style: const TextStyle(fontSize: 0, height: 0),
                        onChanged: (value) {
                          // Debounce keystroke input to prevent rapid scanning issues
                          _scanDebounceTimer?.cancel();
                          _scanDebounceTimer = Timer(const Duration(milliseconds: 50), () {
                            if (mounted && value.isNotEmpty) {
                              // Check if the value ends with Enter (common in barcode scanners)
                              if (value.endsWith('\n') || value.endsWith('\r')) {
                                _processKeystrokeScan(value.trim());
                              }
                            }
                          });
                        },
                        onEditingComplete: () {
                          // This is called when Enter is pressed
                          final scannedValue = _keystrokeScanController.text.trim();
                          if (scannedValue.isNotEmpty && !_isProcessingScan) {
                            _processKeystrokeScan(scannedValue);
                          }
                        },
                        onFieldSubmitted: (value) {
                          // This is also called when Enter is pressed - prevent duplicate processing
                          final scannedValue = value.trim();
                          if (scannedValue.isNotEmpty && !_isProcessingScan) {
                            _processKeystrokeScan(scannedValue);
                          }
                        },
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class POAddLotScreen extends StatefulWidget {
  final String poNumber;
  final String itemCode;
  final double orderedQty;
  final double availableStock;

  const POAddLotScreen({
    super.key,
    required this.poNumber,
    required this.itemCode,
    required this.orderedQty,
    required this.availableStock,
  });

  @override
  State<POAddLotScreen> createState() => _POAddLotScreenState();
}

class _POAddLotScreenState extends State<POAddLotScreen> {
  final TextEditingController _serialController = TextEditingController();
  final TextEditingController _editSerialController = TextEditingController();
  final TextEditingController _keystrokeScanController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _keystrokeScanFocusNode = FocusNode();
  final FocusNode _manualEntryFocusNode = FocusNode();
  final FocusNode _editSerialFocusNode = FocusNode();
  bool _isScanning = false;
  bool _isExpanded = false;
  String? _editingSerialNo;
  Timer? _scanDebounceTimer;
  bool _isProcessingScan = false;

  @override
  void initState() {
    super.initState();
    // Ensure widget is mounted before starting scanning
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        if (AppConstants.scanningMode == 'keystroke') {
          _initializeKeystrokeScanning();
        } else {
          _startContinuousScanning();
        }
      }
    });
  }


  void _initializeKeystrokeScanning() {
    // Focus the invisible text field for keystroke scanning
    _keystrokeScanFocusNode.requestFocus();
    SystemChannels.textInput.invokeMethod('TextInput.hide');

    // Keep the field focused, but allow manual entry to take focus
    _keystrokeScanFocusNode.addListener(() {
      if (!_keystrokeScanFocusNode.hasFocus) {
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted && !_manualEntryFocusNode.hasFocus && !_editSerialFocusNode.hasFocus) {
            // Only regain focus if manual entry and edit are not being used
            _keystrokeScanFocusNode.requestFocus();
            SystemChannels.textInput.invokeMethod('TextInput.hide');
          }
        });
      }
    });

    setState(() => _isScanning = true);
  }

  void _returnFocusToScanner() {
    if (AppConstants.scanningMode == 'keystroke' && mounted) {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted && !_manualEntryFocusNode.hasFocus && !_editSerialFocusNode.hasFocus) {
          _keystrokeScanFocusNode.requestFocus();
          SystemChannels.textInput.invokeMethod('TextInput.hide');
        }
      });
    }
  }

  @override
  void dispose() {
    _scanDebounceTimer?.cancel();
    _stopContinuousScanning();
    _scrollController.dispose();
    _serialController.dispose();
    _editSerialController.dispose();
    _keystrokeScanController.dispose();
    _keystrokeScanFocusNode.dispose();
    _manualEntryFocusNode.dispose();
    _editSerialFocusNode.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients && mounted) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (AppConstants.scanningMode == 'datawedge') {
      final orderProvider = Provider.of<PurchaseOrderProvider>(context, listen: false);
      // Now you can safely access Provider here
      orderProvider.addListener(_handleScanUpdate);
    }
  }

  Future<void> _startContinuousScanning() async {
    // Ensure widget is mounted before accessing Provider
    if (mounted) {
      final orderProvider = Provider.of<PurchaseOrderProvider>(context, listen: false);
      try {
        setState(() => _isScanning = true);
        await orderProvider.startScanning();
        orderProvider.addListener(_handleScanUpdate);
      } catch (e, stackTrace) {
        if (mounted) {
          setState(() => _isScanning = false);
        }
        await TelegramLogger.sendLog("❌ [POAddLotScreen] Failed to start continuous scanning\nError: $e\nStack: $stackTrace");
        AppAlerts.appToast(message: 'Failed to start scanner: ${e.toString()}');
      }
    }
  }

  Future<void> _stopContinuousScanning() async {
    try {
      if (AppConstants.scanningMode == 'keystroke') {
        // For keystroke mode, just unfocus the field
        _keystrokeScanFocusNode.unfocus();
        if (mounted) {
          setState(() => _isScanning = false);
        }
      } else {
        final orderProvider = Provider.of<PurchaseOrderProvider>(context, listen: false);
        orderProvider.removeListener(_handleScanUpdate);
        try {
          await orderProvider.stopScanner();
        } catch (e, stackTrace) {
          debugPrint("Error stopping scanner: $e");
          await TelegramLogger.sendLog("❌ [POAddLotScreen] Error stopping scanner\nError: $e\nStack: $stackTrace");
        }
        if (mounted) {
          setState(() => _isScanning = false);
        }
      }
    } catch (e, stackTrace) {
      await TelegramLogger.sendLog("❌ [POAddLotScreen] Error in _stopContinuousScanning\nError: $e\nStack: $stackTrace");
    }
  }

  void _handleScanUpdate() {
    if (!mounted) return;

    final orderProvider = Provider.of<PurchaseOrderProvider>(context, listen: false);
    if (orderProvider.scannedBarcode != null &&
        orderProvider.scannedBarcode!.isNotEmpty) {
      _handleScannedBarcode(context, orderProvider.scannedBarcode!);
      orderProvider.clearScannedBarcode();
    }
  }

  Future<void> _handleScannedBarcode(BuildContext context, String barcode) async {
    try {
      await _addSerial(context, barcode);
    } catch (e, stackTrace) {
      if (mounted) {
        await TelegramLogger.sendLog("❌ [POAddLotScreen] Error handling barcode: $barcode\nError: $e\nStack: $stackTrace");
        AppAlerts.appToast(message: 'Error handling barcode: ${e.toString()}');
      }
    }
  }

  Future<void> _processKeystrokeScan(String scannedValue) async {
    if (_isProcessingScan || scannedValue.isEmpty) return;
    
    _isProcessingScan = true;
    _scanDebounceTimer?.cancel();
    
    try {
      await _handleScannedBarcode(context, scannedValue);
      if (mounted) {
        _keystrokeScanController.clear();
        // Ensure focus is maintained for continuous scanning
        Future.delayed(const Duration(milliseconds: 10), () {
          if (mounted && !_manualEntryFocusNode.hasFocus && !_editSerialFocusNode.hasFocus) {
            _keystrokeScanFocusNode.requestFocus();
          }
        });
      }
    } catch (e, stackTrace) {
      if (mounted) {
        await TelegramLogger.sendLog("❌ [POAddLotScreen] Error processing keystroke scan: $scannedValue\nError: $e\nStack: $stackTrace");
        AppAlerts.appToast(message: 'Error processing scan: ${e.toString()}');
      }
    } finally {
      _isProcessingScan = false;
    }
  }

  Future<void> _addSerial(BuildContext context, String serialNo) async {
    final orderProvider = Provider.of<PurchaseOrderProvider>(context, listen: false);
    try {
      await orderProvider.addSerialToItem(
        poNumber: widget.poNumber,
        itemCode: widget.itemCode,
        serialNo: serialNo,
      );
      if (mounted) {
        _serialController.clear();
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        AppAlerts.appToast(message: e.toString());
      }
    }
  }

  void _removeSerial(BuildContext context, String serialNo) {
    final orderProvider = Provider.of<PurchaseOrderProvider>(context, listen: false);
    try {
      orderProvider.removeSerialFromItem(
        poNumber: widget.poNumber,
        itemCode: widget.itemCode,
        serialNo: serialNo,
      );
    } catch (e) {
      if (mounted) {
        AppAlerts.appToast(message: e.toString());
      }
    }
  }

  void _startEditingSerial(String serialNo) {
    if (!mounted) return;
    setState(() {
      _editingSerialNo = serialNo;
      _editSerialController.text = serialNo;
    });

    // Focus on the edit field and show keyboard
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        _editSerialFocusNode.requestFocus();
        SystemChannels.textInput.invokeMethod('TextInput.show');
      }
    });
  }

  void _cancelEditing() {
    if (!mounted) return;
    setState(() {
      _editingSerialNo = null;
      _editSerialController.clear();
    });

    // Return focus to scanner field
    _returnFocusToScanner();
  }

  void _saveEditedSerial() {
    if (!mounted ||
        _editingSerialNo == null ||
        _editSerialController.text.isEmpty) return;

    final orderProvider = Provider.of<PurchaseOrderProvider>(context, listen: false);
    try {
      // First remove the old serial
      orderProvider.removeSerialFromItem(
        poNumber: widget.poNumber,
        itemCode: widget.itemCode,
        serialNo: _editingSerialNo!,
      );

      // Then add the new one
      orderProvider.addSerialToItem(
        poNumber: widget.poNumber,
        itemCode: widget.itemCode,
        serialNo: _editSerialController.text,
      );

      if (mounted) {
        setState(() {
          _editingSerialNo = null;
          _editSerialController.clear();
        });

        // Return focus to scanner field
        _returnFocusToScanner();
      }
    } catch (e) {
      if (mounted) {
        AppAlerts.appToast(message: 'Failed to update serial: ${e.toString()}');
      }
    }
  }

  // Method to validate duplicates and handle navigation
  Future<bool> _validateAndNavigateBack(BuildContext context) async {
    final orderProvider = Provider.of<PurchaseOrderProvider>(context, listen: false);

    // Check for duplicates before proceeding
    final hasDuplicates = orderProvider.hasDuplicateSerialsInItem(
      poNumber: widget.poNumber,
      itemCode: widget.itemCode,
    );

    if (hasDuplicates) {
      // Show alert about duplicates with positions
      final duplicatesWithPositions =
      orderProvider.getDuplicateSerialsWithPositions(
        poNumber: widget.poNumber,
        itemCode: widget.itemCode,
      );

      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Duplicate Serial Numbers'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                    'The following serial numbers are duplicated:'),
                const SizedBox(height: 10),
                ...duplicatesWithPositions.entries.map((entry) {
                  final serial = entry.key;
                  final positions = entry.value;
                  return Text(
                    '• $serial (positions: ${positions.join(', ')})',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold),
                  );
                }).toList(),
                const SizedBox(height: 10),
                const Text(
                    'Please remove duplicates before proceeding.'),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return false; // Don't allow navigation
    }

    // If no duplicates, allow navigation
    await _stopContinuousScanning();
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final orderProvider = Provider.of<PurchaseOrderProvider>(context);
    final order = orderProvider.getPurchaseOrderById(widget.poNumber);
    final item = order?.items.firstWhere(
          (i) => i.itemCode == widget.itemCode,
      orElse: () => throw Exception('Item not found'),
    );

    return PopScope(
      canPop: false,
      onPopInvoked: (bool didPop) async {
        if (didPop) return;

        // Validate before allowing back navigation
        final canNavigate = await _validateAndNavigateBack(context);
        if (canNavigate && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Scan Serial Numbers'),
          leading: IconButton(
              onPressed: () async {
                // Validate before allowing back navigation
                final canNavigate = await _validateAndNavigateBack(context);
                if (canNavigate && context.mounted) {
                  Navigator.of(context).pop();
                }
              },
              icon: Icon(Icons.arrow_back_ios)),
          actions: [
            TextButton(
              onPressed: () async {
                // Validate before allowing back navigation
                final canNavigate = await _validateAndNavigateBack(context);
                if (canNavigate && context.mounted) {
                  Navigator.of(context).pop();
                }
              },
              child: const Text("Done"),
            )
          ],
        ),
        body: GestureDetector(
          onTap: () {
            // When user taps anywhere on the screen, return focus to scanner
            if (AppConstants.scanningMode == 'keystroke' &&
                !_manualEntryFocusNode.hasFocus &&
                !_editSerialFocusNode.hasFocus) {
              _returnFocusToScanner();
            }
          },
          behavior: HitTestBehavior.translucent,
          child: SingleChildScrollView(
            controller: _scrollController,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [


                // Item information section
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Item Details',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 8),
                        InkWell(
                          onTap: () {
                            if (mounted) {
                              setState(() {
                                _isExpanded = !_isExpanded;
                              });
                            }
                          },
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item?.itemName ?? '',
                                maxLines: _isExpanded ? null : 2,
                                overflow: _isExpanded
                                    ? TextOverflow.clip
                                    : TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 16,
                                ),
                              ),
                              if (!_isExpanded && (item?.itemName.length ?? 0) > 50)
                                const Text(
                                  'View more',
                                  style: TextStyle(
                                    color: Colors.blue,
                                    fontSize: 12,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Text('Item Code: ',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                            Text(item?.itemCode ?? ''),
                          ],
                        ),
                        Row(
                          children: [
                            const Text('Ordered Qty: ',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                            Text('${widget.orderedQty}'),
                          ],
                        ),
                        Row(
                          children: [
                            const Text('Available Stock: ',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                            Text('${widget.availableStock}'),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Scanner status indicator with Lottie animation
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 50,
                          height: 50,
                          child: Lottie.asset(
                            'assets/animated_icon/scanner.json',
                            animate: _isScanning,
                            repeat: _isScanning,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _isScanning
                                    ? 'Scanner is active'
                                    : 'Scanner is ready',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: _isScanning ? Colors.green : Colors.grey,
                                ),
                              ),
                              Text(
                                _isScanning
                                    ? 'Scanning for serial numbers...'
                                    : 'Tap to scan',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.blue[700],
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${item!.serials.length}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Manual entry section
                const Text(
                  'Manual Entry',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _serialController,
                  focusNode: _manualEntryFocusNode,
                  decoration: InputDecoration(
                    labelText: 'Serial Number',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.add),
                      onPressed: () {
                        if (_serialController.text.isNotEmpty) {
                          _addSerial(context, _serialController.text);
                          // Return focus to scanner field if in keystroke mode
                          if (AppConstants.scanningMode == 'keystroke') {
                            _returnFocusToScanner();
                          }
                        }
                      },
                    ),
                  ),
                  onTap: () {
                    // Allow keyboard to show for manual entry
                    if (AppConstants.scanningMode == 'keystroke') {
                      Future.delayed(const Duration(milliseconds: 50), () {
                        SystemChannels.textInput.invokeMethod('TextInput.show');
                      });
                    }
                  },
                  onSubmitted: (value) {
                    if (_serialController.text.isNotEmpty) {
                      _addSerial(context, value);
                    }
                    // Return focus to scanner field if in keystroke mode
                    if (AppConstants.scanningMode == 'keystroke') {
                      _returnFocusToScanner();
                    }
                  },
                ),

                const SizedBox(height: 20),

                // Scanned serials list
                if (item!.serials.isNotEmpty) ...[
                  const Text(
                    'Scanned Serials',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: item.serials.length,
                    itemBuilder: (context, index) {
                      final serial = item.serials[index];
                      if (_editingSerialNo == serial.serialNo) {
                        return Card(
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Column(
                              children: [
                                TextField(
                                  controller: _editSerialController,
                                  focusNode: _editSerialFocusNode,
                                  decoration: InputDecoration(
                                    labelText: 'Edit Serial',
                                    border: const OutlineInputBorder(),
                                    suffixIcon: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.check,
                                              color: Colors.green),
                                          onPressed: _saveEditedSerial,
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.close,
                                              color: Colors.red),
                                          onPressed: _cancelEditing,
                                        ),
                                      ],
                                    ),
                                  ),
                                  onSubmitted: (value) {
                                    _saveEditedSerial();
                                  },
                                ),
                              ],
                            ),
                          ),
                        );
                      } else {
                        return Card(
                          child: ListTile(
                            leading: Text('${index + 1}.'),
                            title: Text(serial.serialNo),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit, color: Colors.blue),
                                  onPressed: () =>
                                      _startEditingSerial(serial.serialNo),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  onPressed: () =>
                                      _removeSerial(context, serial.serialNo),
                                ),
                              ],
                            ),
                          ),
                        );
                      }
                    },
                  ),
                ],

                // Invisible TextField for keystroke scanning
                if (AppConstants.scanningMode == 'keystroke')
                  SizedBox(
                    height: 0,
                    width: 0,
                    child: Focus(
                      onFocusChange: (hasFocus) {
                        if (hasFocus) {
                          SystemChannels.textInput.invokeMethod('TextInput.hide');
                        }
                      },
                      child: TextFormField(
                        controller: _keystrokeScanController,
                        focusNode: _keystrokeScanFocusNode,
                        showCursor: false,
                        enableInteractiveSelection: false,
                        keyboardType: TextInputType.none,
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                        ),
                        style: const TextStyle(fontSize: 0, height: 0),
                        onChanged: (value) {
                          // Debounce keystroke input to prevent rapid scanning issues
                          _scanDebounceTimer?.cancel();
                          _scanDebounceTimer = Timer(const Duration(milliseconds: 50), () {
                            if (mounted && value.isNotEmpty) {
                              // Check if the value ends with Enter (common in barcode scanners)
                              if (value.endsWith('\n') || value.endsWith('\r')) {
                                _processKeystrokeScan(value.trim());
                              }
                            }
                          });
                        },
                        onEditingComplete: () {
                          // This is called when Enter is pressed
                          final scannedValue = _keystrokeScanController.text.trim();
                          if (scannedValue.isNotEmpty && !_isProcessingScan) {
                            _processKeystrokeScan(scannedValue);
                          }
                        },
                        onFieldSubmitted: (value) {
                          // This is also called when Enter is pressed - prevent duplicate processing
                          final scannedValue = value.trim();
                          if (scannedValue.isNotEmpty && !_isProcessingScan) {
                            _processKeystrokeScan(scannedValue);
                          }
                        },
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}