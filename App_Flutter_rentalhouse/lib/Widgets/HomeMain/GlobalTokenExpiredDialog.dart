import 'package:flutter/material.dart';
import '../../services/TokenExpirationManager.dart';

class GlobalTokenExpiredDialog extends StatefulWidget {
  final Widget child;

  const GlobalTokenExpiredDialog({
    Key? key,
    required this.child,
  }) : super(key: key);

  @override
  State<GlobalTokenExpiredDialog> createState() =>
      _GlobalTokenExpiredDialogState();
}

class _GlobalTokenExpiredDialogState extends State<GlobalTokenExpiredDialog> {
  bool _isDialogShowing = false;

  @override
  void initState() {
    super.initState();
    TokenExpirationManager().addDialogCallback(_showTokenExpiredDialog);
  }

  @override
  void dispose() {
    TokenExpirationManager().removeDialogCallback(_showTokenExpiredDialog);
    super.dispose();
  }

  void _showTokenExpiredDialog(BuildContext context) {
    if (_isDialogShowing) {
      print('Dialog already showing');
      return;
    }

    _isDialogShowing = true;
    print(' TOKEN EXPIRED - Showing dialog');

    try {
      Navigator.of(context).popUntil((route) => route.isFirst);
      ScaffoldMessenger.of(context).clearSnackBars();
    } catch (e) {
      print(' Error clearing previous dialogs: $e');
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      barrierColor: Colors.black.withOpacity(0.4),
      builder: (BuildContext dialogContext) {
        return WillPopScope(
          onWillPop: () async => false,
          child: Dialog(
            backgroundColor: Colors.transparent,
            elevation: 0,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 20,
                    spreadRadius: 0,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      //  Icon - Animated & Modern
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(50),
                        ),
                        child: Icon(
                          Icons.lock_outline_rounded,
                          color: Colors.red.shade600,
                          size: 32,
                        ),
                      ),
                      const SizedBox(height: 20),

                      //  Title - Clean & Bold
                      Text(
                        'Phiên đăng nhập hết hạn',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Colors.grey.shade900,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 12),

                      //  Description - Subtle & Professional
                      Text(
                        'Phiên đăng nhập của bạn đã hết hạn vì lý do bảo mật. Vui lòng đăng nhập lại để tiếp tục.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                          height: 1.6,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      const SizedBox(height: 28),

                      //  Button - Modern Gradient Style
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.blue.shade600,
                              Colors.blue.shade700,
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.blue.withOpacity(0.3),
                              blurRadius: 12,
                              spreadRadius: 0,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              print('👤 User clicked "Đăng nhập lại"');

                              _isDialogShowing = false;

                              Navigator.of(dialogContext).pop();

                              try {
                                Navigator.of(context).pushNamedAndRemoveUntil(
                                  '/login',
                                      (Route<dynamic> route) => false,
                                );
                                print(' Navigated to /login');
                              } catch (e) {
                                print(' Navigation error: $e');
                                try {
                                  Navigator.of(dialogContext)
                                      .pushNamedAndRemoveUntil(
                                    '/login',
                                        (Route<dynamic> route) => false,
                                  );
                                } catch (e2) {
                                  print(' Fallback navigation failed: $e2');
                                }
                              }

                              TokenExpirationManager().notifyLogout();

                            },
                            borderRadius: BorderRadius.circular(10),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 14,
                                horizontal: 16,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.login_rounded,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Đăng nhập lại',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      //  Security Info - Minimal & Informative
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.grey.shade200,
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.shield_rounded,
                              color: Colors.grey.shade500,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Đây là biện pháp bảo mật để bảo vệ tài khoản của bạn',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                  height: 1.4,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    ).then((_) {
      _isDialogShowing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}