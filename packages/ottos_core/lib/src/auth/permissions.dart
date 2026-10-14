/// Permission codes defined by the backend (`permissions` table).
abstract final class Permissions {
  static const usersRead = 'users:read';
  static const usersWrite = 'users:write';
  static const rolesRead = 'roles:read';
  static const rolesWrite = 'roles:write';

  /// Only for quotes (`POST /quotes`).
  static const ratesRead = 'rates:read';
  static const configurationRead = 'configuration:read';
  static const configurationWrite = 'configuration:write';
  static const customersRead = 'customers:read';
  static const customersWrite = 'customers:write';
  static const customersExport = 'customers:export';
  static const customersImport = 'customers:import';
  static const remittancesCreate = 'remittances:create';
  static const remittancesRead = 'remittances:read';
  static const remittancesReadAssigned = 'remittances:read-assigned';
  static const remittancesReadFinancials = 'remittances:read-financials';
  static const remittancesAssign = 'remittances:assign';
  static const remittancesPostpone = 'remittances:postpone';
  static const remittancesDeliver = 'remittances:deliver';
  static const remittancesReportIncident = 'remittances:report-incident';
  static const remittancesReview = 'remittances:review';
  static const remittancesVoid = 'remittances:void';
  static const remittancesHistorical = 'remittances:historical';
  static const remittancesCompleteFromBusiness = 'remittances:complete-from-business';
  static const auditRead = 'audit:read';
  static const reportsRead = 'reports:read';
  static const cashRead = 'cash:read';
  static const cashWrite = 'cash:write';
  static const cashReadOwn = 'cash:read-own';
  static const cashAdjust = 'cash:adjust';
  static const cashExchangeOwn = 'cash:exchange-own';
  static const cashReview = 'cash:review';
}
