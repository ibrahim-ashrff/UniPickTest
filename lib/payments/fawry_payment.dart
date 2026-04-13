import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:fawry_sdk/fawry_sdk.dart';
import 'package:fawry_sdk/fawry_utils.dart';
import 'package:fawry_sdk/model/bill_item.dart';
import 'package:fawry_sdk/model/fawry_launch_model.dart';
import 'package:fawry_sdk/model/launch_apple_pay_model.dart';
import 'package:fawry_sdk/model/launch_checkout_model.dart';
import 'package:fawry_sdk/model/launch_customer_model.dart';
import 'package:fawry_sdk/model/launch_merchant_model.dart';
import 'package:fawry_sdk/model/payment_methods.dart';
import 'package:fawry_sdk/model/response.dart';
import 'package:flutter/material.dart';

class FawryPayment {
  // Store subscriptions per context to allow multiple listeners
  static final Map<BuildContext, StreamSubscription> _subscriptions = {};

  /// Set to true before opening Fawry UI so app can redirect back to checkout on resume (e.g. user pressed back).
  static bool isAwaitingReturnFromFawry = false;
  static void setAwaitingReturnFromFawry(bool value) {
    isAwaitingReturnFromFawry = value;
  }
  static void clearAwaitingReturnFromFawry() {
    isAwaitingReturnFromFawry = false;
  }

  static void listen(
    BuildContext context, {
    required void Function(ResponseStatus response) onPaymentComplete,
    void Function(Object error)? onError,
  }) {
    // Cancel existing subscription for this context if any
    _subscriptions[context]?.cancel();
    
    // Create new subscription for this context
    final subscription = FawrySDK.instance.callbackResultStream().listen((event) {
      debugPrint("FAWRY RAW EVENT: $event");
      try {
        final response = ResponseStatus.fromJson(jsonDecode(event));
        
        // Log all fields including data (which contains reference number)
        debugPrint("FAWRY STATUS: ${response.status}");
        debugPrint("FAWRY MESSAGE: ${response.message ?? ''}");
        debugPrint("FAWRY DATA: ${response.data ?? ''}"); // This likely has the reference number!
        debugPrint("FAWRY ERROR: ${response.error ?? ''}");
        
        onPaymentComplete(response);
      } catch (e) {
        onError?.call(e);
        debugPrint("Fawry callback parse error: $e");
      }
    });
    
    _subscriptions[context] = subscription;
  }

  static void cancel(BuildContext context) {
    _subscriptions[context]?.cancel();
    _subscriptions.remove(context);
  }

  /// Fawry expects merchant ref as alphanumeric (guide). Underscores/long UID-based refs can fail card auth while Pay-at-Fawry still works.
  static String generateMerchantRefNum() {
    // Per Fawry guide: random 10 alphanumeric digits.
    return FawryUtils.randomAlphaNumeric(10);
  }

  static Future<String> pay({
    required String merchantCode,
    required String secureHashKey, // NOTE: using hash key from email
    required String merchantRefNum, // Use [generateMerchantRefNum] — alphanumeric only
    required String customerProfileId,
    required String customerName,
    required String customerEmail,
    required String customerMobile,
    required double amountEgp,
    String description = "UNIPICK Order",
    bool allow3D = true,
    PaymentMethods paymentMethods = PaymentMethods.ALL,
    /// Required for saved cards / tokenized checkout. Must match deep link scheme (iOS Info.plist + Android intent-filter).
    bool payWithCardToken = true,
    bool enableApplePay = false,
    String? applePayMerchantId,
  }) async {

    debugPrint("FAWRY merchantCode=$merchantCode");
    debugPrint("FAWRY merchantRefNum=$merchantRefNum");
    debugPrint("FAWRY customerProfileId=$customerProfileId");
    debugPrint("FAWRY customerMobile=$customerMobile");
    final amountRounded = double.parse(amountEgp.toStringAsFixed(2));
    debugPrint("FAWRY amount=$amountRounded");
    debugPrint("FAWRY baseUrl='https://atfawry.fawrystaging.com/'");
    debugPrint("FAWRY secureHashKey=$secureHashKey");
    debugPrint("FAWRY payWithCardToken=$payWithCardToken");

    // One aggregate line. A "rich" cart would pass multiple [BillItem]s (each menu line:
    // id, name, qty, unit price) so Fawry's receipt/checkout shows itemized rows.
    final chargeItems = <BillItem>[
      BillItem(
        itemId: "Item1",
        description: description,
        quantity: 1,
        price: amountRounded,
      ),
    ];

    final customerModel = LaunchCustomerModel(
      customerProfileId: customerProfileId,
      customerName: customerName,
      customerEmail: customerEmail,
      customerMobile: customerMobile,
    );

    // LaunchMerchantModel: merchantCode, merchantRefNum, secretKey/secureKey per Fawry guide
    final merchantModel = LaunchMerchantModel(
      merchantCode: merchantCode,
      merchantRefNum: merchantRefNum,
      secureKey: secureHashKey, // Security Key / Hash from Fawry (guide: "provided by support")
    );

    LaunchApplePayModel? applePayModel;
    if (enableApplePay) {
      if (applePayMerchantId == null || applePayMerchantId.isEmpty) {
        throw Exception('Apple Pay merchant ID is required when Apple Pay is enabled');
      }
      applePayModel = LaunchApplePayModel(merchantID: applePayMerchantId);
    }

    // Deep link scheme must match iOS Info.plist + Android intent-filter (`unipick`).
    // Needed for FAWRY_PAY / ALL redirects; for iOS card + saved cards (token) the SDK
    // may need the same return URL after 3DS / wallet handoff.
    final isIOS = Platform.isIOS;
    LaunchCheckoutModel? checkoutModel;
    final needsCheckoutScheme = paymentMethods == PaymentMethods.ALL ||
        paymentMethods == PaymentMethods.FAWRY_PAY ||
        (isIOS &&
            paymentMethods == PaymentMethods.CREDIT_CARD &&
            payWithCardToken);
    if (isIOS && needsCheckoutScheme) {
      checkoutModel = LaunchCheckoutModel(scheme: 'unipick');
    }

    // skipReceipt: hide Fawry's post-payment receipt screen.
    // skipLogin: false on iOS + card-only (SDK may need that step); true on Android / other.
    final isIOSCardOnly = isIOS && paymentMethods == PaymentMethods.CREDIT_CARD;

    final model = FawryLaunchModel(
      allow3DPayment: allow3D,
      chargeItems: chargeItems,
      launchCustomerModel: customerModel,
      launchMerchantModel: merchantModel,
      skipLogin: isIOSCardOnly ? false : true,
      skipReceipt: true,
      payWithCardToken: payWithCardToken,
      paymentMethods: paymentMethods,
      launchApplePayModel: applePayModel,
      launchCheckOutModel: checkoutModel,
      // No need for paymentSignature or tokenizationSignature when secureKey is provided
    );

    await FawrySDK.instance.startPayment(
      launchModel: model,
      baseURL: "https://atfawry.fawrystaging.com/",
      lang: FawrySDK.LANGUAGE_ENGLISH,
    );
    
    // Return merchantRefNum so it can be used for status checks
    return merchantRefNum;
  }
}
