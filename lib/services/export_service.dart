import 'dart:typed_data';
import 'package:excel/excel.dart' as xl;
import 'package:file_saver/file_saver.dart';
import 'package:intl/intl.dart';
import '../models/transaction.dart';

/// 정산 리포트(엑셀) 생성 서비스
class ExportService {
  /// 거래 내역 리스트를 받아 xlsx 바이트 데이터를 생성
  /// 컬럼: 날짜, 시간, 사용처, 금액, 계정과목, 상세내용, 공동사용자
  static List<int> buildExcelBytes(
    List<CardTransaction> transactions, {
    String sheetName = '법인카드 정산내역',
  }) {
    final excel = xl.Excel.createExcel();
    final defaultSheetName = excel.getDefaultSheet();
    excel.rename(defaultSheetName!, sheetName);
    final sheet = excel[sheetName];

    final headerStyle = xl.CellStyle(
      bold: true,
      backgroundColorHex: xl.ExcelColor.fromHexString('#3F51B5'),
      fontColorHex: xl.ExcelColor.fromHexString('#FFFFFF'),
      horizontalAlign: xl.HorizontalAlign.Center,
      verticalAlign: xl.VerticalAlign.Center,
    );

    final headers = ['날짜', '시간', '사용처', '금액', '계정과목', '상세내용', '공동사용자'];

    for (int i = 0; i < headers.length; i++) {
      final cell = sheet.cell(
        xl.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0),
      );
      cell.value = xl.TextCellValue(headers[i]);
      cell.cellStyle = headerStyle;
    }

    final dateFmt = DateFormat('yyyy-MM-dd');
    final timeFmt = DateFormat('HH:mm');

    double total = 0;
    for (int r = 0; r < transactions.length; r++) {
      final tx = transactions[r];
      final rowIndex = r + 1;
      total += tx.amount;

      sheet
          .cell(
            xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex),
          )
          .value = xl.TextCellValue(
        dateFmt.format(tx.dateTime),
      );
      sheet
          .cell(
            xl.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex),
          )
          .value = xl.TextCellValue(
        timeFmt.format(tx.dateTime),
      );
      sheet
          .cell(
            xl.CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: rowIndex),
          )
          .value = xl.TextCellValue(
        tx.merchant,
      );
      sheet
          .cell(
            xl.CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: rowIndex),
          )
          .value = xl.DoubleCellValue(
        tx.amount,
      );
      sheet
          .cell(
            xl.CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: rowIndex),
          )
          .value = xl.TextCellValue(
        tx.category,
      );
      sheet
          .cell(
            xl.CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: rowIndex),
          )
          .value = xl.TextCellValue(
        tx.detail,
      );
      sheet
          .cell(
            xl.CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: rowIndex),
          )
          .value = xl.TextCellValue(
        tx.coUsers.join(', '),
      );
    }

    // 합계 행 추가
    final totalRowIndex = transactions.length + 1;
    sheet
        .cell(
          xl.CellIndex.indexByColumnRow(
            columnIndex: 2,
            rowIndex: totalRowIndex,
          ),
        )
        .value = xl.TextCellValue(
      '합계',
    );
    sheet
        .cell(
          xl.CellIndex.indexByColumnRow(
            columnIndex: 3,
            rowIndex: totalRowIndex,
          ),
        )
        .value = xl.DoubleCellValue(
      total,
    );

    // 컬럼 너비 설정
    sheet.setColumnWidth(0, 12);
    sheet.setColumnWidth(1, 8);
    sheet.setColumnWidth(2, 20);
    sheet.setColumnWidth(3, 14);
    sheet.setColumnWidth(4, 22);
    sheet.setColumnWidth(5, 24);
    sheet.setColumnWidth(6, 24);

    final bytes = excel.save();
    return bytes ?? <int>[];
  }

  /// 엑셀 파일을 생성하고 다운로드(브라우저) / 저장(모바일)한다
  static Future<void> exportAndSave(
    List<CardTransaction> transactions, {
    String? fileName,
  }) async {
    final bytes = buildExcelBytes(transactions);
    final name =
        fileName ??
        '법인카드_정산내역_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}';

    await FileSaver.instance.saveFile(
      name: name,
      bytes: Uint8List.fromList(bytes),
      fileExtension: 'xlsx',
      mimeType: MimeType.microsoftExcel,
    );
  }
}
