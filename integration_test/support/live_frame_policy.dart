import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void configureAvContractLiveFramePolicy() {
  final IntegrationTestWidgetsFlutterBinding binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.benchmarkLive;
}
