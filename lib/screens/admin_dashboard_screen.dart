import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // Add this to pubspec.yaml for date formatting if needed, or remove formatting
import 'login_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  // Statistics State
  int _userCount = 0;
  int _roleCount = 0;
  int _totalTaskCount = 0;
  int _pendingTaskCount = 0; // New Metric
  int _routineCount = 0;

  // Derived Metrics
  double _avgRolesPerUser = 0.0;
  double _taskCompletionRate = 0.0;

  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";

  @override
  void initState() {
    super.initState();
    _fetchEnhancedStats();
  }

  // --- THE INTELLIGENCE ENGINE ---
  Future<void> _fetchEnhancedStats() async {
    setState(() => _isLoading = true);

    try {
      final firestore = FirebaseFirestore.instance;

      // 1. Parallel Execution for Speed
      final results = await Future.wait([
        firestore.collection('users').count().get(),
        firestore.collectionGroup('roles').count().get(),
        firestore.collectionGroup('tasks').count().get(),
        // Get specifically PENDING tasks for the ratio
        firestore
            .collectionGroup('tasks')
            .where('isCompleted', isEqualTo: false)
            .count()
            .get(),
        firestore.collectionGroup('routines').count().get(),
      ]);

      final userCount = results[0].count ?? 0;
      final roleCount = results[1].count ?? 0;
      final totalTasks = results[2].count ?? 0;
      final pendingTasks = results[3].count ?? 0;
      final routineCount = results[4].count ?? 0;

      if (mounted) {
        setState(() {
          _userCount = userCount;
          _roleCount = roleCount;
          _totalTaskCount = totalTasks;
          _pendingTaskCount = pendingTasks;
          _routineCount = routineCount;

          // Calculate Intelligence Metrics
          if (_userCount > 0) {
            _avgRolesPerUser = _roleCount / _userCount;
          }

          if (_totalTaskCount > 0) {
            _taskCompletionRate =
                (_totalTaskCount - _pendingTaskCount) / _totalTaskCount;
          } else {
            _taskCompletionRate = 0.0;
          }

          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Admin Stats Error: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _handleLogout() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Formatting currency/numbers
    final numberFormat = NumberFormat.compact();

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9), // Enterprise Grey-White
      body: _isLoading
          ? _buildLoadingSkeleton()
          : RefreshIndicator(
              onRefresh: _fetchEnhancedStats,
              child: CustomScrollView(
                slivers: [
                  // 1. APP BAR
                  SliverAppBar(
                    expandedHeight: 120.0,
                    floating: false,
                    pinned: true,
                    backgroundColor: const Color(0xFF1A1A2E),
                    flexibleSpace: FlexibleSpaceBar(
                      title: const Text(
                        "Command Center",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      centerTitle: false,
                      titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
                      background: Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
                          ),
                        ),
                      ),
                    ),
                    actions: [
                      IconButton(
                        icon: const Icon(Icons.refresh, color: Colors.white70),
                        onPressed: _fetchEnhancedStats,
                      ),
                      IconButton(
                        onPressed: _handleLogout,
                        icon: const Icon(Icons.logout, color: Colors.redAccent),
                      ),
                    ],
                  ),

                  // 2. SEARCH BAR AREA
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: TextField(
                        controller: _searchController,
                        onChanged: (val) => setState(() => _searchQuery = val),
                        decoration: InputDecoration(
                          hintText: "Search users by email...",
                          prefixIcon: const Icon(Icons.search),
                          fillColor: Colors.white,
                          filled: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                  ),

                  // 3. KEY METRICS GRID
                  // 3. KEY METRICS GRID
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    sliver: SliverGrid.count(
                      crossAxisCount: 2,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      // CHANGED: 1.4 -> 1.1 (Makes cards taller to fit content)
                      childAspectRatio: 1.1,
                      children: [
                        // USER GROWTH CARD
                        _buildMetricCard(
                          title: "Total Users",
                          value: numberFormat.format(_userCount),
                          subtitle:
                              "Avg roles: ${_avgRolesPerUser.toStringAsFixed(1)}",
                          icon: Icons.people_alt,
                          colorStart: Colors.blueAccent,
                          colorEnd: Colors.lightBlue,
                        ),

                        // TASK HEALTH CARD
                        _buildMetricCard(
                          title: "System Tasks",
                          value: numberFormat.format(_totalTaskCount),
                          subtitle:
                              "${(_taskCompletionRate * 100).toInt()}% Completion",
                          icon: Icons.check_circle,
                          colorStart: Colors.orange,
                          colorEnd: Colors.deepOrangeAccent,
                          progress: _taskCompletionRate,
                        ),

                        // ACTIVE ROLES
                        _buildMetricCard(
                          title: "Active Roles",
                          value: numberFormat.format(_roleCount),
                          subtitle: "Across all accounts",
                          icon: Icons.layers,
                          colorStart: Colors.purple,
                          colorEnd: Colors.purpleAccent,
                        ),

                        // ROUTINES
                        _buildMetricCard(
                          title: "Global Habits",
                          value: numberFormat.format(_routineCount),
                          subtitle: "Daily routines tracked",
                          icon: Icons.repeat,
                          colorStart: Colors.green,
                          colorEnd: Colors.teal,
                        ),
                      ],
                    ),
                  ),

                  // 4. RECENT ACTIVITY HEADER
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 30, 20, 10),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "User Registry",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          Chip(
                            label: Text("${_userCount} Total"),
                            backgroundColor: Colors.blue.withOpacity(0.1),
                            labelStyle: const TextStyle(
                              color: Colors.blue,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // 5. USER LIST (With Filtering)
                  // Note: Firestore doesn't support native partial text search easily without external tools (Algolia).
                  // We will stream the top 20 and filter locally for this demo.
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('users')
                        .orderBy('createdAt', descending: true)
                        .limit(50)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const SliverToBoxAdapter(
                          child: Center(
                            child: Padding(
                              padding: EdgeInsets.all(20.0),
                              child: CircularProgressIndicator(),
                            ),
                          ),
                        );
                      }

                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return const SliverToBoxAdapter(
                          child: Center(child: Text("No users found.")),
                        );
                      }

                      // Local Filter based on Search
                      final users = snapshot.data!.docs.where((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        final email = (data['email'] ?? '')
                            .toString()
                            .toLowerCase();
                        final name = (data['displayName'] ?? '')
                            .toString()
                            .toLowerCase();
                        final query = _searchQuery.toLowerCase();
                        return email.contains(query) || name.contains(query);
                      }).toList();

                      return SliverList(
                        delegate: SliverChildBuilderDelegate((context, index) {
                          final data =
                              users[index].data() as Map<String, dynamic>;
                          final String name = data['displayName'] ?? 'Unknown';
                          final String email = data['email'] ?? 'No Email';
                          final String photo = data['photoURL'] ?? '';
                          final Timestamp? created = data['createdAt'];

                          // Format Date
                          String dateStr = "Unknown date";
                          if (created != null) {
                            dateStr = DateFormat(
                              'MMM d, y',
                            ).format(created.toDate());
                          }

                          return _buildUserTile(
                            name,
                            email,
                            photo,
                            dateStr,
                            users[index].id,
                          );
                        }, childCount: users.length),
                      );
                    },
                  ),

                  const SliverPadding(padding: EdgeInsets.only(bottom: 50)),
                ],
              ),
            ),
    );
  }

  // --- WIDGET: Modern Metric Card (Fixed: Added Missing Title) ---
  Widget _buildMetricCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color colorStart,
    required Color colorEnd,
    double? progress,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [colorStart, colorEnd],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: colorStart.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1. TOP ROW: Icon + Percentage
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: Colors.white, size: 18),
              ),
              if (progress != null)
                Text(
                  "${(progress * 100).toInt()}%",
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
            ],
          ),

          const Spacer(),

          // 2. THE MISSING LABEL (Title) <-- ADDED THIS
          Text(
            title.toUpperCase(),
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
            ),
          ),

          const SizedBox(height: 4),

          // 3. The Big Value (e.g., 1.5K)
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          const SizedBox(height: 4),

          // 4. Subtitle
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 11,
            ),
          ),

          // 5. Progress Bar (Optional)
          if (progress != null) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: Colors.white.withOpacity(0.2),
                valueColor: const AlwaysStoppedAnimation(Colors.white),
                minHeight: 4,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // --- WIDGET: Pro User List Tile ---
  Widget _buildUserTile(
    String name,
    String email,
    String photoUrl,
    String dateJoined,
    String uid,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.05),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: Colors.grey[200],
          backgroundImage: photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
          child: photoUrl.isEmpty
              ? Text(
                  name[0].toUpperCase(),
                  style: const TextStyle(color: Colors.black87),
                )
              : null,
        ),
        title: Text(
          name,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              email,
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.calendar_today, size: 12, color: Colors.grey[400]),
                const SizedBox(width: 4),
                Text(
                  "Joined $dateJoined",
                  style: TextStyle(color: Colors.grey[400], fontSize: 12),
                ),
              ],
            ),
          ],
        ),
        trailing: PopupMenuButton(
          icon: const Icon(Icons.more_vert, color: Colors.grey),
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'view',
              child: Row(
                children: [
                  Icon(Icons.visibility, size: 18),
                  SizedBox(width: 8),
                  Text("View Details"),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'disable',
              child: Row(
                children: [
                  Icon(Icons.block, size: 18, color: Colors.red),
                  SizedBox(width: 8),
                  Text("Disable Account", style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ],
          onSelected: (val) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("Action '$val' on user $uid")),
            );
          },
        ),
      ),
    );
  }

  // --- WIDGET: Loading Skeleton (Industry Standard Feel) ---
  Widget _buildLoadingSkeleton() {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            const SizedBox(height: 50),
            Container(height: 100, color: Colors.grey[300]), // Fake Header
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: Container(height: 120, color: Colors.grey[300]),
                ), // Fake Card
                const SizedBox(width: 16),
                Expanded(
                  child: Container(height: 120, color: Colors.grey[300]),
                ), // Fake Card
              ],
            ),
            const SizedBox(height: 30),
            Expanded(child: Container(color: Colors.grey[300])), // Fake List
          ],
        ),
      ),
    );
  }
}
