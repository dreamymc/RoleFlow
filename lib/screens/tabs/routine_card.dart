import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:math';
import '../../models/role.dart';
import '../../models/routine_model.dart';
import 'edit_routine_sheet.dart';

class RoutineCard extends StatefulWidget {
  final Routine routine;
  final Role role;
  final VoidCallback onIncrement;
  final VoidCallback onUndo;
  final bool isCompletedToday;

  const RoutineCard({
    super.key,
    required this.routine,
    required this.role,
    required this.onIncrement,
    required this.onUndo,
    required this.isCompletedToday,
  });

  @override
  State<RoutineCard> createState() => _RoutineCardState();
}

class _RoutineCardState extends State<RoutineCard> with SingleTickerProviderStateMixin {
  late ConfettiController _confettiController;
  late AnimationController _bounceController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    // Shorter duration for snappy feel, but we'll control emission flow manually
    _confettiController = ConfettiController(duration: const Duration(milliseconds: 800));
    
    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
      lowerBound: 0.0,
      upperBound: 1.0, 
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.25).animate(
      CurvedAnimation(parent: _bounceController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _bounceController.dispose();
    super.dispose();
  }

  void _handleTap() async {
    // 1. BOUNCE
    await _bounceController.forward();
    await _bounceController.reverse();

    // 2. LOGIC
    widget.onIncrement();

    // 3. FIRE ALWAYS (The "Always Reward" Strategy)
    // We just reset it to ensure it fires fresh every click
    _confettiController.stop();
    _confettiController.play();
  }

  // --- CONFIGURABLE CONFETTI LOGIC ---
  List<Color> _getBlastColors(bool isTargetMet, bool isOverAchiever) {
    if (isOverAchiever) {
      // GRANDUER: Mix of Gold, Role Color, and White
      return [Colors.amber, Colors.orange, Colors.white, widget.role.color];
    } else if (isTargetMet) {
      // TARGET HIT: Pure Gold
      return [Colors.amber, Colors.yellow, Colors.orange];
    } else {
      // NORMAL STEP: Role Colors
      return [widget.role.color, Colors.blueGrey, Colors.white];
    }
  }

  double _getBlastForce(bool isTargetMet, bool isOverAchiever) {
    if (isOverAchiever) return 20; // Massive explosion
    if (isTargetMet) return 10;    // Big pop
    return 5;                      // Standard pop
  }

  @override
  Widget build(BuildContext context) {
    // We check (count + 1) logic relative to current UI state for visual feedback
    // But since this re-renders after update, we use current state logic.
    // Actually, for the confetti triggering *right now*, we want to know what state we are ENTERING.
    // The build method runs *after* the update, so:
    final bool isTargetMet = widget.routine.count >= widget.routine.target;
    final bool isOverAchiever = widget.routine.count > widget.routine.target;
    
    final double progress = (widget.routine.count / widget.routine.target).clamp(0.0, 1.0);
    final String startStr = DateFormat('MMM d').format(widget.routine.startDate);

    return Stack(
      alignment: Alignment.center,
      children: [
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: isOverAchiever 
               ? const BorderSide(color: Colors.amber, width: 2) 
               : BorderSide.none,
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ROW 1: Title & Button
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () {
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                            ),
                            builder: (context) => EditRoutineSheet(
                              routine: widget.routine,
                              roleId: widget.role.id,
                              roleColor: widget.role.color,
                            ),
                          );
                        },
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  widget.routine.title,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                                ),
                                const SizedBox(width: 6),
                                Icon(Icons.edit, size: 14, color: Colors.grey[400]),
                              ],
                            ),
                            if (widget.routine.description.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 4.0),
                                child: Text(
                                  widget.routine.description,
                                  style: TextStyle(fontSize: 13, color: Colors.grey[600], fontStyle: FontStyle.italic),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    
                    // --- THE BUTTON ---
                    widget.isCompletedToday 
                    ? Tooltip(
                        message: "Done for today! Long press to undo.",
                        child: InkWell(
                          onLongPress: widget.onUndo,
                          child: CircleAvatar(
                            backgroundColor: Colors.grey[300],
                            child: const Icon(Icons.check, color: Colors.white),
                          ),
                        ),
                      )
                    : ScaleTransition(
                        scale: _scaleAnimation,
                        child: IconButton.filled(
                          icon: const Icon(Icons.add),
                          style: IconButton.styleFrom(
                            backgroundColor: isTargetMet ? (isOverAchiever ? Colors.amber : Colors.green) : widget.role.color,
                          ),
                          onPressed: _handleTap,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                
                // ROW 2: Progress
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 8,
                          backgroundColor: Colors.grey[200],
                          valueColor: AlwaysStoppedAnimation(
                            isOverAchiever ? Colors.amber : (isTargetMet ? Colors.green : widget.role.color),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      isOverAchiever ? "OVER-ACHIEVER! 🔥" : "${widget.routine.count}/${widget.routine.target} this week",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: isOverAchiever ? Colors.amber[800] : Colors.grey[600],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),
                const Divider(),

                // ROW 3: Stats
                Row(
                  children: [
                    Icon(Icons.local_fire_department, size: 16, color: Colors.orange[800]),
                    const SizedBox(width: 4),
                    Text(
                      "${widget.routine.totalLifetimeCount} total checks",
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey[700]),
                    ),
                    const Spacer(),
                    Text(
                      "Since $startStr",
                      style: TextStyle(fontSize: 11, color: Colors.grey[400]),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        
        // --- DYNAMIC CONFETTI CANNON ---
        ConfettiWidget(
          confettiController: _confettiController,
          blastDirectionality: BlastDirectionality.explosive, 
          shouldLoop: false,
          colors: _getBlastColors(isTargetMet, isOverAchiever),
          // Logic: Normal = 5 particles, Target = 15 particles, Grandeur = 30 particles
          numberOfParticles: isOverAchiever ? 30 : (isTargetMet ? 15 : 7),
          // Logic: Grandeur shoots faster/further
          gravity: isOverAchiever ? 0.2 : 0.1,
          createParticlePath: drawStar, 
        ),
      ],
    );
  }

  Path drawStar(Size size) {
    double degToRad(double deg) => deg * (pi / 180.0);
    const numberOfPoints = 5;
    final halfWidth = size.width / 2;
    final externalRadius = halfWidth;
    final internalRadius = halfWidth / 2.5;
    final degreesPerStep = degToRad(360 / numberOfPoints);
    final halfDegreesPerStep = degreesPerStep / 2;
    final path = Path();
    final fullAngle = degToRad(360);
    path.moveTo(size.width, halfWidth);

    for (double step = 0; step < fullAngle; step += degreesPerStep) {
      path.lineTo(halfWidth + externalRadius * cos(step), halfWidth + externalRadius * sin(step));
      path.lineTo(halfWidth + internalRadius * cos(step + halfDegreesPerStep), halfWidth + internalRadius * sin(step + halfDegreesPerStep));
    }
    path.close();
    return path;
  }
}