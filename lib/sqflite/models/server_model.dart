class ServerModel {
  final int? id;
  final String name;
  final String address;
  final String type;
  final bool isConnected;
  final String? username;
  final String? password;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  ServerModel({
    this.id,
    required this.name,
    required this.address,
    required this.type,
    required this.isConnected,
    this.username,
    this.password,
    this.notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  // JSON 직렬화
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'address': address,
      'type': type,
      'isConnected': isConnected ? 1 : 0,
      'username': username,
      'password': password,
      'notes': notes,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  // JSON 역직렬화
  factory ServerModel.fromJson(Map<String, dynamic> json) {
    return ServerModel(
      id: json['id'] as int?,
      name: json['name'] as String,
      address: json['address'] as String,
      type: json['type'] as String,
      isConnected: (json['isConnected'] as int) == 1,
      username: json['username'] as String?,
      password: json['password'] as String?,
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  // Server 모델로 변환 (UI 호환성)
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'address': address,
      'type': type,
      'isConnected': isConnected,
    };
  }

  // 복사 생성자
  ServerModel copyWith({
    int? id,
    String? name,
    String? address,
    String? type,
    bool? isConnected,
    String? username,
    String? password,
    String? notes,
    DateTime? updatedAt,
  }) {
    return ServerModel(
      id: id ?? this.id,
      name: name ?? this.name,
      address: address ?? this.address,
      type: type ?? this.type,
      isConnected: isConnected ?? this.isConnected,
      username: username ?? this.username,
      password: password ?? this.password,
      notes: notes ?? this.notes,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }
}

