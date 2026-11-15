// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $ReelsTable extends Reels with TableInfo<$ReelsTable, ReelRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ReelsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<ReelStatus, String> status =
      GeneratedColumn<String>(
        'status',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<ReelStatus>($ReelsTable.$converterstatus);
  @override
  late final GeneratedColumnWithTypeConverter<DateTime, int> createdAt =
      GeneratedColumn<int>(
        'created_at',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<DateTime>($ReelsTable.$convertercreatedAt);
  @override
  late final GeneratedColumnWithTypeConverter<DateTime, int> updatedAt =
      GeneratedColumn<int>(
        'updated_at',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<DateTime>($ReelsTable.$converterupdatedAt);
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    description,
    status,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'reels';
  @override
  VerificationContext validateIntegrity(
    Insertable<ReelRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ReelRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ReelRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      ),
      status: $ReelsTable.$converterstatus.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}status'],
        )!,
      ),
      createdAt: $ReelsTable.$convertercreatedAt.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}created_at'],
        )!,
      ),
      updatedAt: $ReelsTable.$converterupdatedAt.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}updated_at'],
        )!,
      ),
    );
  }

  @override
  $ReelsTable createAlias(String alias) {
    return $ReelsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<ReelStatus, String, String> $converterstatus =
      const EnumNameConverter<ReelStatus>(ReelStatus.values);
  static TypeConverter<DateTime, int> $convertercreatedAt =
      const UtcMillisConverter();
  static TypeConverter<DateTime, int> $converterupdatedAt =
      const UtcMillisConverter();
}

class ReelRow extends DataClass implements Insertable<ReelRow> {
  final int id;
  final String name;
  final String? description;
  final ReelStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  const ReelRow({
    required this.id,
    required this.name,
    this.description,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    {
      map['status'] = Variable<String>(
        $ReelsTable.$converterstatus.toSql(status),
      );
    }
    {
      map['created_at'] = Variable<int>(
        $ReelsTable.$convertercreatedAt.toSql(createdAt),
      );
    }
    {
      map['updated_at'] = Variable<int>(
        $ReelsTable.$converterupdatedAt.toSql(updatedAt),
      );
    }
    return map;
  }

  ReelsCompanion toCompanion(bool nullToAbsent) {
    return ReelsCompanion(
      id: Value(id),
      name: Value(name),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      status: Value(status),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory ReelRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ReelRow(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      description: serializer.fromJson<String?>(json['description']),
      status: $ReelsTable.$converterstatus.fromJson(
        serializer.fromJson<String>(json['status']),
      ),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'description': serializer.toJson<String?>(description),
      'status': serializer.toJson<String>(
        $ReelsTable.$converterstatus.toJson(status),
      ),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  ReelRow copyWith({
    int? id,
    String? name,
    Value<String?> description = const Value.absent(),
    ReelStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => ReelRow(
    id: id ?? this.id,
    name: name ?? this.name,
    description: description.present ? description.value : this.description,
    status: status ?? this.status,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  ReelRow copyWithCompanion(ReelsCompanion data) {
    return ReelRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      description: data.description.present
          ? data.description.value
          : this.description,
      status: data.status.present ? data.status.value : this.status,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ReelRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('description: $description, ')
          ..write('status: $status, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, name, description, status, createdAt, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ReelRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.description == this.description &&
          other.status == this.status &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class ReelsCompanion extends UpdateCompanion<ReelRow> {
  final Value<int> id;
  final Value<String> name;
  final Value<String?> description;
  final Value<ReelStatus> status;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  const ReelsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.description = const Value.absent(),
    this.status = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  ReelsCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    this.description = const Value.absent(),
    required ReelStatus status,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) : name = Value(name),
       status = Value(status),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<ReelRow> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? description,
    Expression<String>? status,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (description != null) 'description': description,
      if (status != null) 'status': status,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  ReelsCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<String?>? description,
    Value<ReelStatus>? status,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
  }) {
    return ReelsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(
        $ReelsTable.$converterstatus.toSql(status.value),
      );
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(
        $ReelsTable.$convertercreatedAt.toSql(createdAt.value),
      );
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(
        $ReelsTable.$converterupdatedAt.toSql(updatedAt.value),
      );
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ReelsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('description: $description, ')
          ..write('status: $status, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $ClipsTable extends Clips with TableInfo<$ClipsTable, ClipRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ClipsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  @override
  late final GeneratedColumnWithTypeConverter<ClipSource, String> source =
      GeneratedColumn<String>(
        'source',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<ClipSource>($ClipsTable.$convertersource);
  static const VerificationMeta _mediaStoreIdMeta = const VerificationMeta(
    'mediaStoreId',
  );
  @override
  late final GeneratedColumn<int> mediaStoreId = GeneratedColumn<int>(
    'media_store_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _volumeNameMeta = const VerificationMeta(
    'volumeName',
  );
  @override
  late final GeneratedColumn<String> volumeName = GeneratedColumn<String>(
    'volume_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _pickerUriMeta = const VerificationMeta(
    'pickerUri',
  );
  @override
  late final GeneratedColumn<String> pickerUri = GeneratedColumn<String>(
    'picker_uri',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sizeBytesMeta = const VerificationMeta(
    'sizeBytes',
  );
  @override
  late final GeneratedColumn<int> sizeBytes = GeneratedColumn<int>(
    'size_bytes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _durationMsMeta = const VerificationMeta(
    'durationMs',
  );
  @override
  late final GeneratedColumn<int> durationMs = GeneratedColumn<int>(
    'duration_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<DateTime, int> dateTakenUtc =
      GeneratedColumn<int>(
        'date_taken_utc',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<DateTime>($ClipsTable.$converterdateTakenUtc);
  static const VerificationMeta _displayNameMeta = const VerificationMeta(
    'displayName',
  );
  @override
  late final GeneratedColumn<String> displayName = GeneratedColumn<String>(
    'display_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _widthMeta = const VerificationMeta('width');
  @override
  late final GeneratedColumn<int> width = GeneratedColumn<int>(
    'width',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _heightMeta = const VerificationMeta('height');
  @override
  late final GeneratedColumn<int> height = GeneratedColumn<int>(
    'height',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _mimeTypeMeta = const VerificationMeta(
    'mimeType',
  );
  @override
  late final GeneratedColumn<String> mimeType = GeneratedColumn<String>(
    'mime_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _timeZoneIdMeta = const VerificationMeta(
    'timeZoneId',
  );
  @override
  late final GeneratedColumn<String> timeZoneId = GeneratedColumn<String>(
    'time_zone_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _generationAddedMeta = const VerificationMeta(
    'generationAdded',
  );
  @override
  late final GeneratedColumn<int> generationAdded = GeneratedColumn<int>(
    'generation_added',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<DateTime, int> firstSeenAt =
      GeneratedColumn<int>(
        'first_seen_at',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<DateTime>($ClipsTable.$converterfirstSeenAt);
  static const VerificationMeta _missingMeta = const VerificationMeta(
    'missing',
  );
  @override
  late final GeneratedColumn<bool> missing = GeneratedColumn<bool>(
    'missing',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("missing" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  late final GeneratedColumnWithTypeConverter<DateTime?, int> lastVerifiedAt =
      GeneratedColumn<int>(
        'last_verified_at',
        aliasedName,
        true,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
      ).withConverter<DateTime?>($ClipsTable.$converterlastVerifiedAtn);
  @override
  List<GeneratedColumn> get $columns => [
    id,
    source,
    mediaStoreId,
    volumeName,
    pickerUri,
    sizeBytes,
    durationMs,
    dateTakenUtc,
    displayName,
    width,
    height,
    mimeType,
    timeZoneId,
    generationAdded,
    firstSeenAt,
    missing,
    lastVerifiedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'clips';
  @override
  VerificationContext validateIntegrity(
    Insertable<ClipRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('media_store_id')) {
      context.handle(
        _mediaStoreIdMeta,
        mediaStoreId.isAcceptableOrUnknown(
          data['media_store_id']!,
          _mediaStoreIdMeta,
        ),
      );
    }
    if (data.containsKey('volume_name')) {
      context.handle(
        _volumeNameMeta,
        volumeName.isAcceptableOrUnknown(data['volume_name']!, _volumeNameMeta),
      );
    }
    if (data.containsKey('picker_uri')) {
      context.handle(
        _pickerUriMeta,
        pickerUri.isAcceptableOrUnknown(data['picker_uri']!, _pickerUriMeta),
      );
    }
    if (data.containsKey('size_bytes')) {
      context.handle(
        _sizeBytesMeta,
        sizeBytes.isAcceptableOrUnknown(data['size_bytes']!, _sizeBytesMeta),
      );
    } else if (isInserting) {
      context.missing(_sizeBytesMeta);
    }
    if (data.containsKey('duration_ms')) {
      context.handle(
        _durationMsMeta,
        durationMs.isAcceptableOrUnknown(data['duration_ms']!, _durationMsMeta),
      );
    } else if (isInserting) {
      context.missing(_durationMsMeta);
    }
    if (data.containsKey('display_name')) {
      context.handle(
        _displayNameMeta,
        displayName.isAcceptableOrUnknown(
          data['display_name']!,
          _displayNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_displayNameMeta);
    }
    if (data.containsKey('width')) {
      context.handle(
        _widthMeta,
        width.isAcceptableOrUnknown(data['width']!, _widthMeta),
      );
    } else if (isInserting) {
      context.missing(_widthMeta);
    }
    if (data.containsKey('height')) {
      context.handle(
        _heightMeta,
        height.isAcceptableOrUnknown(data['height']!, _heightMeta),
      );
    } else if (isInserting) {
      context.missing(_heightMeta);
    }
    if (data.containsKey('mime_type')) {
      context.handle(
        _mimeTypeMeta,
        mimeType.isAcceptableOrUnknown(data['mime_type']!, _mimeTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_mimeTypeMeta);
    }
    if (data.containsKey('time_zone_id')) {
      context.handle(
        _timeZoneIdMeta,
        timeZoneId.isAcceptableOrUnknown(
          data['time_zone_id']!,
          _timeZoneIdMeta,
        ),
      );
    }
    if (data.containsKey('generation_added')) {
      context.handle(
        _generationAddedMeta,
        generationAdded.isAcceptableOrUnknown(
          data['generation_added']!,
          _generationAddedMeta,
        ),
      );
    }
    if (data.containsKey('missing')) {
      context.handle(
        _missingMeta,
        missing.isAcceptableOrUnknown(data['missing']!, _missingMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {volumeName, mediaStoreId},
    {pickerUri},
  ];
  @override
  ClipRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ClipRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      source: $ClipsTable.$convertersource.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}source'],
        )!,
      ),
      mediaStoreId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}media_store_id'],
      ),
      volumeName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}volume_name'],
      ),
      pickerUri: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}picker_uri'],
      ),
      sizeBytes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}size_bytes'],
      )!,
      durationMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_ms'],
      )!,
      dateTakenUtc: $ClipsTable.$converterdateTakenUtc.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}date_taken_utc'],
        )!,
      ),
      displayName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}display_name'],
      )!,
      width: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}width'],
      )!,
      height: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}height'],
      )!,
      mimeType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mime_type'],
      )!,
      timeZoneId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}time_zone_id'],
      ),
      generationAdded: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}generation_added'],
      ),
      firstSeenAt: $ClipsTable.$converterfirstSeenAt.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}first_seen_at'],
        )!,
      ),
      missing: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}missing'],
      )!,
      lastVerifiedAt: $ClipsTable.$converterlastVerifiedAtn.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}last_verified_at'],
        ),
      ),
    );
  }

  @override
  $ClipsTable createAlias(String alias) {
    return $ClipsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<ClipSource, String, String> $convertersource =
      const EnumNameConverter<ClipSource>(ClipSource.values);
  static TypeConverter<DateTime, int> $converterdateTakenUtc =
      const UtcMillisConverter();
  static TypeConverter<DateTime, int> $converterfirstSeenAt =
      const UtcMillisConverter();
  static TypeConverter<DateTime, int> $converterlastVerifiedAt =
      const UtcMillisConverter();
  static TypeConverter<DateTime?, int?> $converterlastVerifiedAtn =
      NullAwareTypeConverter.wrap($converterlastVerifiedAt);
}

class ClipRow extends DataClass implements Insertable<ClipRow> {
  final int id;
  final ClipSource source;
  final int? mediaStoreId;
  final String? volumeName;
  final String? pickerUri;
  final int sizeBytes;
  final int durationMs;
  final DateTime dateTakenUtc;
  final String displayName;
  final int width;
  final int height;
  final String mimeType;

  /// IANA zone where the clip was shot, e.g. `Europe/London` (spec §8.3a).
  final String? timeZoneId;
  final int? generationAdded;
  final DateTime firstSeenAt;
  final bool missing;
  final DateTime? lastVerifiedAt;
  const ClipRow({
    required this.id,
    required this.source,
    this.mediaStoreId,
    this.volumeName,
    this.pickerUri,
    required this.sizeBytes,
    required this.durationMs,
    required this.dateTakenUtc,
    required this.displayName,
    required this.width,
    required this.height,
    required this.mimeType,
    this.timeZoneId,
    this.generationAdded,
    required this.firstSeenAt,
    required this.missing,
    this.lastVerifiedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    {
      map['source'] = Variable<String>(
        $ClipsTable.$convertersource.toSql(source),
      );
    }
    if (!nullToAbsent || mediaStoreId != null) {
      map['media_store_id'] = Variable<int>(mediaStoreId);
    }
    if (!nullToAbsent || volumeName != null) {
      map['volume_name'] = Variable<String>(volumeName);
    }
    if (!nullToAbsent || pickerUri != null) {
      map['picker_uri'] = Variable<String>(pickerUri);
    }
    map['size_bytes'] = Variable<int>(sizeBytes);
    map['duration_ms'] = Variable<int>(durationMs);
    {
      map['date_taken_utc'] = Variable<int>(
        $ClipsTable.$converterdateTakenUtc.toSql(dateTakenUtc),
      );
    }
    map['display_name'] = Variable<String>(displayName);
    map['width'] = Variable<int>(width);
    map['height'] = Variable<int>(height);
    map['mime_type'] = Variable<String>(mimeType);
    if (!nullToAbsent || timeZoneId != null) {
      map['time_zone_id'] = Variable<String>(timeZoneId);
    }
    if (!nullToAbsent || generationAdded != null) {
      map['generation_added'] = Variable<int>(generationAdded);
    }
    {
      map['first_seen_at'] = Variable<int>(
        $ClipsTable.$converterfirstSeenAt.toSql(firstSeenAt),
      );
    }
    map['missing'] = Variable<bool>(missing);
    if (!nullToAbsent || lastVerifiedAt != null) {
      map['last_verified_at'] = Variable<int>(
        $ClipsTable.$converterlastVerifiedAtn.toSql(lastVerifiedAt),
      );
    }
    return map;
  }

  ClipsCompanion toCompanion(bool nullToAbsent) {
    return ClipsCompanion(
      id: Value(id),
      source: Value(source),
      mediaStoreId: mediaStoreId == null && nullToAbsent
          ? const Value.absent()
          : Value(mediaStoreId),
      volumeName: volumeName == null && nullToAbsent
          ? const Value.absent()
          : Value(volumeName),
      pickerUri: pickerUri == null && nullToAbsent
          ? const Value.absent()
          : Value(pickerUri),
      sizeBytes: Value(sizeBytes),
      durationMs: Value(durationMs),
      dateTakenUtc: Value(dateTakenUtc),
      displayName: Value(displayName),
      width: Value(width),
      height: Value(height),
      mimeType: Value(mimeType),
      timeZoneId: timeZoneId == null && nullToAbsent
          ? const Value.absent()
          : Value(timeZoneId),
      generationAdded: generationAdded == null && nullToAbsent
          ? const Value.absent()
          : Value(generationAdded),
      firstSeenAt: Value(firstSeenAt),
      missing: Value(missing),
      lastVerifiedAt: lastVerifiedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastVerifiedAt),
    );
  }

  factory ClipRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ClipRow(
      id: serializer.fromJson<int>(json['id']),
      source: $ClipsTable.$convertersource.fromJson(
        serializer.fromJson<String>(json['source']),
      ),
      mediaStoreId: serializer.fromJson<int?>(json['mediaStoreId']),
      volumeName: serializer.fromJson<String?>(json['volumeName']),
      pickerUri: serializer.fromJson<String?>(json['pickerUri']),
      sizeBytes: serializer.fromJson<int>(json['sizeBytes']),
      durationMs: serializer.fromJson<int>(json['durationMs']),
      dateTakenUtc: serializer.fromJson<DateTime>(json['dateTakenUtc']),
      displayName: serializer.fromJson<String>(json['displayName']),
      width: serializer.fromJson<int>(json['width']),
      height: serializer.fromJson<int>(json['height']),
      mimeType: serializer.fromJson<String>(json['mimeType']),
      timeZoneId: serializer.fromJson<String?>(json['timeZoneId']),
      generationAdded: serializer.fromJson<int?>(json['generationAdded']),
      firstSeenAt: serializer.fromJson<DateTime>(json['firstSeenAt']),
      missing: serializer.fromJson<bool>(json['missing']),
      lastVerifiedAt: serializer.fromJson<DateTime?>(json['lastVerifiedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'source': serializer.toJson<String>(
        $ClipsTable.$convertersource.toJson(source),
      ),
      'mediaStoreId': serializer.toJson<int?>(mediaStoreId),
      'volumeName': serializer.toJson<String?>(volumeName),
      'pickerUri': serializer.toJson<String?>(pickerUri),
      'sizeBytes': serializer.toJson<int>(sizeBytes),
      'durationMs': serializer.toJson<int>(durationMs),
      'dateTakenUtc': serializer.toJson<DateTime>(dateTakenUtc),
      'displayName': serializer.toJson<String>(displayName),
      'width': serializer.toJson<int>(width),
      'height': serializer.toJson<int>(height),
      'mimeType': serializer.toJson<String>(mimeType),
      'timeZoneId': serializer.toJson<String?>(timeZoneId),
      'generationAdded': serializer.toJson<int?>(generationAdded),
      'firstSeenAt': serializer.toJson<DateTime>(firstSeenAt),
      'missing': serializer.toJson<bool>(missing),
      'lastVerifiedAt': serializer.toJson<DateTime?>(lastVerifiedAt),
    };
  }

  ClipRow copyWith({
    int? id,
    ClipSource? source,
    Value<int?> mediaStoreId = const Value.absent(),
    Value<String?> volumeName = const Value.absent(),
    Value<String?> pickerUri = const Value.absent(),
    int? sizeBytes,
    int? durationMs,
    DateTime? dateTakenUtc,
    String? displayName,
    int? width,
    int? height,
    String? mimeType,
    Value<String?> timeZoneId = const Value.absent(),
    Value<int?> generationAdded = const Value.absent(),
    DateTime? firstSeenAt,
    bool? missing,
    Value<DateTime?> lastVerifiedAt = const Value.absent(),
  }) => ClipRow(
    id: id ?? this.id,
    source: source ?? this.source,
    mediaStoreId: mediaStoreId.present ? mediaStoreId.value : this.mediaStoreId,
    volumeName: volumeName.present ? volumeName.value : this.volumeName,
    pickerUri: pickerUri.present ? pickerUri.value : this.pickerUri,
    sizeBytes: sizeBytes ?? this.sizeBytes,
    durationMs: durationMs ?? this.durationMs,
    dateTakenUtc: dateTakenUtc ?? this.dateTakenUtc,
    displayName: displayName ?? this.displayName,
    width: width ?? this.width,
    height: height ?? this.height,
    mimeType: mimeType ?? this.mimeType,
    timeZoneId: timeZoneId.present ? timeZoneId.value : this.timeZoneId,
    generationAdded: generationAdded.present
        ? generationAdded.value
        : this.generationAdded,
    firstSeenAt: firstSeenAt ?? this.firstSeenAt,
    missing: missing ?? this.missing,
    lastVerifiedAt: lastVerifiedAt.present
        ? lastVerifiedAt.value
        : this.lastVerifiedAt,
  );
  ClipRow copyWithCompanion(ClipsCompanion data) {
    return ClipRow(
      id: data.id.present ? data.id.value : this.id,
      source: data.source.present ? data.source.value : this.source,
      mediaStoreId: data.mediaStoreId.present
          ? data.mediaStoreId.value
          : this.mediaStoreId,
      volumeName: data.volumeName.present
          ? data.volumeName.value
          : this.volumeName,
      pickerUri: data.pickerUri.present ? data.pickerUri.value : this.pickerUri,
      sizeBytes: data.sizeBytes.present ? data.sizeBytes.value : this.sizeBytes,
      durationMs: data.durationMs.present
          ? data.durationMs.value
          : this.durationMs,
      dateTakenUtc: data.dateTakenUtc.present
          ? data.dateTakenUtc.value
          : this.dateTakenUtc,
      displayName: data.displayName.present
          ? data.displayName.value
          : this.displayName,
      width: data.width.present ? data.width.value : this.width,
      height: data.height.present ? data.height.value : this.height,
      mimeType: data.mimeType.present ? data.mimeType.value : this.mimeType,
      timeZoneId: data.timeZoneId.present
          ? data.timeZoneId.value
          : this.timeZoneId,
      generationAdded: data.generationAdded.present
          ? data.generationAdded.value
          : this.generationAdded,
      firstSeenAt: data.firstSeenAt.present
          ? data.firstSeenAt.value
          : this.firstSeenAt,
      missing: data.missing.present ? data.missing.value : this.missing,
      lastVerifiedAt: data.lastVerifiedAt.present
          ? data.lastVerifiedAt.value
          : this.lastVerifiedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ClipRow(')
          ..write('id: $id, ')
          ..write('source: $source, ')
          ..write('mediaStoreId: $mediaStoreId, ')
          ..write('volumeName: $volumeName, ')
          ..write('pickerUri: $pickerUri, ')
          ..write('sizeBytes: $sizeBytes, ')
          ..write('durationMs: $durationMs, ')
          ..write('dateTakenUtc: $dateTakenUtc, ')
          ..write('displayName: $displayName, ')
          ..write('width: $width, ')
          ..write('height: $height, ')
          ..write('mimeType: $mimeType, ')
          ..write('timeZoneId: $timeZoneId, ')
          ..write('generationAdded: $generationAdded, ')
          ..write('firstSeenAt: $firstSeenAt, ')
          ..write('missing: $missing, ')
          ..write('lastVerifiedAt: $lastVerifiedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    source,
    mediaStoreId,
    volumeName,
    pickerUri,
    sizeBytes,
    durationMs,
    dateTakenUtc,
    displayName,
    width,
    height,
    mimeType,
    timeZoneId,
    generationAdded,
    firstSeenAt,
    missing,
    lastVerifiedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ClipRow &&
          other.id == this.id &&
          other.source == this.source &&
          other.mediaStoreId == this.mediaStoreId &&
          other.volumeName == this.volumeName &&
          other.pickerUri == this.pickerUri &&
          other.sizeBytes == this.sizeBytes &&
          other.durationMs == this.durationMs &&
          other.dateTakenUtc == this.dateTakenUtc &&
          other.displayName == this.displayName &&
          other.width == this.width &&
          other.height == this.height &&
          other.mimeType == this.mimeType &&
          other.timeZoneId == this.timeZoneId &&
          other.generationAdded == this.generationAdded &&
          other.firstSeenAt == this.firstSeenAt &&
          other.missing == this.missing &&
          other.lastVerifiedAt == this.lastVerifiedAt);
}

class ClipsCompanion extends UpdateCompanion<ClipRow> {
  final Value<int> id;
  final Value<ClipSource> source;
  final Value<int?> mediaStoreId;
  final Value<String?> volumeName;
  final Value<String?> pickerUri;
  final Value<int> sizeBytes;
  final Value<int> durationMs;
  final Value<DateTime> dateTakenUtc;
  final Value<String> displayName;
  final Value<int> width;
  final Value<int> height;
  final Value<String> mimeType;
  final Value<String?> timeZoneId;
  final Value<int?> generationAdded;
  final Value<DateTime> firstSeenAt;
  final Value<bool> missing;
  final Value<DateTime?> lastVerifiedAt;
  const ClipsCompanion({
    this.id = const Value.absent(),
    this.source = const Value.absent(),
    this.mediaStoreId = const Value.absent(),
    this.volumeName = const Value.absent(),
    this.pickerUri = const Value.absent(),
    this.sizeBytes = const Value.absent(),
    this.durationMs = const Value.absent(),
    this.dateTakenUtc = const Value.absent(),
    this.displayName = const Value.absent(),
    this.width = const Value.absent(),
    this.height = const Value.absent(),
    this.mimeType = const Value.absent(),
    this.timeZoneId = const Value.absent(),
    this.generationAdded = const Value.absent(),
    this.firstSeenAt = const Value.absent(),
    this.missing = const Value.absent(),
    this.lastVerifiedAt = const Value.absent(),
  });
  ClipsCompanion.insert({
    this.id = const Value.absent(),
    required ClipSource source,
    this.mediaStoreId = const Value.absent(),
    this.volumeName = const Value.absent(),
    this.pickerUri = const Value.absent(),
    required int sizeBytes,
    required int durationMs,
    required DateTime dateTakenUtc,
    required String displayName,
    required int width,
    required int height,
    required String mimeType,
    this.timeZoneId = const Value.absent(),
    this.generationAdded = const Value.absent(),
    required DateTime firstSeenAt,
    this.missing = const Value.absent(),
    this.lastVerifiedAt = const Value.absent(),
  }) : source = Value(source),
       sizeBytes = Value(sizeBytes),
       durationMs = Value(durationMs),
       dateTakenUtc = Value(dateTakenUtc),
       displayName = Value(displayName),
       width = Value(width),
       height = Value(height),
       mimeType = Value(mimeType),
       firstSeenAt = Value(firstSeenAt);
  static Insertable<ClipRow> custom({
    Expression<int>? id,
    Expression<String>? source,
    Expression<int>? mediaStoreId,
    Expression<String>? volumeName,
    Expression<String>? pickerUri,
    Expression<int>? sizeBytes,
    Expression<int>? durationMs,
    Expression<int>? dateTakenUtc,
    Expression<String>? displayName,
    Expression<int>? width,
    Expression<int>? height,
    Expression<String>? mimeType,
    Expression<String>? timeZoneId,
    Expression<int>? generationAdded,
    Expression<int>? firstSeenAt,
    Expression<bool>? missing,
    Expression<int>? lastVerifiedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (source != null) 'source': source,
      if (mediaStoreId != null) 'media_store_id': mediaStoreId,
      if (volumeName != null) 'volume_name': volumeName,
      if (pickerUri != null) 'picker_uri': pickerUri,
      if (sizeBytes != null) 'size_bytes': sizeBytes,
      if (durationMs != null) 'duration_ms': durationMs,
      if (dateTakenUtc != null) 'date_taken_utc': dateTakenUtc,
      if (displayName != null) 'display_name': displayName,
      if (width != null) 'width': width,
      if (height != null) 'height': height,
      if (mimeType != null) 'mime_type': mimeType,
      if (timeZoneId != null) 'time_zone_id': timeZoneId,
      if (generationAdded != null) 'generation_added': generationAdded,
      if (firstSeenAt != null) 'first_seen_at': firstSeenAt,
      if (missing != null) 'missing': missing,
      if (lastVerifiedAt != null) 'last_verified_at': lastVerifiedAt,
    });
  }

  ClipsCompanion copyWith({
    Value<int>? id,
    Value<ClipSource>? source,
    Value<int?>? mediaStoreId,
    Value<String?>? volumeName,
    Value<String?>? pickerUri,
    Value<int>? sizeBytes,
    Value<int>? durationMs,
    Value<DateTime>? dateTakenUtc,
    Value<String>? displayName,
    Value<int>? width,
    Value<int>? height,
    Value<String>? mimeType,
    Value<String?>? timeZoneId,
    Value<int?>? generationAdded,
    Value<DateTime>? firstSeenAt,
    Value<bool>? missing,
    Value<DateTime?>? lastVerifiedAt,
  }) {
    return ClipsCompanion(
      id: id ?? this.id,
      source: source ?? this.source,
      mediaStoreId: mediaStoreId ?? this.mediaStoreId,
      volumeName: volumeName ?? this.volumeName,
      pickerUri: pickerUri ?? this.pickerUri,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      durationMs: durationMs ?? this.durationMs,
      dateTakenUtc: dateTakenUtc ?? this.dateTakenUtc,
      displayName: displayName ?? this.displayName,
      width: width ?? this.width,
      height: height ?? this.height,
      mimeType: mimeType ?? this.mimeType,
      timeZoneId: timeZoneId ?? this.timeZoneId,
      generationAdded: generationAdded ?? this.generationAdded,
      firstSeenAt: firstSeenAt ?? this.firstSeenAt,
      missing: missing ?? this.missing,
      lastVerifiedAt: lastVerifiedAt ?? this.lastVerifiedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(
        $ClipsTable.$convertersource.toSql(source.value),
      );
    }
    if (mediaStoreId.present) {
      map['media_store_id'] = Variable<int>(mediaStoreId.value);
    }
    if (volumeName.present) {
      map['volume_name'] = Variable<String>(volumeName.value);
    }
    if (pickerUri.present) {
      map['picker_uri'] = Variable<String>(pickerUri.value);
    }
    if (sizeBytes.present) {
      map['size_bytes'] = Variable<int>(sizeBytes.value);
    }
    if (durationMs.present) {
      map['duration_ms'] = Variable<int>(durationMs.value);
    }
    if (dateTakenUtc.present) {
      map['date_taken_utc'] = Variable<int>(
        $ClipsTable.$converterdateTakenUtc.toSql(dateTakenUtc.value),
      );
    }
    if (displayName.present) {
      map['display_name'] = Variable<String>(displayName.value);
    }
    if (width.present) {
      map['width'] = Variable<int>(width.value);
    }
    if (height.present) {
      map['height'] = Variable<int>(height.value);
    }
    if (mimeType.present) {
      map['mime_type'] = Variable<String>(mimeType.value);
    }
    if (timeZoneId.present) {
      map['time_zone_id'] = Variable<String>(timeZoneId.value);
    }
    if (generationAdded.present) {
      map['generation_added'] = Variable<int>(generationAdded.value);
    }
    if (firstSeenAt.present) {
      map['first_seen_at'] = Variable<int>(
        $ClipsTable.$converterfirstSeenAt.toSql(firstSeenAt.value),
      );
    }
    if (missing.present) {
      map['missing'] = Variable<bool>(missing.value);
    }
    if (lastVerifiedAt.present) {
      map['last_verified_at'] = Variable<int>(
        $ClipsTable.$converterlastVerifiedAtn.toSql(lastVerifiedAt.value),
      );
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ClipsCompanion(')
          ..write('id: $id, ')
          ..write('source: $source, ')
          ..write('mediaStoreId: $mediaStoreId, ')
          ..write('volumeName: $volumeName, ')
          ..write('pickerUri: $pickerUri, ')
          ..write('sizeBytes: $sizeBytes, ')
          ..write('durationMs: $durationMs, ')
          ..write('dateTakenUtc: $dateTakenUtc, ')
          ..write('displayName: $displayName, ')
          ..write('width: $width, ')
          ..write('height: $height, ')
          ..write('mimeType: $mimeType, ')
          ..write('timeZoneId: $timeZoneId, ')
          ..write('generationAdded: $generationAdded, ')
          ..write('firstSeenAt: $firstSeenAt, ')
          ..write('missing: $missing, ')
          ..write('lastVerifiedAt: $lastVerifiedAt')
          ..write(')'))
        .toString();
  }
}

class $ClipReelsTable extends ClipReels
    with TableInfo<$ClipReelsTable, ClipReelRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ClipReelsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _clipIdMeta = const VerificationMeta('clipId');
  @override
  late final GeneratedColumn<int> clipId = GeneratedColumn<int>(
    'clip_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES clips (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _reelIdMeta = const VerificationMeta('reelId');
  @override
  late final GeneratedColumn<int> reelId = GeneratedColumn<int>(
    'reel_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES reels (id) ON DELETE CASCADE',
    ),
  );
  @override
  late final GeneratedColumnWithTypeConverter<DateTime, int> addedAt =
      GeneratedColumn<int>(
        'added_at',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<DateTime>($ClipReelsTable.$converteraddedAt);
  @override
  List<GeneratedColumn> get $columns => [clipId, reelId, addedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'clip_reels';
  @override
  VerificationContext validateIntegrity(
    Insertable<ClipReelRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('clip_id')) {
      context.handle(
        _clipIdMeta,
        clipId.isAcceptableOrUnknown(data['clip_id']!, _clipIdMeta),
      );
    } else if (isInserting) {
      context.missing(_clipIdMeta);
    }
    if (data.containsKey('reel_id')) {
      context.handle(
        _reelIdMeta,
        reelId.isAcceptableOrUnknown(data['reel_id']!, _reelIdMeta),
      );
    } else if (isInserting) {
      context.missing(_reelIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {clipId, reelId};
  @override
  ClipReelRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ClipReelRow(
      clipId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}clip_id'],
      )!,
      reelId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}reel_id'],
      )!,
      addedAt: $ClipReelsTable.$converteraddedAt.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}added_at'],
        )!,
      ),
    );
  }

  @override
  $ClipReelsTable createAlias(String alias) {
    return $ClipReelsTable(attachedDatabase, alias);
  }

  static TypeConverter<DateTime, int> $converteraddedAt =
      const UtcMillisConverter();
}

class ClipReelRow extends DataClass implements Insertable<ClipReelRow> {
  final int clipId;
  final int reelId;
  final DateTime addedAt;
  const ClipReelRow({
    required this.clipId,
    required this.reelId,
    required this.addedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['clip_id'] = Variable<int>(clipId);
    map['reel_id'] = Variable<int>(reelId);
    {
      map['added_at'] = Variable<int>(
        $ClipReelsTable.$converteraddedAt.toSql(addedAt),
      );
    }
    return map;
  }

  ClipReelsCompanion toCompanion(bool nullToAbsent) {
    return ClipReelsCompanion(
      clipId: Value(clipId),
      reelId: Value(reelId),
      addedAt: Value(addedAt),
    );
  }

  factory ClipReelRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ClipReelRow(
      clipId: serializer.fromJson<int>(json['clipId']),
      reelId: serializer.fromJson<int>(json['reelId']),
      addedAt: serializer.fromJson<DateTime>(json['addedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'clipId': serializer.toJson<int>(clipId),
      'reelId': serializer.toJson<int>(reelId),
      'addedAt': serializer.toJson<DateTime>(addedAt),
    };
  }

  ClipReelRow copyWith({int? clipId, int? reelId, DateTime? addedAt}) =>
      ClipReelRow(
        clipId: clipId ?? this.clipId,
        reelId: reelId ?? this.reelId,
        addedAt: addedAt ?? this.addedAt,
      );
  ClipReelRow copyWithCompanion(ClipReelsCompanion data) {
    return ClipReelRow(
      clipId: data.clipId.present ? data.clipId.value : this.clipId,
      reelId: data.reelId.present ? data.reelId.value : this.reelId,
      addedAt: data.addedAt.present ? data.addedAt.value : this.addedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ClipReelRow(')
          ..write('clipId: $clipId, ')
          ..write('reelId: $reelId, ')
          ..write('addedAt: $addedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(clipId, reelId, addedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ClipReelRow &&
          other.clipId == this.clipId &&
          other.reelId == this.reelId &&
          other.addedAt == this.addedAt);
}

class ClipReelsCompanion extends UpdateCompanion<ClipReelRow> {
  final Value<int> clipId;
  final Value<int> reelId;
  final Value<DateTime> addedAt;
  final Value<int> rowid;
  const ClipReelsCompanion({
    this.clipId = const Value.absent(),
    this.reelId = const Value.absent(),
    this.addedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ClipReelsCompanion.insert({
    required int clipId,
    required int reelId,
    required DateTime addedAt,
    this.rowid = const Value.absent(),
  }) : clipId = Value(clipId),
       reelId = Value(reelId),
       addedAt = Value(addedAt);
  static Insertable<ClipReelRow> custom({
    Expression<int>? clipId,
    Expression<int>? reelId,
    Expression<int>? addedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (clipId != null) 'clip_id': clipId,
      if (reelId != null) 'reel_id': reelId,
      if (addedAt != null) 'added_at': addedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ClipReelsCompanion copyWith({
    Value<int>? clipId,
    Value<int>? reelId,
    Value<DateTime>? addedAt,
    Value<int>? rowid,
  }) {
    return ClipReelsCompanion(
      clipId: clipId ?? this.clipId,
      reelId: reelId ?? this.reelId,
      addedAt: addedAt ?? this.addedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (clipId.present) {
      map['clip_id'] = Variable<int>(clipId.value);
    }
    if (reelId.present) {
      map['reel_id'] = Variable<int>(reelId.value);
    }
    if (addedAt.present) {
      map['added_at'] = Variable<int>(
        $ClipReelsTable.$converteraddedAt.toSql(addedAt.value),
      );
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ClipReelsCompanion(')
          ..write('clipId: $clipId, ')
          ..write('reelId: $reelId, ')
          ..write('addedAt: $addedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $InboxTable extends Inbox with TableInfo<$InboxTable, InboxRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $InboxTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _clipIdMeta = const VerificationMeta('clipId');
  @override
  late final GeneratedColumn<int> clipId = GeneratedColumn<int>(
    'clip_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES clips (id) ON DELETE CASCADE',
    ),
  );
  @override
  late final GeneratedColumnWithTypeConverter<InboxState, String> state =
      GeneratedColumn<String>(
        'state',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<InboxState>($InboxTable.$converterstate);
  @override
  late final GeneratedColumnWithTypeConverter<DateTime, int> addedAt =
      GeneratedColumn<int>(
        'added_at',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<DateTime>($InboxTable.$converteraddedAt);
  @override
  List<GeneratedColumn> get $columns => [clipId, state, addedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'inbox';
  @override
  VerificationContext validateIntegrity(
    Insertable<InboxRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('clip_id')) {
      context.handle(
        _clipIdMeta,
        clipId.isAcceptableOrUnknown(data['clip_id']!, _clipIdMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {clipId};
  @override
  InboxRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return InboxRow(
      clipId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}clip_id'],
      )!,
      state: $InboxTable.$converterstate.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}state'],
        )!,
      ),
      addedAt: $InboxTable.$converteraddedAt.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}added_at'],
        )!,
      ),
    );
  }

  @override
  $InboxTable createAlias(String alias) {
    return $InboxTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<InboxState, String, String> $converterstate =
      const EnumNameConverter<InboxState>(InboxState.values);
  static TypeConverter<DateTime, int> $converteraddedAt =
      const UtcMillisConverter();
}

class InboxRow extends DataClass implements Insertable<InboxRow> {
  final int clipId;
  final InboxState state;
  final DateTime addedAt;
  const InboxRow({
    required this.clipId,
    required this.state,
    required this.addedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['clip_id'] = Variable<int>(clipId);
    {
      map['state'] = Variable<String>($InboxTable.$converterstate.toSql(state));
    }
    {
      map['added_at'] = Variable<int>(
        $InboxTable.$converteraddedAt.toSql(addedAt),
      );
    }
    return map;
  }

  InboxCompanion toCompanion(bool nullToAbsent) {
    return InboxCompanion(
      clipId: Value(clipId),
      state: Value(state),
      addedAt: Value(addedAt),
    );
  }

  factory InboxRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return InboxRow(
      clipId: serializer.fromJson<int>(json['clipId']),
      state: $InboxTable.$converterstate.fromJson(
        serializer.fromJson<String>(json['state']),
      ),
      addedAt: serializer.fromJson<DateTime>(json['addedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'clipId': serializer.toJson<int>(clipId),
      'state': serializer.toJson<String>(
        $InboxTable.$converterstate.toJson(state),
      ),
      'addedAt': serializer.toJson<DateTime>(addedAt),
    };
  }

  InboxRow copyWith({int? clipId, InboxState? state, DateTime? addedAt}) =>
      InboxRow(
        clipId: clipId ?? this.clipId,
        state: state ?? this.state,
        addedAt: addedAt ?? this.addedAt,
      );
  InboxRow copyWithCompanion(InboxCompanion data) {
    return InboxRow(
      clipId: data.clipId.present ? data.clipId.value : this.clipId,
      state: data.state.present ? data.state.value : this.state,
      addedAt: data.addedAt.present ? data.addedAt.value : this.addedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('InboxRow(')
          ..write('clipId: $clipId, ')
          ..write('state: $state, ')
          ..write('addedAt: $addedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(clipId, state, addedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is InboxRow &&
          other.clipId == this.clipId &&
          other.state == this.state &&
          other.addedAt == this.addedAt);
}

class InboxCompanion extends UpdateCompanion<InboxRow> {
  final Value<int> clipId;
  final Value<InboxState> state;
  final Value<DateTime> addedAt;
  const InboxCompanion({
    this.clipId = const Value.absent(),
    this.state = const Value.absent(),
    this.addedAt = const Value.absent(),
  });
  InboxCompanion.insert({
    this.clipId = const Value.absent(),
    required InboxState state,
    required DateTime addedAt,
  }) : state = Value(state),
       addedAt = Value(addedAt);
  static Insertable<InboxRow> custom({
    Expression<int>? clipId,
    Expression<String>? state,
    Expression<int>? addedAt,
  }) {
    return RawValuesInsertable({
      if (clipId != null) 'clip_id': clipId,
      if (state != null) 'state': state,
      if (addedAt != null) 'added_at': addedAt,
    });
  }

  InboxCompanion copyWith({
    Value<int>? clipId,
    Value<InboxState>? state,
    Value<DateTime>? addedAt,
  }) {
    return InboxCompanion(
      clipId: clipId ?? this.clipId,
      state: state ?? this.state,
      addedAt: addedAt ?? this.addedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (clipId.present) {
      map['clip_id'] = Variable<int>(clipId.value);
    }
    if (state.present) {
      map['state'] = Variable<String>(
        $InboxTable.$converterstate.toSql(state.value),
      );
    }
    if (addedAt.present) {
      map['added_at'] = Variable<int>(
        $InboxTable.$converteraddedAt.toSql(addedAt.value),
      );
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('InboxCompanion(')
          ..write('clipId: $clipId, ')
          ..write('state: $state, ')
          ..write('addedAt: $addedAt')
          ..write(')'))
        .toString();
  }
}

class $ReelReferencesTable extends ReelReferences
    with TableInfo<$ReelReferencesTable, ReelReferenceRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ReelReferencesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _reelIdMeta = const VerificationMeta('reelId');
  @override
  late final GeneratedColumn<int> reelId = GeneratedColumn<int>(
    'reel_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES reels (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _urlMeta = const VerificationMeta('url');
  @override
  late final GeneratedColumn<String> url = GeneratedColumn<String>(
    'url',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<ReferenceSource, String> source =
      GeneratedColumn<String>(
        'source',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<ReferenceSource>($ReelReferencesTable.$convertersource);
  static const VerificationMeta _labelMeta = const VerificationMeta('label');
  @override
  late final GeneratedColumn<String> label = GeneratedColumn<String>(
    'label',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<DateTime, int> createdAt =
      GeneratedColumn<int>(
        'created_at',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<DateTime>($ReelReferencesTable.$convertercreatedAt);
  @override
  List<GeneratedColumn> get $columns => [
    id,
    reelId,
    url,
    source,
    label,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'reel_references';
  @override
  VerificationContext validateIntegrity(
    Insertable<ReelReferenceRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('reel_id')) {
      context.handle(
        _reelIdMeta,
        reelId.isAcceptableOrUnknown(data['reel_id']!, _reelIdMeta),
      );
    } else if (isInserting) {
      context.missing(_reelIdMeta);
    }
    if (data.containsKey('url')) {
      context.handle(
        _urlMeta,
        url.isAcceptableOrUnknown(data['url']!, _urlMeta),
      );
    } else if (isInserting) {
      context.missing(_urlMeta);
    }
    if (data.containsKey('label')) {
      context.handle(
        _labelMeta,
        label.isAcceptableOrUnknown(data['label']!, _labelMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {reelId, url},
  ];
  @override
  ReelReferenceRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ReelReferenceRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      reelId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}reel_id'],
      )!,
      url: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}url'],
      )!,
      source: $ReelReferencesTable.$convertersource.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}source'],
        )!,
      ),
      label: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}label'],
      ),
      createdAt: $ReelReferencesTable.$convertercreatedAt.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}created_at'],
        )!,
      ),
    );
  }

  @override
  $ReelReferencesTable createAlias(String alias) {
    return $ReelReferencesTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<ReferenceSource, String, String> $convertersource =
      const EnumNameConverter<ReferenceSource>(ReferenceSource.values);
  static TypeConverter<DateTime, int> $convertercreatedAt =
      const UtcMillisConverter();
}

class ReelReferenceRow extends DataClass
    implements Insertable<ReelReferenceRow> {
  final int id;
  final int reelId;
  final String url;
  final ReferenceSource source;
  final String? label;
  final DateTime createdAt;
  const ReelReferenceRow({
    required this.id,
    required this.reelId,
    required this.url,
    required this.source,
    this.label,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['reel_id'] = Variable<int>(reelId);
    map['url'] = Variable<String>(url);
    {
      map['source'] = Variable<String>(
        $ReelReferencesTable.$convertersource.toSql(source),
      );
    }
    if (!nullToAbsent || label != null) {
      map['label'] = Variable<String>(label);
    }
    {
      map['created_at'] = Variable<int>(
        $ReelReferencesTable.$convertercreatedAt.toSql(createdAt),
      );
    }
    return map;
  }

  ReelReferencesCompanion toCompanion(bool nullToAbsent) {
    return ReelReferencesCompanion(
      id: Value(id),
      reelId: Value(reelId),
      url: Value(url),
      source: Value(source),
      label: label == null && nullToAbsent
          ? const Value.absent()
          : Value(label),
      createdAt: Value(createdAt),
    );
  }

  factory ReelReferenceRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ReelReferenceRow(
      id: serializer.fromJson<int>(json['id']),
      reelId: serializer.fromJson<int>(json['reelId']),
      url: serializer.fromJson<String>(json['url']),
      source: $ReelReferencesTable.$convertersource.fromJson(
        serializer.fromJson<String>(json['source']),
      ),
      label: serializer.fromJson<String?>(json['label']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'reelId': serializer.toJson<int>(reelId),
      'url': serializer.toJson<String>(url),
      'source': serializer.toJson<String>(
        $ReelReferencesTable.$convertersource.toJson(source),
      ),
      'label': serializer.toJson<String?>(label),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  ReelReferenceRow copyWith({
    int? id,
    int? reelId,
    String? url,
    ReferenceSource? source,
    Value<String?> label = const Value.absent(),
    DateTime? createdAt,
  }) => ReelReferenceRow(
    id: id ?? this.id,
    reelId: reelId ?? this.reelId,
    url: url ?? this.url,
    source: source ?? this.source,
    label: label.present ? label.value : this.label,
    createdAt: createdAt ?? this.createdAt,
  );
  ReelReferenceRow copyWithCompanion(ReelReferencesCompanion data) {
    return ReelReferenceRow(
      id: data.id.present ? data.id.value : this.id,
      reelId: data.reelId.present ? data.reelId.value : this.reelId,
      url: data.url.present ? data.url.value : this.url,
      source: data.source.present ? data.source.value : this.source,
      label: data.label.present ? data.label.value : this.label,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ReelReferenceRow(')
          ..write('id: $id, ')
          ..write('reelId: $reelId, ')
          ..write('url: $url, ')
          ..write('source: $source, ')
          ..write('label: $label, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, reelId, url, source, label, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ReelReferenceRow &&
          other.id == this.id &&
          other.reelId == this.reelId &&
          other.url == this.url &&
          other.source == this.source &&
          other.label == this.label &&
          other.createdAt == this.createdAt);
}

class ReelReferencesCompanion extends UpdateCompanion<ReelReferenceRow> {
  final Value<int> id;
  final Value<int> reelId;
  final Value<String> url;
  final Value<ReferenceSource> source;
  final Value<String?> label;
  final Value<DateTime> createdAt;
  const ReelReferencesCompanion({
    this.id = const Value.absent(),
    this.reelId = const Value.absent(),
    this.url = const Value.absent(),
    this.source = const Value.absent(),
    this.label = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  ReelReferencesCompanion.insert({
    this.id = const Value.absent(),
    required int reelId,
    required String url,
    required ReferenceSource source,
    this.label = const Value.absent(),
    required DateTime createdAt,
  }) : reelId = Value(reelId),
       url = Value(url),
       source = Value(source),
       createdAt = Value(createdAt);
  static Insertable<ReelReferenceRow> custom({
    Expression<int>? id,
    Expression<int>? reelId,
    Expression<String>? url,
    Expression<String>? source,
    Expression<String>? label,
    Expression<int>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (reelId != null) 'reel_id': reelId,
      if (url != null) 'url': url,
      if (source != null) 'source': source,
      if (label != null) 'label': label,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  ReelReferencesCompanion copyWith({
    Value<int>? id,
    Value<int>? reelId,
    Value<String>? url,
    Value<ReferenceSource>? source,
    Value<String?>? label,
    Value<DateTime>? createdAt,
  }) {
    return ReelReferencesCompanion(
      id: id ?? this.id,
      reelId: reelId ?? this.reelId,
      url: url ?? this.url,
      source: source ?? this.source,
      label: label ?? this.label,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (reelId.present) {
      map['reel_id'] = Variable<int>(reelId.value);
    }
    if (url.present) {
      map['url'] = Variable<String>(url.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(
        $ReelReferencesTable.$convertersource.toSql(source.value),
      );
    }
    if (label.present) {
      map['label'] = Variable<String>(label.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(
        $ReelReferencesTable.$convertercreatedAt.toSql(createdAt.value),
      );
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ReelReferencesCompanion(')
          ..write('id: $id, ')
          ..write('reelId: $reelId, ')
          ..write('url: $url, ')
          ..write('source: $source, ')
          ..write('label: $label, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $EditSessionsTable extends EditSessions
    with TableInfo<$EditSessionsTable, EditSessionRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $EditSessionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _reelIdMeta = const VerificationMeta('reelId');
  @override
  late final GeneratedColumn<int> reelId = GeneratedColumn<int>(
    'reel_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES reels (id) ON DELETE CASCADE',
    ),
  );
  @override
  late final GeneratedColumnWithTypeConverter<EditorApp, String> editor =
      GeneratedColumn<String>(
        'editor',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('vn'),
      ).withConverter<EditorApp>($EditSessionsTable.$convertereditor);
  static const VerificationMeta _folderNameMeta = const VerificationMeta(
    'folderName',
  );
  @override
  late final GeneratedColumn<String> folderName = GeneratedColumn<String>(
    'folder_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<DateTime, int> createdAt =
      GeneratedColumn<int>(
        'created_at',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<DateTime>($EditSessionsTable.$convertercreatedAt);
  @override
  List<GeneratedColumn> get $columns => [reelId, editor, folderName, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'vn_sessions';
  @override
  VerificationContext validateIntegrity(
    Insertable<EditSessionRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('reel_id')) {
      context.handle(
        _reelIdMeta,
        reelId.isAcceptableOrUnknown(data['reel_id']!, _reelIdMeta),
      );
    }
    if (data.containsKey('folder_name')) {
      context.handle(
        _folderNameMeta,
        folderName.isAcceptableOrUnknown(data['folder_name']!, _folderNameMeta),
      );
    } else if (isInserting) {
      context.missing(_folderNameMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {reelId};
  @override
  EditSessionRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return EditSessionRow(
      reelId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}reel_id'],
      )!,
      editor: $EditSessionsTable.$convertereditor.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}editor'],
        )!,
      ),
      folderName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}folder_name'],
      )!,
      createdAt: $EditSessionsTable.$convertercreatedAt.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}created_at'],
        )!,
      ),
    );
  }

  @override
  $EditSessionsTable createAlias(String alias) {
    return $EditSessionsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<EditorApp, String, String> $convertereditor =
      const EnumNameConverter<EditorApp>(EditorApp.values);
  static TypeConverter<DateTime, int> $convertercreatedAt =
      const UtcMillisConverter();
}

class EditSessionRow extends DataClass implements Insertable<EditSessionRow> {
  final int reelId;

  /// Added in v2; every v1 session was a VN one.
  final EditorApp editor;
  final String folderName;
  final DateTime createdAt;
  const EditSessionRow({
    required this.reelId,
    required this.editor,
    required this.folderName,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['reel_id'] = Variable<int>(reelId);
    {
      map['editor'] = Variable<String>(
        $EditSessionsTable.$convertereditor.toSql(editor),
      );
    }
    map['folder_name'] = Variable<String>(folderName);
    {
      map['created_at'] = Variable<int>(
        $EditSessionsTable.$convertercreatedAt.toSql(createdAt),
      );
    }
    return map;
  }

  EditSessionsCompanion toCompanion(bool nullToAbsent) {
    return EditSessionsCompanion(
      reelId: Value(reelId),
      editor: Value(editor),
      folderName: Value(folderName),
      createdAt: Value(createdAt),
    );
  }

  factory EditSessionRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return EditSessionRow(
      reelId: serializer.fromJson<int>(json['reelId']),
      editor: $EditSessionsTable.$convertereditor.fromJson(
        serializer.fromJson<String>(json['editor']),
      ),
      folderName: serializer.fromJson<String>(json['folderName']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'reelId': serializer.toJson<int>(reelId),
      'editor': serializer.toJson<String>(
        $EditSessionsTable.$convertereditor.toJson(editor),
      ),
      'folderName': serializer.toJson<String>(folderName),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  EditSessionRow copyWith({
    int? reelId,
    EditorApp? editor,
    String? folderName,
    DateTime? createdAt,
  }) => EditSessionRow(
    reelId: reelId ?? this.reelId,
    editor: editor ?? this.editor,
    folderName: folderName ?? this.folderName,
    createdAt: createdAt ?? this.createdAt,
  );
  EditSessionRow copyWithCompanion(EditSessionsCompanion data) {
    return EditSessionRow(
      reelId: data.reelId.present ? data.reelId.value : this.reelId,
      editor: data.editor.present ? data.editor.value : this.editor,
      folderName: data.folderName.present
          ? data.folderName.value
          : this.folderName,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('EditSessionRow(')
          ..write('reelId: $reelId, ')
          ..write('editor: $editor, ')
          ..write('folderName: $folderName, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(reelId, editor, folderName, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EditSessionRow &&
          other.reelId == this.reelId &&
          other.editor == this.editor &&
          other.folderName == this.folderName &&
          other.createdAt == this.createdAt);
}

class EditSessionsCompanion extends UpdateCompanion<EditSessionRow> {
  final Value<int> reelId;
  final Value<EditorApp> editor;
  final Value<String> folderName;
  final Value<DateTime> createdAt;
  const EditSessionsCompanion({
    this.reelId = const Value.absent(),
    this.editor = const Value.absent(),
    this.folderName = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  EditSessionsCompanion.insert({
    this.reelId = const Value.absent(),
    this.editor = const Value.absent(),
    required String folderName,
    required DateTime createdAt,
  }) : folderName = Value(folderName),
       createdAt = Value(createdAt);
  static Insertable<EditSessionRow> custom({
    Expression<int>? reelId,
    Expression<String>? editor,
    Expression<String>? folderName,
    Expression<int>? createdAt,
  }) {
    return RawValuesInsertable({
      if (reelId != null) 'reel_id': reelId,
      if (editor != null) 'editor': editor,
      if (folderName != null) 'folder_name': folderName,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  EditSessionsCompanion copyWith({
    Value<int>? reelId,
    Value<EditorApp>? editor,
    Value<String>? folderName,
    Value<DateTime>? createdAt,
  }) {
    return EditSessionsCompanion(
      reelId: reelId ?? this.reelId,
      editor: editor ?? this.editor,
      folderName: folderName ?? this.folderName,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (reelId.present) {
      map['reel_id'] = Variable<int>(reelId.value);
    }
    if (editor.present) {
      map['editor'] = Variable<String>(
        $EditSessionsTable.$convertereditor.toSql(editor.value),
      );
    }
    if (folderName.present) {
      map['folder_name'] = Variable<String>(folderName.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(
        $EditSessionsTable.$convertercreatedAt.toSql(createdAt.value),
      );
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('EditSessionsCompanion(')
          ..write('reelId: $reelId, ')
          ..write('editor: $editor, ')
          ..write('folderName: $folderName, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $EditCopiesTable extends EditCopies
    with TableInfo<$EditCopiesTable, EditCopyRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $EditCopiesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _reelIdMeta = const VerificationMeta('reelId');
  @override
  late final GeneratedColumn<int> reelId = GeneratedColumn<int>(
    'reel_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES vn_sessions (reel_id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _clipIdMeta = const VerificationMeta('clipId');
  @override
  late final GeneratedColumn<int> clipId = GeneratedColumn<int>(
    'clip_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _copyMediaStoreIdMeta = const VerificationMeta(
    'copyMediaStoreId',
  );
  @override
  late final GeneratedColumn<int> copyMediaStoreId = GeneratedColumn<int>(
    'copy_media_store_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fileNameMeta = const VerificationMeta(
    'fileName',
  );
  @override
  late final GeneratedColumn<String> fileName = GeneratedColumn<String>(
    'file_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sizeBytesMeta = const VerificationMeta(
    'sizeBytes',
  );
  @override
  late final GeneratedColumn<int> sizeBytes = GeneratedColumn<int>(
    'size_bytes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<DateTime, int> copiedAt =
      GeneratedColumn<int>(
        'copied_at',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
        defaultValue: const Constant(0),
      ).withConverter<DateTime>($EditCopiesTable.$convertercopiedAt);
  @override
  List<GeneratedColumn> get $columns => [
    reelId,
    clipId,
    copyMediaStoreId,
    fileName,
    sizeBytes,
    copiedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'vn_copies';
  @override
  VerificationContext validateIntegrity(
    Insertable<EditCopyRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('reel_id')) {
      context.handle(
        _reelIdMeta,
        reelId.isAcceptableOrUnknown(data['reel_id']!, _reelIdMeta),
      );
    } else if (isInserting) {
      context.missing(_reelIdMeta);
    }
    if (data.containsKey('clip_id')) {
      context.handle(
        _clipIdMeta,
        clipId.isAcceptableOrUnknown(data['clip_id']!, _clipIdMeta),
      );
    } else if (isInserting) {
      context.missing(_clipIdMeta);
    }
    if (data.containsKey('copy_media_store_id')) {
      context.handle(
        _copyMediaStoreIdMeta,
        copyMediaStoreId.isAcceptableOrUnknown(
          data['copy_media_store_id']!,
          _copyMediaStoreIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_copyMediaStoreIdMeta);
    }
    if (data.containsKey('file_name')) {
      context.handle(
        _fileNameMeta,
        fileName.isAcceptableOrUnknown(data['file_name']!, _fileNameMeta),
      );
    } else if (isInserting) {
      context.missing(_fileNameMeta);
    }
    if (data.containsKey('size_bytes')) {
      context.handle(
        _sizeBytesMeta,
        sizeBytes.isAcceptableOrUnknown(data['size_bytes']!, _sizeBytesMeta),
      );
    } else if (isInserting) {
      context.missing(_sizeBytesMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {reelId, clipId};
  @override
  EditCopyRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return EditCopyRow(
      reelId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}reel_id'],
      )!,
      clipId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}clip_id'],
      )!,
      copyMediaStoreId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}copy_media_store_id'],
      )!,
      fileName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}file_name'],
      )!,
      sizeBytes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}size_bytes'],
      )!,
      copiedAt: $EditCopiesTable.$convertercopiedAt.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}copied_at'],
        )!,
      ),
    );
  }

  @override
  $EditCopiesTable createAlias(String alias) {
    return $EditCopiesTable(attachedDatabase, alias);
  }

  static TypeConverter<DateTime, int> $convertercopiedAt =
      const UtcMillisConverter();
}

class EditCopyRow extends DataClass implements Insertable<EditCopyRow> {
  final int reelId;
  final int clipId;
  final int copyMediaStoreId;
  final String fileName;
  final int sizeBytes;

  /// Added in v2. The migration set it to the session's `created_at`; the
  /// default (0) is only for an insert that leaves it out.
  final DateTime copiedAt;
  const EditCopyRow({
    required this.reelId,
    required this.clipId,
    required this.copyMediaStoreId,
    required this.fileName,
    required this.sizeBytes,
    required this.copiedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['reel_id'] = Variable<int>(reelId);
    map['clip_id'] = Variable<int>(clipId);
    map['copy_media_store_id'] = Variable<int>(copyMediaStoreId);
    map['file_name'] = Variable<String>(fileName);
    map['size_bytes'] = Variable<int>(sizeBytes);
    {
      map['copied_at'] = Variable<int>(
        $EditCopiesTable.$convertercopiedAt.toSql(copiedAt),
      );
    }
    return map;
  }

  EditCopiesCompanion toCompanion(bool nullToAbsent) {
    return EditCopiesCompanion(
      reelId: Value(reelId),
      clipId: Value(clipId),
      copyMediaStoreId: Value(copyMediaStoreId),
      fileName: Value(fileName),
      sizeBytes: Value(sizeBytes),
      copiedAt: Value(copiedAt),
    );
  }

  factory EditCopyRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return EditCopyRow(
      reelId: serializer.fromJson<int>(json['reelId']),
      clipId: serializer.fromJson<int>(json['clipId']),
      copyMediaStoreId: serializer.fromJson<int>(json['copyMediaStoreId']),
      fileName: serializer.fromJson<String>(json['fileName']),
      sizeBytes: serializer.fromJson<int>(json['sizeBytes']),
      copiedAt: serializer.fromJson<DateTime>(json['copiedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'reelId': serializer.toJson<int>(reelId),
      'clipId': serializer.toJson<int>(clipId),
      'copyMediaStoreId': serializer.toJson<int>(copyMediaStoreId),
      'fileName': serializer.toJson<String>(fileName),
      'sizeBytes': serializer.toJson<int>(sizeBytes),
      'copiedAt': serializer.toJson<DateTime>(copiedAt),
    };
  }

  EditCopyRow copyWith({
    int? reelId,
    int? clipId,
    int? copyMediaStoreId,
    String? fileName,
    int? sizeBytes,
    DateTime? copiedAt,
  }) => EditCopyRow(
    reelId: reelId ?? this.reelId,
    clipId: clipId ?? this.clipId,
    copyMediaStoreId: copyMediaStoreId ?? this.copyMediaStoreId,
    fileName: fileName ?? this.fileName,
    sizeBytes: sizeBytes ?? this.sizeBytes,
    copiedAt: copiedAt ?? this.copiedAt,
  );
  EditCopyRow copyWithCompanion(EditCopiesCompanion data) {
    return EditCopyRow(
      reelId: data.reelId.present ? data.reelId.value : this.reelId,
      clipId: data.clipId.present ? data.clipId.value : this.clipId,
      copyMediaStoreId: data.copyMediaStoreId.present
          ? data.copyMediaStoreId.value
          : this.copyMediaStoreId,
      fileName: data.fileName.present ? data.fileName.value : this.fileName,
      sizeBytes: data.sizeBytes.present ? data.sizeBytes.value : this.sizeBytes,
      copiedAt: data.copiedAt.present ? data.copiedAt.value : this.copiedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('EditCopyRow(')
          ..write('reelId: $reelId, ')
          ..write('clipId: $clipId, ')
          ..write('copyMediaStoreId: $copyMediaStoreId, ')
          ..write('fileName: $fileName, ')
          ..write('sizeBytes: $sizeBytes, ')
          ..write('copiedAt: $copiedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    reelId,
    clipId,
    copyMediaStoreId,
    fileName,
    sizeBytes,
    copiedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EditCopyRow &&
          other.reelId == this.reelId &&
          other.clipId == this.clipId &&
          other.copyMediaStoreId == this.copyMediaStoreId &&
          other.fileName == this.fileName &&
          other.sizeBytes == this.sizeBytes &&
          other.copiedAt == this.copiedAt);
}

class EditCopiesCompanion extends UpdateCompanion<EditCopyRow> {
  final Value<int> reelId;
  final Value<int> clipId;
  final Value<int> copyMediaStoreId;
  final Value<String> fileName;
  final Value<int> sizeBytes;
  final Value<DateTime> copiedAt;
  final Value<int> rowid;
  const EditCopiesCompanion({
    this.reelId = const Value.absent(),
    this.clipId = const Value.absent(),
    this.copyMediaStoreId = const Value.absent(),
    this.fileName = const Value.absent(),
    this.sizeBytes = const Value.absent(),
    this.copiedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  EditCopiesCompanion.insert({
    required int reelId,
    required int clipId,
    required int copyMediaStoreId,
    required String fileName,
    required int sizeBytes,
    this.copiedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : reelId = Value(reelId),
       clipId = Value(clipId),
       copyMediaStoreId = Value(copyMediaStoreId),
       fileName = Value(fileName),
       sizeBytes = Value(sizeBytes);
  static Insertable<EditCopyRow> custom({
    Expression<int>? reelId,
    Expression<int>? clipId,
    Expression<int>? copyMediaStoreId,
    Expression<String>? fileName,
    Expression<int>? sizeBytes,
    Expression<int>? copiedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (reelId != null) 'reel_id': reelId,
      if (clipId != null) 'clip_id': clipId,
      if (copyMediaStoreId != null) 'copy_media_store_id': copyMediaStoreId,
      if (fileName != null) 'file_name': fileName,
      if (sizeBytes != null) 'size_bytes': sizeBytes,
      if (copiedAt != null) 'copied_at': copiedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  EditCopiesCompanion copyWith({
    Value<int>? reelId,
    Value<int>? clipId,
    Value<int>? copyMediaStoreId,
    Value<String>? fileName,
    Value<int>? sizeBytes,
    Value<DateTime>? copiedAt,
    Value<int>? rowid,
  }) {
    return EditCopiesCompanion(
      reelId: reelId ?? this.reelId,
      clipId: clipId ?? this.clipId,
      copyMediaStoreId: copyMediaStoreId ?? this.copyMediaStoreId,
      fileName: fileName ?? this.fileName,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      copiedAt: copiedAt ?? this.copiedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (reelId.present) {
      map['reel_id'] = Variable<int>(reelId.value);
    }
    if (clipId.present) {
      map['clip_id'] = Variable<int>(clipId.value);
    }
    if (copyMediaStoreId.present) {
      map['copy_media_store_id'] = Variable<int>(copyMediaStoreId.value);
    }
    if (fileName.present) {
      map['file_name'] = Variable<String>(fileName.value);
    }
    if (sizeBytes.present) {
      map['size_bytes'] = Variable<int>(sizeBytes.value);
    }
    if (copiedAt.present) {
      map['copied_at'] = Variable<int>(
        $EditCopiesTable.$convertercopiedAt.toSql(copiedAt.value),
      );
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('EditCopiesCompanion(')
          ..write('reelId: $reelId, ')
          ..write('clipId: $clipId, ')
          ..write('copyMediaStoreId: $copyMediaStoreId, ')
          ..write('fileName: $fileName, ')
          ..write('sizeBytes: $sizeBytes, ')
          ..write('copiedAt: $copiedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SentClipsTable extends SentClips
    with TableInfo<$SentClipsTable, SentClipRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SentClipsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _reelIdMeta = const VerificationMeta('reelId');
  @override
  late final GeneratedColumn<int> reelId = GeneratedColumn<int>(
    'reel_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES vn_sessions (reel_id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _clipIdMeta = const VerificationMeta('clipId');
  @override
  late final GeneratedColumn<int> clipId = GeneratedColumn<int>(
    'clip_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<DateTime, int> sentAt =
      GeneratedColumn<int>(
        'sent_at',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<DateTime>($SentClipsTable.$convertersentAt);
  @override
  List<GeneratedColumn> get $columns => [reelId, clipId, sentAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sent_clips';
  @override
  VerificationContext validateIntegrity(
    Insertable<SentClipRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('reel_id')) {
      context.handle(
        _reelIdMeta,
        reelId.isAcceptableOrUnknown(data['reel_id']!, _reelIdMeta),
      );
    } else if (isInserting) {
      context.missing(_reelIdMeta);
    }
    if (data.containsKey('clip_id')) {
      context.handle(
        _clipIdMeta,
        clipId.isAcceptableOrUnknown(data['clip_id']!, _clipIdMeta),
      );
    } else if (isInserting) {
      context.missing(_clipIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {reelId, clipId};
  @override
  SentClipRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SentClipRow(
      reelId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}reel_id'],
      )!,
      clipId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}clip_id'],
      )!,
      sentAt: $SentClipsTable.$convertersentAt.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}sent_at'],
        )!,
      ),
    );
  }

  @override
  $SentClipsTable createAlias(String alias) {
    return $SentClipsTable(attachedDatabase, alias);
  }

  static TypeConverter<DateTime, int> $convertersentAt =
      const UtcMillisConverter();
}

class SentClipRow extends DataClass implements Insertable<SentClipRow> {
  final int reelId;
  final int clipId;
  final DateTime sentAt;
  const SentClipRow({
    required this.reelId,
    required this.clipId,
    required this.sentAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['reel_id'] = Variable<int>(reelId);
    map['clip_id'] = Variable<int>(clipId);
    {
      map['sent_at'] = Variable<int>(
        $SentClipsTable.$convertersentAt.toSql(sentAt),
      );
    }
    return map;
  }

  SentClipsCompanion toCompanion(bool nullToAbsent) {
    return SentClipsCompanion(
      reelId: Value(reelId),
      clipId: Value(clipId),
      sentAt: Value(sentAt),
    );
  }

  factory SentClipRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SentClipRow(
      reelId: serializer.fromJson<int>(json['reelId']),
      clipId: serializer.fromJson<int>(json['clipId']),
      sentAt: serializer.fromJson<DateTime>(json['sentAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'reelId': serializer.toJson<int>(reelId),
      'clipId': serializer.toJson<int>(clipId),
      'sentAt': serializer.toJson<DateTime>(sentAt),
    };
  }

  SentClipRow copyWith({int? reelId, int? clipId, DateTime? sentAt}) =>
      SentClipRow(
        reelId: reelId ?? this.reelId,
        clipId: clipId ?? this.clipId,
        sentAt: sentAt ?? this.sentAt,
      );
  SentClipRow copyWithCompanion(SentClipsCompanion data) {
    return SentClipRow(
      reelId: data.reelId.present ? data.reelId.value : this.reelId,
      clipId: data.clipId.present ? data.clipId.value : this.clipId,
      sentAt: data.sentAt.present ? data.sentAt.value : this.sentAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SentClipRow(')
          ..write('reelId: $reelId, ')
          ..write('clipId: $clipId, ')
          ..write('sentAt: $sentAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(reelId, clipId, sentAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SentClipRow &&
          other.reelId == this.reelId &&
          other.clipId == this.clipId &&
          other.sentAt == this.sentAt);
}

class SentClipsCompanion extends UpdateCompanion<SentClipRow> {
  final Value<int> reelId;
  final Value<int> clipId;
  final Value<DateTime> sentAt;
  final Value<int> rowid;
  const SentClipsCompanion({
    this.reelId = const Value.absent(),
    this.clipId = const Value.absent(),
    this.sentAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SentClipsCompanion.insert({
    required int reelId,
    required int clipId,
    required DateTime sentAt,
    this.rowid = const Value.absent(),
  }) : reelId = Value(reelId),
       clipId = Value(clipId),
       sentAt = Value(sentAt);
  static Insertable<SentClipRow> custom({
    Expression<int>? reelId,
    Expression<int>? clipId,
    Expression<int>? sentAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (reelId != null) 'reel_id': reelId,
      if (clipId != null) 'clip_id': clipId,
      if (sentAt != null) 'sent_at': sentAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SentClipsCompanion copyWith({
    Value<int>? reelId,
    Value<int>? clipId,
    Value<DateTime>? sentAt,
    Value<int>? rowid,
  }) {
    return SentClipsCompanion(
      reelId: reelId ?? this.reelId,
      clipId: clipId ?? this.clipId,
      sentAt: sentAt ?? this.sentAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (reelId.present) {
      map['reel_id'] = Variable<int>(reelId.value);
    }
    if (clipId.present) {
      map['clip_id'] = Variable<int>(clipId.value);
    }
    if (sentAt.present) {
      map['sent_at'] = Variable<int>(
        $SentClipsTable.$convertersentAt.toSql(sentAt.value),
      );
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SentClipsCompanion(')
          ..write('reelId: $reelId, ')
          ..write('clipId: $clipId, ')
          ..write('sentAt: $sentAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SettingsTable extends Settings
    with TableInfo<$SettingsTable, SettingRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<SettingRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  SettingRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SettingRow(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  $SettingsTable createAlias(String alias) {
    return $SettingsTable(attachedDatabase, alias);
  }
}

class SettingRow extends DataClass implements Insertable<SettingRow> {
  final String key;
  final String value;
  const SettingRow({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  SettingsCompanion toCompanion(bool nullToAbsent) {
    return SettingsCompanion(key: Value(key), value: Value(value));
  }

  factory SettingRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SettingRow(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  SettingRow copyWith({String? key, String? value}) =>
      SettingRow(key: key ?? this.key, value: value ?? this.value);
  SettingRow copyWithCompanion(SettingsCompanion data) {
    return SettingRow(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SettingRow(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SettingRow &&
          other.key == this.key &&
          other.value == this.value);
}

class SettingsCompanion extends UpdateCompanion<SettingRow> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const SettingsCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SettingsCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<SettingRow> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SettingsCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return SettingsCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SettingsCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ZoneTimelineTable extends ZoneTimeline
    with TableInfo<$ZoneTimelineTable, ZoneTimelineRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ZoneTimelineTable(this.attachedDatabase, [this._alias]);
  @override
  late final GeneratedColumnWithTypeConverter<DateTime, int> at =
      GeneratedColumn<int>(
        'at',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
      ).withConverter<DateTime>($ZoneTimelineTable.$converterat);
  static const VerificationMeta _zoneIdMeta = const VerificationMeta('zoneId');
  @override
  late final GeneratedColumn<String> zoneId = GeneratedColumn<String>(
    'zone_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [at, zoneId];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'zone_timeline';
  @override
  VerificationContext validateIntegrity(
    Insertable<ZoneTimelineRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('zone_id')) {
      context.handle(
        _zoneIdMeta,
        zoneId.isAcceptableOrUnknown(data['zone_id']!, _zoneIdMeta),
      );
    } else if (isInserting) {
      context.missing(_zoneIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {at};
  @override
  ZoneTimelineRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ZoneTimelineRow(
      at: $ZoneTimelineTable.$converterat.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}at'],
        )!,
      ),
      zoneId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}zone_id'],
      )!,
    );
  }

  @override
  $ZoneTimelineTable createAlias(String alias) {
    return $ZoneTimelineTable(attachedDatabase, alias);
  }

  static TypeConverter<DateTime, int> $converterat = const UtcMillisConverter();
}

class ZoneTimelineRow extends DataClass implements Insertable<ZoneTimelineRow> {
  final DateTime at;
  final String zoneId;
  const ZoneTimelineRow({required this.at, required this.zoneId});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    {
      map['at'] = Variable<int>($ZoneTimelineTable.$converterat.toSql(at));
    }
    map['zone_id'] = Variable<String>(zoneId);
    return map;
  }

  ZoneTimelineCompanion toCompanion(bool nullToAbsent) {
    return ZoneTimelineCompanion(at: Value(at), zoneId: Value(zoneId));
  }

  factory ZoneTimelineRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ZoneTimelineRow(
      at: serializer.fromJson<DateTime>(json['at']),
      zoneId: serializer.fromJson<String>(json['zoneId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'at': serializer.toJson<DateTime>(at),
      'zoneId': serializer.toJson<String>(zoneId),
    };
  }

  ZoneTimelineRow copyWith({DateTime? at, String? zoneId}) =>
      ZoneTimelineRow(at: at ?? this.at, zoneId: zoneId ?? this.zoneId);
  ZoneTimelineRow copyWithCompanion(ZoneTimelineCompanion data) {
    return ZoneTimelineRow(
      at: data.at.present ? data.at.value : this.at,
      zoneId: data.zoneId.present ? data.zoneId.value : this.zoneId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ZoneTimelineRow(')
          ..write('at: $at, ')
          ..write('zoneId: $zoneId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(at, zoneId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ZoneTimelineRow &&
          other.at == this.at &&
          other.zoneId == this.zoneId);
}

class ZoneTimelineCompanion extends UpdateCompanion<ZoneTimelineRow> {
  final Value<DateTime> at;
  final Value<String> zoneId;
  const ZoneTimelineCompanion({
    this.at = const Value.absent(),
    this.zoneId = const Value.absent(),
  });
  ZoneTimelineCompanion.insert({
    this.at = const Value.absent(),
    required String zoneId,
  }) : zoneId = Value(zoneId);
  static Insertable<ZoneTimelineRow> custom({
    Expression<int>? at,
    Expression<String>? zoneId,
  }) {
    return RawValuesInsertable({
      if (at != null) 'at': at,
      if (zoneId != null) 'zone_id': zoneId,
    });
  }

  ZoneTimelineCompanion copyWith({Value<DateTime>? at, Value<String>? zoneId}) {
    return ZoneTimelineCompanion(
      at: at ?? this.at,
      zoneId: zoneId ?? this.zoneId,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (at.present) {
      map['at'] = Variable<int>(
        $ZoneTimelineTable.$converterat.toSql(at.value),
      );
    }
    if (zoneId.present) {
      map['zone_id'] = Variable<String>(zoneId.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ZoneTimelineCompanion(')
          ..write('at: $at, ')
          ..write('zoneId: $zoneId')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $ReelsTable reels = $ReelsTable(this);
  late final $ClipsTable clips = $ClipsTable(this);
  late final $ClipReelsTable clipReels = $ClipReelsTable(this);
  late final $InboxTable inbox = $InboxTable(this);
  late final $ReelReferencesTable reelReferences = $ReelReferencesTable(this);
  late final $EditSessionsTable editSessions = $EditSessionsTable(this);
  late final $EditCopiesTable editCopies = $EditCopiesTable(this);
  late final $SentClipsTable sentClips = $SentClipsTable(this);
  late final $SettingsTable settings = $SettingsTable(this);
  late final $ZoneTimelineTable zoneTimeline = $ZoneTimelineTable(this);
  late final Index clipsDateTakenUtc = Index(
    'clips_date_taken_utc',
    'CREATE INDEX clips_date_taken_utc ON clips (date_taken_utc)',
  );
  late final Index clipReelsReelId = Index(
    'clip_reels_reel_id',
    'CREATE INDEX clip_reels_reel_id ON clip_reels (reel_id)',
  );
  late final Index vnCopiesClipId = Index(
    'vn_copies_clip_id',
    'CREATE INDEX vn_copies_clip_id ON vn_copies (clip_id)',
  );
  late final Index sentClipsClipId = Index(
    'sent_clips_clip_id',
    'CREATE INDEX sent_clips_clip_id ON sent_clips (clip_id)',
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    reels,
    clips,
    clipReels,
    inbox,
    reelReferences,
    editSessions,
    editCopies,
    sentClips,
    settings,
    zoneTimeline,
    clipsDateTakenUtc,
    clipReelsReelId,
    vnCopiesClipId,
    sentClipsClipId,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'clips',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('clip_reels', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'reels',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('clip_reels', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'clips',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('inbox', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'reels',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('reel_references', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'reels',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('vn_sessions', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'vn_sessions',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('vn_copies', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'vn_sessions',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('sent_clips', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $$ReelsTableCreateCompanionBuilder = ReelsCompanion Function({
  Value<int> id,
  required String name,
  Value<String?> description,
  required ReelStatus status,
  required DateTime createdAt,
  required DateTime updatedAt,
});
typedef $$ReelsTableUpdateCompanionBuilder = ReelsCompanion Function({
  Value<int> id,
  Value<String> name,
  Value<String?> description,
  Value<ReelStatus> status,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
});

final class $$ReelsTableReferences
    extends BaseReferences<_$AppDatabase, $ReelsTable, ReelRow> {
  $$ReelsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$ClipReelsTable, List<ClipReelRow>>
  _clipReelsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.clipReels,
    aliasName: 'reels__id__clip_reels__reel_id',
  );

  $$ClipReelsTableProcessedTableManager get clipReelsRefs {
    final manager = $$ClipReelsTableTableManager(
      $_db,
      $_db.clipReels,
    ).filter((f) => f.reelId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_clipReelsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$ReelReferencesTable, List<ReelReferenceRow>>
  _reelReferencesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.reelReferences,
    aliasName: 'reels__id__reel_references__reel_id',
  );

  $$ReelReferencesTableProcessedTableManager get reelReferencesRefs {
    final manager = $$ReelReferencesTableTableManager(
      $_db,
      $_db.reelReferences,
    ).filter((f) => f.reelId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_reelReferencesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$EditSessionsTable, List<EditSessionRow>>
  _editSessionsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.editSessions,
    aliasName: 'reels__id__vn_sessions__reel_id',
  );

  $$EditSessionsTableProcessedTableManager get editSessionsRefs {
    final manager = $$EditSessionsTableTableManager(
      $_db,
      $_db.editSessions,
    ).filter((f) => f.reelId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_editSessionsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$ReelsTableFilterComposer extends Composer<_$AppDatabase, $ReelsTable> {
  $$ReelsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<ReelStatus, ReelStatus, String> get status =>
      $composableBuilder(
        column: $table.status,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnWithTypeConverterFilters<DateTime, DateTime, int> get createdAt =>
      $composableBuilder(
        column: $table.createdAt,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnWithTypeConverterFilters<DateTime, DateTime, int> get updatedAt =>
      $composableBuilder(
        column: $table.updatedAt,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  Expression<bool> clipReelsRefs(
    Expression<bool> Function($$ClipReelsTableFilterComposer f) f,
  ) {
    final $$ClipReelsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.clipReels,
      getReferencedColumn: (t) => t.reelId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ClipReelsTableFilterComposer(
            $db: $db,
            $table: $db.clipReels,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> reelReferencesRefs(
    Expression<bool> Function($$ReelReferencesTableFilterComposer f) f,
  ) {
    final $$ReelReferencesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.reelReferences,
      getReferencedColumn: (t) => t.reelId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ReelReferencesTableFilterComposer(
            $db: $db,
            $table: $db.reelReferences,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> editSessionsRefs(
    Expression<bool> Function($$EditSessionsTableFilterComposer f) f,
  ) {
    final $$EditSessionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.editSessions,
      getReferencedColumn: (t) => t.reelId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EditSessionsTableFilterComposer(
            $db: $db,
            $table: $db.editSessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ReelsTableOrderingComposer
    extends Composer<_$AppDatabase, $ReelsTable> {
  $$ReelsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ReelsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ReelsTable> {
  $$ReelsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<ReelStatus, String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DateTime, int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DateTime, int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  Expression<T> clipReelsRefs<T extends Object>(
    Expression<T> Function($$ClipReelsTableAnnotationComposer a) f,
  ) {
    final $$ClipReelsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.clipReels,
      getReferencedColumn: (t) => t.reelId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ClipReelsTableAnnotationComposer(
            $db: $db,
            $table: $db.clipReels,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> reelReferencesRefs<T extends Object>(
    Expression<T> Function($$ReelReferencesTableAnnotationComposer a) f,
  ) {
    final $$ReelReferencesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.reelReferences,
      getReferencedColumn: (t) => t.reelId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ReelReferencesTableAnnotationComposer(
            $db: $db,
            $table: $db.reelReferences,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> editSessionsRefs<T extends Object>(
    Expression<T> Function($$EditSessionsTableAnnotationComposer a) f,
  ) {
    final $$EditSessionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.editSessions,
      getReferencedColumn: (t) => t.reelId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EditSessionsTableAnnotationComposer(
            $db: $db,
            $table: $db.editSessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ReelsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ReelsTable,
          ReelRow,
          $$ReelsTableFilterComposer,
          $$ReelsTableOrderingComposer,
          $$ReelsTableAnnotationComposer,
          $$ReelsTableCreateCompanionBuilder,
          $$ReelsTableUpdateCompanionBuilder,
          (ReelRow, $$ReelsTableReferences),
          ReelRow,
          PrefetchHooks Function({
            bool clipReelsRefs,
            bool reelReferencesRefs,
            bool editSessionsRefs,
          })
        > {
  $$ReelsTableTableManager(_$AppDatabase db, $ReelsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ReelsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ReelsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ReelsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<ReelStatus> status = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => ReelsCompanion(
                id: id,
                name: name,
                description: description,
                status: status,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                Value<String?> description = const Value.absent(),
                required ReelStatus status,
                required DateTime createdAt,
                required DateTime updatedAt,
              }) => ReelsCompanion.insert(
                id: id,
                name: name,
                description: description,
                status: status,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ReelsTable, ReelRow>(table),
                  $$ReelsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                clipReelsRefs = false,
                reelReferencesRefs = false,
                editSessionsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (clipReelsRefs) db.clipReels,
                    if (reelReferencesRefs) db.reelReferences,
                    if (editSessionsRefs) db.editSessions,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (clipReelsRefs)
                        await $_getPrefetchedDataByColumns<
                          ReelRow,
                          $ReelsTable,
                          ClipReelRow,
                          $ClipReelsTable
                        >(
                          currentTable: table,
                          referencedTable: $$ReelsTableReferences
                              ._clipReelsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ReelsTableReferences(
                                db,
                                table,
                                p0,
                              ).clipReelsRefs,
                          currentColumn: 'id',
                          referencedColumn: 'reel_id',
                          typedResults: items,
                        ),
                      if (reelReferencesRefs)
                        await $_getPrefetchedDataByColumns<
                          ReelRow,
                          $ReelsTable,
                          ReelReferenceRow,
                          $ReelReferencesTable
                        >(
                          currentTable: table,
                          referencedTable: $$ReelsTableReferences
                              ._reelReferencesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ReelsTableReferences(
                                db,
                                table,
                                p0,
                              ).reelReferencesRefs,
                          currentColumn: 'id',
                          referencedColumn: 'reel_id',
                          typedResults: items,
                        ),
                      if (editSessionsRefs)
                        await $_getPrefetchedDataByColumns<
                          ReelRow,
                          $ReelsTable,
                          EditSessionRow,
                          $EditSessionsTable
                        >(
                          currentTable: table,
                          referencedTable: $$ReelsTableReferences
                              ._editSessionsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ReelsTableReferences(
                                db,
                                table,
                                p0,
                              ).editSessionsRefs,
                          currentColumn: 'id',
                          referencedColumn: 'reel_id',
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$ReelsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ReelsTable,
      ReelRow,
      $$ReelsTableFilterComposer,
      $$ReelsTableOrderingComposer,
      $$ReelsTableAnnotationComposer,
      $$ReelsTableCreateCompanionBuilder,
      $$ReelsTableUpdateCompanionBuilder,
      (ReelRow, $$ReelsTableReferences),
      ReelRow,
      PrefetchHooks Function({
        bool clipReelsRefs,
        bool reelReferencesRefs,
        bool editSessionsRefs,
      })
    >;
typedef $$ClipsTableCreateCompanionBuilder = ClipsCompanion Function({
  Value<int> id,
  required ClipSource source,
  Value<int?> mediaStoreId,
  Value<String?> volumeName,
  Value<String?> pickerUri,
  required int sizeBytes,
  required int durationMs,
  required DateTime dateTakenUtc,
  required String displayName,
  required int width,
  required int height,
  required String mimeType,
  Value<String?> timeZoneId,
  Value<int?> generationAdded,
  required DateTime firstSeenAt,
  Value<bool> missing,
  Value<DateTime?> lastVerifiedAt,
});
typedef $$ClipsTableUpdateCompanionBuilder = ClipsCompanion Function({
  Value<int> id,
  Value<ClipSource> source,
  Value<int?> mediaStoreId,
  Value<String?> volumeName,
  Value<String?> pickerUri,
  Value<int> sizeBytes,
  Value<int> durationMs,
  Value<DateTime> dateTakenUtc,
  Value<String> displayName,
  Value<int> width,
  Value<int> height,
  Value<String> mimeType,
  Value<String?> timeZoneId,
  Value<int?> generationAdded,
  Value<DateTime> firstSeenAt,
  Value<bool> missing,
  Value<DateTime?> lastVerifiedAt,
});

final class $$ClipsTableReferences
    extends BaseReferences<_$AppDatabase, $ClipsTable, ClipRow> {
  $$ClipsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$ClipReelsTable, List<ClipReelRow>>
  _clipReelsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.clipReels,
    aliasName: 'clips__id__clip_reels__clip_id',
  );

  $$ClipReelsTableProcessedTableManager get clipReelsRefs {
    final manager = $$ClipReelsTableTableManager(
      $_db,
      $_db.clipReels,
    ).filter((f) => f.clipId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_clipReelsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$InboxTable, List<InboxRow>> _inboxRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.inbox,
    aliasName: 'clips__id__inbox__clip_id',
  );

  $$InboxTableProcessedTableManager get inboxRefs {
    final manager = $$InboxTableTableManager(
      $_db,
      $_db.inbox,
    ).filter((f) => f.clipId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_inboxRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$ClipsTableFilterComposer extends Composer<_$AppDatabase, $ClipsTable> {
  $$ClipsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<ClipSource, ClipSource, String> get source =>
      $composableBuilder(
        column: $table.source,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<int> get mediaStoreId => $composableBuilder(
    column: $table.mediaStoreId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get volumeName => $composableBuilder(
    column: $table.volumeName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get pickerUri => $composableBuilder(
    column: $table.pickerUri,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sizeBytes => $composableBuilder(
    column: $table.sizeBytes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<DateTime, DateTime, int> get dateTakenUtc =>
      $composableBuilder(
        column: $table.dateTakenUtc,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get width => $composableBuilder(
    column: $table.width,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get height => $composableBuilder(
    column: $table.height,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mimeType => $composableBuilder(
    column: $table.mimeType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get timeZoneId => $composableBuilder(
    column: $table.timeZoneId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get generationAdded => $composableBuilder(
    column: $table.generationAdded,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<DateTime, DateTime, int> get firstSeenAt =>
      $composableBuilder(
        column: $table.firstSeenAt,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<bool> get missing => $composableBuilder(
    column: $table.missing,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<DateTime?, DateTime, int> get lastVerifiedAt =>
      $composableBuilder(
        column: $table.lastVerifiedAt,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  Expression<bool> clipReelsRefs(
    Expression<bool> Function($$ClipReelsTableFilterComposer f) f,
  ) {
    final $$ClipReelsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.clipReels,
      getReferencedColumn: (t) => t.clipId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ClipReelsTableFilterComposer(
            $db: $db,
            $table: $db.clipReels,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> inboxRefs(
    Expression<bool> Function($$InboxTableFilterComposer f) f,
  ) {
    final $$InboxTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.inbox,
      getReferencedColumn: (t) => t.clipId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$InboxTableFilterComposer(
            $db: $db,
            $table: $db.inbox,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ClipsTableOrderingComposer
    extends Composer<_$AppDatabase, $ClipsTable> {
  $$ClipsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get mediaStoreId => $composableBuilder(
    column: $table.mediaStoreId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get volumeName => $composableBuilder(
    column: $table.volumeName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get pickerUri => $composableBuilder(
    column: $table.pickerUri,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sizeBytes => $composableBuilder(
    column: $table.sizeBytes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get dateTakenUtc => $composableBuilder(
    column: $table.dateTakenUtc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get width => $composableBuilder(
    column: $table.width,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get height => $composableBuilder(
    column: $table.height,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mimeType => $composableBuilder(
    column: $table.mimeType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get timeZoneId => $composableBuilder(
    column: $table.timeZoneId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get generationAdded => $composableBuilder(
    column: $table.generationAdded,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get firstSeenAt => $composableBuilder(
    column: $table.firstSeenAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get missing => $composableBuilder(
    column: $table.missing,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastVerifiedAt => $composableBuilder(
    column: $table.lastVerifiedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ClipsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ClipsTable> {
  $$ClipsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumnWithTypeConverter<ClipSource, String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<int> get mediaStoreId => $composableBuilder(
    column: $table.mediaStoreId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get volumeName => $composableBuilder(
    column: $table.volumeName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get pickerUri =>
      $composableBuilder(column: $table.pickerUri, builder: (column) => column);

  GeneratedColumn<int> get sizeBytes =>
      $composableBuilder(column: $table.sizeBytes, builder: (column) => column);

  GeneratedColumn<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<DateTime, int> get dateTakenUtc =>
      $composableBuilder(
        column: $table.dateTakenUtc,
        builder: (column) => column,
      );

  GeneratedColumn<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => column,
  );

  GeneratedColumn<int> get width =>
      $composableBuilder(column: $table.width, builder: (column) => column);

  GeneratedColumn<int> get height =>
      $composableBuilder(column: $table.height, builder: (column) => column);

  GeneratedColumn<String> get mimeType =>
      $composableBuilder(column: $table.mimeType, builder: (column) => column);

  GeneratedColumn<String> get timeZoneId => $composableBuilder(
    column: $table.timeZoneId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get generationAdded => $composableBuilder(
    column: $table.generationAdded,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<DateTime, int> get firstSeenAt =>
      $composableBuilder(
        column: $table.firstSeenAt,
        builder: (column) => column,
      );

  GeneratedColumn<bool> get missing =>
      $composableBuilder(column: $table.missing, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DateTime?, int> get lastVerifiedAt =>
      $composableBuilder(
        column: $table.lastVerifiedAt,
        builder: (column) => column,
      );

  Expression<T> clipReelsRefs<T extends Object>(
    Expression<T> Function($$ClipReelsTableAnnotationComposer a) f,
  ) {
    final $$ClipReelsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.clipReels,
      getReferencedColumn: (t) => t.clipId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ClipReelsTableAnnotationComposer(
            $db: $db,
            $table: $db.clipReels,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> inboxRefs<T extends Object>(
    Expression<T> Function($$InboxTableAnnotationComposer a) f,
  ) {
    final $$InboxTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.inbox,
      getReferencedColumn: (t) => t.clipId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$InboxTableAnnotationComposer(
            $db: $db,
            $table: $db.inbox,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ClipsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ClipsTable,
          ClipRow,
          $$ClipsTableFilterComposer,
          $$ClipsTableOrderingComposer,
          $$ClipsTableAnnotationComposer,
          $$ClipsTableCreateCompanionBuilder,
          $$ClipsTableUpdateCompanionBuilder,
          (ClipRow, $$ClipsTableReferences),
          ClipRow,
          PrefetchHooks Function({bool clipReelsRefs, bool inboxRefs})
        > {
  $$ClipsTableTableManager(_$AppDatabase db, $ClipsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ClipsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ClipsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ClipsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<ClipSource> source = const Value.absent(),
                Value<int?> mediaStoreId = const Value.absent(),
                Value<String?> volumeName = const Value.absent(),
                Value<String?> pickerUri = const Value.absent(),
                Value<int> sizeBytes = const Value.absent(),
                Value<int> durationMs = const Value.absent(),
                Value<DateTime> dateTakenUtc = const Value.absent(),
                Value<String> displayName = const Value.absent(),
                Value<int> width = const Value.absent(),
                Value<int> height = const Value.absent(),
                Value<String> mimeType = const Value.absent(),
                Value<String?> timeZoneId = const Value.absent(),
                Value<int?> generationAdded = const Value.absent(),
                Value<DateTime> firstSeenAt = const Value.absent(),
                Value<bool> missing = const Value.absent(),
                Value<DateTime?> lastVerifiedAt = const Value.absent(),
              }) => ClipsCompanion(
                id: id,
                source: source,
                mediaStoreId: mediaStoreId,
                volumeName: volumeName,
                pickerUri: pickerUri,
                sizeBytes: sizeBytes,
                durationMs: durationMs,
                dateTakenUtc: dateTakenUtc,
                displayName: displayName,
                width: width,
                height: height,
                mimeType: mimeType,
                timeZoneId: timeZoneId,
                generationAdded: generationAdded,
                firstSeenAt: firstSeenAt,
                missing: missing,
                lastVerifiedAt: lastVerifiedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required ClipSource source,
                Value<int?> mediaStoreId = const Value.absent(),
                Value<String?> volumeName = const Value.absent(),
                Value<String?> pickerUri = const Value.absent(),
                required int sizeBytes,
                required int durationMs,
                required DateTime dateTakenUtc,
                required String displayName,
                required int width,
                required int height,
                required String mimeType,
                Value<String?> timeZoneId = const Value.absent(),
                Value<int?> generationAdded = const Value.absent(),
                required DateTime firstSeenAt,
                Value<bool> missing = const Value.absent(),
                Value<DateTime?> lastVerifiedAt = const Value.absent(),
              }) => ClipsCompanion.insert(
                id: id,
                source: source,
                mediaStoreId: mediaStoreId,
                volumeName: volumeName,
                pickerUri: pickerUri,
                sizeBytes: sizeBytes,
                durationMs: durationMs,
                dateTakenUtc: dateTakenUtc,
                displayName: displayName,
                width: width,
                height: height,
                mimeType: mimeType,
                timeZoneId: timeZoneId,
                generationAdded: generationAdded,
                firstSeenAt: firstSeenAt,
                missing: missing,
                lastVerifiedAt: lastVerifiedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ClipsTable, ClipRow>(table),
                  $$ClipsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({clipReelsRefs = false, inboxRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (clipReelsRefs) db.clipReels,
                if (inboxRefs) db.inbox,
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (clipReelsRefs)
                    await $_getPrefetchedDataByColumns<
                      ClipRow,
                      $ClipsTable,
                      ClipReelRow,
                      $ClipReelsTable
                    >(
                      currentTable: table,
                      referencedTable: $$ClipsTableReferences
                          ._clipReelsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$ClipsTableReferences(db, table, p0).clipReelsRefs,
                      currentColumn: 'id',
                      referencedColumn: 'clip_id',
                      typedResults: items,
                    ),
                  if (inboxRefs)
                    await $_getPrefetchedDataByColumns<
                      ClipRow,
                      $ClipsTable,
                      InboxRow,
                      $InboxTable
                    >(
                      currentTable: table,
                      referencedTable: $$ClipsTableReferences._inboxRefsTable(
                        db,
                      ),
                      managerFromTypedResult: (p0) =>
                          $$ClipsTableReferences(db, table, p0).inboxRefs,
                      currentColumn: 'id',
                      referencedColumn: 'clip_id',
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$ClipsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ClipsTable,
      ClipRow,
      $$ClipsTableFilterComposer,
      $$ClipsTableOrderingComposer,
      $$ClipsTableAnnotationComposer,
      $$ClipsTableCreateCompanionBuilder,
      $$ClipsTableUpdateCompanionBuilder,
      (ClipRow, $$ClipsTableReferences),
      ClipRow,
      PrefetchHooks Function({bool clipReelsRefs, bool inboxRefs})
    >;
typedef $$ClipReelsTableCreateCompanionBuilder = ClipReelsCompanion Function({
  required int clipId,
  required int reelId,
  required DateTime addedAt,
  Value<int> rowid,
});
typedef $$ClipReelsTableUpdateCompanionBuilder = ClipReelsCompanion Function({
  Value<int> clipId,
  Value<int> reelId,
  Value<DateTime> addedAt,
  Value<int> rowid,
});

final class $$ClipReelsTableReferences
    extends BaseReferences<_$AppDatabase, $ClipReelsTable, ClipReelRow> {
  $$ClipReelsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ClipsTable _clipIdTable(_$AppDatabase db) =>
      db.clips.createAlias('clip_reels__clip_id__clips__id');

  $$ClipsTableProcessedTableManager get clipId {
    final $_column = $_itemColumn<int>('clip_id')!;

    final manager = $$ClipsTableTableManager(
      $_db,
      $_db.clips,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_clipIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $ReelsTable _reelIdTable(_$AppDatabase db) =>
      db.reels.createAlias('clip_reels__reel_id__reels__id');

  $$ReelsTableProcessedTableManager get reelId {
    final $_column = $_itemColumn<int>('reel_id')!;

    final manager = $$ReelsTableTableManager(
      $_db,
      $_db.reels,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_reelIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$ClipReelsTableFilterComposer
    extends Composer<_$AppDatabase, $ClipReelsTable> {
  $$ClipReelsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnWithTypeConverterFilters<DateTime, DateTime, int> get addedAt =>
      $composableBuilder(
        column: $table.addedAt,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  $$ClipsTableFilterComposer get clipId {
    final $$ClipsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.clipId,
      referencedTable: $db.clips,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ClipsTableFilterComposer(
            $db: $db,
            $table: $db.clips,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ReelsTableFilterComposer get reelId {
    final $$ReelsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.reelId,
      referencedTable: $db.reels,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ReelsTableFilterComposer(
            $db: $db,
            $table: $db.reels,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ClipReelsTableOrderingComposer
    extends Composer<_$AppDatabase, $ClipReelsTable> {
  $$ClipReelsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$ClipsTableOrderingComposer get clipId {
    final $$ClipsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.clipId,
      referencedTable: $db.clips,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ClipsTableOrderingComposer(
            $db: $db,
            $table: $db.clips,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ReelsTableOrderingComposer get reelId {
    final $$ReelsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.reelId,
      referencedTable: $db.reels,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ReelsTableOrderingComposer(
            $db: $db,
            $table: $db.reels,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ClipReelsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ClipReelsTable> {
  $$ClipReelsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumnWithTypeConverter<DateTime, int> get addedAt =>
      $composableBuilder(column: $table.addedAt, builder: (column) => column);

  $$ClipsTableAnnotationComposer get clipId {
    final $$ClipsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.clipId,
      referencedTable: $db.clips,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ClipsTableAnnotationComposer(
            $db: $db,
            $table: $db.clips,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ReelsTableAnnotationComposer get reelId {
    final $$ReelsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.reelId,
      referencedTable: $db.reels,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ReelsTableAnnotationComposer(
            $db: $db,
            $table: $db.reels,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ClipReelsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ClipReelsTable,
          ClipReelRow,
          $$ClipReelsTableFilterComposer,
          $$ClipReelsTableOrderingComposer,
          $$ClipReelsTableAnnotationComposer,
          $$ClipReelsTableCreateCompanionBuilder,
          $$ClipReelsTableUpdateCompanionBuilder,
          (ClipReelRow, $$ClipReelsTableReferences),
          ClipReelRow,
          PrefetchHooks Function({bool clipId, bool reelId})
        > {
  $$ClipReelsTableTableManager(_$AppDatabase db, $ClipReelsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ClipReelsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ClipReelsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ClipReelsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> clipId = const Value.absent(),
                Value<int> reelId = const Value.absent(),
                Value<DateTime> addedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ClipReelsCompanion(
                clipId: clipId,
                reelId: reelId,
                addedAt: addedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required int clipId,
                required int reelId,
                required DateTime addedAt,
                Value<int> rowid = const Value.absent(),
              }) => ClipReelsCompanion.insert(
                clipId: clipId,
                reelId: reelId,
                addedAt: addedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ClipReelsTable, ClipReelRow>(table),
                  $$ClipReelsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({clipId = false, reelId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (clipId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.clipId,
                        referencedTable: $$ClipReelsTableReferences
                            ._clipIdTable(db),
                        referencedColumn: $$ClipReelsTableReferences
                            ._clipIdTable(db)
                            .id,
                      ) as T;
                    }
                    if (reelId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.reelId,
                        referencedTable: $$ClipReelsTableReferences
                            ._reelIdTable(db),
                        referencedColumn: $$ClipReelsTableReferences
                            ._reelIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$ClipReelsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ClipReelsTable,
      ClipReelRow,
      $$ClipReelsTableFilterComposer,
      $$ClipReelsTableOrderingComposer,
      $$ClipReelsTableAnnotationComposer,
      $$ClipReelsTableCreateCompanionBuilder,
      $$ClipReelsTableUpdateCompanionBuilder,
      (ClipReelRow, $$ClipReelsTableReferences),
      ClipReelRow,
      PrefetchHooks Function({bool clipId, bool reelId})
    >;
typedef $$InboxTableCreateCompanionBuilder = InboxCompanion Function({
  Value<int> clipId,
  required InboxState state,
  required DateTime addedAt,
});
typedef $$InboxTableUpdateCompanionBuilder = InboxCompanion Function({
  Value<int> clipId,
  Value<InboxState> state,
  Value<DateTime> addedAt,
});

final class $$InboxTableReferences
    extends BaseReferences<_$AppDatabase, $InboxTable, InboxRow> {
  $$InboxTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ClipsTable _clipIdTable(_$AppDatabase db) =>
      db.clips.createAlias('inbox__clip_id__clips__id');

  $$ClipsTableProcessedTableManager get clipId {
    final $_column = $_itemColumn<int>('clip_id')!;

    final manager = $$ClipsTableTableManager(
      $_db,
      $_db.clips,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_clipIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$InboxTableFilterComposer extends Composer<_$AppDatabase, $InboxTable> {
  $$InboxTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnWithTypeConverterFilters<InboxState, InboxState, String> get state =>
      $composableBuilder(
        column: $table.state,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnWithTypeConverterFilters<DateTime, DateTime, int> get addedAt =>
      $composableBuilder(
        column: $table.addedAt,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  $$ClipsTableFilterComposer get clipId {
    final $$ClipsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.clipId,
      referencedTable: $db.clips,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ClipsTableFilterComposer(
            $db: $db,
            $table: $db.clips,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$InboxTableOrderingComposer
    extends Composer<_$AppDatabase, $InboxTable> {
  $$InboxTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$ClipsTableOrderingComposer get clipId {
    final $$ClipsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.clipId,
      referencedTable: $db.clips,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ClipsTableOrderingComposer(
            $db: $db,
            $table: $db.clips,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$InboxTableAnnotationComposer
    extends Composer<_$AppDatabase, $InboxTable> {
  $$InboxTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumnWithTypeConverter<InboxState, String> get state =>
      $composableBuilder(column: $table.state, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DateTime, int> get addedAt =>
      $composableBuilder(column: $table.addedAt, builder: (column) => column);

  $$ClipsTableAnnotationComposer get clipId {
    final $$ClipsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.clipId,
      referencedTable: $db.clips,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ClipsTableAnnotationComposer(
            $db: $db,
            $table: $db.clips,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$InboxTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $InboxTable,
          InboxRow,
          $$InboxTableFilterComposer,
          $$InboxTableOrderingComposer,
          $$InboxTableAnnotationComposer,
          $$InboxTableCreateCompanionBuilder,
          $$InboxTableUpdateCompanionBuilder,
          (InboxRow, $$InboxTableReferences),
          InboxRow,
          PrefetchHooks Function({bool clipId})
        > {
  $$InboxTableTableManager(_$AppDatabase db, $InboxTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$InboxTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$InboxTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$InboxTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> clipId = const Value.absent(),
            Value<InboxState> state = const Value.absent(),
            Value<DateTime> addedAt = const Value.absent(),
          }) => InboxCompanion(clipId: clipId, state: state, addedAt: addedAt),
          createCompanionCallback:
              ({
                Value<int> clipId = const Value.absent(),
                required InboxState state,
                required DateTime addedAt,
              }) => InboxCompanion.insert(
                clipId: clipId,
                state: state,
                addedAt: addedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$InboxTable, InboxRow>(table),
                  $$InboxTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({clipId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (clipId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.clipId,
                        referencedTable: $$InboxTableReferences._clipIdTable(
                          db,
                        ),
                        referencedColumn: $$InboxTableReferences
                            ._clipIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$InboxTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $InboxTable,
      InboxRow,
      $$InboxTableFilterComposer,
      $$InboxTableOrderingComposer,
      $$InboxTableAnnotationComposer,
      $$InboxTableCreateCompanionBuilder,
      $$InboxTableUpdateCompanionBuilder,
      (InboxRow, $$InboxTableReferences),
      InboxRow,
      PrefetchHooks Function({bool clipId})
    >;
typedef $$ReelReferencesTableCreateCompanionBuilder =
    ReelReferencesCompanion Function({
      Value<int> id,
      required int reelId,
      required String url,
      required ReferenceSource source,
      Value<String?> label,
      required DateTime createdAt,
    });
typedef $$ReelReferencesTableUpdateCompanionBuilder =
    ReelReferencesCompanion Function({
      Value<int> id,
      Value<int> reelId,
      Value<String> url,
      Value<ReferenceSource> source,
      Value<String?> label,
      Value<DateTime> createdAt,
    });

final class $$ReelReferencesTableReferences
    extends
        BaseReferences<_$AppDatabase, $ReelReferencesTable, ReelReferenceRow> {
  $$ReelReferencesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $ReelsTable _reelIdTable(_$AppDatabase db) =>
      db.reels.createAlias('reel_references__reel_id__reels__id');

  $$ReelsTableProcessedTableManager get reelId {
    final $_column = $_itemColumn<int>('reel_id')!;

    final manager = $$ReelsTableTableManager(
      $_db,
      $_db.reels,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_reelIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$ReelReferencesTableFilterComposer
    extends Composer<_$AppDatabase, $ReelReferencesTable> {
  $$ReelReferencesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get url => $composableBuilder(
    column: $table.url,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<ReferenceSource, ReferenceSource, String>
  get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<DateTime, DateTime, int> get createdAt =>
      $composableBuilder(
        column: $table.createdAt,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  $$ReelsTableFilterComposer get reelId {
    final $$ReelsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.reelId,
      referencedTable: $db.reels,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ReelsTableFilterComposer(
            $db: $db,
            $table: $db.reels,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ReelReferencesTableOrderingComposer
    extends Composer<_$AppDatabase, $ReelReferencesTable> {
  $$ReelReferencesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get url => $composableBuilder(
    column: $table.url,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$ReelsTableOrderingComposer get reelId {
    final $$ReelsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.reelId,
      referencedTable: $db.reels,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ReelsTableOrderingComposer(
            $db: $db,
            $table: $db.reels,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ReelReferencesTableAnnotationComposer
    extends Composer<_$AppDatabase, $ReelReferencesTable> {
  $$ReelReferencesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get url =>
      $composableBuilder(column: $table.url, builder: (column) => column);

  GeneratedColumnWithTypeConverter<ReferenceSource, String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<String> get label =>
      $composableBuilder(column: $table.label, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DateTime, int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$ReelsTableAnnotationComposer get reelId {
    final $$ReelsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.reelId,
      referencedTable: $db.reels,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ReelsTableAnnotationComposer(
            $db: $db,
            $table: $db.reels,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ReelReferencesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ReelReferencesTable,
          ReelReferenceRow,
          $$ReelReferencesTableFilterComposer,
          $$ReelReferencesTableOrderingComposer,
          $$ReelReferencesTableAnnotationComposer,
          $$ReelReferencesTableCreateCompanionBuilder,
          $$ReelReferencesTableUpdateCompanionBuilder,
          (ReelReferenceRow, $$ReelReferencesTableReferences),
          ReelReferenceRow,
          PrefetchHooks Function({bool reelId})
        > {
  $$ReelReferencesTableTableManager(
    _$AppDatabase db,
    $ReelReferencesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ReelReferencesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ReelReferencesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ReelReferencesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> reelId = const Value.absent(),
                Value<String> url = const Value.absent(),
                Value<ReferenceSource> source = const Value.absent(),
                Value<String?> label = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => ReelReferencesCompanion(
                id: id,
                reelId: reelId,
                url: url,
                source: source,
                label: label,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int reelId,
                required String url,
                required ReferenceSource source,
                Value<String?> label = const Value.absent(),
                required DateTime createdAt,
              }) => ReelReferencesCompanion.insert(
                id: id,
                reelId: reelId,
                url: url,
                source: source,
                label: label,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ReelReferencesTable, ReelReferenceRow>(table),
                  $$ReelReferencesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({reelId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (reelId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.reelId,
                        referencedTable: $$ReelReferencesTableReferences
                            ._reelIdTable(db),
                        referencedColumn: $$ReelReferencesTableReferences
                            ._reelIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$ReelReferencesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ReelReferencesTable,
      ReelReferenceRow,
      $$ReelReferencesTableFilterComposer,
      $$ReelReferencesTableOrderingComposer,
      $$ReelReferencesTableAnnotationComposer,
      $$ReelReferencesTableCreateCompanionBuilder,
      $$ReelReferencesTableUpdateCompanionBuilder,
      (ReelReferenceRow, $$ReelReferencesTableReferences),
      ReelReferenceRow,
      PrefetchHooks Function({bool reelId})
    >;
typedef $$EditSessionsTableCreateCompanionBuilder =
    EditSessionsCompanion Function({
      Value<int> reelId,
      Value<EditorApp> editor,
      required String folderName,
      required DateTime createdAt,
    });
typedef $$EditSessionsTableUpdateCompanionBuilder =
    EditSessionsCompanion Function({
      Value<int> reelId,
      Value<EditorApp> editor,
      Value<String> folderName,
      Value<DateTime> createdAt,
    });

final class $$EditSessionsTableReferences
    extends BaseReferences<_$AppDatabase, $EditSessionsTable, EditSessionRow> {
  $$EditSessionsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ReelsTable _reelIdTable(_$AppDatabase db) =>
      db.reels.createAlias('vn_sessions__reel_id__reels__id');

  $$ReelsTableProcessedTableManager get reelId {
    final $_column = $_itemColumn<int>('reel_id')!;

    final manager = $$ReelsTableTableManager(
      $_db,
      $_db.reels,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_reelIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$EditSessionsTableFilterComposer
    extends Composer<_$AppDatabase, $EditSessionsTable> {
  $$EditSessionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnWithTypeConverterFilters<EditorApp, EditorApp, String> get editor =>
      $composableBuilder(
        column: $table.editor,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<String> get folderName => $composableBuilder(
    column: $table.folderName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<DateTime, DateTime, int> get createdAt =>
      $composableBuilder(
        column: $table.createdAt,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  $$ReelsTableFilterComposer get reelId {
    final $$ReelsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.reelId,
      referencedTable: $db.reels,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ReelsTableFilterComposer(
            $db: $db,
            $table: $db.reels,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$EditSessionsTableOrderingComposer
    extends Composer<_$AppDatabase, $EditSessionsTable> {
  $$EditSessionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get editor => $composableBuilder(
    column: $table.editor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get folderName => $composableBuilder(
    column: $table.folderName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$ReelsTableOrderingComposer get reelId {
    final $$ReelsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.reelId,
      referencedTable: $db.reels,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ReelsTableOrderingComposer(
            $db: $db,
            $table: $db.reels,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$EditSessionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $EditSessionsTable> {
  $$EditSessionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumnWithTypeConverter<EditorApp, String> get editor =>
      $composableBuilder(column: $table.editor, builder: (column) => column);

  GeneratedColumn<String> get folderName => $composableBuilder(
    column: $table.folderName,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<DateTime, int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$ReelsTableAnnotationComposer get reelId {
    final $$ReelsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.reelId,
      referencedTable: $db.reels,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ReelsTableAnnotationComposer(
            $db: $db,
            $table: $db.reels,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$EditSessionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $EditSessionsTable,
          EditSessionRow,
          $$EditSessionsTableFilterComposer,
          $$EditSessionsTableOrderingComposer,
          $$EditSessionsTableAnnotationComposer,
          $$EditSessionsTableCreateCompanionBuilder,
          $$EditSessionsTableUpdateCompanionBuilder,
          (EditSessionRow, $$EditSessionsTableReferences),
          EditSessionRow,
          PrefetchHooks Function({bool reelId})
        > {
  $$EditSessionsTableTableManager(_$AppDatabase db, $EditSessionsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$EditSessionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$EditSessionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$EditSessionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> reelId = const Value.absent(),
                Value<EditorApp> editor = const Value.absent(),
                Value<String> folderName = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => EditSessionsCompanion(
                reelId: reelId,
                editor: editor,
                folderName: folderName,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> reelId = const Value.absent(),
                Value<EditorApp> editor = const Value.absent(),
                required String folderName,
                required DateTime createdAt,
              }) => EditSessionsCompanion.insert(
                reelId: reelId,
                editor: editor,
                folderName: folderName,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$EditSessionsTable, EditSessionRow>(table),
                  $$EditSessionsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({reelId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (reelId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.reelId,
                        referencedTable: $$EditSessionsTableReferences
                            ._reelIdTable(db),
                        referencedColumn: $$EditSessionsTableReferences
                            ._reelIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$EditSessionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $EditSessionsTable,
      EditSessionRow,
      $$EditSessionsTableFilterComposer,
      $$EditSessionsTableOrderingComposer,
      $$EditSessionsTableAnnotationComposer,
      $$EditSessionsTableCreateCompanionBuilder,
      $$EditSessionsTableUpdateCompanionBuilder,
      (EditSessionRow, $$EditSessionsTableReferences),
      EditSessionRow,
      PrefetchHooks Function({bool reelId})
    >;
typedef $$EditCopiesTableCreateCompanionBuilder = EditCopiesCompanion Function({
  required int reelId,
  required int clipId,
  required int copyMediaStoreId,
  required String fileName,
  required int sizeBytes,
  Value<DateTime> copiedAt,
  Value<int> rowid,
});
typedef $$EditCopiesTableUpdateCompanionBuilder = EditCopiesCompanion Function({
  Value<int> reelId,
  Value<int> clipId,
  Value<int> copyMediaStoreId,
  Value<String> fileName,
  Value<int> sizeBytes,
  Value<DateTime> copiedAt,
  Value<int> rowid,
});

class $$EditCopiesTableFilterComposer
    extends Composer<_$AppDatabase, $EditCopiesTable> {
  $$EditCopiesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get clipId => $composableBuilder(
    column: $table.clipId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get copyMediaStoreId => $composableBuilder(
    column: $table.copyMediaStoreId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fileName => $composableBuilder(
    column: $table.fileName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sizeBytes => $composableBuilder(
    column: $table.sizeBytes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<DateTime, DateTime, int> get copiedAt =>
      $composableBuilder(
        column: $table.copiedAt,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );
}

class $$EditCopiesTableOrderingComposer
    extends Composer<_$AppDatabase, $EditCopiesTable> {
  $$EditCopiesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get clipId => $composableBuilder(
    column: $table.clipId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get copyMediaStoreId => $composableBuilder(
    column: $table.copyMediaStoreId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fileName => $composableBuilder(
    column: $table.fileName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sizeBytes => $composableBuilder(
    column: $table.sizeBytes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get copiedAt => $composableBuilder(
    column: $table.copiedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$EditCopiesTableAnnotationComposer
    extends Composer<_$AppDatabase, $EditCopiesTable> {
  $$EditCopiesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get clipId =>
      $composableBuilder(column: $table.clipId, builder: (column) => column);

  GeneratedColumn<int> get copyMediaStoreId => $composableBuilder(
    column: $table.copyMediaStoreId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get fileName =>
      $composableBuilder(column: $table.fileName, builder: (column) => column);

  GeneratedColumn<int> get sizeBytes =>
      $composableBuilder(column: $table.sizeBytes, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DateTime, int> get copiedAt =>
      $composableBuilder(column: $table.copiedAt, builder: (column) => column);
}

class $$EditCopiesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $EditCopiesTable,
          EditCopyRow,
          $$EditCopiesTableFilterComposer,
          $$EditCopiesTableOrderingComposer,
          $$EditCopiesTableAnnotationComposer,
          $$EditCopiesTableCreateCompanionBuilder,
          $$EditCopiesTableUpdateCompanionBuilder,
          (
            EditCopyRow,
            BaseReferences<_$AppDatabase, $EditCopiesTable, EditCopyRow>,
          ),
          EditCopyRow,
          PrefetchHooks Function()
        > {
  $$EditCopiesTableTableManager(_$AppDatabase db, $EditCopiesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$EditCopiesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$EditCopiesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$EditCopiesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> reelId = const Value.absent(),
                Value<int> clipId = const Value.absent(),
                Value<int> copyMediaStoreId = const Value.absent(),
                Value<String> fileName = const Value.absent(),
                Value<int> sizeBytes = const Value.absent(),
                Value<DateTime> copiedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => EditCopiesCompanion(
                reelId: reelId,
                clipId: clipId,
                copyMediaStoreId: copyMediaStoreId,
                fileName: fileName,
                sizeBytes: sizeBytes,
                copiedAt: copiedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required int reelId,
                required int clipId,
                required int copyMediaStoreId,
                required String fileName,
                required int sizeBytes,
                Value<DateTime> copiedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => EditCopiesCompanion.insert(
                reelId: reelId,
                clipId: clipId,
                copyMediaStoreId: copyMediaStoreId,
                fileName: fileName,
                sizeBytes: sizeBytes,
                copiedAt: copiedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$EditCopiesTable, EditCopyRow>(table),
                  BaseReferences<_$AppDatabase, $EditCopiesTable, EditCopyRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$EditCopiesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $EditCopiesTable,
      EditCopyRow,
      $$EditCopiesTableFilterComposer,
      $$EditCopiesTableOrderingComposer,
      $$EditCopiesTableAnnotationComposer,
      $$EditCopiesTableCreateCompanionBuilder,
      $$EditCopiesTableUpdateCompanionBuilder,
      (
        EditCopyRow,
        BaseReferences<_$AppDatabase, $EditCopiesTable, EditCopyRow>,
      ),
      EditCopyRow,
      PrefetchHooks Function()
    >;
typedef $$SentClipsTableCreateCompanionBuilder = SentClipsCompanion Function({
  required int reelId,
  required int clipId,
  required DateTime sentAt,
  Value<int> rowid,
});
typedef $$SentClipsTableUpdateCompanionBuilder = SentClipsCompanion Function({
  Value<int> reelId,
  Value<int> clipId,
  Value<DateTime> sentAt,
  Value<int> rowid,
});

class $$SentClipsTableFilterComposer
    extends Composer<_$AppDatabase, $SentClipsTable> {
  $$SentClipsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get clipId => $composableBuilder(
    column: $table.clipId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<DateTime, DateTime, int> get sentAt =>
      $composableBuilder(
        column: $table.sentAt,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );
}

class $$SentClipsTableOrderingComposer
    extends Composer<_$AppDatabase, $SentClipsTable> {
  $$SentClipsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get clipId => $composableBuilder(
    column: $table.clipId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sentAt => $composableBuilder(
    column: $table.sentAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SentClipsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SentClipsTable> {
  $$SentClipsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get clipId =>
      $composableBuilder(column: $table.clipId, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DateTime, int> get sentAt =>
      $composableBuilder(column: $table.sentAt, builder: (column) => column);
}

class $$SentClipsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SentClipsTable,
          SentClipRow,
          $$SentClipsTableFilterComposer,
          $$SentClipsTableOrderingComposer,
          $$SentClipsTableAnnotationComposer,
          $$SentClipsTableCreateCompanionBuilder,
          $$SentClipsTableUpdateCompanionBuilder,
          (
            SentClipRow,
            BaseReferences<_$AppDatabase, $SentClipsTable, SentClipRow>,
          ),
          SentClipRow,
          PrefetchHooks Function()
        > {
  $$SentClipsTableTableManager(_$AppDatabase db, $SentClipsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SentClipsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SentClipsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SentClipsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> reelId = const Value.absent(),
                Value<int> clipId = const Value.absent(),
                Value<DateTime> sentAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SentClipsCompanion(
                reelId: reelId,
                clipId: clipId,
                sentAt: sentAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required int reelId,
                required int clipId,
                required DateTime sentAt,
                Value<int> rowid = const Value.absent(),
              }) => SentClipsCompanion.insert(
                reelId: reelId,
                clipId: clipId,
                sentAt: sentAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SentClipsTable, SentClipRow>(table),
                  BaseReferences<_$AppDatabase, $SentClipsTable, SentClipRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SentClipsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SentClipsTable,
      SentClipRow,
      $$SentClipsTableFilterComposer,
      $$SentClipsTableOrderingComposer,
      $$SentClipsTableAnnotationComposer,
      $$SentClipsTableCreateCompanionBuilder,
      $$SentClipsTableUpdateCompanionBuilder,
      (
        SentClipRow,
        BaseReferences<_$AppDatabase, $SentClipsTable, SentClipRow>,
      ),
      SentClipRow,
      PrefetchHooks Function()
    >;
typedef $$SettingsTableCreateCompanionBuilder = SettingsCompanion Function({
  required String key,
  required String value,
  Value<int> rowid,
});
typedef $$SettingsTableUpdateCompanionBuilder = SettingsCompanion Function({
  Value<String> key,
  Value<String> value,
  Value<int> rowid,
});

class $$SettingsTableFilterComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SettingsTableOrderingComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SettingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$SettingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SettingsTable,
          SettingRow,
          $$SettingsTableFilterComposer,
          $$SettingsTableOrderingComposer,
          $$SettingsTableAnnotationComposer,
          $$SettingsTableCreateCompanionBuilder,
          $$SettingsTableUpdateCompanionBuilder,
          (
            SettingRow,
            BaseReferences<_$AppDatabase, $SettingsTable, SettingRow>,
          ),
          SettingRow,
          PrefetchHooks Function()
        > {
  $$SettingsTableTableManager(_$AppDatabase db, $SettingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> key = const Value.absent(),
            Value<String> value = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) => SettingsCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback: ({
            required String key,
            required String value,
            Value<int> rowid = const Value.absent(),
          }) => SettingsCompanion.insert(key: key, value: value, rowid: rowid),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SettingsTable, SettingRow>(table),
                  BaseReferences<_$AppDatabase, $SettingsTable, SettingRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SettingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SettingsTable,
      SettingRow,
      $$SettingsTableFilterComposer,
      $$SettingsTableOrderingComposer,
      $$SettingsTableAnnotationComposer,
      $$SettingsTableCreateCompanionBuilder,
      $$SettingsTableUpdateCompanionBuilder,
      (SettingRow, BaseReferences<_$AppDatabase, $SettingsTable, SettingRow>),
      SettingRow,
      PrefetchHooks Function()
    >;
typedef $$ZoneTimelineTableCreateCompanionBuilder =
    ZoneTimelineCompanion Function({
      Value<DateTime> at,
      required String zoneId,
    });
typedef $$ZoneTimelineTableUpdateCompanionBuilder =
    ZoneTimelineCompanion Function({Value<DateTime> at, Value<String> zoneId});

class $$ZoneTimelineTableFilterComposer
    extends Composer<_$AppDatabase, $ZoneTimelineTable> {
  $$ZoneTimelineTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnWithTypeConverterFilters<DateTime, DateTime, int> get at =>
      $composableBuilder(
        column: $table.at,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<String> get zoneId => $composableBuilder(
    column: $table.zoneId,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ZoneTimelineTableOrderingComposer
    extends Composer<_$AppDatabase, $ZoneTimelineTable> {
  $$ZoneTimelineTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get at => $composableBuilder(
    column: $table.at,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get zoneId => $composableBuilder(
    column: $table.zoneId,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ZoneTimelineTableAnnotationComposer
    extends Composer<_$AppDatabase, $ZoneTimelineTable> {
  $$ZoneTimelineTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumnWithTypeConverter<DateTime, int> get at =>
      $composableBuilder(column: $table.at, builder: (column) => column);

  GeneratedColumn<String> get zoneId =>
      $composableBuilder(column: $table.zoneId, builder: (column) => column);
}

class $$ZoneTimelineTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ZoneTimelineTable,
          ZoneTimelineRow,
          $$ZoneTimelineTableFilterComposer,
          $$ZoneTimelineTableOrderingComposer,
          $$ZoneTimelineTableAnnotationComposer,
          $$ZoneTimelineTableCreateCompanionBuilder,
          $$ZoneTimelineTableUpdateCompanionBuilder,
          (
            ZoneTimelineRow,
            BaseReferences<_$AppDatabase, $ZoneTimelineTable, ZoneTimelineRow>,
          ),
          ZoneTimelineRow,
          PrefetchHooks Function()
        > {
  $$ZoneTimelineTableTableManager(_$AppDatabase db, $ZoneTimelineTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ZoneTimelineTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ZoneTimelineTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ZoneTimelineTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<DateTime> at = const Value.absent(),
            Value<String> zoneId = const Value.absent(),
          }) => ZoneTimelineCompanion(at: at, zoneId: zoneId),
          createCompanionCallback: ({
            Value<DateTime> at = const Value.absent(),
            required String zoneId,
          }) => ZoneTimelineCompanion.insert(at: at, zoneId: zoneId),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ZoneTimelineTable, ZoneTimelineRow>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $ZoneTimelineTable,
                    ZoneTimelineRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ZoneTimelineTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ZoneTimelineTable,
      ZoneTimelineRow,
      $$ZoneTimelineTableFilterComposer,
      $$ZoneTimelineTableOrderingComposer,
      $$ZoneTimelineTableAnnotationComposer,
      $$ZoneTimelineTableCreateCompanionBuilder,
      $$ZoneTimelineTableUpdateCompanionBuilder,
      (
        ZoneTimelineRow,
        BaseReferences<_$AppDatabase, $ZoneTimelineTable, ZoneTimelineRow>,
      ),
      ZoneTimelineRow,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$ReelsTableTableManager get reels =>
      $$ReelsTableTableManager(_db, _db.reels);
  $$ClipsTableTableManager get clips =>
      $$ClipsTableTableManager(_db, _db.clips);
  $$ClipReelsTableTableManager get clipReels =>
      $$ClipReelsTableTableManager(_db, _db.clipReels);
  $$InboxTableTableManager get inbox =>
      $$InboxTableTableManager(_db, _db.inbox);
  $$ReelReferencesTableTableManager get reelReferences =>
      $$ReelReferencesTableTableManager(_db, _db.reelReferences);
  $$EditSessionsTableTableManager get editSessions =>
      $$EditSessionsTableTableManager(_db, _db.editSessions);
  $$EditCopiesTableTableManager get editCopies =>
      $$EditCopiesTableTableManager(_db, _db.editCopies);
  $$SentClipsTableTableManager get sentClips =>
      $$SentClipsTableTableManager(_db, _db.sentClips);
  $$SettingsTableTableManager get settings =>
      $$SettingsTableTableManager(_db, _db.settings);
  $$ZoneTimelineTableTableManager get zoneTimeline =>
      $$ZoneTimelineTableTableManager(_db, _db.zoneTimeline);
}
