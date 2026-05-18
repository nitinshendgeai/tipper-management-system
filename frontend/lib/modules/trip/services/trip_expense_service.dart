import 'package:dio/dio.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/storage/token_storage.dart';
import '../models/trip_expense_model.dart';

class TripExpenseService {
  final Dio _dio = Dio();

  Future<Options> _authOptions() async {
    final token = await TokenStorage.getToken();
    return Options(
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );
  }

  // ─── Get all expenses for a trip ──────────────────────────────────────────

  Future<TripExpenseSummary> getExpenses(int tripId) async {
    final options = await _authOptions(); // Phase 3 fix: was missing auth token
    final response = await _dio.get(
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
    final options = await _authOptions();
    final response = await _dio.post(
      '${ApiConstants.baseUrl}/trips/$tripId/expenses',
      data: payload,
      options: options,
    );
    return TripExpenseModel.fromJson(response.data as Map<String, dynamic>);
  }

  // ─── Delete expense ───────────────────────────────────────────────────────

  Future<void> deleteExpense(int tripId, int expenseId) async {
    final options = await _authOptions();
    await _dio.delete(
      '${ApiConstants.baseUrl}/trips/$tripId/expenses/$expenseId',
      options: options,
    );
  }
}
