import 'package:flutter/material.dart';

class InactiveAccountScreen extends StatelessWidget {
  const InactiveAccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      body: SafeArea(
        child: Stack(
          children: [
            // =========================================================
            // BACKGROUND DECORATIONS
            // =========================================================
            Positioned(
              top: -90,
              right: -80,
              child: Container(
                width: 230,
                height: 230,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFE74C3C).withOpacity(.06),
                ),
              ),
            ),

            Positioned(
              bottom: -100,
              left: -80,
              child: Container(
                width: 240,
                height: 240,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF2C3E50).withOpacity(.05),
                ),
              ),
            ),

            // =========================================================
            // MAIN CONTENT
            // =========================================================
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(22),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: 460,
                  ),
                  child: Column(
                    children: [
                      // =================================================
                      // TOP BRAND
                      // =================================================
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  Color(0xFF2C3E50),
                                  Color(0xFF4CA1AF),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF2C3E50)
                                      .withOpacity(.18),
                                  blurRadius: 14,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.work_outline_rounded,
                              color: Colors.white,
                              size: 25,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            "BMM Workforce",
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF1F2937),
                              letterSpacing: -.3,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 28),

                      // =================================================
                      // MAIN CARD
                      // =================================================
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(
                          24,
                          28,
                          24,
                          24,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(
                            color: Colors.white,
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(.07),
                              blurRadius: 35,
                              offset: const Offset(0, 14),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            // ===========================================
                            // STATUS ICON
                            // ===========================================
                            Stack(
                              alignment: Alignment.center,
                              children: [
                                Container(
                                  width: 116,
                                  height: 116,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: const Color(0xFFE74C3C)
                                        .withOpacity(.07),
                                  ),
                                ),
                                Container(
                                  width: 88,
                                  height: 88,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: LinearGradient(
                                      colors: [
                                        const Color(0xFFE74C3C)
                                            .withOpacity(.14),
                                        const Color(0xFFC0392B)
                                            .withOpacity(.08),
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    border: Border.all(
                                      color: const Color(0xFFE74C3C)
                                          .withOpacity(.16),
                                      width: 1,
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.person_off_rounded,
                                    color: Color(0xFFE74C3C),
                                    size: 43,
                                  ),
                                ),

                                // Small status dot
                                Positioned(
                                  right: 8,
                                  bottom: 8,
                                  child: Container(
                                    width: 27,
                                    height: 27,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black
                                              .withOpacity(.10),
                                          blurRadius: 8,
                                        ),
                                      ],
                                    ),
                                    padding: const EdgeInsets.all(4),
                                    child: Container(
                                      decoration: const BoxDecoration(
                                        color: Color(0xFFE74C3C),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.close,
                                        color: Colors.white,
                                        size: 12,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 25),

                            // ===========================================
                            // STATUS BADGE
                            // ===========================================
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 13,
                                vertical: 7,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE74C3C)
                                    .withOpacity(.08),
                                borderRadius: BorderRadius.circular(30),
                                border: Border.all(
                                  color: const Color(0xFFE74C3C)
                                      .withOpacity(.15),
                                ),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.info_outline_rounded,
                                    size: 15,
                                    color: Color(0xFFE74C3C),
                                  ),
                                  SizedBox(width: 6),
                                  Text(
                                    "ACCOUNT INACTIVE",
                                    style: TextStyle(
                                      color: Color(0xFFE74C3C),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: .8,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 16),

                            // ===========================================
                            // TITLE
                            // ===========================================
                            const Text(
                              "Your Account Is Inactive",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF172033),
                                letterSpacing: -.5,
                              ),
                            ),

                            const SizedBox(height: 10),

                            const Text(
                              "Access to your workforce account is "
                              "currently disabled.",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 15,
                                color: Color(0xFF64748B),
                                height: 1.5,
                                fontWeight: FontWeight.w500,
                              ),
                            ),

                            const SizedBox(height: 24),

                            // ===========================================
                            // INFORMATION BOX
                            // ===========================================
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: const Color(0xFFE2E8F0),
                                ),
                              ),
                              child: const Row(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  SizedBox(
                                    width: 4,
                                  ),

                                  Icon(
                                    Icons.support_agent_rounded,
                                    color: Color(0xFF4CA1AF),
                                    size: 25,
                                  ),

                                  SizedBox(width: 13),

                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          "Need access?",
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w800,
                                            color: Color(0xFF172033),
                                          ),
                                        ),
                                        SizedBox(height: 4),
                                        Text(
                                          "Please contact your administrator "
                                          "to reactivate your account.",
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Color(0xFF64748B),
                                            height: 1.45,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 25),

                            // ===========================================
                            // BACK TO LOGIN
                            // ===========================================
                            SizedBox(
                              width: double.infinity,
                              height: 54,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFF2C3E50),
                                      Color(0xFF4CA1AF),
                                    ],
                                    begin: Alignment.centerLeft,
                                    end: Alignment.centerRight,
                                  ),
                                  borderRadius:
                                      BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF4CA1AF)
                                          .withOpacity(.22),
                                      blurRadius: 15,
                                      offset: const Offset(0, 7),
                                    ),
                                  ],
                                ),
                                child: ElevatedButton(
                                  onPressed: () async {
                                    Navigator.pushNamedAndRemoveUntil(
                                      context,
                                      '/',
                                      (_) => false,
                                    );
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.transparent,
                                    foregroundColor: Colors.white,
                                    shadowColor: Colors.transparent,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(16),
                                    ),
                                  ),
                                  child: const Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.arrow_back_rounded,
                                        size: 20,
                                      ),
                                      SizedBox(width: 9),
                                      Text(
                                        "Back to Login",
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // =================================================
                      // FOOTER
                      // =================================================
                      Text(
                        "BMM Workforce",
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                          fontWeight: FontWeight.w600,
                        ),
                      ),

                      const SizedBox(height: 4),

                      Text(
                        "Secure workforce management",
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade400,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}