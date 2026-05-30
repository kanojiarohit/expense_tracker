import 'package:isar/isar.dart';

part 'provisional_transaction.g.dart';

@collection
class ProvisionalTransaction {
  Id id = Isar.autoIncrement;

  late int amountMinor;
  late String transactionType;
  late String note;
  late String smsBody;
  late String sender;
  String? paymentMethod;
  String? sourceKey;

  @Index()
  late DateTime smsReceivedAt;

  @Index()
  late DateTime createdAt;

  @Index()
  late String status;
}
