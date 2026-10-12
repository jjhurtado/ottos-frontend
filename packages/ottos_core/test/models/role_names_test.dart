import 'package:flutter_test/flutter_test.dart';
import 'package:ottos_core/ottos_core.dart';

void main() {
  test('system roles show in Spanish while they keep the original English text', () {
    const admin = Role(id: 'r1', code: 'ADMIN', name: 'Administrator', description: 'Full access to the system');
    const sales = RoleSummary(id: 'r2', code: 'SALES', name: 'Sales');

    expect(admin.displayName, 'Administrador');
    expect(admin.displayDescription, 'Acceso completo al sistema');
    expect(sales.displayName, 'Ventas');
    expect(CoreTexts.roleName('DELIVERY', 'Delivery'), 'Repartidor');
  });

  test('a renamed system role and a custom role show as typed', () {
    const renamed = Role(id: 'r2', code: 'SALES', name: 'Vendedores', description: 'Atienden el mostrador');
    const custom = Role(id: 'r4', code: 'SUPERVISOR', name: 'Supervisor', description: 'Revisa el día');

    expect(renamed.displayName, 'Vendedores');
    expect(renamed.displayDescription, 'Atienden el mostrador');
    expect(custom.displayName, 'Supervisor');
    expect(CoreTexts.roleDescription('SUPERVISOR', null), isNull);
  });
}
