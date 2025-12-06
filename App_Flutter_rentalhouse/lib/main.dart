import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_dynamic_links/firebase_dynamic_links.dart';
import 'package:flutter_rentalhouse/services/auth_service.dart';
import 'package:flutter_rentalhouse/viewmodels/vm_auth.dart';
import 'package:flutter_rentalhouse/viewmodels/vm_chat.dart';
import 'package:flutter_rentalhouse/viewmodels/vm_favorite.dart';
import 'package:flutter_rentalhouse/viewmodels/vm_rental.dart';
import 'package:flutter_rentalhouse/views/Admin/ViewModel/admin_viewmodel.dart';
import 'package:flutter_rentalhouse/views/login_view.dart';
import 'package:flutter_rentalhouse/views/welcome.dart';
import 'package:flutter_rentalhouse/views/reset_password.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: "assets/.env");
  await Firebase.initializeApp();
  runApp(RentalApp());
}

// Lớp xử lý Firebase Dynamic Links
class DeepLinkHandler {
  final FirebaseDynamicLinks _dynamicLinks = FirebaseDynamicLinks.instance;

  Future<void> initDynamicLinks(BuildContext context) async {
    // Xử lý liên kết khi ứng dụng đang chạy
    _dynamicLinks.onLink.listen((PendingDynamicLinkData? dynamicLink) async {
      await _handleDeepLink(context, dynamicLink?.link);
    }, onError: (e) {
      print('Error processing dynamic link: $e');
    });

    // Xử lý liên kết khi ứng dụng được mở từ trạng thái đóng
    final PendingDynamicLinkData? initialLink =
        await _dynamicLinks.getInitialLink();
    if (initialLink != null) {
      await _handleDeepLink(context, initialLink.link);
    }
  }

  Future<void> _handleDeepLink(BuildContext context, Uri? deepLink) async {
    if (deepLink != null) {
      print('Deep link received: $deepLink');
      print('Path: ${deepLink.path}, Query: ${deepLink.queryParameters}');
      final oobCode = deepLink.queryParameters['oobCode'];
      if (oobCode != null && deepLink.path == '/reset-password') {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã nhận liên kết đặt lại mật khẩu')),
        );
        Navigator.pushNamed(
          context,
          '/reset-password',
          arguments: {'oobCode': oobCode},
        );
      } else {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Liên kết không hợp lệ')),
        );
      }
    } else {
      print('No deep link received');
    }
  }
}

class RentalApp extends StatelessWidget {
  final DeepLinkHandler _deepLinkHandler = DeepLinkHandler();

  RentalApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Khởi tạo DeepLinkHandler sau khi widget được xây dựng
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _deepLinkHandler.initDynamicLinks(context);
    });

    return MultiProvider(
      providers: [
        // User
        ChangeNotifierProvider(create: (_) => AuthViewModel()),
        ChangeNotifierProvider(create: (_) => RentalViewModel()),
        ChangeNotifierProvider(create: (_) => FavoriteViewModel()),
        ChangeNotifierProvider(create: (_) => ChatViewModel()),

        // Admin
        ChangeNotifierProvider(create: (_) => AdminViewModel()),
        Provider(create: (_) => AuthService()),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Ứng Dụng Thuê Nhà',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
          useMaterial3: true,
          fontFamily: 'Roboto',
        ),
        // Định nghĩa các route để điều hướng
        routes: {
          '/login': (context) => const LoginScreen(),
          '/reset-password': (context) => const ResetPasswordScreen(),
        },
        onGenerateRoute: (settings) {
          if (settings.name == '/reset-password') {
            final args = settings.arguments as Map<String, dynamic>?;
            return MaterialPageRoute(
              builder: (context) =>
                  ResetPasswordScreen(oobCode: args?['oobCode']),
            );
          }
          return null;
        },
        home: const WelcomeScreen(),
      ),
    );
  }
}
