import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:vecinal/features/prototipo/data/mock_data.dart';
import 'package:vecinal/features/prototipo/presentation/theme/app_theme.dart';
import 'package:vecinal/features/prototipo/presentation/widgets/proto_button.dart';
import 'package:vecinal/features/prototipo/presentation/widgets/proto_post_card.dart';
import 'package:vecinal/features/prototipo/presentation/widgets/proto_text_field.dart';

/// Pantalla principal del prototipo: Mapa con barra de navegación superior.
///
/// Después de elegir zona (o entrar como invitado), el flujo llega aquí.
/// Contiene 4 pestañas: Mapa, Muro, Publicar y Cuenta.
class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  int pending = 1;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        backgroundColor: kBackgroundColor,
        appBar: AppBar(
          backgroundColor: kSurfaceColor,
          elevation: 0,
          title: const Text(
            'Vecinal',
            style: TextStyle(
              color: kTextColor,
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
          centerTitle: true,
          bottom: TabBar(
            indicatorColor: kPrimaryColor,
            indicatorWeight: 3,
            labelColor: kPrimaryColor,
            unselectedLabelColor: const Color(0xFF9CA3AF),
            labelStyle: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
            unselectedLabelStyle: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
            tabs: const [
              Tab(icon: Icon(Icons.map_outlined, size: 24), text: 'Mapa'),
              Tab(icon: Icon(Icons.feed_outlined, size: 24), text: 'Muro'),
              Tab(icon: Icon(Icons.add_circle_outline, size: 24), text: 'Publicar'),
              Tab(icon: Icon(Icons.person_outline, size: 24), text: 'Cuenta'),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.notifications_outlined, color: kTextColor),
              onPressed: () => context.go('/por-revisar'),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: TabBarView(
          children: [
            // Pestaña 1: Mapa (vista principal)
            _MapaTab(),
            // Pestaña 2: Muro
            _MuroTab(pending: pending),
            // Pestaña 3: Publicar
            _PublicarTab(),
            // Pestaña 4: Cuenta
            _CuentaTab(),
          ],
        ),
      ),
    );
  }
}

/// Pestaña: Mapa (vista principal)
class _MapaTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Mapa de tu zona',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: kTextColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'El mapa sin conexión estará disponible en próximas versiones.',
              style: TextStyle(fontSize: 15, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 24),
            // Tarjeta de placeholder del mapa
            Container(
              height: 300,
              decoration: BoxDecoration(
                color: kSecondaryColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: kSecondaryColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: const Icon(
                        Icons.map_outlined,
                        size: 36,
                        color: kSecondaryColor,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Mapa',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: kTextColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Próximamente con zonas offline',
                      style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
            ),
            const Spacer(),
            ProtoButton(
              text: 'Ver tutorial',
              icon: Icons.play_circle_outline,
              onPressed: () => context.go('/tutorial'),
              fullWidth: true,
              secondary: true,
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

/// Pestaña: Muro
class _MuroTab extends StatelessWidget {
  final int pending;

  const _MuroTab({required this.pending});

  @override
  Widget build(BuildContext context) {
    final posts = mockPosts;

    return SafeArea(
      child: Column(
        children: [
          if (pending > 0)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
              color: kWarningColor.withValues(alpha: 0.1),
              child: Row(
                children: [
                  const Icon(Icons.schedule, size: 16, color: kWarningColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '$pending publicación${pending > 1 ? 'es' : ''} guardada${pending > 1 ? 's' : ''} en tu celular',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: kWarningColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 10),
          Expanded(
            child: posts.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.note_add, size: 64, color: Colors.grey.shade300),
                        const SizedBox(height: 16),
                        Text(
                          'Aún no hay publicaciones en tu zona.',
                          style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: posts.length,
                    itemBuilder: (context, index) {
                      return ProtoPostCard(post: posts[index]);
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

/// Pestaña: Publicar
class _PublicarTab extends StatefulWidget {
  @override
  State<_PublicarTab> createState() => _PublicarTabState();
}

class _PublicarTabState extends State<_PublicarTab> {
  String? selectedType;
  final titleController = TextEditingController();
  final descriptionController = TextEditingController();
  String? error;

  @override
  void dispose() {
    titleController.dispose();
    descriptionController.dispose();
    super.dispose();
  }

  void _publish() {
    if (selectedType == null) {
      setState(() => error = 'Selecciona un tipo de publicación.');
      return;
    }
    if (titleController.text.trim().length < 3) {
      setState(() => error = 'El título debe tener entre 3 y 120 caracteres.');
      return;
    }
    setState(() => error = null);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Publicación guardada en tu celular.'),
        backgroundColor: kSuccessColor,
        behavior: SnackBarBehavior.floating,
      ),
    );
    if (mounted) {
      context.go('/mapa');
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                '¿Qué quieres compartir?',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: kTextColor),
              ),
              const SizedBox(height: 8),
              Text(
                'Elige el tipo y los datos se prellenan.',
                style: TextStyle(fontSize: 15, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 24),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: mockPublishTypes.map((t) {
                  final isSelected = selectedType == t['value'];
                  return ChoiceChip(
                    label: Text(
                      t['label']!,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: isSelected ? Colors.white : kTextColor,
                      ),
                    ),
                    selected: isSelected,
                    onSelected: (_) => setState(() => selectedType = t['value']),
                    selectedColor: kPrimaryColor,
                    backgroundColor: kSurfaceColor,
                    labelPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: isSelected ? kPrimaryColor : Colors.grey.shade300,
                      ),
                    ),
                    elevation: 0,
                  );
                }).toList(),
              ),
              const SizedBox(height: 28),
              ProtoTextField(
                label: 'Título',
                hint: 'Necesito ayuda con...',
                controller: titleController,
                maxLength: 120,
                errorText: error,
              ),
              const SizedBox(height: 20),
              ProtoTextField(
                label: 'Descripción (opcional)',
                hint: 'Más detalles sobre lo que ofreces o necesitas',
                controller: descriptionController,
                maxLength: 2000,
                maxLines: 3,
              ),
              const SizedBox(height: 28),
              ProtoButton(
                text: 'Publicar',
                icon: Icons.publish,
                onPressed: _publish,
                fullWidth: true,
              ),
              const SizedBox(height: 16),
              ProtoButton(
                text: 'Cancelar',
                icon: Icons.close,
                onPressed: () => context.go('/mapa'),
                fullWidth: true,
                secondary: true,
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

/// Pestaña: Cuenta
class _CuentaTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Center(
                child: CircleAvatar(
                  radius: 48,
                  backgroundColor: Color(0xFFE2E8F0),
                  child: Icon(Icons.person, size: 48, color: kPrimaryColor),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Beto',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: kTextColor),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Zona: La Victoria · Lima',
                style: TextStyle(fontSize: 15, color: Colors.grey.shade600),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              ProtoButton(
                text: 'Modo sencillo',
                icon: Icons.accessibility,
                onPressed: () {},
                fullWidth: true,
              ),
              const SizedBox(height: 12),
              ProtoButton(
                text: 'Ver tutorial',
                icon: Icons.play_circle_outline,
                onPressed: () => context.go('/tutorial'),
                fullWidth: true,
              ),
              const SizedBox(height: 12),
              ProtoButton(
                text: 'Cerrar sesión',
                icon: Icons.logout,
                onPressed: () => context.go('/ingresar'),
                fullWidth: true,
                secondary: true,
              ),
              const SizedBox(height: 32),
              const Divider(color: Color(0xFFE5E7EB)),
              const SizedBox(height: 16),
              ProtoButton(
                text: 'Perdí mi teléfono',
                icon: Icons.phone_disabled,
                onPressed: () {},
                fullWidth: true,
                secondary: true,
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
