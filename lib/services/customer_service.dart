import 'package:rapide_nforce/core/models/api_result.dart';
import 'package:rapide_nforce/models/customer_model.dart';

class CustomerService {
  CustomerService._();

  static final CustomerService instance = CustomerService._();

  Future<ApiResult<List<CustomerModel>>> fetchCustomers() async {
    return ApiResult.fail('Customers are not available in the technician app.');
  }
}
