import 'package:flutter/material.dart';

// -----------------------------------------------------------------------------
// 6. SYSTEM SETTINGS VIEW
// -----------------------------------------------------------------------------
class SystemSettingsView extends StatefulWidget {
  const SystemSettingsView({super.key});

  @override
  State<SystemSettingsView> createState() => _SystemSettingsViewState();
}

class _SystemSettingsViewState extends State<SystemSettingsView> {
  bool gcashEnabled = true;
  bool codEnabled = true;
  bool voiceOrderingEnabled = true;
  bool autoApprovalEnabled = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('System settings', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
        const SizedBox(height: 32),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left grid layout panel: Geofence card bounds
            Expanded(
              flex: 5,
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Campus geofence', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 16),
                    Container(
                      height: 100,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [Colors.teal.shade50, Colors.blue.shade50]),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.teal.shade200, style: BorderStyle.solid),
                      ),
                      child: Center(
                        child: Text(
                          '[ Geofence Boundary Map Area Grid ]',
                          style: TextStyle(color: Colors.teal.shade800, fontWeight: FontWeight.w500, fontSize: 13),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Geofence radius', style: TextStyle(color: Colors.grey)),
                        Text('450 m', style: TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    )
                  ],
                ),
              ),
            ),
            const SizedBox(width: 24),
            
            // Right grid layout panel: Payments channels switch options
            Expanded(
              flex: 5,
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Payments', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      title: const Text('GCash via PayMongo', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                      value: gcashEnabled,
                      activeColor: Colors.amber,
                      onChanged: (val) { setState(() { gcashEnabled = val; }); },
                      contentPadding: EdgeInsets.zero,
                    ),
                    SwitchListTile(
                      title: const Text('Cash on delivery', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                      value: codEnabled,
                      activeColor: Colors.amber,
                      onChanged: (val) { setState(() { codEnabled = val; }); },
                      contentPadding: EdgeInsets.zero,
                    ),
                  ],
                ),
              ),
            )
          ],
        ),
        const SizedBox(height: 24),
        
        // Bottom full-width card parameters view list
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('General', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 12),
              SwitchListTile(
                title: const Text('Voice ordering', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                value: voiceOrderingEnabled,
                activeColor: Colors.amber,
                onChanged: (val) { setState(() { voiceOrderingEnabled = val; }); },
                contentPadding: EdgeInsets.zero,
              ),
              SwitchListTile(
                title: const Text('New vendor auto-approval', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                value: autoApprovalEnabled,
                activeColor: Colors.amber,
                onChanged: (val) { setState(() { autoApprovalEnabled = val; }); },
                contentPadding: EdgeInsets.zero,
              ),
            ],
          ),
        )
      ],
    );
  }
}
