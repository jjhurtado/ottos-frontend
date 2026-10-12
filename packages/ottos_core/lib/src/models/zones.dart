import 'package:equatable/equatable.dart';

class Province extends Equatable {
  const Province({required this.code, required this.name});

  factory Province.fromJson(Map<String, dynamic> json) =>
      Province(code: json['code'] as String, name: json['name'] as String? ?? '');

  final String code;
  final String name;

  @override
  List<Object?> get props => [code];
}

class Municipality extends Equatable {
  const Municipality({required this.code, required this.name, required this.provinceCode, this.provinceName});

  factory Municipality.fromJson(Map<String, dynamic> json) => Municipality(
    code: json['code'] as String,
    name: json['name'] as String? ?? '',
    provinceCode: json['provinceCode'] as String? ?? '',
    provinceName: json['provinceName'] as String?,
  );

  final String code;
  final String name;
  final String provinceCode;
  final String? provinceName;

  @override
  List<Object?> get props => [code];
}
