import 'package:flutter/material.dart';

/// ============================================
/// TokenExpirationManager - Quản lý toàn cục token expiration
/// ============================================
///
/// Singleton class để quản lý:
/// - Listeners khi user logout
/// - Callbacks để show dialog
/// - State tracking
///
class TokenExpirationManager {
  //  Singleton instance
  static final TokenExpirationManager _instance =
  TokenExpirationManager._internal();

  //  Private constructor
  TokenExpirationManager._internal();

  //  Factory constructor
  factory TokenExpirationManager() {
    return _instance;
  }

  //  Lists to store callbacks
  final List<VoidCallback> _logoutListeners = [];
  final List<Function(BuildContext)> _dialogCallbacks = [];

  //  State tracking (THÊM CÁI NÀY)
  bool _isTokenExpired = false;

  // ============================================
  // Getters
  // ============================================

  /// Kiểm tra xem token có hết hạn không
  bool get isTokenExpired => _isTokenExpired;

  /// Lấy số lượng listeners
  int get logoutListenerCount => _logoutListeners.length;

  /// Lấy số lượng dialog callbacks
  int get dialogCallbackCount => _dialogCallbacks.length;

  // ============================================
  // Logout Listeners
  // ============================================

  /// Thêm listener khi user logout
  void addLogoutListener(VoidCallback callback) {
    if (!_logoutListeners.contains(callback)) {
      _logoutListeners.add(callback);
      print('Added logout listener (total: ${_logoutListeners.length})');
    }
  }

  /// Xóa logout listener
  void removeLogoutListener(VoidCallback callback) {
    _logoutListeners.remove(callback);
    print(' Removed logout listener (remaining: ${_logoutListeners.length})');
  }

  /// Notify tất cả logout listeners
  void notifyLogout() {
    print(' Notifying ${_logoutListeners.length} logout listeners');
    for (var listener in _logoutListeners) {
      try {
        listener();
      } catch (e) {
        print('Error calling logout listener: $e');
      }
    }
  }

  // ============================================
  // Dialog Callbacks
  // ============================================

  /// Thêm callback để show dialog
  void addDialogCallback(Function(BuildContext) callback) {
    if (!_dialogCallbacks.contains(callback)) {
      _dialogCallbacks.add(callback);
      print(' Added dialog callback (total: ${_dialogCallbacks.length})');
    }
  }

  /// Xóa dialog callback
  void removeDialogCallback(Function(BuildContext) callback) {
    _dialogCallbacks.remove(callback);
    print(' Removed dialog callback (remaining: ${_dialogCallbacks.length})');
  }

  /// Show dialog ở tất cả context
  void showTokenExpiredDialogGlobal(BuildContext context) {
    print(' Triggering token expired dialog (${_dialogCallbacks.length} callbacks)');
    for (var callback in _dialogCallbacks) {
      try {
        callback(context);
      } catch (e) {
        print(' Error calling dialog callback: $e');
      }
    }
  }

  // ============================================
  // State Management (THÊM METHODS NÀY)
  // ============================================

  /// Mark token as expired
  void markTokenAsExpired() {
    if (!_isTokenExpired) {
      _isTokenExpired = true;
      print(' Token marked as expired');
    }
  }

  /// Mark token as valid
  void markTokenAsValid() {
    if (_isTokenExpired) {
      _isTokenExpired = false;
      print(' Token marked as valid');
    }
  }

  /// Reset token expiration state
  void resetTokenState() {
    _isTokenExpired = false;
    print('♻️ Token state reset');
  }

  // ============================================
  // Cleanup
  // ============================================

  /// Clear tất cả listeners và callbacks
  void clear() {
    print(' Clearing TokenExpirationManager (${_logoutListeners.length} listeners, ${_dialogCallbacks.length} callbacks)');
    _logoutListeners.clear();
    _dialogCallbacks.clear();
    _isTokenExpired = false;
    print('✅ TokenExpirationManager cleared');
  }

  // ============================================
  // Debug Info
  // ============================================

  /// Print debug information
  void printDebugInfo() {
    print('═══════════════════════════════════════════');
    print('TokenExpirationManager Debug Info:');
    print('  - Logout Listeners: ${_logoutListeners.length}');
    print('  - Dialog Callbacks: ${_dialogCallbacks.length}');
    print('  - Token Expired: $_isTokenExpired');
    print('═══════════════════════════════════════════');
  }

  /// Get status string
  String getStatus() {
    return 'TokenExpired: $_isTokenExpired, '
        'Listeners: ${_logoutListeners.length}, '
        'Callbacks: ${_dialogCallbacks.length}';
  }
}