class User {
  final String companyCode;
  final String username;
  final String password;
  final String locationCode;

  User({
    required this.companyCode,
    required this.username,
    required this.password,
    required this.locationCode,
  });

  // Factory constructor to create a User from JSON (database result)
  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      companyCode: json['CmpyCode'] as String,
      username: json['user_name'] as String,
      password: json['password'] as String,
      locationCode: json['locCode'] as String,
    );
  }

  // Convert a User to JSON (for storage or API calls)
  Map<String, dynamic> toJson() {
    return {
      'CmpyCode': companyCode,
      'user_name': username,
      'password': password,
      'locCode': locationCode,
    };
  }

  @override
  String toString() {
    return 'User(companyCode: $companyCode, username: $username, locationCode: $locationCode)';
  }

  // Optional: Equality comparison
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is User &&
        other.companyCode == companyCode &&
        other.username == username &&
        other.locationCode == locationCode;
  }

  @override
  int get hashCode {
    return companyCode.hashCode ^ username.hashCode ^ locationCode.hashCode;
  }
}