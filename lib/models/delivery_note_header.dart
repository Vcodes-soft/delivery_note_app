import 'package:flutter/material.dart';

class DeliveryNoteHeader {
  final String cmpyCode;
  final String dnNumber;
  final String locCode;
  final DateTime dates;
  final String customerCode;
  final String salesmanCode;
  final String soNumber;
  final String refNo;
  final String status;
  final String invStat;
  final double discount;
  final String curCode;
  final double exRate;
  final String dnType;
  final int qty;
  final TimeOfDay dTime;
  final String loginUser;
  final double creditLimitAmount;
  final double outstandingBalance;
  final double grossAmount;
  final String narration;
  final String commissionYN;
  final String supplier;
  final String dyType;

  DeliveryNoteHeader({
    required this.cmpyCode,
    required this.dnNumber,
    required this.locCode,
    required this.dates,
    required this.customerCode,
    required this.salesmanCode,
    required this.soNumber,
    required this.refNo,
    required this.status,
    required this.invStat,
    required this.discount,
    required this.curCode,
    required this.exRate,
    required this.dnType,
    required this.qty,
    required this.dTime,
    required this.loginUser,
    required this.creditLimitAmount,
    required this.outstandingBalance,
    required this.grossAmount,
    required this.narration,
    required this.commissionYN,
    required this.supplier,
    required this.dyType,
  });

  Map<String, dynamic> toJson() {
    return {
      'Cmpycode': cmpyCode,
      'DnNumber': dnNumber,
      'LocCode': locCode,
      'Dates': dates.toIso8601String(),
      'CustomerCode': customerCode,
      'SalesmanCode': salesmanCode,
      'SoNumber': soNumber,
      'RefNo': refNo,
      'Status': status,
      'InvStat': invStat,
      'Discount': discount,
      'CurCode': curCode,
      'ExRate': exRate,
      'DnType': dnType,
      'Qty': qty,
      'DTime': '${dTime.hour}:${dTime.minute}',
      'LoginUser': loginUser,
      'CreditLimitAmount': creditLimitAmount,
      'OutstandingBalance': outstandingBalance,
      'GrossAmount': grossAmount,
      'Narration': narration,
      'CommissionYN': commissionYN,
      'Supplier': supplier,
      'DYType': dyType,
    };
  }
}