import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_platform_alert/flutter_platform_alert.dart';
import 'package:laundrivr/src/data/filter.dart';
import 'package:laundrivr/src/features/theme/laundrivr_theme.dart';
import 'package:loader_overlay/loader_overlay.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../constants.dart';
import '../../data/adapter/ble_adapter.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _targetDigits = "";
  bool _isTargetDigitsValidValue = false;

  // create an instance of ble functional test with the param for updating the loading spinner
  late BleAdapter bleFunctionalTest =
      BleAdapter(updateShowLoadingSpinner, showMyDialog);

  late final StreamSubscription<AuthState> _authStateSubscription;
  final TextEditingController _targetDigitsValidityController =
      TextEditingController();
  bool _redirecting = false;

  Future<void> showMyDialog(String title, String message) async {
    // if not mounted don't do anything
    if (!mounted) {
      return;
    }

    await FlutterPlatformAlert.showAlert(
        windowTitle: title,
        text: message,
        alertStyle: AlertButtonStyle.ok,
        iconStyle: IconStyle.information,
        windowPosition: AlertWindowPosition.screenCenter);
  }

  void updateShowLoadingSpinner(bool showLoadingSpinner) {
    showLoadingSpinner
        ? context.loaderOverlay.show()
        : context.loaderOverlay.hide();
  }

  Future<void> _signOut() async {
    try {
      await supabase.auth.signOut();
    } on AuthException catch (error) {
      context.showErrorSnackBar(message: error.message);
    } catch (error) {
      context.showErrorSnackBar(message: 'Unexpected error occurred');
    }
  }

  void _startBleTransaction() async {
    bleFunctionalTest.start(EndsWithFilter(_targetDigits));
    _targetDigitsValidityController.clear();
    setState(() {
      _targetDigits = "";
    });
  }

  @override
  void initState() {
    _targetDigitsValidityController.addListener(() {
      final isTargetDigitsValid =
          _targetDigitsAreValid(_targetDigitsValidityController.value.text);
      if (isTargetDigitsValid != _isTargetDigitsValidValue) {
        setState(() {
          _isTargetDigitsValidValue = isTargetDigitsValid;
        });
      }
    });
    _authStateSubscription = supabase.auth.onAuthStateChange.listen((data) {
      if (_redirecting) return;
      final session = data.session;
      if (session == null) {
        _redirecting = true;
        Navigator.of(context).pushReplacementNamed('/');
      }
    });
    super.initState();
  }

  @override
  void dispose() {
    _authStateSubscription.cancel();
    _targetDigitsValidityController.clear();
    super.dispose();
  }

  String _validateTargetDigits(String value) {
    if (value.isEmpty) {
      return 'Please enter three numbers';
    }
    if (!_targetDigitsAreOnlyNumbers(value)) {
      return 'Please enter only numbers';
    }

    if (!_targetDigitsAreThree(value)) {
      return 'Please enter three numbers';
    }

    return "";
  }

  bool _targetDigitsAreValid(String value) {
    return value.isNotEmpty &&
        _targetDigitsAreThree(value) &&
        _targetDigitsAreOnlyNumbers(value);
  }

  bool _targetDigitsAreThree(String value) {
    return value.length == 3;
  }

  bool _targetDigitsAreOnlyNumbers(String targetDigits) {
    // return false if the input is not only numbers or if it's less than 3 digits
    return RegExp(r'^[0-9]+$').hasMatch(targetDigits);
  }

  @override
  Widget build(BuildContext context) {
    final LaundrivrTheme laundrivrTheme =
        Theme.of(context).extension<LaundrivrTheme>()!;
    // get the current user from supabase
    final User user = supabase.auth.currentUser!;
    return LoaderOverlay(
      child: Scaffold(
        backgroundColor: laundrivrTheme.opaqueBackgroundColor,
        body: SafeArea(
          child: Center(
              child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              const SizedBox(height: 25),
              Text('Home Screen',
                  style: laundrivrTheme.primaryTextStyle?.copyWith(
                    fontWeight: FontWeight.bold,
                  )),
              const SizedBox(height: 25),
              Text('${user.email}',
                  style: laundrivrTheme.primaryTextStyle?.copyWith(
                    fontWeight: FontWeight.w500,
                    fontSize: 24,
                  )),
              const SizedBox(height: 25),
              ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 50, vertical: 20),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      primary: laundrivrTheme.secondaryOpaqueBackgroundColor,
                      elevation: 10),
                  onPressed: _signOut,
                  child: Text('Sign out',
                      style: laundrivrTheme.primaryTextStyle?.copyWith(
                        fontWeight: FontWeight.w800,
                        fontSize: 24,
                      ))),
              const SizedBox(height: 50),
              SizedBox(
                width: 300,
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 200,
                        child: PinCodeTextField(
                          controller: _targetDigitsValidityController,
                          appContext: context,
                          length: 3,
                          animationType: AnimationType.scale,
                          cursorColor: laundrivrTheme.primaryBrightTextColor,
                          pinTheme: PinTheme(
                            shape: PinCodeFieldShape.underline,
                            activeColor: _isTargetDigitsValidValue
                                ? Colors.green
                                : Colors.red,
                            fieldHeight: 50,
                          ),
                          animationDuration: const Duration(milliseconds: 300),
                          validator: (v) {
                            String output = _validateTargetDigits(v!);
                            if (output.isEmpty) {
                              return null;
                            } else {
                              return output;
                            }
                          },
                          onChanged: (value) {
                            setState(() {
                              _targetDigits = value;
                            });
                          },
                        ),
                      ),
                      const SizedBox(height: 25),
                      ElevatedButton(
                          style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 50, vertical: 20),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                              primary:
                                  laundrivrTheme.secondaryOpaqueBackgroundColor,
                              elevation: 10),
                          onPressed: _isTargetDigitsValidValue
                              ? _startBleTransaction
                              : null,
                          child: Text('Hack Machine',
                              style: laundrivrTheme.primaryTextStyle?.copyWith(
                                fontWeight: FontWeight.w800,
                                fontSize: 24,
                              ))),
                    ]),
              ),
            ],
          )),
        ),
      ),
    );
  }
}
