import 'package:flutter_test/flutter_test.dart';
import 'package:icteach/widgets/principal_workspace_shell.dart';

void main() {
  test('school profile is available through principal settings only', () {
    expect(principalPanelLabels, contains('Settings'));
    expect(principalPanelLabels, isNot(contains('School Profile')));
  });

  test('saved school profile destination migrates to settings', () {
    expect(normalizePrincipalPanelSelection('School Profile'), 'Settings');
    expect(normalizePrincipalPanelSelection('Settings'), 'Settings');
  });

  test('obsolete and unknown principal destinations return to dashboard', () {
    expect(normalizePrincipalPanelSelection('LRN Registry'), 'Dashboard');
    expect(normalizePrincipalPanelSelection('Unknown'), 'Dashboard');
    expect(normalizePrincipalPanelSelection(null), 'Dashboard');
  });
}
