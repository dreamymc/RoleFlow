import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import '../services/auth_service.dart';
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
                    Row(
                      children: [
                        const Text('Color:'),
                        const Spacer(),
                        GestureDetector(
                          onTap: () {
                            showDialog(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('Pick a color'),
                                content: BlockPicker(
                                  pickerColor: newRoleColor,
                                  onColorChanged: (color) {
                                    setStateDialog(() => newRoleColor = color);
                                    Navigator.pop(ctx);
                                  },
                                ),
                              ),
                            );
                          },
                          child: CircleAvatar(backgroundColor: newRoleColor),
                        ),
                      ],
                    ),
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

  // --- DELETE ROLE LOGIC ---
  void _deleteRole(String roleId, String roleName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Role?'),
        content: Text(
          'Are you sure you want to delete "$roleName"?\nThis will delete all tasks and routines inside it.',
        ),
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

  // --- LOGOUT CONFIRMATION LOGIC (NEW) ---
  void _confirmSignOut() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Log Out'),
        content: const Text('Are you sure you want to log out of RoleFlow?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context), // Close dialog
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context); // Close dialog
              await AuthService().signOut(); // Actually sign out
            },
            style: FilledButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            child: const Text('Log Out'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final String? photoURL = user?.photoURL;
    final String name = user?.displayName ?? 'RoleFlow User';

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA), // Cleaner background
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddRoleDialog,
        backgroundColor: Colors.black87,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text("New Role", style: TextStyle(color: Colors.white)),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              // --- HEADER (Updated Layout with Confirm Logout) ---
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Photo + Greeting Group
                  Row(
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
                          Text(
                            'Welcome back,',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                          Text(
                            name,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  // Dedicated Logout Button (Now with Confirmation)
                  IconButton(
                    onPressed: _confirmSignOut, // Calls the dialog now!
                    icon: const Icon(Icons.logout, color: Colors.grey),
                    tooltip: "Logout",
                  ),
                ],
              ),

              const SizedBox(height: 30),
              const Text(
                'Your Dashboard',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black54,
                ),
              ),
              const SizedBox(height: 16),

              // --- GRID OF ROLES ---
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('users')
                      .doc(user!.uid)
                      .collection('roles')
                      .orderBy('createdAt', descending: false)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError)
                      return const Center(child: Text('Error loading roles'));
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final docs = snapshot.data!.docs;

                    if (docs.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.dashboard_customize,
                              size: 60,
                              color: Colors.grey[300],
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              "No roles yet. Create your first one!",
                              style: TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      );
                    }

                    return GridView.builder(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                            childAspectRatio: 0.85,
                          ),
                      itemCount: docs.length,
                      itemBuilder: (context, index) {
                        final role = Role.fromFirestore(
                          docs[index].data() as Map<String, dynamic>,
                          docs[index].id,
                        );

                        return _RoleGridCard(
                          role: role,
                          onLongPress: () => _deleteRole(role.id, role.name),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------
// HELPER: The "Mini-HUD" Card
// ------------------------------------------------------
class _RoleGridCard extends StatelessWidget {
  final Role role;
  final VoidCallback onLongPress;

  const _RoleGridCard({required this.role, required this.onLongPress});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return GestureDetector(
      onLongPress: onLongPress,
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => RoleDetailScreen(role: role)),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: role.color.withOpacity(0.1), // Colored Shadow
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon Circle & Menu Dots
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: role.color.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.layers, color: role.color, size: 20),
                  ),
                  Icon(Icons.more_horiz, color: Colors.grey[300], size: 20),
                ],
              ),

              const Spacer(),

              // Role Name
              Text(
                role.name,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  height: 1.2,
                  letterSpacing: -0.5,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 16),

              // --- LIVE STATS ROW ---
              Row(
                children: [
                  // 1. TASK STAT (Pending)
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
                      builder: (context, snapshot) {
                        int count = snapshot.hasData
                            ? snapshot.data!.docs.length
                            : 0;
                        return _StatPill(
                          count: count,
                          icon: Icons.check_circle_outline,
                          label: "Tasks",
                          color: Colors.grey[700]!,
                        );
                      },
                    ),
                  ),

                  const SizedBox(width: 8),

                  // 2. ROUTINE STAT (Total)
                  Expanded(
                    child: StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('users')
                          .doc(user!.uid)
                          .collection('roles')
                          .doc(role.id)
                          .collection('routines')
                          .snapshots(),
                      builder: (context, snapshot) {
                        int count = snapshot.hasData
                            ? snapshot.data!.docs.length
                            : 0;
                        return _StatPill(
                          count: count,
                          icon: Icons.repeat,
                          label: "Habits",
                          color: role.color, // Colored to pop
                        );
                      },
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
// HELPER: The "Stat Pill"
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
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(height: 4),
          Text(
            "$count",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: color.withOpacity(0.8),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
