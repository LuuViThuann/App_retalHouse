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
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    backgroundColor: Colors.white.withOpacity(0.95),
    transitionAnimationController: AnimationController(
      vsync: vsync,
      duration: Duration(milliseconds: 300),
    )..forward(),
    builder: (context) {
      return Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 16,
          right: 16,
          top: 16,
        ),
        child: ValueListenableBuilder<List<Conversation>>(
          valueListenable: filteredConversations,
          builder: (context, filteredConversations, child) {
            return Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.7,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: searchController,
                          focusNode: searchFocusNode,
                          decoration: InputDecoration(
                            hintText: 'Tìm kiếm người dùng...',
                            prefixIcon: Icon(Icons.search,
                                color: AppStyles.primaryColor),
                            suffixIcon: searchController.text.isNotEmpty
                                ? IconButton(
                                    icon: Icon(Icons.clear,
                                        color: Colors.grey[600]),
                                    onPressed: () {
                                      searchController.clear();
                                      onSearchChanged('');
                                    },
                                  )
                                : null,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                  color: AppStyles.primaryColor, width: 2),
                            ),
                            filled: true,
                            fillColor: Colors.white.withOpacity(0.9),
                            contentPadding: EdgeInsets.symmetric(
                                vertical: 10, horizontal: 12),
                          ),
                          onChanged: onSearchChanged,
                          onTap: () {
                            searchFocusNode.requestFocus();
                          },
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  Expanded(
                    child: filteredConversations.isEmpty
                        ? Center(
                            child: Shimmer.fromColors(
                              baseColor: Colors.grey[300]!,
                              highlightColor: Colors.grey[100]!,
                              child: Text(
                                searchController.text.isEmpty
                                    ? 'Không có cuộc trò chuyện nào'
                                    : 'Không tìm thấy người dùng nào',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontFamily: 'Roboto',
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          )
                        : ListView.builder(
                            padding: EdgeInsets.zero,
                            itemCount: filteredConversations.length,
                            itemBuilder: (context, index) {
                              final conversation = filteredConversations[index];
                              final landlord = conversation.landlord;
                              return AnimatedContainer(
                                duration: Duration(milliseconds: 200),
                                margin: EdgeInsets.only(bottom: 12),
                                child: GestureDetector(
                                  onTap: () {
                                    Navigator.pop(context);
                                    Navigator.push(
                                      context,
                                      NavigationUtils.createSlideRoute(
                                        ChatScreen(
                                          rentalId: conversation.rentalId,
                                          landlordId:
                                              conversation.landlord['id'],
                                          conversationId: conversation.id,
                                        ),
                                      ),
                                    );
                                  },
                                  child: Container(
                                    padding: EdgeInsets.symmetric(
                                        vertical: 8, horizontal: 12),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          Colors.blue[50]!,
                                          Colors.white
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                          color: Colors.blue[100]!, width: 1),
                                    ),
                                    child: Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 24,
                                          backgroundColor: Colors.blue[50],
                                          backgroundImage:
                                              landlord['avatarBase64']
                                                          ?.isNotEmpty ==
                                                      true
                                                  ? MemoryImage(base64Decode(
                                                      landlord['avatarBase64']
                                                          as String))
                                                  : null,
                                          child: landlord['avatarBase64']
                                                      ?.isEmpty ==
                                                  true
                                              ? Icon(Icons.person,
                                                  color: Colors.blue[700],
                                                  size: 28)
                                              : null,
                                        ),
                                        SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            landlord['username'] ?? 'Chủ nhà',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontFamily: 'Roboto',
                                              fontSize: 16,
                                              color: Colors.blue[500],
                                            ),
                                          ),
                                        ),
                                        Icon(
                                          Icons.chat,
                                          color: AppStyles.primaryColor,
                                          size: 24,
                                        ),
                                      ],
                                    ),
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
