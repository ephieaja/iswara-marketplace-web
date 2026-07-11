import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/auth_provider.dart';
import 'providers/cart_provider.dart';
import 'config/theme.dart';
import 'screens/welcome_screen.dart';
import 'screens/cart_screen.dart';
import 'screens/orders_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(const IswaraMarketplaceApp());
}

class IswaraMarketplaceApp extends StatelessWidget {
  const IswaraMarketplaceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => CartProvider()),
      ],
      child: MaterialApp(
        title: 'ISWARA Marketplace',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        home: const WelcomeScreen(),
        routes: {
          '/cart': (context) => const CartScreen(),
          '/orders': (context) => const OrdersScreen(),
        },
      ),
    );
  }
}
