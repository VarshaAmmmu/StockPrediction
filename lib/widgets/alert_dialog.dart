import 'package:flutter/material.dart';

class AddAlertDialog extends StatefulWidget {
  final String stockSymbol;
  final double currentPrice;
  final Function(double, bool) onAddAlert;

  const AddAlertDialog({
    Key? key,
    required this.stockSymbol,
    required this.currentPrice,
    required this.onAddAlert,
  }) : super(key: key);

  @override
  State<AddAlertDialog> createState() => _AddAlertDialogState();
}

class _AddAlertDialogState extends State<AddAlertDialog> {
  late TextEditingController _priceController;
  bool _isAbove = true;

  @override
  void initState() {
    super.initState();
    _priceController = TextEditingController(
      text: widget.currentPrice.toStringAsFixed(2),
    );
  }

  @override
  void dispose() {
    _priceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Add Alert for ${widget.stockSymbol}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _priceController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Target Price',
              prefixText: '\$',
            ),
          ),
          const SizedBox(height: 16),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment<bool>(
                value: true,
                label: Text('Above'),
              ),
              ButtonSegment<bool>(
                value: false,
                label: Text('Below'),
              ),
            ],
            selected: {_isAbove},
            onSelectionChanged: (Set<bool> selected) {
              setState(() {
                _isAbove = selected.first;
              });
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final price = double.tryParse(_priceController.text);
            if (price != null) {
              widget.onAddAlert(price, _isAbove);
              Navigator.of(context).pop();
            }
          },
          child: const Text('Add Alert'),
        ),
      ],
    );
  }
}
