import 'package:isar/isar.dart';

import '../database/isar_service.dart';
import '../models/provisional_transaction.dart';

class ProvisionalTransactionStatus {
  static const pending = 'pending';
  static const saved = 'saved';
  static const deleted = 'deleted';
}

class ProvisionalTransactionRepository {
  Future<int> save(ProvisionalTransaction transaction) async {
    final isar = await IsarService.instance.database;
    return isar.writeTxn(() => isar.provisionalTransactions.put(transaction));
  }

  Future<int?> saveIfNew(ProvisionalTransaction transaction) async {
    final isar = await IsarService.instance.database;
    final sourceKey = transaction.sourceKey;
    final existing = sourceKey == null
        ? await isar.provisionalTransactions
              .filter()
              .smsBodyEqualTo(transaction.smsBody)
              .and()
              .senderEqualTo(transaction.sender)
              .and()
              .smsReceivedAtEqualTo(transaction.smsReceivedAt)
              .findFirst()
        : await isar.provisionalTransactions
              .filter()
              .sourceKeyEqualTo(sourceKey)
              .findFirst();
    if (existing != null) {
      return null;
    }
    return isar.writeTxn(() => isar.provisionalTransactions.put(transaction));
  }

  Future<List<ProvisionalTransaction>> fetchPending() async {
    final isar = await IsarService.instance.database;
    return isar.provisionalTransactions
        .filter()
        .statusEqualTo(ProvisionalTransactionStatus.pending)
        .sortBySmsReceivedAtDesc()
        .findAll();
  }

  Future<int> pendingCount() async {
    final isar = await IsarService.instance.database;
    return isar.provisionalTransactions
        .filter()
        .statusEqualTo(ProvisionalTransactionStatus.pending)
        .count();
  }

  Future<void> delete(int id) async {
    final isar = await IsarService.instance.database;
    await isar.writeTxn(() => isar.provisionalTransactions.delete(id));
  }

  Future<void> removeSaved(int id) async {
    await delete(id);
  }
}
