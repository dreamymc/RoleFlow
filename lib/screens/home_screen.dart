import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:image_picker/image_picker.dart';
import '../services/auth_service.dart';
import '../services/cloudinary_service.dart';
import '../models/role.dart';
import 'role_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // --- ADD ROLE LOGIC ---
  void _showAddRoleDialog() {
    String newRoleName = '';
    Color newRoleColor = Colors.blue;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Add New Role'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      decoration: const InputDecoration(
                        labelText: 'Role Name',
                        hintText: 'e.g., Side Hustle',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (val) => newRoleName = val,
                    ),
                    const SizedBox(height: 16),
                    // Use the simple color row for quick add
                    _buildProColorRow(context, "Role Color", newRoleColor, (c) {
                      setStateDialog(() => newRoleColor = c);
                    }),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () async {
                    if (newRoleName.trim().isEmpty) return;

                    final user = FirebaseAuth.instance.currentUser;
                    if (user != null) {
                      await FirebaseFirestore.instance
                          .collection('users')
                          .doc(user.uid)
                          .collection('roles')
                          .add({
                            'name': newRoleName.trim(),
                            'color': newRoleColor.value,
                            'createdAt': FieldValue.serverTimestamp(),
                          });
                    }
                    if (mounted) Navigator.pop(context);
                  },
                  child: const Text('Add'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // --- EDIT ROLE LOGIC ---
  void _showEditRoleDialog(Role role) {
    String editName = role.name;
    Color editColor = role.color;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Edit Role'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: TextEditingController(text: editName),
                      decoration: const InputDecoration(
                        labelText: 'Role Name',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (val) => editName = val,
                    ),
                    const SizedBox(height: 16),
                    _buildProColorRow(context, "Role Color", editColor, (c) {
                      setStateDialog(() => editColor = c);
                    }),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () async {
                    final user = FirebaseAuth.instance.currentUser;
                    if (user != null) {
                      await FirebaseFirestore.instance
                          .collection('users')
                          .doc(user.uid)
                          .collection('roles')
                          .doc(role.id)
                          .update({
                            'name': editName.trim(),
                            'color': editColor.value,
                          });
                    }
                    if (mounted) Navigator.pop(context);
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // --- DELETE ROLE LOGIC ---
  void _deleteRole(String roleId, String roleName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Role?'),
        content: Text('Are you sure you want to delete "$roleName"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final user = FirebaseAuth.instance.currentUser;
              if (user != null) {
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(user.uid)
                    .collection('roles')
                    .doc(roleId)
                    .delete();
              }
              if (mounted) Navigator.pop(context);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // --- THE PROFILE STUDIO SHEET (UPGRADED) ---
  void _showProfileStudio(User user, Map<String, dynamic> userData) {
    // 1. SETUP TEMPORARY STATE (Changes live here until you click Save)
    final nameCtrl = TextEditingController(
      text: userData['displayName'] ?? user.displayName ?? '',
    );
    final greetingCtrl = TextEditingController(
      text: userData['greeting'] ?? 'Welcome back,',
    );

    // Colors
    Color tempBgColor = Color(userData['backgroundColor'] ?? 0xFFF5F7FA);
    Color tempTextColor = Color(
      userData['textColor'] ?? 0xFF000000,
    ); // Default to Black

    // Photo
    String? currentPhotoURL =
        userData['photoURL'] ?? user.photoURL; // What's in DB
    String? newUploadedURL; // What we just uploaded (but haven't saved yet)

    bool isUploading = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            // Helper to decide which photo to show PREVIEW of
            final ImageProvider? bgImage;
            if (newUploadedURL != null) {
              bgImage = NetworkImage(newUploadedURL!);
            } else if (currentPhotoURL != null) {
              bgImage = NetworkImage(currentPhotoURL!);
            } else {
              bgImage = null;
            }

            return Padding(
              padding: EdgeInsets.fromLTRB(
                24,
                24,
                24,
                MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Profile Studio",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),

                  // 1. AVATAR UPLOADER (NOW DELAYED SAVE)
                  Center(
                    child: GestureDetector(
                      onTap: () async {
                        final picker = ImagePicker();
                        final XFile? image = await picker.pickImage(
                          source: ImageSource.gallery,
                        );

                        if (image != null) {
                          setSheetState(() => isUploading = true);
                          // Upload to Cloudinary, but ONLY get the URL back. Don't save to DB yet.
                          String? url = await CloudinaryService().uploadImage(
                            File(image.path),
                          );

                          if (url != null) {
                            setSheetState(() {
                              newUploadedURL = url; // Store in temp variable
                              isUploading = false;
                            });
                          } else {
                            setSheetState(() => isUploading = false);
                          }
                        }
                      },
                      child: Stack(
                        children: [
                          CircleAvatar(
                            radius: 50,
                            backgroundColor: Colors.grey[200],
                            backgroundImage: bgImage,
                            child: isUploading
                                ? const CircularProgressIndicator()
                                : (bgImage == null
                                      ? const Icon(
                                          Icons.person,
                                          size: 50,
                                          color: Colors.grey,
                                        )
                                      : null),
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: const BoxDecoration(
                                color: Colors.black,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.camera_alt,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 2. IDENTITY
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: "Display Name",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: greetingCtrl,
                    decoration: const InputDecoration(
                      labelText: "Greeting Message",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 3. PRO COLOR PICKERS
                  const Text(
                    "Theme Customization",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),

                  // Background Color
                  _buildProColorRow(context, "Background", tempBgColor, (c) {
                    setSheetState(() => tempBgColor = c);
                  }),
                  const SizedBox(height: 12),

                  // Text Color
                  _buildProColorRow(context, "Text Color", tempTextColor, (c) {
                    setSheetState(() => tempTextColor = c);
                  }),

                  const SizedBox(height: 32),

                  // 4. MAIN SAVE BUTTON
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: FilledButton(
                      onPressed: () async {
                        // THIS IS THE MOMENT WE SAVE EVERYTHING

                        Map<String, dynamic> updateData = {
                          'displayName': nameCtrl.text.trim(),
                          'greeting': greetingCtrl.text.trim(),
                          'backgroundColor': tempBgColor.value,
                          'textColor': tempTextColor.value,
                        };

                        // Only update photo if a new one was uploaded
                        if (newUploadedURL != null) {
                          updateData['photoURL'] = newUploadedURL;
                          await user.updatePhotoURL(newUploadedURL);
                        }

                        // Save to Firestore (Merge to create if missing)
                        await FirebaseFirestore.instance
                            .collection('users')
                            .doc(user.uid)
                            .set(updateData, SetOptions(merge: true));

                        // Update Auth Display Name
                        await user.updateDisplayName(nameCtrl.text.trim());

                        if (mounted) Navigator.pop(context);
                      },
                      child: const Text("Save Changes"),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // --- HELPER: PRO COLOR PICKER (WHEEL + RGB SLIDERS) ---
  Widget _buildProColorRow(
    BuildContext context,
    String label,
    Color currentColor,
    Function(Color) onColorChanged,
  ) {
    return Row(
      children: [
        Text(label, style: const TextStyle(fontSize: 16)),
        const Spacer(),
        GestureDetector(
          onTap: () {
            showDialog(
              context: context,
              builder: (ctx) {
                // Initialize local state for the dialog
                Color pickerColor = currentColor;

                return AlertDialog(
                  contentPadding: const EdgeInsets.all(0),
                  // SizedBox to control height of the TabBarView
                  content: SizedBox(
                    width: 340,
                    height: 450,
                    child: DefaultTabController(
                      length: 2,
                      child: StatefulBuilder(
                        builder: (context, setDialogState) {
                          return Column(
                            children: [
                              const TabBar(
                                labelColor: Colors.black,
                                unselectedLabelColor: Colors.grey,
                                indicatorColor: Colors.black,
                                tabs: [
                                  Tab(text: "Visual Wheel"),
                                  Tab(text: "RGB Inputs"),
                                ],
                              ),
                              Expanded(
                                child: TabBarView(
                                  children: [
                                    // TAB 1: THE DRAGGABLE WHEEL + HEX
                                    SingleChildScrollView(
                                      child: Padding(
                                        padding: const EdgeInsets.only(
                                          top: 16.0,
                                        ),
                                        child: ColorPicker(
                                          pickerColor: pickerColor,
                                          onColorChanged: (c) => setDialogState(
                                            () => pickerColor = c,
                                          ),
                                          enableAlpha: false,
                                          displayThumbColor: true,
                                          hexInputBar: true, // Hex is Editable
                                          paletteType: PaletteType.hsvWithHue,
                                          labelTypes:
                                              const [], // Hide text here to keep it clean
                                        ),
                                      ),
                                    ),
                                    // TAB 2: THE RGB SLIDERS + TEXT FIELDS
                                    Padding(
                                      padding: const EdgeInsets.all(24.0),
                                      child: SlidePicker(
                                        pickerColor: pickerColor,
                                        onColorChanged: (c) => setDialogState(
                                          () => pickerColor = c,
                                        ),
                                        enableAlpha: false,
                                        displayThumbColor: true,
                                        showLabel: true, // Shows R: 255
                                        showIndicator: true,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                  actions: [
                    TextButton(
                      child: const Text('Cancel'),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                    FilledButton(
                      child: const Text('Select'),
                      onPressed: () {
                        onColorChanged(pickerColor);
                        Navigator.pop(ctx);
                      },
                    ),
                  ],
                );
              },
            );
          },
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: currentColor,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.grey.shade300),
            ),
          ),
        ),
      ],
    );
  }

  // --- LOGOUT CONFIRMATION ---
  void _confirmSignOut() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Log Out'),
        content: const Text('Are you sure you want to log out of RoleFlow?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              await AuthService().signOut();
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Log Out'),
          ),
        ],
      ),
    );
  }

  // --- BUILD METHOD ---
  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .snapshots(),
      builder: (context, snapshot) {
        Map<String, dynamic> userData = {};
        if (snapshot.hasData && snapshot.data!.data() != null) {
          userData = snapshot.data!.data() as Map<String, dynamic>;
        }

        final bgColor = Color(userData['backgroundColor'] ?? 0xFFF5F7FA);
        final textColor = Color(
          userData['textColor'] ?? 0xFF000000,
        ); // READ TEXT COLOR

        final displayName =
            userData['displayName'] ?? user.displayName ?? 'RoleFlow User';
        final photoURL = userData['photoURL'] ?? user.photoURL;
        final greeting = userData['greeting'] ?? 'Welcome back,';

        return Scaffold(
          resizeToAvoidBottomInset: false,
          backgroundColor: bgColor,
          floatingActionButton: FloatingActionButton.extended(
            onPressed: _showAddRoleDialog,
            backgroundColor: Colors.black87,
            icon: const Icon(Icons.add, color: Colors.white),
            label: const Text(
              "New Role",
              style: TextStyle(color: Colors.white),
            ),
          ),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),
                  // --- HEADER ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      GestureDetector(
                        onTap: () => _showProfileStudio(user, userData),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 24,
                              backgroundColor: Colors.grey[200],
                              backgroundImage: photoURL != null
                                  ? NetworkImage(photoURL)
                                  : null,
                              child: photoURL == null
                                  ? const Icon(Icons.person, color: Colors.grey)
                                  : null,
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // APPLY TEXT COLOR HERE
                                Text(
                                  greeting,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: textColor.withOpacity(0.7),
                                  ),
                                ),
                                Text(
                                  displayName,
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                    color: textColor,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: _confirmSignOut,
                        icon: Icon(
                          Icons.logout,
                          color: textColor.withOpacity(0.5),
                        ),
                        tooltip: "Logout",
                      ),
                    ],
                  ),

                  const SizedBox(height: 30),
                  Text(
                    'Your Dashboard',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: textColor.withOpacity(0.8),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // --- DYNAMIC ROLES AREA ---
                  Expanded(
                    child: StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('users')
                          .doc(user.uid)
                          .collection('roles')
                          .orderBy('createdAt', descending: false)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.hasError)
                          return const Center(
                            child: Text('Error loading roles'),
                          );
                        if (snapshot.connectionState == ConnectionState.waiting)
                          return const Center(
                            child: CircularProgressIndicator(),
                          );

                        final docs = snapshot.data!.docs;
                        if (docs.isEmpty)
                          return Center(
                            child: Text(
                              "No roles yet.",
                              style: TextStyle(
                                color: textColor.withOpacity(0.6),
                              ),
                            ),
                          );

                        return _buildDynamicLayout(docs);
                      },
                    ),
                  ),
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // --- DYNAMIC LAYOUT (Helper) ---
  Widget _buildDynamicLayout(List<QueryDocumentSnapshot> docs) {
    int count = docs.length;
    Role getRole(int index) => Role.fromFirestore(
      docs[index].data() as Map<String, dynamic>,
      docs[index].id,
    );

    Widget buildCard(int index) {
      final role = getRole(index);
      return _RoleGridCard(
        role: role,
        onMenuPressed: () {
          showModalBottomSheet(
            context: context,
            builder: (ctx) => Wrap(
              children: [
                ListTile(
                  leading: const Icon(Icons.edit, color: Colors.blue),
                  title: const Text('Edit Role'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showEditRoleDialog(role);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.delete, color: Colors.red),
                  title: const Text('Delete Role'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _deleteRole(role.id, role.name);
                  },
                ),
              ],
            ),
          );
        },
      );
    }

    if (count == 1) return Column(children: [Expanded(child: buildCard(0))]);
    if (count == 2)
      return Column(
        children: [
          Expanded(child: buildCard(0)),
          const SizedBox(height: 16),
          Expanded(child: buildCard(1)),
        ],
      );
    if (count == 3)
      return Column(
        children: [
          Expanded(flex: 4, child: buildCard(0)),
          const SizedBox(height: 16),
          Expanded(
            flex: 5,
            child: Row(
              children: [
                Expanded(child: buildCard(1)),
                const SizedBox(width: 16),
                Expanded(child: buildCard(2)),
              ],
            ),
          ),
        ],
      );
    if (count == 4)
      return Column(
        children: [
          Expanded(
            child: Row(
              children: [
                Expanded(child: buildCard(0)),
                const SizedBox(width: 16),
                Expanded(child: buildCard(1)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Row(
              children: [
                Expanded(child: buildCard(2)),
                const SizedBox(width: 16),
                Expanded(child: buildCard(3)),
              ],
            ),
          ),
        ],
      );

    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.85,
      ),
      itemCount: count,
      itemBuilder: (context, index) => buildCard(index),
    );
  }
}

// ------------------------------------------------------
// HELPER: The Card Widget (Compact Fix)
// ------------------------------------------------------
class _RoleGridCard extends StatelessWidget {
  final Role role;
  final VoidCallback onMenuPressed;

  const _RoleGridCard({required this.role, required this.onMenuPressed});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return GestureDetector(
      onLongPress: onMenuPressed,
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => RoleDetailScreen(role: role)),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: role.color.withOpacity(0.1),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        // FIX 1: Reduce padding from 20 to 16 to save vertical space
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(
                      10,
                    ), // Slightly smaller icon padding
                    decoration: BoxDecoration(
                      color: role.color.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.layers, color: role.color, size: 22),
                  ),
                  GestureDetector(
                    onTap: onMenuPressed,
                    child: Icon(
                      Icons.more_horiz,
                      color: Colors.grey[300],
                      size: 24,
                    ),
                  ),
                ],
              ),

              const Spacer(), // Pushes content to edges, but collapses if space is tight
              // Role Name
              Text(
                role.name,
                style: const TextStyle(
                  fontSize: 20, // Reduced from 22 to 20
                  fontWeight: FontWeight.w800,
                  height: 1.1,
                  letterSpacing: -0.5,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),

              // FIX 2: Reduce gap from 20 to 12
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('users')
                          .doc(user!.uid)
                          .collection('roles')
                          .doc(role.id)
                          .collection('tasks')
                          .where('isCompleted', isEqualTo: false)
                          .snapshots(),
                      builder: (context, snapshot) => _StatPill(
                        count: snapshot.hasData
                            ? snapshot.data!.docs.length
                            : 0,
                        icon: Icons.check_circle_outline,
                        label: "Tasks",
                        color: Colors.grey[700]!,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('users')
                          .doc(user!.uid)
                          .collection('roles')
                          .doc(role.id)
                          .collection('routines')
                          .snapshots(),
                      builder: (context, snapshot) => _StatPill(
                        count: snapshot.hasData
                            ? snapshot.data!.docs.length
                            : 0,
                        icon: Icons.repeat,
                        label: "Habits",
                        color: role.color,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------
// HELPER: The "Stat Pill" (Tightened for Overflow Fix)
// ------------------------------------------------------
class _StatPill extends StatelessWidget {
  final int count;
  final IconData icon;
  final String label;
  final Color color;
  const _StatPill({
    required this.count,
    required this.icon,
    required this.label,
    required this.color,
  });
  @override
  Widget build(BuildContext context) {
    return Container(
      // REDUCED VERTICAL PADDING FROM 10 TO 8
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // REDUCED ICON SIZE FROM 18 TO 16
          Icon(icon, size: 16, color: color),
          const SizedBox(height: 4), // Reduced from 6 to 4
          Text(
            "$count",
            // REDUCED FONT SIZE FROM 18 TO 16
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: color.withOpacity(0.8),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
