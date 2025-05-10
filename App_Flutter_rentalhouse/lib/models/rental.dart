class Rental {
  final String? id;
  final String title;
  final String description;
  final double price;
  final String location;
  final String userId;
  final List<String> images;
  final DateTime createdAt;

  Rental({
    this.id,
    required this.title,
    required this.description,
    required this.price,
    required this.location,
    required this.userId,
    required this.images,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    '_id': id,
    'title': title,
    'description': description,
    'price': price,
    'location': location,
    'userId': userId,
    'images': images,
    'createdAt': createdAt.toIso8601String(),
  };

  factory Rental.fromJson(Map<String, dynamic> json) => Rental(
    id: json['_id'],
    title: json['title'],
    description: json['description'],
    price: json['price'].toDouble(),
    location: json['location'],
    userId: json['userId'],
    images: List<String>.from(json['images']),
    createdAt: DateTime.parse(json['createdAt']),
  );
}