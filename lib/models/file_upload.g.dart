// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'file_upload.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class FileUploadAdapter extends TypeAdapter<FileUpload> {
  @override
  final int typeId = 1;

  @override
  FileUpload read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return FileUpload(
      id: fields[0] as String,
      fileName: fields[1] as String,
      recordCount: fields[2] as int,
      uploadDate: fields[3] as DateTime,
      status: fields[4] as String,
      enrichedCount: fields[5] as int,
      filePath: fields[6] as String?,
      originalFileBytes: (fields[7] as List?)?.cast<int>(),
      enrichedFileBytes: (fields[8] as List?)?.cast<int>(),
      completionDate: fields[9] as DateTime?,
      successRate: fields[10] as double?,
      avgConfidence: fields[11] as double?,
      processingDuration: fields[12] as int?,
    );
  }

  @override
  void write(BinaryWriter writer, FileUpload obj) {
    writer
      ..writeByte(13)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.fileName)
      ..writeByte(2)
      ..write(obj.recordCount)
      ..writeByte(3)
      ..write(obj.uploadDate)
      ..writeByte(4)
      ..write(obj.status)
      ..writeByte(5)
      ..write(obj.enrichedCount)
      ..writeByte(6)
      ..write(obj.filePath)
      ..writeByte(7)
      ..write(obj.originalFileBytes)
      ..writeByte(8)
      ..write(obj.enrichedFileBytes)
      ..writeByte(9)
      ..write(obj.completionDate)
      ..writeByte(10)
      ..write(obj.successRate)
      ..writeByte(11)
      ..write(obj.avgConfidence)
      ..writeByte(12)
      ..write(obj.processingDuration);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FileUploadAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
