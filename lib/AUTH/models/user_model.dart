class User {
  final String id;
  final String username;
  final String email;
  final String firstName;
  final String lastName;
  final String mobile;
  final String address;
  // final String profile;

  User({
    required this.id,
    required this.username,
    required this.email,
    this.firstName = '',
    this.lastName = '',
    this.mobile = '',
    this.address = '',
    // this.profile = '',
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] ?? '',
      username: json['username'] ?? '',
      email: json['email'] ?? '',
      firstName: json['firstName'] ?? '',
      lastName: json['lastName'] ?? '',
      mobile: json['mobile'] ?? '',
      address: json['address'] ?? '',
      // profile: json['profile'] ?? '',
    );
  }
}
