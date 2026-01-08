import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class Database {

  /// Add items
  static Future<void> addItems(String collectionName, Map<String, dynamic> data) async {
    try{
      CollectionReference collectionRef =
      FirebaseFirestore.instance.collection(collectionName);
      await collectionRef.add(data);
    } catch(e){
      print('Error adding item in collection $collectionName: $e');
    }
  }

  /// Set items
  static Future<void> setItems(String collectionName, String? documentId, Map<String, dynamic> data) async {
    try {
      documentId = documentId ?? FirebaseAuth.instance.currentUser!.uid;

      CollectionReference collectionRef =
      FirebaseFirestore.instance.collection(collectionName);
      await collectionRef.doc(documentId).set(data);
    } catch(e){
      print('Error setting item in collection $collectionName: $e');
    }
  }

  /// Update items
  static Future<void> updateItems(String collectionName, String documentId, Map<String, dynamic> data) async {
    try {
      CollectionReference collectionRef =
      FirebaseFirestore.instance.collection(collectionName);
      await collectionRef.doc(documentId).update(data);
    } catch(e){
      print('Error updating item in collection $collectionName: $e');
    }
  }

  /// Delete items
  static Future<void> deleteItems(String collectionName, String documentId) async {
    try {
      CollectionReference collectionRef =
      FirebaseFirestore.instance.collection(collectionName);
      await collectionRef.doc(documentId).delete();
    } catch(e){
      print('Error deleting item in collection $collectionName: $e');
    }
  }

  /// Get Snapshot with order
  static Future<QuerySnapshot> getSnapshotOrder(String collectionName, String orderBy) async {
    try {
      CollectionReference collectionRef =
      FirebaseFirestore.instance.collection(collectionName);
      QuerySnapshot snapshot = await collectionRef.orderBy(orderBy).get();
      return snapshot;
    } catch(e){
      print('Error getting snapshot in collection $collectionName: $e');
      rethrow;
    }
  }

  /// Get Snapshot with order
  static Future<QuerySnapshot> getSnapshotNoOrder(String collectionName) async {
    try {
      CollectionReference collectionRef =
      FirebaseFirestore.instance.collection(collectionName);
      QuerySnapshot snapshot = await collectionRef.get();
      return snapshot;
    } catch(e){
      print('Error getting snapshot in collection $collectionName: $e');
      rethrow;
    }
  }

  /// Get Document
  static Future<DocumentSnapshot> getDocument(String collectionName, String? documentId) async {
    try {
      documentId = documentId ?? FirebaseAuth.instance.currentUser!.uid;

      CollectionReference collectionRef =
      FirebaseFirestore.instance.collection(collectionName);
      DocumentSnapshot document = await collectionRef.doc(documentId).get();
      return document;
    } catch (e) {
      print('Error getting document in collection $collectionName: $e');
      rethrow;
    }
  }

  /// Stream Snapshot
  static Stream<QuerySnapshot> streamSnapshot(String collectionName, String orderBy) {
    try {
      CollectionReference collectionRef =
      FirebaseFirestore.instance.collection(collectionName);
      return collectionRef.orderBy(orderBy).snapshots();
    } catch(e){
      print('Error streaming snapshot in collection $collectionName: $e');
      rethrow;
    }
  }

  /// Generic query method
  static Future<List<Map<String, dynamic>>> getItemsWithConditions(
      String collectionName,
      String userIDColumnName, {
        required Map<String, dynamic> conditions,
      }) async {
    try {
      Query query = FirebaseFirestore.instance.collection(collectionName)
          .where(userIDColumnName, isEqualTo: FirebaseAuth.instance.currentUser!.uid);

      // Apply all conditions dynamically
      conditions.forEach((field, value) {
        query = query.where(field, isEqualTo: value);
      });

      QuerySnapshot querySnapshot = await query.get();

      // Convert to a list of maps
      List<Map<String, dynamic>> items = querySnapshot.docs
          .map((doc) => {'id': doc.id, ...doc.data() as Map<String, dynamic>})
          .toList();

      return items;
    } catch (e) {
      print('Error fetching items: $e');
      return [];
    }
  }

}