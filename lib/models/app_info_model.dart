import 'package:cloud_firestore/cloud_firestore.dart';

class AppInfoModel {
  final String vision;
  final String version;
  final String university;
  final String appLogoUrl;
  final List<ContributorModel> contributors;

  AppInfoModel({
    required this.vision,
    required this.version,
    required this.university,
    required this.appLogoUrl,
    required this.contributors,
  });

  factory AppInfoModel.fromFirestore(DocumentSnapshot doc) {
    if (!doc.exists || doc.data() == null) {
      return AppInfoModel(
        vision: '',
        version: '',
        university: '',
        appLogoUrl: '',
        contributors: [],
      );
    }
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return AppInfoModel(
      vision: data['vision'] ?? '',
      version: data['version'] ?? '',
      university: data['university'] ?? '',
      appLogoUrl: data['appLogoUrl'] ?? '',
      contributors: (data['contributors'] as List? ?? [])
          .map((item) => ContributorModel.fromMap(item))
          .toList(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'vision': vision,
      'version': version,
      'university': university,
      'appLogoUrl': appLogoUrl,
      'contributors': contributors.map((c) => c.toMap()).toList(),
    };
  }
}

class ContributorModel {
  final String name;
  final String role;
  final String subtitle;

  ContributorModel({
    required this.name,
    required this.role,
    required this.subtitle,
  });

  factory ContributorModel.fromMap(Map<String, dynamic> map) {
    return ContributorModel(
      name: map['name'] ?? '',
      role: map['role'] ?? '',
      subtitle: map['subtitle'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'role': role,
      'subtitle': subtitle,
    };
  }
}
