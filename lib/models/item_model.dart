class Item {
  final String id;
  final String name;
  final String code;
  final double stock;
  final double orderedQuantity;
  final String unit;
  final bool isSerialized;
  final bool isNonInventory;

  Item({
    required this.id,
    required this.name,
    required this.code,
    required this.stock,
    required this.orderedQuantity,
    required this.unit,
    required this.isNonInventory,
    required this.isSerialized,

  });
}