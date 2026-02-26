// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'csv_field_analysis.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class CsvFieldInfoAdapter extends TypeAdapter<CsvFieldInfo> {
  @override
  final int typeId = 2;

  @override
  CsvFieldInfo read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return CsvFieldInfo(
      columnName: fields[0] as String,
      detectedType: fields[1] as String,
      mappedTo: fields[2] as String,
      sampleValues: (fields[3] as List).cast<String>(),
      columnIndex: fields[4] as int,
      confidence: fields[5] as double,
    );
  }

  @override
  void write(BinaryWriter writer, CsvFieldInfo obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.columnName)
      ..writeByte(1)
      ..write(obj.detectedType)
      ..writeByte(2)
      ..write(obj.mappedTo)
      ..writeByte(3)
      ..write(obj.sampleValues)
      ..writeByte(4)
      ..write(obj.columnIndex)
      ..writeByte(5)
      ..write(obj.confidence);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CsvFieldInfoAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class CsvFieldAnalysisAdapter extends TypeAdapter<CsvFieldAnalysis> {
  @override
  final int typeId = 3;

  @override
  CsvFieldAnalysis read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return CsvFieldAnalysis(
      fileUploadId: fields[0] as String,
      fields: (fields[1] as List).cast<CsvFieldInfo>(),
      analyzedAt: fields[2] as DateTime,
      totalRows: fields[3] as int,
      totalColumns: fields[4] as int,
      hasHeader: fields[5] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, CsvFieldAnalysis obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.fileUploadId)
      ..writeByte(1)
      ..write(obj.fields)
      ..writeByte(2)
      ..write(obj.analyzedAt)
      ..writeByte(3)
      ..write(obj.totalRows)
      ..writeByte(4)
      ..write(obj.totalColumns)
      ..writeByte(5)
      ..write(obj.hasHeader);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CsvFieldAnalysisAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
