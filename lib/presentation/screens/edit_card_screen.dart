import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/app_localizations.dart';
import '../providers/cards_provider.dart';
import '../../core/theme/app_theme.dart';

/// Screen for editing an existing card
class EditCardScreen extends ConsumerStatefulWidget {
  final String cardId;

  const EditCardScreen({super.key, required this.cardId});

  @override
  ConsumerState<EditCardScreen> createState() => _EditCardScreenState();
}

class _EditCardScreenState extends ConsumerState<EditCardScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _idController = TextEditingController();
  final _prefixController = TextEditingController();
  final _suffixController = TextEditingController();

  bool _isLoading = false;
  bool _isInitialized = false;
  String _originalId = '';

  @override
  void dispose() {
    _nameController.dispose();
    _idController.dispose();
    _prefixController.dispose();
    _suffixController.dispose();
    super.dispose();
  }

  void _initControllers() {
    if (_isInitialized) return;

    final state = ref.read(cardsProvider);
    final card = state.cards.where((c) => c.id == widget.cardId).firstOrNull;

    if (card != null) {
      _nameController.text = card.name;
      _idController.text = card.id;
      _originalId = card.id;
      _prefixController.text = card.prefix;
      _suffixController.text = card.suffix;
      _isInitialized = true;
    }
  }

  String? _validateCardId(String? value, AppLocalizations l10n) {
    if (value == null || value.trim().isEmpty) {
      return l10n.idRequired;
    }
    final newId = value.trim();
    if (newId == _originalId) return null;
    
    final state = ref.read(cardsProvider);
    final exists = state.cards.any((c) => c.id == newId);
    if (exists) {
      return l10n.cardIdExists;
    }
    return null;
  }

  Future<void> _saveCard() async {
    if (!_formKey.currentState!.validate()) return;

    final state = ref.read(cardsProvider);
    final card = state.cards.where((c) => c.id == widget.cardId).firstOrNull;

    if (card == null) {
      context.pop();
      return;
    }

    setState(() => _isLoading = true);

    final updatedCard = card.copyWith(
      id: _idController.text.trim(),
      name: _nameController.text.trim(),
      prefix: _prefixController.text.trim(),
      suffix: _suffixController.text.trim(),
    );

    final success = await ref
        .read(cardsProvider.notifier)
        .updateCard(updatedCard);

    if (mounted) {
      setState(() => _isLoading = false);
      if (success) {
        context.pop();
      } else {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.saveChangesError)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(cardsProvider);
    final card = state.cards.where((c) => c.id == widget.cardId).firstOrNull;

    // Initialize controllers with card data
    _initControllers();

    if (card == null) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => context.pop(),
          ),
          title: Text(l10n.editCardTitle),
        ),
        body: Center(child: Text(l10n.noCards)),
      );
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        title: Text(l10n.editCardTitle),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Header illustration
            Container(
              height: 120,
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Center(
                child: Icon(
                  Icons.edit_rounded,
                  size: 56,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Card ID Section
            _SectionHeader(title: l10n.cardIdLabel),
            const SizedBox(height: 8),
            _FormCard(
              child: TextFormField(
                controller: _idController,
                decoration: InputDecoration(
                  hintText: l10n.cardIdPlaceholder,
                  prefixIcon: const Icon(Icons.credit_card_rounded),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  errorBorder: InputBorder.none,
                  focusedErrorBorder: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                keyboardType: TextInputType.number,
                validator: (value) => _validateCardId(value, l10n),
              ),
            ),

            const SizedBox(height: 24),

            // Name Section
            _SectionHeader(title: l10n.cardNameLabel),
            const SizedBox(height: 8),
            _FormCard(
              child: TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  hintText: l10n.cardNamePlaceholder,
                  prefixIcon: const Icon(Icons.label_rounded),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  errorBorder: InputBorder.none,
                  focusedErrorBorder: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return l10n.nameRequired;
                  }
                  return null;
                },
              ),
            ),

            const SizedBox(height: 24),

            // Prefix Section
            _SectionHeader(title: l10n.cardPrefixLabel),
            const SizedBox(height: 8),
            _FormCard(
              child: TextFormField(
                controller: _prefixController,
                decoration: InputDecoration(
                  hintText: l10n.cardPrefixPlaceholder,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Suffix Section
            _SectionHeader(title: l10n.cardSuffixLabel),
            const SizedBox(height: 8),
            _FormCard(
              child: TextFormField(
                controller: _suffixController,
                decoration: InputDecoration(
                  hintText: l10n.cardSuffixPlaceholder,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
            ),

            const SizedBox(height: 32),

            // Save button
            ElevatedButton(
              onPressed: _isLoading ? null : _saveCard,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 18),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(
                      l10n.saveChanges,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      title,
      style: theme.textTheme.titleSmall?.copyWith(
        color: theme.colorScheme.primary,
        fontWeight: FontWeight.bold,
        letterSpacing: 0.5,
      ),
    );
  }
}

class _FormCard extends StatelessWidget {
  final Widget child;

  const _FormCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: child,
      ),
    );
  }
}
