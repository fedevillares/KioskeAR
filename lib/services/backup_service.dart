import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import '../utils/app_logger.dart';
import '../models/product.dart';
import '../models/sale.dart';
import '../services/storage_service.dart';

class BackupService {
  // Crear backup completo en JSON
  static Future<File?> createBackup(String kioscoId) async {
    try {
      // Cargar datos
      final products = await StorageService.loadProducts(kioscoId);
      final sales = await StorageService.loadSales(kioscoId);
      
      // Crear estructura de backup
      final backup = {
        'version': '1.0.0',
        'created_at': DateTime.now().toIso8601String(),
        'app': 'Kioske.AR',
        'data': {
          'products': products.map((p) => p.toJson()).toList(),
          'sales': sales.map((s) => s.toJson()).toList(),
        },
        'summary': {
          'total_products': products.length,
          'total_sales': sales.length,
          'total_value': products.fold<double>(0, (sum, p) => sum + p.totalValue),
        }
      };
      
      // Convertir a JSON
      final jsonString = const JsonEncoder.withIndent('  ').convert(backup);
      
      // Guardar archivo
      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final fileName = 'kiosco_backup_$timestamp.json';
      final file = File('${directory.path}/$fileName');
      
      await file.writeAsString(jsonString);
      
      debugLog('✅ Backup creado: ${file.path}');
      return file;
    } catch (e) {
      debugLog('❌ Error creando backup: $e');
      return null;
    }
  }

  // Crear backup en formato CSV (Excel-compatible)
  static Future<File?> createExcelBackup(String kioscoId) async {
    try {
      final products = await StorageService.loadProducts(kioscoId);
      final sales = await StorageService.loadSales(kioscoId);
      
      // CSV de productos
      final productsCSV = StringBuffer();
      productsCSV.writeln('ID,Nombre,Categoría,Stock,Precio,Costo,Stock Mínimo,Última Actualización');
      
      for (var product in products) {
        final lastUpdated = product.lastUpdated ?? DateTime.now();
        productsCSV.writeln(
          '${product.id},'
          '"${product.name}",'
          '${product.category},'
          '${product.stock},'
          '${product.price},'
          '${product.costPrice},'
          '${product.minStock},'
          '${DateFormat('yyyy-MM-dd HH:mm').format(lastUpdated)}'
        );
      }
      
      // CSV de ventas
      final salesCSV = StringBuffer();
      salesCSV.writeln('ID,Producto ID,Producto,Cantidad,Precio Unitario,Total,Fecha');
      
      for (var sale in sales) {
        salesCSV.writeln(
          '${sale.id},'
          '${sale.productId},'
          '"${sale.productName}",'
          '${sale.quantity},'
          '${sale.pricePerUnit},'
          '${sale.totalPrice},'
          '${DateFormat('yyyy-MM-dd HH:mm').format(sale.timestamp)}'
        );
      }
      
      // Guardar archivos
      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      
      final productsFile = File('${directory.path}/productos_$timestamp.csv');
      final salesFile = File('${directory.path}/ventas_$timestamp.csv');
      
      await productsFile.writeAsString(productsCSV.toString());
      await salesFile.writeAsString(salesCSV.toString());
      
      debugLog('✅ Backup CSV creado');
      debugLog('   Productos: ${productsFile.path}');
      debugLog('   Ventas: ${salesFile.path}');
      
      return productsFile; // Retornar el primero
    } catch (e) {
      debugLog('❌ Error creando backup CSV: $e');
      return null;
    }
  }

  // Compartir backup
  static Future<void> shareBackup(String filePath) async {
    try {
      final file = XFile(filePath);
      await Share.shareXFiles(
        [file],
        subject: 'Backup Kioske.AR',
        text: 'Backup de datos - ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}',
      );
      debugLog('✅ Compartiendo backup: $filePath');
    } catch (e) {
      debugLog('❌ Error compartiendo backup: $e');
    }
  }

  // Compartir múltiples archivos (productos + ventas CSV)
  static Future<void> shareMultipleBackups(List<String> filePaths) async {
    try {
      final files = filePaths.map((path) => XFile(path)).toList();
      await Share.shareXFiles(
        files,
        subject: 'Backup Kioske.AR - Datos Completos',
        text: 'Backup de productos y ventas - ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}',
      );
      debugLog('✅ Compartiendo ${files.length} archivos');
    } catch (e) {
      debugLog('❌ Error compartiendo archivos: $e');
    }
  }

  // Restaurar desde backup
  static Future<bool> restoreBackup(String filePath, String kioscoId) async {
    try {
      final file = File(filePath);
      
      if (!await file.exists()) {
        debugLog('❌ Archivo no existe: $filePath');
        return false;
      }
      
      final jsonString = await file.readAsString();
      final backup = json.decode(jsonString);
      
      // Validar estructura
      if (!backup.containsKey('data')) {
        throw Exception('Formato de backup inválido');
      }
      
      // Restaurar productos
      if (backup['data']['products'] != null) {
        final products = (backup['data']['products'] as List)
            .map((p) => Product.fromJson(p))
            .toList();
        await StorageService.saveProducts(kioscoId, products);
        debugLog('✅ ${products.length} productos restaurados');
      }

      // Restaurar ventas
      if (backup['data']['sales'] != null) {
        final sales = (backup['data']['sales'] as List)
            .map((s) => Sale.fromJson(s))
            .toList();
        await StorageService.saveSales(kioscoId, sales);
        debugLog('✅ ${sales.length} ventas restauradas');
      }
      
      debugLog('✅ Backup restaurado exitosamente');
      return true;
    } catch (e) {
      debugLog('❌ Error restaurando backup: $e');
      return false;
    }
  }

  // Obtener lista de backups disponibles
  static Future<List<FileSystemEntity>> getAvailableBackups() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      
      if (!await directory.exists()) {
        return [];
      }
      
      final entities = await directory.list().toList();
      final files = entities
          .where((file) =>
              file.path.contains('kiosco_backup_') ||
              file.path.contains('productos_') ||
              file.path.contains('ventas_'))
          .toList();
      
      // Ordenar por fecha (más reciente primero)
      files.sort((a, b) => b.path.compareTo(a.path));
      
      debugLog('📋 ${files.length} backups encontrados');
      return files;
    } catch (e) {
      debugLog('❌ Error listando backups: $e');
      return [];
    }
  }

  // Eliminar backup
  static Future<bool> deleteBackup(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
        debugLog('✅ Backup eliminado: $filePath');
        return true;
      }
      debugLog('⚠️  Archivo no existe: $filePath');
      return false;
    } catch (e) {
      debugLog('❌ Error eliminando backup: $e');
      return false;
    }
  }

  // Eliminar backups antiguos
  static Future<int> cleanOldBackups({int keepLast = 30}) async {
    try {
      final backups = await getAvailableBackups();
      int deleted = 0;
      
      if (backups.length > keepLast) {
        for (var i = keepLast; i < backups.length; i++) {
          if (await deleteBackup(backups[i].path)) {
            deleted++;
          }
        }
      }
      
      debugLog('✅ $deleted backups antiguos eliminados');
      return deleted;
    } catch (e) {
      debugLog('❌ Error limpiando backups: $e');
      return 0;
    }
  }

  // Backup automático (llamar diariamente)
  static Future<void> autoBackup(String kioscoId) async {
    try {
      debugLog('🔄 Iniciando backup automático...');

      // Verificar si ya se hizo backup hoy
      final backups = await getAvailableBackups();
      final today = DateFormat('yyyyMMdd').format(DateTime.now());

      final hasBackupToday = backups.any((file) {
        final fileName = file.path.split('/').last;
        return fileName.contains(today);
      });

      if (!hasBackupToday) {
        final file = await createBackup(kioscoId);
        if (file != null) {
          debugLog('✅ Backup automático creado: ${file.path}');
        }
      } else {
        debugLog('ℹ️  Ya existe backup de hoy');
      }
      
      // Limpiar backups antiguos (mantener solo últimos 30)
      await cleanOldBackups(keepLast: 30);
      
    } catch (e) {
      debugLog('❌ Error en backup automático: $e');
    }
  }

  // Obtener información del backup
  static Future<Map<String, dynamic>?> getBackupInfo(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) return null;
      
      final jsonString = await file.readAsString();
      final backup = json.decode(jsonString);
      
      return {
        'version': backup['version'] ?? 'Unknown',
        'created_at': backup['created_at'] ?? 'Unknown',
        'total_products': backup['summary']?['total_products'] ?? 0,
        'total_sales': backup['summary']?['total_sales'] ?? 0,
        'total_value': backup['summary']?['total_value'] ?? 0.0,
      };
    } catch (e) {
      debugLog('❌ Error leyendo info del backup: $e');
      return null;
    }
  }

  // Verificar integridad del backup
  static Future<bool> verifyBackup(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) return false;
      
      final jsonString = await file.readAsString();
      final backup = json.decode(jsonString);
      
      // Verificar estructura básica
      if (!backup.containsKey('version')) return false;
      if (!backup.containsKey('data')) return false;
      if (!backup['data'].containsKey('products')) return false;
      if (!backup['data'].containsKey('sales')) return false;
      
      debugLog('✅ Backup verificado correctamente');
      return true;
    } catch (e) {
      debugLog('❌ Error verificando backup: $e');
      return false;
    }
  }

  // Obtener tamaño del backup
  static Future<int> getBackupSize(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        return await file.length();
      }
      return 0;
    } catch (e) {
      debugLog('❌ Error obteniendo tamaño: $e');
      return 0;
    }
  }

  // Formatear tamaño en KB/MB
  static String formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}