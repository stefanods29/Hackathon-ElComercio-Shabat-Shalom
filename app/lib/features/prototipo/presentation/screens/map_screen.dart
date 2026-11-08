import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:vecinal/features/prototipo/data/mock_data.dart';
import 'package:vecinal/features/prototipo/data/models.dart';
import 'package:vecinal/features/prototipo/presentation/theme/app_theme.dart';
import 'package:vecinal/features/prototipo/presentation/widgets/proto_button.dart';
import 'package:vecinal/features/prototipo/presentation/widgets/proto_post_card.dart';
import 'package:vecinal/features/prototipo/presentation/widgets/proto_text_field.dart';

/// Pantalla principal del prototipo Winki: Mapa con publicaciones como marcadores.
class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  int _selectedIndex = 0;
  int pending = 1;
  final GlobalKey<ScaffoldState> _drawerKey = GlobalKey<ScaffoldState>();

  final List<Widget> _tabs = [
    _MapaTab(),
    _MuroTab(),
    _PublicarTab(),
    _CuentaTab(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _drawerKey,
      backgroundColor: kBackgroundColor,
      appBar: AppBar(
        backgroundColor: kSurfaceColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.menu, color: kTextColor),
          onPressed: () => _drawerKey.currentState?.openDrawer(),
        ),
        title: const _WinkiAppBarTitle(),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined, color: kTextColor),
            onPressed: () => context.go('/por-revisar'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      drawer: _buildDrawer(context),
      body: _tabs[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        type: BottomNavigationBarType.fixed,
        backgroundColor: kSurfaceColor,
        selectedItemColor: kPrimaryColor,
        unselectedItemColor: const Color(0xFF9CA3AF),
        showSelectedLabels: true,
        showUnselectedLabels: true,
        selectedLabelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        unselectedLabelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.map_outlined, size: 24), activeIcon: Icon(Icons.map, size: 24), label: 'Mapa'),
          BottomNavigationBarItem(icon: Icon(Icons.feed_outlined, size: 24), activeIcon: Icon(Icons.feed, size: 24), label: 'Muro'),
          BottomNavigationBarItem(icon: Icon(Icons.add_circle_outline, size: 24), activeIcon: Icon(Icons.add_circle, size: 24), label: 'Publicar'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline, size: 24), activeIcon: Icon(Icons.person, size: 24), label: 'Cuenta'),
        ],
      ),
    );
  }

  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: kPrimaryColor,
                borderRadius: BorderRadius.only(bottomLeft: Radius.circular(26), bottomRight: Radius.circular(26)),
              ),
              child: Column(
                children: [
                  const WinkiLogo(size: 56, withText: false),
                  const SizedBox(height: 12),
                  const Text('Winki', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(height: 4),
                  Text('Menú principal', style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.8))),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _DrawerItem(icon: Icons.home_outlined, label: 'Mapa', onTap: () { _drawerKey.currentState?.closeDrawer(); setState(() => _selectedIndex = 0); }),
            _DrawerItem(icon: Icons.feed_outlined, label: 'Muro', onTap: () { _drawerKey.currentState?.closeDrawer(); setState(() => _selectedIndex = 1); }),
            _DrawerItem(icon: Icons.add_circle_outlined, label: 'Publicar', onTap: () { _drawerKey.currentState?.closeDrawer(); setState(() => _selectedIndex = 2); }),
            _DrawerItem(icon: Icons.person_outlined, label: 'Cuenta', onTap: () { _drawerKey.currentState?.closeDrawer(); setState(() => _selectedIndex = 3); }),
            const Divider(height: 1),
            _DrawerItem(icon: Icons.school, label: 'Ver tutorial', onTap: () { _drawerKey.currentState?.closeDrawer(); context.go('/tutorial'); }),
            _DrawerItem(icon: Icons.warning_outlined, label: 'Emergencia', onTap: () { _drawerKey.currentState?.closeDrawer(); context.go('/emergencia'); }),
            _DrawerItem(icon: Icons.notifications_outlined, label: 'Avisos', onTap: () { _drawerKey.currentState?.closeDrawer(); context.go('/avisos'); }),
            const Divider(height: 1),
            _DrawerItem(icon: Icons.logout, label: 'Cerrar sesión', isDestructive: true, onTap: () { _drawerKey.currentState?.closeDrawer(); context.go('/ingresar'); }),
            _DrawerItem(icon: Icons.phone_disabled, label: 'Perdí mi teléfono', isDestructive: true, onTap: () => _drawerKey.currentState?.closeDrawer()),
            const Spacer(),
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Servicios, solidaridad y emergencias para tu barrio', textAlign: TextAlign.center, style: TextStyle(fontSize: 10, color: Color(0xFF9CA3AF))),
            ),
          ],
        ),
      ),
    );
  }
}

/// Ítem del drawer lateral
class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDestructive;
  const _DrawerItem({required this.icon, required this.label, required this.onTap, this.isDestructive = false});
  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: isDestructive ? kErrorColor : kSecondaryColor, size: 24),
      title: Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: isDestructive ? kErrorColor : kTextColor)),
      onTap: onTap,
    );
  }
}

/// Título de la app en el AppBar
class _WinkiAppBarTitle extends StatelessWidget {
  const _WinkiAppBarTitle();
  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 32, height: 32, decoration: BoxDecoration(color: kPrimaryColor, borderRadius: BorderRadius.circular(9999)), child: const Icon(Icons.sentiment_very_satisfied, size: 20, color: Colors.white)),
      const SizedBox(width: 4),
      const Text('Winki', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: kTextColor)),
    ]);
  }
}

/// Pestaña: Mapa (vista principal)
class _MapaTab extends StatelessWidget {
  const _MapaTab();
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Mapa de tu zona', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: kTextColor)),
                const SizedBox(height: 4),
                Text('Publicaciones cerca de ti', style: TextStyle(fontSize: 10, color: kTextSecondaryColor)),
              ],
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                Container(
                  width: double.infinity,
                  height: double.infinity,
                  decoration: BoxDecoration(color: kSecondaryColor.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey.shade200)),
                  child: const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.map_outlined, size: 32, color: kSecondaryColor),
                        SizedBox(height: 16),
                        Text('Mapa', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: kTextColor)),
                        SizedBox(height: 4),
                        Text('Próximamente con zonas offline', style: TextStyle(fontSize: 10, color: const Color(0xFF9CA3AF))),
                      ],
                    ),
                  ),
                ),
                ...mockPosts.map((post) => _MapMarker(post: post)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: kSurfaceColor, borderRadius: BorderRadius.only(topLeft: Radius.circular(26), topRight: Radius.circular(26)), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 12, offset: const Offset(0, -4))]),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              ProtoButton(text: 'Ver tutorial', icon: Icons.play_circle_outline, onPressed: () => context.go('/tutorial'), fullWidth: true, secondary: true),
              const SizedBox(height: 12),
            ]),
          ),
        ],
      ),
    );
  }
}

/// Marcador de publicación sobre el mapa
class _MapMarker extends StatelessWidget {
  final PostProto post;
  const _MapMarker({required this.post});
  Color _statusColor(String status) {
    switch (status) {
      case 'savedOnPhone': return kStatusSavedColor;
      case 'accepted': return kStatusAcceptedColor;
      case 'rejected': return kStatusRejectedColor;
      default: return kSecondaryColor;
    }
  }
  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(post.status);
    return Positioned(
      left: 60,
      top: 180,
      child: GestureDetector(
        onTap: () => context.go('/publicaciones/${post.id}'),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 32, height: 32, decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 6, offset: const Offset(0, 2))]), child: const Icon(Icons.location_on, size: 18, color: Colors.white)),
          const SizedBox(height: 4),
          Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: kSurfaceColor, borderRadius: BorderRadius.circular(9999), border: Border.all(color: statusColor), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4, offset: const Offset(0, 2))]), child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(post.typeLabel, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: statusColor)),
            const SizedBox(height: 2),
            Text(post.title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: kTextColor), maxLines: 2, overflow: TextOverflow.ellipsis),
          ])),
        ]),
      ),
    );
  }
}

/// Pestaña: Muro
class _MuroTab extends StatelessWidget {
  const _MuroTab();
  @override
  Widget build(BuildContext context) {
    final posts = mockPosts;
    return SafeArea(
      child: Column(
        children: [
          Expanded(
            child: posts.isEmpty
                ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.note_add, size: 64, color: Colors.grey.shade300), const SizedBox(height: 12), Text('Aún no hay publicaciones en tu zona.', style: TextStyle(fontSize: 14, color: Colors.grey.shade600))]))
                : ListView.builder(itemCount: posts.length, itemBuilder: (context, index) => ProtoPostCard(post: posts[index], onTap: () => context.go('/publicaciones/${posts[index].id}'))),
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
  void dispose() { titleController.dispose(); descriptionController.dispose(); super.dispose(); }
  void _publish() {
    if (selectedType == null) { setState(() => error = 'Selecciona un tipo de publicación.'); return; }
    if (titleController.text.trim().length < 3) { setState(() => error = 'El título debe tener entre 3 y 120 caracteres.'); return; }
    setState(() => error = null);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Publicación guardada en tu celular.'), backgroundColor: kSuccessColor, behavior: SnackBarBehavior.floating));
    if (mounted) context.go('/mapa');
  }
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(padding: const EdgeInsets.all(20), child: SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('¿Qué quieres compartir?', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: kTextColor)),
          const SizedBox(height: 4),
          Text('Elige el tipo y los datos se prellenan.', style: TextStyle(fontSize: 10, color: kTextSecondaryColor)),
          const SizedBox(height: 24),
          Wrap(spacing: 4, runSpacing: 4, children: mockPublishTypes.map((t) {
            final isSelected = selectedType == t['value'];
            return ChoiceChip(label: Text(t['label']!, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: isSelected ? Colors.white : kTextColor)), selected: isSelected, onSelected: (_) => setState(() => selectedType = t['value']), selectedColor: kPrimaryColor, backgroundColor: kSurfaceColor, labelPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9999), side: BorderSide(color: isSelected ? kPrimaryColor : Colors.grey.shade300)), elevation: 0);
          }).toList()),
          const SizedBox(height: 24),
          ProtoTextField(label: 'Título', hint: 'Necesito ayuda con...', controller: titleController, maxLength: 120, errorText: error),
          const SizedBox(height: 16),
          ProtoTextField(label: 'Descripción (opcional)', hint: 'Más detalles sobre lo que ofreces o necesitas', controller: descriptionController, maxLength: 2000, maxLines: 3),
          const SizedBox(height: 24),
          ProtoButton(text: 'Publicar', icon: Icons.publish, onPressed: _publish, fullWidth: true),
          const SizedBox(height: 12),
          ProtoButton(text: 'Cancelar', icon: Icons.close, onPressed: () => context.go('/mapa'), fullWidth: true, secondary: true),
          const SizedBox(height: 24),
        ]),
      )),
    );
  }
}

/// Pestaña: Cuenta
class _CuentaTab extends StatelessWidget {
  const _CuentaTab();
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Center(child: CircleAvatar(radius: 48, backgroundColor: Color(0xFFE2E8F0), child: Icon(Icons.person, size: 48, color: kPrimaryColor))),
          const SizedBox(height: 12),
          const Text('Beto', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: kTextColor), textAlign: TextAlign.center),
          const SizedBox(height: 4),
          Text('Zona: La Victoria · Lima', style: TextStyle(fontSize: 12, color: kTextSecondaryColor), textAlign: TextAlign.center),
          const SizedBox(height: 48),
          ProtoButton(text: 'Modo sencillo', icon: Icons.accessibility, onPressed: () {}, fullWidth: true),
          const SizedBox(height: 12),
          ProtoButton(text: 'Ver tutorial', icon: Icons.play_circle_outline, onPressed: () => context.go('/tutorial'), fullWidth: true),
          const SizedBox(height: 12),
          ProtoButton(text: 'Emergencia', icon: Icons.warning, onPressed: () => context.go('/emergencia'), fullWidth: true, secondary: true),
          const SizedBox(height: 12),
          ProtoButton(text: 'Avisos', icon: Icons.notifications, onPressed: () => context.go('/avisos'), fullWidth: true, secondary: true),
          const SizedBox(height: 48),
          const Divider(color: Color(0xFFE5E7EB)),
          const SizedBox(height: 16),
          ProtoButton(text: 'Perdí mi teléfono', icon: Icons.phone_disabled, onPressed: () {}, fullWidth: true, secondary: true),
          const SizedBox(height: 48),
        ])),
      ),
    );
  }
}

/// Widget del logo de Winki
class WinkiLogo extends StatelessWidget {
  final double size;
  final bool withText;
  const WinkiLogo({super.key, this.size = 56, this.withText = true});
  @override
  Widget build(BuildContext context) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Container(width: size, height: size, decoration: BoxDecoration(color: kPrimaryColor, borderRadius: BorderRadius.circular(9999)), child: Stack(children: [
        Positioned(left: size * 0.22, top: size * 0.30, child: Container(width: size * 0.12, height: size * 0.12, decoration: BoxDecoration(color: const Color(0xFF0E5A58), shape: BoxShape.circle))),
        Positioned(left: size * 0.58, top: size * 0.30, child: Container(width: size * 0.12, height: size * 0.12, decoration: BoxDecoration(color: const Color(0xFF0E5A58), shape: BoxShape.circle))),
        Positioned(left: size * 0.25, top: size * 0.58, child: Container(width: size * 0.40, height: size * 0.12, decoration: BoxDecoration(color: const Color(0xFF0E5A58), borderRadius: BorderRadius.circular(9999)))),
        Positioned(left: size * 0.72, top: size * 0.58, child: Container(width: size * 0.18, height: size * 0.18, decoration: BoxDecoration(color: kAccentColor, shape: BoxShape.circle))),
      ])),
      if (withText) ...[
        const SizedBox(height: 12),
        const Text('Winki', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: kPrimaryColor, letterSpacing: -0.02)),
        const SizedBox(height: 2),
        Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: size * 0.14, height: size * 0.14, decoration: BoxDecoration(color: kAccentColor, shape: BoxShape.circle)),
          const SizedBox(width: 4),
          Container(width: size * 0.14, height: size * 0.14, decoration: BoxDecoration(color: kAccentColor, shape: BoxShape.circle)),
        ]),
      ],
    ]);
  }
}
