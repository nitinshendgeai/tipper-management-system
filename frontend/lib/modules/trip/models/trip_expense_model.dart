class TripExpenseModel {

  final int id;
  final int tripId;
  final String expenseType;
  final double amount;
  final String? remarks;
  final DateTime? createdAt;

  const TripExpenseModel({
    required this.id,
    required this.tripId,
    required this.expenseType,
    required this.amount,
    this.remarks,
    this.createdAt,
  });

  factory TripExpenseModel.fromJson(Map<String, dynamic> json) {
    return TripExpenseModel(
      id: json['id'] as int,
      tripId: json['trip_id'] as int,
      expenseType: json['expense_type'] as String? ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      remarks: json['remarks'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
    );
  }
}


class TripExpenseSummary {

  final int tripId;
  final double totalAmount;
  final List<TripExpenseModel> expenses;
  final Map<String, double> byType;

  const TripExpenseSummary({
    required this.tripId,
    required this.totalAmount,
    required this.expenses,
    required this.byType,
  });

  factory TripExpenseSummary.fromJson(Map<String, dynamic> json) {
    final rawExpenses = json['expenses'] as List? ?? [];
    final rawByType = json['by_type'] as Map<String, dynamic>? ?? {};

    return TripExpenseSummary(
      tripId: json['trip_id'] as int,
      totalAmount: (json['total_amount'] as num?)?.toDouble() ?? 0.0,
      expenses: rawExpenses
          .map((e) => TripExpenseModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      byType: rawByType.map((k, v) => MapEntry(k, (v as num).toDouble())),
    );
  }
}


/// Expense type options (mirrors backend ExpenseType)
const List<String> kExpenseTypes = [
  'Diesel',
  'Toll',
  'Food/Bata',
  'Repair',
  'Puncture',
  'Police',
  'Other',
];
