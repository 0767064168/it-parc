// ============================================
// lib/screens/wiki/wiki_screen.dart
// ============================================

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/theme.dart';
import '../../models/wiki.dart';
import '../../providers/wiki_provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/app_navigation_layout.dart';

class WikiScreen extends StatefulWidget {
  const WikiScreen({super.key});

  @override
  State<WikiScreen> createState() => _WikiScreenState();
}

class _WikiScreenState extends State<WikiScreen> {
  final _searchController = TextEditingController();
  WikiArticle? _selectedArticle;
  String _selectedCategory = 'Tous';

  final List<String> _categories = ['Tous', 'Matériel', 'Logiciel', 'Réseau', 'Sécurité', 'Général'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _loadData() {
    Provider.of<WikiProvider>(context, listen: false).fetchArticles(
      search: _searchController.text.trim().isEmpty ? null : _searchController.text.trim(),
    );
  }

  void _selectArticle(WikiArticle article) {
    setState(() => _selectedArticle = article);
    Provider.of<WikiProvider>(context, listen: false).fetchAttachments(article.id);
  }

  void _showArticleDialog(BuildContext context, {WikiArticle? article}) {
    final isEdit = article != null;
    final titleController = TextEditingController(text: article?.titre);
    final contentController = TextEditingController(text: article?.contenu);
    String selectedCat = article?.categorie ?? 'Général';
    bool isPublic = article?.estPublic ?? false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateBuilder) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            isEdit ? 'Modifier l\'Article' : 'Publier dans la FAQ / Wiki',
            style: GoogleFonts.inter(fontWeight: FontWeight.w700),
          ),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 550,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(labelText: 'Titre de l\'article *'),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _categories.contains(selectedCat) ? selectedCat : 'Général',
                          decoration: const InputDecoration(labelText: 'Catégorie'),
                          items: _categories.where((c) => c != 'Tous').map((cat) {
                            return DropdownMenuItem(value: cat, child: Text(cat));
                          }).toList(),
                          onChanged: (val) => setStateBuilder(() => selectedCat = val!),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Row(
                        children: [
                          const Text('Public :'),
                          Switch(
                            value: isPublic,
                            activeThumbColor: AppTheme.primaryColor,
                            onChanged: (val) => setStateBuilder(() => isPublic = val),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: contentController,
                    maxLines: 8,
                    decoration: const InputDecoration(
                      labelText: 'Contenu (Markdown supporté de façon basique)',
                      alignLabelWithHint: true,
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Annuler', style: GoogleFonts.inter(color: AppTheme.textSecondaryColor)),
            ),
            ElevatedButton(
              onPressed: () async {
                if (titleController.text.trim().isEmpty || contentController.text.trim().isEmpty) return;

                final data = {
                  'titre': titleController.text.trim(),
                  'contenu': contentController.text.trim(),
                  'categorie': selectedCat,
                  'est_public': isPublic ? 1 : 0,
                };

                final provider = Provider.of<WikiProvider>(context, listen: false);
                bool success = false;
                if (isEdit) {
                  success = await provider.updateArticle(article.id, data);
                } else {
                  success = await provider.createArticle(data);
                }

                if (success && context.mounted) {
                  Navigator.pop(context);
                  _loadData();
                  setState(() => _selectedArticle = null);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(isEdit ? 'Article mis à jour' : 'Article publié'),
                      backgroundColor: AppTheme.successColor,
                    ),
                  );
                }
              },
              child: Text(isEdit ? 'Enregistrer' : 'Publier'),
            ),
          ],
        ),
      ),
    );
  }

  /// Sélectionne un fichier et l'uploade sur le serveur
  Future<void> _uploadAttachment(BuildContext context, int articleId) async {
    // Capturer la référence avant tout await (règle use_build_context_synchronously)
    final provider = Provider.of<WikiProvider>(context, listen: false);
    final messenger = ScaffoldMessenger.of(context);

    final result = await FilePicker.pickFiles(
      allowMultiple: false,
      type: FileType.custom,
      allowedExtensions: [
        'pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx',
        'txt', 'md', 'csv',
        'png', 'jpg', 'jpeg', 'gif', 'svg',
        'zip', '7z',
      ],
    );

    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    if (file.path == null) return;

    final attachment = await provider.uploadAttachment(articleId, file.path!, file.name);

    if (attachment != null) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Fichier importé avec succès'),
          backgroundColor: AppTheme.successColor,
        ),
      );
    } else {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Erreur lors de l\'import du fichier'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }

  Future<void> _confirmDeleteAttachment(BuildContext context, WikiAttachment attachment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Supprimer le fichier'),
        content: Text('Supprimer "${attachment.nomOriginal}" ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Supprimer', style: TextStyle(color: AppTheme.errorColor)),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      final ok = await Provider.of<WikiProvider>(context, listen: false)
          .deleteAttachment(attachment.id);
      if (ok && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Fichier supprimé'), backgroundColor: AppTheme.successColor),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final wikiProvider = Provider.of<WikiProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.currentUser;
    final canEdit = user?.role == 'admin' || user?.role == 'technicien';

    final filteredArticles = wikiProvider.articles.where((a) {
      if (_selectedCategory == 'Tous') return true;
      return a.categorie == _selectedCategory;
    }).toList();

    final size = MediaQuery.of(context).size;
    final isLargeScreen = size.width > 800;

    return AppNavigationLayout(
      title: 'Base de Connaissances',
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded),
          onPressed: _loadData,
        ),
      ],
      floatingActionButton: canEdit
          ? FloatingActionButton.extended(
              onPressed: () => _showArticleDialog(context),
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.edit_note_rounded),
              label: Text('Rédiger un article', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
            )
          : null,
      child: Column(
        children: [
          // Search & Category Pills
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Rechercher un article, un guide ou une solution...',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded),
                            onPressed: () {
                              _searchController.clear();
                              _loadData();
                            },
                          )
                        : null,
                  ),
                  onSubmitted: (_) => _loadData(),
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _categories.map((cat) {
                      final isSel = _selectedCategory == cat;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(cat),
                          selected: isSel,
                          onSelected: (_) => setState(() => _selectedCategory = cat),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),

          // Split View
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Panneau gauche : liste des articles
                Expanded(
                  flex: 2,
                  child: wikiProvider.isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : filteredArticles.isEmpty
                          ? Center(
                              child: Text(
                                'Aucun article trouvé.',
                                style: GoogleFonts.inter(color: AppTheme.textSecondaryColor),
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              itemCount: filteredArticles.length,
                              itemBuilder: (context, index) {
                                final article = filteredArticles[index];
                                final isSelected = _selectedArticle?.id == article.id;

                                return Card(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  color: isSelected
                                      ? AppTheme.primaryColor.withValues(alpha: 0.08)
                                      : null,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    side: BorderSide(
                                      color: isSelected ? AppTheme.primaryColor : AppTheme.borderColor,
                                      width: isSelected ? 1.5 : 1,
                                    ),
                                  ),
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    leading: Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: AppTheme.primaryColor.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(
                                        _categoryIcon(article.categorie),
                                        color: AppTheme.primaryColor,
                                        size: 20,
                                      ),
                                    ),
                                    title: Text(
                                      article.titre,
                                      style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14),
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const SizedBox(height: 4),
                                        Text(
                                          '${article.categorie} • Par ${article.auteurPrenom ?? ""} ${article.auteurNom ?? "IT Team"}',
                                          style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textSecondaryColor),
                                        ),
                                      ],
                                    ),
                                    trailing: const Icon(Icons.chevron_right_rounded),
                                    onTap: () {
                                      if (isLargeScreen) {
                                        _selectArticle(article);
                                      } else {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => MobileArticleReader(
                                              article: article,
                                              canEdit: canEdit,
                                              onEdit: () => _showArticleDialog(context, article: article),
                                            ),
                                          ),
                                        );
                                      }
                                    },
                                  ),
                                );
                              },
                            ),
                ),

                // ── Panneau droit : lecteur d'article + pièces jointes
                if (isLargeScreen)
                  Expanded(
                    flex: 3,
                    child: Container(
                      margin: const EdgeInsets.fromLTRB(0, 0, 16, 16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppTheme.borderColor),
                      ),
                      child: _selectedArticle == null
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.menu_book_outlined,
                                      size: 64,
                                      color: AppTheme.textSecondaryColor.withValues(alpha: 0.3)),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Sélectionnez un article pour le lire',
                                    style: GoogleFonts.inter(
                                        color: AppTheme.textSecondaryColor, fontSize: 15),
                                  ),
                                ],
                              ),
                            )
                          : _buildArticleReader(context, _selectedArticle!, canEdit, wikiProvider),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildArticleReader(
    BuildContext context,
    WikiArticle article,
    bool canEdit,
    WikiProvider wikiProvider,
  ) {
    return Column(
      children: [
        // ── En-tête article
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Barre méta + actions
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        article.categorie.toUpperCase(),
                        style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.primaryColor),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Mis à jour: ${DateFormat('dd/MM/yyyy').format(DateTime.parse(article.updatedAt))}',
                      style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textSecondaryColor),
                    ),
                    const Spacer(),
                    if (canEdit) ...[
                      IconButton(
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: () => _showArticleDialog(context, article: article),
                        tooltip: 'Modifier',
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: AppTheme.errorColor),
                        onPressed: () => _deleteArticleConfirm(context, article),
                        tooltip: 'Supprimer',
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  article.titre,
                  style: GoogleFonts.inter(
                      fontWeight: FontWeight.w800,
                      fontSize: 22,
                      color: AppTheme.textPrimaryColor),
                ),
                const SizedBox(height: 4),
                Text(
                  'Auteur: ${article.auteurPrenom ?? ""} ${article.auteurNom ?? "IT Team"}',
                  style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textSecondaryColor),
                ),
                const Divider(height: 32),
                // Contenu
                Text(
                  article.contenu,
                  style: GoogleFonts.inter(
                      fontSize: 15, height: 1.6, color: AppTheme.textPrimaryColor),
                ),
                const SizedBox(height: 32),

                // ── Section Pièces Jointes
                _buildAttachmentsSection(context, article, canEdit, wikiProvider),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAttachmentsSection(
    BuildContext context,
    WikiArticle article,
    bool canEdit,
    WikiProvider wikiProvider,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Titre de la section
        Row(
          children: [
            Container(width: 4, height: 18, decoration: BoxDecoration(
              color: AppTheme.primaryColor,
              borderRadius: BorderRadius.circular(2),
            )),
            const SizedBox(width: 8),
            Text(
              'Pièces jointes',
              style: GoogleFonts.inter(
                  fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.textPrimaryColor),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${wikiProvider.attachments.length}',
                style: GoogleFonts.inter(
                    fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.primaryColor),
              ),
            ),
            const Spacer(),
            wikiProvider.isUploading
                ? const SizedBox(
                    width: 24, height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : TextButton.icon(
                    onPressed: () => _uploadAttachment(context, article.id),
                    icon: const Icon(Icons.upload_file_rounded, size: 18),
                    label: Text('Importer', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                    style: TextButton.styleFrom(foregroundColor: AppTheme.primaryColor),
                  ),
          ],
        ),
        const SizedBox(height: 12),

        // État de chargement
        if (wikiProvider.isLoadingAttachments)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (wikiProvider.attachments.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            decoration: BoxDecoration(
              color: AppTheme.borderColor.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: AppTheme.borderColor,
                style: BorderStyle.solid,
              ),
            ),
            child: Column(
              children: [
                Icon(Icons.attach_file_rounded,
                    size: 36, color: AppTheme.textSecondaryColor.withValues(alpha: 0.4)),
                const SizedBox(height: 8),
                Text(
                  canEdit
                      ? 'Aucun fichier joint. Cliquez sur "Importer" pour en ajouter.'
                      : 'Aucun fichier joint à cet article.',
                  style: GoogleFonts.inter(
                      fontSize: 12, color: AppTheme.textSecondaryColor),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          )
        else
          // Liste des pièces jointes
          Column(
            children: wikiProvider.attachments.map((att) {
              return _buildAttachmentTile(context, att, canEdit, wikiProvider);
            }).toList(),
          ),
      ],
    );
  }

  Widget _buildAttachmentTile(
    BuildContext context,
    WikiAttachment att,
    bool canEdit,
    WikiProvider wikiProvider,
  ) {
    final ext = att.extension;
    final icon = _fileIcon(ext);
    final iconColor = _fileIconColor(ext);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Row(
        children: [
          // Icône type fichier
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 12),
          // Nom et méta
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  att.nomOriginal,
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${att.tailleLabel} • ${DateFormat('dd/MM/yyyy HH:mm').format(att.createdAt)}',
                  style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textSecondaryColor),
                ),
              ],
            ),
          ),
          // Bouton télécharger
          IconButton(
            icon: const Icon(Icons.download_rounded),
            tooltip: 'Télécharger',
            color: AppTheme.primaryColor,
            onPressed: () => _openDownload(context, wikiProvider, att),
          ),
          // Bouton supprimer (admin/technicien)
          if (canEdit)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded),
              tooltip: 'Supprimer',
              color: AppTheme.errorColor,
              onPressed: () => _confirmDeleteAttachment(context, att),
            ),
        ],
      ),
    );
  }

  /// Télécharge le fichier et le sauvegarde dans le dossier Téléchargements
  Future<void> _openDownload(
    BuildContext context,
    WikiProvider wikiProvider,
    WikiAttachment att,
  ) async {
    final url = wikiProvider.downloadUrl(att.id);
    final messenger = ScaffoldMessenger.of(context);

    // Indicateur de progression
    messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(
              width: 18, height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text('Téléchargement de "${att.nomOriginal}"...')),
          ],
        ),
        duration: const Duration(seconds: 30),
        backgroundColor: AppTheme.primaryColor,
      ),
    );

    try {
      String savePath;

      if (Platform.isAndroid) {
        // Sur Android : télécharger dans /storage/emulated/0/Download/
        const downloadsPath = '/storage/emulated/0/Download';
        final dir = Directory(downloadsPath);
        if (!await dir.exists()) {
          // Fallback vers le répertoire temporaire si indisponible
          final tmp = await getTemporaryDirectory();
          savePath = '${tmp.path}/${att.nomOriginal}';
        } else {
          savePath = '$downloadsPath/${att.nomOriginal}';
        }
      } else {
        // Sur iOS ou Desktop : utiliser le répertoire Documents
        final dir = await getApplicationDocumentsDirectory();
        savePath = '${dir.path}/${att.nomOriginal}';
      }

      await wikiProvider.downloadTo(url, savePath);

      messenger.clearSnackBars();
      if (context.mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_outline, color: Colors.white, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Téléchargé : ${att.nomOriginal}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            backgroundColor: AppTheme.successColor,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      messenger.clearSnackBars();
      if (context.mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Erreur de téléchargement : $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  void _deleteArticleConfirm(BuildContext context, WikiArticle article) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer l\'article'),
        content: Text('Voulez-vous supprimer l\'article "${article.titre}" ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final ok = await Provider.of<WikiProvider>(context, listen: false).deleteArticle(article.id);
              if (ok && context.mounted) {
                _loadData();
                setState(() => _selectedArticle = null);
                ScaffoldMessenger.of(context)
                    .showSnackBar(const SnackBar(content: Text('Article supprimé')));
              }
            },
            child: const Text('Supprimer', style: TextStyle(color: AppTheme.errorColor)),
          ),
        ],
      ),
    );
  }

  // ── Helpers icônes ────────────────────────────────
  IconData _categoryIcon(String cat) {
    switch (cat) {
      case 'Matériel':  return Icons.computer_rounded;
      case 'Logiciel':  return Icons.apps_rounded;
      case 'Réseau':    return Icons.lan_rounded;
      case 'Sécurité':  return Icons.security_rounded;
      default:          return Icons.article_rounded;
    }
  }

  IconData _fileIcon(String ext) {
    switch (ext) {
      case 'pdf':                           return Icons.picture_as_pdf_rounded;
      case 'doc': case 'docx':             return Icons.description_rounded;
      case 'xls': case 'xlsx': case 'csv': return Icons.table_chart_rounded;
      case 'ppt': case 'pptx':             return Icons.slideshow_rounded;
      case 'png': case 'jpg': case 'jpeg':
      case 'gif': case 'svg': case 'webp': return Icons.image_rounded;
      case 'zip': case '7z': case 'rar':   return Icons.folder_zip_rounded;
      case 'txt': case 'md':               return Icons.text_snippet_rounded;
      default:                              return Icons.attach_file_rounded;
    }
  }

  Color _fileIconColor(String ext) {
    switch (ext) {
      case 'pdf':                            return Colors.red.shade600;
      case 'doc': case 'docx':              return Colors.blue.shade700;
      case 'xls': case 'xlsx': case 'csv':  return Colors.green.shade700;
      case 'ppt': case 'pptx':              return Colors.orange.shade700;
      case 'png': case 'jpg': case 'jpeg':
      case 'gif': case 'svg': case 'webp':  return Colors.purple.shade600;
      case 'zip': case '7z': case 'rar':    return Colors.brown.shade600;
      default:                               return AppTheme.textSecondaryColor;
    }
  }
}

// ─────────────────────────────────────────────────────
//  Lecteur mobile (plein écran)
// ─────────────────────────────────────────────────────
class MobileArticleReader extends StatefulWidget {
  final WikiArticle article;
  final bool canEdit;
  final VoidCallback onEdit;

  const MobileArticleReader({
    super.key,
    required this.article,
    required this.canEdit,
    required this.onEdit,
  });

  @override
  State<MobileArticleReader> createState() => _MobileArticleReaderState();
}

class _MobileArticleReaderState extends State<MobileArticleReader> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<WikiProvider>(context, listen: false).fetchAttachments(widget.article.id);
    });
  }

  IconData _fileIcon(String ext) {
    switch (ext) {
      case 'pdf':                           return Icons.picture_as_pdf_rounded;
      case 'doc': case 'docx':             return Icons.description_rounded;
      case 'xls': case 'xlsx': case 'csv': return Icons.table_chart_rounded;
      case 'ppt': case 'pptx':             return Icons.slideshow_rounded;
      case 'png': case 'jpg': case 'jpeg':
      case 'gif': case 'svg': case 'webp': return Icons.image_rounded;
      case 'zip': case '7z': case 'rar':   return Icons.folder_zip_rounded;
      case 'txt': case 'md':               return Icons.text_snippet_rounded;
      default:                              return Icons.attach_file_rounded;
    }
  }

  Color _fileIconColor(String ext) {
    switch (ext) {
      case 'pdf':                            return Colors.red.shade600;
      case 'doc': case 'docx':              return Colors.blue.shade700;
      case 'xls': case 'xlsx': case 'csv':  return Colors.green.shade700;
      case 'ppt': case 'pptx':              return Colors.orange.shade700;
      case 'png': case 'jpg': case 'jpeg':
      case 'gif': case 'svg': case 'webp':  return Colors.purple.shade600;
      case 'zip': case '7z': case 'rar':    return Colors.brown.shade600;
      default:                               return AppTheme.textSecondaryColor;
    }
  }

  Future<void> _uploadAttachment(BuildContext context, int articleId) async {
    final provider = Provider.of<WikiProvider>(context, listen: false);
    final messenger = ScaffoldMessenger.of(context);

    final result = await FilePicker.pickFiles(
      allowMultiple: false,
      type: FileType.custom,
      allowedExtensions: [
        'pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx',
        'txt', 'md', 'csv',
        'png', 'jpg', 'jpeg', 'gif', 'svg',
        'zip', '7z',
      ],
    );

    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    if (file.path == null) return;

    final attachment = await provider.uploadAttachment(articleId, file.path!, file.name);

    if (attachment != null) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Fichier importé avec succès'),
          backgroundColor: AppTheme.successColor,
        ),
      );
    } else {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Erreur lors de l\'import du fichier'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }

  Future<void> _confirmDeleteAttachment(BuildContext context, WikiAttachment attachment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Supprimer le fichier'),
        content: Text('Supprimer "${attachment.nomOriginal}" ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Supprimer', style: TextStyle(color: AppTheme.errorColor)),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      final ok = await Provider.of<WikiProvider>(context, listen: false)
          .deleteAttachment(attachment.id);
      if (ok && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Fichier supprimé'), backgroundColor: AppTheme.successColor),
        );
      }
    }
  }

  Future<void> _openDownload(
    BuildContext context,
    WikiProvider wikiProvider,
    WikiAttachment att,
  ) async {
    final url = wikiProvider.downloadUrl(att.id);
    final messenger = ScaffoldMessenger.of(context);

    messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(
              width: 18, height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text('Téléchargement de "${att.nomOriginal}"...')),
          ],
        ),
        duration: const Duration(seconds: 30),
        backgroundColor: AppTheme.primaryColor,
      ),
    );

    try {
      String savePath;

      if (Platform.isAndroid) {
        const downloadsPath = '/storage/emulated/0/Download';
        final dir = Directory(downloadsPath);
        if (!await dir.exists()) {
          final tmp = await getTemporaryDirectory();
          savePath = '${tmp.path}/${att.nomOriginal}';
        } else {
          savePath = '$downloadsPath/${att.nomOriginal}';
        }
      } else {
        final dir = await getApplicationDocumentsDirectory();
        savePath = '${dir.path}/${att.nomOriginal}';
      }

      await wikiProvider.downloadTo(url, savePath);

      messenger.clearSnackBars();
      if (context.mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_outline, color: Colors.white, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Téléchargé : ${att.nomOriginal}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            backgroundColor: AppTheme.successColor,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      messenger.clearSnackBars();
      if (context.mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Erreur de téléchargement : $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  Widget _buildAttachmentsSection(BuildContext context, WikiProvider wikiProvider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(width: 4, height: 18, decoration: BoxDecoration(
              color: AppTheme.primaryColor,
              borderRadius: BorderRadius.circular(2),
            )),
            const SizedBox(width: 8),
            Text(
              'Pièces jointes',
              style: GoogleFonts.inter(
                  fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.textPrimaryColor),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${wikiProvider.attachments.length}',
                style: GoogleFonts.inter(
                    fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.primaryColor),
              ),
            ),
            const Spacer(),
            wikiProvider.isUploading
                ? const SizedBox(
                    width: 24, height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : TextButton.icon(
                    onPressed: () => _uploadAttachment(context, widget.article.id),
                    icon: const Icon(Icons.upload_file_rounded, size: 18),
                    label: Text('Importer', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                    style: TextButton.styleFrom(foregroundColor: AppTheme.primaryColor),
                  ),
          ],
        ),
        const SizedBox(height: 12),

        if (wikiProvider.isLoadingAttachments)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (wikiProvider.attachments.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            decoration: BoxDecoration(
              color: AppTheme.borderColor.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: AppTheme.borderColor,
                style: BorderStyle.solid,
              ),
            ),
            child: Column(
              children: [
                Icon(Icons.attach_file_rounded,
                    size: 36, color: AppTheme.textSecondaryColor.withValues(alpha: 0.4)),
                const SizedBox(height: 8),
                Text(
                  widget.canEdit
                      ? 'Aucun fichier joint. Cliquez sur "Importer" pour en ajouter.'
                      : 'Aucun fichier joint à cet article.',
                  style: GoogleFonts.inter(
                      fontSize: 12, color: AppTheme.textSecondaryColor),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          )
        else
          Column(
            children: wikiProvider.attachments.map((att) {
              return _buildAttachmentTile(context, att, wikiProvider);
            }).toList(),
          ),
      ],
    );
  }

  Widget _buildAttachmentTile(
    BuildContext context,
    WikiAttachment att,
    WikiProvider wikiProvider,
  ) {
    final ext = att.extension;
    final icon = _fileIcon(ext);
    final iconColor = _fileIconColor(ext);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  att.nomOriginal,
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${att.tailleLabel} • ${DateFormat('dd/MM/yyyy HH:mm').format(att.createdAt)}',
                  style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textSecondaryColor),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.download_rounded),
            tooltip: 'Télécharger',
            color: AppTheme.primaryColor,
            onPressed: () => _openDownload(context, wikiProvider, att),
          ),
          if (widget.canEdit)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded),
              tooltip: 'Supprimer',
              color: AppTheme.errorColor,
              onPressed: () => _confirmDeleteAttachment(context, att),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final wikiProvider = Provider.of<WikiProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.article.categorie),
        actions: [
          if (widget.canEdit) ...[
            IconButton(icon: const Icon(Icons.edit_outlined), onPressed: widget.onEdit),
          ],
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.article.titre,
              style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 20),
            ),
            const SizedBox(height: 6),
            Text(
              'Par ${widget.article.auteurPrenom ?? ""} ${widget.article.auteurNom ?? "IT Team"} • Publié le ${DateFormat('dd/MM/yyyy').format(DateTime.parse(widget.article.createdAt))}',
              style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textSecondaryColor),
            ),
            const Divider(height: 24),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.article.contenu,
                      style: GoogleFonts.inter(fontSize: 14, height: 1.5),
                    ),
                    const SizedBox(height: 32),
                    _buildAttachmentsSection(context, wikiProvider),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
