import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_rentalhouse/models/rental.dart';
import 'package:flutter_rentalhouse/services/AI_Chat_service.dart';
import 'package:flutter_rentalhouse/services/chat_ai_service.dart';
import 'package:flutter_rentalhouse/views/rental_detail_view.dart';
import 'package:intl/intl.dart';
import 'package:location/location.dart' as loc;
import 'package:lottie/lottie.dart';

import '../config/loading.dart';


class ChatAIPage extends StatefulWidget {
  const ChatAIPage({super.key});

  @override
  State<ChatAIPage> createState() => _ChatAIPageState();
}

class _ChatAIPageState extends State<ChatAIPage>
    with SingleTickerProviderStateMixin {
  // ─── Navigation ───────────────────────────────────────────
  bool _showHistory = false;

  // ─── Real userId from Firebase ────────────────────────────
  String get _currentUserId =>
      FirebaseAuth.instance.currentUser?.uid ?? 'anonymous';

  // ─── Chat state ───────────────────────────────────────────
  List<Map<String, dynamic>> messages = [];
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool isLoading = false;
  String? conversationId;
  List<String> suggestions = [];

  // ─── Location ─────────────────────────────────────────────
  double? currentLatitude;
  double? currentLongitude;
  bool isLocationAvailable = false;

  // ─── Rental list pagination ───────────────────────────────
  static const int _initialShowCount = 5;
  Map<String, int> _rentalGroupShowCount = {};

  // ─── History ──────────────────────────────────────────────
  List<ConversationItem> _conversations = [];
  bool _isLoadingHistory = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  List<ConversationItem> _filteredConversations = [];

  // ─── Animation ────────────────────────────────────────────
  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  // ─── History pagination ───────────────────────────────
  static const int _historyPageSize = 10;
  bool _isLoadingMoreHistory = false;
  bool _hasMoreHistory = false;
  int _historySkip = 0;
  final ScrollController _historyScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _fadeAnim =
        CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();

    _initializeConversation();
    _getCurrentLocation();

    _historyScrollController.addListener(_onHistoryScroll);
  }

  @override
  void dispose() {
    _historyScrollController.removeListener(_onHistoryScroll);
    _historyScrollController.dispose();

    _controller.dispose();
    _scrollController.dispose();
    _searchController.dispose();
    _animController.dispose();
    super.dispose();
  }
  void _onHistoryScroll() {
    if (_historyScrollController.position.pixels >=
        _historyScrollController.position.maxScrollExtent - 100) {
      if (!_isLoadingMoreHistory && _hasMoreHistory) {
        _loadMoreHistory();
      }
    }
  }
  Future<void> _loadHistory() async {
    setState(() {
      _isLoadingHistory = true;
      _historySkip = 0;
      _conversations = [];
    });

    // 🔥 Tự dọn conversation trống trước khi load
    await ChatAIService.cleanEmptyConversations();

    try {
      final result = await ChatAIService.getConversationList(
        _currentUserId,
        limit: _historyPageSize,
        skip: 0,
      );
      if (mounted) {
        setState(() {
          _conversations = result.conversations;
          _filteredConversations = result.conversations;
          _hasMoreHistory = result.hasMore;
          _historySkip = result.conversations.length;
          _isLoadingHistory = false;
        });
      }
    } catch (e) {
      debugPrint('Load history error: $e');
      if (mounted) setState(() => _isLoadingHistory = false);
    }
  }

  Future<void> _loadMoreHistory() async {
    if (_isLoadingMoreHistory || !_hasMoreHistory) return;
    setState(() => _isLoadingMoreHistory = true);

    try {
      final result = await ChatAIService.getConversationList(
        _currentUserId,
        limit: _historyPageSize,
        skip: _historySkip,
      );
      if (mounted) {
        setState(() {
          _conversations.addAll(result.conversations);
          _filteredConversations = _searchQuery.isEmpty
              ? _conversations
              : _conversations.where((c) => c.preview
              .toLowerCase().contains(_searchQuery.toLowerCase())).toList();
          _hasMoreHistory = result.hasMore;
          _historySkip += result.conversations.length;
          _isLoadingMoreHistory = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingMoreHistory = false);
    }
  }
  // ══════════════════════════════════════════════════════════
  // LOCATION
  // ══════════════════════════════════════════════════════════
  Future<void> _getCurrentLocation() async {
    try {
      loc.Location location = loc.Location();
      bool serviceEnabled = await location.serviceEnabled();
      if (!serviceEnabled) {
        serviceEnabled = await location.requestService();
        if (!serviceEnabled) return;
      }
      loc.PermissionStatus permission = await location.hasPermission();
      if (permission == loc.PermissionStatus.denied) {
        permission = await location.requestPermission();
        if (permission != loc.PermissionStatus.granted) return;
      }
      final locationData = await location.getLocation();
      if (mounted) {
        setState(() {
          currentLatitude = locationData.latitude;
          currentLongitude = locationData.longitude;
          isLocationAvailable = true;
        });
      }
    } catch (e) {
      debugPrint('Location error: $e');
    }
  }

  // ══════════════════════════════════════════════════════════
  // INIT CONVERSATION
  // ══════════════════════════════════════════════════════════
  Future<void> _initializeConversation() async {
    try {
      final response = await ChatAIService.startConversation(
        initialContext: {'device': 'mobile', 'platform': 'flutter'},
      );
      if (mounted) {
        setState(() {
          conversationId = response.conversationId;
          messages.add({'role': 'assistant', 'text': response.greeting});
        });
      }
      _loadSuggestions();
    } catch (e) {
      if (mounted) {
        setState(() {
          messages.add({
            'role': 'assistant',
            'text':
            '👋 Xin chào! Tôi là trợ lý AI chuyên về bất động sản. '
                'Tôi có thể giúp bạn tìm nhà phù hợp!',
          });
        });
      }
    }
  }

  Future<void> _loadSuggestions() async {
    try {
      final loaded = await ChatAIService.getSuggestions(_currentUserId);
      if (mounted) setState(() => suggestions = loaded);
    } catch (_) {}
  }

  // ══════════════════════════════════════════════════════════
  // NEW CHAT
  // ══════════════════════════════════════════════════════════
  Future<void> _startNewChat() async {
    setState(() {
      messages = [];
      conversationId = null;
      _rentalGroupShowCount = {};
      isLoading = false;
      _showHistory = false;
    });
    await _initializeConversation();
    _scrollToBottom();
  }


  Future<void> _deleteConversation(String convId) async {
    final ok = await ChatAIService.deleteConversation(convId);
    if (ok && mounted) {
      setState(() {
        _conversations.removeWhere((c) => c.id == convId);
        _filteredConversations.removeWhere((c) => c.id == convId);
        if (conversationId == convId) conversationId = null;
      });
    }
  }

  void _filterConversations(String query) {
    setState(() {
      _searchQuery = query;
      if (query.isEmpty) {
        _filteredConversations = _conversations;
      } else {
        _filteredConversations = _conversations
            .where((c) =>
            c.preview.toLowerCase().contains(query.toLowerCase()))
            .toList();
      }
    });
  }

  Future<void> _loadConversation(String convId) async {
    try {
      final conv = await ChatAIService.getConversation(convId);
      if (conv == null) return;

      final List<Map<String, dynamic>> restoredMessages = [];

      for (final m in conv.messages) {
        if (m.role == 'user' || m.role == 'assistant') {
          // Message thông thường
          restoredMessages.add({
            'role': m.role,
            'text': m.content,
          });
        } else if (m.role == 'system' &&
            m.content == '__RENTALS__' &&
            m.metadata != null) {
          // 🔥 Restore rental messages từ metadata
          final meta = m.metadata!;
          final rentalsRaw = meta['rentals'] as List<dynamic>?;
          final count = meta['count'] as int? ?? 0;

          if (rentalsRaw != null && rentalsRaw.isNotEmpty) {
            final groupId = 'history_${m.timestamp?.millisecondsSinceEpoch ?? DateTime.now().millisecondsSinceEpoch}';

            // Parse rentals
            final rentals = rentalsRaw
                .map((r) {
              try {
                return Rental.fromJson(r as Map<String, dynamic>);
              } catch (e) {
                return null;
              }
            })
                .whereType<Rental>()
                .toList();

            if (rentals.isNotEmpty) {
              // Khởi tạo show count
              _rentalGroupShowCount[groupId] = 5;

              // Thêm header
              restoredMessages.add({
                'role': 'system',
                'type': 'rental_header',
                'count': rentals.length,
                'groupId': groupId,
              });

              // Thêm list
              restoredMessages.add({
                'role': 'system',
                'type': 'rental_list',
                'rentals': rentals,
                'groupId': groupId,
              });
            }
          }
        }
      }

      debugPrint('✅ Restored ${restoredMessages.length} messages for $convId');

      if (mounted) {
        setState(() {
          conversationId = convId;
          messages = restoredMessages;
          _showHistory = false;
        });
      }
      _scrollToBottom();
    } catch (e) {
      debugPrint('❌ Load conversation error: $e');
    }
  }

  // ══════════════════════════════════════════════════════════
  // SEND MESSAGE
  // ══════════════════════════════════════════════════════════
  Future<void> sendMessage() async {
    final userInput = _controller.text.trim();
    if (userInput.isEmpty) return;

    setState(() {
      isLoading = true;
      messages.add({'role': 'user', 'text': userInput});
      _controller.clear();
    });
    _scrollToBottom();

    try {
      final history = messages
          .where((m) => m['role'] == 'user' || m['role'] == 'assistant')
          .map((m) => ChatMessage(role: m['role'], content: m['text']))
          .toList();

      final response = await ChatAIService.chat(
        message: userInput,
        conversationHistory: history,
        conversationId: conversationId,
        includeRecommendations: true,
        latitude: currentLatitude,
        longitude: currentLongitude,
      );

      if (!mounted) return;
      setState(() {
        isLoading = false;
        messages.add({'role': 'assistant', 'text': response.message});

        if (response.recommendations != null &&
            response.recommendations!.isNotEmpty) {
          final allRentals = response.recommendations!;
          final groupId =
          DateTime.now().millisecondsSinceEpoch.toString();
          _rentalGroupShowCount[groupId] = _initialShowCount;

          messages.add({
            'role': 'system',
            'type': 'rental_header',
            'count': allRentals.length,
            'groupId': groupId,
          });
          messages.add({
            'role': 'system',
            'type': 'rental_list',
            'rentals': allRentals,
            'groupId': groupId,
          });

          if (response.explanation != null &&
              response.explanation!.isNotEmpty) {
            messages.add({
              'role': 'assistant',
              'text': '💡 ${response.explanation}',
            });
          }
        }

        if (response.conversationId != null) {
          conversationId = response.conversationId;
        }
      });

      // Refresh history silently in background so new convo appears in list
      _refreshHistorySilent();
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoading = false;
          messages.add({
            'role': 'assistant',
            'text':
            '❌ Xin lỗi, tôi gặp chút vấn đề kỹ thuật. Bạn thử lại nhé! 🙏',
          });
        });
      }
    }
    _scrollToBottom();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 150), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  // Refresh history list without showing loading spinner
  Future<void> _refreshHistorySilent() async {
    try {
      final result = await ChatAIService.getConversationList(
        _currentUserId,
        limit: 50,
      );
      if (mounted) {
        setState(() {
          _conversations = result.conversations;
          // Re-apply search filter if active
          if (_searchQuery.isEmpty) {
            _filteredConversations = result.conversations;
          } else {
            _filteredConversations = result.conversations
                .where((c) => c.preview
                .toLowerCase()
                .contains(_searchQuery.toLowerCase()))
                .toList();
          }
        });
      }
    } catch (_) {
      // Silent — don't disturb user if background refresh fails
    }
  }

  // ══════════════════════════════════════════════════════════
  // BUILD
  // ══════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            Expanded(
              child: _showHistory ? _buildHistoryPanel() : _buildChatPanel(),
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  // TOP BAR
  // ══════════════════════════════════════════════════════════
  Widget _buildTopBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                // Back button
                _TopBarBtn(
                  icon: Icons.arrow_back_ios_new_rounded,
                  onTap: () => Navigator.pop(context),
                ),
                const SizedBox(width: 10),

                // Avatar + title
                const _AIAvatar(size: 38, borderRadius: 12),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Trợ lý AI Bất Động Sản',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1a1a2e),
                        ),
                      ),
                      Row(
                        children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: const BoxDecoration(
                              color: Color(0xFF22C55E),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            'Đang hoạt động',
                            style: TextStyle(
                                fontSize: 11, color: Colors.grey[500]),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // History toggle
                _TopBarBtn(
                  icon: _showHistory
                      ? Icons.chat_bubble_rounded
                      : Icons.history_rounded,
                  onTap: () {
                    setState(() => _showHistory = !_showHistory);
                    if (_showHistory) _loadHistory();
                  },
                  tooltip: _showHistory ? 'Quay lại chat' : 'Lịch sử',
                ),
                const SizedBox(width: 6),

                // New chat
                _TopBarBtn(
                  icon: Icons.add_comment_rounded,
                  onTap: _startNewChat,
                  tooltip: 'Chat mới',
                  color: const Color(0xFF1E40AF),
                  iconColor: Colors.white,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  // HISTORY PANEL
  // ══════════════════════════════════════════════════════════
  Widget _buildHistoryPanel() {
    return FadeTransition(
      opacity: _fadeAnim,
      child: Column(
        children: [
          // Search bar
          Container(
            color: Colors.white,
            padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(14),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: _filterConversations,
                decoration: InputDecoration(
                  hintText: 'Tìm kiếm cuộc hội thoại...',
                  hintStyle: TextStyle(
                      color: Colors.grey[400], fontSize: 13),
                  prefixIcon:
                  Icon(Icons.search, color: Colors.grey[400], size: 20),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                    icon: Icon(Icons.close,
                        color: Colors.grey[400], size: 18),
                    onPressed: () {
                      _searchController.clear();
                      _filterConversations('');
                    },
                  )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                      vertical: 12, horizontal: 4),
                ),
              ),
            ),
          ),

          // Header row
          Container(
            color: Colors.white,
            padding:
            const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(
              children: [
                Text(
                  'Lịch sử hội thoại',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[600],
                  ),
                ),
                const Spacer(),
                if (_filteredConversations.isNotEmpty)
                  Text(
                    '${_filteredConversations.length} cuộc trò chuyện',
                    style:
                    TextStyle(fontSize: 11, color: Colors.grey[400]),
                  ),
              ],
            ),
          ),

          const Divider(height: 1),

          // List
          Expanded(
            child: _isLoadingHistory
                ?  Center(
              child: Container(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Loading animation
                    Lottie.asset(
                      AssetsConfig.loadingLottie,
                      width: 80,
                      height: 80,
                      fit: BoxFit.fill,
                    ),
                    const SizedBox(height: 16),
                    // Loading text
                    const Text(
                      'Đang mở lịch sử chat...',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black38,
                      ),
                    ),

                  ],
                ),
              ),
            )
                : RefreshIndicator(
              color: const Color(0xFF1E40AF),
              onRefresh: _loadHistory,
              child:_filteredConversations.isEmpty
                  ? LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: SizedBox(
                    height: constraints.maxHeight,
                    child: _buildEmptyHistory(),
                  ),
                ),
              )
                  : ListView.separated(
                controller: _historyScrollController,
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: _filteredConversations.length + (_hasMoreHistory ? 1 : 0),
                separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
                itemBuilder: (ctx, i) {
                  // Nút "Xem thêm" ở cuối
                  if (i == _filteredConversations.length) {
                    return _isLoadingMoreHistory
                        ? const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(child: CircularProgressIndicator(
                          color: Color(0xFF1E40AF), strokeWidth: 2)),
                    )
                        : Padding(
                      padding: const EdgeInsets.all(12),
                      child: GestureDetector(
                        onTap: _loadMoreHistory,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.expand_more_rounded,
                                  color: Color(0xFF1E40AF), size: 18),
                              SizedBox(width: 6),
                              Text('Xem thêm',
                                  style: TextStyle(
                                      color: Color(0xFF1E40AF),
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13)),
                            ],
                          ),
                        ),
                      ),
                    );
                  }

                  // Item conversation với nút xóa
                  return Dismissible(
                    key: Key(_filteredConversations[i].id),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      color: Colors.red[400],
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      child: const Icon(Icons.delete_rounded,
                          color: Colors.white, size: 22),
                    ),
                    onDismissed: (_) => _deleteConversation(
                        _filteredConversations[i].id),
                    child: _ConversationTile(
                      item: _filteredConversations[i],
                      isActive: conversationId == _filteredConversations[i].id,
                      onTap: () => _loadConversation(_filteredConversations[i].id),
                      onDelete: () => _deleteConversation(_filteredConversations[i].id),
                    ),
                  );
                },
              ),
            ),
          ),


        ],
      ),
    );
  }

  Widget _buildEmptyHistory() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.06),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.history_rounded,
                size: 48, color: Colors.blue[300]),
          ),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isNotEmpty
                ? 'Không tìm thấy kết quả'
                : 'Chưa có lịch sử hội thoại',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF374151),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isNotEmpty
                ? 'Thử từ khóa khác'
                : 'Bắt đầu chat để tạo lịch sử',
            style: TextStyle(fontSize: 13, color: Colors.grey[400]),
          ),
          if (_searchQuery.isEmpty) ...[
            const SizedBox(height: 24),
            _PrimaryBtn(
              label: 'Bắt đầu chat mới',
              icon: Icons.add_comment_rounded,
              onTap: _startNewChat,
            ),
          ],
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  // CHAT PANEL
  // ══════════════════════════════════════════════════════════
  Widget _buildChatPanel() {
    return Column(
      children: [
        // Suggestions chips (only when fresh)
        if (suggestions.isNotEmpty && messages.length <= 2)
          _buildSuggestions(),

        // Messages
        Expanded(
          child: messages.isEmpty
              ? _buildWelcomeScreen()
              : ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 8),
            itemCount: messages.length + (isLoading ? 1 : 0),
            itemBuilder: (ctx, i) {
              if (i == messages.length) return _buildTyping();
              return _buildMessageItem(ctx, messages[i]);
            },
          ),
        ),

        // Input
        _buildInput(),
      ],
    );
  }

  // ── Welcome screen ─────────────────────────────────────────
  Widget _buildWelcomeScreen() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF1E40AF).withOpacity(0.25),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  )
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: Image.asset(
                  'assets/img/ai.jpg',
                  width: 90,
                  height: 90,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF1E40AF), Color(0xFF60A5FA)],
                      ),
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: const Icon(Icons.smart_toy_rounded,
                        size: 40, color: Colors.white),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Trợ lý AI BĐS',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1a1a2e),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Hỏi tôi bất cứ điều gì về bất động sản!\nTôi sẽ giúp bạn tìm ngôi nhà phù hợp.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 14, color: Colors.grey[500], height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  // ── Suggestions ────────────────────────────────────────────
  Widget _buildSuggestions() {
    final chips = [
      if (isLocationAvailable) ...[
        _SuggestChip(
            label: '📍 Gần tôi',
            onTap: () => _tapSuggestion('Tìm nhà trọ gần vị trí hiện tại')),
        _SuggestChip(
            label: '🏫 Gần trường',
            onTap: () => _tapSuggestion('Tìm nhà gần trường học')),
      ],
      ...suggestions
          .take(3)
          .map((s) => _SuggestChip(
          label: s.length > 30 ? '${s.substring(0, 28)}…' : s,
          onTap: () => _tapSuggestion(s))),
    ];

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: chips
              .map((c) => Padding(
            padding: const EdgeInsets.only(right: 8),
            child: c,
          ))
              .toList(),
        ),
      ),
    );
  }

  void _tapSuggestion(String text) {
    _controller.text = text;
    sendMessage();
  }

  // ── Typing indicator ───────────────────────────────────────
  Widget _buildTyping() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 4,
                )
              ],
            ),
            child: const _AIAvatar(size: 38, borderRadius: 12),
          ),
          const SizedBox(width: 8),
          Container(
            padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.05), blurRadius: 6)
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _Dot(delay: 0),
                const SizedBox(width: 4),
                _Dot(delay: 150),
                const SizedBox(width: 4),
                _Dot(delay: 300),
                const SizedBox(width: 8),
                Text('AI đang xử lý...',
                    style:
                    TextStyle(fontSize: 12, color: Colors.grey[500])),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Input ──────────────────────────────────────────────────
  Widget _buildInput() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 16,
              offset: const Offset(0, -4)),
        ],
      ),
      padding:
      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(20),
              ),
              child: TextField(
                controller: _controller,
                maxLines: 4,
                minLines: 1,
                textInputAction: TextInputAction.newline,
                decoration: InputDecoration(
                  hintText: 'Nhập câu hỏi của bạn...',
                  hintStyle:
                  TextStyle(color: Colors.grey[400], fontSize: 14),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: isLoading ? null : sendMessage,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                gradient: isLoading
                    ? LinearGradient(
                    colors: [Colors.grey[300]!, Colors.grey[300]!])
                    : const LinearGradient(
                  colors: [Color(0xFF1E40AF), Color(0xFF3B82F6)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: isLoading
                    ? []
                    : [
                  BoxShadow(
                    color: const Color(0xFF1E40AF).withOpacity(0.35),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  )
                ],
              ),
              child: Icon(
                isLoading ? Icons.hourglass_empty : Icons.send_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  // MESSAGE ITEM
  // ══════════════════════════════════════════════════════════
  Widget _buildMessageItem(
      BuildContext context, Map<String, dynamic> msg) {
    // ── RENTAL LIST ─────────────────────────────────────────
    if (msg['type'] == 'rental_list' && msg['rentals'] != null) {
      final rentals = msg['rentals'] as List<Rental>;
      final groupId = msg['groupId'] as String;

      return StatefulBuilder(
        builder: (ctx, setLocalState) {
          final showCount =
              _rentalGroupShowCount[groupId] ?? _initialShowCount;
          final display = rentals.take(showCount).toList();

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                ...display.map((r) => _ModernRentalCard(
                  rental: r,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => RentalDetailScreen(rental: r)),
                  ),
                )),

                if (showCount < rentals.length)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 6, 4, 2),
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _rentalGroupShowCount[groupId] =
                              (showCount + 5).clamp(0, rentals.length);
                        });
                      },
                      child: Container(
                        width: double.infinity,
                        padding:
                        const EdgeInsets.symmetric(vertical: 13),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              Color(0xFF1E40AF),
                              Color(0xFF3B82F6)
                            ],
                          ),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF1E40AF)
                                  .withOpacity(0.25),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            )
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.expand_more_rounded,
                                color: Colors.white, size: 18),
                            const SizedBox(width: 6),
                            Text(
                              'Xem thêm ${rentals.length - showCount} bài đăng',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                if (showCount >= rentals.length && rentals.length > 5)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle_rounded,
                            color: Colors.green[500], size: 14),
                        const SizedBox(width: 5),
                        Text(
                          'Đã hiển thị tất cả ${rentals.length} bài',
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          );
        },
      );
    }

    // ── RENTAL HEADER ────────────────────────────────────────
    if (msg['type'] == 'rental_header') {
      return Padding(
        padding: const EdgeInsets.fromLTRB(0, 12, 0, 4),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [Color(0xFF1E40AF), Color(0xFF3B82F6)]),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.home_rounded,
                  color: Colors.white, size: 18),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Gợi Ý Bài Đăng Phù Hợp',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Colors.blue[700],
                    fontSize: 14,
                  ),
                ),
                Text(
                  'Tìm thấy ${msg['count']} bài đăng phù hợp nhất',
                  style:
                  TextStyle(fontSize: 11, color: Colors.grey[500]),
                ),
              ],
            ),
          ],
        ),
      );
    }

    // ── TEXT BUBBLE ──────────────────────────────────────────
    final isUser = msg['role'] == 'user';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment:
        isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(9),
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 4,
                  )
                ],
              ),
              child:const _AIAvatar(size: 38, borderRadius: 12),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.72,
              ),
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isUser
                    ? const Color(0xFF1E40AF)
                    : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isUser ? 16 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 16),
                ),
                boxShadow: [
                  BoxShadow(
                    color: isUser
                        ? const Color(0xFF1E40AF).withOpacity(0.2)
                        : Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                msg['text'] ?? '',
                style: TextStyle(
                  color: isUser ? Colors.white : const Color(0xFF1a1a2e),
                  fontSize: 14,
                  height: 1.45,
                ),
              ),
            ),
          ),
          if (isUser) const SizedBox(width: 4),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════
// CONVERSATION TILE
// ════════════════════════════════════════════════════════════
class _ConversationTile extends StatelessWidget {
  final ConversationItem item;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _ConversationTile({
    required this.item,
    required this.isActive,
    required this.onTap,
    required this.onDelete,
  });

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}p trước';
    if (diff.inHours < 24) return '${diff.inHours}h trước';
    if (diff.inDays < 7) return '${diff.inDays}d trước';
    return DateFormat('dd/MM').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        color: isActive ? Colors.blue.withOpacity(0.05) : Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isActive
                    ? const Color(0xFF1E40AF)
                    : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(
                Icons.chat_bubble_outline_rounded,
                color: isActive ? Colors.white : Colors.grey[400],
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.preview.isNotEmpty
                        ? item.preview
                        : 'Cuộc trò chuyện',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: isActive
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: const Color(0xFF1a1a2e),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Icon(Icons.message_outlined,
                          size: 11, color: Colors.grey[400]),
                      const SizedBox(width: 3),
                      Text(
                        '${item.messageCount} tin nhắn',
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey[400]),
                      ),
                      const SizedBox(width: 8),
                      if (item.recommendationCount > 0) ...[
                        Icon(Icons.home_outlined,
                            size: 11, color: Colors.blue[300]),
                        const SizedBox(width: 3),
                        Text(
                          '${item.recommendationCount} gợi ý',
                          style: TextStyle(
                              fontSize: 11, color: Colors.blue[400]),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _formatTime(item.lastMessageAt),
                  style:
                  TextStyle(fontSize: 11, color: Colors.grey[400]),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: item.status == 'active'
                        ? Colors.green.withOpacity(0.12)
                        : Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    item.status == 'active' ? 'Đang chat' : 'Xong',
                    style: TextStyle(
                      fontSize: 9,
                      color: item.status == 'active'
                          ? Colors.green[600]
                          : Colors.grey[400],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),

                const SizedBox(height: 4),
                GestureDetector(
                  onTap: onDelete,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(Icons.delete_outline_rounded,
                        size: 14, color: Colors.red[400]),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════
// MODERN RENTAL CARD
// ════════════════════════════════════════════════════════════
class _ModernRentalCard extends StatelessWidget {
  final Rental rental;
  final VoidCallback? onTap;

  const _ModernRentalCard({required this.rental, this.onTap});

  String _formatPrice(double price) {
    if (price >= 1e9) return '${(price / 1e9).toStringAsFixed(1)} tỷ';
    if (price >= 1e6) return '${(price / 1e6).toStringAsFixed(1)}tr';
    return NumberFormat.currency(
        locale: 'vi_VN', symbol: '₫', decimalDigits: 0)
        .format(price);
  }

  @override
  Widget build(BuildContext context) {
    final img = rental.images.isNotEmpty
        ? rental.images[0]
        : 'https://via.placeholder.com/400x200?text=No+Image';
    final area = rental.area['total']?.toString() ?? '0';
    final beds = rental.area['bedrooms']?.toString() ?? '0';
    final baths = rental.area['bathrooms']?.toString() ?? '0';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 2),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Image
                SizedBox(
                  width: 118,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.network(img,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: Colors.grey[200],
                            child: Icon(Icons.home_outlined,
                                color: Colors.grey[400], size: 32),
                          )),
                      Positioned(
                        top: 8,
                        left: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E40AF),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            rental.propertyType,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 8,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Content
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              rental.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1a1a2e),
                                height: 1.3,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(Icons.place_outlined,
                                    size: 10, color: Colors.grey[500]),
                                const SizedBox(width: 2),
                                Expanded(
                                  child: Text(
                                    rental.location['short'] ?? '—',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                        fontSize: 10, color: Colors.grey[500]),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 5),
                            Row(
                              children: [
                                if (area != '0') ...[
                                  _Chip(
                                      icon: Icons.square_foot,
                                      label: '${area}m²'),
                                  const SizedBox(width: 4),
                                ],
                                if (beds != '0') ...[
                                  _Chip(
                                      icon: Icons.bed_outlined, label: beds),
                                  const SizedBox(width: 4),
                                ],
                                if (baths != '0')
                                  _Chip(
                                      icon: Icons.bathroom_outlined,
                                      label: baths),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _formatPrice(rental.price),
                                  style: const TextStyle(
                                    color: Color(0xFFDC2626),
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (rental.confidence != null &&
                                    rental.confidence! > 0)
                                  Text(
                                    'Phù hợp ${(rental.confidence! * 100).toStringAsFixed(0)}%',
                                    style: TextStyle(
                                        fontSize: 9,
                                        color: Colors.blue[600]),
                                  ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E40AF),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text('Xem',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
class _AIAvatar extends StatelessWidget {
  final double size;
  final double borderRadius;

  const _AIAvatar({this.size = 38, this.borderRadius = 12});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Image.asset(
        'assets/img/ai.jpg',
        width: size,
        height: size,
        fit: BoxFit.cover,
        // 🔥 Fallback khi asset lỗi
        errorBuilder: (_, __, ___) => Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1E40AF), Color(0xFF3B82F6)],
            ),
            borderRadius: BorderRadius.circular(borderRadius),
          ),
          child: Icon(
            Icons.smart_toy_rounded,
            color: Colors.white,
            size: size * 0.5,
          ),
        ),
      ),
    );
  }
}
// ════════════════════════════════════════════════════════════
// SMALL WIDGETS
// ════════════════════════════════════════════════════════════
class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _Chip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 9, color: Colors.grey[600]),
          const SizedBox(width: 2),
          Text(label,
              style: TextStyle(
                  fontSize: 9,
                  color: Colors.grey[700],
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _TopBarBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;
  final Color? color;
  final Color? iconColor;

  const _TopBarBtn({
    required this.icon,
    required this.onTap,
    this.tooltip,
    this.color,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip ?? '',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: color ?? const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(icon,
              size: 18,
              color: iconColor ?? const Color(0xFF374151)),
        ),
      ),
    );
  }
}

class _SuggestChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _SuggestChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
        const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.blue.withOpacity(0.07),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: Colors.blue.withOpacity(0.2), width: 1),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 12,
                color: Colors.blue[700],
                fontWeight: FontWeight.w500)),
      ),
    );
  }
}

class _PrimaryBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _PrimaryBtn(
      {required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
        const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1E40AF), Color(0xFF3B82F6)],
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF1E40AF).withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 16),
            const SizedBox(width: 8),
            Text(label,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14)),
          ],
        ),
      ),
    );
  }
}

class _Dot extends StatefulWidget {
  final int delay;
  const _Dot({required this.delay});
  @override
  State<_Dot> createState() => _DotState();
}

class _DotState extends State<_Dot> with SingleTickerProviderStateMixin {
  late AnimationController _c;
  late Animation<double> _a;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _a = Tween(begin: 0.3, end: 1.0).animate(
        CurvedAnimation(parent: _c, curve: Curves.easeInOut));
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _c.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _a,
      child: Container(
        width: 7,
        height: 7,
        decoration: BoxDecoration(
          color: const Color(0xFF1E40AF),
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    );
  }
}