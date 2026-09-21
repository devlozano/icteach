import 'workspace_data.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'learning_path_service.dart';
import '../models/module_model.dart';

class ModuleService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get modules for a specific class (with ordering in memory)
  Stream<List<ModuleModel>> getModulesForClass(String classId) {
    return WorkspaceData.watch(
      'modules/$classId',
      () => _firestore
          .collection('classes')
          .doc(classId)
          .collection('modules')
          .snapshots()
          .map((snapshot) {
            final modules = snapshot.docs
                .map((doc) => ModuleModel.fromFirestore(doc))
                .toList();
            // Sort in memory by 'order' field
            modules.sort((a, b) => a.order.compareTo(b.order));
            return modules;
          }),
    );
  }

  // Get published modules for students (with ordering in memory)
  Stream<List<ModuleModel>> getPublishedModulesForClass(String classId) {
    return WorkspaceData.watch(
      'publishedModules/$classId',
      () => _firestore
          .collection('classes')
          .doc(classId)
          .collection('modules')
          .where('isPublished', isEqualTo: true)
          .snapshots()
          .map((snapshot) {
            final modules = snapshot.docs
                .map((doc) => ModuleModel.fromFirestore(doc))
                .toList();
            // Sort in memory by 'order' field
            modules.sort((a, b) => a.order.compareTo(b.order));
            return modules;
          }),
    );
  }

  // Create a new module
  Future<void> createModule(ModuleModel module) async {
    await LearningPathService.requireActive(module.classId);
    try {
      final docRef = _firestore
          .collection('classes')
          .doc(module.classId)
          .collection('modules')
          .doc();

      final data = module.toFirestore();
      data['id'] = docRef.id;
      data['createdAt'] = FieldValue.serverTimestamp();
      data['updatedAt'] = FieldValue.serverTimestamp();

      await docRef.set(data);
      print('✅ Module created: ${module.title}');
    } catch (e) {
      print('❌ Error creating module: $e');
      rethrow;
    }
  }

  // ✅ FIXED: Update an existing module
  Future<void> updateModule(
    String classId,
    String moduleId,
    ModuleModel module,
  ) async {
    await LearningPathService.requireActive(classId);
    try {
      final data = module.toFirestore();
      data['updatedAt'] = FieldValue.serverTimestamp();

      await _firestore
          .collection('classes')
          .doc(classId)
          .collection('modules')
          .doc(moduleId)
          .update(data);
      print('✅ Module updated: ${module.title}');
    } catch (e) {
      print('❌ Error updating module: $e');
      rethrow;
    }
  }

  // Delete a module
  Future<void> deleteModule(String classId, String moduleId) async {
    await LearningPathService.requireActive(classId);
    try {
      await _firestore
          .collection('classes')
          .doc(classId)
          .collection('modules')
          .doc(moduleId)
          .delete();
      print('✅ Module deleted: $moduleId');
    } catch (e) {
      print('❌ Error deleting module: $e');
      rethrow;
    }
  }

  // Get a single module by ID
  Future<ModuleModel?> getModule(String classId, String moduleId) async {
    try {
      final doc = await _firestore
          .collection('classes')
          .doc(classId)
          .collection('modules')
          .doc(moduleId)
          .get();

      if (doc.exists) {
        return ModuleModel.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      print('❌ Error getting module: $e');
      return null;
    }
  }

  // Toggle publish status
  Future<void> togglePublish(
    String classId,
    String moduleId,
    bool isPublished,
  ) async {
    await LearningPathService.requireActive(classId);
    try {
      await _firestore
          .collection('classes')
          .doc(classId)
          .collection('modules')
          .doc(moduleId)
          .update({
            'isPublished': isPublished,
            'updatedAt': FieldValue.serverTimestamp(),
          });
      print('✅ Module publish toggled: $moduleId -> $isPublished');
    } catch (e) {
      print('❌ Error toggling publish: $e');
      rethrow;
    }
  }

  // Get module count for a class
  Future<int> getModuleCount(String classId) async {
    try {
      final snapshot = await _firestore
          .collection('classes')
          .doc(classId)
          .collection('modules')
          .count()
          .get();
      return snapshot.count ?? 0;
    } catch (e) {
      print('❌ Error getting module count: $e');
      return 0;
    }
  }

  // Reorder modules
  Future<void> reorderModules(String classId, List<String> moduleIds) async {
    try {
      final batch = _firestore.batch();

      for (int i = 0; i < moduleIds.length; i++) {
        final ref = _firestore
            .collection('classes')
            .doc(classId)
            .collection('modules')
            .doc(moduleIds[i]);
        batch.update(ref, {
          'order': i,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
      print('✅ Modules reordered: ${moduleIds.length} modules');
    } catch (e) {
      print('❌ Error reordering modules: $e');
      rethrow;
    }
  }

  // Get modules by competency
  Stream<List<ModuleModel>> getModulesByCompetency(
    String classId,
    String competency,
  ) {
    return _firestore
        .collection('classes')
        .doc(classId)
        .collection('modules')
        .where('competencies', arrayContains: competency)
        .where('isPublished', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
          final modules = snapshot.docs
              .map((doc) => ModuleModel.fromFirestore(doc))
              .toList();
          modules.sort((a, b) => a.order.compareTo(b.order));
          return modules;
        });
  }

  // Get module with video only
  Stream<List<ModuleModel>> getModulesWithVideo(String classId) {
    return _firestore
        .collection('classes')
        .doc(classId)
        .collection('modules')
        .where('isPublished', isEqualTo: true)
        .where('videoUrl', isNotEqualTo: null)
        .where('videoUrl', isNotEqualTo: '')
        .snapshots()
        .map((snapshot) {
          final modules = snapshot.docs
              .map((doc) => ModuleModel.fromFirestore(doc))
              .toList();
          modules.sort((a, b) => a.order.compareTo(b.order));
          return modules;
        });
  }
}
