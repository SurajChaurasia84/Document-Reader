import 'package:flutter/widgets.dart';
import 'services/ad_service.dart';
import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await AdService.init();

  runApp(const DocReaderApp());
}
