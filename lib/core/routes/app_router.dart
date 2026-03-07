import 'package:go_router/go_router.dart';
import '../../screens/login_screen.dart';
import '../../screens/shop_setup_screen.dart';
import '../../screens/dashboard_screen.dart';
import '../../screens/sales_screen.dart';
import '../../screens/products_screen.dart';
import '../../screens/customers_screen.dart';
import '../../screens/reports_screen.dart';
import '../../screens/settings_screen.dart';
import '../../screens/register_screen.dart';
import '../../screens/saved_reports_screen.dart';
import '../../screens/receipt_settings_screen.dart';
import '../../screens/saved_receipts_screen.dart';

class AppRouter {
  static GoRouter getRouter(String initialRoute) {
    return GoRouter(
      initialLocation: initialRoute,
      routes: [
        GoRoute(
          path: '/shop-setup',
          builder: (context, state) => const ShopSetupScreen(),
        ),
        GoRoute(
          path: '/register-pin',
          builder: (context, state) => const RegisterScreen(),
        ),
        GoRoute(
          path: '/login',
        builder: (context, state) {
          final email = state.uri.queryParameters['mode'] == 'email';
          return LoginScreen(startWithEmail: email);
        },
      ),
      GoRoute(
        path: '/dashboard',
        builder: (context, state) => const DashboardScreen(),
      ),
      GoRoute(
        path: '/sales',
        builder: (context, state) => const SalesScreen(),
      ),
      GoRoute(
        path: '/products',
        builder: (context, state) => const ProductsScreen(),
      ),
      GoRoute(
        path: '/customers',
        builder: (context, state) => const CustomersScreen(),
      ),
      GoRoute(
        path: '/reports',
        builder: (context, state) => const ReportsScreen(),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/saved-reports',
        builder: (context, state) => const SavedReportsScreen(),
      ),
      GoRoute(
        path: '/receipt-settings',
        builder: (context, state) => const ReceiptSettingsScreen(),
      ),
      GoRoute(
        path: '/saved-receipts',
        builder: (context, state) => const SavedReceiptsScreen(),
      ),
      ],
    );
  }
}
