import 'dart:math';
import 'dart:typed_data';

import 'package:alembic/main.dart';
import 'package:alembic/splash.dart';
import 'package:encrypt/encrypt.dart' as e;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:gap/gap.dart';
import 'package:padded/padded.dart';
import 'package:toxic/extensions/random.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  late TextEditingController emailController;
  late TextEditingController passController;
  late FocusNode fEmail;
  late FocusNode fPass;

  @override
  void initState() {
    emailController = TextEditingController();
    passController = TextEditingController();
    fEmail = FocusNode();
    fPass = FocusNode();
    super.initState();
  }

  void _doLogin() async {
    await box.put("1", emailController.value.text);
    await box.put("2", passController.value.text);
    await box.put("authenticated", true);
    Navigator.pushAndRemoveUntil(
        context,
        CupertinoPageRoute(builder: (context) => const SplashScreen()),
        (route) => false);
  }

  @override
  Widget build(BuildContext context) => CupertinoPageScaffold(
          child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SvgPicture.asset("assets/login.svg", width: 100, height: 100),
            const Gap(16),
            PaddingHorizontal(
                padding: 32,
                child: CupertinoTextField(
                  focusNode: fEmail,
                  prefix: const PaddingLeft(
                    padding: 4,
                    child: Icon(CupertinoIcons.person_alt_circle_fill),
                  ),
                  onSubmitted: (_) => fPass.requestFocus(),
                  decoration: BoxDecoration(
                      color: const Color(0x55000000),
                      borderRadius: BorderRadius.circular(8)),
                  textAlign: TextAlign.left,
                )),
            const Gap(16),
            PaddingHorizontal(
                padding: 32,
                child: CupertinoTextField(
                  focusNode: fPass,
                  obscureText: true,
                  prefix: const PaddingLeft(
                    padding: 4,
                    child: Icon(CupertinoIcons.padlock_solid),
                  ),
                  onSubmitted: (_) {
                    _doLogin();
                  },
                  decoration: BoxDecoration(
                      color: const Color(0x55000000),
                      borderRadius: BorderRadius.circular(8)),
                  textAlign: TextAlign.left,
                ))
          ],
        ),
      ));
}
