import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class RoleService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<bool> isCliente(String userId) async {
    final clientDoc = await _firestore.collection('cliente').doc(userId).get();
    return clientDoc.exists;
  }
}
