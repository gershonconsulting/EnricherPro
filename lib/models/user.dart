class User {
  final int id;
  final String firstName;
  final String lastName;
  final String email;
  final String company;
  final String title;
  final String plan;

  const User({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.company,
    required this.title,
    required this.plan,
  });

  factory User.fromJson(Map<String, dynamic> json) => User(
        id: json['id'] as int,
        firstName: json['first_name'] as String? ?? '',
        lastName: json['last_name'] as String? ?? '',
        email: json['email'] as String? ?? '',
        company: json['company'] as String? ?? '',
        title: json['title'] as String? ?? '',
        plan: json['plan'] as String? ?? 'free',
      );

  String get fullName => '$firstName $lastName'.trim();
  bool get isPaid => plan != 'free';
}
