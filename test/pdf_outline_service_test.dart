import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:medicalreader/features/reader/services/pdf_outline_service.dart';

void main() {
  test('imports embedded outline hierarchy and destinations', () {
    const pdf = '''%PDF-1.4
1 0 obj
<< /Type /Catalog /Pages 2 0 R /Outlines 6 0 R >>
endobj
2 0 obj
<< /Type /Pages /Kids [4 0 R 3 0 R] /Count 2 >>
endobj
3 0 obj
<< /Type /Page /Parent 2 0 R >>
endobj
4 0 obj
<< /Type /Page /Parent 2 0 R >>
endobj
6 0 obj
<< /Type /Outlines /First 7 0 R >>
endobj
7 0 obj
<< /Title (Chapter 1) /Dest [4 0 R /XYZ null null null] /First 8 0 R >>
endobj
8 0 obj
<< /Title (Section 1) /Dest [3 0 R /XYZ null null null] /Parent 7 0 R >>
endobj
''';
    final nodes = const PdfOutlineService().extractFromBytes(
      Uint8List.fromList(pdf.codeUnits),
    );
    expect(nodes, hasLength(1));
    expect(nodes.first.name, 'Chapter 1');
    expect(nodes.first.pageStart, 2);
    expect(nodes.first.children, hasLength(1));
    expect(nodes.first.children.first.name, 'Section 1');
    expect(nodes.first.children.first.pageStart, 1);
  });
}
