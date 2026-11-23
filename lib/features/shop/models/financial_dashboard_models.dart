// ============================================================
//  مدل‌های «داشبورد مالی» وب (`AdminHome.razor` + `DashboardController.cs`)
//  منبع دقیق سمت سرور: `Inventory.Shared/Dtos/OperationDtos.cs` (خطوط ۵۰۰ تا ۶۲۰)
//    • GET  /api/dashboard                         → DashboardSummaryDto
//    • GET  /api/dashboard/admin                   → AdminDashboardDto
//    • GET  /api/dashboard/recent?count=8          → List<RecentActivityDto>
//    • POST /api/dashboard/credits/{id}/settle     → تسویه نسیه/اعتبار مشتری
// ============================================================

double _asDouble(dynamic v) {
  if (v is num) return v.toDouble();
  return double.tryParse(v?.toString() ?? '') ?? 0;
}

int _asInt(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v?.toString() ?? '') ?? 0;
}

DateTime _asDate(dynamic v) =>
    DateTime.tryParse(v?.toString() ?? '') ?? DateTime.now();

/// خلاصهٔ عملیاتی فروشگاه (`DashboardSummary` — `GET /api/dashboard`)
class DashboardSummaryDto {
  const DashboardSummaryDto({
    this.productCount = 0,
    this.warehouseCount = 0,
    this.customerCount = 0,
    this.supplierCount = 0,
    this.belowReorderCount = 0,
    this.inventoryValue = 0,
    this.todaySales = 0,
    this.todayPurchases = 0,
    this.monthSales = 0,
    this.monthPurchases = 0,
    this.lowStockThreshold = 0,
  });

  final int productCount;
  final int warehouseCount;
  final int customerCount;
  final int supplierCount;
  final int belowReorderCount;
  final double inventoryValue;
  final double todaySales;
  final double todayPurchases;
  final double monthSales;
  final double monthPurchases;
  final int lowStockThreshold;

  factory DashboardSummaryDto.fromJson(Map<String, dynamic> j) =>
      DashboardSummaryDto(
        productCount: _asInt(j['productCount'] ?? j['ProductCount']),
        warehouseCount: _asInt(j['warehouseCount'] ?? j['WarehouseCount']),
        customerCount: _asInt(j['customerCount'] ?? j['CustomerCount']),
        supplierCount: _asInt(j['supplierCount'] ?? j['SupplierCount']),
        belowReorderCount: _asInt(
          j['belowReorderCount'] ?? j['BelowReorderCount'],
        ),
        inventoryValue: _asDouble(j['inventoryValue'] ?? j['InventoryValue']),
        todaySales: _asDouble(j['todaySales'] ?? j['TodaySales']),
        todayPurchases: _asDouble(j['todayPurchases'] ?? j['TodayPurchases']),
        monthSales: _asDouble(j['monthSales'] ?? j['MonthSales']),
        monthPurchases: _asDouble(j['monthPurchases'] ?? j['MonthPurchases']),
        lowStockThreshold: _asInt(
          j['lowStockThreshold'] ?? j['LowStockThreshold'],
        ),
      );
}

/// نقطهٔ نمودار روند (`TrendPoint`)
class FinancialTrendPoint {
  const FinancialTrendPoint({
    required this.label,
    required this.sales,
    this.profit = 0,
  });

  final String label;
  final double sales;
  final double profit;

  factory FinancialTrendPoint.fromJson(Map<String, dynamic> j) =>
      FinancialTrendPoint(
        label: (j['label'] ?? j['Label'] ?? '').toString(),
        sales: _asDouble(j['sales'] ?? j['Sales']),
        profit: _asDouble(j['profit'] ?? j['Profit']),
      );
}

/// بدهکار سررسیدشده (`DebtorItem`)
class OverdueDebtorDto {
  const OverdueDebtorDto({
    required this.partyId,
    required this.partyName,
    this.mobile,
    required this.number,
    required this.transactionId,
    required this.kind,
    required this.amount,
    required this.dueDate,
    required this.daysOverdue,
  });

  final int partyId;
  final String partyName;
  final String? mobile;
  final String number;
  final int transactionId;
  final String kind;
  final double amount;
  final DateTime dueDate;
  final int daysOverdue;

  factory OverdueDebtorDto.fromJson(Map<String, dynamic> j) => OverdueDebtorDto(
    partyId: _asInt(j['partyId'] ?? j['PartyId']),
    partyName: (j['partyName'] ?? j['PartyName'] ?? '').toString(),
    mobile: (j['mobile'] ?? j['Mobile'])?.toString(),
    number: (j['number'] ?? j['Number'] ?? '').toString(),
    transactionId: _asInt(j['transactionId'] ?? j['TransactionId']),
    kind: (j['kind'] ?? j['Kind'] ?? 'نسیه').toString(),
    amount: _asDouble(j['amount'] ?? j['Amount']),
    dueDate: _asDate(j['dueDate'] ?? j['DueDate']),
    daysOverdue: _asInt(j['daysOverdue'] ?? j['DaysOverdue']),
  );
}

/// هشدار چک دریافتی یا پرداختی سررسیدشده (`ChequeAlertItem`)
class ChequeAlertDto {
  const ChequeAlertDto({
    this.source = 'Invoice',
    required this.chequeId,
    required this.number,
    this.bankName,
    this.ownerName,
    required this.partyName,
    this.orderNumber = '',
    required this.amount,
    required this.dueDate,
    this.status = 0,
    this.bounceReason,
  });

  /// `Invoice`، `Treasury` یا `Expense` — شناسه‌ها بین منابع مشترک نیستند!
  final String source;
  final int chequeId;
  final String number;
  final String? bankName;
  final String? ownerName;
  final String partyName;
  final String orderNumber;
  final double amount;
  final DateTime dueDate;

  /// `0 = InHand/Pending`، `1 = Cleared`، `2 = Bounced`
  final int status;
  final String? bounceReason;

  bool get isInvoiceSource => source.trim().toLowerCase() == 'invoice';
  bool get isBounced => status == 2;

  int daysPastDue(DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    final due = DateTime(dueDate.year, dueDate.month, dueDate.day);
    final diff = today.difference(due).inDays;
    return diff > 0 ? diff : 0;
  }

  static int _parseStatus(dynamic raw) {
    if (raw is num) return raw.toInt();
    final s = raw?.toString().trim().toLowerCase() ?? '';
    return switch (s) {
      'bounced' || '2' => 2,
      'cleared' || '1' => 1,
      _ => 0,
    };
  }

  factory ChequeAlertDto.fromJson(Map<String, dynamic> j) => ChequeAlertDto(
    source: (j['source'] ?? j['Source'] ?? 'Invoice').toString(),
    chequeId: _asInt(j['chequeId'] ?? j['ChequeId']),
    number: (j['number'] ?? j['Number'] ?? '').toString(),
    bankName: (j['bankName'] ?? j['BankName'])?.toString(),
    ownerName: (j['ownerName'] ?? j['OwnerName'])?.toString(),
    partyName: (j['partyName'] ?? j['PartyName'] ?? '').toString(),
    orderNumber: (j['orderNumber'] ?? j['OrderNumber'] ?? '').toString(),
    amount: _asDouble(j['amount'] ?? j['Amount']),
    dueDate: _asDate(j['dueDate'] ?? j['DueDate']),
    status: _parseStatus(j['status'] ?? j['Status']),
    bounceReason: (j['bounceReason'] ?? j['BounceReason'])?.toString(),
  );
}

/// فعالیت اخیر خرید/فروش/اصلاح موجودی (`RecentActivity` — `GET /api/dashboard/recent`)
class RecentActivityDto {
  const RecentActivityDto({
    required this.date,
    required this.type,
    required this.number,
    required this.partyName,
    required this.amount,
  });

  final DateTime date;
  final String type;
  final String number;
  final String partyName;
  final double amount;

  String get typeLabel => switch (type.trim()) {
    'Sale' => 'فروش',
    'Purchase' => 'خرید',
    _ => 'اصلاح موجودی',
  };

  factory RecentActivityDto.fromJson(Map<String, dynamic> j) =>
      RecentActivityDto(
        date: _asDate(j['date'] ?? j['Date']),
        type: (j['type'] ?? j['Type'] ?? '').toString(),
        number: (j['number'] ?? j['Number'] ?? '').toString(),
        partyName: (j['partyName'] ?? j['PartyName'] ?? '').toString(),
        amount: _asDouble(j['amount'] ?? j['Amount']),
      );
}

/// داشبورد مالی/مدیریتی (`AdminDashboard` — `GET /api/dashboard/admin`)
class AdminDashboardDto {
  const AdminDashboardDto({
    this.pendingReceivedChequesCount = 0,
    this.pendingIssuedChequesCount = 0,
    this.salesToday = 0,
    this.salesWeek = 0,
    this.salesMonth = 0,
    this.salesQuarter = 0,
    this.profitToday = 0,
    this.profitWeek = 0,
    this.profitMonth = 0,
    this.profitQuarter = 0,
    this.overdueDebtors = const [],
    this.todayCheques = const [],
    this.issuedCheques = const [],
    this.dailyTrend = const [],
    this.monthlyTrend = const [],
    this.payCash = 0,
    this.payCredit = 0,
    this.payCheque = 0,
    this.payInstallment = 0,
  });

  final int pendingReceivedChequesCount;
  final int pendingIssuedChequesCount;

  final double salesToday;
  final double salesWeek;
  final double salesMonth;
  final double salesQuarter;

  final double profitToday;
  final double profitWeek;
  final double profitMonth;
  final double profitQuarter;

  final List<OverdueDebtorDto> overdueDebtors;
  final List<ChequeAlertDto> todayCheques;
  final List<ChequeAlertDto> issuedCheques;
  final List<FinancialTrendPoint> dailyTrend;
  final List<FinancialTrendPoint> monthlyTrend;

  final double payCash;
  final double payCredit;
  final double payCheque;
  final double payInstallment;

  double get totalPayMix => payCash + payCredit + payCheque + payInstallment;

  static List<T> _listOf<T>(
    dynamic raw,
    T Function(Map<String, dynamic>) fromMap,
  ) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((e) => fromMap(Map<String, dynamic>.from(e)))
        .toList();
  }

  factory AdminDashboardDto.fromJson(Map<String, dynamic> j) =>
      AdminDashboardDto(
        pendingReceivedChequesCount: _asInt(
          j['pendingReceivedChequesCount'] ?? j['PendingReceivedChequesCount'],
        ),
        pendingIssuedChequesCount: _asInt(
          j['pendingIssuedChequesCount'] ?? j['PendingIssuedChequesCount'],
        ),
        salesToday: _asDouble(j['salesToday'] ?? j['SalesToday']),
        salesWeek: _asDouble(j['salesWeek'] ?? j['SalesWeek']),
        salesMonth: _asDouble(j['salesMonth'] ?? j['SalesMonth']),
        salesQuarter: _asDouble(j['salesQuarter'] ?? j['SalesQuarter']),
        profitToday: _asDouble(j['profitToday'] ?? j['ProfitToday']),
        profitWeek: _asDouble(j['profitWeek'] ?? j['ProfitWeek']),
        profitMonth: _asDouble(j['profitMonth'] ?? j['ProfitMonth']),
        profitQuarter: _asDouble(j['profitQuarter'] ?? j['ProfitQuarter']),
        overdueDebtors: _listOf(
          j['overdueDebtors'] ?? j['OverdueDebtors'],
          OverdueDebtorDto.fromJson,
        ),
        todayCheques: _listOf(
          j['todayCheques'] ?? j['TodayCheques'],
          ChequeAlertDto.fromJson,
        ),
        issuedCheques: _listOf(
          j['issuedCheques'] ?? j['IssuedCheques'],
          ChequeAlertDto.fromJson,
        ),
        dailyTrend: _listOf(
          j['dailyTrend'] ?? j['DailyTrend'],
          FinancialTrendPoint.fromJson,
        ),
        monthlyTrend: _listOf(
          j['monthlyTrend'] ?? j['MonthlyTrend'],
          FinancialTrendPoint.fromJson,
        ),
        payCash: _asDouble(j['payCash'] ?? j['PayCash']),
        payCredit: _asDouble(j['payCredit'] ?? j['PayCredit']),
        payCheque: _asDouble(j['payCheque'] ?? j['PayCheque']),
        payInstallment: _asDouble(j['payInstallment'] ?? j['PayInstallment']),
      );
}
