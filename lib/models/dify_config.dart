class DifyConfig {
  final String id;
  final String name;
  final String apiUrl;
  final String apiKey;

  DifyConfig({
    required this.id,
    required this.name,
    required this.apiUrl,
    required this.apiKey,
  });

  factory DifyConfig.fromJson(Map<String, dynamic> json) {
    return DifyConfig(
      id: json['id'],
      name: json['name'],
      apiUrl: json['apiUrl'],
      apiKey: json['apiKey'],
    );
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'name': name, 'apiUrl': apiUrl, 'apiKey': apiKey};
  }

  DifyConfig copyWith({
    String? id,
    String? name,
    String? apiUrl,
    String? apiKey,
  }) {
    return DifyConfig(
      id: id ?? this.id,
      name: name ?? this.name,
      apiUrl: apiUrl ?? this.apiUrl,
      apiKey: apiKey ?? this.apiKey,
    );
  }
}
