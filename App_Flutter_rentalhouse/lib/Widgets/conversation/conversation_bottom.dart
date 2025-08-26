import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_rentalhouse/constants/app_style.dart';
import 'package:flutter_rentalhouse/models/conversation.dart';
import 'package:flutter_rentalhouse/utils/navigation_conversation.dart';
import 'package:flutter_rentalhouse/views/chat_user.dart';
import 'package:shimmer/shimmer.dart';

void showSearchBottomSheet({
  required BuildContext context,
  required TextEditingController searchController,
  required FocusNode searchFocusNode,
  required ValueNotifier<List<Conversation>> filteredConversations,
  required Function(String) onSearchChanged,
  required TickerProvider vsync,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    backgroundColor: Colors.white.withOpacity(0.95),
    transitionAnimationController: AnimationController(
      vsync: vsync,
      duration: const Duration(milliseconds: 400),
      animationBehavior: AnimationBehavior.preserve,
    )..forward(),
    builder: (context) {
      return Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 20,
          right: 20,
          top: 20,
        ),
        child: ValueListenableBuilder<List<Conversation>>(
          valueListenable: filteredConversations,
          builder: (context, filteredConversations, child) {
            return Container(
              decoration: const BoxDecoration(
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.75,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.blue.shade50, Colors.white],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blue.shade100.withOpacity(0.2),
                          blurRadius: 8,
                          spreadRadius: 1,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: searchController,
                      focusNode: searchFocusNode,
                      decoration: InputDecoration(
                        hintText: 'Tìm kiếm người dùng...',
                        hintStyle: TextStyle(
                          color: Colors.grey.shade500,
                          fontWeight: FontWeight.w400,
                        ),
                        prefixIcon: AnimatedScale(
                          scale: searchFocusNode.hasFocus ? 1.1 : 1.0,
                          duration: const Duration(milliseconds: 200),
                          child: Icon(Icons.search,
                              color: AppStyles.primaryColor, size: 24),
                        ),
                        suffixIcon: searchController.text.isNotEmpty
                            ? IconButton(
                                icon: AnimatedScale(
                                  scale: 1.0,
                                  duration: const Duration(milliseconds: 200),
                                  child: Icon(Icons.clear,
                                      color: Colors.grey.shade600, size: 22),
                                ),
                                onPressed: () {
                                  searchController.clear();
                                  onSearchChanged('');
                                },
                              )
                            : null,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: AppStyles.primaryColor,
                            width: 2,
                          ),
                        ),
                        filled: true,
                        fillColor: Colors.transparent,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 16,
                        ),
                      ),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.black87,
                      ),
                      onChanged: onSearchChanged,
                      onTap: () {
                        searchFocusNode.requestFocus();
                      },
                    ),
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: filteredConversations.isEmpty
                        ? Center(
                            child: Shimmer.fromColors(
                              baseColor: Colors.grey.shade200,
                              highlightColor: Colors.grey.shade100,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.search_off,
                                    size: 48,
                                    color: Colors.grey.shade400,
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    searchController.text.isEmpty
                                        ? 'Không có cuộc trò chuyện nào'
                                        : 'Không tìm thấy người dùng nào',
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontFamily: 'Roboto',
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : ListView.builder(
                            padding: EdgeInsets.zero,
                            itemCount: filteredConversations.length,
                            itemBuilder: (context, index) {
                              final conversation = filteredConversations[index];
                              final landlord = conversation.landlord;
                              return InkWell(
                                onTap: () {
                                  Navigator.pop(context);
                                  Navigator.push(
                                    context,
                                    NavigationUtils.createSlideRoute(
                                      ChatScreen(
                                        rentalId: conversation.rentalId,
                                        landlordId: conversation.landlord['id'],
                                        conversationId: conversation.id,
                                      ),
                                    ),
                                  );
                                },
                                borderRadius: BorderRadius.circular(16),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  margin: const EdgeInsets.only(bottom: 16),
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 12, horizontal: 16),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.blue.shade50,
                                        Colors.white,
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.blue.shade100
                                            .withOpacity(0.2),
                                        blurRadius: 8,
                                        spreadRadius: 1,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                    border: Border.all(
                                      color:
                                          Colors.blue.shade100.withOpacity(0.5),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 26,
                                        backgroundColor: Colors.blue.shade100,
                                        backgroundImage:
                                            landlord['avatarBase64']
                                                        ?.isNotEmpty ==
                                                    true
                                                ? MemoryImage(base64Decode(
                                                    landlord['avatarBase64']
                                                        as String))
                                                : null,
                                        child:
                                            landlord['avatarBase64']?.isEmpty ==
                                                    true
                                                ? Icon(
                                                    Icons.person,
                                                    color: Colors.blue.shade700,
                                                    size: 30,
                                                  )
                                                : null,
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Text(
                                          landlord['username'] ?? 'Chủ nhà',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontFamily: 'Roboto',
                                            fontSize: 16,
                                            color: Colors.blue.shade800,
                                            letterSpacing: 0.2,
                                          ),
                                        ),
                                      ),
                                      AnimatedScale(
                                        scale: 1.0,
                                        duration:
                                            const Duration(milliseconds: 200),
                                        child: Icon(
                                          Icons.chat,
                                          color: AppStyles.primaryColor,
                                          size: 24,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        ),
      );
    },
  ).whenComplete(() {
    searchController.clear();
    onSearchChanged('');
  });
}
