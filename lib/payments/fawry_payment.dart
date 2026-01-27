import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:fawry_sdk/fawry_sdk.dart';
import 'package:fawry_sdk/fawry_utils.dart';
import 'package:fawry_sdk/model/bill_item.dart';
import 'package:fawry_sdk/model/fawry_launch_model.dart';
import 'package:fawry_sdk/model/launch_customer_model.dart';
import 'package:fawry_sdk/model/launch_merchant_model.dart';
import 'package:fawry_sdk/model/payment_methods.dart';
import 'package:fawry_sdk/model/response.dart';
import 'package:flutter/material.dart';

class FawryPayment {
  // Store subscriptions per context to allow multiple listeners
  static final Map<BuildContext, StreamSubscription> _subscriptions = {};

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
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Fawry callback parse error: $e")),
          );
        }
      }
    });
    
    _subscriptions[context] = subscription;
  }

  static void cancel(BuildContext context) {
    _subscriptions[context]?.cancel();
    _subscriptions.remove(context);
  }

  static Future<String> pay({
    required String merchantCode,
    required String secureHashKey, // NOTE: using hash key from email
    required String customerProfileId,
    required String customerName,
    required String customerEmail,
    required String customerMobile,
    required double amountEgp,
    String description = "UNIPICK Order",
    bool allow3D = true,
    PaymentMethods paymentMethods = PaymentMethods.ALL,
  }) async {
    final merchantRefNum = FawryUtils.randomAlphaNumeric(10);

    debugPrint("FAWRY merchantCode=$merchantCode");
    debugPrint("FAWRY merchantRefNum=$merchantRefNum");
    debugPrint("FAWRY customerProfileId=$customerProfileId");
    debugPrint("FAWRY customerMobile=$customerMobile");
    debugPrint("FAWRY amount=$amountEgp");
    debugPrint("FAWRY baseUrl='https://atfawry.fawrystaging.com/'");
    debugPrint("FAWRY secureHashKey=$secureHashKey");

    final chargeItems = <BillItem>[
      BillItem(
        itemId: "Item1",
        description: description,
        quantity: 1,
        price: amountEgp,
      ),
    ];

    final customerModel = LaunchCustomerModel(
      customerProfileId: customerProfileId,
      customerName: customerName,
      customerEmail: customerEmail,
      customerMobile: customerMobile,
    );

    // Pass secureKey directly to LaunchMerchantModel (this is the merchantSecretKey)
    final merchantModel = LaunchMerchantModel(
      merchantCode: merchantCode,
      merchantRefNum: merchantRefNum,
      secureKey: secureHashKey, // Pass the Security Key / Hash code from Fawry email
    );

    final model = FawryLaunchModel(
      allow3DPayment: allow3D,
      chargeItems: chargeItems,
      launchCustomerModel: customerModel,
      launchMerchantModel: merchantModel,
      skipLogin: true,
      skipReceipt: true,
      payWithCardToken: true, // Enable card tokenization to show "remember this card" option
      paymentMethods: paymentMethods,
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
