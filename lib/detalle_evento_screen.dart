// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

class AppColors {
  static const Color primario = Color(0xFF4B5AE4);
  static const Color primarioClaro = Color(0xFF6B7FFF);
  static const Color fondoPrincipal = Color(0xFFF8F9FF);
  static const Color textoBlanco = Color(0xFFFFFFFF);
  static const Color textoOscuro = Color(0xFF1A1D2E);
  static const Color textoMedio = Color(0xFF6B7280);
  static const Color acento = Color(0xFF10B981);
  static const Color error = Color(0xFFEF4444);
}

class DetalleEventoScreen extends StatefulWidget {
  final int idEvento;
  final String correoUsuario;

  const DetalleEventoScreen({
    super.key,
    required this.idEvento,
    required this.correoUsuario,
  });

  @override
  _DetalleEventoScreenState createState() => _DetalleEventoScreenState();
}

class _DetalleEventoScreenState extends State<DetalleEventoScreen> {
  Map<String, dynamic>? eventoDetalle;
  bool isLoading = true;
  String errorMessage = '';
  Position? _currentPosition;
  MapController _mapController = MapController();
  List<LatLng> _routePoints = [];
  bool _showingRoute = false;
  String? _estimatedTime;
  String? _estimatedDistance;

  @override
  void initState() {
    super.initState();
    _cargarDetalleEvento();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return;
    }

    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      setState(() {
        _currentPosition = position;
      });
    } catch (e) {
      print('Error obteniendo ubicación: $e');
    }
  }

  Future<void> _cargarDetalleEvento() async {
    setState(() {
      isLoading = true;
      errorMessage = '';
    });

    final url = Uri.parse(
      'http://192.168.56.1:8000/movil/evento/${widget.idEvento}/${widget.correoUsuario}',
    );

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final resultado = jsonDecode(response.body);
        setState(() {
          eventoDetalle = resultado['evento'];
          isLoading = false;
        });
      } else {
        setState(() {
          errorMessage = 'Error al cargar el evento';
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Error de conexión: $e';
        isLoading = false;
      });
    }
  }

  Future<void> _calcularRuta() async {
    if (_currentPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo obtener tu ubicación actual'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (eventoDetalle == null ||
        eventoDetalle!['latitud'] == null ||
        eventoDetalle!['longitud'] == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('El evento no tiene ubicación definida'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() {
      _showingRoute = true;
    });

    // Coordenadas de origen y destino
    final latOrigen = _currentPosition!.latitude;
    final lonOrigen = _currentPosition!.longitude;
    final latDestino = eventoDetalle!['latitud'];
    final lonDestino = eventoDetalle!['longitud'];

    // Llamar a OSRM (Open Source Routing Machine) para obtener la ruta
    final url = Uri.parse(
      'https://router.project-osrm.org/route/v1/driving/$lonOrigen,$latOrigen;$lonDestino,$latDestino?overview=full&geometries=geojson',
    );

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['routes'] != null && data['routes'].isNotEmpty) {
          final route = data['routes'][0];
          final coordinates = route['geometry']['coordinates'] as List;

          // Convertir coordenadas a LatLng
          final List<LatLng> points = coordinates.map((coord) {
            return LatLng(coord[1].toDouble(), coord[0].toDouble());
          }).toList();

          // Calcular tiempo y distancia
          final duration = route['duration']; // en segundos
          final distance = route['distance']; // en metros

          final hours = (duration / 3600).floor();
          final minutes = ((duration % 3600) / 60).round();

          String timeString;
          if (hours > 0) {
            timeString = '$hours h $minutes min';
          } else {
            timeString = '$minutes min';
          }

          final distanceKm = (distance / 1000).toStringAsFixed(1);

          setState(() {
            _routePoints = points;
            _estimatedTime = timeString;
            _estimatedDistance = '$distanceKm km';
          });

          // Ajustar el mapa para mostrar la ruta completa
          _mapController.fitCamera(
            CameraFit.bounds(
              bounds: LatLngBounds.fromPoints(points),
              padding: const EdgeInsets.all(50),
            ),
          );

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Ruta calculada: $distanceKm km - $timeString'),
              backgroundColor: AppColors.acento,
            ),
          );
        }
      } else {
        throw Exception('Error al calcular la ruta');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al calcular la ruta: $e'),
          backgroundColor: AppColors.error,
        ),
      );
      setState(() {
        _showingRoute = false;
      });
    }
  }

  Future<void> _abrirEnGoogleMaps() async {
    if (eventoDetalle == null ||
        eventoDetalle!['latitud'] == null ||
        eventoDetalle!['longitud'] == null) {
      return;
    }

    final lat = eventoDetalle!['latitud'];
    final lon = eventoDetalle!['longitud'];
    final url = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$lat,$lon',
    );

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.fondoPrincipal,
      body: SafeArea(
        child: isLoading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.primario),
              )
            : errorMessage.isNotEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 60,
                      color: AppColors.error,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      errorMessage,
                      style: const TextStyle(
                        color: AppColors.textoMedio,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _cargarDetalleEvento,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primario,
                      ),
                      child: const Text('Reintentar'),
                    ),
                  ],
                ),
              )
            : Column(
                children: [
                  // Barra superior
                  Container(
                    width: double.infinity,
                    height: 60,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppColors.primario, AppColors.primarioClaro],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.arrow_back,
                            color: AppColors.textoBlanco,
                            size: 28,
                          ),
                          onPressed: () {
                            Navigator.pop(context);
                          },
                        ),
                        const Expanded(
                          child: Text(
                            'Detalle del Evento',
                            style: TextStyle(
                              color: AppColors.textoBlanco,
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Contenido scrolleable
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Información principal
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  AppColors.primario.withValues(alpha: 0.1),
                                  AppColors.primarioClaro.withValues(
                                    alpha: 0.05,
                                  ),
                                ],
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Nombre del evento
                                Text(
                                  eventoDetalle!['nombre_evento'] ??
                                      'Sin nombre',
                                  style: const TextStyle(
                                    fontSize: 26,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textoOscuro,
                                  ),
                                ),
                                const SizedBox(height: 10),

                                // Estado
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: eventoDetalle!['estado'] == 'activo'
                                        ? AppColors.acento
                                        : Colors.grey,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    eventoDetalle!['estado'] == 'activo'
                                        ? 'EVENTO ACTIVO'
                                        : 'EVENTO FINALIZADO',
                                    style: const TextStyle(
                                      color: AppColors.textoBlanco,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 20),

                          // Detalles del evento
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildInfoCard(
                                  Icons.calendar_today,
                                  'Fecha',
                                  eventoDetalle!['fecha_evento'] ?? '',
                                ),
                                const SizedBox(height: 15),
                                _buildInfoCard(
                                  Icons.access_time,
                                  'Horario',
                                  '${eventoDetalle!['hora_inicio']} - ${eventoDetalle!['hora_fin']}',
                                ),
                                const SizedBox(height: 15),
                                _buildInfoCard(
                                  Icons.location_on,
                                  'Ubicación',
                                  eventoDetalle!['ubicacion'] ??
                                      'No especificada',
                                ),
                                const SizedBox(height: 15),
                                _buildInfoCard(
                                  Icons.people,
                                  'Total de invitados',
                                  '${eventoDetalle!['total_invitados']} personas',
                                ),
                                const SizedBox(height: 15),
                                _buildInfoCard(
                                  Icons.person_outline,
                                  'Organizado por',
                                  eventoDetalle!['organizador']['nombre'] ??
                                      'Desconocido',
                                ),
                                const SizedBox(height: 15),
                                _buildInfoCard(
                                  Icons.qr_code,
                                  'Código del evento',
                                  eventoDetalle!['codigo_evento'] ?? '',
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 30),

                          // Mapa
                          if (eventoDetalle!['latitud'] != null &&
                              eventoDetalle!['longitud'] != null) ...[
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Ubicación en el mapa',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textoOscuro,
                                    ),
                                  ),
                                  if (_showingRoute && _estimatedTime != null)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 5,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.acento,
                                        borderRadius: BorderRadius.circular(15),
                                      ),
                                      child: Text(
                                        '$_estimatedDistance • $_estimatedTime',
                                        style: const TextStyle(
                                          color: AppColors.textoBlanco,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 15),
                            Container(
                              height: 300,
                              margin: const EdgeInsets.symmetric(
                                horizontal: 20,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(15),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.1),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(15),
                                child: FlutterMap(
                                  mapController: _mapController,
                                  options: MapOptions(
                                    initialCenter: LatLng(
                                      eventoDetalle!['latitud'],
                                      eventoDetalle!['longitud'],
                                    ),
                                    initialZoom: 15.0,
                                  ),
                                  children: [
                                    TileLayer(
                                      urlTemplate:
                                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                      userAgentPackageName: 'com.litzor.movil',
                                    ),
                                    // Ruta calculada
                                    if (_showingRoute &&
                                        _routePoints.isNotEmpty)
                                      PolylineLayer(
                                        polylines: [
                                          Polyline(
                                            points: _routePoints,
                                            color: AppColors.primario,
                                            strokeWidth: 4.0,
                                          ),
                                        ],
                                      ),
                                    MarkerLayer(
                                      markers: [
                                        // Marcador del evento
                                        Marker(
                                          point: LatLng(
                                            eventoDetalle!['latitud'],
                                            eventoDetalle!['longitud'],
                                          ),
                                          width: 40,
                                          height: 40,
                                          child: const Icon(
                                            Icons.location_on,
                                            color: Colors.red,
                                            size: 40,
                                          ),
                                        ),
                                        // Marcador de ubicación actual
                                        if (_currentPosition != null)
                                          Marker(
                                            point: LatLng(
                                              _currentPosition!.latitude,
                                              _currentPosition!.longitude,
                                            ),
                                            width: 30,
                                            height: 30,
                                            child: Container(
                                              decoration: BoxDecoration(
                                                color: AppColors.acento,
                                                shape: BoxShape.circle,
                                                border: Border.all(
                                                  color: AppColors.textoBlanco,
                                                  width: 3,
                                                ),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),

                            // Botones de navegación
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                              ),
                              child: Column(
                                children: [
                                  // Botón "Cómo llegar"
                                  SizedBox(
                                    width: double.infinity,
                                    height: 55,
                                    child: ElevatedButton.icon(
                                      onPressed: _calcularRuta,
                                      icon: const Icon(Icons.directions),
                                      label: const Text(
                                        'Cómo llegar',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.primario,
                                        foregroundColor: AppColors.textoBlanco,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            15,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),

                                  // Botón "Abrir en Google Maps"
                                  SizedBox(
                                    width: double.infinity,
                                    height: 55,
                                    child: OutlinedButton.icon(
                                      onPressed: _abrirEnGoogleMaps,
                                      icon: const Icon(Icons.map),
                                      label: const Text(
                                        'Abrir en Google Maps',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: AppColors.primario,
                                        side: BorderSide(
                                          color: AppColors.primario,
                                          width: 2,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            15,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildInfoCard(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 45,
            height: 45,
            decoration: BoxDecoration(
              color: AppColors.primario.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppColors.primario, size: 24),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textoMedio,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textoOscuro,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
