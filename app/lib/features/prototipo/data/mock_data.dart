// Datos de ejemplo (mock) para el prototipo de UI/UX.
// Se usan para que el prototipo funcione sin backend ni servicios reales.

import 'package:vecinal/features/prototipo/data/models.dart';

final List<ZoneProto> mockZones = const [
  ZoneProto(id: 'zona-1', name: 'La Victoria', district: 'Lima'),
  ZoneProto(id: 'zona-2', name: 'Miraflores', district: 'Lima'),
  ZoneProto(id: 'zona-3', name: 'San Borja', district: 'Lima'),
  ZoneProto(id: 'zona-4', name: 'Surco', district: 'Lima'),
];

final List<PostProto> mockPosts = [
  PostProto(
    id: 'post-1',
    title: 'Necesito ayuda en mi cuadra',
    type: 'need',
    typeLabel: 'Necesito',
    status: 'savedOnPhone',
    statusLabel: 'Guardado en tu celular',
    ago: 'hace 2 minutos',
    author: 'Ana',
    zone: 'La Victoria',
  ),
  PostProto(
    id: 'post-2',
    title: 'Presto herramientas de jardinería',
    type: 'lend',
    typeLabel: 'Presto',
    status: 'accepted',
    statusLabel: 'Enviado',
    ago: 'hace 15 minutos',
    author: 'Carlos',
    zone: 'Miraflores',
  ),
  PostProto(
    id: 'post-3',
    title: 'Dono ropa en buen estado',
    type: 'donate',
    typeLabel: 'Dono',
    status: 'accepted',
    statusLabel: 'Enviado',
    ago: 'hace 1 hora',
    author: 'María',
    zone: 'San Borja',
  ),
  PostProto(
    id: 'post-4',
    title: 'Ofrezco ayuda a mis vecinos',
    type: 'offer',
    typeLabel: 'Ofrezco',
    status: 'rejected',
    statusLabel: 'No se pudo completar',
    ago: 'hace 3 horas',
    author: 'Luis',
    zone: 'Surco',
  ),
];

final List<Map<String, String>> mockPublishTypes = const [
  {'value': 'offer', 'label': 'Ofrezco', 'hint': 'Ayuda o servicios'},
  {'value': 'need', 'label': 'Necesito', 'hint': 'Pido ayuda o cosas'},
  {'value': 'lend', 'label': 'Presto', 'hint': 'Presto cosas mías'},
  {'value': 'donate', 'label': 'Dono', 'hint': 'Dono cosas'},
  {'value': 'exchange', 'label': 'Intercambio', 'hint': 'Intercambio cosas'},
  {'value': 'ride', 'label': 'Movilidad', 'hint': 'Ofrezco movilidad'},
];
