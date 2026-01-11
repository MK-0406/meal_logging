import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../functions.dart';
import '../main.dart';

class UsersPage extends StatefulWidget {
  const UsersPage({super.key});

  @override
  State<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends State<UsersPage> {
  final CollectionReference users = FirebaseFirestore.instance.collection(
    'users',
  );

  String? _selectedUserId;

  Widget _buildTextField(
    String label,
    TextEditingController controller, {
    bool isNumber = false,
    void Function(String)? onChanged,
  }) {
    return TextFormField(
      controller: controller,
      onChanged: onChanged,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter $label';
        } else if (isNumber) {
          if (double.tryParse(value) == null) {
            return '$label must be a number';
          } else if (double.parse(value) < 0) {
            return '$label must be greater than 0';
          }
        }
        return null;
      },
    );
  }

  void _showUserDialog(Map<String, dynamic>? data) {
    final nameController = TextEditingController();
    final ageController = TextEditingController();
    final heightController = TextEditingController();
    final weightController = TextEditingController();
    final bmiController = TextEditingController();
    final bloodPressureSystolicController = TextEditingController();
    final bloodPressureDiastolicController = TextEditingController();
    final cholesterolLevelController = TextEditingController();
    final bloodSugarLevelController = TextEditingController();

    final formKey = GlobalKey<FormState>();

    String? gender;
    double? bmi;

    String heightUnit = 'cm';
    String weightUnit = 'kg';
    String cholesterolUnit = 'mmol/L';
    String bloodSugarUnit = 'mmol/L';

    double heightM = 0;
    double weightKg = 0;
    double cholesterolMmoll = 0;
    double bloodSugarMmoll = 0;

    void changeUnit() {
      if (double.tryParse(cholesterolLevelController.text) != null) {
        switch (cholesterolUnit) {
          case 'mg/dL':
            cholesterolMmoll =
                double.parse(cholesterolLevelController.text) * 0.02586;
            break;
          case 'mmol/L':
            cholesterolMmoll = double.parse(cholesterolLevelController.text);
            break;
        }
        switch (bloodSugarUnit) {
          case 'mg/dL':
            bloodSugarMmoll =
                double.parse(bloodSugarLevelController.text) * 0.05556;
            break;
          case 'mmol/L':
            bloodSugarMmoll = double.parse(bloodSugarLevelController.text);
            break;
        }
        cholesterolMmoll = double.parse(cholesterolMmoll.toStringAsFixed(1));
        bloodSugarMmoll = double.parse(bloodSugarMmoll.toStringAsFixed(1));
        heightM = double.parse(heightM.toStringAsFixed(1));
        weightKg = double.parse(weightKg.toStringAsFixed(1));
      }
    }

    void onHeightUnitChanged(String changedUnit) {
      final previousUnit = heightUnit;
      if (previousUnit == changedUnit) return;

      double height = double.parse(heightController.text);

      switch (previousUnit) {

        case 'cm':
          switch (changedUnit) {
            case 'm':
              height = height / 100;
              break;
            case 'ft':
              height = height / 30.48;
              break;
          }
          break;

        case 'm':
          switch (changedUnit) {
            case 'cm':
              height = height * 100.roundToDouble();
              break;
            case 'ft':
              height = (height / 0.305);
              break;
          }
          break;

        case 'ft':
          switch (changedUnit) {
            case 'cm':
              height = (height * 30.48).roundToDouble();
              break;
            case 'm':
              height = height * 0.305;
              break;
          }
          break;
      }
      heightController.text = height.toStringAsFixed(2);
      heightUnit = changedUnit;
    }

    void onWeightUnitChanged(String changedUnit) {
      final previousUnit = weightUnit;
      if (previousUnit == changedUnit) return;

      double weight = double.parse(weightController.text);

      switch (previousUnit) {

        case 'kg':
          weight = weight * 2.205;
          break;

        case 'lb':
          weight = weight / 2.205;
          break;
      }
      weightController.text = weight.toStringAsFixed(1);
      weightUnit = changedUnit;
    }

    void onCholesterolUnitChanged(String changedUnit) {
      final previousUnit = cholesterolUnit;
      if (previousUnit == changedUnit) return;

      double cholesterol = double.parse(cholesterolLevelController.text);

      switch (previousUnit) {

        case 'mmol/L':
          cholesterol = cholesterol / 0.02586;
          break;

        case 'mg/dL':
          cholesterol = cholesterol * 0.02586;
          break;
      }
      cholesterolLevelController.text = cholesterol.toStringAsFixed(1);
      cholesterolUnit = changedUnit;
    }

    void onBloodSugarUnitChanged(String changedUnit) {
      final previousUnit = bloodSugarUnit;
      if (previousUnit == changedUnit) return;

      double bloodSugar = double.parse(bloodSugarLevelController.text);

      switch (previousUnit) {

        case 'mmol/L':
          bloodSugar = bloodSugar / 0.05556;
          break;

        case 'mg/dL':
          bloodSugar = bloodSugar * 0.05556;
          break;
      }
      bloodSugarLevelController.text = bloodSugar.toStringAsFixed(1);
      bloodSugarUnit = changedUnit;
    }

    void calculateBMI() {
      final heightValue = double.tryParse(heightController.text);
      final weightValue = double.tryParse(weightController.text);

      if (heightValue == null ||
          weightValue == null ||
          heightValue <= 0 ||
          weightValue <= 0) {
        bmi = null;
        return;
      }

      switch (heightUnit) {
        case 'cm':
          heightM = heightValue / 100;
          break;
        case 'ft':
          heightM = heightValue * 0.3048;
          break;
        case 'm':
          heightM = heightValue;
          break;
      }

      switch (weightUnit) {
        case 'kg':
          weightKg = weightValue;
          break;
        case 'lb':
          weightKg = weightValue * 0.453592;
          break;
      }

      bmi = weightKg / (heightM * heightM);
      bmi = double.parse(bmi!.toStringAsFixed(2));
    }

    void onHeightOrWeightChanged({
      required void Function(void Function()) dialogSetState,
    }) {
      if (!mounted) return;

      calculateBMI();

      if (bmi == null) {
        dialogSetState(() {
          bmiController.text = '';
        });
        return;
      }

      dialogSetState(() {
        bmiController.text = bmi!.toStringAsFixed(2);
      });
    }

    _selectedUserId = data?['id'];
    nameController.text = data?['name'];
    ageController.text = data!['age'].toString();
    gender = data['gender'];

    // Reset units to default
    heightUnit = 'cm';
    weightUnit = 'kg';
    cholesterolUnit = 'mmol/L';
    bloodSugarUnit = 'mmol/L';

    // Initialize variables
    heightM = (data['height_m'] is num) ? data['height_m'].toDouble() : 0.0;
    weightKg = (data['weight_kg'] is num) ? data['weight_kg'].toDouble() : 0.0;
    bmi = (data['bmi'] is num) ? data['bmi'].toDouble() : null;
    cholesterolMmoll = (data['cholesterol_mmolL'] is num)
        ? data['cholesterol_mmolL'].toDouble()
        : 0.0;
    bloodSugarMmoll = (data['bloodSugar_mmolL'] is num)
        ? data['bloodSugar_mmolL'].toDouble()
        : 0.0;

    heightController.text = (heightM * 100).toStringAsFixed(2);
    weightController.text = weightKg.toString();
    bmiController.text = bmi?.toString() ?? '';
    bloodPressureSystolicController.text = data['bloodPressureSystolic']
        .toString();
    bloodPressureDiastolicController.text = data['bloodPressureDiastolic']
        .toString();
    cholesterolLevelController.text = cholesterolMmoll.toString();
    bloodSugarLevelController.text = bloodSugarMmoll.toString();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return Dialog(
            backgroundColor: Color(0xFFE3F2FD),
            insetPadding: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: SizedBox(
              height:
                  MediaQuery.of(context).size.height *
                  0.85, // Fixed height for sticky behavior
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                // This makes it stick
                children: [
                  // Sticky Header
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: lightBlueTheme.colorScheme.tertiary,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(20),
                        topRight: Radius.circular(20),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      'Update User',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: lightBlueTheme.colorScheme.secondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),

                  // Scrollable Content
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Form(
                        key: formKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(height: 20),
                            Text(
                              'Personal Information',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 20),
                            _buildTextField('Name', nameController),
                            const SizedBox(height: 12),

                            Row(
                              children: [
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    initialValue: gender,
                                    items: ['Male', 'Female']
                                        .map(
                                          (e) => DropdownMenuItem(
                                            value: e,
                                            child: Text(e),
                                          ),
                                        )
                                        .toList(),
                                    onChanged: (v) =>
                                        setDialogState(() => gender = v),
                                    decoration: InputDecoration(
                                      labelText: 'Gender', // Fixed label
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    validator: (value) => value == null
                                        ? 'Please select the gender'
                                        : null,
                                  ),
                                ),
                                const SizedBox(width: 15),
                                Expanded(
                                  child: _buildTextField('Age', ageController),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            Row(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: _buildTextField(
                                    'Height',
                                    heightController,
                                    onChanged: (_) => onHeightOrWeightChanged(
                                      dialogSetState: setDialogState,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 15),
                                Expanded(
                                  flex: 2,
                                  child: DropdownButtonFormField<String>(
                                    initialValue: heightUnit,
                                    items: ['cm', 'm', 'ft']
                                        .map(
                                          (e) => DropdownMenuItem(
                                            value: e,
                                            child: Text(e),
                                          ),
                                        )
                                        .toList(),
                                    onChanged: (v) =>
                                        setDialogState(() => onHeightUnitChanged(v!)),
                                    decoration: InputDecoration(
                                      labelText: 'Unit', // Fixed label
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                              ],
                            ),
                            const SizedBox(height: 12),

                            Row(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: _buildTextField(
                                    'Weight',
                                    weightController,
                                    onChanged: (_) => onHeightOrWeightChanged(
                                      dialogSetState: setDialogState,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 15),
                                Expanded(
                                  flex: 2,
                                  child: DropdownButtonFormField<String>(
                                    initialValue: weightUnit,
                                    items: ['kg', 'lb']
                                        .map(
                                          (e) => DropdownMenuItem(
                                            value: e,
                                            child: Text(e),
                                          ),
                                        )
                                        .toList(),
                                    onChanged: (v) =>
                                        setDialogState(() => onWeightUnitChanged(v!)),
                                    decoration: InputDecoration(
                                      labelText: 'Unit', // Fixed label
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                              ],
                            ),
                            const SizedBox(height: 12),

                            TextFormField(
                              controller: bmiController,
                              readOnly: true,
                              decoration: InputDecoration(
                                labelText: 'BMI',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                labelStyle: TextStyle(fontSize: 15),
                                contentPadding: EdgeInsets.symmetric(
                                  vertical: 13,
                                  horizontal: 16,
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),

                            Text(
                              'Health Information',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 20),

                            _buildTextField(
                              'Blood Pressure Systolic',
                              bloodPressureSystolicController,
                              isNumber: true,
                            ),
                            const SizedBox(height: 12),
                            _buildTextField(
                              'Blood Pressure Diastolic',
                              bloodPressureDiastolicController,
                              isNumber: true,
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: _buildTextField(
                                    'Cholesterol Level',
                                    cholesterolLevelController,
                                  ),
                                ),
                                const SizedBox(width: 15),
                                Expanded(
                                  flex: 2,
                                  child: DropdownButtonFormField<String>(
                                    initialValue: cholesterolUnit,
                                    items: ['mg/dL', 'mmol/L']
                                        .map(
                                          (e) => DropdownMenuItem(
                                            value: e,
                                            child: Text(e),
                                          ),
                                        )
                                        .toList(),
                                    onChanged: (v) => setDialogState(
                                      () => onCholesterolUnitChanged(v!),
                                    ),
                                    decoration: InputDecoration(
                                      labelText: 'Unit', // Fixed label
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: _buildTextField(
                                    'Blood Sugar Level',
                                    bloodSugarLevelController,
                                  ),
                                ),
                                const SizedBox(width: 15),
                                Expanded(
                                  flex: 2,
                                  child: DropdownButtonFormField<String>(
                                    initialValue: bloodSugarUnit,
                                    items: ['mg/dL', 'mmol/L']
                                        .map(
                                          (e) => DropdownMenuItem(
                                            value: e,
                                            child: Text(e),
                                          ),
                                        )
                                        .toList(),
                                    onChanged: (v) => setDialogState(
                                      () => onBloodSugarUnitChanged(v!),
                                    ),
                                    decoration: InputDecoration(
                                      labelText: 'Unit', // Fixed label
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 30),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Sticky Footer
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: lightBlueTheme.colorScheme.tertiary,
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(20),
                        bottomRight: Radius.circular(20),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 4,
                          offset: const Offset(0, -2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        TextButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                          },
                          icon: const Icon(Icons.cancel),
                          label: const Text('Cancel'),
                          style: OutlinedButton.styleFrom(
                            //foregroundColor: Colors.deepOrange,
                            side: BorderSide(
                              color: lightBlueTheme.colorScheme.secondary,
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: () async {
                            changeUnit();
                            if (formKey.currentState!.validate()) {
                              await Database.setItems(
                                'usersInfo',
                                _selectedUserId,
                                {
                                  'name': nameController.text.trim(),
                                  'age': int.parse(ageController.text),
                                  'gender': gender,
                                  'height_m': heightM,
                                  'weight_kg': weightKg,
                                  'bmi': bmi,
                                  'bloodPressureSystolic': double.parse(
                                    double.tryParse(
                                      bloodPressureSystolicController.text,
                                    )!.toStringAsFixed(2),
                                  ),
                                  'bloodPressureDiastolic': double.parse(
                                    double.tryParse(
                                      bloodPressureDiastolicController.text,
                                    )!.toStringAsFixed(2),
                                  ),
                                  'cholesterol_mmolL': cholesterolMmoll,
                                  'bloodSugar_mmolL': bloodSugarMmoll,
                                  'createdAt': FieldValue.serverTimestamp(),
                                  'updatedAt': FieldValue.serverTimestamp(),
                                },
                              );
                              if (context.mounted) {
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('User updated successfully'),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              }
                            }
                          },
                          icon: Icon(Icons.update),
                          label: Text('Update'),
                          style: ElevatedButton.styleFrom(
                            //backgroundColor: Colors.deepOrange,
                            //foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _showUserDetails(Map<String, dynamic> data) async {
    final userInfoData = FirebaseFirestore.instance
        .collection('usersInfo')
        .doc(data['id'])
        .snapshots();
    final userInfo = await userInfoData.first.then(
      (value) => value.data() as Map<String, dynamic>,
    );

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Color(0xFFE3F2FD),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          data['email'],
          style: TextStyle(
            color: lightBlueTheme.colorScheme.primary,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Divider(color: lightBlueTheme.colorScheme.primary, thickness: 2),
            const SizedBox(height: 12),
            _buildInfoRow('Name', userInfo['name']),
            _buildInfoRow('Email', data['email']),
            _buildInfoRow('Role', data['role']),
            _buildInfoRow('Gender', userInfo['gender']),
            _buildInfoRow('Age', '${userInfo['age']} years'),
            _buildInfoRow('Height', '${userInfo['height_m']} m'),
            _buildInfoRow('Weight', '${userInfo['weight_kg']} kg'),
            _buildInfoRow('BMI', '${userInfo['bmi']} kg/m²'),
            _buildInfoRow(
              'Blood Pressure',
              '${userInfo['bloodPressureDiastolic']}/${userInfo['bloodPressureSystolic']} mmHg',
            ),
            _buildInfoRow(
              'Blood Sugar',
              '${userInfo['bloodSugar_mmolL']} mmol/L',
            ),
            _buildInfoRow(
              'Cholesterol',
              '${userInfo['cholesterol_mmolL']} mmol/L',
            ),
            _buildInfoRow(
              'Status',
              (userInfo['ban'] == true) ? 'Banned' : 'Not Banned',
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            icon: Icon(Icons.edit, color: lightBlueTheme.colorScheme.primary),
            label: Text(
              'Edit',
              style: TextStyle(color: lightBlueTheme.colorScheme.primary),
            ),
            onPressed: () {
              Navigator.pop(context);
              _showUserDialog({...data, ...userInfo});
            },
          ),
          TextButton.icon(
            icon: const Icon(Icons.block_outlined, color: Colors.red),
            label: const Text('Ban/Unban', style: TextStyle(color: Colors.red)),
            onPressed: () async {
              await Database.setItems(
                'usersInfo',
                data['id'],
                {
                  'ban': (userInfo['ban'] == true) ? false : true,
                  'updatedAt': FieldValue.serverTimestamp(),
                },
              );
              if (context.mounted) Navigator.pop(context);
            },
          ),
          TextButton(
            child: const Text('Close', style: TextStyle(color: Colors.grey)),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text(
          'Manage Users',
          style: TextStyle(
            color: lightBlueTheme.colorScheme.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: lightBlueTheme.colorScheme.tertiary,
        automaticallyImplyLeading: false,
      ),
      /*floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showMealDialog(isEditing: false),
        backgroundColor: lightBlueTheme.colorScheme.secondary,
        icon: const Icon(Icons.add),
        label: const Text('Add Meal'),
      ),*/
      body: StreamBuilder<QuerySnapshot>(
        stream: users.orderBy('email').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Error loading users'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(
                color: lightBlueTheme.colorScheme.primary,
              ),
            );
          }

          final data = snapshot.data!.docs.map((doc) {
            final user = doc.data() as Map<String, dynamic>;
            user['id'] = doc.id;
            return user;
          }).toList();

          if (data.isEmpty) {
            return const Center(child: Text('No users found.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: data.length,
            itemBuilder: (context, index) {
              final user = data[index];
              return Card(
                elevation: 5,
                margin: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: ListTile(
                  title: Text(
                    user['email'],
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text('${user['role']}'),
                  trailing: Icon(
                    Icons.keyboard_arrow_right,
                    color: lightBlueTheme.colorScheme.secondary,
                  ),
                  onTap: () => _showUserDetails(user),
                ),
              );
            },
          );
        },
      ),
    );
  }

  /// Helper UI widgets
  Widget _buildInfoRow(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          Text(': ${value ?? '-'}', style: const TextStyle(fontSize: 16)),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
