class Comment {
  final String id;
  final String rentalId;
  final User userId;
  final String content;
  final DateTime createdAt;
  final List<Reply> replies;
  final List<Like> likes;

  Comment({
    required this.id,
    required this.rentalId,
    required this.userId,
    required this.content,
    required this.createdAt,
    required this.replies,
    required this.likes,
  });

  factory Comment.fromJson(Map<String, dynamic> json) {
    return Comment(
      id: json['_id'],
      rentalId: json['rentalId'],
      userId: User.fromJson(json['userId']),
      content: json['content'],
      createdAt: DateTime.parse(json['createdAt']),
      replies: (json['replies'] as List<dynamic>?)
          ?.map((reply) => Reply.fromJson(reply))
          .toList() ?? [],
      likes: (json['likes'] as List<dynamic>?)
          ?.map((like) => Like.fromJson(like))
          .toList() ?? [],
    );
  }
}

class User {
  final String id;
  final String? username;
  final String? avatarBase64;

  User({
    required this.id,
    this.username,
    this.avatarBase64,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['_id'] ?? json['uid'], // Handle both MongoDB and Firebase user IDs
      username: json['username'],
      avatarBase64: json['avatarBase64'],
    );
  }
}

class Reply {
  final User userId;
  final String content;
  final DateTime createdAt;

  Reply({
    required this.userId,
    required this.content,
    required this.createdAt,
  });

  factory Reply.fromJson(Map<String, dynamic> json) {
    return Reply(
      userId: User.fromJson(json['userId']),
      content: json['content'],
      createdAt: DateTime.parse(json['createdAt']),
    );
  }
}

class Like {
  final String userId;
  final DateTime createdAt;

  Like({
    required this.userId,
    required this.createdAt,
  });

  factory Like.fromJson(Map<String, dynamic> json) {
    return Like(
      userId: json['userId']['_id'] ?? json['userId'],
      createdAt: DateTime.parse(json['createdAt']),
    );
  }
}