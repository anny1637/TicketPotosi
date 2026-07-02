import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class PdfService {
  static Future<void> printTicket(Map<String, dynamic> ticket) async {
    final pdf = pw.Document();

    final title = ticket['event']?['title'] ?? 'Evento';
    final organizer = ticket['event']?['organizer'] ?? 'Gobernación de Potosí';
    final location = ticket['event']?['location'] ?? 'Potosí';
    final date = ticket['event']?['event_date'] ?? '';
    final code = ticket['ticket_code'] ?? '—';
    final user = ticket['user']?['name'] ?? 'Usuario';
    final typeName = ticket['ticket_type']?['name'] ?? 'Entrada';
    final price = ticket['ticket_type']?['price'] ?? '0.00';

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Container(
            padding: const pw.EdgeInsets.all(32),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.purple, width: 2),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(16)),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Cabecera
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('TICKET DE INGRESO',
                            style: pw.TextStyle(
                                fontSize: 24,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColors.purple)),
                        pw.Text(organizer,
                            style: pw.TextStyle(
                                fontSize: 12,
                                color: PdfColors.grey700)),
                      ],
                    ),
                    pw.Text('TicketPotosí',
                        style: pw.TextStyle(
                            fontSize: 18,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.purple800)),
                  ],
                ),
                pw.Divider(color: PdfColors.purple100, thickness: 1.5, height: 32),

                // Información del evento
                pw.Text('INFORMACIÓN DEL EVENTO',
                    style: pw.TextStyle(
                        fontSize: 13,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.grey800)),
                pw.SizedBox(height: 8),
                pw.Text(title,
                    style: pw.TextStyle(
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.black)),
                pw.SizedBox(height: 12),

                pw.Row(
                  children: [
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('LUGAR:',
                              style: pw.TextStyle(
                                  fontSize: 10,
                                  fontWeight: pw.FontWeight.bold,
                                  color: PdfColors.grey600)),
                          pw.Text(location,
                              style: const pw.TextStyle(fontSize: 12)),
                        ],
                      ),
                    ),
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('FECHA:',
                              style: pw.TextStyle(
                                  fontSize: 10,
                                  fontWeight: pw.FontWeight.bold,
                                  color: PdfColors.grey600)),
                          pw.Text(date.replaceAll('T', ' ').substring(0, 16),
                              style: const pw.TextStyle(fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ),
                pw.Divider(color: PdfColors.grey200, thickness: 1, height: 32),

                // Información del ticket y usuario
                pw.Text('DETALLES DEL TICKET',
                    style: pw.TextStyle(
                        fontSize: 13,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.grey800)),
                pw.SizedBox(height: 8),

                pw.Row(
                  children: [
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('TITULAR:',
                              style: pw.TextStyle(
                                  fontSize: 10,
                                  fontWeight: pw.FontWeight.bold,
                                  color: PdfColors.grey600)),
                          pw.Text(user,
                              style: const pw.TextStyle(fontSize: 12)),
                          pw.SizedBox(height: 12),
                          pw.Text('TIPO DE ENTRADA:',
                              style: pw.TextStyle(
                                  fontSize: 10,
                                  fontWeight: pw.FontWeight.bold,
                                  color: PdfColors.grey600)),
                          pw.Text(typeName,
                              style: pw.TextStyle(
                                  fontSize: 14,
                                  fontWeight: pw.FontWeight.bold,
                                  color: PdfColors.purple)),
                        ],
                      ),
                    ),
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('CÓDIGO DE TICKET:',
                              style: pw.TextStyle(
                                  fontSize: 10,
                                  fontWeight: pw.FontWeight.bold,
                                  color: PdfColors.grey600)),
                          pw.Text(code,
                              style: pw.TextStyle(
                                  fontSize: 12,
                                  font: pw.Font.courier(),
                                  fontWeight: pw.FontWeight.bold)),
                          pw.SizedBox(height: 12),
                          pw.Text('PRECIO:',
                              style: pw.TextStyle(
                                  fontSize: 10,
                                  fontWeight: pw.FontWeight.bold,
                                  color: PdfColors.grey600)),
                          pw.Text('Bs. $price',
                              style: const pw.TextStyle(fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ),
                pw.Spacer(),

                // Notas y pie de página
                pw.Center(
                  child: pw.Column(
                    children: [
                      pw.Text('Presenta este ticket impreso o digital al ingresar al evento.',
                          style: pw.TextStyle(
                              fontSize: 10,
                              color: PdfColors.grey700,
                              fontStyle: pw.FontStyle.italic)),
                      pw.SizedBox(height: 4),
                      pw.Text('El código QR es único y personal. Su uso indebido anula el ingreso.',
                          style: pw.TextStyle(
                              fontSize: 9,
                              color: PdfColors.red800,
                              fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 16),
                      pw.Text('¡Gracias por usar TicketPotosí!',
                          style: pw.TextStyle(
                              fontSize: 11,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.purple700)),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
        name: 'ticket_$code.pdf');
  }

  static Future<void> printEventReport(Map<String, dynamic> report) async {
    final pdf = pw.Document();

    final event = report['event'] as Map<String, dynamic>? ?? {};
    final summary = report['summary'] as Map<String, dynamic>? ?? {};
    final tickets = (report['tickets'] as List?) ?? [];

    final title = event['title'] ?? 'Evento';
    final organizer = event['organizer'] ?? 'Gobernación de Potosí';
    final location = event['location'] ?? 'Potosí';
    final date = event['event_date'] ?? '';
    
    final sold = summary['total_sold'] ?? 0;
    final used = summary['total_used'] ?? 0;
    final revenue = (summary['total_revenue'] ?? 0.0) is num 
        ? (summary['total_revenue'] as num).toDouble() 
        : double.tryParse(summary['total_revenue']?.toString() ?? '') ?? 0.0;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Container(
            padding: const pw.EdgeInsets.all(32),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Cabecera del reporte
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('REPORTE OFICIAL DE EVENTO',
                            style: pw.TextStyle(
                                fontSize: 20,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColors.indigo900)),
                        pw.Text(organizer,
                            style: pw.TextStyle(
                                fontSize: 11,
                                color: PdfColors.grey700)),
                      ],
                    ),
                    pw.Text('TicketPotosí',
                        style: pw.TextStyle(
                            fontSize: 16,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.indigo)),
                  ],
                ),
                pw.Divider(color: PdfColors.indigo100, thickness: 1.5, height: 24),

                // Detalles del evento
                pw.Text('DETALLES DEL EVENTO',
                    style: pw.TextStyle(
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.grey800)),
                pw.SizedBox(height: 6),
                pw.Text(title,
                    style: pw.TextStyle(
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.black)),
                pw.SizedBox(height: 8),

                pw.Row(
                  children: [
                    pw.Expanded(
                      child: pw.Text('Lugar: $location',
                          style: const pw.TextStyle(fontSize: 11)),
                    ),
                    pw.Expanded(
                      child: pw.Text('Fecha: ${date.replaceAll('T', ' ').substring(0, 16)}',
                          style: const pw.TextStyle(fontSize: 11)),
                    ),
                  ],
                ),
                pw.Divider(color: PdfColors.grey200, thickness: 1, height: 24),

                // Resumen de Ventas
                pw.Text('RESUMEN DE VENTAS Y ASISTENCIA',
                    style: pw.TextStyle(
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.grey800)),
                pw.SizedBox(height: 8),

                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      children: [
                        pw.Text('$sold',
                            style: pw.TextStyle(
                                fontSize: 16,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColors.indigo)),
                        pw.Text('Vendidos', style: const pw.TextStyle(fontSize: 10)),
                      ],
                    ),
                    pw.Column(
                      children: [
                        pw.Text('$used',
                            style: pw.TextStyle(
                                fontSize: 16,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColors.green)),
                        pw.Text('Asistencias (Usados)', style: const pw.TextStyle(fontSize: 10)),
                      ],
                    ),
                    pw.Column(
                      children: [
                        pw.Text('Bs. ${revenue.toStringAsFixed(2)}',
                            style: pw.TextStyle(
                                fontSize: 16,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColors.orange900)),
                        pw.Text('Recaudación Total', style: const pw.TextStyle(fontSize: 10)),
                      ],
                    ),
                  ],
                ),
                pw.Divider(color: PdfColors.grey200, thickness: 1, height: 24),

                // Lista de Compradores
                pw.Text('DETALLE DE TICKETS EMITIDOS',
                    style: pw.TextStyle(
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.grey800)),
                pw.SizedBox(height: 8),

                pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                  children: [
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text('Comprador', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text('Tipo', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text('Código', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text('Estado', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                        ),
                      ],
                    ),
                    ...tickets.map((t) {
                      final name = t['user']?['name'] ?? 'Sin nombre';
                      final type = t['ticket_type']?['name'] ?? 'General';
                      final code = t['ticket_code'] ?? '—';
                      final status = t['status'] == 'used' ? 'Usado' : (t['status'] == 'paid' ? 'Pagado' : 'Pendiente');

                      return pw.TableRow(
                        children: [
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(6),
                            child: pw.Text(name, style: const pw.TextStyle(fontSize: 9)),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(6),
                            child: pw.Text(type, style: const pw.TextStyle(fontSize: 9)),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(6),
                            child: pw.Text(code, style: const pw.TextStyle(fontSize: 9)),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(6),
                            child: pw.Text(status, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                          ),
                        ],
                      );
                    }).toList(),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'reporte_${event['id'] ?? 'evento'}.pdf',
    );
  }
}
