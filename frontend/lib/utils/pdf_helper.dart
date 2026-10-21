// ============================================================
// lib/utils/pdf_helper.dart — Générateur PDF (Assets & Tickets)
// ============================================================

import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/asset.dart';
import '../models/ticket.dart';

// ─────────────────────────────────────────────────────────────
//  Palette de couleurs du thème
// ─────────────────────────────────────────────────────────────
class _PdfTheme {
  static const primary    = PdfColor.fromInt(0xFF1565C0); // bleu foncé
  static const accent     = PdfColor.fromInt(0xFF42A5F5); // bleu clair
  static const success    = PdfColor.fromInt(0xFF2E7D32); // vert
  static const error      = PdfColor.fromInt(0xFFC62828); // rouge
  static const warning    = PdfColor.fromInt(0xFFE65100); // orange
  static const bgLight    = PdfColor.fromInt(0xFFF5F7FA); // gris très clair
  static const borderGray = PdfColor.fromInt(0xFFDDE1E7);
  static const textDark   = PdfColor.fromInt(0xFF1A1A2E);
  static const textMuted  = PdfColor.fromInt(0xFF6B7280);
  // Semi-transparent white (70% opacity) for subtitle text on dark backgrounds
  static const white70    = PdfColor.fromInt(0xB3FFFFFF);
}

// ─────────────────────────────────────────────────────────────
//  Helpers privés
// ─────────────────────────────────────────────────────────────
String _fmt(String? v, {String fallback = '—'}) => (v != null && v.isNotEmpty) ? v : fallback;

String _fmtDate(String? iso) {
  if (iso == null || iso.isEmpty) return '—';
  try {
    final dt = DateTime.parse(iso);
    return DateFormat('dd/MM/yyyy', 'fr_FR').format(dt);
  } catch (_) {
    return iso;
  }
}

String _fmtDateTime(DateTime? dt) {
  if (dt == null) return '—';
  return DateFormat('dd/MM/yyyy HH:mm', 'fr_FR').format(dt);
}

// ─────────────────────────────────────────────────────────────
//  Classe principale PdfHelper
// ─────────────────────────────────────────────────────────────
class PdfHelper {
  // ───────────────────────────────────────────────────────────
  //  Passeport Technique — Équipement
  // ───────────────────────────────────────────────────────────
  static Future<Uint8List> generateAssetPassport(Asset asset) async {
    final pdf = pw.Document(
      title: 'Passeport Technique — ${asset.assetTag}',
      author: 'Gestionnaire de Parc IT',
    );

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 32, vertical: 28),
        header: (ctx) => _buildAssetHeader(asset, ctx),
        footer: (ctx) => _buildFooter(ctx),
        build: (ctx) => [
          _sectionSpacer(),
          _buildAssetIdentity(asset),
          _sectionSpacer(),
          if (asset.specs != null) ...[
            _buildSection('Spécifications Techniques', [
              _twoColRow('CPU', _fmt(asset.specs!.cpu)),
              _twoColRow('RAM', _fmt(asset.specs!.ram)),
              _twoColRow('Stockage', _fmt(asset.specs!.stockage)),
              _twoColRow('Système d\'exploitation', '${_fmt(asset.specs!.os)} ${_fmt(asset.specs!.versionOs, fallback: '')}'),
              _twoColRow('Hostname', _fmt(asset.specs!.hostname)),
              _twoColRow('Adresse IP', _fmt(asset.specs!.ipAddress)),
              _twoColRow('Adresse MAC', _fmt(asset.specs!.macAddress)),
            ]),
            _sectionSpacer(),
          ],
          if (asset.securite != null) ...[
            _buildSecuriteSection(asset.securite!),
            _sectionSpacer(),
          ],
          if (asset.couts != null) ...[
            _buildSection('Informations Financières', [
              _twoColRow('Prix d\'acquisition', asset.couts!.prix != null
                  ? '${NumberFormat('#,##0', 'fr_FR').format(asset.couts!.prix)} ${asset.couts!.devise}'
                  : '—'),
              _twoColRow('Fournisseur', _fmt(asset.couts!.fournisseur)),
              _twoColRow('Bon de commande', _fmt(asset.couts!.bonCommande)),
              _twoColRow('Date d\'acquisition', _fmtDate(asset.couts!.dateAcquisition ?? asset.dateAcquisition)),
              _twoColRow('Fin de garantie', _fmtDate(asset.couts!.finGarantie ?? asset.finGarantie)),
            ]),
            _sectionSpacer(),
          ],
          if (asset.affectations != null && asset.affectations!.isNotEmpty) ...[
            _buildAffectationsSection(asset.affectations!),
            _sectionSpacer(),
          ],
          if (asset.notes != null && asset.notes!.isNotEmpty) ...[
            _buildSection('Notes', [
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  color: _PdfTheme.bgLight,
                  borderRadius: pw.BorderRadius.circular(4),
                  border: pw.Border.all(color: _PdfTheme.borderGray),
                ),
                child: pw.Text(asset.notes!, style: const pw.TextStyle(fontSize: 9)),
              ),
            ]),
            _sectionSpacer(),
          ],
          _buildSignatureBlock(single: true, label1: 'Responsable IT'),
        ],
      ),
    );

    return pdf.save();
  }

  // ───────────────────────────────────────────────────────────
  //  Fiche d'Intervention — Ticket
  // ───────────────────────────────────────────────────────────
  static Future<Uint8List> generateTicketIntervention(Ticket ticket) async {
    final pdf = pw.Document(
      title: 'Fiche d\'Intervention — ${ticket.numero}',
      author: 'Gestionnaire de Parc IT',
    );

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 32, vertical: 28),
        header: (ctx) => _buildTicketHeader(ticket, ctx),
        footer: (ctx) => _buildFooter(ctx),
        build: (ctx) => [
          _sectionSpacer(),
          _buildTicketMeta(ticket),
          _sectionSpacer(),
          _buildSection('Description', [
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: _PdfTheme.bgLight,
                borderRadius: pw.BorderRadius.circular(4),
                border: pw.Border.all(color: _PdfTheme.borderGray),
              ),
              child: pw.Text(
                _fmt(ticket.description),
                style: const pw.TextStyle(fontSize: 9),
              ),
            ),
          ]),
          _sectionSpacer(),
          if (ticket.assetTag != null) ...[
            _buildSection('Équipement concerné', [
              _twoColRow('Tag équipement', _fmt(ticket.assetTag)),
              _twoColRow('Marque / Modèle', '${_fmt(ticket.assetMarque)} ${_fmt(ticket.assetModele, fallback: '')}'),
            ]),
            _sectionSpacer(),
          ],
          if (ticket.commentaires.isNotEmpty) ...[
            _buildInterventionNotes(ticket),
            _sectionSpacer(),
          ],
          if (ticket.historique.isNotEmpty) ...[
            _buildHistoriqueSection(ticket),
            _sectionSpacer(),
          ],
          _buildSignatureBlock(
            single: false,
            label1: 'Technicien IT',
            label2: 'Responsable / Demandeur',
          ),
        ],
      ),
    );

    return pdf.save();
  }

  // ─────────────────────────────────────────────────────────────
  //  Widgets internes — En-têtes
  // ─────────────────────────────────────────────────────────────
  static pw.Widget _buildAssetHeader(Asset asset, pw.Context ctx) {
    return pw.Column(children: [
      pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: const pw.BoxDecoration(
          color: _PdfTheme.primary,
          borderRadius: pw.BorderRadius.all(pw.Radius.circular(6)),
        ),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('PASSEPORT TECHNIQUE',
                    style: pw.TextStyle(
                      color: PdfColors.white,
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                    )),
                pw.SizedBox(height: 2),
                pw.Text('Gestionnaire de Parc IT — Direction Informatique',
                    style: pw.TextStyle(color: _PdfTheme.white70, fontSize: 8)),
              ],
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(asset.assetTag,
                    style: pw.TextStyle(
                      color: PdfColors.white,
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                    )),
                pw.Text('Imprimé le ${_fmtDateTime(DateTime.now())}',
                    style: pw.TextStyle(color: _PdfTheme.white70, fontSize: 8)),
              ],
            ),
          ],
        ),
      ),
      pw.SizedBox(height: 4),
    ]);
  }

  static pw.Widget _buildTicketHeader(Ticket ticket, pw.Context ctx) {
    final badgeColor = _priorityColor(ticket.priorite);
    return pw.Column(children: [
      pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: const pw.BoxDecoration(
          color: _PdfTheme.primary,
          borderRadius: pw.BorderRadius.all(pw.Radius.circular(6)),
        ),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('FICHE D\'INTERVENTION',
                    style: pw.TextStyle(
                      color: PdfColors.white,
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                    )),
                pw.SizedBox(height: 2),
                pw.Text(ticket.titre,
                    style: pw.TextStyle(color: _PdfTheme.white70, fontSize: 9)),
              ],
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(ticket.numero,
                    style: pw.TextStyle(
                      color: PdfColors.white,
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                    )),
                pw.SizedBox(height: 4),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: pw.BoxDecoration(
                    color: badgeColor,
                    borderRadius: pw.BorderRadius.circular(10),
                  ),
                  child: pw.Text(
                    ticket.prioriteLabel.toUpperCase(),
                    style: pw.TextStyle(
                      color: PdfColors.white,
                      fontSize: 8,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      pw.SizedBox(height: 4),
    ]);
  }

  static pw.Widget _buildFooter(pw.Context ctx) {
    return pw.Column(children: [
      pw.Divider(color: _PdfTheme.borderGray, thickness: 0.5),
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('Gestionnaire de Parc IT — Document confidentiel',
              style: const pw.TextStyle(color: _PdfTheme.textMuted, fontSize: 7)),
          pw.Text('Page ${ctx.pageNumber} / ${ctx.pagesCount}',
              style: const pw.TextStyle(color: _PdfTheme.textMuted, fontSize: 7)),
        ],
      ),
    ]);
  }

  // ─────────────────────────────────────────────────────────────
  //  Widgets internes — Contenu Asset
  // ─────────────────────────────────────────────────────────────
  static pw.Widget _buildAssetIdentity(Asset asset) {
    final statutColor = _statutAssetColor(asset.statut);
    return pw.Container(
      decoration: pw.BoxDecoration(
        color: _PdfTheme.bgLight,
        borderRadius: pw.BorderRadius.circular(6),
        border: pw.Border.all(color: _PdfTheme.borderGray),
      ),
      padding: const pw.EdgeInsets.all(12),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _infoChip('IDENTITÉ ÉQUIPEMENT', _PdfTheme.primary),
                pw.SizedBox(height: 8),
                _twoColRow('Tag / Nom Machine', asset.assetTag),
                _twoColRow('Numéro de série', _fmt(asset.serialNumber)),
                _twoColRow('Marque', asset.marque),
                _twoColRow('Modèle', _fmt(asset.modele)),
                _twoColRow('Type', asset.type),
              ],
            ),
          ),
          pw.SizedBox(width: 16),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _infoChip('AFFECTATION', _PdfTheme.accent),
                pw.SizedBox(height: 8),
                _twoColRow('Site', _fmt(asset.site)),
                _twoColRow('Département', _fmt(asset.departement)),
                _twoColRow('Utilisateur', _fmt(asset.utilisateurActuel)),
                _twoColRow('Email', _fmt(asset.utilisateurEmail)),
                _twoColRow('Date d\'acquisition', _fmtDate(asset.dateAcquisition)),
              ],
            ),
          ),
          pw.SizedBox(width: 16),
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: pw.BoxDecoration(
              color: statutColor,
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Column(
              children: [
                pw.Text('STATUT', style: pw.TextStyle(color: PdfColors.white, fontSize: 7, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 4),
                pw.Text(
                  asset.statut.replaceAll('_', ' ').toUpperCase(),
                  style: pw.TextStyle(color: PdfColors.white, fontSize: 8, fontWeight: pw.FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildSecuriteSection(Securite sec) {
    final checks = [
      ('Microsoft Defender', sec.defender),
      ('EDR', sec.edr),
      ('Intune', sec.intune),
      ('Entra ID', sec.entraId),
      ('BitLocker', sec.bitlocker),
      ('OneDrive', sec.onedrive),
    ];
    final total = checks.length;
    final enabled = checks.where((c) => c.$2).length;
    final score = (enabled / total * 100).round();

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _sectionTitle('Conformité Sécurité'),
        pw.SizedBox(height: 6),
        pw.Container(
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: _PdfTheme.borderGray),
            borderRadius: pw.BorderRadius.circular(6),
          ),
          padding: const pw.EdgeInsets.all(12),
          child: pw.Column(
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Score de conformité',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: pw.BoxDecoration(
                      color: score >= 80 ? _PdfTheme.success : score >= 50 ? _PdfTheme.warning : _PdfTheme.error,
                      borderRadius: pw.BorderRadius.circular(10),
                    ),
                    child: pw.Text(
                      '$score% ($enabled/$total)',
                      style: pw.TextStyle(color: PdfColors.white, fontSize: 8, fontWeight: pw.FontWeight.bold),
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 10),
              pw.Wrap(
                spacing: 8,
                runSpacing: 6,
                children: checks.map((c) => _securityBadge(c.$1, c.$2)).toList(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildAffectationsSection(List<AffectationHistory> affectations) {
    return _buildSection('Historique d\'Affectations', [
      pw.Table(
        border: pw.TableBorder.all(color: _PdfTheme.borderGray, width: 0.5),
        columnWidths: {
          0: const pw.FlexColumnWidth(2),
          1: const pw.FlexColumnWidth(1.5),
          2: const pw.FlexColumnWidth(1.5),
          3: const pw.FlexColumnWidth(1),
        },
        children: [
          pw.TableRow(
            decoration: const pw.BoxDecoration(color: _PdfTheme.primary),
            children: [
              _tableHeader('Utilisateur'),
              _tableHeader('Date Attribution'),
              _tableHeader('Date Retrait'),
              _tableHeader('Statut'),
            ],
          ),
          ...affectations.take(10).map((a) => pw.TableRow(
            decoration: pw.BoxDecoration(
              color: affectations.indexOf(a).isEven ? PdfColors.white : _PdfTheme.bgLight,
            ),
            children: [
              _tableCell(_fmt(a.utilisateurNom)),
              _tableCell(_fmtDate(a.dateAttribution)),
              _tableCell(_fmtDate(a.dateRetrait)),
              _tableCell(a.actif ? 'Actif' : 'Retiré',
                  color: a.actif ? _PdfTheme.success : _PdfTheme.textMuted),
            ],
          )),
        ],
      ),
    ]);
  }

  // ─────────────────────────────────────────────────────────────
  //  Widgets internes — Contenu Ticket
  // ─────────────────────────────────────────────────────────────
  static pw.Widget _buildTicketMeta(Ticket ticket) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        color: _PdfTheme.bgLight,
        borderRadius: pw.BorderRadius.circular(6),
        border: pw.Border.all(color: _PdfTheme.borderGray),
      ),
      padding: const pw.EdgeInsets.all(12),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _infoChip('IDENTIFICATION', _PdfTheme.primary),
                pw.SizedBox(height: 8),
                _twoColRow('Numéro', ticket.numero),
                _twoColRow('Type', ticket.typeLabel),
                _twoColRow('Priorité', ticket.prioriteLabel),
                _twoColRow('Statut', ticket.statutLabel),
              ],
            ),
          ),
          pw.SizedBox(width: 16),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _infoChip('PERSONNES', _PdfTheme.accent),
                pw.SizedBox(height: 8),
                _twoColRow('Demandeur', ticket.createurNomComplet),
                _twoColRow('Technicien', ticket.technicienNomComplet),
                _twoColRow('Site', _fmt(ticket.site)),
              ],
            ),
          ),
          pw.SizedBox(width: 16),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _infoChip('DATES', _PdfTheme.accent),
                pw.SizedBox(height: 8),
                _twoColRow('Créé le', _fmtDateTime(ticket.createdAt)),
                _twoColRow('Mis à jour', _fmtDateTime(ticket.updatedAt)),
                if (ticket.closedAt != null)
                  _twoColRow('Clôturé le', _fmtDateTime(ticket.closedAt)),
                if (ticket.slaDeadline != null)
                  _twoColRow('Deadline SLA', _fmtDateTime(ticket.slaDeadline)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildInterventionNotes(Ticket ticket) {
    final publicComments = ticket.commentaires.where((c) => !c.isInternal).toList();
    if (publicComments.isEmpty) return pw.SizedBox();

    return _buildSection('Notes d\'Intervention', [
      ...publicComments.take(5).map((c) => pw.Container(
        margin: const pw.EdgeInsets.only(bottom: 6),
        padding: const pw.EdgeInsets.all(8),
        decoration: pw.BoxDecoration(
          border: pw.Border(left: pw.BorderSide(color: _PdfTheme.accent, width: 3)),
          color: _PdfTheme.bgLight,
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(c.auteurNomComplet,
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8, color: _PdfTheme.primary)),
                pw.Text(_fmtDateTime(c.createdAt),
                    style: const pw.TextStyle(fontSize: 7, color: _PdfTheme.textMuted)),
              ],
            ),
            pw.SizedBox(height: 3),
            pw.Text(c.contenu, style: const pw.TextStyle(fontSize: 8)),
          ],
        ),
      )),
    ]);
  }

  static pw.Widget _buildHistoriqueSection(Ticket ticket) {
    return _buildSection('Historique des Modifications', [
      pw.Table(
        border: pw.TableBorder.all(color: _PdfTheme.borderGray, width: 0.5),
        columnWidths: {
          0: const pw.FlexColumnWidth(1.5),
          1: const pw.FlexColumnWidth(1.5),
          2: const pw.FlexColumnWidth(1.5),
          3: const pw.FlexColumnWidth(1.5),
        },
        children: [
          pw.TableRow(
            decoration: const pw.BoxDecoration(color: _PdfTheme.primary),
            children: [
              _tableHeader('Date'),
              _tableHeader('Champ'),
              _tableHeader('Ancienne valeur'),
              _tableHeader('Nouvelle valeur'),
            ],
          ),
          ...ticket.historique.take(8).map((h) => pw.TableRow(
            decoration: pw.BoxDecoration(
              color: ticket.historique.indexOf(h).isEven ? PdfColors.white : _PdfTheme.bgLight,
            ),
            children: [
              _tableCell(_fmtDateTime(h.createdAt)),
              _tableCell(h.champModifie),
              _tableCell(_fmt(h.ancienneValeur)),
              _tableCell(_fmt(h.nouvelleValeur)),
            ],
          )),
        ],
      ),
    ]);
  }

  // ─────────────────────────────────────────────────────────────
  //  Bloc signatures
  // ─────────────────────────────────────────────────────────────
  static pw.Widget _buildSignatureBlock({
    required bool single,
    required String label1,
    String? label2,
  }) {
    final box = pw.Expanded(
      child: pw.Container(
        height: 80,
        margin: const pw.EdgeInsets.only(right: 8),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: _PdfTheme.borderGray),
          borderRadius: pw.BorderRadius.circular(4),
        ),
        padding: const pw.EdgeInsets.all(10),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(label1,
                style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: _PdfTheme.primary)),
            pw.SizedBox(height: 4),
            pw.Text('Nom & Prénom : .................................................',
                style: const pw.TextStyle(fontSize: 7, color: _PdfTheme.textMuted)),
            pw.SizedBox(height: 20),
            pw.Text('Signature : ........................................................',
                style: const pw.TextStyle(fontSize: 7, color: _PdfTheme.textMuted)),
          ],
        ),
      ),
    );

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _sectionTitle('Validation & Signatures'),
        pw.SizedBox(height: 6),
        pw.Row(children: [
          box,
          if (!single && label2 != null)
            pw.Expanded(
              child: pw.Container(
                height: 80,
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: _PdfTheme.borderGray),
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                padding: const pw.EdgeInsets.all(10),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(label2,
                        style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: _PdfTheme.primary)),
                    pw.SizedBox(height: 4),
                    pw.Text('Nom & Prénom : .................................................',
                        style: const pw.TextStyle(fontSize: 7, color: _PdfTheme.textMuted)),
                    pw.SizedBox(height: 20),
                    pw.Text('Signature : ........................................................',
                        style: const pw.TextStyle(fontSize: 7, color: _PdfTheme.textMuted)),
                  ],
                ),
              ),
            ),
        ]),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────
  //  Helpers de widgets partagés
  // ─────────────────────────────────────────────────────────────
  static pw.Widget _buildSection(String title, List<pw.Widget> children) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _sectionTitle(title),
        pw.SizedBox(height: 6),
        ...children,
      ],
    );
  }

  static pw.Widget _sectionTitle(String title) {
    return pw.Row(children: [
      pw.Container(width: 4, height: 14, color: _PdfTheme.primary),
      pw.SizedBox(width: 6),
      pw.Text(title,
          style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: _PdfTheme.textDark)),
    ]);
  }

  static pw.Widget _infoChip(String label, PdfColor color) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: pw.BoxDecoration(
        color: color,
        borderRadius: pw.BorderRadius.circular(10),
      ),
      child: pw.Text(label,
          style: pw.TextStyle(color: PdfColors.white, fontSize: 7, fontWeight: pw.FontWeight.bold)),
    );
  }

  static pw.Widget _twoColRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 110,
            child: pw.Text('$label :',
                style: pw.TextStyle(fontSize: 8, color: _PdfTheme.textMuted, fontWeight: pw.FontWeight.bold)),
          ),
          pw.Flexible(
            child: pw.Text(value,
                style: const pw.TextStyle(fontSize: 8),
                maxLines: 3),
          ),
        ],
      ),
    );
  }

  static pw.Widget _securityBadge(String label, bool enabled) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: pw.BoxDecoration(
        color: enabled ? _PdfTheme.success : _PdfTheme.error,
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Row(children: [
        pw.Text(enabled ? '✓' : '✗',
            style: pw.TextStyle(color: PdfColors.white, fontSize: 8, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(width: 4),
        pw.Text(label, style: const pw.TextStyle(color: PdfColors.white, fontSize: 8)),
      ]),
    );
  }

  static pw.Widget _tableHeader(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(text,
          style: pw.TextStyle(
              color: PdfColors.white, fontSize: 8, fontWeight: pw.FontWeight.bold)),
    );
  }

  static pw.Widget _tableCell(String text, {PdfColor? color}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(text,
          style: pw.TextStyle(fontSize: 8, color: color ?? _PdfTheme.textDark)),
    );
  }

  static pw.Widget _sectionSpacer() => pw.SizedBox(height: 14);

  // ─────────────────────────────────────────────────────────────
  //  Helpers couleurs
  // ─────────────────────────────────────────────────────────────
  static PdfColor _statutAssetColor(String statut) {
    switch (statut) {
      case 'en_service': return _PdfTheme.success;
      case 'en_maintenance': return _PdfTheme.warning;
      case 'hors_service':
      case 'reforme': return _PdfTheme.error;
      default: return _PdfTheme.textMuted;
    }
  }

  static PdfColor _priorityColor(String priorite) {
    switch (priorite) {
      case 'critique': return _PdfTheme.error;
      case 'haute':    return _PdfTheme.warning;
      case 'moyenne':  return _PdfTheme.accent;
      case 'basse':    return _PdfTheme.success;
      default:         return _PdfTheme.textMuted;
    }
  }
}
