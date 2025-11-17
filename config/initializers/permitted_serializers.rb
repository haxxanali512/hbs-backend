# Configure permitted classes for YAML serialization
# This allows Date, Time, and related classes to be serialized for Audited gem
Rails.application.config.active_record.yaml_column_permitted_classes = [
  Date,
  Time,
  DateTime,
  ActiveSupport::TimeWithZone,
  ActiveSupport::TimeZone,
  BigDecimal,
  Float,
  Integer,
  String,
  Symbol,
  TrueClass,
  FalseClass,
  Array,
  Hash,
  ActiveRecord::Base,
  ActiveRecord::Relation,
  ActiveRecord::Associations::CollectionProxy
].freeze
