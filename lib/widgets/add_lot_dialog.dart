import 'package:delivery_note_app/providers/order_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:delivery_note_app/providers/purchase_order_provider.dart';
import 'package:delivery_note_app/utils/app_alerts.dart';
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
  bool _isScanning = false;
  bool _isExpanded = false;
  String? _editingSerialNo;

  @override
  void initState() {
    super.initState();
    // Ensure widget is mounted before starting scanning
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _startContinuousScanning();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final orderProvider = Provider.of<OrderProvider>(context, listen: false);
    // Now you can safely access Provider here
    orderProvider.addListener(_handleScanUpdate);
  }

  Future<void> _startContinuousScanning() async {
    // Ensure widget is mounted before accessing Provider
    if (mounted) {
      final orderProvider = Provider.of<OrderProvider>(context, listen: false);
      try {
        setState(() => _isScanning = true);
        await orderProvider.startScanning();
        orderProvider.addListener(_handleScanUpdate);
      } catch (e) {
        if (mounted) {
          setState(() => _isScanning = false);
        }
        AppAlerts.appToast(message: 'Failed to start scanner: ${e.toString()}');
      }
    }
  }

  Future<void> _stopContinuousScanning() async {
    final orderProvider = Provider.of<OrderProvider>(context, listen: false);
    orderProvider.removeListener(_handleScanUpdate);
    try {
      await orderProvider.stopScanner();
    } catch (e) {
      debugPrint("Error stopping scanner: $e");
    }
    if (mounted) {
      setState(() => _isScanning = false);
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

  void _handleScannedBarcode(BuildContext context, String barcode) async {
    try {
      await _addSerial(context, barcode);
    } catch (e) {
      if (mounted) {
        AppAlerts.appToast(message: 'Error handling barcode: ${e.toString()}');
      }
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
  }

  void _cancelEditing() {
    if (!mounted) return;
    setState(() {
      _editingSerialNo = null;
      _editSerialController.clear();
    });
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
      }
    } catch (e) {
      if (mounted) {
        AppAlerts.appToast(message: 'Failed to update serial: ${e.toString()}');
      }
    }
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
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Scan Serial Numbers'),
          leading: IconButton(
              onPressed: () async {
                _stopContinuousScanning();
                Navigator.of(context).pop();
              },
              icon: Icon(Icons.arrow_back_ios)),
          actions: [
            TextButton(
              onPressed: () async {
                _stopContinuousScanning();
                Navigator.of(context).pop();
              },
              child: const Text("Done"),
            ),
          ],
        ),
        body: SingleChildScrollView(
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
                      Column(
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
                decoration: InputDecoration(
                  labelText: 'Serial Number',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: () {
                      if (_serialController.text.isNotEmpty) {
                        _addSerial(context, _serialController.text);
                      }
                    },
                  ),
                ),
                onSubmitted: (value) => _addSerial(context, value),
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
            ],
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
  bool _isScanning = false;
  bool _isExpanded = false;
  String? _editingSerialNo;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _startContinuousScanning();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final orderProvider = Provider.of<OrderProvider>(context, listen: false);
    // Now you can safely access Provider here
    orderProvider.addListener(_handleScanUpdate);
  }

  Future<void> _startContinuousScanning() async {
    // Ensure widget is mounted before accessing Provider
    if (mounted) {
      final orderProvider =
          Provider.of<PurchaseOrderProvider>(context, listen: false);
      try {
        setState(() => _isScanning = true);
        await orderProvider.startScanning();
        orderProvider.addListener(_handleScanUpdate);
      } catch (e) {
        if (mounted) {
          setState(() => _isScanning = false);
        }
        AppAlerts.appToast(message: 'Failed to start scanner: ${e.toString()}');
      }
    }
  }

  Future<void> _stopContinuousScanning() async {
    final orderProvider =
        Provider.of<PurchaseOrderProvider>(context, listen: false);
    orderProvider.removeListener(_handleScanUpdate);
    try {
      await orderProvider.stopScanner();
    } catch (e) {
      debugPrint("Error stopping scanner: $e");
    }
    if (mounted) {
      setState(() => _isScanning = false);
    }
  }

  void _handleScanUpdate() {
    if (!mounted) return;

    final orderProvider =
        Provider.of<PurchaseOrderProvider>(context, listen: false);
    if (orderProvider.scannedBarcode != null &&
        orderProvider.scannedBarcode!.isNotEmpty) {
      _handleScannedBarcode(context, orderProvider.scannedBarcode!);
      orderProvider.clearScannedBarcode();
    }
  }

  void _handleScannedBarcode(BuildContext context, String barcode) async {
    try {
      await _addSerial(context, barcode);
    } catch (e) {
      if (mounted) {
        AppAlerts.appToast(message: 'Error handling barcode: ${e.toString()}');
      }
    }
  }

  Future<void> _addSerial(BuildContext context, String serialNo) async {
    final orderProvider =
        Provider.of<PurchaseOrderProvider>(context, listen: false);
    try {
      await orderProvider.addSerialToItem(
        poNumber: widget.poNumber,
        itemCode: widget.itemCode,
        serialNo: serialNo,
      );
      if (mounted) {
        _serialController.clear();
      }
    } catch (e) {
      if (mounted) {
        AppAlerts.appToast(message: e.toString());
      }
    }
  }

  void _removeSerial(BuildContext context, String serialNo) {
    final orderProvider =
        Provider.of<PurchaseOrderProvider>(context, listen: false);
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
  }

  void _cancelEditing() {
    if (!mounted) return;
    setState(() {
      _editingSerialNo = null;
      _editSerialController.clear();
    });
  }

  void _saveEditedSerial() {
    if (!mounted ||
        _editingSerialNo == null ||
        _editSerialController.text.isEmpty) return;

    final orderProvider =
        Provider.of<PurchaseOrderProvider>(context, listen: false);
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
      }
    } catch (e) {
      if (mounted) {
        AppAlerts.appToast(message: 'Failed to update serial: ${e.toString()}');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final orderProvider = Provider.of<PurchaseOrderProvider>(context);
    final order = orderProvider.getPurchaseOrderById(widget.poNumber);
    final item = order?.items.firstWhere(
      (i) => i.itemCode == widget.itemCode,
      orElse: () => throw Exception('Item not found'),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Serial Numbers'),
        leading: IconButton(
            onPressed: () async {
              _stopContinuousScanning();
              Navigator.of(context).pop();
            },
            icon: Icon(Icons.arrow_back_ios)),
        actions: [
          IconButton(
            icon: const Icon(Icons.done),
            onPressed: () async {
              _stopContinuousScanning();
              Navigator.of(context).pop();
            },
            tooltip: 'Done',
          ),
        ],
      ),
      body: SingleChildScrollView(
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
                        'assets/animate_icon/scanner.json',
                        animate: _isScanning,
                        repeat: _isScanning,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Column(
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
              decoration: InputDecoration(
                labelText: 'Serial Number',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () {
                    if (_serialController.text.isNotEmpty) {
                      _addSerial(context, _serialController.text);
                    }
                  },
                ),
              ),
              onSubmitted: (value) => _addSerial(context, value),
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
          ],
        ),
      ),
    );
  }
}
