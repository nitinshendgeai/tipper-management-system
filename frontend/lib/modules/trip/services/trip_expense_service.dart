import '../../../core/constants/api_constants.dart';
import '../../../core/network/dio_client.dart';
import '../models/trip_expense_model.dart';

/// Phase 6 (FE-006): migrated from raw Dio() to DioClient.instance.
class TripExpenseService {
  // ─── Get all expenses for a trip ──────────────────────────────────────────

  Future<TripExpenseSummary> getExpenses(int tripId) async {
    final options = await DioClient.authOptions();
    final response = await DioClient.instance.get(
      '${ApiConstants.baseUrl}/trips/$tripId/expenses',
      options: options,
    );
    return TripExpenseSummary.fromJson(response.data as Map<String, dynamic>);
  }

  // ─── Add expense ──────────────────────────────────────────────────────────

  Future<TripExpenseModel> addExpense(
    int tripId,
    Map<String, dynamic> payload,
  ) async {
    final options = await DioClient.authOptions();
    final response = await DioClient.instance.post(
      '${ApiConstants.baseUrl}/trips/$tripId/expenses',
      data: payload,
      options: options,
    );
    return TripExpenseModel.fromJson(response.data as Map<String, dynamic>);
  }

  // ─── Delete expense ───────────────────────────────────────────────────────

  Future<void> deleteExpense(int tripId, int expenseId) async {
    final options = await DioClient.authOptions();
    await DioClient.instance.delete(
      '${ApiConstants.baseUrl}/trips/$tripId/expenses/$expenseId',
      options: options,
    );
  }
}
