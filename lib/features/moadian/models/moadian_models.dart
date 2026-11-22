import 'dart:convert';
import 'dart:typed_data';

/// پاسخ استاندارد همهٔ سرویس‌های ماژول مودیان تیسا (`ApiModel` در سرور).
class MoadianApiResult {
  const MoadianApiResult({
    required this.success,
    required this.status,
    this.message,
    this.data,
    this.deliveryUncertain = false,
    this.requestJson,
    this.responseJson,
  });

  final bool success;
  final int status;
  final String? message;
  final dynamic data;

  /// وقتی `true` است یعنی بستهٔ صورتحساب ساخته شده اما در حین ارسال خطای شبکه/Timeout
  /// رخ داده است؛ نباید کورکورانه ارسال مجدد زد و باید ابتدا کارپوشه/استعلام بررسی شود.
  final bool deliveryUncertain;
  final String? requestJson;
  final String? responseJson;

  factory MoadianApiResult.fromJson(dynamic raw) {
    if (raw is! Map) {
      return MoadianApiResult(
        success: false,
        status: 500,
        message: raw?.toString() ?? 'پاسخ نامعتبر از سرور دریافت شد.',
      );
    }
    final j = Map<String, dynamic>.from(raw);
    dynamic pick(String a, String b) => j.containsKey(a) ? j[a] : j[b];
    return MoadianApiResult(
      success: pick('success', 'Success') == true,
      status: (pick('status', 'Status') as num?)?.toInt() ?? 0,
      message: pick('message', 'Message')?.toString(),
      data: pick('data', 'Data'),
      deliveryUncertain:
          pick('deliveryUncertain', 'DeliveryUncertain') == true,
      requestJson: pick('requestJson', 'RequestJson')?.toString(),
      responseJson: pick('responseJson', 'ResponseJson')?.toString(),
    );
  }
}

/// فهرست صفحه‌بندی‌شدهٔ مودیان (`PagedList<T>`).
class MoadianPagedList<T> {
  const MoadianPagedList({
    required this.items,
    required this.totalCount,
    required this.page,
    required this.pageSize,
    required this.totalPages,
  });

  final List<T> items;
  final int totalCount;
  final int page;
  final int pageSize;
  final int totalPages;

  factory MoadianPagedList.empty() => const MoadianPagedList(
    items: [],
    totalCount: 0,
    page: 1,
    pageSize: 10,
    totalPages: 0,
  );

  factory MoadianPagedList.fromJson(
    Map<String, dynamic> j,
    T Function(Map<String, dynamic>) itemParser,
  ) {
    dynamic pick(String a, String b) => j.containsKey(a) ? j[a] : j[b];
    final rawItems = (pick('items', 'Items') as List? ?? const []);
    final items = rawItems
        .whereType<Map>()
        .map((e) => itemParser(Map<String, dynamic>.from(e)))
        .toList();
    final total = (pick('totalCount', 'TotalCount') as num?)?.toInt() ??
        items.length;
    final page = (pick('page', 'Page') as num?)?.toInt() ?? 1;
    final pageSize = (pick('pageSize', 'PageSize') as num?)?.toInt() ?? 10;
    final totalPages =
        (pick('totalPages', 'TotalPages') as num?)?.toInt() ??
        (pageSize > 0 ? ((total + pageSize - 1) ~/ pageSize) : 1);
    return MoadianPagedList(
      items: items,
      totalCount: total,
      page: page,
      pageSize: pageSize,
      totalPages: totalPages,
    );
  }
}

/// پروندهٔ خدمات‌دهنده / مؤدی مالیاتی (`VMShowCpinfoByCompany`).
class MoadianCpInfo {
  const MoadianCpInfo({
    required this.cpInfoId,
    this.companyId,
    this.companyName,
    required this.persianName,
    this.englishName,
    this.nationalId,
    this.economicNumber,
    this.type = 'حقوقی',
    this.postalCode,
  });

  final int cpInfoId;
  final int? companyId;
  final String? companyName;
  final String persianName;
  final String? englishName;
  final String? nationalId;
  final String? economicNumber;
  final String type;
  final String? postalCode;

  factory MoadianCpInfo.fromJson(Map<String, dynamic> j) {
    dynamic pick(String a, String b) => j.containsKey(a) ? j[a] : j[b];
    final rawId = j['cpinfoid'] ?? j['cpInfoId'] ?? j['CpInfoId'] ?? j['id'];
    return MoadianCpInfo(
      cpInfoId: rawId is num
          ? rawId.toInt()
          : (int.tryParse(rawId?.toString() ?? '') ?? 0),
      companyId: (pick('companyId', 'CompanyId') as num?)?.toInt(),
      companyName: pick('companyName', 'CompanyName')?.toString(),
      persianName: pick('persianName', 'PersianName')?.toString() ?? '',
      englishName: pick('englishName', 'EnglishName')?.toString(),
      nationalId: (j['nationalid'] ?? j['nationalId'] ?? j['Nationalid'])
          ?.toString(),
      economicNumber: pick('economicNumber', 'EconomicNumber')?.toString(),
      type: (pick('type', 'Type')?.toString().trim().isNotEmpty == true)
          ? pick('type', 'Type')!.toString().trim()
          : 'حقوقی',
      postalCode: pick('postalCode', 'PostalCode')?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'cpinfoid': cpInfoId,
    if (companyId != null && companyId! > 0) 'companyId': companyId,
    'persianName': persianName.trim(),
    'englishName': englishName?.trim(),
    'nationalid': nationalId?.trim(),
    'economicNumber': economicNumber?.trim(),
    'type': type.trim().isEmpty ? 'حقوقی' : type.trim(),
    'postalCode': postalCode?.trim(),
  };
}

/// سال مالی پروندهٔ مودیان (`VMFiscalYear`).
class MoadianFiscalYear {
  const MoadianFiscalYear({
    required this.id,
    required this.cpInfoId,
    required this.title,
    required this.startDate,
    required this.endDate,
    this.isActive = true,
  });

  final int id;
  final int cpInfoId;
  final String title;
  final DateTime startDate;
  final DateTime endDate;
  final bool isActive;

  bool containsDate(DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    final s = DateTime(startDate.year, startDate.month, startDate.day);
    final e = DateTime(endDate.year, endDate.month, endDate.day);
    return !d.isBefore(s) && !d.isAfter(e);
  }

  factory MoadianFiscalYear.fromJson(Map<String, dynamic> j) {
    dynamic pick(String a, String b) => j.containsKey(a) ? j[a] : j[b];
    DateTime parseDt(dynamic v) =>
        DateTime.tryParse(v?.toString() ?? '') ?? DateTime.now();
    return MoadianFiscalYear(
      id: (pick('id', 'Id') as num?)?.toInt() ?? 0,
      cpInfoId: (pick('cpInfoId', 'CpInfoId') as num?)?.toInt() ?? 0,
      title: pick('title', 'Title')?.toString() ?? '',
      startDate: parseDt(pick('startDate', 'StartDate')),
      endDate: parseDt(pick('endDate', 'EndDate')),
      isActive: pick('isActive', 'IsActive') != false,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'cpInfoId': cpInfoId,
    'title': title.trim(),
    'startDate': _isoDate(startDate),
    'endDate': _isoDate(endDate),
    'isActive': isActive,
  };
}

/// جزئیات فایل کلید خصوصی (`FileDetail` در `VMConnection`).
class MoadianKeyFile {
  const MoadianKeyFile({
    required this.fileName,
    this.displayName,
    this.fileSize = 0,
    this.fileType = 'application/x-pem-file',
    this.fileContentBase64,
    this.fileContent,
  });

  final String fileName;
  final String? displayName;
  final int fileSize;
  final String fileType;
  final String? fileContentBase64;
  final Uint8List? fileContent;

  factory MoadianKeyFile.fromJson(Map<String, dynamic> j) {
    dynamic pick(String a, String b) => j.containsKey(a) ? j[a] : j[b];
    Uint8List? bytes;
    String? b64;
    final raw = pick('fileContent', 'FileContent');
    if (raw is String && raw.isNotEmpty) {
      b64 = raw;
      try {
        bytes = base64Decode(raw);
      } catch (_) {}
    } else if (raw is List) {
      bytes = Uint8List.fromList(
        raw.whereType<num>().map((e) => e.toInt()).toList(),
      );
      b64 = base64Encode(bytes);
    }
    return MoadianKeyFile(
      fileName: pick('fileName', 'FileName')?.toString() ?? '',
      displayName: pick('displayName', 'DisplayName')?.toString(),
      fileSize:
          (pick('fileSize', 'FileSize') as num?)?.toInt() ?? bytes?.length ?? 0,
      fileType:
          pick('fileType', 'FileType')?.toString() ?? 'application/x-pem-file',
      fileContentBase64: b64,
      fileContent: bytes,
    );
  }

  Map<String, dynamic> toJson() => {
    'fileName': fileName,
    'displayName': displayName ?? fileName,
    'fileSize': fileSize,
    'fileType': fileType,
    if (fileContentBase64 != null)
      'fileContent': fileContentBase64
    else if (fileContent != null)
      'fileContent': base64Encode(fileContent!),
  };
}

/// تنظیمات اتصال به سامانه مودیان (`VMConnection`).
class MoadianConnection {
  const MoadianConnection({
    this.id = 0,
    required this.cpInfoId,
    required this.taxMemoryId,
    required this.webServiceAddress,
    this.filePrivateKey,
  });

  static const String officialEndpoint = 'https://tp.tax.gov.ir/req/api/';
  static const String sandboxEndpoint = 'https://rc.tp.tax.gov.ir/req/api/';

  final int id;
  final int cpInfoId;
  final String taxMemoryId;
  final String webServiceAddress;
  final MoadianKeyFile? filePrivateKey;

  bool get isConfigured =>
      taxMemoryId.trim().isNotEmpty && webServiceAddress.trim().isNotEmpty;

  bool get hasStoredPrivateKey =>
      filePrivateKey != null &&
      (filePrivateKey!.fileName.trim().isNotEmpty ||
          (filePrivateKey!.fileContentBase64 ?? '').isNotEmpty ||
          (filePrivateKey!.fileContent?.isNotEmpty ?? false));

  factory MoadianConnection.fromJson(Map<String, dynamic> j) {
    dynamic pick(String a, String b) => j.containsKey(a) ? j[a] : j[b];
    final fk = pick('filePrivatekey', 'FilePrivatekey');
    return MoadianConnection(
      id: (pick('id', 'Id') as num?)?.toInt() ?? 0,
      cpInfoId:
          ((j['cpinfoid'] ?? j['cpInfoId'] ?? j['CpInfoId']) as num?)
              ?.toInt() ??
          0,
      taxMemoryId:
          (j['taxMemoryID'] ?? j['taxMemoryId'] ?? j['TaxMemoryID'])
              ?.toString() ??
          '',
      webServiceAddress:
          pick('webServiceAddress', 'WebServiceAddress')?.toString() ?? '',
      filePrivateKey: fk is Map
          ? MoadianKeyFile.fromJson(Map<String, dynamic>.from(fk))
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    if (id > 0) 'id': id,
    'cpinfoid': cpInfoId,
    'taxMemoryID': taxMemoryId.trim(),
    'webServiceAddress': webServiceAddress.trim(),
    if (filePrivateKey != null) 'filePrivatekey': filePrivateKey!.toJson(),
  };
}

/// کالا یا خدمت مودیان (`VMGoodsOrService` و `VMGoodsOrServicesList`).
class MoadianGood {
  const MoadianGood({
    required this.goodsOrServicesId,
    required this.cpInfoId,
    required this.name,
    required this.uniqueIdentifier,
    this.unitOfMeasurementId = 0,
    this.unitOfMeasurement,
    this.valueAddedPercentage = 0,
    required this.price,
    this.description,
  });

  final int goodsOrServicesId;
  final int cpInfoId;
  final String name;
  final String uniqueIdentifier;
  final int unitOfMeasurementId;
  final String? unitOfMeasurement;
  final double valueAddedPercentage;
  final double price;
  final String? description;

  factory MoadianGood.fromJson(Map<String, dynamic> j) {
    dynamic pick(String a, String b) => j.containsKey(a) ? j[a] : j[b];
    final rawId =
        j['goodsOrServicesID'] ??
        j['goodsOrServicesId'] ??
        j['GoodsOrServicesId'] ??
        j['GoodsOrServicesID'] ??
        j['id'];
    return MoadianGood(
      goodsOrServicesId: (rawId as num?)?.toInt() ?? 0,
      cpInfoId: (pick('cpInfoId', 'CpInfoId') as num?)?.toInt() ?? 0,
      name: pick('name', 'Name')?.toString() ?? '',
      uniqueIdentifier:
          pick('uniqueIdentifier', 'UniqueIdentifier')?.toString() ?? '',
      unitOfMeasurementId:
          (pick('unitOfMeasurementId', 'UnitOfMeasurementId') as num?)
              ?.toInt() ??
          0,
      unitOfMeasurement:
          pick('unitOfMeasurement', 'UnitOfMeasurement')?.toString(),
      valueAddedPercentage:
          (pick('valueAddedPercentage', 'ValueAddedPercentage') as num?)
              ?.toDouble() ??
          0,
      price: (pick('price', 'Price') as num?)?.toDouble() ?? 0,
      description: pick('description', 'Description')?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'goodsOrServicesId': goodsOrServicesId,
    'goodsOrServicesID': goodsOrServicesId,
    'cpInfoId': cpInfoId,
    'name': name.trim(),
    'uniqueIdentifier': uniqueIdentifier.trim(),
    'unitOfMeasurementId': unitOfMeasurementId,
    'unitOfMeasurement': unitOfMeasurement?.trim(),
    'valueAddedPercentage': valueAddedPercentage,
    'price': price,
    if (description != null) 'description': description!.trim(),
  };
}

/// خریدار / مشتری مودیان (`VMCustomerList`).
class MoadianCustomer {
  const MoadianCustomer({
    required this.customerId,
    required this.cpInfoId,
    required this.name,
    this.type = 'حقیقی',
    this.nationalId,
    this.economicNumber,
    this.phone,
    this.postalCode,
    this.address,
  });

  final int customerId;
  final int cpInfoId;
  final String name;
  final String type;
  final String? nationalId;
  final String? economicNumber;
  final String? phone;
  final String? postalCode;
  final String? address;

  String get displayLabel => type.trim().isEmpty ? name : '$name ($type)';

  factory MoadianCustomer.fromJson(Map<String, dynamic> j) {
    dynamic pick(String a, String b) => j.containsKey(a) ? j[a] : j[b];
    final rawId =
        j['costomerID'] ??
        j['customerId'] ??
        j['CustomerId'] ??
        j['CostomerID'] ??
        j['id'];
    return MoadianCustomer(
      customerId: (rawId as num?)?.toInt() ?? 0,
      cpInfoId: (pick('cpInfoId', 'CpInfoId') as num?)?.toInt() ?? 0,
      name: pick('name', 'Name')?.toString() ?? '',
      type: (pick('type', 'Type')?.toString().trim().isNotEmpty == true)
          ? pick('type', 'Type')!.toString().trim()
          : 'حقیقی',
      nationalId:
          (j['nationalID'] ?? j['nationalId'] ?? j['NationalID'])?.toString(),
      economicNumber: pick('economicNumber', 'EconomicNumber')?.toString(),
      phone: pick('phone', 'Phone')?.toString(),
      postalCode: pick('postalCode', 'PostalCode')?.toString(),
      address: pick('address', 'Address')?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'customerId': customerId,
    'costomerID': customerId,
    'cpInfoId': cpInfoId,
    'name': name.trim(),
    'type': type.trim().isEmpty ? 'حقیقی' : type.trim(),
    'nationalID': nationalId?.trim(),
    'economicNumber': economicNumber?.trim(),
    'phone': phone?.trim(),
    'postalCode': postalCode?.trim(),
    'address': address?.trim(),
  };
}

/// واحد سنجش معتبر سامانه مودیان (`VMUnitOfMeasurement`).
class MoadianUnit {
  const MoadianUnit({
    int? unitId,
    int? unitOfMeasurementId,
    required this.cpInfoId,
    required this.name,
    required this.code,
  }) : unitOfMeasurementId = unitOfMeasurementId ?? unitId ?? 0;

  final int unitOfMeasurementId;
  final int cpInfoId;
  final String name;
  final String code;

  int get unitId => unitOfMeasurementId;

  factory MoadianUnit.fromJson(Map<String, dynamic> j) {
    dynamic pick(String a, String b) => j.containsKey(a) ? j[a] : j[b];
    final rawId =
        j['unitOfMeasurementID'] ??
        j['unitOfMeasurementId'] ??
        j['UnitOfMeasurementId'] ??
        j['UnitOfMeasurementID'] ??
        j['id'];
    return MoadianUnit(
      unitOfMeasurementId: (rawId as num?)?.toInt() ?? 0,
      cpInfoId: (pick('cpInfoId', 'CpInfoId') as num?)?.toInt() ?? 0,
      name: pick('name', 'Name')?.toString() ?? '',
      code: pick('code', 'Code')?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'unitOfMeasurementId': unitOfMeasurementId,
    'unitOfMeasurementID': unitOfMeasurementId,
    'cpInfoId': cpInfoId,
    'name': name.trim(),
    'code': code.trim(),
  };
}

/// یک ردیف قلم کالا/خدمت در صورتحساب (`VmInvoiceItems`).
class MoadianInvoiceItem {
  MoadianInvoiceItem({
    this.invoiceId,
    this.goodsOrServicesId = 0,
    this.name,
    this.uniqueIdentifier,
    this.unitOfMeasurement,
    this.count = 1,
    this.priceUnit = 0,
    this.discount = 0,
    this.valueAddedPercentage = 0,
    this.valueAddedAmount,
    this.calculatedPay,
    this.descriptionKala,
  });

  int? invoiceId;
  int goodsOrServicesId;
  String? name;
  String? uniqueIdentifier;
  String? unitOfMeasurement;
  double count;
  double priceUnit;
  double discount;
  double valueAddedPercentage;
  double? valueAddedAmount;
  double? calculatedPay;
  String? descriptionKala;

  MoadianInvoiceItem copy() => MoadianInvoiceItem(
    invoiceId: invoiceId,
    goodsOrServicesId: goodsOrServicesId,
    name: name,
    uniqueIdentifier: uniqueIdentifier,
    unitOfMeasurement: unitOfMeasurement,
    count: count,
    priceUnit: priceUnit,
    discount: discount,
    valueAddedPercentage: valueAddedPercentage,
    valueAddedAmount: valueAddedAmount,
    calculatedPay: calculatedPay,
    descriptionKala: descriptionKala,
  );

  factory MoadianInvoiceItem.fromJson(Map<String, dynamic> j) {
    dynamic pick(String a, String b) => j.containsKey(a) ? j[a] : j[b];
    final rawGid =
        j['goodsOrServicesID'] ??
        j['goodsOrServicesId'] ??
        j['GoodsOrServicesId'] ??
        j['GoodsOrServicesID'];
    return MoadianInvoiceItem(
      invoiceId: (pick('invoiceId', 'InvoiceId') as num?)?.toInt(),
      goodsOrServicesId: (rawGid as num?)?.toInt() ?? 0,
      name: pick('name', 'Name')?.toString(),
      uniqueIdentifier:
          pick('uniqueIdentifier', 'UniqueIdentifier')?.toString(),
      unitOfMeasurement:
          pick('unitOfMeasurement', 'UnitOfMeasurement')?.toString(),
      count: (pick('count', 'Count') as num?)?.toDouble() ?? 1,
      priceUnit: (pick('priceUnit', 'PriceUnit') as num?)?.toDouble() ?? 0,
      discount: (pick('discount', 'Discount') as num?)?.toDouble() ?? 0,
      valueAddedPercentage:
          (pick('valueAddedPercentage', 'ValueAddedPercentage') as num?)
              ?.toDouble() ??
          0,
      valueAddedAmount:
          (pick('valueAddedAmount', 'ValueAddedAmount') as num?)?.toDouble(),
      calculatedPay:
          (pick('calculatedPay', 'CalculatedPay') as num?)?.toDouble(),
      descriptionKala: pick('descriptionKala', 'DescriptionKala')?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    final gross = count * priceUnit;
    final net = (gross - discount) < 0 ? 0.0 : (gross - discount);
    final vat = (net * valueAddedPercentage / 100.0).truncateToDouble();
    final total = net.truncateToDouble() + vat;
    return {
      if (invoiceId != null) 'invoiceId': invoiceId,
      'goodsOrServicesId': goodsOrServicesId,
      'goodsOrServicesID': goodsOrServicesId,
      'name': name,
      'uniqueIdentifier': uniqueIdentifier,
      'unitOfMeasurement': unitOfMeasurement,
      'count': count,
      'priceUnit': priceUnit,
      'discount': discount,
      'beforeDisPrice': gross,
      'valueAddedPercentage': valueAddedPercentage,
      'valueAddedAmount': vat,
      'totalPrice': total,
      'calculatedPay': total,
      'descriptionKala': descriptionKala,
    };
  }
}

/// شمارنده‌های وضعیت سراسری که همراه فهرست صورتحساب‌ها برمی‌گردد (`Labels` در `InvoiceResponse`).
class MoadianInvoiceLabels {
  const MoadianInvoiceLabels({
    this.all = 0,
    this.sentToSystem = 0,
    this.inquiry = 0,
    this.lackOfResponsiveness = 0,
    this.error = 0,
    this.notSentToSystem = 0,
  });

  final int all;
  final int sentToSystem;
  final int inquiry;
  final int lackOfResponsiveness;
  final int error;
  final int notSentToSystem;

  int get notSent => notSentToSystem;
  int get sent => sentToSystem;
  int get waitingInquiry => inquiry;
  int get waitingReaction => lackOfResponsiveness;
  int get hasError => error;

  int? countForTab(String code) => switch (code) {
    'همه' => all,
    '0' => notSentToSystem,
    '4' => sentToSystem,
    '2' => lackOfResponsiveness,
    '5' => error,
    _ => null,
  };

  factory MoadianInvoiceLabels.fromJson(Map<String, dynamic>? j) {
    if (j == null) return const MoadianInvoiceLabels();
    int pickInt(String a, String b) {
      final v = j[a] ?? j[b];
      if (v is num) return v.toInt();
      return int.tryParse(v?.toString().trim() ?? '') ?? 0;
    }

    return MoadianInvoiceLabels(
      all: pickInt('lblAll', 'LblAll'),
      sentToSystem: pickInt('lblSentToSystem', 'LblSentToSystem'),
      inquiry: pickInt('lblInquiry', 'LblInquiry'),
      lackOfResponsiveness: pickInt(
        'lblLackOfResponsiveness',
        'LblLackOfResponsiveness',
      ),
      error: pickInt('lblError', 'LblError'),
      notSentToSystem: pickInt('lblNotSentToSystem', 'LblNotSentToSystem'),
    );
  }
}

/// پاسخ ترکیبی فهرست صورتحساب‌ها (`InvoiceResponse`).
class MoadianInvoicePageResult {
  const MoadianInvoicePageResult({
    required this.invoices,
    required this.labels,
  });

  final MoadianPagedList<MoadianInvoice> invoices;
  final MoadianInvoiceLabels labels;
}

/// سربرگ و جزئیات کامل صورتحساب مودیان (`VmInvoiceItems.InvoiceVM`).
class MoadianInvoice {
  MoadianInvoice({
    required this.id,
    this.numberInvoice,
    this.cpInfoId,
    this.persianName,
    this.sellerNationalId,
    this.sellerEconomicNo,
    this.sellerPostalCode,
    this.customerId,
    this.customerName,
    this.customerType,
    this.customerNationalId,
    this.customerEconomicNumber,
    this.customerPhone,
    this.customerPostalCode,
    this.customerAddress,
    this.fiscalYearId,
    this.fiscalYearName,
    this.dateStartFiscalYear,
    this.dateEndFiscalYear,
    this.typePattern = 'نوع اول',
    this.dateOrder,
    this.name,
    this.paymentType = 'نقدی',
    this.description,
    this.statusSentToSystem,
    this.statusSentToSystemInt,
    this.taxNumber,
    this.newTaxNumber,
    this.referenceId,
    this.totalMoney = 0,
    this.subject = 'اصلی',
    this.showButtons = true,
    this.isNew = false,
    this.priceNaghd = 0,
    this.priceNesye = 0,
    List<MoadianInvoiceItem>? items,
  }) : invoiceItems = items ?? <MoadianInvoiceItem>[];

  int id;
  int? numberInvoice;
  int? cpInfoId;
  String? persianName;
  String? sellerNationalId;
  String? sellerEconomicNo;
  String? sellerPostalCode;
  int? customerId;
  String? customerName;
  String? customerType;
  String? customerNationalId;
  String? customerEconomicNumber;
  String? customerPhone;
  String? customerPostalCode;
  String? customerAddress;
  String? fiscalYearId;
  String? fiscalYearName;
  DateTime? dateStartFiscalYear;
  DateTime? dateEndFiscalYear;
  String typePattern;
  DateTime? dateOrder;
  String? name;
  String paymentType;
  String? description;
  String? statusSentToSystem;
  String? statusSentToSystemInt;
  String? taxNumber;
  String? newTaxNumber;
  String? referenceId;
  double totalMoney;
  String? subject;
  bool showButtons;
  bool isNew;
  double priceNaghd;
  double priceNesye;
  List<MoadianInvoiceItem> invoiceItems;

  String? get buyerNationalId => customerNationalId;
  String? get buyerEconomicNo => customerEconomicNumber;
  String? get buyerPostalCode => customerPostalCode;
  String? get buyerPhone => customerPhone;
  String? get buyerAddress => customerAddress;

  /// شناسهٔ واقعی رکورد با پشتیبانی از رکوردهای قدیمی که شناسه را در `Name` نگه می‌داشتند.
  int get effectiveId {
    if (id > 0) return id;
    final parsed = int.tryParse(name ?? '');
    return (parsed != null && parsed > 0) ? parsed : 0;
  }

  /// کد عددی وضعیت (`0` تا `11`) هم‌تراز با `MoadianUi.cs`.
  String get statusCode {
    final sInt = statusSentToSystemInt?.trim() ?? '';
    if (RegExp(r'^\d+$').hasMatch(sInt)) return sInt;
    final sRaw = statusSentToSystem?.trim() ?? '';
    if (RegExp(r'^\d+$').hasMatch(sRaw)) return sRaw;
    return switch (sRaw) {
      'ارسال نشده' => '0',
      'ارسال شده در انتظار استعلام' => '1',
      'در انتظار بررسی کارپوشه' || 'عدم پاسخگویی سامانه' => '2',
      'ارسال شده' => '3',
      'ارسال شده در انتظار واکنش' || 'در انتظار واکنش' || 'درانتظار واکنش' =>
        '4',
      'دارای خطا' => '5',
      'بدون نیاز به واکنش' => '6',
      'تأیید شده' || 'تایید شده' => '7',
      'رد شده' => '8',
      'باطل' => '9',
      'اصلاحی' => '10',
      'تأیید سیستمی' || 'تایید سیستمی' => '11',
      _ => '0',
    };
  }

  bool get isNoBuyerType =>
      typePattern.contains('دوم') ||
      typePattern.contains('سوم') ||
      typePattern.trim() == '2' ||
      typePattern.trim() == '3';

  factory MoadianInvoice.fromJson(Map<String, dynamic> j) {
    dynamic pick(String a, String b) => j.containsKey(a) ? j[a] : j[b];
    DateTime? parseDate(dynamic v) {
      final s = v?.toString().trim() ?? '';
      if (s.isEmpty) return null;
      return DateTime.tryParse(s);
    }

    final rawId =
        j['id'] ?? j['Id'] ?? j['invoiceID'] ?? j['invoiceId'] ?? j['InvoiceID'];
    final rawCustId =
        j['customerId'] ?? j['CustomerId'] ?? j['customerID'] ?? j['CustomerID'];
    final rawTotal =
        j['totallMoney'] ??
        j['TotallMoney'] ??
        j['totalMoney'] ??
        j['TotalMoney'];
    final rawItems =
        (pick('invoiceItems', 'InvoiceItems') as List? ?? const []);

    return MoadianInvoice(
      id: (rawId as num?)?.toInt() ?? 0,
      numberInvoice: (pick('numberInvoice', 'NumberInvoice') as num?)?.toInt(),
      cpInfoId:
          ((j['cpInfoId'] ?? j['CPInfoId'] ?? j['cpinfoid']) as num?)?.toInt(),
      persianName: pick('persianName', 'PersianName')?.toString(),
      sellerNationalId:
          (j['sellerNationalId'] ??
                  j['SellerNationalId'] ??
                  j['cpNationalId'] ??
                  j['nationalid'])
              ?.toString(),
      sellerEconomicNo:
          (j['sellerEconomicNo'] ??
                  j['SellerEconomicNo'] ??
                  j['cpEconomicNumber'] ??
                  j['economicNumber'])
              ?.toString(),
      sellerPostalCode:
          (j['sellerPostalCode'] ?? j['SellerPostalCode'] ?? j['cpPostalCode'])
              ?.toString(),
      customerId: (rawCustId as num?)?.toInt(),
      customerName: pick('customerName', 'CustomerName')?.toString(),
      customerType: pick('customerType', 'CustomerType')?.toString(),
      customerNationalId:
          (j['customerNationalId'] ??
                  j['CustomerNationalId'] ??
                  j['buyerNationalId'])
              ?.toString(),
      customerEconomicNumber:
          (j['customerEconomicNumber'] ??
                  j['CustomerEconomicNumber'] ??
                  j['buyerEconomicNo'])
              ?.toString(),
      customerPhone:
          (j['customerPhone'] ?? j['CustomerPhone'] ?? j['buyerPhone'])
              ?.toString(),
      customerPostalCode:
          (j['customerPostalCode'] ??
                  j['CustomerPostalCode'] ??
                  j['buyerPostalCode'])
              ?.toString(),
      customerAddress:
          (j['customerAddress'] ?? j['CustomerAddress'] ?? j['buyerAddress'])
              ?.toString(),
      fiscalYearId:
          (j['fiscalYearId'] ?? j['FiscalYearId'] ?? j['fiscalYearID'])
              ?.toString(),
      fiscalYearName: pick('fiscalYearName', 'FiscalYearName')?.toString(),
      dateStartFiscalYear: parseDate(
        pick('datestartFiscalYear', 'DatestartFiscalYear'),
      ),
      dateEndFiscalYear: parseDate(
        pick('dateEndFiscalYear', 'DateEndFiscalYear'),
      ),
      typePattern:
          (pick('typePattern', 'TypePattern')?.toString().trim().isNotEmpty ==
              true)
          ? pick('typePattern', 'TypePattern')!.toString().trim()
          : 'نوع اول',
      dateOrder:
          parseDate(pick('dateOrder', 'DateOrder')) ??
          parseDate(pick('dateOrderPicker', 'DateOrderPicker')),
      name: pick('name', 'Name')?.toString(),
      paymentType:
          (pick('paymentType', 'PaymentType')?.toString().trim().isNotEmpty ==
              true)
          ? pick('paymentType', 'PaymentType')!.toString().trim()
          : 'نقدی',
      description: pick('description', 'Description')?.toString(),
      statusSentToSystem:
          pick('statusSentToSystem', 'StatusSentToSystem')?.toString(),
      statusSentToSystemInt:
          pick('statusSentToSystemInt', 'StatusSentToSystemInt')?.toString(),
      taxNumber: pick('taxNumber', 'TaxNumber')?.toString(),
      newTaxNumber: pick('newTaxNumber', 'NewTaxNumber')?.toString(),
      referenceId: pick('referenceId', 'ReferenceId')?.toString(),
      totalMoney: (rawTotal as num?)?.toDouble() ?? 0,
      subject: pick('subject', 'Subject')?.toString() ?? 'اصلی',
      showButtons: pick('showButtons', 'ShowButtons') != false,
      isNew: pick('isNew', 'IsNew') == true,
      priceNaghd: (pick('priceNaghd', 'PriceNaghd') as num?)?.toDouble() ?? 0,
      priceNesye: (pick('priceNesye', 'PriceNesye') as num?)?.toDouble() ?? 0,
      items: rawItems
          .whereType<Map>()
          .map((e) => MoadianInvoiceItem.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }

  Map<String, dynamic> toJson({String? overrideSubject}) {
    final dt = dateOrder ?? DateTime.now();
    final dateOnly = _dateOnly(dt);
    return {
      'id': effectiveId,
      if (numberInvoice != null) 'numberInvoice': numberInvoice,
      'cPInfoId': cpInfoId,
      'customerId': isNoBuyerType ? null : customerId,
      'customerName': customerName,
      'fiscalYearId': fiscalYearId,
      'typePattern': typePattern,
      'dateOrder': dateOnly,
      'paymentType': isNoBuyerType ? 'نقدی' : paymentType,
      'description': description,
      'statusSentToSystem': statusSentToSystem ?? statusCode,
      'statusSentToSystemInt': statusSentToSystemInt ?? statusCode,
      'taxNumber': taxNumber,
      'newTaxNumber': newTaxNumber,
      'referenceId': referenceId,
      'totallMoney': totalMoney,
      'subject': overrideSubject ?? subject ?? 'اصلی',
      'showButtons': showButtons,
      'isNew': isNew,
      'priceNaghd': priceNaghd,
      'priceNesye': priceNesye,
      'invoiceItems': invoiceItems.map((e) => e.toJson()).toList(),
    };
  }
}

/// جزئیات خطای برگشتی استعلام سامانه مودیان (`ErroreMesage`).
class MoadianErrorInfo {
  const MoadianErrorInfo({
    this.code,
    this.status,
    this.message,
    this.errorsAndWarnings,
  });

  final String? code;
  final String? status;
  final String? message;
  final String? errorsAndWarnings;

  String get displayMessage {
    final parts = [
      if ((code ?? '').trim().isNotEmpty) 'کد خطا: ${code!.trim()}',
      if ((errorsAndWarnings ?? '').trim().isNotEmpty)
        errorsAndWarnings!.trim(),
      if ((message ?? '').trim().isNotEmpty &&
          message!.trim() != errorsAndWarnings?.trim())
        message!.trim(),
    ];
    return parts.isEmpty
        ? 'جزئیات خطای متنی از سوی سامانه مودیان ثبت نشده است.'
        : parts.join('\n');
  }

  bool get hasAny =>
      (code?.trim().isNotEmpty == true) ||
      (message?.trim().isNotEmpty == true) ||
      (errorsAndWarnings?.trim().isNotEmpty == true);

  factory MoadianErrorInfo.fromJson(dynamic raw) {
    if (raw is! Map) return const MoadianErrorInfo();
    final j = Map<String, dynamic>.from(raw);
    return MoadianErrorInfo(
      code: (j['code'] ?? j['Code'])?.toString(),
      status: (j['status'] ?? j['Status'] ?? j['code'] ?? j['Code'])
          ?.toString(),
      message: (j['message'] ?? j['Message'])?.toString(),
      errorsAndWarnings:
          (j['errorsAndWarnings'] ?? j['ErrorsAndWarnings'])?.toString(),
    );
  }
}

/// ردیف گزارش عیب‌یاب اسکیمای مودیان (`DiagnoseRow`).
class MoadianDiagnoseRow {
  const MoadianDiagnoseRow({
    required this.table,
    required this.exists,
    required this.columns,
    this.missing = const [],
    this.totalRows,
    this.activeRows,
    this.linkage,
    this.warning,
    this.error,
  });

  final String table;
  final bool exists;
  final int columns;
  final List<String> missing;
  final int? totalRows;
  final int? activeRows;
  final String? linkage;
  final String? warning;
  final String? error;

  factory MoadianDiagnoseRow.fromJson(Map<String, dynamic> j) {
    dynamic pick(String a, String b) => j.containsKey(a) ? j[a] : j[b];
    return MoadianDiagnoseRow(
      table: pick('table', 'Table')?.toString() ?? '',
      exists: pick('exists', 'Exists') == true,
      columns: (pick('columns', 'Columns') as num?)?.toInt() ?? 0,
      missing: (pick('missing', 'Missing') as List? ?? const [])
          .map((e) => e.toString())
          .toList(),
      totalRows: (pick('totalRows', 'TotalRows') as num?)?.toInt(),
      activeRows: (pick('activeRows', 'ActiveRows') as num?)?.toInt(),
      linkage: pick('linkage', 'Linkage')?.toString(),
      warning: pick('warning', 'Warning')?.toString(),
      error: pick('error', 'Error')?.toString(),
    );
  }
}

String _dateOnly(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

String _isoDate(DateTime d) => '${_dateOnly(d)}T00:00:00';
