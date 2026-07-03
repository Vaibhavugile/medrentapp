import 'package:flutter/material.dart';

class LeadDetailsScreen extends StatelessWidget {
  final Map<String, dynamic> lead;

  const LeadDetailsScreen({
    super.key,
    required this.lead,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Lead Details"),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [

          Container(
  padding: const EdgeInsets.all(24),
  decoration: BoxDecoration(
    gradient: LinearGradient(
      colors: [
        Colors.indigo.shade500,
        Colors.blue.shade400,
      ],
    ),
    borderRadius: BorderRadius.circular(24),
  ),
  child: Column(
    children: [

      CircleAvatar(
        radius: 38,
        backgroundColor: Colors.white24,
        child: Text(
          (lead['customerName'] ?? "C")
              .toString()[0]
              .toUpperCase(),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),

      const SizedBox(height: 18),

      Text(
        lead['customerName'] ?? '',
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
      ),
      const SizedBox(height: 14),

_statusChip(
  lead['status'] ?? 'New',
),

      const SizedBox(height: 10),

      Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 7,
        ),
        decoration: BoxDecoration(
          color: Colors.white24,
          borderRadius: BorderRadius.circular(100),
        ),
        child: Text(
          (lead['type'] ?? '')
              .toString()
              .toUpperCase(),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    ],
  ),
),

const SizedBox(height: 25),

          _item(Icons.person, "Contact Person",
              lead['contactPerson']),

          _item(Icons.phone, "Phone",
              lead['phone']),

          _item(Icons.email, "Email",
              lead['email']),

          _item(Icons.location_on, "Address",
              lead['address']),

          _item(Icons.campaign, "Lead Source",
              lead['leadSource']),

          _item(Icons.notes, "Notes",
              lead['notes']),

          _item(Icons.category, "Type",
              lead['type']),

          _item(Icons.person_outline, "Created By",
              lead['createdByName']),
        ],
      ),
    );
  }

  Widget _item(
  IconData icon,
  String title,
  dynamic value,
) {
  return Container(
    margin: const EdgeInsets.only(bottom: 16),
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(.05),
          blurRadius: 12,
          offset: const Offset(0, 5),
        ),
      ],
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [

        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Colors.indigo.withOpacity(.1),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(
            icon,
            color: Colors.indigo,
          ),
        ),

        const SizedBox(width: 16),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              Text(
                title,
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),

              const SizedBox(height: 6),

              Text(
                value == null || value.toString().trim().isEmpty
                    ? "-"
                    : value.toString(),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
Widget _statusChip(String status) {
  Color color;

  switch (status.toLowerCase()) {
    case 'new':
      color = Colors.white;
      break;

    case 'contacted':
      color = Colors.orange;
      break;

    case 'req shared':
      color = Colors.purple;
      break;

    case 'closed':
      color = Colors.green;
      break;

    case 'lost':
      color = Colors.red;
      break;

    default:
      color = Colors.white;
  }

  return Container(
    padding: const EdgeInsets.symmetric(
      horizontal: 18,
      vertical: 8,
    ),
    decoration: BoxDecoration(
      color: color.withOpacity(.12),
      borderRadius: BorderRadius.circular(100),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [

        Icon(
          Icons.circle,
          size: 10,
          color: color,
        ),

        const SizedBox(width: 8),

        Text(
          status.toUpperCase(),
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    ),
  );
}
}